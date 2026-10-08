"""Blender 4.2 (background), phase 2 of tools/fan_props/build_sign_relief.py: the cleaned depth grid -> a relief mesh.

Input  <stage>/grid.npz  D (rows top-down, units off the back plane), M (covered), y0, z1, step (units per cell)
Output <stage>/low.npz   V (verts, the sign's BO3 frame), tv (tris, Blender CCW about the outward normal),
                         tn (corner normals), tuv (front-projected UVs, v up) - build_fan_props' save_low format
       <stage>/mesh.json the counts

THE MESH: one vertex per covered grid point at its depth; a quad wherever all four corners are covered (a depth step
between neighbours IS the wall of a raised letter); the outer boundary extruded straight back to x = 0 (the sign's
sides close onto the wall it hangs on; the back stays open, flush to the core like the old sign's dropped back faces).
Then a collapse decimate to TRIS, smooth shading with SHARP_DEG hard edges, and the UVs re-projected from the final
vertex positions (front orthographic: u across y, v up z) so the decimator can never smear the texture.
Run: blender -b -noaudio --python tools/fan_props/sign_relief_mesh.py -- <stage dir> <tris> <sharp_deg> <frame w> <frame h> <z centre>
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:]
stage = Path(argv[0])
TRIS = int(argv[1])
SHARP_DEG = float(argv[2])
FRAME_W, FRAME_H, Z_CENTRE = float(argv[3]), float(argv[4]), float(argv[5])


def log(*a):
    print('[SIGN_RELIEF]', *a, flush=True)


g = np.load(stage / 'grid.npz')
D, M = g['D'], g['M'].astype(bool)
y0, z1, step = float(g['y0']), float(g['z1']), float(g['step'])
H, W = D.shape
bpy.ops.wm.read_factory_settings(use_empty=True)
rr, cc = np.nonzero(M)
vid = np.full((H, W), -1, dtype=np.int64)
vid[rr, cc] = np.arange(len(rr))
verts = np.stack([D[rr, cc], y0 + cc * step, z1 - rr * step], axis=1)
a, b = vid[:-1, :-1], vid[:-1, 1:]
c_, d = vid[1:, 1:], vid[1:, :-1]
ok = (a >= 0) & (b >= 0) & (c_ >= 0) & (d >= 0)
# seen from +X (y right, z up): rows grow DOWN, columns RIGHT -> top-left, bottom-left, bottom-right, top-right is
# counter-clockwise for that viewer, so every grid quad's normal points +X, out of the sign
faces = np.stack([a[ok], d[ok], c_[ok], b[ok]], axis=1)
nf = len(faces)
mesh0 = bpy.data.meshes.new('grid')
mesh0.from_pydata(verts.tolist(), [], faces.tolist())
mesh0.validate()
log('grid', W, 'x', H, 'verts', len(verts), 'quads', nf)
bm = bmesh.new()
bm.from_mesh(mesh0)
# drop verts that no quad uses (a lone covered pixel)
loose = [v for v in bm.verts if not v.link_faces]
bmesh.ops.delete(bm, geom=loose, context='VERTS')
# the outer boundary -> straight back to the wall
bm.edges.ensure_lookup_table()
boundary = [e for e in bm.edges if e.is_boundary]
ext = bmesh.ops.extrude_edge_only(bm, edges=boundary)
for v in ext['geom']:
    if isinstance(v, bmesh.types.BMVert):
        v.co.x = 0.0
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
# recalc may flip the whole shell inward if it guesses wrong: the front must face +X
front_up = sum(f.normal.x * f.calc_area() for f in bm.faces)
if front_up < 0:
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
me = bpy.data.meshes.new('tod_cybercity_sign2_low')
bm.to_mesh(me)
bm.free()
ob = bpy.data.objects.new(me.name, me)
bpy.context.scene.collection.objects.link(ob)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
me.calc_loop_triangles()
n0 = len(me.loop_triangles)
mod = ob.modifiers.new('reduce', 'DECIMATE')
mod.decimate_type = 'COLLAPSE'
mod.ratio = min(1.0, TRIS / n0)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
me = ob.data
# the collapse places a merged vertex at its quadric optimum, which can overshoot a letter's tip (seen: 25.15 against
# the source's 24.21): keep every vertex inside the depth the sign really has
dmax = float(D[M].max())
xs = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get('co', xs)
xs = xs.reshape(-1, 3)
over = (xs[:, 0] > dmax) | (xs[:, 0] < 0)
xs[:, 0] = np.clip(xs[:, 0], 0.0, dmax)
me.vertices.foreach_set('co', xs.ravel())
me.update()
log('clamped', int(over.sum()), 'decimated vertices into depth 0 ..', round(dmax, 3))
me.set_sharp_from_angle(angle=math.radians(SHARP_DEG))
me.shade_smooth()
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode='OBJECT')
me.calc_loop_triangles()
V = np.array([v.co[:] for v in me.vertices], dtype=np.float64)
tv = np.array([[me.loops[li].vertex_index for li in t.loops] for t in me.loop_triangles], dtype=np.int32)
tn = np.array([[me.corner_normals[li].vector[:] for li in t.loops] for t in me.loop_triangles], dtype=np.float64)
P = V[tv]                                               # front orthographic UVs from the FINAL positions
u = (P[..., 1] + FRAME_W / 2) / FRAME_W
v = (P[..., 2] - (Z_CENTRE - FRAME_H / 2)) / FRAME_H
tuv = np.stack([u, v], axis=-1)
np.savez(stage / 'low.npz', V=V, tv=tv, tn=tn, tuv=tuv)
lo, hi = V.min(0), V.max(0)
(stage / 'mesh.json').write_text(json.dumps(dict(grid=[W, H], step=step, quads=nf, tris_before=n0, tris=len(tv),
                                                 verts=len(V), bounds=[lo.tolist(), hi.tolist()]), indent=1))
log('decimated', n0, '->', len(tv), 'tris; bounds', lo.round(3).tolist(), hi.round(3).tolist())
