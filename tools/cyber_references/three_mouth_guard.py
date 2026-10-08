"""Add a folded steel mouth guard to the existing armored master (Blender)."""
import sys, runpy, json, hashlib
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from equipment import *
assert REFERENCE == 3
for ob in list(scene.objects):
    if ob.name.startswith(('Mouth guard |', 'Eye strip |')):
        bpy.data.objects.remove(ob, do_unlink=True)
bone = 'j_head'
guard_metal = mat('scarred gunmetal mouth armor', (.14,.16,.17), 'metal')
# A closed plate, folded forward at its centre: no projecting blade or grille.
# Top stays beneath the nose; lower edge covers the jaw above the collar.
for side in (-1, 1):
    outer = side * 3.35
    front = [(0, -6.15, 65.00), (outer, -3.35, 64.90),
             (outer * .83, -3.12, 61.90), (0, -5.70, 61.55)]
    back = [(x, y + .24, z) for x, y, z in front]
    mesh('Mouth guard | folded steel cheek', front + back,
         [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),
          (2,6,7,3),(3,7,4,0)], guard_metal, bone, .025)
    rod('Mouth guard | rubbed upper rim', front[0], front[1], .075, edge, bone, 8)
    rod('Mouth guard | rubbed lower rim', front[3], front[2], .065, edge, bone, 8)
    q, n = headpoint(side * 2, 64.25, True, .32)
    panel('Mouth guard | cheek mount', q, n, .92, 1.60, bone, steel, depth=.22)
    rod('Mouth guard | cheek retaining link', q, Vector(front[1]) + Vector((0,0,-.55)), .16, steel, bone, 10)
    bolt('Mouth guard | cheek rivet', q + n*.24, n, bone, .16)
    # Short, recessed diagonal louvers sit on the wings, leaving the nose ridge
    # as one uninterrupted folded edge. Raised metal lips give real depth.
    normal = Vector((side*.64,-.77,.025)).normalized()
    for index in range(3 if side == -1 else 2):
        t = .55 + index*.12
        p = Vector(front[0]).lerp(Vector(front[1]), t) + Vector((0,0,-1.15))
        panel('Mouth guard | recessed breathing port', p + normal*.03, normal,
              .20, .78, bone, rubber, depth=.035, fasteners=False)
        rod('Mouth guard | port protective lip', p + Vector((side*.12,0,-.38)),
            p + Vector((side*.12,0,.38)), .045, edge, bone, 8)
    # A riveted sacrificial rim and a small serial stamp are deliberately
    # asymmetric, like repaired industrial armor rather than a clean costume.
    if side == -1:
        p = Vector(front[0]).lerp(Vector(front[1]), .39) + Vector((0,0,-2.10))
        label('Mouth guard | workshop serial', 'MK-33', p + normal*.04, normal,
              .22, bone, mat=letter)
    for t in (.25,.80):
        p = Vector(front[0]).lerp(Vector(front[1]),t) + Vector((0,0,-.27))
        bolt('Mouth guard | captive face screw', p + normal*.04, normal, bone, .105)
scene['armored_mouth_guard'] = 'folded_steel_v1'
# Cyclops-style single red aperture; the casing follows the skull curvature
# rather than laying a floating straight bar across the two eye sockets.
laser_red = mat('ruby laser eye aperture', (.80,.004,.009), 'light', 3.5)
for side in (-1, 1):
    inner, _ = headpoint(0,65.85,False,.55)
    outer, _ = headpoint(side*1.95,65.85,False,.55)
    outer.z = inner.z
    mid = (inner+outer)*.5
    n = Vector((side*(outer.y-inner.y),-abs(outer.x-inner.x),0)).normalized()
    width = (outer-inner).length + .13
    panel('Eye strip | armored optical shroud', mid,n,width,1.08,bone,steel,depth=.37,fasteners=False)
    panel('Eye strip | deep aperture gasket', mid+n*.38,n,width-.13,.44,bone,rubber,depth=.055,fasteners=False)
    # A continuous slim light, with a dark recess above and below its glass.
    panel('Eye strip | continuous ruby aperture', mid+n*.44,n,width,.23,bone,laser_red,depth=.035,fasteners=False)
    end = outer + n*.18
    bolt('Eye strip | temple optical lock',end,n,bone,.11)
    q,qn=headpoint(side*2,65.85,True,.30)
    rod('Eye strip | temple attachment',outer,q,.12,steel,bone,10)
# The curved wings share a central optical bridge: one unbroken aperture,
# rather than two separate glowing spectacle lenses over the nose.
bridge,_=headpoint(0,65.85,False,1.03)
panel('Eye strip | nose optical bridge',bridge+Vector((0,.09,0)),(0,-1,0),.68,.88,bone,steel,depth=.045,fasteners=False)
panel('Eye strip | continuous centre aperture',bridge,(0,-1,0),.72,.23,bone,laser_red,depth=.045,fasteners=False)
scene['armored_eye_strip']='ruby_cyclops_v1'
scene['armored_native_scale'] = 1.33
scene['authoring_transport'] = 'Original Blender MCP master; mouth guard refined in Blender Python, 2026-10-06'
runpy.run_path(str(Path(__file__).parent/'three_remove_forehead.py'))
runpy.run_path(str(Path(__file__).parent/'three_sword_arms.py'))
runpy.run_path(str(Path(__file__).parent/'three_back_spikes.py'))
runpy.run_path(str(Path(__file__).parent/'three_helmet.py'))
runpy.run_path(str(Path(__file__).parent/'three_armor_finish.py'))
runpy.run_path(str(Path(__file__).parent/'fix_modifier_order.py'))
save('03_completed_reference_three_armored_only')
# The shared review runs its UI layout steps only in an interactive session.
review = (Path(__file__).parent/'review.py').read_text()
start = review.index('# Keep the exact concept')
end = review.index("camera((30,-126,62)", start)
review = review[:start] + review[end:]
exec(compile(review, str(Path(__file__).parent/'review.py'), 'exec'))
