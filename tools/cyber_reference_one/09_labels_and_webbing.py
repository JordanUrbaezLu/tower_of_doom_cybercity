"""Final close-up fixes: readable manufacturer stamps and less smooth harness cloth."""
import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *
tokens=('stencil','telemetry','serial stamp','identification','service legend','safety label','service hatch number','machine serial','receiver number','worn warning')
fixed=[]
for ob in scene.objects:
    if ob.type=='MESH' and 'attachment_bone' in ob and any(s in ob.name for s in tokens) and not ob.get('label_basis_correct'):
        # Legacy font orientation was reflected by a left-handed basis. Mirror in
        # its own font plane, then repair winding; preserve position and weights.
        for v in ob.data.vertices:v.co.x=-v.co.x
        bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
        ob['label_basis_correct']=True;fixed.append(ob.name)
ns=web.node_tree.nodes;ls=web.node_tree.links;bs=ns.get('Principled BSDF')
for node in list(ns):
    if node.name.startswith('Cloth finish |'):ns.remove(node)
source=bs.inputs['Base Color'].links[0].from_socket
tex=ns.new('ShaderNodeTexImage');tex.name='Cloth finish | dirt pattern';tex.image=bpy.data.images.get('worn_steel_v1.png');tex.projection='BOX';tex.projection_blend=.2
coord=ns.new('ShaderNodeTexCoord');coord.name='Cloth finish | object coordinates'
scale=ns.new('ShaderNodeVectorMath');scale.name='Cloth finish | stain scale';scale.operation='SCALE';scale.inputs['Scale'].default_value=.20;ls.new(coord.outputs['Object'],scale.inputs[0]);ls.new(scale.outputs[0],tex.inputs['Vector'])
bw=ns.new('ShaderNodeRGBToBW');bw.name='Cloth finish | mottled staining';ls.new(tex.outputs[0],bw.inputs[0])
ramp=ns.new('ShaderNodeValToRGB');ramp.name='Cloth finish | charcoal canvas';ramp.color_ramp.elements[0].color=(.19,.19,.19,1);ramp.color_ramp.elements[1].color=(.72,.72,.72,1);ramp.color_ramp.elements[1].position=.3;ls.new(bw.outputs[0],ramp.inputs[0])
mix=ns.new('ShaderNodeMixRGB');mix.name='Cloth finish | embedded grease';mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;ls.new(source,mix.inputs[1]);ls.new(ramp.outputs[0],mix.inputs[2]);ls.new(mix.outputs[0],bs.inputs['Base Color'])
for link in list(bs.inputs['Roughness'].links):ls.remove(link)
bs.inputs['Roughness'].default_value=.91;bs.inputs['Metallic'].default_value=0;bs.inputs['Sheen Weight'].default_value=.16
assert json.loads(scene['donor_signatures'])=={o.name:signature(o) for o in base}
report=json.loads((OUT/'validation.json').read_text());report['label_orientation_corrected']=len(fixed);report['surface_finish']='Dedicated raster enamel/steel and matte stained canvas; original zombie textures retained'
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
save('09_final_textured_master')
print('READABLE_STAMPS',len(fixed))
