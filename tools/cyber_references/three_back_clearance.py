"""Support the pressure vessels beyond the enlarged dorsal spikes."""
from equipment import *
assert REFERENCE==3
offset=7.25
previous=scene.get('armored_backpack_clearance_offset',0.0)
delta=offset-previous
contacts=('Back | harness cushion','Back | folded mounting foot')
for ob in list(scene.objects):
    if ob.name.startswith('Back standoff |'):
        bpy.data.objects.remove(ob,do_unlink=True)
    elif ob.type=='MESH' and ob.name.startswith('Back |') and not ob.name.startswith(contacts):
        local=ob.matrix_world.to_3x3().inverted()@Vector((0,delta,0))
        for v in ob.data.vertices:v.co+=local
        ob.data.update()
scene['armored_backpack_clearance_offset']=offset

foot=next(o for o in scene.objects if o.name=='Back | folded mounting foot')
center=sum((foot.matrix_world@v.co for v in foot.data.vertices),Vector())/len(foot.data.vertices)
start_y=center.y
alloy=mat('vented backpack cantilever alloy',(.16,.19,.20),'metal')
# Four real open relief slots in boxed cantilevers, rather than painted holes.
outer=[(0,0),(offset,0),(offset,.94),(offset-1.35,1.15),(0,.56)]
inner=[(.90,.15),(offset-.50,.15),(offset-.50,.72),(offset-1.45,.90),(.90,.39)]
for side in (-1,1):
    x=side*3.60
    for z in (47.05,57.80):
        verts=[]
        for thickness in (-.12,.12):
            for loop in (outer,inner):
                verts.extend(Vector((x+thickness,start_y+y,z+h)) for y,h in loop)
        faces=[];count=len(outer)
        for i in range(count):
            j=(i+1)%count
            faces.extend(((i,j,count+j,count+i),
                          (2*count+i,3*count+i,3*count+j,2*count+j),
                          (i,2*count+i,2*count+j,j),
                          (count+i,count+j,3*count+j,3*count+i)))
        mesh('Back standoff | slotted cantilever',verts,faces,alloy,bevel=.025)
        normal=Vector((side,0,0))
        for y,h in ((.24,.25),(offset-.26,.43)):
            q=Vector((x+side*.15,start_y+y,z+h))
            bolt('Back standoff | captive mounting screw',q,normal,r=.15)
        # Lower feet use a short folded lug to reach the unchanged vest pad.
        if z<50:
            rod('Back standoff | folded lower root support',
                (x,start_y,47.39),(x,start_y,48.18),.16,steel,sides=8)
        label('Back standoff | stamped clearance serial','SPK / 30',
              (x+side*.145,start_y+offset*.62,z+.82),normal,.14,up=Vector((0,1,0)))

vessels=[o for o in scene.objects if o.name.startswith('Back |') and
         ('pressure housing' in o.name or 'smoked chamber envelope' in o.name)]
front=min((o.matrix_world@v.co).y for o in vessels for v in o.data.vertices)
spikes=json.loads(scene['armored_back_spikes'])
tip=max(-s['scaled_bounds'][0][0] for s in spikes['spikes'])
clearance=front-tip
assert clearance>1.50,(front,tip,clearance)
scene['armored_backpack_clearance']=json.dumps({'offset':offset,'pressure_vessel_front':front,
     'maximum_dorsal_spike_tip':tip,'minimum_bind_pose_depth_clearance':clearance,
     'original_contact_feet_retained':True,'supports':'four open slotted cantilevers'})
print('ARMORED_BACK_CLEARANCE',scene['armored_backpack_clearance'],flush=True)
