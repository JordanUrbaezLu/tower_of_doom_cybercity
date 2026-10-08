import bpy
rig=bpy.data.objects['Cybercity_zombie_rig']
for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
parts=[ob for ob in bpy.context.scene.objects if 'attachment_bone' in ob]
for ob in parts:
    for mod in list(ob.modifiers):
        if mod.type=='ARMATURE':ob.modifiers.remove(mod)
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
evaluated=[(ob,bpy.data.meshes.new_from_object(ob.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)) for ob in parts]
for ob,geometry in evaluated:
    ob.data=geometry
    for mod in list(ob.modifiers):ob.modifiers.remove(mod)
    ob.vertex_groups.clear();vg=ob.vertex_groups.new(name=ob['attachment_bone'])
    vg.add(list(range(len(geometry.vertices))),1,'REPLACE')
    mod=ob.modifiers.new('Original joint','ARMATURE');mod.object=rig
    ob['bevel_geometry_finalized']=True
print('EVALUATED_BEVELS_RIGIDLY_BOUND',len(parts))
