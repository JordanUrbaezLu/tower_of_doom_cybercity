"""Unify authored armor finishes without touching the retained stock donors."""
from equipment import *

assert REFERENCE == 3
plate = mat('armored shared worn gunmetal', (.14, .17, .18), 'metal')
rim = mat('armored shared abraded steel edges', (.28, .31, .32), 'metal')
recess = mat('armored shared blackened fittings', (.040, .047, .052), 'metal')
hose_finish = mat('armored shared aged black hoses', (.020, .022, .026), 'rubber')
replacements = {
    'executioner helmet forged graphite': plate,
    'executioner helmet repaired plate': plate,
    'scarred sword alloy': plate,
    'chipped porcelain enamel': plate,
    'executioner helmet cold worn edges': rim,
    'rubbed steel': rim,
    'spike arm blackened forged roots': recess,
    'oil-black iron': recess,
    'aged magenta pressure line': hose_finish,
    'pressure hose dark reinforcement': hose_finish,
}
replacements = {'R1 | ' + name: material for name, material in replacements.items()}
parts = [o for o in scene.objects if o.get('attachment_bone')]
donor_slots = {o.name: [m.name if m else None for m in o.data.materials] for o in base}
assert not any(ob.data is donor.data for ob in parts for donor in base)
for ob in parts:
    for slot in ob.material_slots:
        if slot.material and slot.material.name in replacements:
            slot.material = replacements[slot.material.name]

# The same shader, oxidation, forging relief and abrasion now cross the head,
# sword plates and body armor. Keep the optical recess and small status lamps.
usage = {}
for material in (plate, rim, recess, hose_finish):
    bones = sorted({o['attachment_bone'] for o in parts
                    if material in list(o.data.materials)})
    usage[material.name] = bones
assert {'j_head', 'j_elbow_le', 'j_elbow_ri', 'j_spine4'} <= set(usage[plate.name])
assert {'j_head', 'j_elbow_le', 'j_elbow_ri'} <= set(usage[rim.name])
assert not any(slot.material and slot.material.name in replacements
               for ob in parts for slot in ob.material_slots)
assert donor_slots == {o.name: [m.name if m else None for m in o.data.materials] for o in base}
scene['armored_finish'] = 'shared_worn_gunmetal_v1'
scene['armored_finish_spec'] = json.dumps({
    'policy': scene['armored_finish'],
    'material_bone_usage': usage,
    'shared_surface_details': ['oily staining', 'brown oxidation',
                              'forging relief', 'directional abrasion'],
    'stock_donor_materials_unchanged': True,
    'primary_accent': 'continuous red optic',
    'secondary_accents': 'existing small cyan/amber status lamps and faded hazard paint',
})
print('ARMORED_FINISH_OK', scene['armored_finish_spec'])
