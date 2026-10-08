"""Cyber Rampage Inducer - construction library for the live Blender studio (port 9884).

Units are GAME units (1 = 1 inch); the device stands on z=0 with its FRONT on +X,
exactly as the xmodel ships (gen_tower_map.js INDUCER_YAW 90 turns local +X to
north, into the arena). The arena's south wall sits 24 units behind the origin
(local x = -24), so nothing here may reach past x = -23.

Every exported part lives under the collection 'Inducer | master' and carries
`icyber_part` + `icyber_group` ('solid' = the baked opaque atlas, 'plasma' = the
scrolling transparent energy column). Studio dressing lives under
'Inducer | studio' and is never exported.

STATE IN ONE MATERIAL: every emissive material reads the custom property
`rampage_on` through an Attribute node of type INSTANCER (probed 2026-10-02 in
Cycles and EEVEE Next: a non-instanced object reads its own property, an
instanced one reads the instancing empty). The master has none (= OFF); the
studio's ON preview is a collection instance carrying rampage_on = 1; the bake
sets it on the joined kit to produce the ON emission map.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT/'art/rampage_inducer_cyber'
MASTER = ART/'rampage_inducer_cyber.blend'
MASTER_COLLECTION = 'Inducer | master'
STUDIO_COLLECTION = 'Inducer | studio'
PREFIX = 'RI | '
WALL_X = -24.0

scene = bpy.context.scene
_stage = {'col': None, 'name': None}


# ------------------------------------------------------------------ collections
def collection(name, parent=None):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        (parent or scene.collection).children.link(c)
    return c


def master_collection():
    return collection(MASTER_COLLECTION)


def studio_collection():
    return collection(STUDIO_COLLECTION)


MOVING_COLLECTION = 'Inducer | moving parts'


def moving_collection():
    """Animated parts live OUTSIDE the master collection: the ON preview instances
    the master (static parts) and carries its own fast-driven copies of these."""
    return collection(MOVING_COLLECTION)


def begin(stage):
    """Open (and empty) one stage's sub-collection: every stage is re-runnable."""
    col = collection(PREFIX + stage, master_collection())
    moving = moving_collection()
    doomed = list(col.objects) + [o for o in moving.objects if o.get('icyber_stage') == stage and o.type == 'MESH']
    for ob in doomed:
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if data is not None and data.users == 0:
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)
            elif isinstance(data, bpy.types.Curve):
                bpy.data.curves.remove(data)
    _stage['col'], _stage['name'] = col, stage
    return col


# ------------------------------------------------------------------ materials
def _nodes(m):
    m.use_nodes = True
    return m.node_tree.nodes, m.node_tree.links


def _principled(m):
    n, _ = _nodes(m)
    return n.get('Principled BSDF')


