"""Exactly 14 approved rear armor spikes enlarged around their embedded roots.

The selection is pinned to the immutable body3 donor and shared by Blender and
native export. No skeleton, weights, faces, normals or texture coordinates move.
"""
import json,math
from pathlib import Path

POLICY='back_spikes_130_v1'
SCALE=1.30
SPEC=json.loads((Path(__file__).parent/'cyber_references/armored_back_spikes.json').read_text())
assert SPEC['policy']==POLICY and SPEC['scale']==SCALE
assert len(SPEC['spikes'])==14

def scaled_spike_positions(points):
    """Accept native donor coordinates; return changed indices and review data."""
    assert len(points)==SPEC['mesh_vertices']
    changed={};spikes=[]
    for spike in SPEC['spikes']:
        indices=spike['vertex_indices'];anchor=spike['anchor']
        original=[[min(points[i][a] for i in indices),max(points[i][a] for i in indices)] for a in range(3)]
        assert all(abs(x-y)<.0001 for actual,expected in zip(original,spike['original_bounds']) for x,y in zip(actual,expected)),spike['component']
        for i in indices:
            assert i not in changed
            changed[i]=tuple(anchor[a]+(points[i][a]-anchor[a])*SCALE for a in range(3))
            assert all(math.isfinite(x) for x in changed[i])
        scaled=[[min(changed[i][a] for i in indices),max(changed[i][a] for i in indices)] for a in range(3)]
        # Independent dimensional check on all three axes, not just the tip.
        for old,new in zip(original,scaled):
            assert abs((new[1]-new[0])/(old[1]-old[0])-1.30)<1e-6
        roots=spike['root_points']
        scaled_root=[sum(anchor[a]+(p[a]-anchor[a])*SCALE for p in roots)/len(roots) for a in range(3)]
        assert max(abs(a-b) for a,b in zip(anchor,scaled_root))<1e-6
        # Blender's +90-degree import introduces sub-micro-unit rounding.
        # Metadata uses the pinned source bounds after checking the measured
        # geometry; both transports then carry the same canonical record.
        canonical=spike['original_bounds']
        canonical_scaled=[[anchor[a]+(value-anchor[a])*SCALE for value in bounds]
                          for a,bounds in enumerate(canonical)]
        assert max(abs(x-y) for actual,expected in zip(scaled,canonical_scaled)
                   for x,y in zip(actual,expected))<.0001
        spikes.append({'component':spike['component'],'vertices':len(indices),'anchor':anchor,
                       'original_bounds':canonical,'scaled_bounds':canonical_scaled})
    assert len(changed)==520
    return changed,{'policy':POLICY,'scale':SCALE,'spikes':spikes,'changed_vertices':len(changed)}

def enlarge_back_spikes(model, source_sha256):
    assert source_sha256==SPEC['source_sha256'],'Unexpected armored donor'
    mesh=model.meshes[SPEC['mesh_index']]
    assert mesh.name==SPEC['mesh_name']
    changed,report=scaled_spike_positions([v.offset for v in mesh.verts])
    for index,position in changed.items():mesh.verts[index].offset=position
    return report
