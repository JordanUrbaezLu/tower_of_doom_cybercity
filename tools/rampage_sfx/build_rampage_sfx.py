"""Rampage ON / OFF stings (2026-10-02): the user's downloads, reworked into the map's own cyber sound
for the cyber Rampage Inducer (docs/168).

User, in order: "I also downloaded wav files for rampage on and off. Can we implement and slight tweak to
match our inducer and give it a bit more cyber tone" -> (after hearing pass 1) "Remove the cha ching. and
a bit more tweaks. Almost a bit away from the original sound to give it more uniqueness".

PASS 2 (rev unique_2) - the recording is still the spine (its rumble and crackle carry the weight), but it
is TRANSFORMED rather than decorated:
  * RESPONSE  the 0.15 s of dead air before each recording trimmed (6 ms kept, 2 ms fade-in)
  * PITCH     ON +3 semitones (brighter, 16% shorter = snappier); OFF -2 semitones (deeper, heavier)
  * METAL     a ring-modulated copy (ON 90 Hz, OFF 70 Hz), band-limited 300 Hz-6 kHz - robotic edge
  * HUM       a feedback comb tuned to the key (ON E3, OFF A2) on the source - a pitched energy core
  * BOOT/DECAY  ON boots: 4-bit / 6 kHz crunch resolving clean over its first 0.8 s. OFF decays: clean
              degrading to 5-bit crunch over its body, then a TAPE-STOP from 1.0 s before the body ends
              (over 2 s the playback speed sinks to 15% as it fades out) - the power draining away
  * GLITCH    ON: three digital stutters (a 35 ms grain repeated, falling away) through the surge
  * SWEEP     a detuned two-voice synth through a resonant low-pass: ON rises E2 -> E4 opening, OFF falls
              E4 -> A1 closing - louder than pass 1. Its volume FOLLOWS THE RECORDING'S OWN ENVELOPE
              (full while the recording is within 6 dB of its peak, squared below that; ON's tail after
              the body 0.15 s), so it is finished before the recording is
  * WEIGHT    ON: a sub drop (70 -> 38 Hz) on the press
  * PRESS     ON's rising three-blip arpeggio / OFF's falling pair, dry, inside the first 0.12 s
  * MASTER    28 Hz high-pass, +2 dB shelf at 5 kHz, -13 LUFS / -1 dBTP (ffmpeg loudnorm, two-pass)

PASS 3 (rev unique_3; user on pass 2: "You have like this last second sound that takes over. I dont want
that"): measured per layer, the closing three-note chime + its ping-pong echoes were 65-97% of what the ear
heard from 1.75 s to the end of ON (and 55% of OFF at 1.5 s). The chime and its echoes are GONE from both,
and the sweep now follows the recording so it cannot take the ending over instead. Every other layer is as
pass 2. Check any future layer the same way: no added layer may out-weigh the recording in any 250 ms.

Inputs (repo copies, sha256 pinned in the manifest): art/rampage_sfx/source/rampage_{on,off}_src.wav
Outputs: sound_assets/tod/sfx/tod_rampage_{on,off}.wav (48 kHz stereo 16-bit), art/rampage_sfx/manifest.json
Run:     python tools/rampage_sfx/build_rampage_sfx.py            (re-render both stings + the manifest)
Gate:    python tools/rampage_sfx/build_rampage_sfx.py --check    (build_map.ps1, every build; see check())
"""
import hashlib, json, os, re, subprocess, tempfile
from pathlib import Path
import numpy as np
import scipy.signal as ss
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT/'art/rampage_sfx/source'
OUT = ROOT/'sound_assets/tod/sfx'
MANIFEST = ROOT/'art/rampage_sfx/manifest.json'
FFMPEG = Path(os.environ.get('TOD_FFMPEG', r'C:\Users\jorda\AppData\Local\Microsoft\WinGet\Packages'
              r'\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin\ffmpeg.exe'))
SR = 48000
REV = 'unique_3'
TARGET_LUFS, TARGET_TP = -13.0, -1.0
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()

