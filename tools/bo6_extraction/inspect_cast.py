"""Inventory actual Cast models/animations before choosing a BO3 conversion rig.

Uses the installed Cast reader directly, without opening Blender or an extractor.
This is source-data inspection, not Blender import or BO3 runtime verification.
"""

import argparse
import datetime
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path


def inspect(path, cast):
    raw = path.read_bytes()
    assert raw[:4] == b"cast", f"Not a Cast file: {path}"
    item = {"path": str(path.resolve()), "sha256": hashlib.sha256(raw).hexdigest(),
            "models": [], "animations": []}
    for root in cast.Cast.load(str(path)).Roots():
        for model in root.ChildrenOfType(cast.Model):
            skeleton = model.Skeleton()
            bones = skeleton.Bones() if skeleton else []
            names = [bone.Name() for bone in bones]
            assert len(names) == len(set(names)), f"Duplicate bone name: {path}"
            for index, bone in enumerate(bones):
                visited = {index}
                parent = bone.ParentIndex()
                while parent >= 0:
                    assert parent < len(bones) and parent not in visited, (path, bone.Name(), parent)
                    visited.add(parent)
                    parent = bones[parent].ParentIndex()
            meshes = []
            for mesh in model.Meshes():
                positions = mesh.VertexPositionBuffer() or []
                faces = mesh.FaceBuffer() or []
                vertices = mesh.VertexCount() or 0
                assert vertices > 0 and len(positions) == vertices * 3, path
                assert faces and len(faces) % 3 == 0 and all(0 <= i < vertices for i in faces), path
                assert all(math.isfinite(x) for x in positions), path
                unique_faces = {tuple(sorted(faces[i:i + 3])) for i in range(0, len(faces), 3)}
                for layer in range(mesh.UVLayerCount()):
                    uv = mesh.VertexUVLayerBuffer(layer) or []
                    assert len(uv) == vertices * 2 and all(math.isfinite(x) for x in uv), path
                material = mesh.Material()
                meshes.append({"name": mesh.Name(), "vertices": vertices,
                               "raw_triangles": mesh.FaceCount(),
                               "unique_index_triangles": len(unique_faces),
                               "duplicate_index_triangles": mesh.FaceCount() - len(unique_faces),
                               "uv_layers": mesh.UVLayerCount(),
                               "color_layers": mesh.ColorLayerCount(),
                               "max_weight_influence": mesh.MaximumWeightInfluence(),
                               "material": material.Name() if material else None,
                               "bounds": [[min(positions[axis::3]) for axis in range(3)],
                                          [max(positions[axis::3]) for axis in range(3)]]})
            materials = []
            for material in model.Materials():
                slots = {}
                for key, slot in material.Slots().items():
                    filename = slot.Path() if isinstance(slot, cast.File) else None
                    slots[key] = {"node_type": type(slot).__name__, "path": filename,
                                  "exists": (path.parent / filename).is_file() if filename else None}
                materials.append({"name": material.Name(), "slots": slots})
            item["models"].append({"name": model.Name() or path.stem, "meshes": meshes,
                                   "vertices": sum(mesh["vertices"] for mesh in meshes),
                                   "raw_triangles": sum(mesh["raw_triangles"] for mesh in meshes),
                                   "unique_index_triangles": sum(mesh["unique_index_triangles"] for mesh in meshes),
                                   "bones": [{"name": bone.Name(), "parent": bone.ParentIndex()}
                                             for bone in bones], "materials": materials})
        for animation in root.ChildrenOfType(cast.Animation):
            curves = animation.Curves()
            frames = [frame for curve in curves for frame in curve.KeyFrameBuffer()]
            assert frames and animation.Framerate() > 0, path
            assert all(math.isfinite(value) for curve in curves for value in curve.KeyValueBuffer()), path
            item["animations"].append({
                "name": animation.Name() or path.stem, "fps": animation.Framerate(), "looping": animation.Looping(),
                "frame_range": [min(frames), max(frames)], "curve_count": len(curves),
                "target_bones": sorted({curve.NodeName() for curve in curves}),
                "curve_modes": sorted({curve.Mode() for curve in curves}),
                "properties": sorted({curve.KeyPropertyName() for curve in curves}),
                "notifications": [{"name": note.Name(), "frames": note.KeyFrameBuffer()}
                                  for note in animation.Notifications()],
            })
    assert item["models"] or item["animations"], f"No models/animations in {path}"
    return item


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cast-reader", type=Path, default=Path(os.environ["APPDATA"]) /
                        "Blender Foundation/Blender/4.2/scripts/addons/io_scene_cast/cast.py")
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError(f"Preserving existing report: {args.output}")
    spec = importlib.util.spec_from_file_location("cast_reader", args.cast_reader)
    cast = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cast)
    report = {"checked_at": datetime.datetime.now().astimezone().isoformat(),
              "evidence_scope": "Cast data only; no Blender import or BO3 runtime test",
              "cast_reader": str(args.cast_reader),
              "cast_reader_sha256": hashlib.sha256(args.cast_reader.read_bytes()).hexdigest(),
              "files": [inspect(path, cast) for path in args.files]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(f"Inspected {len(report['files'])} Cast files: {args.output}")


if __name__ == "__main__":
    main()
