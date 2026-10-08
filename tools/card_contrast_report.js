#!/usr/bin/env node
// card_contrast_report.js - luminance/contrast stats for the LIVE upgrade-card
// set (docs/87), and the install-time check for a returned contrast re-bake.
//
//   node tools/card_contrast_report.js                 stats for the shipped set
//   node tools/card_contrast_report.js --compare DIR   DIR holds the returned
//                                                      PNGs (same names); prints
//                                                      per-file contrast delta and
//                                                      FAILS if size, colour type
//                                                      or the ALPHA CHANNEL differ
//   node tools/card_contrast_report.js --list          print the live filenames
//
// Pure node: a minimal PNG decoder (8-bit RGBA, non-interlaced - every card is)
// so it needs no npm install. Stats are over OPAQUE pixels (alpha >= 250), sampled
// on a 2 px grid:
//   p5 / p50 / p95   luminance percentiles (Rec.709 Y, 0..255)
//   span             p95 - p5: how much of the tonal range the card actually uses
//   rms              RMS contrast (std dev of Y)
//   plate            mean Y of the description-plate FIELD (rows 840..990,
//                    cols 170..600) - the dark navy behind the effect text
//
// THE LIVE SET is derived, not typed: every GSC domain whose add_domain call is
// live (in _tod_upgrades.gsc), through the Lua CARD_SLUG table, plus the 8 tier
// cards. If a domain is added or retired the list follows on the next run.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = path.resolve(__dirname, '..');
const IMG_DIR = path.join(ROOT, 'source_data', 'tod_ui_images', '_images');
const GSC = path.join(ROOT, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_upgrades.gsc');
const GSC_IDS = path.join(ROOT, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_upgrade_ui.gsc');   // domain_id(): case "key": return N;
const LUA = path.join(ROOT, 'ui', 'uieditor', 'menus', 'hud', 'tod_upgrade.lua');

// ---------------------------------------------------------------- the live set
function liveCardFiles() {
    // 1. live domain KEYS: uncommented add_domain( "key", ... ) lines.
    const gsc = fs.readFileSync(GSC, 'utf8').split(/\r?\n/);
    const keys = [];
    for (const line of gsc) {
        const m = line.match(/^\s*add_domain\(\s*"([a-z0-9_]+)"/);
        if (m) keys.push(m[1]);
    }
    // 2. key -> id: _tod_upgrade_ui::domain_id(), a switch of `case "key": return N;`
    const idText = fs.readFileSync(GSC_IDS, 'utf8');
    const idOf = {};
    const idRe = /case\s+"([a-z0-9_]+)"\s*:\s*return\s+(\d+)\s*;/g;
    let m;
    while ((m = idRe.exec(idText)) !== null) {
        if (idOf[m[1]] === undefined) idOf[m[1]] = parseInt(m[2], 10);
    }
    // 3. id -> slug: the Lua CARD_SLUG table (live entries only).
    const lua = fs.readFileSync(LUA, 'utf8');
    const block = lua.slice(lua.indexOf('local CARD_SLUG = {'), lua.indexOf('local CARD_ONE_IMAGE'));
    const slugOf = {};
    const slugRe = /^\s*\[(\d+)\]\s*=\s*"([a-z_]+)"/gm;
    let s;
    const blockNoComments = block.split('\n').map(l => l.replace(/--.*$/, '')).join('\n');
    // a line may carry several [id] = "slug" pairs
    const pairRe = /\[(\d+)\]\s*=\s*"([a-z_]+)"/g;
    while ((s = pairRe.exec(blockNoComments)) !== null) slugOf[parseInt(s[1], 10)] = s[2];
    void slugRe;
    const oneImg = {};
    const oneBlock = lua.slice(lua.indexOf('local CARD_ONE_IMAGE'), lua.indexOf('art.cards = {}'));
    const oneRe = /\[(\d+)\]\s*=\s*"(regular|super|ultimate)"/g;
    let o;
    while ((o = oneRe.exec(oneBlock)) !== null) oneImg[parseInt(o[1], 10)] = o[2];

    const files = [];
    const missing = [];
    for (const k of keys) {
        const id = idOf[k];
        const slug = id === undefined ? undefined : slugOf[id];
        if (!slug) { missing.push(k + (id === undefined ? ' (no id)' : ' (id ' + id + ', no slug)')); continue; }
        if (oneImg[id]) files.push('i_tod_card_' + slug + '_' + oneImg[id] + '.png');
        else for (const r of ['regular', 'super', 'ultimate']) files.push('i_tod_card_' + slug + '_' + r + '.png');
    }
    for (const c of ['skirmisher', 'assault', 'heavy', 'slasher']) for (const t of [2, 3]) files.push('i_tod_card_tier_' + c + '_' + t + '.png');
    return { files, keys, missing };
}

// ---------------------------------------------------------------- PNG decode
function decodePng(buf) {
    const sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    for (let i = 0; i < 8; i++) if (buf[i] !== sig[i]) throw new Error('not a PNG');
    let pos = 8, w = 0, h = 0, depth = 0, ct = 0, interlace = 0;
    const idat = [];
    while (pos < buf.length) {
        const len = buf.readUInt32BE(pos);
        const type = buf.toString('ascii', pos + 4, pos + 8);
        const data = buf.subarray(pos + 8, pos + 8 + len);
        if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); depth = data[8]; ct = data[9]; interlace = data[12]; }
        else if (type === 'IDAT') idat.push(data);
        else if (type === 'IEND') break;
        pos += 12 + len;
    }
    if (depth !== 8 || interlace !== 0) throw new Error('unsupported PNG (depth ' + depth + ', interlace ' + interlace + ')');
    const bpp = { 0: 1, 2: 3, 4: 2, 6: 4 }[ct];
    if (!bpp) throw new Error('unsupported colour type ' + ct);
    const raw = zlib.inflateSync(Buffer.concat(idat));
    const stride = w * bpp;
    const out = Buffer.alloc(stride * h);
    let ip = 0;
    for (let y = 0; y < h; y++) {
        const f = raw[ip++];
        const o = y * stride;
        for (let x = 0; x < stride; x++) {
            const a = x >= bpp ? out[o + x - bpp] : 0;
            const b = y > 0 ? out[o - stride + x] : 0;
            const c = (y > 0 && x >= bpp) ? out[o - stride + x - bpp] : 0;
            const v = raw[ip++];
            let p;
            if (f === 0) p = v;
            else if (f === 1) p = v + a;
            else if (f === 2) p = v + b;
            else if (f === 3) p = v + ((a + b) >> 1);
            else if (f === 4) {
                const pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c);
                p = v + ((pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c));
            } else throw new Error('bad filter ' + f);
            out[o + x] = p & 255;
        }
    }
    return { w, h, ct, bpp, data: out };
}

