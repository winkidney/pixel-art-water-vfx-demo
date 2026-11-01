"""Verify actual OpenGL captures, not a software recreation of the shaders."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
EV=Path(sys.argv[1]) if len(sys.argv)>1 else PROJECT.parent/'evidence/parameters/scene-regression'
water=np.array(Image.open(PROJECT/'assets/stone-basin/bathymetry.png'))[:,:,0]>127
fall=np.max(np.array(Image.open(PROJECT/'assets/stone-basin/waterfall-mask.png'))[:,:,:2],axis=2)>127
occlusion=np.array(Image.open(PROJECT/'assets/stone-basin/occlusion-mask.png'))[:,:,0]>0
runtime=json.loads((EV/'runtime-report.json').read_text())
report={'variants':{}}
for variant in ('day','night'):
    def pixels(name): return np.array(Image.open(EV/variant/(name+'.png')).convert('RGB')).astype(np.int16)
    def changed(a,b): return np.any(pixels(a)!=pixels(b),axis=2)
    result={}
    delta=changed('environment-a','plate')
    result['dry_pixels_changed_outside_waterfall']=int((delta & ~water & ~fall).sum())
    result['water_pixels_changed']=int((delta & water).sum())
    result['black_water_pixels']=int((water & (pixels('environment-a').max(axis=2)==0)).sum())
    result['frozen_pixels_changed']=int(changed('complete','freeze-repeat').sum())
    result['animated_water_pixels']=int((changed('environment-a','environment-b') & water).sum())
    fall_delta=changed('fall-a','fall-b')
    result['animated_waterfall_pixels']=int((fall_delta & fall).sum())
    result['waterfall_animation_leaked_pixels']=int((fall_delta & ~fall).sum())
    result['layer_pixel_changes']={}
    for effect in ('depth_enabled','refraction_enabled','caustics_enabled','foam_enabled','ripples_enabled','reflection_enabled','submersion_enabled','environment_enabled','waterfall_enabled'):
        result['layer_pixel_changes'][effect]=int(changed('layers-on','off-'+effect).sum())
    result['deep_submersion_pixel_changes']=int(changed('depth-096','submersion-off').sum())
    occ=changed('occlusion-on','occlusion-off')
    result['occlusion_pixel_changes']=int(occ.sum())
    result['occlusion_changes_outside_mask']=int((occ & ~occlusion).sum())
    result['front_actor_pixels_overpainted']=int(changed('foreground-front-on','foreground-front-off').sum())
    scene=pixels('complete-full')[96:736,24:984]
    blocks=scene.reshape(320,2,480,2,3)
    reference=blocks[:,0,:,0,:][:,None,:,None,:]
    bad=np.any(blocks!=reference,axis=(1,3,4))
    bad[:20,:170]=False # HUD is full-resolution UI, not scene pixels.
    result['perfect_2x_art_blocks']=bool(not bad.any())
    samples=runtime['variants'][variant]['depth_samples']
    depths=[v['immersion'] for v in samples]
    result['monotonic_depth']=depths==sorted(depths) and depths[0]==0 and depths[-1]>.9
    result['all_depth_samples_walkable']=all(v['walkable'] for v in samples)
    result['passed']=(result['dry_pixels_changed_outside_waterfall']==0 and result['black_water_pixels']==0
        and result['frozen_pixels_changed']==0 and result['animated_water_pixels']>1000
        and result['animated_waterfall_pixels']>1000 and result['waterfall_animation_leaked_pixels']==0
        and all(v>0 for v in result['layer_pixel_changes'].values())
        and result['deep_submersion_pixel_changes']>0 and result['occlusion_pixel_changes']>0
        and result['occlusion_changes_outside_mask']==0 and result['front_actor_pixels_overpainted']==0
        and result['perfect_2x_art_blocks'] and result['monotonic_depth'] and result['all_depth_samples_walkable'])
    report['variants'][variant]=result
report['passed']=runtime['passed'] and all(v['passed'] for v in report['variants'].values())
(EV/'render-checks.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if not report['passed']: raise SystemExit(1)
