"""Stage the complete staff's base material streams and original glow textures.

No runtime shader is installed. Original albedo and emission-color bytes are
retained; NOG is decoded with the reviewed Tower II convention. Additional
layers, shader constants, transparency and native appearance remain open.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

REPO=Path(__file__).resolve().parents[2]
ASSEMBLY=REPO/'local_sync_cache/bo6_ice_staff/staging/assembly'
EXPECTED={'material_18911d6f7aeac1d9':(2048,2048),
          'material_7816470a495eb7d0':(2048,2048),
          'material_265e6ebadb703c9':(2048,2048),
          'material_368354ed1784cc03':(1024,1024),
          'material_5ef8c6c509565385':(2048,2048),
          'material_185cf03e0a997c76':(2048,2048)}
EMISSION={'material_7816470a495eb7d0','material_265e6ebadb703c9',
          'material_5ef8c6c509565385','material_185cf03e0a997c76'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-packages',type=Path)
    args=parser.parse_args()
    if args.python_packages:sys.path.insert(0,str(args.python_packages))
    import numpy as np
    from PIL import Image
    source=json.loads((ASSEMBLY/'vm_geometry.json').read_text())
    assert set(source['materials'])==set(EXPECTED)
    out=ASSEMBLY/'_images';out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for name,values in source['materials'].items():
        slots={k:Path(v) for k,v in values.items()}
        assert all(p.is_file() for p in slots.values()),name
        prefix='i_tod_bo6_ice_'+name.removeprefix('material_')
        with Image.open(slots['albedo']) as im:
            assert im.size==EXPECTED[name] and im.mode=='RGBA',name
        with Image.open(slots['extra9']) as im:
            assert im.mode=='RGBA'
            data=np.array(im,dtype=np.uint8)
            if name=='material_368354ed1784cc03':
                assert im.size==(1,1) and im.getpixel((0,0))==(179,128,255,128)
            else:
                assert im.size==EXPECTED[name]
                assert np.ptp(data[:,:,1])>16 and np.ptp(data[:,:,3])>16
        files={}
        for slot,suffix,field in [('albedo','c','colorMap')]+([('extra10','e','sourceEmissionColor')] if name in EMISSION else []):
            target=out/(prefix+'_'+suffix+'.png')
            shutil.copyfile(slots[slot],target)
            assert digest(target)==digest(slots[slot])
            files[field]=target
        x=data[:,:,3].astype(np.float32)/127.5-1
        y=data[:,:,1].astype(np.float32)/127.5-1
        z=np.sqrt(np.maximum(0,1-x*x-y*y))
        length=np.sqrt(x*x+y*y+z*z)
        normal=np.rint((np.stack((x/length,y/length,z/length),axis=-1)*.5+.5)*255).clip(0,255).astype(np.uint8)
        for pixels,suffix,field in ((normal,'n','normalMap'),(data[:,:,0],'g','cosinePowerMap'),(data[:,:,2],'o','occMap')):
            im=Image.fromarray(pixels)
            if im.width<4 or im.height<4:
                assert im.size==(1,1)
                im=im.resize((4,4),Image.Resampling.NEAREST)
            target=out/(prefix+'_'+suffix+'.png');im.save(target)
            with Image.open(target) as check:assert np.array_equal(np.array(im),np.array(check))
            files[field]=target
        rows.append(dict(material=name,source_resolution=EXPECTED[name],source_slots={k:dict(path=str(v),sha256=digest(v)) for k,v in slots.items()},outputs={k:dict(path=str(v.relative_to(REPO)),sha256=digest(v)) for k,v in files.items()},unresolved='Material constants, alpha/metal/specular, layered masks, scrolling/distortion and native emission intensity remain unverified.'))
    report=dict(scope='Isolated base-stream conversion; no GDT/shader installation or parity claim',decode='normal XY=A/G; gloss=R; AO=B; positive normal Z reconstructed',color_bytes_unchanged=True,emission_color_bytes_unchanged=True,native_verified=False,materials=rows)
    (ASSEMBLY/'materials.json').write_text(json.dumps(report,indent=2)+'\n')
    print('STAGED: 6 original color maps, 18 decoded base streams, 4 original emission-color maps; no native shader claim')


if __name__=='__main__':main()
