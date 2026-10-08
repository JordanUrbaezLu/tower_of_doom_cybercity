"""Apply/review the enlarged back spikes without recreating unchanged kit parts."""
import runpy,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
runpy.run_path(str(HERE/'resume_three.py'))
runpy.run_path(str(HERE/'three_back_spikes.py'))
runpy.run_path(str(HERE/'three_remove_backpack.py'))
runpy.run_path(str(HERE/'fix_modifier_order.py'))
from equipment import save
save('03_completed_reference_three_armored_only')
review=(HERE/'review.py').read_text()
start=review.index('# Keep the exact concept')
end=review.index('camera((30,-126,62)',start)
review=review[:start]+review[end:]
exec(compile(review,str(HERE/'review.py'),'exec'))