// ---------------------------------------------------------------- stats
function stats(img) {
    const { w, h, bpp, data } = img;
    const hist = new Int32Array(256);
    let n = 0, sum = 0, sumsq = 0, plateSum = 0, plateN = 0;
    let opaque = 0, clear = 0, mid = 0;
    for (let y = 0; y < h; y += 2) {
        for (let x = 0; x < w; x += 2) {
            const i = (y * w + x) * bpp;
            const a = bpp === 4 ? data[i + 3] : 255;
            if (a === 255) opaque++; else if (a === 0) clear++; else mid++;
            if (a < 250) continue;
            const r = data[i], g = bpp >= 3 ? data[i + 1] : r, b = bpp >= 3 ? data[i + 2] : r;
            const L = (0.2126 * r + 0.7152 * g + 0.0722 * b) | 0;
            hist[L]++; n++; sum += L; sumsq += L * L;
            if (y >= 840 && y <= 990 && x >= 170 && x <= 600) { plateSum += L; plateN++; }
        }
    }
    const mean = sum / n;
    const rms = Math.sqrt(sumsq / n - mean * mean);
    let acc = 0, p5 = -1, p50 = -1, p95 = -1;
    for (let L = 0; L < 256; L++) {
        acc += hist[L];
        if (p5 < 0 && acc >= 0.05 * n) p5 = L;
        if (p50 < 0 && acc >= 0.50 * n) p50 = L;
        if (p95 < 0 && acc >= 0.95 * n) p95 = L;
    }
    return { mean, rms, p5, p50, p95, span: p95 - p5, plate: plateN ? plateSum / plateN : 0, opaque, clear, mid };
}