# the design, per sting (all the numbers the header describes)
SPEC = {
    'on':  dict(semis=+3.0, ring_hz=90.0, comb_hz=164.81, sweep=(82.41, 329.63), cutoff=(300, 5200),
                body_end=1.95, boot=0.8, sub=True, stutters=(0.45, 1.0, 1.5)),
    'off': dict(semis=-2.0, ring_hz=70.0, comb_hz=110.0, sweep=(329.63, 55.0), cutoff=(4200, 200),
                body_end=2.95, decay_bits=5, tape_from=1.0, tape_secs=2.0, tape_curve=1.3, tape_end=0.15),
}
LEVEL_DB = dict(metal=-9.0, hum=-12.0, sweep=-8.0, sub=-7.0, glitch=-8.0, blips=-10.0, grit=-14.0)
SWEEP_FOLLOW_DB = -6.0      # the sweep is at full level while the recording is within this of its peak


def load(p):
    x, sr = sf.read(str(p), dtype='float64', always_2d=True)
    assert sr == SR and x.shape[1] == 2, (p, sr, x.shape)
    return x


def trim_lead(x, thresh_db=-48.0, pre_ms=6.0):
    env = np.abs(x).max(axis=1)
    idx = int(np.argmax(env > 10 ** (thresh_db / 20)))
    start = max(0, idx - int(SR * pre_ms / 1000))
    y = x[start:].copy()
    n = int(SR * 0.002)
    y[:n] *= np.linspace(0, 1, n)[:, None]
    return y, start / SR


def sos(kind, f, x, order=2):
    return ss.sosfilt(ss.butter(order, f, btype=kind, fs=SR, output='sos'), x, axis=0)


def shelf_high(x, f0, gain_db, q=0.707):
    A = 10 ** (gain_db / 40); w0 = 2 * np.pi * f0 / SR; al = np.sin(w0) / (2 * q); c = np.cos(w0)
    b = [A * ((A + 1) + (A - 1) * c + 2 * np.sqrt(A) * al), -2 * A * ((A - 1) + (A + 1) * c),
         A * ((A + 1) + (A - 1) * c - 2 * np.sqrt(A) * al)]
    a = [(A + 1) - (A - 1) * c + 2 * np.sqrt(A) * al, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - 2 * np.sqrt(A) * al]
    return ss.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)


def rms(x):
    return float(np.sqrt(np.mean(np.square(x))) + 1e-12)


def active_rms(x):
    env = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    k = env > (env.max() * 10 ** (-30 / 20))
    return rms(x[k]) if k.any() else rms(x)


def pitch_shift(x, semis):
    """Varispeed (resample): pitch AND length move together - the 'different machine' shift."""
    ratio = 2 ** (semis / 12)                  # playback speed
    n_out = int(round(len(x) / ratio))
    return ss.resample(x, n_out, axis=0)


def ring_mod(x, hz):
    t = np.arange(len(x)) / SR
    return sos('bandpass', [300, 6000], x * np.sin(2 * np.pi * hz * t)[:, None])


def comb(x, hz, g=0.72):
    d = int(round(SR / hz))
    y = x.copy()
    for i in range(d, len(y), d):              # block-recursive feedback comb (exact for blocks of d)
        j = min(len(y), i + d)
        y[i:j] += g * y[i - d:j - d]
    return sos('bandpass', [hz * 0.8, 2400], y)


