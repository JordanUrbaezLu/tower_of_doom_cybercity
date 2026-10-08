"""Build staff PaP heads and first-equip clips from the user's local exports.

Generation only: PyCoD (TOD_PYCOD), BO3 export2bin, the original test-map T7
exports and BO6 CAST reader are required. Normal builds use the checked-in
binaries plus verify_staff_presentation.py; they do not need these tools.
See docs/150_staff_pap_presentation.md for sources and adaptation boundaries.
"""
import copy
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys

from import_staff_animations import ROOT, blocks, emit
from staff_presentation_bindings import attachment_fields, shipping_staff_fields
from bo6_extraction.install_ice_staff_bo3 import load_pycod, TOOLS

xm = load_pycod()
from PyCoD import xanim as xa

TEST = ROOT.parent/'test+map'
MODELS = ROOT/'model_export/tod_staff_pap'
ANIMS = ROOT/'xanim_export/tod_staff_pap'
EXTRACTED = ROOT/'tmp/staff_pap_20260921/extracted'
BO6 = Path.home()/'Downloads/BO6_Pilot_Export/bo6/animations'
IDENT = ((1., 0., 0.), (0., 1., 0.), (0., 0., 1.))
ROOT_TRACKS = {'tag_view', 'tag_ads', 'tag_torso', 'tag_cambone'}
BLADE_NAMES = ('bone_b7b569366dda82f0', 'bone_896eff6c3e7caea6',
               'bone_30cea30368f62858', 'bone_d86c05bd633da796')
REPORT = dict(sources={}, files={}, geometry={}, clips={}, native_verified=False)
GDT = []


def vadd(a, b): return tuple(x+y for x, y in zip(a, b))
def vsub(a, b): return tuple(x-y for x, y in zip(a, b))
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def norm(a): return tuple(x/math.sqrt(dot(a, a)) for x in a)
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def transpose(m): return tuple(zip(*m))
def mv(m, v): return tuple(dot(row, v) for row in m)
def mm(a, b): return tuple(tuple(dot(row, col) for col in transpose(b)) for row in a)
def basis(m):
    x=norm(m[0]); z=norm(cross(x, m[1])); return (x, cross(z, x), z)
def pose(p): return tuple(p.offset), transpose(basis(p.matrix))
def compose(a, b): return vadd(a[0], mv(a[1], b[0])), mm(a[1], b[1])
def relative(a, b): return mv(transpose(b[1]), vsub(a[0], b[0])), mm(transpose(b[1]), a[1])
def fp(p): return xa.FramePart(p[0], basis(transpose(p[1])))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def source(p):
    REPORT['sources'][str(p)] = digest(p)
    return p
def model(p):
    m=xm.Model(); m.LoadFile_Bin(str(source(p))); return m
def anim(p):
    a=xa.Anim(); a.LoadFile_Bin(str(source(p))); return a


def write_asset(obj, name, kind):
    folder = MODELS if kind=='XMODEL' else ANIMS
    folder.mkdir(parents=True, exist_ok=True)
    path=folder/(name+'.'+kind+'_EXPORT')
    obj.WriteFile_Raw(str(path))
    subprocess.run([str(TOOLS/'bin/export2bin.exe'), '/nt=8', '/o=.', path.name],
                   cwd=folder, check=True, capture_output=True)
    binary=path.with_suffix('.'+kind+'_BIN')
    REPORT['files'][binary.relative_to(ROOT).as_posix()]=digest(binary)
    return binary


def model_block(name, template):
    fields=dict(template)
    fields['filename']='tod_staff_pap\\\\'+name+'.XMODEL_BIN'
    # One explicitly audited high-detail mesh, no inherited legacy LODs.
    for key in list(fields):
        if key.startswith('lod') and 'filename' in key.lower(): fields[key]=''
        # 2026-10-01 (docs/167 item 4): a WORLD model also takes no GENERATED
        # LODs - the donor's 50/25/12/7/4% chain decimated the thin staff away
        # at range ("floating pieces"). tools/staff_world_lods.py gates it.
        if name.endswith('_wm') and key.startswith('autogen') and not key.endswith('Percent'): fields[key]='0'
    GDT.append((name, 'xmodel.gdf', fields))


