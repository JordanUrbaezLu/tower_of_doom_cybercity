"""Live Blender MCP studio for the CYBER Rampage Inducer (2026-10-02).

Run INSIDE Blender 4.2 at startup:
  blender.exe --factory-startup --python tools/inducer_cyber/mcp_bootstrap.py

Port 9884 is the inducer's own (tools/inducer/ used it for the BO6 review
studio). 9876 = Tower II sword, 9877 = zombie roster, 9878 = Heavenly Altar:
never point inducer work at those. The window stays open for the user; stage
scripts arrive through tools/inducer_cyber/mcp_call.py.
"""
import bpy, importlib.util, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
VENDOR = ROOT.parent/'tower_of_doom_II_hellbound/tmp/blender_mcp_vendor/addon.py'
spec = importlib.util.spec_from_file_location('tod_inducer_cyber_mcp', VENDOR)
addon = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = addon
spec.loader.exec_module(addon)
addon.register()
bpy.context.scene.blendermcp_auto_start_server = False
bpy.types.tod_inducer_cyber_mcp = addon.BlenderMCPServer(host='127.0.0.1', port=9884)
bpy.types.tod_inducer_cyber_mcp.start()
bpy.context.scene['mcp_port'] = 9884
print('TOD_INDUCER_CYBER_MCP_READY port=9884', flush=True)
