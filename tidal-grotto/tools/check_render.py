from pathlib import Path
import json
import numpy as np
from PIL import Image

project = Path(__file__).resolve().parents[1]
ev = project.parent/'evidence'
def pixels(name):
    return np.array(Image.open(ev/(name+'.png')).convert('RGB')).astype(np.int16)
water = np.array(Image.open(project/'assets/bathymetry.png'))[:,:,0] > 127
a, b = pixels('01-complete-world'), pixels('02-original-world')
changed = np.max(np.abs(a-b),axis=2)>0
report = {
    'dry_pixels_changed': int((changed & ~water).sum()),
    'water_pixels_changed': int((changed & water).sum()),
}
base = pixels('06-animation-world')
report['layer_pixel_changes'] = {}
for name in ['depth_enabled','refraction_enabled','caustics_enabled','foam_enabled','ripples_enabled','reflection_enabled']:
    diff = np.max(np.abs(base-pixels('layer-off-'+name+'-world')),axis=2)
    report['layer_pixel_changes'][name] = int((diff>0).sum())
diff = np.max(np.abs(pixels('depth-278-096-world')-pixels('04-submersion-off-world')),axis=2)
report['submersion_pixel_changes'] = int((diff>0).sum())
diff = np.max(np.abs(pixels('05-ripples-world')-pixels('06-animation-world')),axis=2)
report['animated_water_pixels'] = int(((diff>0)&water).sum())
full = pixels('01-complete')
scene = full[96:736,24:984]
blocks = scene.reshape(320,2,480,2,3)
reference = blocks[:,0,:,0,:][:,None,:,None,:]
bad = np.any(blocks!=reference,axis=(1,3,4))
# The high-resolution status label is UI, rendered above the scene at top left.
bad[:20,:170] = False
report['perfect_2x_art_blocks'] = bool(not bad.any())
depth = json.loads((ev/'runtime-report.json').read_text())['depth_samples']
values = [v['immersion'] for v in depth]
report['monotonic_depth'] = values==sorted(values) and values[0]==0 and values[-1]>.9
report['passed'] = report['dry_pixels_changed']==0 and report['perfect_2x_art_blocks'] and report['monotonic_depth'] and report['submersion_pixel_changes']>0 and all(x>0 for x in report['layer_pixel_changes'].values()) and report['animated_water_pixels']>1000
(ev/'render-checks.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if not report['passed']: raise SystemExit(1)