def clip_block(name, clip, template, rigpath):
    binary=write_asset(clip, name, 'XANIM')
    fields=dict(template)
    fields.update(filename='tod_staff_pap\\\\'+binary.name, model=rigpath, useBones='0', looping='0')
    GDT.append((name, 'xanim.gdf', fields))
    REPORT['clips'][name]=dict(frames=len(clip.frames), fps=clip.framerate,
                              bones=len(clip.parts), sound=fields['customnote0actionparam1'])


def build_origins(origins, approved):
    rig=model(ROOT/'model_export/tod_staff_anim/tod_vm_staff_elements_skeleton.XMODEL_BIN')
    idx={b.name:i for i,b in enumerate(rig.bones)}
    rests=[relative(pose(b),pose(rig.bones[b.parent])) if b.parent>=0 else pose(b) for b in rig.bones]
    oldmodels=TOOLS/'model_export/sla/tod_staff'
    body_names={b.name for b in model(oldmodels/'tod_staff_view.xmodel_bin').bones}
    tips={e:model(oldmodels/('tod_staff_tip_'+e+'_view.xmodel_bin')) for e in ('water','fire','lightning')}
    head_names={b.name for piece in tips.values() for b in piece.bones}
    idle=anim(TEST/'xanim_export/tod_staff/vm_zom_staff_idle.XANIM_BIN')
    idle_idx={p.name:i for i,p in enumerate(idle.parts)}
    head_basis={b.name:pose(idle.frames[0].parts[idle_idx[piece.bones[0].name]])
                for piece in tips.values() for b in piece.bones}
    shift=tuple(json.loads(source(TEST/'docs/staff_ice_alignment_report.json').read_text())['position_shift'])
    for element in ('fire','lightning'):
        basename='wpn_t7_zmb_hd_staff_tip_'+element+'_upg_world_LOD0.XMODEL_BIN'
        path=next(EXTRACTED.rglob(basename))
        head=model(path)
        assert head.bones[0].name=='tag_tip_'+element
        assert max(abs(x) for x in head.bones[0].offset)<.001
        name='tod_staff_'+element+'_pap_tip'
        write_asset(head,name,'XMODEL')
        model_block(name,origins['tod_staff_tip_'+element+'_view'])
        REPORT['geometry'][name]=dict(vertices=sum(len(m.verts) for m in head.meshes),
            triangles=sum(len(m.faces) for m in head.meshes), bones=len(head.bones),
            source=path.relative_to(EXTRACTED).as_posix())
        raw=anim(TEST/('xanim_export/tod_staff/vm_zom_staff_t7_'+element+'_upg_first_raise.XANIM_BIN'))
        raw_idx={p.name:i for i,p in enumerate(raw.parts)}
        clip=copy.deepcopy(raw); clip.parts=[xa.PartInfo(b.name) for b in rig.bones]; clip.frames=[]
        for frame in raw.frames:
            authored={n:pose(frame.parts[i]) for n,i in raw_idx.items()}
            posed=[]
            for i,b in enumerate(rig.bones):
                n=b.name
                if n in ROOT_TRACKS: p=((0,0,0),IDENT)
                elif n=='j_elbow_bulge_le': p=pose(posed[b.parent])
                elif n in head_names and n in authored:
                    p=compose(pose(posed[idx['tag_tip']]),relative(authored[n],head_basis[n]))
                elif n in body_names and n in authored: p=compose(authored['tag_weapon_right'],authored[n])
                elif n in authored: p=authored[n]
                else: p=compose(pose(posed[b.parent]),rests[i]) if b.parent>=0 else rests[i]
                posed.append(fp(p))
            for n,i in idx.items():
                if n not in ROOT_TRACKS|{'tag_camera'}: posed[i].offset=vadd(posed[i].offset,shift)
            assert posed[idx['j_elbow_bulge_le']].offset==posed[idx['j_elbow_le']].offset
            f=xa.Frame(frame.frame); f.parts=posed; clip.frames.append(f)
        template=approved['tod_vm_staff_'+element+'_fit_t7_'+element+'_first_raise']
        clip_block('tod_staff_'+element+'_pap_first_raise',clip,template,template['model'])