// ---------------------------------------------------------------- regions + legibility
// THE CARD'S CONTENT LIVES IN FOUR BANDS on the 768x1152 canvas. Everything else
// is chassis (body, rivets, rails, glow). Boxes verified by writing crops with
// --crops and LOOKING at them - do that again if the card layout ever moves.
const REGIONS = [
    { key: 'title', box: [118, 92, 652, 190], what: 'the amber title plate: domain name in white' },
    { key: 'art', box: [128, 228, 648, 692], what: 'the screen panel: the icon/illustration' },
    { key: 'rarity', box: [178, 716, 598, 788], what: 'the rarity band: REGULAR/SUPER/ULTIMATE +N' },
    { key: 'effect', box: [162, 846, 610, 984], what: 'the description plate: what the upgrade DOES' },
];
// sRGB -> linear, for a real WCAG contrast ratio (not a raw 0..255 difference)
const LIN = (() => { const t = new Float64Array(256); for (let i = 0; i < 256; i++) { const c = i / 255; t[i] = c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); } return t; })();

// Otsu split of a region's luminance histogram: the bright cluster is the INK
// (white/coloured type, the lit parts of the icon), the dark cluster is the FIELD
// it has to be seen against. Works for every band here because every one of them
// is light-on-dark or white-on-amber.
function regionContrast(img, box) {
    const [x0, y0, x1, y1] = box;
    const { w, bpp, data } = img;
    const hist = new Int32Array(256);
    let n = 0;
    for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
            const i = (y * w + x) * bpp;
            if (bpp === 4 && data[i + 3] < 250) continue;
            const L = (0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]) | 0;
            hist[L]++; n++;
        }
    }
    if (!n) return null;
    let total = 0; for (let i = 0; i < 256; i++) total += i * hist[i];
    let sumB = 0, wB = 0, best = -1, thr = 128;
    for (let t = 0; t < 256; t++) {
        wB += hist[t]; if (!wB) continue;
        const wF = n - wB; if (!wF) break;
        sumB += t * hist[t];
        const mB = sumB / wB, mF = (total - sumB) / wF;
        const between = wB * wF * (mB - mF) * (mB - mF);
        if (between > best) { best = between; thr = t; }
    }
    let inkY = 0, inkN = 0, fldY = 0, fldN = 0, inkPk = 0;
    for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
            const i = (y * w + x) * bpp;
            if (bpp === 4 && data[i + 3] < 250) continue;
            const L = (0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]) | 0;
            const Y = 0.2126 * LIN[data[i]] + 0.7152 * LIN[data[i + 1]] + 0.0722 * LIN[data[i + 2]];
            if (L > thr) { inkY += Y; inkN++; if (L > inkPk) inkPk = L; } else { fldY += Y; fldN++; }
        }
    }
    if (!inkN || !fldN) return null;
    const ink = inkY / inkN, fld = fldY / fldN;
    return {
        ratio: (Math.max(ink, fld) + 0.05) / (Math.min(ink, fld) + 0.05),
        inkPct: 100 * inkN / n, thr, inkPk,
    };
}

// THE ART PANEL NEEDS ITS OWN MEASURE, AND THE FIRST ONE WAS WRONG. The Otsu
// ink/field ratio above says every art panel is 7:1 or better - because it puts
// the white sparkles, cyan speed lines and gold trim in "ink" and everything
// else in "field". That is a real number answering a question nobody asked: it
// proves bright pixels exist somewhere in the panel, NOT that the illustration
// separates from the panel behind it. The SPRINT boot is dark navy on a dark
// navy panel and scores 5.6:1 on that metric while being the least visible icon
// in the set.
//
// So: find the panel's BACKGROUND (the modal luminance - the field is always the
// largest single tone), then find the ILLUSTRATION BODY (the largest mode that is
// not the background, ignoring a +-10 window around it), and report the WCAG
// ratio between those two. Dark-on-dark art lands near 1:1 whatever else is in
// the panel.
function iconSeparation(img, box) {
    const [x0, y0, x1, y1] = box;
    const { w, bpp, data } = img;
    const hist = new Int32Array(256);
    const rgbSum = [new Float64Array(256), new Float64Array(256), new Float64Array(256)];
    for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
            const i = (y * w + x) * bpp;
            if (bpp === 4 && data[i + 3] < 250) continue;
            const L = (0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]) | 0;
            hist[L]++;
            rgbSum[0][L] += data[i]; rgbSum[1][L] += data[i + 1]; rgbSum[2][L] += data[i + 2];
        }
    }
    // smooth the histogram so a gradient background is one mode, not twenty
    const sm = new Float64Array(256);
    for (let i = 0; i < 256; i++) { let s = 0, n = 0; for (let k = -3; k <= 3; k++) { const j = i + k; if (j >= 0 && j < 256) { s += hist[j]; n++; } } sm[i] = s / n; }
    let bg = 0; for (let i = 1; i < 256; i++) if (sm[i] > sm[bg]) bg = i;
    // ...AND THE "second mode" IS ALSO THE BACKGROUND. The panel carries a vignette
    // gradient, so the runner-up mode is the lit corner of the same navy field
    // (every card reported "panel L31 vs icon L42", the bright-orange rocket
    // included). Two metrics, two wrong questions. What actually answers "does the
    // illustration separate from its panel" is AREA: the field occupies a narrow
    // luminance band, so measure how much of the panel sits OUTSIDE it.
    //   ink   = % of panel area more than 25 L from the field mode (the drawing)
    //   dark  = of that ink, the % that is DARKER than the field (ink that
    //           separates only by being blacker - outlines, not shapes)
    // A bright icon on a dark panel has high ink. A dark-navy icon has almost none,
    // because its body sits inside the field band and only its outline escapes.
    let ink = 0, inkDark = 0, tot = 0;
    for (let i = 0; i < 256; i++) {
        tot += hist[i];
        if (Math.abs(i - bg) > 25) { ink += hist[i]; if (i < bg) inkDark += hist[i]; }
    }
    return { bg, ink: 100 * ink / tot, inkDark: 100 * inkDark / Math.max(1, ink) };
}

