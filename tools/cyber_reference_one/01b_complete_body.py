"""Resume the body assembly without touching the completed harness."""
import sys, importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *
for ob in list(scene.objects):
    if 'attachment_bone' in ob and ob.name.startswith(('Shoulder','Leg |','Knee |','Thigh |')):bpy.data.objects.remove(ob,do_unlink=True)
src=(Path(__file__).parent/'01_body.py').read_text()
exec(compile(src[src.index('# Layered shoulder silhouette'):],str(Path(__file__).parent/'01_body.py'),'exec'),globals())