def surface(name, base, metal=0.0, rough=0.4, grain=0.0, grain_scale=60.0, vary=0.25, coat=0.0):
    """Hard-surface material with value variation and an optional micro grain.

    Variation and grain are what the bake turns into colour/gloss/normal detail;
    they are deliberately quiet so the in-game normal map never reads as noise.
    """
    full = PREFIX + name
    m = bpy.data.materials.get(full) or bpy.data.materials.new(full)
    n, l = _nodes(m)
    for node in list(n):
        if node.type not in ('OUTPUT_MATERIAL', 'BSDF_PRINCIPLED'):
            n.remove(node)
    b = n.get('Principled BSDF') or n.new('ShaderNodeBsdfPrincipled')
    out = next(x for x in n if x.type == 'OUTPUT_MATERIAL')
    l.new(b.outputs[0], out.inputs['Surface'])
    m.diffuse_color = (*base, 1)
    b.inputs['Base Color'].default_value = (*base, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Emission Strength'].default_value = 0.0
    tc = n.new('ShaderNodeTexCoord')
    if vary > 0:
        noise = n.new('ShaderNodeTexNoise'); noise.label = 'broad finish variation'
        noise.inputs['Scale'].default_value = 0.08; noise.inputs['Detail'].default_value = 3.0
        l.new(tc.outputs['Object'], noise.inputs['Vector'])
        ramp = n.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = 0.35; ramp.color_ramp.elements[1].position = 0.65
        ramp.color_ramp.elements[0].color = (*(c * (1 - vary) for c in base), 1)
        ramp.color_ramp.elements[1].color = (*(min(1.0, c * (1 + vary * 0.6)) for c in base), 1)
        l.new(noise.outputs['Fac'], ramp.inputs[0]); l.new(ramp.outputs[0], b.inputs['Base Color'])
        rr = n.new('ShaderNodeMapRange')
        rr.inputs['From Min'].default_value = 0.3; rr.inputs['From Max'].default_value = 0.7
        rr.inputs['To Min'].default_value = rough * 0.82; rr.inputs['To Max'].default_value = min(0.95, rough * 1.25)
        l.new(noise.outputs['Fac'], rr.inputs['Value']); l.new(rr.outputs[0], b.inputs['Roughness'])
    if grain > 0:
        g = n.new('ShaderNodeTexNoise'); g.label = 'machined micro grain'
        g.inputs['Scale'].default_value = grain_scale; g.inputs['Detail'].default_value = 2.0
        l.new(tc.outputs['Object'], g.inputs['Vector'])
        bump = n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = grain
        bump.inputs['Distance'].default_value = 0.02
        l.new(g.outputs['Fac'], bump.inputs['Height']); l.new(bump.outputs[0], b.inputs['Normal'])
    m['icyber_role'] = 'surface'
    return m


def state_attr(n):
    a = n.new('ShaderNodeAttribute'); a.attribute_type = 'INSTANCER'; a.attribute_name = 'rampage_on'
    a.label = 'rampage_on (0 OFF / 1 ON)'
    return a


def emissive(name, idle_rgb, on_rgb, idle_strength, on_strength, base=(0.02, 0.02, 0.025), rough=0.25, metal=0.0, facets=False):
    """Light material that changes colour and strength with `rampage_on`.
    facets=True multiplies glow and colour by the mesh's per-face `facet` tone."""
    full = PREFIX + name
    m = bpy.data.materials.get(full) or bpy.data.materials.new(full)
    n, l = _nodes(m)
    for node in list(n):
        if node.type not in ('OUTPUT_MATERIAL', 'BSDF_PRINCIPLED'):
            n.remove(node)
    b = n.get('Principled BSDF') or n.new('ShaderNodeBsdfPrincipled')
    out = next(x for x in n if x.type == 'OUTPUT_MATERIAL')
    l.new(b.outputs[0], out.inputs['Surface'])
    b.inputs['Base Color'].default_value = (*base, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    a = state_attr(n)
    mix = n.new('ShaderNodeMixRGB'); mix.blend_type = 'MIX'
    mix.inputs['Color1'].default_value = (*idle_rgb, 1); mix.inputs['Color2'].default_value = (*on_rgb, 1)
    l.new(a.outputs['Fac'], mix.inputs['Fac']); l.new(mix.outputs['Color'], b.inputs['Emission Color'])
    s = n.new('ShaderNodeMapRange')
    s.inputs['To Min'].default_value = idle_strength; s.inputs['To Max'].default_value = on_strength
    l.new(a.outputs['Fac'], s.inputs['Value'])
    if facets:
        f = n.new('ShaderNodeAttribute'); f.attribute_type = 'GEOMETRY'; f.attribute_name = 'facet'
        k = n.new('ShaderNodeMath'); k.operation = 'MULTIPLY'
        l.new(s.outputs[0], k.inputs[0]); l.new(f.outputs['Fac'], k.inputs[1])
        l.new(k.outputs[0], b.inputs['Emission Strength'])
        tint = n.new('ShaderNodeMixRGB'); tint.blend_type = 'MULTIPLY'; tint.inputs['Fac'].default_value = 1.0
        tint.inputs['Color1'].default_value = (*base, 1)
        l.new(f.outputs['Color'], tint.inputs['Color2']); l.new(tint.outputs[0], b.inputs['Base Color'])
    else:
        l.new(s.outputs[0], b.inputs['Emission Strength'])
    m.diffuse_color = (*idle_rgb, 1)
    m['icyber_role'] = 'emissive'
    m['icyber_idle'] = list(idle_rgb) + [idle_strength]
    m['icyber_on'] = list(on_rgb) + [on_strength]
    return m


def hazard(name='hazard stripes', a=(0.95, 0.36, 0.02), b=(0.018, 0.018, 0.02), scale=0.42):
    full = PREFIX + name
    m = bpy.data.materials.get(full) or bpy.data.materials.new(full)
    n, l = _nodes(m)
    for node in list(n):
        if node.type not in ('OUTPUT_MATERIAL', 'BSDF_PRINCIPLED'):
            n.remove(node)
    bs = n.get('Principled BSDF') or n.new('ShaderNodeBsdfPrincipled')
    out = next(x for x in n if x.type == 'OUTPUT_MATERIAL')
    l.new(bs.outputs[0], out.inputs['Surface'])
    tc = n.new('ShaderNodeTexCoord')
    wave = n.new('ShaderNodeTexWave'); wave.wave_type = 'BANDS'; wave.bands_direction = 'DIAGONAL'
    wave.wave_profile = 'SAW'; wave.inputs['Scale'].default_value = scale; wave.inputs['Distortion'].default_value = 0
    l.new(tc.outputs['Object'], wave.inputs['Vector'])
    ramp = n.new('ShaderNodeValToRGB'); ramp.color_ramp.interpolation = 'CONSTANT'
    ramp.color_ramp.elements[0].position = 0.0; ramp.color_ramp.elements[0].color = (*a, 1)
    ramp.color_ramp.elements[1].position = 0.5; ramp.color_ramp.elements[1].color = (*b, 1)
    l.new(wave.outputs['Fac'], ramp.inputs[0]); l.new(ramp.outputs[0], bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value = 0.42; bs.inputs['Metallic'].default_value = 0.15
    m.diffuse_color = (*a, 1)
    m['icyber_role'] = 'surface'
    return m


def plasma_preview(name='plasma column'):
    """Viewport stand-in for the in-game scrolling energy (a separate BO3 material).

    Vertical energy strands over a soft fill; the strands drift upward with the
    timeline (press Play in the viewport). The game uses generated textures on
    lit_emissive_scroll_transparent instead of this node tree.
    """
    full = PREFIX + name
    m = bpy.data.materials.get(full) or bpy.data.materials.new(full)
    n, l = _nodes(m)
    for node in list(n):
        if node.type != 'OUTPUT_MATERIAL':
            n.remove(node)
    out = next(x for x in n if x.type == 'OUTPUT_MATERIAL')
    m.blend_method = 'BLEND'
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        pass
    m.use_backface_culling = False
    tc = n.new('ShaderNodeTexCoord')
    mp = n.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (1.0, 1.0, 1.0)
    l.new(tc.outputs['UV'], mp.inputs['Vector'])
    fc = mp.inputs['Location'].driver_add('default_value', 1)
    fc.driver.expression = 'frame * 0.012'
    noise = n.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 3.0
    noise.inputs['Detail'].default_value = 6.0; noise.inputs['Roughness'].default_value = 0.62
    sep = n.new('ShaderNodeSeparateXYZ'); comb = n.new('ShaderNodeCombineXYZ')
    l.new(mp.outputs[0], sep.inputs[0])
    mul = n.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = 14.0
    l.new(sep.outputs['X'], mul.inputs[0]); l.new(mul.outputs[0], comb.inputs['X'])
    mul2 = n.new('ShaderNodeMath'); mul2.operation = 'MULTIPLY'; mul2.inputs[1].default_value = 1.4
    l.new(sep.outputs['Y'], mul2.inputs[0]); l.new(mul2.outputs[0], comb.inputs['Y'])
    l.new(comb.outputs[0], noise.inputs['Vector'])
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.46; ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.78; ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    l.new(noise.outputs['Fac'], ramp.inputs[0])
    a = state_attr(n)
    col = n.new('ShaderNodeMixRGB'); col.inputs['Color1'].default_value = (1.0, 0.55, 0.12, 1)
    col.inputs['Color2'].default_value = (1.0, 0.30, 0.05, 1); l.new(a.outputs['Fac'], col.inputs['Fac'])
    st = n.new('ShaderNodeMapRange'); st.inputs['To Min'].default_value = 1.6; st.inputs['To Max'].default_value = 9.0
    l.new(a.outputs['Fac'], st.inputs['Value'])
    strength = n.new('ShaderNodeMath'); strength.operation = 'MULTIPLY'
    l.new(ramp.outputs[0], strength.inputs[0]); l.new(st.outputs[0], strength.inputs[1])
    fill = n.new('ShaderNodeMath'); fill.operation = 'MULTIPLY_ADD'
    fill.inputs[1].default_value = 1.0; fill.inputs[2].default_value = 0.0
    l.new(strength.outputs[0], fill.inputs[0])
    em = n.new('ShaderNodeEmission'); l.new(col.outputs[0], em.inputs['Color']); l.new(fill.outputs[0], em.inputs['Strength'])
    tr = n.new('ShaderNodeBsdfTransparent')
    alpha = n.new('ShaderNodeMapRange'); alpha.inputs['To Min'].default_value = 0.10; alpha.inputs['To Max'].default_value = 0.85
    l.new(ramp.outputs[0], alpha.inputs['Value'])
    sepuv = n.new('ShaderNodeSeparateXYZ'); l.new(tc.outputs['UV'], sepuv.inputs[0])
    lo = n.new('ShaderNodeMapRange'); lo.inputs['From Max'].default_value = 0.18
    hi = n.new('ShaderNodeMapRange'); hi.inputs['From Min'].default_value = 1.0; hi.inputs['From Max'].default_value = 0.82
    l.new(sepuv.outputs['Y'], lo.inputs['Value']); l.new(sepuv.outputs['Y'], hi.inputs['Value'])
    ends = n.new('ShaderNodeMath'); ends.operation = 'MULTIPLY'
    l.new(lo.outputs[0], ends.inputs[0]); l.new(hi.outputs[0], ends.inputs[1])
    faded = n.new('ShaderNodeMath'); faded.operation = 'MULTIPLY'
    l.new(alpha.outputs[0], faded.inputs[0]); l.new(ends.outputs[0], faded.inputs[1])
    mix = n.new('ShaderNodeMixShader'); l.new(faded.outputs[0], mix.inputs['Fac'])
    l.new(tr.outputs[0], mix.inputs[1]); l.new(em.outputs[0], mix.inputs[2]); l.new(mix.outputs[0], out.inputs['Surface'])
    m.diffuse_color = (1.0, 0.5, 0.1, 0.4)
    m['icyber_role'] = 'plasma'
    return m


# The palette. Graphite chassis + titanium bands carry the map's cool steel; the
# STATUS lights speak the arena's cyan while idle and go rampage red when ON; the
# CORE family is the dim amber lamp the user asked for in v18.99i (OFF) that
# turns into a hot orange burn when ON.
def palette():
    P = {}
    P['graphite'] = surface('graphite armour', (0.032, 0.037, 0.048), metal=0.55, rough=0.36, grain=0.035, vary=0.22, coat=0.25)
    P['carbon'] = surface('carbon inner chassis', (0.012, 0.013, 0.017), metal=0.3, rough=0.5, grain=0.02, vary=0.15)
    P['titanium'] = surface('titanium bands', (0.30, 0.32, 0.36), metal=0.9, rough=0.27, grain=0.05, grain_scale=140, vary=0.12)
    P['steel'] = surface('machined steel', (0.55, 0.56, 0.58), metal=1.0, rough=0.22, grain=0.04, grain_scale=220, vary=0.08)
    P['copper'] = surface('copper windings', (0.42, 0.17, 0.07), metal=1.0, rough=0.3, grain=0.03, grain_scale=300, vary=0.12)
    P['rubber'] = surface('rubber conduit', (0.016, 0.016, 0.019), metal=0.0, rough=0.62, grain=0.04, grain_scale=90, vary=0.1)
    P['glass'] = surface('dark screen glass', (0.004, 0.005, 0.007), metal=0.0, rough=0.06, vary=0.0)
    P['hazard'] = hazard()
    P['status'] = emissive('status light', (0.0, 0.62, 1.0), (1.0, 0.10, 0.025), 4.0, 7.5)
    P['core'] = emissive('core light', (1.0, 0.40, 0.05), (1.0, 0.27, 0.03), 2.2, 9.0)
    P['crystal'] = emissive('fury crystal', (1.0, 0.45, 0.08), (1.0, 0.33, 0.05), 2.1, 12.0,
                            base=(0.55, 0.18, 0.03), rough=0.12, facets=True)
    P['meter_lo'] = emissive('meter low bars', (1.0, 0.42, 0.06), (1.0, 0.32, 0.04), 3.0, 7.0)
    P['meter_hi'] = emissive('meter high bars', (0.0, 0.0, 0.0), (1.0, 0.09, 0.02), 0.0, 8.5, base=(0.03, 0.012, 0.01))
    P['letters'] = emissive('rampage letters', (1.0, 0.46, 0.08), (1.0, 0.22, 0.03), 2.6, 8.0)
    P['plasma'] = plasma_preview()
    return P


# ------------------------------------------------------------------ objects
def make(name, verts, faces, mats, group='solid', smooth=30, mat_index=None):
    """One mesh object in the current stage; `smooth` = sharp-edge angle in degrees
    (None = flat). mat_index: per-face material slot list (default all 0)."""
    me = bpy.data.meshes.new(PREFIX + name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.validate(clean_customdata=False)
    me.update()
    if not isinstance(mats, (list, tuple)):
        mats = [mats]
    for m in mats:
        me.materials.append(m)
    if mat_index is not None:
        for p, i in zip(me.polygons, mat_index):
            p.material_index = i
    if smooth is not None:
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(smooth))
    ob = bpy.data.objects.new(PREFIX + name, me)
    (_stage['col'] or master_collection()).objects.link(ob)
    ob['icyber_part'] = True
    ob['icyber_group'] = group
    ob['icyber_stage'] = _stage['name'] or ''
    return ob


def from_bmesh(name, bm, mats, group='solid', smooth=30):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(PREFIX + name)
    bm.to_mesh(me); bm.free()
    if not isinstance(mats, (list, tuple)):
        mats = [mats]
    for m in mats:
        me.materials.append(m)
    if smooth is not None:
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(smooth))
    ob = bpy.data.objects.new(PREFIX + name, me)
    (_stage['col'] or master_collection()).objects.link(ob)
    ob['icyber_part'] = True
    ob['icyber_group'] = group
    ob['icyber_stage'] = _stage['name'] or ''
    return ob


def recalc_normals(ob):
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(ob.data); bm.free(); ob.data.update()
    return ob


def bevel(ob, width=0.3, segments=2, angle=35, harden=True, profile=0.6):
    m = ob.modifiers.new('Machined edge bevel', 'BEVEL')
    m.width = width; m.segments = segments; m.limit_method = 'ANGLE'
    m.angle_limit = math.radians(angle); m.profile = profile
    m.harden_normals = harden; m.miter_outer = 'MITER_ARC'
    w = ob.modifiers.new('Weighted surface normals', 'WEIGHTED_NORMAL')
    w.keep_sharp = True; w.mode = 'FACE_AREA'
    return ob


def lathe(name, profile, mat, seg=64, group='solid', smooth=40, close_bottom=True, close_top=True, start=0.0, end=None, closed=False):
    """Revolve a (radius, z) profile about Z. A radius of 0 collapses to a pole.

    BO3 culls back faces, so every lathe must be a CLOSED solid: either the
    profile starts and ends on the axis (poles), or `closed=True` joins the last
    ring back to the first (an annulus / collar)."""
    if closed:
        profile = list(profile) + [profile[0]]
        close_bottom = close_top = False
    full = end is None
    end = math.tau if full else end
    count = seg if full else seg + 1
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        ring = []
        for i in range(count):
            a = start + (end - start) * i / seg
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    if closed:
        bm.verts.remove(rings[-1][0]) if len(rings[-1]) == 1 else [bm.verts.remove(v) for v in rings[-1]]
        rings[-1] = rings[0]
    for ra, rb in zip(rings, rings[1:]):
        if len(ra) == 1 and len(rb) == 1:
            continue
        if len(ra) == 1 or len(rb) == 1:
            pole, ring = (ra[0], rb) if len(ra) == 1 else (rb[0], ra)
            for i in range(len(ring) - (0 if full else 1)):
                j = (i + 1) % len(ring)
                bm.faces.new((pole, ring[i], ring[j]))
            continue
        for i in range(len(ra) - (0 if full else 1)):
            j = (i + 1) % len(ra)
            bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    if full:
        if close_bottom and len(rings[0]) > 2:
            bm.faces.new(list(reversed(rings[0])))
        if close_top and len(rings[-1]) > 2:
            bm.faces.new(rings[-1])
    return from_bmesh(name, bm, mat, group, smooth)


def tube_uv(name, radius, z0, z1, mat, seg=48, rows=8, group='plasma'):
    """Open cylinder with U around / V along the height - the plasma column.
    Single-sided here; the exporter adds the reversed shell so BO3 draws both."""
    me = bpy.data.meshes.new(PREFIX + name)
    verts, faces, uvs = [], [], []
    for j in range(rows + 1):
        z = z0 + (z1 - z0) * j / rows
        for i in range(seg + 1):
            a = math.tau * i / seg
            verts.append((radius * math.cos(a), radius * math.sin(a), z))
    for j in range(rows):
        for i in range(seg):
            a = j * (seg + 1) + i
            faces.append((a, a + 1, a + seg + 2, a + seg + 1))
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            j, i = divmod(vi, seg + 1)
            uv.data[li].uv = (i / seg, j / rows)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    me.update()
    ob = bpy.data.objects.new(PREFIX + name, me)
    (_stage['col'] or master_collection()).objects.link(ob)
    ob['icyber_part'] = True; ob['icyber_group'] = group; ob['icyber_stage'] = _stage['name'] or ''
    return ob


def poly_chamfer_square(hx, hy, c):
    """Square (half sizes hx, hy) with 45-degree chamfered corners, CCW from +X."""
    return [(hx, -hy + c), (hx, hy - c), (hx - c, hy), (-hx + c, hy),
            (-hx, hy - c), (-hx, -hy + c), (-hx + c, -hy), (hx - c, -hy)]


def loft(name, polys, mat, group='solid', smooth=None, cap_bottom=True, cap_top=True):
    """Stack of same-count polygons [(z, [(x, y), ...]), ...] joined by side quads."""
    bm = bmesh.new()
    rings = [[bm.verts.new((x, y, z)) for x, y in pts] for z, pts in polys]
    for ra, rb in zip(rings, rings[1:]):
        k = len(ra)
        for i in range(k):
            j = (i + 1) % k
            bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    return from_bmesh(name, bm, mat, group, smooth)


def prism(name, pts, z0, z1, mat, group='solid', smooth=None):
    return loft(name, [(z0, pts), (z1, pts)], mat, group, smooth)


def box(name, center, size, mat, rot=(0, 0, 0), group='solid'):
    cx, cy, cz = center; hx, hy, hz = (s * 0.5 for s in size)
    pts = [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)]
    ob = prism(name, pts, -hz, hz, mat, group)
    ob.rotation_euler = rot
    ob.location = (cx, cy, cz)
    return ob


def torus(name, R, r, mat, seg=64, ring=12, center=(0, 0, 0), rot=(0, 0, 0), group='solid', smooth=60):
    bm = bmesh.new()
    rows = []
    for i in range(seg):
        a = math.tau * i / seg
        c, s = math.cos(a), math.sin(a)
        row = []
        for j in range(ring):
            b = math.tau * j / ring
            rr = R + r * math.cos(b)
            row.append(bm.verts.new((rr * c, rr * s, r * math.sin(b))))
        rows.append(row)
    for i in range(seg):
        a, b2 = rows[i], rows[(i + 1) % seg]
        for j in range(ring):
            k = (j + 1) % ring
            bm.faces.new((a[j], b2[j], b2[k], a[k]))
    ob = from_bmesh(name, bm, mat, group, smooth)
    ob.location = center; ob.rotation_euler = rot
    return ob


def catmull(points, steps=8):
    pts = [Vector(p) for p in points]
    if len(pts) < 3:
        return pts
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def sweep(name, path, section, mat, group='solid', smooth=50, caps=True, up=Vector((0, 0, 1)), twist_ref=None, scale_fn=None):
    """Sweep a closed 2D section [(u, v)] along a polyline with parallel-transport
    frames (no twisting). u runs along the frame's side axis, v along its normal.
    scale_fn(t) -> (su, sv) tapers the section along the path (t in 0..1)."""
    path = [Vector(p) for p in path]
    n = len(path)
    tangents = []
    for i in range(n):
        t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        tangents.append(t)
    ref = Vector(twist_ref) if twist_ref is not None else up
    side = tangents[0].cross(ref)
    if side.length < 1e-6:
        side = tangents[0].cross(Vector((1, 0, 0)))
    side.normalize()
    frames = []
    for i in range(n):
        if i > 0:
            axis = tangents[i - 1].cross(tangents[i])
            if axis.length > 1e-8:
                ang = tangents[i - 1].angle(tangents[i])
                side = Matrix.Rotation(ang, 3, axis.normalized()) @ side
        nrm = side.cross(tangents[i]).normalized()
        frames.append((side.copy(), nrm))
    lengths = [0.0]
    for i in range(1, n):
        lengths.append(lengths[-1] + (path[i] - path[i - 1]).length)
    total = lengths[-1] or 1.0
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(path):
        s, nr = frames[i]
        su, sv = scale_fn(lengths[i] / total) if scale_fn else (1.0, 1.0)
        rings.append([bm.verts.new(p + s * (u * su) + nr * (v * sv)) for u, v in section])
    k = len(section)
    for ra, rb in zip(rings, rings[1:]):
        for j in range(k):
            jj = (j + 1) % k
            bm.faces.new((ra[j], ra[jj], rb[jj], rb[j]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return from_bmesh(name, bm, mat, group, smooth)


def circle_section(r, sides=12):
    return [(r * math.cos(math.tau * i / sides), r * math.sin(math.tau * i / sides)) for i in range(sides)]


def rounded_rect_section(w, h, rad, per_corner=3):
    pts = []
    corners = [(w / 2 - rad, h / 2 - rad, 0), (-w / 2 + rad, h / 2 - rad, 90),
               (-w / 2 + rad, -h / 2 + rad, 180), (w / 2 - rad, -h / 2 + rad, 270)]
    for cx, cy, a0 in corners:
        for i in range(per_corner + 1):
            a = math.radians(a0 + 90 * i / per_corner)
            pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts


def cable(name, points, radius, mat, rib_every=0.0, rib=0.12, sides=12, steps=10, group='solid'):
    """Smooth conduit through `points`; optional corrugation ribs every N units."""
    path = catmull(points, steps)
    if rib_every > 0:
        fine = []
        for a, b in zip(path, path[1:]):
            seg = (b - a).length
            cuts = max(1, int(seg / (rib_every / 3)))
            for i in range(cuts):
                fine.append(a.lerp(b, i / cuts))
        fine.append(path[-1])
        path = fine
        lengths = [0.0]
        for i in range(1, len(path)):
            lengths.append(lengths[-1] + (path[i] - path[i - 1]).length)
        total = lengths[-1]

        def sf(t):
            phase = (t * total) / rib_every
            k = 1.0 + rib * (0.5 + 0.5 * math.cos(math.tau * phase))
            return (k, k)
        return sweep(name, path, circle_section(radius, sides), mat, group, scale_fn=sf)
    return sweep(name, path, circle_section(radius, sides), mat, group)


def crystal(name, length, radius, mat, seed, sides=7, center=(0, 0, 0), rot=(0, 0, 0), group='solid', taper=0.35):
    """Faceted crystal: convex hull of a jittered spindle (elongated along Z)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    zs = [-0.5, -0.3, -0.08, 0.12, 0.32, 0.5]
    for z in zs:
        if abs(z) >= 0.5:
            bm.verts.new((rnd.uniform(-0.04, 0.04) * radius, rnd.uniform(-0.04, 0.04) * radius, z * length))
            continue
        prof = (1.0 - (abs(z) / 0.5) ** 1.6) * (1 - taper * max(0.0, z)) + 0.06
        for i in range(sides):
            a = math.tau * (i + rnd.uniform(-0.18, 0.18)) / sides
            rr = radius * prof * rnd.uniform(0.82, 1.08)
            bm.verts.new((rr * math.cos(a), rr * math.sin(a), z * length + rnd.uniform(-0.04, 0.04) * length))
    bmesh.ops.convex_hull(bm, input=list(bm.verts))
    ob = from_bmesh(name, bm, mat, group, smooth=None)
    facet_tones(ob, seed)
    ob.location = center; ob.rotation_euler = rot
    return ob


def facet_tones(ob, seed):
    """Per-face brightness (0.35..1) the crystal material multiplies its glow and
    colour by - what makes a convex hull read as cut facets, in Blender AND baked."""
    rnd = random.Random(seed * 7919 + 13)
    me = ob.data
    attr = me.attributes.get('facet') or me.attributes.new('facet', 'FLOAT', 'CORNER')
    for p in me.polygons:
        v = rnd.uniform(0.35, 1.0)
        for li in p.loop_indices:
            attr.data[li].value = v
    return ob


def text_mesh(name, body, size, mat, location, rotation, extrude=0.06, font=None, spacing=1.1, group='solid'):
    cu = bpy.data.curves.new(PREFIX + name + ' text', 'FONT')
    cu.body = body; cu.size = size; cu.extrude = extrude
    cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.space_character = spacing
    if font is not None:
        cu.font = font
    tmp = bpy.data.objects.new('tmp_text', cu)
    scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True); bpy.data.curves.remove(cu)
    me.name = PREFIX + name
    me.materials.clear(); me.materials.append(mat)
    ob = bpy.data.objects.new(PREFIX + name, me)
    (_stage['col'] or master_collection()).objects.link(ob)
    ob.location = location; ob.rotation_euler = rotation
    ob['icyber_part'] = True; ob['icyber_group'] = group; ob['icyber_stage'] = _stage['name'] or ''
    return ob


def hex_bolt(name, center, normal, mat_head, r=0.42, h=0.3):
    """Hex bolt head on a surface: `normal` points out of the surface."""
    nrm = Vector(normal).normalized()
    pts = [(r * math.cos(math.tau * i / 6 + math.pi / 6), r * math.sin(math.tau * i / 6 + math.pi / 6)) for i in range(6)]
    ob = prism(name, pts, 0, h, mat_head, smooth=None)
    q = Vector((0, 0, 1)).rotation_difference(nrm)
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = q
    ob.location = center
    return ob


def radial(count, start_deg=0.0):
    return [math.radians(start_deg + 360.0 * i / count) for i in range(count)]


def frame_matrix(origin, x_axis, z_axis):
    z = Vector(z_axis).normalized(); x = Vector(x_axis).normalized()
    y = z.cross(x).normalized(); x = y.cross(z).normalized()
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


def place_on(ob, origin, x_axis, z_axis):
    """Orient an object built in its own XY (Z out of the surface) onto a surface
    frame. Uses matrix_basis (computed on access) - matrix_world of a brand-new
    object is stale until the next depsgraph update."""
    ob.rotation_mode = 'XYZ'
    ob.matrix_basis = frame_matrix(origin, x_axis, z_axis) @ ob.matrix_basis
    return ob


def apply_transform(ob):
    """Bake the object transform into its mesh (keeps exports and bevels honest)."""
    me = ob.data
    me.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    me.update()
    return ob


# ------------------------------------------------------------------ the animation rig
import importlib as _il
import anim_spec as A
_il.reload(A)


def _rig_empty(name, parent=None, col=None):
    ob = bpy.data.objects.get(name)
    if ob is None:
        ob = bpy.data.objects.new(name, None)
        (col or moving_collection()).objects.link(ob)
    ob.empty_display_type = 'PLAIN_AXES'; ob.empty_display_size = 1.5
    ob.parent = parent
    if parent is not None:
        ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.hide_render = True
    return ob


def rig_chain(bone, prefix='RI rig | ', col=None, base=(0.0, 0.0, 0.0)):
    """outer (pivot + bob, yaw) -> tilt (fixed) -> inner (shiver X, spin Z).
    Rotation orders reproduce anim_spec.pose(): Rz(yaw).Tilt.Rx(shiver).Rz(spin)."""
    spec = A.BONES[bone]
    outer = _rig_empty(prefix + bone, None, col)
    outer.rotation_mode = 'XYZ'
    outer.location = (spec['pivot'][0] + base[0], spec['pivot'][1] + base[1], spec['pivot'][2] + base[2])
    outer.rotation_euler = (0, 0, 0)
    tilt = _rig_empty(prefix + bone + ' tilt', outer, col)
    tilt.rotation_mode = 'YXZ'
    tilt.rotation_euler = (math.radians(spec['tilt'][0]), math.radians(spec['tilt'][1]), 0)
    tilt.location = (0, 0, 0)
    inner = _rig_empty(prefix + bone + ' spin', tilt, col)
    inner.rotation_mode = 'ZYX'
    inner.rotation_euler = (0, 0, 0); inner.location = (0, 0, 0)
    return outer, tilt, inner


def rest_parent_matrix(bone, base=(0.0, 0.0, 0.0)):
    spec = A.BONES[bone]
    m = Matrix.Translation(Vector(spec['pivot']) + Vector(base))
    tx, ty = spec['tilt']
    m = m @ (Matrix.Rotation(math.radians(tx), 4, 'X') @ Matrix.Rotation(math.radians(ty), 4, 'Y'))
    return m


def tilt_about_pivot(ob, bone):
    """Turn geometry authored flat (at the pivot) into the bone's rest tilt."""
    spec = A.BONES[bone]
    pv = Matrix.Translation(Vector(spec['pivot']))
    tx, ty = spec['tilt']
    r = Matrix.Rotation(math.radians(tx), 4, 'X') @ Matrix.Rotation(math.radians(ty), 4, 'Y')
    ob.data.transform(pv @ r @ pv.inverted())
    ob.data.update()
    return ob


def rig_bone(ob, bone):
    """Attach an exported part to an animated bone (kept at its rest place)."""
    assert bone in A.BONES, bone
    ob['icyber_bone'] = bone
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    moving_collection().objects.link(ob)
    outer, tilt, inner = rig_chain(bone)
    ob.parent = inner
    ob.matrix_parent_inverse = rest_parent_matrix(bone).inverted()
    return ob


def _drive(ob, path, index, expr):
    try:
        ob.driver_remove(path, index)
    except TypeError:
        pass
    fc = ob.driver_add(path, index)
    fc.driver.type = 'SCRIPTED'
    fc.driver.expression = expr
    for mod in list(fc.modifiers):
        fc.modifiers.remove(mod)
    return fc


def drive_chain(bone, clip, prefix='RI rig | ', base=(0.0, 0.0, 0.0)):
    """Timeline drivers = anim_spec.angles() (simple expressions, no Python)."""
    n = A.CLIPS[clip]; m = A.MOTION[clip][bone]; spec = A.BONES[bone]
    outer = bpy.data.objects[prefix + bone]
    inner = bpy.data.objects[prefix + bone + ' spin']
    w = 2 * math.pi / n
    _drive(outer, 'rotation_euler', 2, '%.9f*frame' % (w * m['yaw']))
    z0 = spec['pivot'][2] + base[2]
    if m['bob_cycles']:
        _drive(outer, 'location', 2, '%.6f+%.6f*sin(%.9f*frame)' % (z0, m['bob'], w * m['bob_cycles']))
    else:
        _drive(outer, 'location', 2, '%.6f' % z0)
    if m['shiver_cycles']:
        _drive(inner, 'rotation_euler', 0, '%.9f*sin(%.9f*frame)' % (math.radians(m['shiver']), w * m['shiver_cycles']))
    else:
        _drive(inner, 'rotation_euler', 0, '0.0')
    _drive(inner, 'rotation_euler', 2, '%.9f*frame' % (w * m['spin']))


ON_PREVIEW_OFFSET = (0.0, -85.0, 0.0)
ON_PREFIX = 'RI ON rig | '


def sync_rig():
    """(Re)drive the master rig at IDLE speed and rebuild the ON preview's moving
    copies (linked mesh data, rampage_on = 1, ON speed) beside the instance."""
    studio = studio_collection()
    for ob in list(studio.objects):
        if ob.get('icyber_on_moving'):
            bpy.data.objects.remove(ob, do_unlink=True)
    bones = sorted({o['icyber_bone'] for o in moving_collection().objects if o.get('icyber_bone')})
    for bone in bones:
        drive_chain(bone, 'idle')
        outer, tilt, inner = rig_chain(bone, ON_PREFIX, studio, ON_PREVIEW_OFFSET)
        for e in (outer, tilt, inner):
            e['icyber_on_moving'] = True; e['icyber_studio'] = True
        drive_chain(bone, 'on', ON_PREFIX, ON_PREVIEW_OFFSET)
        for src in [o for o in moving_collection().objects if o.get('icyber_bone') == bone and o.type == 'MESH']:
            dup = src.copy()
            for k in ('icyber_part', 'icyber_group', 'icyber_stage', 'icyber_bone'):
                if k in dup:
                    del dup[k]
            dup['rampage_on'] = 1.0; dup['icyber_on_moving'] = True; dup['icyber_studio'] = True
            studio.objects.link(dup)
            dup.parent = inner
            dup.matrix_parent_inverse = rest_parent_matrix(bone, ON_PREVIEW_OFFSET).inverted() @ Matrix.Translation(Vector(ON_PREVIEW_OFFSET))
            dup.name = 'RI ON preview | ' + src.name[len(PREFIX):]
    return bones


def arc_tube(name, R, r, a0, a1, mat, z=0.0, sides=8, steps=24, group='solid'):
    """A capped arc of tube (a halo segment) in the XY plane at height z."""
    path = [Vector((R * math.cos(a0 + (a1 - a0) * i / steps), R * math.sin(a0 + (a1 - a0) * i / steps), z))
            for i in range(steps + 1)]
    return sweep(name, path, circle_section(r, sides), mat, group, smooth=60)


# ------------------------------------------------------------------ saving / views
def save(stage):
    ART.mkdir(parents=True, exist_ok=True)
    scene['inducer_stage'] = stage
    scene['inducer_authoring'] = 'Blender MCP execute_blender_code, isolated localhost:9884'
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
    parts = [o for o in scene.objects if o.get('icyber_part')]
    tris = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in parts:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles(); tris += len(me.loop_triangles)
        ev.to_mesh_clear()
    print('INDUCER_STAGE_SAVED', stage, 'parts', len(parts), 'tris', tris, flush=True)


def view_camera(zoom=0):
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                sp = area.spaces.active
                sp.region_3d.view_perspective = 'CAMERA'
                sp.region_3d.view_camera_zoom = zoom
                sp.region_3d.view_camera_offset = (0, 0)
