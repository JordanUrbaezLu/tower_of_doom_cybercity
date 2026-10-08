"""Blender node-aware channel bake for the cyber equipment's native fullspec shader."""
import bpy

EMISSION_SCALE=6.0

def wire_channel(material, channel, emission_scale=EMISSION_SCALE):
    ns=material.node_tree.nodes;links=material.node_tree.links
    bs=ns.get('Principled BSDF');out=next(n for n in ns if n.type=='OUTPUT_MATERIAL')
    def input_value(name):
        inp=bs.inputs[name]
        if inp.is_linked:return inp.links[0].from_socket
        val=inp.default_value
        node=ns.new('ShaderNodeRGB' if hasattr(val,'__len__') else 'ShaderNodeValue')
        node.outputs[0].default_value=tuple(val) if hasattr(val,'__len__') else val
        return node.outputs[0]
    def math(op,a,b):
        n=ns.new('ShaderNodeMath');n.operation=op
        for socket,value in zip(n.inputs,(a,b)):
            if isinstance(value,(int,float)):socket.default_value=value
            else:links.new(value,socket)
        return n.outputs[0]
    emit=ns.new('ShaderNodeEmission');emit.inputs['Strength'].default_value=1
    if channel=='c':source=input_value('Base Color')
    elif channel=='g':source=math('SUBTRACT',1,input_value('Roughness'))
    elif channel=='s':
        # Fullspec = dielectric F0 .04 blended to base color by metallic.
        mix=ns.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[1].default_value=(.04,.04,.04,1)
        links.new(input_value('Metallic'),mix.inputs[0]);links.new(input_value('Base Color'),mix.inputs[2]);source=mix.outputs[0]
    elif channel=='e':
        source=input_value('Emission Color')
        # Store relative radiance in LDR, then reconstruct with GDT scaleRGB.
        # Keeps the eye core brighter than lamps without clipping everything.
        assert emission_scale > 0
        links.new(math('DIVIDE',input_value('Emission Strength'),emission_scale),emit.inputs['Strength'])
    else:raise ValueError(channel)
    links.new(source,emit.inputs['Color']);links.new(emit.outputs[0],out.inputs['Surface'])
