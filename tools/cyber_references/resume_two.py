import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/cyber_reference_two_mcp/reference_two.blend'))
