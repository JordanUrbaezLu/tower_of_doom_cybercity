"""Retire the complete pressure pack, plumbing and now-unused mounting frame."""
import bpy, json

scene = bpy.context.scene
assert scene.get('cyber_reference_number') == 3
removed = []
for ob in list(scene.objects):
    if ob.get('attachment_bone') and ob.name.startswith(('Back |', 'Back standoff |')):
        removed.append(ob.name)
        bpy.data.objects.remove(ob, do_unlink=True)
assert removed or scene.get('armored_backpack_removed')
scene['armored_backpack_removed'] = True
scene['armored_backpack_removal'] = json.dumps({
    'policy': 'no_pressure_pack_v1',
    'removed_objects': len(removed) if removed else json.loads(scene['armored_backpack_removal'])['removed_objects'],
    'tank_frame_plumbing_and_standoffs_removed': True,
    'dorsal_armor_spikes_retained': True,
})
for key in ('armored_backpack_clearance', 'armored_backpack_clearance_offset', 'reference_three_backpack_design'):
    if key in scene:
        del scene[key]
print('ARMORED_BACKPACK_REMOVED', scene['armored_backpack_removal'], flush=True)
