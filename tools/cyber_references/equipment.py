"""Shared detailed MCP authoring primitives; original R1 library remains immutable."""
from pathlib import Path
_here=Path(__file__).resolve().parent
_lib=_here.parent/'cyber_reference_one/lib.py'
__file__=str(_lib)
_source=_lib.read_text().replace("assert scene.get('reference_one_mcp'), 'Use 00_open.py in this task session first'", "assert scene.get('cyber_reference_number') in (2,3)")
_source=_source.replace("and o.name!='Studio floor'", "and o.name!='Studio floor' and not o.get('arm_replacement_display')")
exec(compile(_source,str(_lib),'exec'),globals())
__file__=str(_here/'equipment.py')
OUT=Path(scene['cyber_study_output']);REFERENCE=scene['cyber_reference_number'];WORD={2:'two',3:'three'}[REFERENCE]
key='reference_'+WORD
_donor_limb=limb
def limb(b0,b1,objects=body):
    result=_donor_limb(b0,b1,objects)
    a,b,axis,length,front,side,point,radii=result
    def measured_point(t,angle,gap=.1):
        try:return point(t,angle,gap)
        except AssertionError as original:
            # Some armored trousers have whole missing transverse patches. Bridge
            # from nearby measured longitudinal rims, preserving the local axis.
            rims=[]
            for sign in (-1,1):
                for step in range(1,9):
                    sample=t+sign*step*.025
                    if not .015<sample<.97:continue
                    try:p,n=point(sample,angle,gap)
                    except AssertionError:continue
                    rims.append((p-a.lerp(b,sample),abs(sample-t),n));break
            if not rims:raise original
            offset=sum((v/d for v,d,n in rims),Vector())/sum(1/d for v,d,n in rims)
            measurements.append({'bone':b0,'bridged_t':t,'angle':angle,'longitudinal_rim_distances':[d*length for v,d,n in rims]})
            return a.lerp(b,t)+offset,rims[0][2]
    return a,b,axis,length,front,side,measured_point,radii
def save(stage):
    scene['cyber_authoring_stage']=stage
    for o in scene.objects:
        if 'attachment_bone' in o:o['equipment_revision']=6
    assert json.loads(scene['donor_signatures'])=={o.name:signature(o) for o in base},'Donor changed'
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/('reference_'+WORD+'.blend')))
    print('REFERENCE_STAGE_OK',REFERENCE,stage,'objects',sum('attachment_bone' in o for o in scene.objects))

def armored_display(donor):
    # Blender truncates long object names. Old display copies predate the
    # explicit donor key; each immutable body3 submesh has a unique vertex count.
    candidates=[o for o in scene.objects if o.get('arm_replacement_display') and
                (o.get('arm_replacement_donor')==donor.name or
                 (not o.get('arm_replacement_donor') and len(o.data.vertices)==len(donor.data.vertices)))]
    assert len(candidates)==1,(donor.name,[o.name for o in candidates])
    display=candidates[0]
    display['arm_replacement_donor']=donor.name
    display.name='Arm replacement | '+donor.name.rsplit(' | ',1)[-1]
    return display

def glow_slot(name,p,n,w,h,bone='j_spine4',up=Vector((0,0,1)),color=cyan):
    p=Vector(p);r,n,u,f=basis(n,up)
    box(name+' recessed gasket',p,(w+.18,.17,h+.22),rubber,bone,f,.05)
    box(name+' phosphor glass',p+n*.10,(w,.07,h),color,bone,f,.025)
    for sx in (-1,1):box(name+' metal lip',p+r*sx*(w/2+.11),( .10,.20,h+.35),edge,bone,f,.025)

def fitted_shell(name,point,t0,t1,angle,width,bone,mat=ivory,gap=.26):
    # Separate angular and longitudinal surface samples: fit both slim wrists and large armor.
    N=16;M=4;verts=[]
    for dep in (0,.20):
        for i in range(M+1):
            t=t0+(t1-t0)*i/M
            for j in range(N+1):
                a=angle+(j/N-.5)*width
                p,n=point(t,a,gap+dep);verts.append(p)
    count=(M+1)*(N+1);faces=[]
    for off in (0,count):
        for i in range(M):
            for j in range(N):q=off+i*(N+1)+j;faces.append((q,q+1,q+N+2,q+N+1))
    for i in (0,M):
        for j in range(N):q=i*(N+1)+j;faces.append((q,q+1,q+1+count,q+count))
    for j in (0,N):
        for i in range(M):q=i*(N+1)+j;faces.append((q,q+N+1,q+N+1+count,q+count))
    return mesh(name,verts,faces,mat,bone,.035)

def buckle(name,p,n,bone,up):
    pp,r,n,u,f=panel(name+' leather tab',p,n,1.12,1.05,bone,web,up,depth=.10,fasteners=False)
    for x in (-.44,.44):box(name+' open buckle side',pp+r*x+n*.08,(.12,.14,.78),edge,bone,f,.025)
    for z in (-.35,.35):box(name+' buckle bar',pp+u*z+n*.08,(.89,.14,.12),edge,bone,f,.025)
    rod(name+' tongue',pp-u*.28+n*.13,pp+u*.24+n*.13,.045,steel,bone,12)

def ribbed_hose(name,points,r=.19,bone='j_spine4'):
    ob=hose(name,points,r,magenta,bone,False)
    # Reinforcement follows actual tube center samples, never chords across curved hoses.
    vs=ob.data.vertices;centers=[sum((v.co for v in vs[i:i+10]),Vector())/10 for i in range(0,len(vs),10)]
    rib=mat('pressure hose dark reinforcement',(.038,.004,.018),'rubber')
    traveled=0
    for i in range(1,len(centers)-1):
        traveled+=(centers[i]-centers[i-1]).length
        if traveled>.40:
            ring(name+' molded reinforcement',centers[i],centers[i+1]-centers[i-1],r*1.015,.024,rib,bone);traveled=0
    return ob
