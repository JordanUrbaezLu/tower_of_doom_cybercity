import sys,importlib,ast
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
D.group='14 Inner crystal clusters'
crystal=bpy.data.materials[PREFIX+'faceted energized crystal']
source=ast.parse((Path(__file__).parent/'03_crystals_wings.py').read_text())
function=next(n for n in source.body if isinstance(n,ast.FunctionDef) and n.name=='crystal_shard')
exec(compile(ast.Module(body=[function],type_ignores=[]),'<crystal primitive>','exec'),globals())
for s in (-1,1):
    for x,z,height in [(12.6,30,12),(25,66,10),(26,93,8)]:
        for j in range(3):
            crystal_shard('Inner portal | fitted crystal spire',s*(x+(j-1)*.75),-17.3+(j%2)*.5,z,.45 if j!=1 else .65,height*(1 if j==1 else .68),j)
        box('Inner portal | crystal socket',(s*x,-16.7,z+.5),(3.4,2.7,1.2),gold,.15)
D.group='15 Refined holographic surfaces'
field=bpy.data.materials[PREFIX+'celestial blue optical field'];nodes=field.node_tree.nodes
ramp=next(n for n in nodes if n.type=='VALTORGB');ramp.color_ramp.elements[0].color=(.003,.009,.025,1);ramp.color_ramp.elements[1].color=(.007,.043,.09,1)
next(n for n in nodes if n.type=='TEX_NOISE').inputs['Scale'].default_value=65
nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.3
for ob in list(scene.objects):
    if ob.name.startswith('Crest | fine optical data path'):bpy.data.objects.remove(ob,do_unlink=True)
mat=bpy.data.materials[PREFIX+'reference heavenly portal artwork'];n,l=mat.node_tree.nodes,mat.node_tree.links
tex=next(n for n in n if n.type=='TEX_IMAGE');em=next(n for n in n if n.type=='EMISSION')
bw=n.new('ShaderNodeRGBToBW');l.new(tex.outputs['Color'],bw.inputs[0]);mapping=n.new('ShaderNodeMapRange');mapping.clamp=True
mapping.inputs['From Min'].default_value=.83;mapping.inputs['From Max'].default_value=1;mapping.inputs['To Min'].default_value=.95;mapping.inputs['To Max'].default_value=5
l.new(bw.outputs[0],mapping.inputs[0]);l.new(mapping.outputs[0],em.inputs[1])
wing=bpy.data.materials[PREFIX+'holographic cyan membrane'];next(n for n in wing.node_tree.nodes if n.type=='MIX_SHADER').inputs[0].default_value=.36
for ob in list(scene.objects):
    if ob.name.startswith('Wing | individually swept feather'):
        pts=[tuple(v.co) for v in ob.data.vertices][25:]
        tube('Wing | refined trailing violet lip',pts,.035,violet,6)
# Warm-white surfaces remain white, with illumination provided by the actual lighting rig.
for mat in (ivory,):
    ramp=next(n for n in mat.node_tree.nodes if n.type=='VALTORGB')
    ramp.color_ramp.elements[0].color=(.57,.59,.63,1);ramp.color_ramp.elements[1].color=(.79,.81,.85,1)
for ob in scene.objects:
    if ob.type=='LIGHT' and ob.name=='Altar review key':ob.data.energy=260000
    if ob.type=='LIGHT' and ob.name=='Altar review cool fill':ob.data.energy=140000
camera((25,-265,110),(0,0,65),146)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active;s.shading.type='RENDERED';s.shading.use_scene_world_render=True;s.shading.use_scene_lights_render=True;s.shading.use_compositor='ALWAYS';s.overlay.show_overlays=False;s.region_3d.view_perspective='CAMERA';s.region_3d.view_camera_zoom=-5
save('06 optical polish and inner crystal construction')
