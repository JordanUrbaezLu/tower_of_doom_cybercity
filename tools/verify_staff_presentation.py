"""Build gate for staff PaP geometry, flourish bindings and zero added weapons."""
import hashlib
import json
from import_staff_animations import ROOT, blocks
from staff_presentation_bindings import STAFF_BINDINGS, STAFF_ASSEMBLY, attachment_fields, shipping_staff_fields
import build_staff_crystal
import build_staff_assembly
import restore_staff_retail
from verify_weapon_attachments import declarations


def check_world_assembly(element, weapon, packed):
    # Verify the base head and its PaP replacement use the SAME shaft socket.
    # A blank tag falls back to the weapon root and strands the head at the
    # grip. Base view heads also need the parent used by their animation rig.
    socket = 'tag_barrel_attach' if element == 'ice' else 'tag_tip'
    assert weapon['attachWorldModelTag1'] == socket, (element, 'base world head socket')
    assert packed['attachment0_WorldModelTag_model0'] == socket, (element, 'packed world head socket')
    assert packed['attachment0_ViewModelTag_model0'] == socket, (element, 'packed view head must not fall back to grip')
    # 2026-09-27 (docs/161): the Origins armminigun player clips carry the staff
    # on tag_weapon_right; the v19.49 fallback was the stock bow's left mount.
    # A pose is only valid with ITS hand - never mix the two pairs.
    pairs = {'armminigun': 'tag_weapon_right', 'bow': 'tag_weapon_left'}
    assert weapon['playerAnimType'] in pairs, (element, 'staff player pose must be armminigun (Origins) or bow (fallback)')
    hand = pairs[weapon['playerAnimType']]
    assert weapon['worldModelTagRight'] == weapon['worldModelTagLeft'] == hand, (element, weapon['playerAnimType'] + ' pose needs the ' + hand + ' mount')
    assert weapon['attachViewModelTag1'] == socket, (element, 'base view head must use its animation parent socket')
    # The head and crystal are one model. The second attachment must be empty,
    # otherwise the rejected standalone crystal can be drawn a second time.
    for key in ('attachViewModel2','attachViewModelTag2','attachWorldModel2','attachWorldModelTag2'):
        assert not weapon.get(key), (element, 'stray separate crystal', key)
    for view in ('View','World'):
        assert not packed.get('attachment0_'+view+'Model_model1'), (element,'separate packed crystal')
        if element in STAFF_ASSEMBLY:
            form='view' if view=='View' else 'world'
            assert weapon['attach'+view+'Model1']==STAFF_ASSEMBLY[element][form]
            assert packed['attachment0_'+view+'Model_model0']==STAFF_ASSEMBLY[element]['pap' if view=='View' else 'pap_world']