def crush(x, bits, hold_hz):
    hold = max(1, int(SR / hold_hz))
    held = x[(np.arange(len(x)) // hold) * hold]
    peak = np.abs(held).max() + 1e-12
    q = 2 ** (bits - 1)
    return np.round(held / peak * q) / q * peak


def tape_stop(x, start_s, dur_s, end_speed=0.15, curve=1.3):
    """From start_s, the playback speed sinks to end_speed over dur_s while it fades (then silence)."""
    i0 = int(start_s * SR)
    if i0 >= len(x):
        return x
    m = int(dur_s * SR)
    sp = 1.0 - (1.0 - end_speed) * (np.arange(m) / m) ** curve
    pos = i0 + np.cumsum(sp)
    pos = pos[pos < len(x) - 1]
    head = x[:i0]
    idx = np.floor(pos).astype(int); fr = (pos - idx)[:, None]
    seg = x[idx] * (1 - fr) + x[idx + 1] * fr
    fade = np.linspace(1, 0, len(seg)) ** 0.55
    seg = seg * fade[:, None]
    return np.concatenate([head, seg, np.zeros((int(0.05 * SR), x.shape[1]))])


def saw_voice(f_curve, cents):
    f = f_curve * 2 ** (cents / 1200)
    ph = np.cumsum(2 * np.pi * f / SR)
    out = np.zeros_like(f)
    for k in range(1, 48):
        live = (k * f) < 16000
        if not live.any():
            break
        out += np.where(live, np.sin(k * ph) / k, 0.0)
    return out * (2 / np.pi)


def svf_lowpass(x, fc_curve, q):
    y = np.zeros_like(x); low = band = 0.0; damp = 1.0 / q
    fs = 2 * np.sin(np.pi * np.clip(fc_curve, 20, SR / 6) / SR)
    for i in range(len(x)):
        f = fs[i]
        low += f * band
        high = x[i] - low - damp * band
        band += f * high
        y[i] = low
    return y


def fm_blip(freq, n, at, dur=0.07, index=2.2, ratio=2.0, decay=0.05):
    out = np.zeros(n); i0 = int(at * SR); m = int(min(n - i0, dur * SR * 4))
    if m <= 0:
        return out
    t = np.arange(m) / SR
    env = np.minimum(t / 0.003, 1.0) * np.exp(-np.maximum(t - 0.003, 0) / decay)
    mod = index * np.exp(-t / 0.04) * np.sin(2 * np.pi * freq * ratio * t)
    out[i0:i0 + m] = np.sin(2 * np.pi * freq * t + mod) * env
    return out


def envelope(x, ms=30.0):
    """0..1 RMS envelope (30 ms window) of a stereo or mono signal, 1 at its loudest moment."""
    m = x if x.ndim == 1 else np.abs(x).max(axis=1)
    k = max(1, int(SR * ms / 1000))
    e = np.sqrt(np.convolve(np.square(m), np.ones(k) / k, mode='same'))
    return e / (e.max() + 1e-12)


def stutters(x, times, grain_s=0.035, reps=4):
    out = np.zeros_like(x); g = int(grain_s * SR)
    for t0 in times:
        i0 = int(t0 * SR)
        if i0 + g >= len(x):
            continue
        grain = x[i0:i0 + g] * np.hanning(g)[:, None]
        for r in range(1, reps + 1):
            j = i0 + r * g
            if j + g > len(x):
                break
            out[j:j + g] += grain * (0.8 ** r)
    return out


def build(kind, x0):
    S = SPEC[kind]
    x, trimmed = trim_lead(x0)
    x = pitch_shift(x, S['semis'])
    x = sos('highpass', 28, x)
    n = len(x); t = np.arange(n) / SR
    body = S['body_end']
    # BOOT (ON) / DECAY (OFF): crossfade clean <-> crushed on a time envelope
    if kind == 'on':
        crushed = crush(x, 4, 6000)
        w = np.clip(1 - t / S['boot'], 0, 1) ** 1.3
    else:
        crushed = crush(x, S['decay_bits'], 7000)
        w = np.clip(t / body, 0, 1) ** 1.6 * 0.85
    spine = x * (1 - w[:, None]) + crushed * w[:, None]
    spine = 0.75 * spine + 0.25 * np.tanh(1.5 * spine) / 1.5
    ref = active_rms(spine)

    def at(level_db, sig):
        if not np.any(sig):
            return np.zeros((n, 2))
        if sig.ndim == 1:
            sig = np.stack([sig, sig], axis=1)
        sig = sig[:n] if len(sig) >= n else np.pad(sig, ((0, n - len(sig)), (0, 0)))
        return sig / active_rms(sig) * ref * 10 ** (level_db / 20)

    metal = ring_mod(x, S['ring_hz'])
    hum = comb(x, S['comb_hz'])
    grit = sos('highpass', 900, crush(sos('bandpass', [900, 7000], x), 6, 9000))
    f0, f1 = S['sweep']; c0, c1 = S['cutoff']
    k = np.clip(t / body, 0, 1)
    f_curve = f0 * (f1 / f0) ** k
    fc = c0 * (c1 / c0) ** k
    if kind == 'on':
        amp = np.clip(t / 0.18, 0, 1) * np.where(t > body, np.clip(1 - (t - body) / 0.15, 0, 1), 1.0)
    else:
        amp = np.clip(t / 0.04, 0, 1) * np.clip(1.2 - 0.6 * k, 0, 1) * np.where(t > body, np.clip(1 - (t - body) / 0.5, 0, 1), 1.0)
    # pass 3: the synth rides UNDER the recording - full only while the recording is near its peak, and it
    # falls away FASTER than the recording (squared), so it is done before the recording is (the first cut,
    # linear with a 0.4 s tail, still out-weighed the recording at 2.0 s in ON - recording_leads caught it)
    amp = amp * np.clip(envelope(spine) / 10 ** (SWEEP_FOLLOW_DB / 20), 0, 1) ** 2
    vl = svf_lowpass(saw_voice(f_curve, -9), fc, 4.0) * amp
    vr = svf_lowpass(saw_voice(f_curve, +9), fc, 4.0) * amp
    sweep = np.stack([0.85 * vl + 0.15 * vr, 0.15 * vl + 0.85 * vr], axis=1)
    sub = np.zeros(n)
    if S.get('sub'):
        m = int(0.42 * SR); tt = np.arange(m) / SR
        fs_ = 70 * (38 / 70) ** (tt / 0.42)
        sub[:m] = np.sin(np.cumsum(2 * np.pi * fs_ / SR)) * np.exp(-tt / 0.16) * np.minimum(tt / 0.004, 1)
    glitch = stutters(x, S.get('stutters', ()))
    blips = np.zeros(n)
    if kind == 'on':
        for i, f in enumerate((1567.98, 2093.0, 2637.0)):
            blips += fm_blip(f, n, 0.01 + 0.05 * i, dur=0.035, index=1.4, decay=0.018)
    else:
        for i, f in enumerate((2637.0, 1567.98)):
            blips += fm_blip(f, n, 0.01 + 0.06 * i, dur=0.035, index=1.4, decay=0.018)
    parts = {'recording': spine, 'metal': at(LEVEL_DB['metal'], metal), 'hum': at(LEVEL_DB['hum'], hum),
             'grit': at(LEVEL_DB['grit'], grit), 'sweep': at(LEVEL_DB['sweep'], sweep), 'sub': at(LEVEL_DB['sub'], sub),
             'glitch': at(LEVEL_DB['glitch'], glitch), 'blips': at(LEVEL_DB['blips'], blips)}

    def post(y):                                   # linear, so post(sum) == sum(post) - the check below relies on it
        if kind == 'off':
            y = tape_stop(y, body - S['tape_from'], S['tape_secs'], S['tape_end'], S['tape_curve'])
        return shelf_high(sos('highpass', 28, y), 5000, 2.0)

    mix = post(sum(parts.values()))
    gain = 0.7 / max(1e-9, np.abs(mix).max())
    return mix * gain, trimmed, {k_: post(v) * gain for k_, v in parts.items()}


EAR = ss.butter(2, [1000, 5000], btype='bandpass', fs=SR, output='sos')   # where the ear is most sensitive


def recording_leads(kind, parts, win_s=0.25, floor_db=-30.0):
    """The user's pass-2 rule ("this last second sound that takes over. I dont want that"): in every 250 ms
    window within 30 dB of the sting's loudest, the RECORDING carries the most ear-weighted energy - no
    added layer may take the sound over. Returns the per-window shares; raises if any window fails."""
    win = int(win_s * SR)
    n = len(parts['recording'])
    rows, loud = [], []
    for i0 in range(0, n, win):
        e = {k_: float(np.sum(ss.sosfilt(EAR, v[i0:i0 + win].mean(axis=1)) ** 2)) for k_, v in parts.items()}
        rows.append((i0 / SR, e)); loud.append(sum(e.values()))
    top = max(loud)
    bad = []
    for (t0, e), tot in zip(rows, loud):
        if tot < top * 10 ** (floor_db / 10):
            continue
        lead = max(e, key=e.get)
        if lead != 'recording':
            bad.append(f'{t0:.2f}s {lead} {100 * e[lead] / tot:.0f}% vs recording {100 * e["recording"] / tot:.0f}%')
    assert not bad, f'{kind}: an added layer takes the sound over -> ' + '; '.join(bad)
    return min(100 * e['recording'] / tot for (t0, e), tot in zip(rows, loud) if tot >= top * 10 ** (floor_db / 10))


def loudnorm(wav_in, wav_out):
    first = subprocess.run([str(FFMPEG), '-hide_banner', '-nostats', '-i', str(wav_in), '-af',
                            f'loudnorm=I={TARGET_LUFS}:TP={TARGET_TP}:LRA=11:print_format=json', '-f', 'null', '-'],
                           capture_output=True, text=True)
    meas = json.loads(re.search(r'\{[^{}]*"input_i"[^{}]*\}', first.stderr, re.S).group(0))
    af = (f"loudnorm=I={TARGET_LUFS}:TP={TARGET_TP}:LRA=11:linear=true:measured_I={meas['input_i']}"
          f":measured_TP={meas['input_tp']}:measured_LRA={meas['input_lra']}:measured_thresh={meas['input_thresh']}"
          f":offset={meas['target_offset']},aresample=48000")
    run = subprocess.run([str(FFMPEG), '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav_in), '-af', af,
                          '-ar', '48000', '-ac', '2', '-c:a', 'pcm_s16le', str(wav_out)], capture_output=True, text=True)
    assert run.returncode == 0, run.stderr
    check = subprocess.run([str(FFMPEG), '-hide_banner', '-nostats', '-i', str(wav_out), '-af', 'ebur128=peak=true',
                            '-f', 'null', '-'], capture_output=True, text=True).stderr
    return float(re.findall(r'I:\s+(-?[\d.]+) LUFS', check)[-1]), float(re.findall(r'Peak:\s+(-?[\d.]+) dBFS', check)[-1])


def check(root=ROOT):
    """Build gate (--check, every build incl. -GscOnly): the stings the game plays are THIS tool's output and
    the switch is wired to them. Catches: a hand-edited / stale WAV (sha != manifest), a re-pointed alias row
    (pass 1 shipped tod_rampage_on's FileSpec on the HOOP sting through a mangled backslash), the switch not
    playing both aliases, and the stock purchase cha-ching back on the flip (user, 2026-10-02: "Remove the
    cha ching")."""
    root = Path(root); errs = []
    man_p = root/'art/rampage_sfx/manifest.json'
    man = json.loads(man_p.read_text()) if man_p.exists() else {}
    if man.get('rev') != REV:
        errs.append(f'manifest rev {man.get("rev")!r} != the tool\'s {REV!r} - re-run build_rampage_sfx.py')
    outs = man.get('outputs', {})
    for kind in ('on', 'off'):
        o = outs.get(kind, {})
        src = root/f'art/rampage_sfx/source/rampage_{kind}_src.wav'; wav = root/f'sound_assets/tod/sfx/tod_rampage_{kind}.wav'
        if not wav.exists():
            errs.append(f'{wav.name} missing')
        elif sha(wav) != o.get('sha256'):
            errs.append(f'{wav.name} is not the tool\'s output (sha != manifest) - re-run build_rampage_sfx.py, never hand-edit it')
        if not src.exists() or sha(src) != o.get('source_sha256'):
            errs.append(f'source {src.name} missing or changed since the manifest was written')
    rows = {}
    for line in (root/'sound/aliases/tod_ui.csv').read_text(encoding='utf-8').splitlines():
        cols = line.split(',')
        if cols and cols[0].startswith('tod_rampage_o'):
            rows[cols[0]] = cols
    for kind in ('on', 'off'):
        name = f'tod_rampage_{kind}'; want = f'tod\\sfx\\tod_rampage_{kind}.wav'
        if name not in rows:
            errs.append(f'alias {name} missing from sound/aliases/tod_ui.csv')
        elif len(rows[name]) < 4 or rows[name][3] != want:
            errs.append(f'alias {name} plays {rows[name][3] if len(rows[name]) > 3 else "?"!r}, want {want!r}')
    gsc = (root/'scripts/zm/zm_tower_of_doom/_tod_rampage.gsc').read_text(encoding='utf-8')
    code = re.sub(r'//[^\n]*', '', re.sub(r'/\*.*?\*/', '', gsc, flags=re.S))
    # what PlaySound can actually play: literals written in its argument, plus every literal assigned to a
    # bare variable that IS its argument (the switch picks `sting_alias` with an if/else - an unwrapped ternary
    # in the call failed the whole file, 2026-10-02 16:51). A literal assigned to a variable PlaySound never
    # receives does not count.
    played = set()
    for arg in re.findall(r'PlaySound\s*\((.*?)\)\s*;', code, flags=re.S):
        played.update(re.findall(r'"([^"]+)"', arg))
        var = arg.strip()
        if re.fullmatch(r'[A-Za-z_]\w*', var):
            played.update(re.findall(r'\b' + var + r'\s*=\s*"([^"]+)"\s*;', code))
    for kind in ('on', 'off'):
        if f'tod_rampage_{kind}' not in played:
            errs.append(f'_tod_rampage.gsc never plays "tod_rampage_{kind}"')
    if 'zmb_cha_ching' in code:
        errs.append('_tod_rampage.gsc plays the stock purchase cha-ching again - the user removed it from the switch')
    for e in errs:
        print('RAMPAGE_SFX CHECK FAIL:', e)
    if not errs:
        print(f'RAMPAGE_SFX CHECK OK: rev {REV}, both stings == manifest, both aliases -> their own wav, '
              f'the switch plays both, no cha-ching')
    return not errs


def main():
    import sys
    if '--check' in sys.argv:
        i = sys.argv.index('--check')
        root = sys.argv[i + 1] if len(sys.argv) > i + 1 and not sys.argv[i + 1].startswith('--') else ROOT
        sys.exit(0 if check(root) else 1)
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'rev': REV, 'target_lufs': TARGET_LUFS, 'target_tp': TARGET_TP, 'spec': SPEC, 'levels_db': LEVEL_DB, 'outputs': {}}
    for kind in ('on', 'off'):
        src = SRC/f'rampage_{kind}_src.wav'
        mix, trimmed, parts = build(kind, load(src))
        rec_min = recording_leads(kind, parts)
        with tempfile.TemporaryDirectory() as td:
            raw = Path(td)/f'{kind}_raw.wav'
            sf.write(str(raw), mix.astype(np.float32), SR, subtype='FLOAT')
            out = OUT/f'tod_rampage_{kind}.wav'
            i_lufs, peak = loudnorm(raw, out)
        info = sf.info(str(out))
        assert info.samplerate == SR and info.channels == 2 and info.subtype == 'PCM_16'
        assert abs(i_lufs - TARGET_LUFS) < 1.0 and peak <= -0.5, (kind, i_lufs, peak)
        report['outputs'][kind] = {'source': str(src.relative_to(ROOT)), 'source_sha256': sha(src),
                                   'wav': str(out.relative_to(ROOT)), 'sha256': sha(out),
                                   'seconds': round(info.duration, 3), 'lead_trimmed_s': round(trimmed, 3),
                                   'lufs': i_lufs, 'peak_dbfs': peak, 'recording_min_share_pct': round(rec_min, 1)}
        print(f'RAMPAGE_SFX {REV} {kind}: {info.duration:.2f} s, {i_lufs:.1f} LUFS, peak {peak:.1f} dBFS, '
              f'recording leads every window (min share {rec_min:.0f}%) -> {out.relative_to(ROOT)}')
    MANIFEST.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