// ---------------------------------------------------------------- PNG encode (calibration previews only)
const CRC_TABLE = (() => {
    const t = new Int32Array(256);
    for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1); t[n] = c; }
    return t;
})();
function crc32(buf) {
    let c = -1;
    for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 255] ^ (c >>> 8);
    return (c ^ -1) >>> 0;
}
function chunk(type, data) {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
    const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td), 0);
    return Buffer.concat([len, td, crc]);
}
function encodePngRgba(w, h, rgba) {
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
    const stride = w * 4;
    const raw = Buffer.alloc((stride + 1) * h);
    for (let y = 0; y < h; y++) { raw[y * (stride + 1)] = 0; rgba.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride); }
    return Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
    ]);
}
// --curve OUTDIR [--points "0:0,40:28,128:132,200:216,255:255"] writes curve-applied
// copies of the live set (RGB through the LUT, alpha untouched) - the calibration
// look for a contrast brief, and the numbers a --compare run should then match.
function buildLut(spec) {
    const pts = spec.split(',').map(p => p.split(':').map(Number)).sort((a, b) => a[0] - b[0]);
    const lut = new Uint8Array(256);
    for (let x = 0; x < 256; x++) {
        let i = 0;
        while (i < pts.length - 2 && x > pts[i + 1][0]) i++;
        const [x0, y0] = pts[i], [x1, y1] = pts[i + 1];
        const y = x <= x0 ? y0 : x >= x1 ? y1 : y0 + (y1 - y0) * (x - x0) / (x1 - x0);
        lut[x] = Math.max(0, Math.min(255, Math.round(y)));
    }
    return lut;
}

function alphaIdentical(a, b) {
    if (a.w !== b.w || a.h !== b.h || a.bpp !== 4 || b.bpp !== 4) return false;
    const n = a.w * a.h;
    let diff = 0;
    for (let i = 0; i < n; i++) if (Math.abs(a.data[i * 4 + 3] - b.data[i * 4 + 3]) > 2) diff++;
    return diff === 0 ? true : diff;
}

// ---------------------------------------------------------------- main
const args = process.argv.slice(2);
const live = liveCardFiles();
if (live.missing.length) {
    console.error('[card-contrast] live domains with NO card slug: ' + live.missing.join(', '));
}
if (args.includes('--list')) { console.log(live.files.join('\n')); process.exit(0); }

const cmpIdx = args.indexOf('--compare');
const cmpDir = cmpIdx >= 0 ? path.resolve(args[cmpIdx + 1]) : null;

