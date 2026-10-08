"""Blender: bake a known gradient to detect lost shader links/emission ratios."""
import bpy, sys, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from cyber_material_bake import wire_channel, EMISSION_SCALE
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=1
sc.render.threads_mode='FIXED';sc.render.threads=2;sc.render.bake.margin=0
bpy.ops.mesh.primitive_plane_add(size=1,location=(.5,.5,0))
ob=bpy.context.object
m=bpy.data.materials.new('Known linked gradient');m.use_nodes=True;ob.data.materials.append(m)
ns=m.node_tree.nodes;links=m.node_tree.links;bs=ns.get('Principled BSDF')
geo=ns.new('ShaderNodeNewGeometry');sep=ns.new('ShaderNodeSeparateXYZ');links.new(geo.outputs['Position'],sep.inputs[0])
for name in ('Base Color','Metallic','Roughness'):links.new(sep.outputs['X'],bs.inputs[name])
bs.inputs['Emission Color'].default_value=(.2,.6,1,1)
bs.inputs['Emission Strength'].default_value=1.8
results={}
for channel in ('c','s','g','e'):
    wire_channel(m,channel)
    im=bpy.data.images.new('test_'+channel,width=32,height=32,float_buffer=True)
    im.colorspace_settings.name='Non-Color'
    target=ns.new('ShaderNodeTexImage');target.image=im;ns.active=target
    bpy.ops.object.bake(type='EMIT');pixels=list(im.pixels)
    samples=[]
    for x in (7,23):
        actual=pixels[(16*32+x)*4:(16*32+x)*4+3];v=(x+.5)/32
        expected={'c':[v]*3,'s':[.04*(1-v)+v*v]*3,'g':[1-v]*3,'e':[z*1.8/EMISSION_SCALE for z in (.2,.6,1)]}[channel]
        assert max(abs(a-b) for a,b in zip(actual,expected))<.002,(channel,actual,expected)
        samples.append({'actual':actual,'expected':expected})
    results[channel]=samples
(ROOT/'tmp/cyber_material_bake_test.json').write_text(json.dumps(results,indent=2)+'\n')
print('CYBER_MATERIAL_BAKE_TEST_OK: linked color, metallic/specular, roughness/gloss and emission strength survive actual Cycles bakes.')
