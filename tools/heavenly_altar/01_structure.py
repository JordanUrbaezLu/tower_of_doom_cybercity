import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
assert scene.get('mcp_port')==9878,'Use the altar Blender window only'
# Preserve the exact donor in its original .blend and a hidden reference collection.
for ob in list(scene.objects):
    if ob.get('altar_design') or ob.name.startswith('Altar review'):
        bpy.data.objects.remove(ob,do_unlink=True)
    elif ob.type=='MESH':
        ob.hide_render=True;ob.hide_set(True)
        ob['preserved_original_reference']=True
scene['altar_reference']='ChatGPT Image Sep 16, 2026, 04_39_31 PM.png'
D.group='01 Structural frame'
# Three dimensional plinth with broad chamfered feet and stepped gold horizons.
base=[(-46,0),(46,0),(45,3),(40,10),(32,14),(-32,14),(-40,10),(-45,3)]
panel('Plinth | load bearing graphite',base,-23,37,dark,.5)
panel('Plinth | lower titanium shoe',[(-47,.3),(47,.3),(46,2.4),(-46,2.4)],-24,39,steel,.25)
panel('Plinth | broad gold cornice',[(-40,11.5),(40,11.5),(39,13.7),(-39,13.7)],-23.7,33,gold,.22)
line('Plinth | front light lip',[(-40,12.3),(40,12.3)],-24.15,.16,warm)
for s in (-1,1):
    def P(p):return [(s*x,z) for x,z in p]
    bevel_panel('Foot | sloping shield',P([(26,1.5),(46,1.5),(42,8),(36,12),(28,10)]),-24.8,2)
    line('Foot | violet inset',P([(29,4),(38,4),(41,7)]),-25.25,.22,violet)
    line('Foot | cyan end pilot',P([(44,1.8),(43,3.1)]),-25.3,.18,cyan)
    bevel_panel('Plinth | angular front bank',P([(2,2.8),(22,2.8),(28,6),(26,11.5),(3,11.5)]),-25.1,2)
    line('Plinth | light recess',P([(7,9.8),(16,9.8),(18,11)]),-25.55,.22,violet)
    bevel_panel('Foot | inner heel',P([(2,.3),(24,.3),(20,3),(5,3)]),-25.6,.6)
    for x,z in [(30,3),(38,9),(21,4),(5,4)]:bolt('Plinth | captive fastener',s*x,z,-25.9,.2)
    # Diamond outline retained from the original altar; replacement hard-surface shells.
    outer=P([(15,14),(25,14),(25,42),(51,65),(24,96),(16,90),(40,65),(15,44)])
    panel('Frame | deep structural backbone',outer,-17,27,dark,.35)
    # Side return reveals create convincing depth from a three-quarter view.
    panel('Frame | rear gold seam',outer,8.5,1.2,gold,.18)
    rail=P([(17,16),(23,16),(23,43),(49,65),(23,94),(19,91),(43.5,65),(17,43)])
    panel('Frame | outer gold bezel',rail,-20,3,gold,.25)
    outerface=P([(18,17),(22,17),(22,43.5),(47.5,65),(22,92.4),(20,90.5),(44.4,65),(18,43.7)])
    panel('Frame | white armor rim',outerface,-20.5,1,ivory,.16)
    inner=P([(14.5,15),(17.1,15),(17.1,43.2),(41.6,65),(17.3,91.5),(15.3,89.5),(38.2,65),(14.5,43.5)])
    panel('Frame | inner gold liner',inner,-20.1,2,goldlight,.14)
    line('Frame | unbroken cyan data trace',P([(16.9,18),(16.9,43.5),(40.5,65),(17,90)]),-20.7,.19,cyan)
    line('Frame | outer violet conductor',P([(23.1,25),(23.1,42.5),(49,65),(23.5,94)]),-20.2,.23,violet)
    # Segmented ceramic shields along both diagonal legs, each with gold saddles.
    for start,end in [((24,45),(45,63)),((45,67),(25,90))]:
        A,B=Vector(start),Vector(end);t=(B-A).normalized();n=Vector((-t.y,t.x))
        for j in range(3):
            a=A+(B-A)*(j/3+.018);b=A+(B-A)*((j+1)/3-.018)
            pts=[a+n*.1,b+n*.1,b+n*2.15,a+n*2.15]
            pts=P([(v.x,v.y) for v in pts]);bevel_panel('Frame | segmented rail panel',pts,-21.05,.55)
            bolt('Frame | rail socket',s*(a.x+n.x),a.y+n.y,-21.55,.18)
    # Uprights, side flanges, and full-depth top crossbeam.
    box('Pillar | return spine',(s*29,1,59),(6,17,88),dark,.3)
    box('Pillar | rear ivory case',(s*29,10,59),(5,3,82),ivory,.3)
    for z in (25,42,62,84,99):
        box('Pillar | gold retention band',(s*29,0,z),(6.5,18,1),gold,.14)
    flange=P([(18,101),(39,99),(39,106),(36,114),(17,114)])
    panel('Shoulder | armored crossbeam',flange,-13,26,dark,.35)
    bevel_panel('Shoulder | pearl shield',P([(19,107),(37,104),(38,109),(36,114),(18,114)]),-15,2)
    line('Shoulder | purple undercut',P([(21,108),(34,105.8),(36,107.5)]),-15.7,.29,violet)
    bevel_panel('Shoulder | hanging cap',P([(28,94),(35,95),(37,102),(29,105),(26,102)]),-14,2)
    line('Shoulder | vertical cyan slit',P([(25,96),(25,103)]),-14.8,.2,cyan)
    for x,z in [(31,112),(35,98),(22,111)]:bolt('Shoulder | hex socket',s*x,z,-15.8)
    # Lower reaction wheel mount with angular armor cheeks.
    bevel_panel('Reactor | flanking shield',P([(8,13),(23,13),(24,19),(20,22),(9,20)]),-21.6,3)
    for j in range(3):line('Reactor | cyan grille',P([(15+j*1.1,15.2),(16+j*1.1,16.5)]),-22.15,.22,cyan)
D.group='02 Lower reaction wheel'
disc('Lower reactor | dark socket',0,13,-22.4,10,6,dark)
ring('Lower reactor | gold outer rim',0,13,-23,9.5,1.1,2,gold)
ring('Lower reactor | ivory interrupted bezel',0,13,-23.5,8.1,1.25,1,ivory,start=.12,end=math.pi-.12,N=64)
ring('Lower reactor | violet light',0,13,-24.2,4.4,.35,1,violet)
disc('Lower reactor | central lens',0,13,-24.3,3.6,.8,optic)
ring('Lower reactor | inner gold rim',0,13,-24.6,3.8,.4,.7,goldlight)
panel('Lower reactor | central spear',[(-.7,9),(0,7),(1,10),(1,14),(0,15.5),(-1,14)],-26,1,white,.1)
for a in range(15,181,30):
    ang=math.radians(a);line('Lower reactor | radial insert',[(7*math.cos(ang),13+7*math.sin(ang)),(8.8*math.cos(ang),13+8.8*math.sin(ang))],-24,.35,goldlight)
camera();live_view();save('01 reference silhouette and layered armor')
