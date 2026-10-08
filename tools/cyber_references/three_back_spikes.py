"""Enlarge the armored zombie's rear spikes in the visible donor copy only."""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from cyber_back_spikes import POLICY,SPEC,scaled_spike_positions
from equipment import *
assert REFERENCE==3
donor=next(o for o in body if o.name.endswith(' | '+SPEC['mesh_name']))
display=armored_display(donor)
assert len(display.data.vertices)==len(donor.data.vertices)==SPEC['mesh_vertices']
# Original Blender body was rotated +90 degrees relative to native body3.
native=[(-v.co.y,v.co.x,v.co.z) for v in donor.data.vertices]
changed,report=scaled_spike_positions(native)
for index,co in changed.items():display.data.vertices[index].co=(co[1],-co[0],co[2])
display.data.update()
display['back_spikes']=POLICY
scene['armored_back_spikes']=json.dumps(report)
scene['armored_walk_profile']='native_walk_arms_down_v1'
print('ARMORED_BACK_SPIKES',json.dumps(report),flush=True)
