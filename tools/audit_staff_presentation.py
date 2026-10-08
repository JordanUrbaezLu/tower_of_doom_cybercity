"""One-time binary geometry/animation audit (requires PyCoD; no game launch)."""
import json
import math
from build_staff_presentation import ROOT, MODELS, ANIMS, model, anim, pose, compose, IDENT, BLADE_NAMES, relative, dot


def main():
    manifest=json.loads((ROOT/'docs/staff_presentation_manifest.json').read_text())
    report={}
    for name,expected in manifest['geometry'].items():
        m=model(MODELS/(name+'.XMODEL_BIN'))
        assert len({b.name for b in m.bones})==len(m.bones)<256
        assert sum(len(x.verts) for x in m.meshes)==expected['vertices']
        assert sum(len(x.faces) for x in m.meshes)==expected['triangles']
        for i,mesh in enumerate(m.meshes):
            for v in mesh.verts:
                assert all(0<=b<len(m.bones) and w>=0 for b,w in v.weights)
                assert abs(sum(w for b,w in v.weights)-1)<.001
            for f in mesh.faces:
                assert f.mesh_id==i and f.material_id<len(m.materials)
                assert all(0<=c.vertex<len(mesh.verts) for c in f.indices)
        report[name]={'vertices':expected['vertices'],'triangles':expected['triangles'],'meshes':len(m.meshes)}
    for perspective in ('vm','wm'):
        original=model(ROOT/('model_export/tod_bo6_ice/tod_bo6_ice_'+perspective+'.XMODEL_BIN'))
        body=model(MODELS/('tod_staff_ice_body_'+perspective+'.XMODEL_BIN'))
        tip=model(MODELS/('tod_staff_ice_tip_'+perspective+'.XMODEL_BIN'))
        pap=model(MODELS/('tod_staff_ice_pap_tip_'+perspective+'.XMODEL_BIN'))
        socket=pose(next(b for b in body.bones if b.name=='tag_barrel_attach'))
        max_error=0.;changed=0
        for mi,old in enumerate(original.meshes):
            piece=body if mi<8 else tip
            mesh=piece.meshes[mi if mi<8 else mi-8]
            assert len(old.faces)==len(mesh.faces)
            for v,nv in zip(old.verts,mesh.verts):
                p=nv.offset if mi<8 else compose(socket,(nv.offset,IDENT))[0]
                max_error=max(max_error,math.dist(v.offset,p))
                oldweights={original.bones[b].name:round(w,5) for b,w in v.weights}
                newweights={piece.bones[b].name:round(w,5) for b,w in nv.weights}
                assert oldweights==newweights
            for f,nf in zip(old.faces,mesh.faces):
                assert original.materials[f.material_id].name==piece.materials[nf.material_id].name
                assert [x.vertex for x in f.indices]==[x.vertex for x in nf.indices]
                for c,nc in zip(f.indices,nf.indices):
                    assert c.uv==nc.uv and c.color==nc.color
            if mi>=8:
                for v,pv in zip(mesh.verts,pap.meshes[mi-8].verts):
                    moved=math.dist(v.offset,pv.offset)>.001
                    is_blade=any(tip.bones[b].name in BLADE_NAMES for b,w in v.weights if w>.001)
                    assert not moved or is_blade,'PaP altered non-blade geometry'
                    changed+=moved
        assert max_error<.02,(perspective,max_error)
        assert changed>1000,changed
        report[perspective]={'reconstructed_max_error_inches':max_error,'opened_blade_vertices':changed}
    donor=anim(ROOT/'xanim_export/tod_staff_approved/tod_vm_staff_ice_fit_t7_water_first_raise.XANIM_BIN')
    donoridx={p.name:i for i,p in enumerate(donor.parts)}
    for name,expected in manifest['clips'].items():
        a=anim(ANIMS/(name+'.XANIM_BIN'));idx={p.name:i for i,p in enumerate(a.parts)}
        assert len(a.frames)==expected['frames'] and len(a.parts)==expected['bones']<256
        for f in a.frames:
            assert all(math.isfinite(x) for p in f.parts for x in p.offset)
            assert math.dist(f.parts[idx['j_elbow_le']].offset,f.parts[idx['j_elbow_bulge_le']].offset)<.002
        if name.startswith('tod_staff_ice'):
            for old,new in zip(donor.frames,a.frames):
                for n in ('j_wrist_le','j_wrist_ri','j_elbow_le','j_elbow_ri','tag_weapon','tag_flash'):
                    assert math.dist(old.parts[donoridx[n]].offset,new.parts[idx[n]].offset)<.002
        report[name]={'frames':len(a.frames),'bones':len(a.parts),'finite':True}
    (ROOT/'tmp/staff_pap_20260921/binary_audit.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Binary audit passed: complete meshes, valid weights/materials/triangle indices, reconstructed base ice, only four blade pivots changed, original hand poses and elbow repair preserved.')


if __name__=='__main__':main()
