"""Presentation-only overrides, shared by importers and build validation."""
# 2026-09-27 (docs/161): THE ORIGINS STAFF PLAYER POSE. Treyarch's playeranim
# scripts (core_common) bind the staff's 48 pb_staff_* / 29 pt_staff_* clips to
# playerAnimType "armminigun" under #gametype ZM, and all 77 of those xanims are
# ALREADY in zm_common.ff, which every Zombies usermap loads before its own .ff
# (the user's console log shows the load order). So the whole third-person set
# is one value here - nothing is converted, zoned or packed by us.
# Mount: the clips carry the staff on tag_weapon_RIGHT (its +Z runs along the
# shaft and passes 2.07 in from the left hand, 22.9 in down it, on every frame
# sampled; tag_weapon_left sits collapsed on the left wrist). Our world shafts
# keep their +Z long axis (the Origins shaft IS the stock staff world model).
# FALLBACK if the pose reads wrong in game: 'bow' + both tags 'tag_weapon_left'
# (the v19.49 stock bow pose, docs/160). verify_staff_3p.py pins the pairing.
STAFF_PLAYER_ANIM_TYPE = 'armminigun'
STAFF_WORLD_MOUNT = 'tag_weapon_right'
STAFF_BINDINGS = {element: {'attachmentUnique': 'au_tod_staff_'+element,
                           'playerAnimType': STAFF_PLAYER_ANIM_TYPE,
                           'worldModelTagRight': STAFF_WORLD_MOUNT,
                           'worldModelTagLeft': STAFF_WORLD_MOUNT,
                           'attachWorldModelTag1': 'tag_tip'}
                  for element in ('fire', 'lightning', 'ice')}
# 2026-09-27 (docs/165): a complete head carries its own crystal vertices.
# Both use the head root, so no separate crystal attachment can disappear or
# remain stationary while the lightning cage spins. Ice retains its BO6 kit.
STAFF_ASSEMBLY = {el: {form: 'tod_staff_'+el+'_complete_'+form
                       for form in ('view','world','pap','pap_world')} for el in ('fire','lightning')}
for _element, _models in STAFF_ASSEMBLY.items():
    STAFF_BINDINGS[_element].update(attachViewModel1=_models['view'], attachWorldModel1=_models['world'],
                                    attachViewModelTag1='tag_tip',
                                    attachViewModel2='', attachViewModelTag2='',
                                    attachWorldModel2='', attachWorldModelTag2='')
STAFF_BINDINGS['ice'].update(
    gunModel='tod_staff_ice_body_vm', worldModel='tod_staff_ice_body_wm',
    attachViewModel1='tod_staff_ice_tip_vm', attachWorldModel1='tod_staff_ice_tip_wm',
    attachViewModelTag1='tag_barrel_attach', attachWorldModelTag1='tag_barrel_attach',
    firstRaiseAnim='tod_staff_ice_first_raise')


def shipping_staff_fields(element, twins):
    """Use emitted gameplay values, including global headshot normalization.

    Presentation is shared across all handling/perk variants. A new gameplay
    variant must not accidentally inherit values from the untuned source port.
    """
    variants={n:f for n,f in twins.items() if n.startswith('tod_staff_'+element+'_q')}
    assert variants,('no generated staff',element)
    first=variants[sorted(variants)[0]]
    for n,f in variants.items():
        assert all(f.get(k)==v for k,v in first.items() if k.startswith('loc') and k[3:4].isupper()),(n,'presentation needs variant-specific location values')
    return first


def attachment_fields(element, packed, weapon_fields):
    fields={'attachmenttype': 'gmod6' if packed else 'none',
            'configstringFileType': 'ATTACHMENTUNIQUEFILE'}
    # The native asset DB fills omitted loc multipliers with 4x head / 5x neck
    # and legacy bullet ranges with 15000/16000. Explicitly retain the weapon's
    # existing loc values and disable those legacy range overrides. Neither
    # form may acquire new combat defaults merely by enabling unique assets.
    fields.update({k:v for k,v in weapon_fields.items() if k.startswith('loc') and k[3:4].isupper()})
    fields.update(maxDamageRange='0',minDamageRange='0')
    if not packed: return fields
    fields.update(disableBaseWeaponAttachment='1', attachment0_ModelAssociation='gmod6',
                  firstRaiseAnim='tod_staff_'+element+'_pap_first_raise')
    for perspective,key in [('vm','View'),('wm','World')]:
        fields['attachment0_'+key+'Model_model0']=('tod_staff_ice_pap_tip_'+perspective if element=='ice'
                                                   else STAFF_ASSEMBLY[element]['pap' if perspective=='vm' else 'pap_world'])
        # Base animated heads use their animation rig's tag_tip parent. The upgraded
        # single-bone head is instead rigid, with an unkeyed root: both views
        # must explicitly use the shaft tip, never the default weapon root.
        fields['attachment0_'+key+'ModelTag_model0']=('tag_barrel_attach' if element=='ice'
                                                      else 'tag_tip')
    # Fire/lightning crystals are part of model0 itself in both views.
    return fields


if __name__ == '__main__':
    # Refresh just presentation bindings; do not reimport the accepted clips.
    from import_staff_animations import ROOT, blocks, emit
    path=ROOT/'source_data/tod_staff.gdt'
    assets=blocks(path)
    for name,kind,fields in assets:
        fields.update(STAFF_BINDINGS[name.removeprefix('tod_staff_')])
    path.write_text('{\n'+''.join(emit(*a) for a in assets)+'}\n',encoding='latin1')
    # docs/164: the gmod6/none AU blocks are this module's output too
    # (attachment_fields is their one owner), so refresh them IN PLACE rather
    # than re-running build_staff_presentation.py (which needs the T7/BO6
    # exports and regenerates binaries). Every other PaP block is re-emitted
    # unchanged (the round trip is lossless), and the manifest pin is re-stamped.
    import hashlib, json
    pap=ROOT/'source_data/tod_staff_pap.gdt'
    twins={n:f for n,k,f in blocks(ROOT/'source_data/tod_weapon_twins.gdt')}
    out=[]
    for name,kind,fields in blocks(pap):
        if kind=='attachmentunique.gdf' and name.startswith('au_tod_staff_'):
            element,form=name[len('au_tod_staff_'):].rsplit('_',1)
            fields=attachment_fields(element,form=='gmod6',shipping_staff_fields(element,twins))
        out.append((name,kind,fields))
    pap.write_text('{\n'+''.join(emit(*a) for a in out)+'}\n',encoding='latin1')
    manifest_path=ROOT/'docs/staff_presentation_manifest.json'
    manifest=json.loads(manifest_path.read_text())
    manifest['files']['source_data/tod_staff_pap.gdt']=hashlib.sha256(pap.read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    print('Staff presentation bindings refreshed (sources + PaP attachments). Regenerate weapon twins next.')
