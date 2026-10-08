"""Read material bindings from the live reference-one donor, without editing it."""
import bpy,json
print(json.dumps({o.name:[m.name if m else None for m in o.data.materials]
    for o in bpy.context.scene.objects if o.type=='MESH' and 'attachment_bone' not in o and o.name!='Studio floor'},indent=2))