def cast_curves(filename):
    reader=Path(os.environ.get('APPDATA',''))/'Blender Foundation/Blender/4.2/scripts/addons/io_scene_cast/cast.py'
    spec=importlib.util.spec_from_file_location('staff_cast',reader)
    cast=importlib.util.module_from_spec(spec);spec.loader.exec_module(cast)
    a=cast.Cast.load(str(source(BO6/filename))).Roots()[0].ChildrenOfType(cast.Animation)[0]
    curves={c.NodeName(): (list(c.KeyFrameBuffer()),list(c.KeyValueBuffer())) for c in a.Curves()
            if c.KeyPropertyName()=='rq' and c.NodeName() in BLADE_NAMES}
    assert set(curves)==set(BLADE_NAMES)
    return curves


def quaternion(curve, t):
    frames,values=curve
    qs=[tuple(values[i:i+4]) for i in range(0,len(values),4)]
    assert len(frames)==len(qs)
    if t<=frames[0]: return norm(qs[0])
    for i in range(1,len(frames)):
        if t>frames[i]: continue
        a=norm(qs[i-1]);b=norm(qs[i]);d=dot(a,b)
        if d<0: b=tuple(-x for x in b); d=-d
        f=(t-frames[i-1])/(frames[i]-frames[i-1])
        if d>.9995:return norm(tuple(x+(y-x)*f for x,y in zip(a,b)))
        angle=math.acos(min(1,d));den=math.sin(angle)
        return tuple((math.sin((1-f)*angle)*x+math.sin(f*angle)*y)/den for x,y in zip(a,b))
    return norm(qs[-1])


def qmatrix(q):
    x,y,z,w=norm(q)
    return ((1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)),
            (2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)),
            (2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)))


def posed_blades(m, curves, time):
    posed=[]
    for b in m.bones:
        p=relative(pose(b),pose(m.bones[b.parent])) if b.parent>=0 else pose(b)
        if b.name in curves: p=(p[0],qmatrix(quaternion(curves[b.name],time)))
        posed.append(compose(posed[b.parent],p) if b.parent>=0 else p)
    return posed


def bake_pose(m, poses):
    out=copy.deepcopy(m)
    rotations=[mm(p[1],transpose(pose(b)[1])) for p,b in zip(poses,m.bones)]
    for old,mesh in zip(m.meshes,out.meshes):
        for v,nv in zip(old.verts,mesh.verts):
            points=[(vadd(poses[i][0],mv(rotations[i],vsub(v.offset,m.bones[i].offset))),w) for i,w in v.weights]
            nv.offset=tuple(sum(p[j]*w for p,w in points) for j in range(3))
        for f in mesh.faces:
            for corner in f.indices:
                weights=mesh.verts[corner.vertex].weights
                normals=[(mv(rotations[i],corner.normal),w) for i,w in weights]
                corner.normal=norm(tuple(sum(n[j]*w for n,w in normals) for j in range(3)))
    for b,p in zip(out.bones,poses): b.offset=p[0];b.matrix=transpose(p[1])
    return out


