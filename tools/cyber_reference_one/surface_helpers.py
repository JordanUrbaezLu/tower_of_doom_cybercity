"""Surface primitives frozen from revision four for independent reference-one authoring."""

def mesh(name,verts,faces,mat,bone='j_spine4',bevel=0):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob);return attach(ob,name,mat,bone,bevel)

def box(name,loc,dims,mat=steel,bone='j_spine4',frame=None,bevel=.045):
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object;ob.dimensions=dims
    if frame is not None:ob.rotation_euler=frame.to_euler()
    return attach(ob,name,mat,bone,bevel)

def cyl(name,loc,radius,depth,mat=edge,bone='j_spine4',axis=(0,0,1),sides=24):
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=depth,location=loc)
    ob=bpy.context.object;ob.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    for p in ob.data.polygons:p.use_smooth=len(p.vertices)==4
    return attach(ob,name,mat,bone,min(.035,depth*.12))

def tube(name,points,radius=.12,mat=magenta,bone='j_spine4',smooth=True):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=10;cu.bevel_depth=radius;cu.bevel_resolution=3
    sp=cu.splines.new('BEZIER' if smooth else 'POLY')
    if smooth:
        sp.bezier_points.add(len(points)-1)
        for p,co in zip(sp.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    else:
        sp.points.add(len(points)-1)
        for p,co in zip(sp.points,points):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
    return attach(bpy.context.object,name,mat,bone)

def basis(n,up=Vector((0,0,1))):
    n=Vector(n).normalized();u=(Vector(up)-n*Vector(up).dot(n)).normalized();r=n.cross(u).normalized()
    return r,n,u,Matrix((r,n,u)).transposed()

def bolt(name,p,n,bone='j_spine4',r=.13):
    p=Vector(p);n=Vector(n);cyl(name+' washer',p,r*1.35,.045,rubber,bone,n)
    cyl(name+' hex head',p+n*.065,r,.10,edge,bone,n,6)
    right,_,up,frame=basis(n)
    box(name+' recessed slot',p+n*.122,(r*1.1,.012,.026),rubber,bone,frame,.003)

def panel(name,p,n,width,height,bone='j_spine4',mat=ivory,up=Vector((0,0,1)),depth=.22,fasteners=True):
    p=Vector(p);r,n,u,frame=basis(n,up)
    # Asymmetric manufactured outline: cut corners, slightly tapered lower edge.
    shape=[(-.48,-.34),(-.37,-.50),(.31,-.50),(.48,-.35),(.50,.36),(.34,.50),(-.36,.50),(-.5,.33)]
    vs=[p+r*x*width+u*z*height+n*d for d in (0,depth) for x,z in shape]
    fs=[tuple(range(7,-1,-1)),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    mesh(name,vs,fs,mat,bone,.035)
    if fasteners:
        for x,z in [(-.33,-.32),(.33,-.32),(-.33,.32),(.33,.32)]:bolt(name,p+r*x*width+u*z*height+n*(depth+.02),n,bone,min(.13,width*.075))
    return p+n*depth,r,n,u,frame

def bvh(objects,accept=None):
    vs=[];fs=[]
    for ob in objects:
        offset=len(vs);coords=[ob.matrix_world@v.co for v in ob.data.vertices];vs.extend(coords)
        for poly in ob.data.polygons:
            center=sum((coords[i] for i in poly.vertices),Vector())/len(poly.vertices)
            if accept is None or accept(center):fs.append(tuple(offset+i for i in poly.vertices))
    assert fs;return BVHTree.FromPolygons(vs,fs)

def skin(x,z,back=False,gap=.12):
    p,n,idx,d=surface.ray_cast(Vector((x,24 if back else -24,z)),Vector((0,-1 if back else 1,0)),48)
    assert p is not None,('no torso surface',key,x,z,back)
    return p+Vector((0,gap if back else -gap,0))

def torso_panel(name,x,z,w,h,back=False,mat=ivory):
    n=Vector((0,1 if back else -1,0));p=skin(x,z,back,.16)
    # Rigid plate bridges the measured cloth relief instead of intersecting it.
    hits=[skin(x+dx*w,z+dz*h,back,.13) for dx in (-.42,0,.42) for dz in (-.4,0,.4)]
    p.y=(max(v.y for v in hits) if back else min(v.y for v in hits))
    box(name+' padded backing',p-n*.06,(w*.94,.18,h*.94),web)
    return panel(name,p,n,w,h,mat=mat)

def limb(b0,b1,objects=body):
    a=rig.matrix_world@rig.data.bones[b0].head_local;b=rig.matrix_world@rig.data.bones[b1].head_local
    axis=(b-a).normalized();length=(b-a).length
    front=Vector((0,-1,.15));front=(front-axis*front.dot(axis)).normalized();side=front.cross(axis).normalized()
    if b0.endswith('_ri'):side=-side
    def accept(p):
        d=p-a;t=d.dot(axis)/length;return -.22<t<1.22 and (d-axis*d.dot(axis)).length<6.2
    tree=bvh(objects,accept);radii=[]
    def radius_at(t,angle):
        c=a.lerp(b,t);direction=front*math.cos(angle)+side*math.sin(angle)
        p,n,idx,dist=tree.ray_cast(c+direction*9,-direction,9)
        return (p-c).dot(direction) if p is not None else None
    def point(t,angle,gap=.1):
        c=a.lerp(b,t);direction=front*math.cos(angle)+side*math.sin(angle)
        radius=radius_at(t,angle)
        if radius is None or radius<.30:
            # Torn cloth has actual holes. Bridge only the missing angular span
            # from its measured rims; never ray through to the opposite wall.
            rims=[]
            for sign in (-1,1):
                for step in range(1,21):
                    r=radius_at(t,angle+sign*step*math.pi/40)
                    if r is not None and r>=.30:rims.append((r,step));break
            assert len(rims)==2,('no measured rims around donor tear',key,b0,t,angle)
            radius=(rims[0][0]*rims[1][1]+rims[1][0]*rims[0][1])/(rims[0][1]+rims[1][1])
        assert .29<radius<7,(b0,radius)
        radii.append(radius);return c+direction*(radius+gap),direction
    return a,b,axis,length,front,side,point,radii

def strap(name,point,t,width,length,bone):
    # Two closed bands; inner vertices follow the donor mesh independently.
    N=40;vs=[]
    for gap in (.08,.19):
        for row in (-.5,0,.5):
            for j in range(N):vs.append(point(t+row*width/length,j*math.tau/N,gap)[0])
    fs=[];count=3*N
    for layer in (0,count):
        for row in range(2):
            for j in range(N):a=layer+row*N+j;b=layer+row*N+(j+1)%N;fs.append((a,b,b+N,a+N))
    for row in (0,2):
        for j in range(N):a=row*N+j;b=row*N+(j+1)%N;fs.append((a,b,b+count,a+count))
    mesh(name,vs,fs,web,bone)

def headpoint(x,z,side=False,gap=.08):
    if side:
        sign=1 if x>=0 else -1;origin=Vector((sign*12,x if abs(x)<1 else -.2,z));direction=Vector((-sign,0,0))
    else:origin=Vector((x,-16,z));direction=Vector((0,1,0))
    p,n,i,d=headsurface.ray_cast(origin,direction,30);assert p is not None,('head fit',key,x,z)
    return p-direction*gap,-direction