// --crops OUTDIR --only <substr> : write each region as its own PNG so the boxes
// above can be checked by eye. A region box nobody has looked at is a guess.
const cropIdx = args.indexOf('--crops');
if (cropIdx >= 0) {
    const outDir = path.resolve(args[cropIdx + 1]);
    const onlyIdx = args.indexOf('--only');
    const only = onlyIdx >= 0 ? args[onlyIdx + 1].split(',') : ['damage_regular'];
    fs.mkdirSync(outDir, { recursive: true });
    for (const f of live.files) {
        if (!only.some(o => f.includes(o))) continue;
        const img = decodePng(fs.readFileSync(path.join(IMG_DIR, f)));
        for (const r of REGIONS) {
            const [x0, y0, x1, y1] = r.box, cw = x1 - x0, ch = y1 - y0;
            const out = Buffer.alloc(cw * ch * 4);
            for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
                const s = ((y + y0) * img.w + (x + x0)) * img.bpp, d = (y * cw + x) * 4;
                out[d] = img.data[s]; out[d + 1] = img.data[s + 1]; out[d + 2] = img.data[s + 2]; out[d + 3] = img.bpp === 4 ? img.data[s + 3] : 255;
            }
            fs.writeFileSync(path.join(outDir, f.replace(/\.png$/, '') + '__' + r.key + '.png'), encodePngRgba(cw, ch, out));
        }
    }
    console.log('[card-contrast] crops -> ' + outDir);
    process.exit(0);
}

// --regions : the legibility read. Per card, the WCAG contrast ratio between each
// band's INK and the FIELD behind it. 4.5:1 is the readable-body-text floor, 3:1
// the large-text floor; below 3:1 a player squints at it inside a 15 s timed pick.
if (args.includes('--regions')) {
    const fromIdx = args.indexOf('--from');
    const srcDir = fromIdx >= 0 ? path.resolve(args[fromIdx + 1]) : IMG_DIR;   // --from DIR reads a returned drop instead of the shipped set
    const onlyIdx = args.indexOf('--only');
    const only = onlyIdx >= 0 ? args[onlyIdx + 1].split(',') : null;
    const acc = {}; for (const r of REGIONS) acc[r.key] = [];
    const icons = [];
    const rows = [];
    const artBox = REGIONS.find(r => r.key === 'art').box;
    for (const f of live.files) {
        if (only && !only.some(o => f.includes(o))) continue;
        const src = path.join(srcDir, f);
        if (!fs.existsSync(src)) continue;
        const img = decodePng(fs.readFileSync(src));
        const cells = REGIONS.map(r => { const c = regionContrast(img, r.box); if (c) acc[r.key].push({ f, ratio: c.ratio }); return c; });
        const ic = iconSeparation(img, artBox);
        if (ic) icons.push({ f, ...ic });
        rows.push(`${f.padEnd(44)} ` + REGIONS.map((r, i) => `${r.key} ${cells[i] ? cells[i].ratio.toFixed(2).padStart(6) : "  n/a"}:1`).join("  ")
            + (ic ? `   INK ${ic.ink.toFixed(1).padStart(5)}%  (${ic.inkDark.toFixed(0)}% of it merely darker)` : ""));
    }
    rows.forEach(r => console.log(r));
    console.log('');
    for (const r of REGIONS) {
        const a = acc[r.key].slice().sort((x, y) => x.ratio - y.ratio);
        if (!a.length) continue;
        const med = a[a.length >> 1].ratio;
        const under3 = a.filter(x => x.ratio < 3).length, under45 = a.filter(x => x.ratio < 4.5).length;
        console.log(`${r.key.padEnd(7)} median ${med.toFixed(2)}:1   worst ${a[0].ratio.toFixed(2)}:1 (${a[0].f})   best ${a[a.length - 1].ratio.toFixed(2)}:1   under 3:1 ${under3}   under 4.5:1 ${under45}   <- ${r.what}`);
    }
    if (icons.length) {
        const s2 = icons.slice().sort((x, y) => x.ink - y.ink);
        console.log("");
        console.log(`ART PANEL INK COVERAGE  median ${s2[s2.length >> 1].ink.toFixed(1)}%   under 8% ${s2.filter(x => x.ink < 8).length}   under 12% ${s2.filter(x => x.ink < 12).length}`);
        console.log("  the 12 faintest illustrations (least of the panel is anything but field):");
        for (const x of s2.slice(0, 12)) console.log(`    ${x.f.padEnd(44)} ink ${x.ink.toFixed(1).padStart(5)}%   field L${x.bg}   ${x.inkDark.toFixed(0)}% of the ink is only DARKER than the field`);
        console.log("  the 6 clearest, for comparison:");
        for (const x of s2.slice(-6)) console.log(`    ${x.f.padEnd(44)} ink ${x.ink.toFixed(1).padStart(5)}%   field L${x.bg}`);
    }
    process.exit(0);
}

