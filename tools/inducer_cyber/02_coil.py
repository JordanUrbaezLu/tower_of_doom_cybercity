"""Stage 02 - the power coil: copper windings over a glowing core, retaining
bars, titanium collars and the upward emitter lens that feeds the crystal."""
import sys, importlib, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
from mathutils import Vector

assert scene.get('mcp_port') == 9884
P = palette()
begin('02 coil')

# collars (closed annular profiles)
bevel(lathe('coil lower collar', [(10.2, 13.7), (12.8, 13.7), (13.15, 14.05), (13.15, 15.15), (12.75, 15.55), (10.2, 15.55)],
            P['titanium'], seg=64, closed=True), 0.12, 2, 40)
bevel(lathe('coil upper collar', [(9.4, 21.55), (12.75, 21.55), (13.15, 21.95), (13.15, 22.75), (12.55, 23.25), (9.4, 23.25)],
            P['titanium'], seg=64, closed=True), 0.12, 2, 40)
# the glowing core the windings sit on: light shows through every crevice
lathe('coil energised core', [(0, 15.4), (10.55, 15.4), (10.55, 21.7), (0, 21.7)], P['core'], seg=64)
# windings: four copper turns, each a little proud of the core
for i, z in enumerate((16.25, 17.6, 18.95, 20.3)):
    torus('coil winding %d' % i, 11.05, 0.56, P['copper'], seg=56, ring=8, center=(0, 0, z))
# retaining bars hold the windings: never on the front (+X) axis
for i, a in enumerate(radial(3, 90)):
    c, s = math.cos(a), math.sin(a)
    bar = box('coil retaining bar %d' % i, (0, 0, 18.5), (1.5, 1.7, 6.6), P['graphite'])
    bar.location = (c * 11.95, s * 11.95, 18.5); bar.rotation_euler = (0, 0, a)
    apply_transform(bar); bevel(bar, 0.18, 2, 40)
    for z in (16.0, 21.0):
        hex_bolt('coil bar bolt %d' % i, Vector((c * 12.68, s * 12.68, z)), Vector((c, s, 0)), P['steel'], r=0.36, h=0.22)
# status LEDs around the lower collar's face
for i, a in enumerate(radial(8, 22.5)):
    c, s = math.cos(a), math.sin(a)
    led = box('coil collar led %d' % i, (0, 0, 0), (0.25, 0.9, 0.32), P['status'])
    led.location = (c * 13.18, s * 13.18, 14.6); led.rotation_euler = (0, 0, a)
    apply_transform(led)
# the emitter: a graphite dish rising to a glowing lens under the crystal
lathe('coil emitter dish', [(0, 23.1), (9.5, 23.1), (9.5, 23.45), (8.6, 23.75), (5.4, 24.2), (3.75, 24.65), (0, 24.65)],
      P['graphite'], seg=64, smooth=30)
lathe('coil emitter lens', [(0, 24.5), (3.55, 24.5), (3.35, 24.85), (2.55, 25.15), (1.3, 25.33), (0, 25.38)],
      P['core'], seg=48, smooth=60)
torus('coil emitter lens rim', 3.7, 0.3, P['titanium'], seg=40, ring=8, center=(0, 0, 24.62))
for i, a in enumerate(radial(12, 15)):
    c, s = math.cos(a), math.sin(a)
    hex_bolt('coil collar top bolt %d' % i, Vector((c * 11.15, s * 11.15, 23.25)), Vector((0, 0, 1)), P['steel'], r=0.34, h=0.2)

save('02 coil')
print('COIL_OK')
