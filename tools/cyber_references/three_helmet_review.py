"""Author/review the enclosed helmet without recreating retained torso/arm kit."""
import runpy, sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
runpy.run_path(str(HERE/'resume_three.py'))
runpy.run_path(str(HERE/'three_helmet.py'))
runpy.run_path(str(HERE/'three_armor_finish.py'))
runpy.run_path(str(HERE/'fix_modifier_order.py'))
from equipment import save
save('03_completed_reference_three_armored_only')
review=(HERE/'review.py').read_text()
start=review.index('# Keep the exact concept')
end=review.index('camera((30,-126,62)',start)
review=review[:start]+review[end:]
exec(compile(review,str(HERE/'review.py'),'exec'))
