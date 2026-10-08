#!/usr/bin/env python3
"""Pair the server's [TOD_BAT] LAUNCH / [TOD_HOOP] ARC lines with the client's [TOD_HOOP_C] FLIGHT
lines per entity in a console_mp.log and derive TOD_HOOP_ARC_K (docs/147 section Calibration).

  python tools/hoop_calibrate.py <console_mp.log> [--g 800] [--lift 32]

Per launch:  K_z = sqrt(2 g (apex - z0 - lift)) / iz      (vertical, the box is a height)
             K_h = sqrt(R g / (2 iz |ixy|))               (horizontal cross-check, clean flights only)
and the ARC result the server computed against the client's in_box, so a K change can be judged
before a build: with K' the recomputed arc from the logged impulse lands where the client saw it.
"""
import re, sys, math, statistics

V = r'\(\s*([-\d.e]+),\s*([-\d.e]+),\s*([-\d.e]+)\s*\)'
LAUNCH = re.compile(r'\[TOD_BAT\] ms=(\d+) LAUNCH ent=(\d+) .*?impulse=' + V)
ARC = re.compile(r'\[TOD_HOOP\] ms=(\d+) ARC ent=(\d+) from=' + V + r' impulse=' + V + r' (?:k=[-\d.]+|kh=[-\d.]+ kz=[-\d.]+)(?: v=' + V + r')? result=(\w+) t=([-\d.]+) apex=([-\d.]+) end=' + V + r' hit=(\S+)')
FLIGHT = re.compile(r'\[TOD_HOOP_C\] FLIGHT ent=(\d+) from=' + V + r' apex=([-\d.]+) land=' + V + r' dist=([-\d.]+) in_box=(\d)')

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(2)
    g = float(args[args.index('--g') + 1]) if '--g' in args else 800.0
    lift = float(args[args.index('--lift') + 1]) if '--lift' in args else 32.0
    text = open(args[0], encoding='utf-8', errors='replace').read().splitlines()
    launches, arcs, flights = [], [], []
    for ln in text:
        m = LAUNCH.search(ln)
        if m: launches.append((int(m[1]), int(m[2]), tuple(map(float, m.group(3, 4, 5))))); continue
        m = ARC.search(ln)
        if m: arcs.append((int(m[1]), int(m[2]), m[12], float(m[14]), m.group(15, 16, 17), m[18])); continue
        m = FLIGHT.search(ln)
        if m: flights.append((int(m[1]), tuple(map(float, m.group(2, 3, 4))), float(m[5]), tuple(map(float, m.group(6, 7, 8))), float(m[9]), int(m[10])))
    print(f'launches {len(launches)}  arcs {len(arcs)}  flights {len(flights)}')
    # pair: a FLIGHT for ent N belongs to the most recent LAUNCH of ent N before it (flights are printed 3 s after)
    kz, kh, rows = [], [], []
    li = 0
    fl_by_order = flights
    used = set()
    for ent, f0, apex, land, dist, inbox in fl_by_order:
        cand = [i for i, (ms, e, imp) in enumerate(launches) if e == ent and i not in used]
        if not cand: continue
        i = cand[0]; used.add(i)
        ms, _, (ix, iy, iz) = launches[i]
        arc = next((a for a in arcs if a[1] == ent and abs(a[0] - ms) < 4000), None)
        rise = apex - f0[2] - lift
        k_z = math.sqrt(2 * g * rise) / iz if rise > 0 and iz > 0 else float('nan')
        ixy = math.hypot(ix, iy)
        k_h = math.sqrt(dist * g / (2 * iz * ixy)) if iz > 0 and ixy > 0 and dist > 0 else float('nan')
        if not math.isnan(k_z): kz.append(k_z)
        if not math.isnan(k_h): kh.append(k_h)
        rows.append((ent, ms, iz, ixy, apex, dist, inbox, arc[2] if arc else '-', arc[3] if arc else float('nan'), k_z, k_h))
    print(f'{"ent":>4} {"ms":>7} {"iz":>7} {"ixy":>7} {"apex":>7} {"dist":>6} {"in":>2} {"ARC":>7} {"arcApex":>7} {"K_z":>6} {"K_h":>6}')
    for r in rows:
        print(f'{r[0]:>4} {r[1]:>7} {r[2]:>7.1f} {r[3]:>7.1f} {r[4]:>7.1f} {r[5]:>6.0f} {r[6]:>2} {r[7]:>7} {r[8]:>7.1f} {r[9]:>6.2f} {r[10]:>6.2f}')
    if kz: print(f'K_z median {statistics.median(kz):.3f}  mean {statistics.mean(kz):.3f}  n {len(kz)}')
    if kh: print(f'K_h median {statistics.median(kh):.3f}  mean {statistics.mean(kh):.3f}  n {len(kh)}')
    agree = sum(1 for r in rows if r[7] != '-' and ((r[7] == 'basket') == (r[6] == 1)))
    known = sum(1 for r in rows if r[7] != '-')
    print(f'server ARC agrees with the client on {agree}/{known} paired flights; client baskets {sum(r[6] for r in rows)}, server baskets {sum(1 for r in rows if r[7] == "basket")}')

if __name__ == '__main__':
    main()
