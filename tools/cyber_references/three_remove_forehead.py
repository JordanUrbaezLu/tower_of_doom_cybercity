"""Remove the raised welding shield, its hinges and crown support frame."""
import bpy
prefixes=(
    'Head | finished welder hood', 'Head | welder hood',
    'Head | recessed smoked welding', 'Head | thick visor',
    'Head | exposed filter', 'Head | chamfered visor', 'Head | dark visor',
    'Head | filter retention', 'Head | raised visor', 'Head | visor ',
    'Head | folded visor', 'Head | welder visor warning',
    'Head | hinge face screw', 'Head | helmet crown rail',
    'Head | worn crown edge', 'Head | yoke fastening screw')
removed=[]
for ob in list(bpy.context.scene.objects):
    if ob.get('attachment_bone')=='j_head' and ob.name.startswith(prefixes):
        removed.append(ob.name);bpy.data.objects.remove(ob,do_unlink=True)
assert removed or bpy.context.scene.get('armored_forehead_shield_removed')
bpy.context.scene['armored_forehead_shield_removed']=True
print('FOREHEAD_SHIELD_REMOVED',len(removed),flush=True)