def split_model(m, tip):
    socket=next(i for i,b in enumerate(m.bones) if b.name=='tag_barrel_attach')
    start=next(i for i,b in enumerate(m.bones) if b.name=='j_water')
    selected=[socket]+list(range(start,len(m.bones))) if tip else list(range(start))
    remap={old:new for new,old in enumerate(selected)}
    out=copy.deepcopy(m);out.bones=[out.bones[i] for i in selected]
    anchor=pose(m.bones[socket])
    for b in out.bones:
        b.parent=remap.get(b.parent,-1)
        if tip: p=relative(pose(b),anchor);b.offset=p[0];b.matrix=transpose(p[1])
    out.meshes=out.meshes[8:] if tip else out.meshes[:8]
    for mi,mesh in enumerate(out.meshes):
        for v in mesh.verts:
            v.weights=[(remap[i],w) for i,w in v.weights]
            if tip:v.offset=mv(transpose(anchor[1]),vsub(v.offset,anchor[0]))
        for f in mesh.faces:
            f.mesh_id=mi
            if tip:
                for c in f.indices:c.normal=mv(transpose(anchor[1]),c.normal)
    return out


def world_model(m):
    out=copy.deepcopy(m)
    r=((0,0,-1),(0,1,0),(1,0,0))
    for i,b in enumerate(out.bones):
        if i==0:continue
        b.offset=mv(r,vadd(b.offset,(11.667,0,0)));b.matrix=tuple(mv(r,a) for a in b.matrix)
    for mesh in out.meshes:
        for v in mesh.verts:v.offset=mv(r,vadd(v.offset,(11.667,0,0)))
        for f in mesh.faces:
            for c in f.indices:c.normal=mv(r,c.normal)
    return out


def build_ice(approved, templates, clips_only=False):
    original=model(ROOT/'model_export/tod_bo6_ice/tod_bo6_ice_vm.XMODEL_BIN')
    idle=cast_curves('t10_vm_ww_staff_upg_idle.cast')
    packed=None if clips_only else bake_pose(original,posed_blades(original,idle,0))
    template=templates['tod_bo6_ice_vm']
    pieces=[] if clips_only else [('vm',original,packed),('wm',world_model(original),world_model(packed))]
    for perspective,m,pm in pieces:
        body=split_model(m,False);tip=split_model(m,True);pap=split_model(pm,True)
        # Independent reconstruction: splitting must preserve EVERY original vertex.
        socket=pose(next(b for b in body.bones if b.name=='tag_barrel_attach'))
        error=max(math.dist(compose(socket,(v.offset,IDENT))[0],ov.offset)
                  for mesh,orig in zip(tip.meshes,m.meshes[8:]) for v,ov in zip(mesh.verts,orig.verts))
        assert error<.0001,error
        for suffix,piece in [('body',body),('tip',tip),('pap_tip',pap)]:
            name='tod_staff_ice_'+suffix+'_'+perspective
            write_asset(piece,name,'XMODEL');model_block(name,template)
            REPORT['geometry'][name]=dict(vertices=sum(len(x.verts) for x in piece.meshes),
                triangles=sum(len(x.faces) for x in piece.meshes),bones=len(piece.bones),
                reconstruction_error=error)
    # Append the actual BO6 weapon bones to the approved donor arm rig. Only
    # the four opening blades use BO6 motion; the tested hands keep their pose.
    rig=model(ROOT/'model_export/tod_staff_anim/tod_vm_staff_ice_skeleton.XMODEL_BIN')
    # Retain the arm/camera tree and weapon anchor, not the donor's unused
    # Origins tips/reload props/pistol. Adding BO6 to that entire union exceeds
    # 256 bones. All geometry weights belong to the retained arm tree.
    selected=[]
    for i,b in enumerate(rig.bones):
        if b.name in ('tag_view','tag_weapon','tag_flash') or (b.parent in selected and rig.bones[b.parent].name!='tag_weapon'):
            selected.append(i)
    remap={old:new for new,old in enumerate(selected)}
    rig.bones=[rig.bones[i] for i in selected]
    for b in rig.bones:b.parent=remap.get(b.parent,-1)
    for mesh in rig.meshes:
        for v in mesh.verts:v.weights=[(remap[i],w) for i,w in v.weights]
    idx={b.name:i for i,b in enumerate(rig.bones)}
    grip=pose(rig.bones[idx['tag_weapon']])
    for b in original.bones:
        if b.name in idx:continue
        n=copy.deepcopy(b)
        n.parent=idx[original.bones[b.parent].name]
        p=compose(grip,pose(b));n.offset=p[0];n.matrix=transpose(p[1])
        idx[n.name]=len(rig.bones);rig.bones.append(n)
    rig_name='tod_staff_ice_flourish_skeleton'
    assert len(rig.bones)<256,len(rig.bones)
    write_asset(rig,rig_name,'XMODEL')
    donor=anim(ROOT/'xanim_export/tod_staff_approved/tod_vm_staff_ice_fit_t7_water_first_raise.XANIM_BIN')
    donor_idx={p.name:i for i,p in enumerate(donor.parts)}
    for packed_flag in (False,True):
        curves=cast_curves('t10_vm_ww_staff_'+('upg_' if packed_flag else '')+'first_raise.cast')
        clip=copy.deepcopy(donor);clip.parts=[xa.PartInfo(b.name) for b in rig.bones];clip.frames=[]
        for fi,frame in enumerate(donor.frames):
            weapon_pose=pose(frame.parts[donor_idx['tag_weapon']])
            bo6poses=posed_blades(original,curves,fi*76/(len(donor.frames)-1))
            added={b.name:compose(weapon_pose,p) for b,p in zip(original.bones,bo6poses)}
            f=xa.Frame(frame.frame)
            f.parts=[copy.deepcopy(frame.parts[donor_idx[b.name]]) if b.name in donor_idx else fp(added[b.name]) for b in rig.bones]
            clip.frames.append(f)
        # PaP flourish ends at the same authored blade pose baked into the model.
        if packed_flag:
            for n in BLADE_NAMES:
                assert abs(dot(quaternion(curves[n],76),quaternion(idle[n],0)))>.9999
        name='tod_staff_ice_'+('pap_' if packed_flag else '')+'first_raise'
        clip_block(name,clip,approved['tod_vm_staff_ice_fit_t7_water_first_raise'],
                   'tod_staff_pap\\\\'+rig_name+'.XMODEL_BIN')