const curveIdx = args.indexOf('--curve');
if (curveIdx >= 0) {
    const outDir = path.resolve(args[curveIdx + 1]);
    const ptsIdx = args.indexOf('--points');
    const spec = ptsIdx >= 0 ? args[ptsIdx + 1] : '0:0,40:28,128:132,200:216,255:255';
    const onlyIdx = args.indexOf('--only');
    const only = onlyIdx >= 0 ? args[onlyIdx + 1].split(',') : null;
    const lut = buildLut(spec);
    fs.mkdirSync(outDir, { recursive: true });
    let n = 0;
    for (const f of live.files) {
        if (only && !only.some(o => f.includes(o))) continue;
        const img = decodePng(fs.readFileSync(path.join(IMG_DIR, f)));
        const out = Buffer.from(img.data);
        for (let i = 0; i < out.length; i += 4) { out[i] = lut[out[i]]; out[i + 1] = lut[out[i + 1]]; out[i + 2] = lut[out[i + 2]]; }
        fs.writeFileSync(path.join(outDir, f), encodePngRgba(img.w, img.h, out));
        n++;
    }
    console.log(`[card-contrast] curve "${spec}" applied to ${n} file(s) -> ${outDir}`);
    process.exit(0);
}

const fmt = (s) => `p5 ${String(s.p5).padStart(3)}  p50 ${String(s.p50).padStart(3)}  p95 ${String(s.p95).padStart(3)}  span ${String(s.span).padStart(3)}  rms ${s.rms.toFixed(1).padStart(5)}  plate ${s.plate.toFixed(1).padStart(5)}`;
const spans = [], rmss = [];
let fails = 0, compared = 0;
for (const f of live.files) {
    const p = path.join(IMG_DIR, f);
    if (!fs.existsSync(p)) { console.log(`${f.padEnd(44)} MISSING in repo`); fails++; continue; }
    const img = decodePng(fs.readFileSync(p));
    const s = stats(img);
    spans.push(s.span); rmss.push(s.rms);
    if (!cmpDir) { console.log(`${f.padEnd(44)} ${img.w}x${img.h} ct${img.ct}  ${fmt(s)}`); continue; }
    const q = path.join(cmpDir, f);
    if (!fs.existsSync(q)) { console.log(`${f.padEnd(44)} NOT IN DROP`); continue; }
    const img2 = decodePng(fs.readFileSync(q));
    const s2 = stats(img2);
    compared++;
    const problems = [];
    if (img2.w !== img.w || img2.h !== img.h) problems.push(`size ${img2.w}x${img2.h}`);
    if (img2.ct !== img.ct) problems.push(`colour type ${img2.ct}`);
    const ai = alphaIdentical(img, img2);
    if (ai !== true) problems.push(ai === false ? 'alpha not comparable' : `alpha differs on ${ai} px`);
    const dSpan = s2.span - s.span, dRms = s2.rms - s.rms;
    if (dSpan < 0 || dRms < 0) problems.push('contrast went DOWN');
    if (s2.p95 < s.p95) problems.push('highlights dimmer');
    const tag = problems.length ? 'FAIL ' + problems.join('; ') : 'ok';
    if (problems.length) fails++;
    console.log(`${f.padEnd(44)} span ${String(s.span).padStart(3)} -> ${String(s2.span).padStart(3)} (${dSpan >= 0 ? '+' : ''}${dSpan})  rms ${s.rms.toFixed(1)} -> ${s2.rms.toFixed(1)} (${dRms >= 0 ? '+' : ''}${dRms.toFixed(1)})  plate ${s.plate.toFixed(0)} -> ${s2.plate.toFixed(0)}  ${tag}`);
}
const min = (a) => Math.min(...a), max = (a) => Math.max(...a), avg = (a) => a.reduce((x, y) => x + y, 0) / a.length;
console.log('');
console.log(`[card-contrast] ${live.files.length} live card files (${live.keys.length} live domains + 8 tier cards)`);
if (spans.length) console.log(`[card-contrast] shipped set: span min/avg/max ${min(spans)}/${avg(spans).toFixed(1)}/${max(spans)}   rms min/avg/max ${min(rmss).toFixed(1)}/${avg(rmss).toFixed(1)}/${max(rmss).toFixed(1)}`);
if (cmpDir) {
    console.log(`[card-contrast] compared ${compared}/${live.files.length} against ${cmpDir}: ${fails ? fails + ' FAIL' : 'all ok'}`);
    process.exit(fails ? 1 : 0);
}
