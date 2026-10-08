"""The armored sprinter's authorized elbow-to-hand surface replacement.

Keep every bone, non-arm face, and its vertices/weights. Arm-only vertices are
retired with their faces; the stock skeleton drives the articulated blades.
"""
POLICY = 'elbow_to_tip_spikes_v3'
ARM_WEIGHT_CUTOFF = .45

def arm_bone_names(parents):
    selected = {'j_elbow_le', 'j_elbow_ri'}
    assert selected <= set(parents)
    while True:
        descendants = {name for name, parent in parents.items() if parent in selected}
        if descendants <= selected:
            return selected
        selected |= descendants

def replace_face(corner_weights, selected):
    weights = list(corner_weights)
    assert weights
    return sum(sum(weight for bone, weight in corner if bone in selected)
               for corner in weights) / len(weights) >= ARM_WEIGHT_CUTOFF

def retained_faces(model, mesh):
    parents = {bone.name.lower(): model.bones[bone.parent].name.lower()
               if bone.parent >= 0 else None for bone in model.bones}
    selected = arm_bone_names(parents)
    weights = [[(model.bones[index].name.lower(), weight) for index, weight in vertex.weights]
               for vertex in mesh.verts]
    return [face for face in mesh.faces
            if not replace_face((weights[corner.vertex] for corner in face.indices), selected)]

def replace_arm_surfaces(model):
    removed_faces=[];removed_vertices=[]
    for mesh in model.meshes:
        faces=retained_faces(model,mesh)
        removed_faces.append(len(mesh.faces)-len(faces))
        # The binary reader compacts vertices in first-face-use order. Match
        # that format explicitly, preserving exact values on retained corners.
        original=mesh.verts;mapping={};vertices=[]
        for face in faces:
            for corner in face.indices:
                old=corner.vertex
                if old not in mapping:
                    mapping[old]=len(vertices);vertices.append(original[old])
                corner.vertex=mapping[old]
        removed_vertices.append(len(original)-len(vertices))
        mesh.faces=faces;mesh.verts=vertices
    return removed_faces,removed_vertices