def main():
    global REPORT,GDT
    origins={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff_origins.gdt')}
    approved={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff_approved_anims.gdt')}
    ice={n:f for n,k,f in blocks(ROOT/'source_data/tod_bo6_ice_staff.gdt')}
    clips_only='--ice-clips-only' in sys.argv
    if clips_only:
        REPORT=json.loads((ROOT/'docs/staff_presentation_manifest.json').read_text())
        GDT=[(n,k,f) for n,k,f in blocks(ROOT/'source_data/tod_staff_pap.gdt')
             if k not in ('attachmentunique.gdf','xanim.gdf') or not (n.startswith('tod_staff_ice') or k=='attachmentunique.gdf')]
    else:build_origins(origins,approved)
    build_ice(approved,ice,clips_only)
    weapons={n:f for n,k,f in blocks(source(ROOT/'source_data/tod_weapon_twins.gdt'))}
    for element in ('fire','lightning','ice'):
        # Visual override: inherit timers/ammo/fire modes and explicitly retain
        # the shipping weapon's location multipliers against native DB defaults.
        shipped=shipping_staff_fields(element,weapons)
        none=attachment_fields(element,False,shipped)
        pap=attachment_fields(element,True,shipped)
        GDT.extend([('au_tod_staff_'+element+'_none','attachmentunique.gdf',none),
                    ('au_tod_staff_'+element+'_gmod6','attachmentunique.gdf',pap)])
    path=ROOT/'source_data/tod_staff_pap.gdt'
    path.write_text('{\n'+''.join(emit(*x) for x in GDT)+'}\n')
    REPORT['files'][path.relative_to(ROOT).as_posix()]=digest(path)
    (ROOT/'docs/staff_presentation_manifest.json').write_text(json.dumps(REPORT,indent=2)+'\n')
    print('Built PaP heads for all three staffs, two T7 upgraded flourishes and two BO6 blade flourishes.')


if __name__=='__main__':main()
