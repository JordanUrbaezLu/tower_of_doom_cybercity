"""Regenerate constant native wing textures in sRGB, preserving linear artist color."""
import bpy,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];IMG=ROOT/'model_export/tod_heavenly_altar/_images';STAGE=ROOT/'art/heavenly_altar/engine_kit'
encode=lambda v:12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055
for suffix,color in [('c',(.02,.35,1,.36)),('e',(.02,.35,1,1))]:
    name='i_tod_altar_wings_'+suffix;im=bpy.data.images.new(name,width=32,height=32,alpha=True)
    im.colorspace_settings.name='sRGB';im.generated_color=(*(encode(v) for v in color[:3]),color[3]);im.filepath_raw=str(IMG/(name+'.png'));im.file_format='PNG';im.save()
path=STAGE/'source_manifest.json';m=json.loads(path.read_text());m['wing_color_space']='linear authoring color encoded to sRGB PNG'
m['textures']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in IMG.glob('*.png')};path.write_text(json.dumps(m,indent=2)+'\n')
print('ALTAR_WING_COLOR_FIXED')
