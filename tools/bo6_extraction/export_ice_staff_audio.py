"""Export exact bank-referenced staff sounds through the guarded Saluki session.

Adapted from Tower II's export_ledger_audio.py. Every export first requires
local OCR to identify exactly one loaded row with the requested hash. Unknown
or unreadable rows stop input. Existing WAVs are validated without re-export.
This acquires source audio; it does not claim event mapping or native playback.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

from inventory_ice_staff import inspect_wav

REPO = Path(__file__).resolve().parents[2]
ROOT = Path.home()/'Downloads/BO6_Pilot_Export/bo6'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    plan=json.loads((REPO/'docs/bo6_ports/manifests/ice_staff_sources.json').read_text(encoding='utf-8'))
    banks={}
    for name,sha in plan['bank_sha256'].items():
        assert Path(name).name==name,name
        path=ROOT/'sndbanks/json'/name
        assert hashlib.sha256(path.read_bytes()).hexdigest()==sha,name
        banks[name]=json.loads(path.read_text(encoding='utf-8-sig'))
    sounds={}
    for sound,entry in plan['sounds'].items():
        assert re.fullmatch(r'[a-zA-Z0-9_./-]+', sound) and '..' not in Path(sound).parts and not Path(sound).is_absolute(), sound
        assert all(any(row['snd']==sound for row in banks[name]) for name in entry['source_banks']),sound
        sounds[sound]=set(entry['source_banks'])

    def powershell(script, *arguments):
        result = subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(REPO/'tools/bo6_extraction'/script),*map(str,arguments)],capture_output=True,text=True,timeout=50)
        assert result.returncode == 0, (result.stdout,result.stderr)
        return json.loads(result.stdout)

    def request(action, *arguments):
        receipt = powershell('saluki_request.ps1','-SessionDir',args.session,'-Task','tod_bo6_ice_staff','-Action',action,*arguments)
        assert receipt['ok'], receipt
        return receipt

    report = dict(checked=datetime.datetime.now().astimezone().isoformat(),session=str(args.session),expected=len(sounds),complete=False,sounds=[],unavailable=[])

    def save():
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(report,indent=2)+'\n')

    for sound,banks in sorted(sounds.items()):
        path = ROOT/'sounds'/(sound+'.wav')
        proof = None
        if not path.is_file():
            if not re.fullmatch(r'sound_[0-9a-f]+',sound):
                report['unavailable'].append(dict(sound=sound,reason='Named asset missing; explicit identifier resolution needed'))
                save()
                continue
            matched = False
            for search_attempt in range(3):
                # A WAV can finish writing before Saluki re-enables its UI.
                # Retry only the same search, never an unverified export.
                time.sleep(1)
                request('click','-X',496,'-Y',130)
                request('click','-X',190,'-Y',130)
                proof = request('text','-Text','kind:sound '+sound)
                ocr = powershell('read_capture_text.ps1','-Path',proof['screenshot'])
                # OCR read the observed hexadecimal '11' as 'Il'. These
                # letters cannot occur in hex; normalize only those glyphs.
                visible = []
                for line in ocr['lines']:
                    match = re.fullmatch(r'sound[\s_]+([0-9a-fA-FIlOo\s]+)',line)
                    if match:
                        token = re.sub(r'\s+','',match[1]).translate(str.maketrans({'I':'1','l':'1','O':'0','o':'0'})).lower()
                        visible.append('sound_'+token)
                matched = bool(re.search(r'Showing\s+1\s+assets\s+out\s+of',ocr['text'],re.I)) and visible == [sound]
                if matched: break
            if not matched:
                report['stopped_before_export'] = dict(sound=sound,screenshot=proof['screenshot'],ocr=ocr)
                save()
                raise RuntimeError('Exact single-row OCR check failed; no export click: '+sound)
            for attempt in range(2):
                request('click','-X',495,'-Y',758)
                deadline = time.monotonic()+(4 if attempt == 0 else 15)
                while not path.is_file() and time.monotonic()<deadline: time.sleep(.2)
                if path.is_file(): break
                request('capture')
            assert path.is_file(), 'Expected WAV absent; stopping: '+str(path)
            time.sleep(.3)
        item = dict(sound=sound,banks=sorted(banks),source=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),validation=inspect_wav(path))
        if proof: item['ui_proof'] = proof['screenshot']
        report['sounds'].append(item)
        save()
        print('Validated '+str(len(report['sounds']))+'/'+str(len(sounds))+': '+sound,flush=True)
    report['complete'] = len(report['sounds']) == len(sounds) and not report['unavailable']
    save()


if __name__ == '__main__':
    main()