def main():
    declarations()
    build_staff_crystal.check()
    build_staff_assembly.check()
    restore_staff_retail.check()
    check_base_animation_parent()
    manifest=json.loads((ROOT/'docs/staff_presentation_manifest.json').read_text())
    for path,expected in manifest['files'].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==expected,('staff presentation changed/missing',path)
    assets={n:(k,f) for n,k,f in blocks(ROOT/'source_data/tod_staff_pap.gdt')}
    sources={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff.gdt')}
    twins={n:f for n,k,f in blocks(ROOT/'source_data/tod_weapon_twins.gdt')}
    staff_twins={n:f for n,f in twins.items() if n.startswith('tod_staff_')}
    assert all(k not in ('projectileweapon.gdf','bulletweapon.gdf') for k,f in assets.values()),'Presentation must not add registered weapons'
    zone=(ROOT/'zone_source/zm_tower_of_doom.zone').read_text(encoding='utf-8')
    assert '\nattachment,gmod6\n' in zone
    aliases={l.split(',')[0] for l in (ROOT/'sound/aliases/tod_ports.csv').read_text(encoding='utf-8').splitlines()}
    for element,bindings in STAFF_BINDINGS.items():
        shipping=shipping_staff_fields(element,twins)
        for weapon in [sources['tod_staff_'+element]]+[f for n,f in staff_twins.items() if n.startswith('tod_staff_'+element+'_')]:
            check_world_assembly(element, weapon, assets['au_tod_staff_'+element+'_gmod6'][1])
            for key,value in bindings.items():assert weapon.get(key)==value,(element,key,'binding')
            for suffix in ('_none','_gmod6'):
                assert weapon['attachmentUnique']+suffix in assets,(element,'unresolved attachment base',suffix)
        for packed in (False,True):
            name='au_tod_staff_'+element+('_gmod6' if packed else '_none')
            kind,fields=assets[name]
            assert kind=='attachmentunique.gdf' and fields==attachment_fields(element,packed,shipping),(name,'non-visual override')
            assert '\nattachmentunique,'+name+'\n' in zone,(name,'not explicitly linked')
    for name,data in manifest['clips'].items():
        kind,fields=assets[name]
        assert kind=='xanim.gdf' and fields['type']=='relative' and fields['useBones']=='0'
        assert fields['customnote0action']=='2D Sound' and fields['customnote0actionparam1'] in aliases
        assert data['frames']>30 and 100<data['bones']<256
    for name,(kind,fields) in assets.items():
        if kind not in ('xmodel.gdf','xanim.gdf'):continue
        for key,folder in [('filename','model_export' if kind=='xmodel.gdf' else 'xanim_export'),('model','model_export')]:
            if key not in fields:continue
            path=folder+'/'+fields[key].replace('\\\\','/')
            assert (ROOT/path).is_file(),(name,'missing dependency',path)
    for perspective in ('vm','wm'):
        body=manifest['geometry']['tod_staff_ice_body_'+perspective]
        tip=manifest['geometry']['tod_staff_ice_tip_'+perspective]
        pap=manifest['geometry']['tod_staff_ice_pap_tip_'+perspective]
        assert body['vertices']+tip['vertices']==51060
        assert body['triangles']+tip['triangles']==59842
        assert (tip['vertices'],tip['triangles'])==(pap['vertices'],pap['triangles'])
        assert tip['reconstruction_error']<.0001
    print(f'Staff PaP validation passed: 3 upgraded heads, integrated fire/lightning head/crystals in both views (base + packed), 4 first-equip clips, {len(staff_twins)} existing weapon roots; presentation adds zero weapons.')


def check_base_animation_parent():
    # Relative clips are compiled against this hierarchy. Attaching a head
    # at the weapon root instead silently loses the shaft-to-tip transform;
    # previewing exported GLOBAL frames alone cannot detect that error.
    rig=build_staff_assembly.model(ROOT/'model_export/tod_staff_anim/tod_vm_staff_elements_skeleton.XMODEL_BIN')
    bones={b.name:b for b in rig.bones}
    assets={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff_approved_anims.gdt')}
    for element in ('fire','lightning'):
        head=build_staff_assembly.model(build_staff_assembly.OUT/(STAFF_ASSEMBLY[element]['view']+'.XMODEL_BIN'))
        root=bones[head.bones[0].name]
        assert root.parent>=0
        parent=rig.bones[root.parent].name
        assert parent==STAFF_BINDINGS[element]['attachViewModelTag1'],(element,'attachment / animation hierarchy mismatch',parent)
        for bone in head.bones[1:]:
            animated=bones[bone.name]
            assert rig.bones[animated.parent].name==head.bones[bone.parent].name,(element,bone.name,'head hierarchy mismatch')
        for name,fields in assets.items():
            if name.startswith('tod_vm_staff_'+element+'_fit_'):
                assert fields['model'].replace('\\\\','/').replace('\\','/').endswith('tod_vm_staff_elements_skeleton.XMODEL_BIN'),(name,'different animation rig')
    print('STAFF_BASE_PARENT_OK: both articulated base heads attach to their compiled animation parent; child hierarchies preserved.')


if __name__=='__main__':main()
