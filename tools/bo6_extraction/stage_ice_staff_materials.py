"""Stage reviewed staff-body color and packed NOG streams at source resolution.

The decode follows Tower of Doom II's build_material_streams.py and its MDS
Shader 1.8.3 node audit: normal XY=(A,G), gloss=R, AO=B. Source slots are
preserved and every unresolved layer remains in the report. No GDT or gameplay
binding is written until the complete staff assembly is available.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys

REPO = Path(__file__).resolve().parents[2]
SOURCE = Path.home()/'Downloads/BO6_Pilot_Export/bo6/models/wpn_t10_wm_ww_zmb_staffs_nocol/wpn_t10_wm_ww_zmb_staffs_nocol_LOD0.cast'
OUT = REPO/'local_sync_cache/bo6_ice_staff/staging/body/_images'
REVIEWED = {'material_5cca21b19874c8d9':(2048,2048),
            'material_6394a6b54d0b53ec':(2048,2048),
            'material_181e47b523024669':(2048,2048),
            'material_3587ccc715838fe3':(1024,1024)}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-packages',type=Path,
                        help='Optional isolated Pillow/numpy installation')
    args=parser.parse_args()
    if args.python_packages:
        sys.path.insert(0,str(args.python_packages))
    from PIL import Image
    import numpy as np
    reader=Path(os.environ['APPDATA'])/'Blender Foundation/Blender/4.2/scripts/addons/io_scene_cast/cast.py'
    spec=importlib.util.spec_from_file_location('staff_cast_reader',reader)
    cast=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cast)
    materials=[m for root in cast.Cast.load(str(SOURCE)).Roots()
               for model in root.ChildrenOfType(cast.Model) for m in model.Materials()]
    assert {m.Name() for m in materials} == set(REVIEWED)
    tasks=[]
    # Read and validate all inputs before writing any staged output.
    for m in materials:
        slots={key:SOURCE.parent/node.Path() for key,node in m.Slots().items() if isinstance(node,cast.File)}
        assert all(path.is_file() for path in slots.values()),m.Name()
        with Image.open(slots['albedo']) as im:
            assert im.size == REVIEWED[m.Name()] and im.mode=='RGBA',m.Name()
        with Image.open(slots['extra9']) as im:
            assert im.mode=='RGBA'
            data=np.array(im,dtype=np.uint8)
            if m.Name()=='material_3587ccc715838fe3':
                # Source uniform gloss 179, flat normal and white AO are real
                # authored values for this small hose material, not substitutes.
                assert im.size==(1,1) and im.getpixel((0,0))==(179,128,255,128)
            else:
                assert im.size==REVIEWED[m.Name()]
                assert np.ptp(data[:,:,1])>16 and np.ptp(data[:,:,3])>16
        tasks.append((m.Name(),slots,data))
    OUT.mkdir(parents=True,exist_ok=True)
    result=[]
    for material,slots,data in tasks:
        prefix='i_tod_bo6_ice_'+material.removeprefix('material_')
        color=OUT/(prefix+'_c.png')
        shutil.copyfile(slots['albedo'],color)
        assert digest(color)==digest(slots['albedo'])
        x=data[:,:,3].astype(np.float32)/127.5-1
        y=data[:,:,1].astype(np.float32)/127.5-1
        z=np.sqrt(np.maximum(0,1-x*x-y*y))
        length=np.sqrt(x*x+y*y+z*z)
        normal=np.rint((np.stack((x/length,y/length,z/length),axis=-1)*.5+.5)*255).clip(0,255).astype(np.uint8)
        outputs={'colorMap':color}
        for pixels,suffix,field in ((normal,'n','normalMap'),(data[:,:,0],'g','cosinePowerMap'),(data[:,:,2],'o','occMap')):
            im=Image.fromarray(pixels)
            if im.width<4 or im.height<4:
                assert im.size==(1,1)
                im=im.resize((4,4),Image.Resampling.NEAREST)
            target=OUT/(prefix+'_'+suffix+'.png')
            im.save(target)
            with Image.open(target) as check:
                expected=np.array(im)
                assert np.array_equal(np.array(check),expected),target
            outputs[field]=target
        # Quantization validation: normal XY must reproduce the source away
        # from the normalized tangent-horizon outliers, and G/O must be exact.
        mask=x*x+y*y<=1
        assert np.max(np.abs(normal[:,:,0][mask].astype(int)-data[:,:,3][mask].astype(int)))==0
        assert np.max(np.abs(normal[:,:,1][mask].astype(int)-data[:,:,1][mask].astype(int)))==0
        result.append(dict(material=material,source_resolution=list(REVIEWED[material]),
            source_slots={s:dict(path=str(p),sha256=digest(p)) for s,p in slots.items()},
            suggested_fields={field:p.stem for field,p in outputs.items()},
            output_files=[dict(path=str(p),sha256=digest(p)) for p in outputs.values()],
            unresolved_slots=[s for s in slots if s not in ('albedo','extra9')],
            unresolved=['Albedo alpha and metal/specular interpretation','Layer masks, emission and state transitions','Native material comparison']))
    report=dict(stage='body_base_material_streams',source=str(SOURCE),source_sha256=digest(SOURCE),
                decode='normal=(A,G,reconstructed positive Z); gloss=R; AO=B; linear DirectX data',
                deployed=False,native_verified=False,full_shader_parity=False,materials=result)
    (OUT.parent/'materials.json').write_text(json.dumps(report,indent=2)+'\n')
    print('STAGED: 4 original color maps and 12 decoded surface maps; layered shader and native review remain open')


if __name__=='__main__':
    main()
