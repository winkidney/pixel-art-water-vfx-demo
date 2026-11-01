"""Author semantic engine data; never repaint or synthesize artwork."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, binary_closing, binary_fill_holes

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/stone-basin'
SIZE = (480, 320)
SPEC = {
    'size': SIZE,
    'basin': [(210,53),(217,43),(240,35),(258,41),(263,55),(279,61),(288,70),(315,79),(330,85),(345,98),(370,111),(397,120),(436,126),(477,138),(479,160),(462,187),(444,210),(418,219),(398,230),(382,247),(370,267),(366,288),(363,309),(366,319),(203,319),(175,307),(155,297),(136,290),(114,283),(93,270),(76,258),(65,245),(61,236),(69,225),(81,217),(106,207),(125,197),(129,188),(120,178),(110,172),(140,168),(145,157),(145,148),(139,139),(131,128),(125,120),(117,113),(112,104),(103,101),(101,94),(106,89),(114,90),(127,98),(145,105),(160,106),(172,103),(172,92),(182,85),(193,78),(202,70),(208,62)],
    'terrace': [(2,124),(21,124),(28,130),(54,131),(72,132),(85,143),(82,153),(98,164),(107,179),(127,189),(125,197),(104,207),(80,217),(68,221),(56,204),(43,195),(29,188),(16,169),(2,168)],
    'beach': [(61,233),(73,244),(92,258),(115,271),(138,284),(169,296),(198,311),(203,319),(153,319),(131,311),(117,303),(101,298),(91,291),(80,280),(68,277),(62,265),(53,263),(47,247)],
    'reefs': [ [(333,205),(342,195),(368,190),(389,197),(408,209),(408,220),(390,230),(367,237),(345,228)], [(248,280),(260,264),(279,257),(292,268),(307,280),(315,297),(313,314),(288,319),(265,309),(253,295)] ],
    'waterfall': [(353,23),(367,21),(385,26),(406,29),(430,31),(437,29),(434,51),(435,77),(430,104),(420,107),(404,105),(384,97),(365,91),(348,85)],
    'impact': [(345,83),(371,89),(397,100),(427,102),(442,100),(451,110),(443,118),(412,119),(380,111),(354,103),(331,93)],
    'occlusion': [
        {'foot': 106, 'polygon':[(139,24),(165,23),(177,40),(175,75),(171,102),(157,107),(145,102),(144,81)]},
        {'foot': 238, 'polygon':[(333,205),(342,195),(368,190),(389,197),(408,209),(408,220),(390,230),(367,237),(345,228)]},
        {'foot': 318, 'polygon':[(248,280),(260,264),(279,257),(292,268),(307,280),(315,297),(313,314),(288,319),(265,309),(253,295)]},
        {'foot': 258, 'polygon':[(419,179),(429,166),(447,156),(459,155),(479,160),(479,258),(455,257),(443,235)]}
    ]
}

def polygon(points):
    im = Image.new('L', SIZE)
    ImageDraw.Draw(im).polygon([tuple(p) for p in points], fill=255)
    return np.array(im) > 0

basin = polygon(SPEC['basin'])
art = np.array(Image.open(DEST/'day-imagegen.png').convert('RGB').resize(SIZE,Image.Resampling.NEAREST))/255.
blue = (art[:,:,2]>art[:,:,0]*1.10)&(art[:,:,1]>art[:,:,0]*1.10)&(art[:,:,2]>art[:,:,1]*.62)
dist = distance_transform_edt(basin)
water = binary_fill_holes(binary_closing(basin & blue, iterations=1)) & basin
water |= dist>4
# Exclude exposed coral reefs and foreground palm, but keep submerged boulders.
for reef in SPEC['reefs']: water &= ~polygon(reef)
palm = polygon(SPEC['occlusion'][-1]['polygon'])
water &= ~(palm & ~blue)
walk = basin | polygon(SPEC['terrace']) | polygon(SPEC['beach'])
for reef in SPEC['reefs']: walk &= ~polygon(reef)
walk &= ~palm
yy,xx = np.indices(water.shape)
walk &= ~((xx>328)&(yy<124))  # continuous falling curtain/impact are not a walking platform
depth = np.clip(dist/62.,0,1)**1.05
depth *= np.clip((yy-205)*-.012+1, .30,1)
rgba=np.stack([water*255,np.clip(distance_transform_edt(water)/64,0,1)*255,depth*255,walk*255],axis=-1).astype('uint8')
Image.fromarray(rgba).save(DEST/'bathymetry.png')
fall=polygon(SPEC['waterfall'])
impact=polygon(SPEC['impact'])
Image.fromarray(np.stack([fall*255,impact*255,np.zeros_like(fall),np.full_like(fall,255,dtype='uint8')],axis=-1).astype('uint8')).save(DEST/'waterfall-mask.png')
# One channel stores the occluder's ground contact y. Source color comes from ImageGen.
occ=np.zeros((320,480,4),dtype='uint8');occ[:,:,3]=255
for obj in SPEC['occlusion']:
    region=polygon(obj['polygon'])
    if obj is SPEC['occlusion'][-1]:
        region &= ~blue  # preserve animated water visible between palm fronds
    occ[region,0]=round(obj['foot']/320*255)
Image.fromarray(occ).save(DEST/'occlusion-mask.png')
(DEST/'semantics.json').write_text(json.dumps(SPEC,indent=2)+'\n')
print(json.dumps({'water_pixels':int(water.sum()),'walkable_pixels':int(walk.sum()),'depth_max':float(depth.max())}))
