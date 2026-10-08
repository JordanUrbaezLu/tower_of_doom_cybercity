"""Apply the dedicated raster surface maps to the actual meshes through MCP."""
import sys, importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *
textures={}
for material,filename,scale,gain in [(steel,'worn_steel_v1.png',.125,.76),(edge,'worn_steel_v1.png',.16,1.35),(ivory,'chipped_enamel_v1.png',.125,.92)]:
    ns=material.node_tree.nodes;ls=material.node_tree.links;bs=ns.get('Principled BSDF')
    for node in list(ns):
        if node.name.startswith('Surface map |'):ns.remove(node)
    image=bpy.data.images.load(str(OUT/'textures'/filename),check_existing=True);image.colorspace_settings.name='sRGB';image.pack()
    tex=ns.new('ShaderNodeTexImage');tex.name='Surface map | detailed albedo';tex.image=image;tex.projection='BOX';tex.projection_blend=.18;tex.extension='REPEAT'
    coord=ns.new('ShaderNodeTexCoord');coord.name='Surface map | fixed object coordinates'
    mapping=ns.new('ShaderNodeVectorMath');mapping.name='Surface map | physical grain scale';mapping.operation='SCALE';mapping.inputs['Scale'].default_value=scale
    ls.new(coord.outputs['Object'],mapping.inputs[0]);ls.new(mapping.outputs[0],tex.inputs['Vector'])
    multiply=ns.new('ShaderNodeMixRGB');multiply.name='Surface map | exposure calibration';multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1;multiply.inputs[2].default_value=(gain,gain,gain,1)
    ls.new(tex.outputs['Color'],multiply.inputs[1]);ls.new(multiply.outputs[0],bs.inputs['Base Color'])
    bw=ns.new('ShaderNodeRGBToBW');bw.name='Surface map | fine paint and scratch relief';ls.new(tex.outputs['Color'],bw.inputs[0])
    bump=ns.new('ShaderNodeBump');bump.name='Surface map | detailed abrasion normal';bump.inputs['Strength'].default_value=.23;bump.inputs['Distance'].default_value=.012
    ls.new(bw.outputs[0],bump.inputs['Height'])
    old=ns.get('Paint edge and forging relief')
    if old:ls.new(old.outputs[0],bump.inputs['Normal'])
    ls.new(bump.outputs[0],bs.inputs['Normal'])
    rough=ns.new('ShaderNodeMapRange');rough.name='Surface map | oily wear roughness';rough.inputs['From Min'].default_value=0;rough.inputs['From Max'].default_value=.6;rough.inputs['To Min'].default_value=.42;rough.inputs['To Max'].default_value=.79
    ls.new(bw.outputs[0],rough.inputs['Value']);ls.new(rough.outputs[0],bs.inputs['Roughness'])
    if material==ivory:
        metal=ns.new('ShaderNodeMapRange');metal.name='Surface map | exposed iron';metal.inputs['From Min'].default_value=.045;metal.inputs['From Max'].default_value=.22;metal.inputs['To Min'].default_value=.70;metal.inputs['To Max'].default_value=.04
        ls.new(bw.outputs[0],metal.inputs['Value']);ls.new(metal.outputs[0],bs.inputs['Metallic'])
    material['texture_source']=filename
    textures[filename]={'pixels':list(image.size),'sha256':hashlib.sha256((OUT/'textures'/filename).read_bytes()).hexdigest()}
assert json.loads(scene['donor_signatures'])=={o.name:signature(o) for o in base}
report=json.loads((OUT/'validation.json').read_text());report['surface_textures']=textures;report['texture_generation']='built-in image_gen; prompts in textures/prompts.json'
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
scene['reference_one_texture_pass']=1
camera((26,-86,63),(8,-5,51),35)
save('08_dedicated_surface_textures')
print('SOURCE_TEXTURES_EMBEDDED',json.dumps(textures))
