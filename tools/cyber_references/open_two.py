import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
reference=2
exec(compile((Path(__file__).parent/'open_study.py').read_text(),str(Path(__file__).parent/'open_study.py'),'exec'))
