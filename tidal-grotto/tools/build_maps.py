"""Build technical semantic/depth masks. Does not alter ImageGen art."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, binary_fill_holes, binary_dilation, binary_closing, label

root = Path(__file__).resolve().parents[1]
spec = json.loads((root / 'assets/shoreline.json').read_text())
size = tuple(spec['size'])
mask_image = Image.new('L', size)
draw = ImageDraw.Draw(mask_image)
draw.polygon([tuple(p) for p in spec['water']], fill=255)
for island in spec['islands']:
    draw.polygon([tuple(p) for p in island], fill=0)
authored_water = np.array(mask_image) > 0
art = np.array(Image.open(root / 'assets/grotto-imagegen.png').convert('RGB').resize(size, Image.Resampling.NEAREST)).astype(float) / 255
# The contour encodes semantic intention. Exclude above-surface palm foliage
# and warm dark basalt at the islet, leaving the underwater teal stones alone.
yy, xx = np.indices(authored_water.shape)
palm_area = (xx > 340) & (xx < 390) & (yy > 60) & (yy < 118)
green = (art[:,:,1] > art[:,:,2] * 1.3) & (art[:,:,0] > art[:,:,2] * 1.2)
blue = (art[:,:,2] > art[:,:,0]*1.12) & (art[:,:,1] > art[:,:,0]*1.16) & (art[:,:,2] > art[:,:,1]*.63)
# Refine the authored broad contour against water's cyan palette. Closing fills
# isolated seabed texture gaps while the explicit island exclusion remains solid.
water = binary_closing(authored_water & blue, iterations=2)
water |= distance_transform_edt(authored_water) > 5
water = binary_fill_holes(water) & authored_water
components, count = label(~water)
areas = np.bincount(components.ravel())
small_holes = areas[components] < 32
water |= small_holes & authored_water
water &= ~(palm_area & binary_dilation(green, iterations=1))
dist = distance_transform_edt(water)
# Bathymetry follows the authored basin, so a neutral-colored submerged rock
# cannot turn deep water into a dry foothold.
basin_dist = distance_transform_edt(authored_water)
depth = np.clip(basin_dist / 70, 0, 1) ** 1.05
# The near-camera sand shelf is shallow; the north central basin is deep.
depth *= np.clip(.65 + (280-yy)/180, .45, 1)
warm_sand = (art[:,:,0] > .56) & (art[:,:,1] > .50) & (art[:,:,2] < art[:,:,0] * .87)
walkable = authored_water | (binary_dilation(authored_water, iterations=16) & warm_sand)
walkable &= ~((xx>338)&(xx<391)&(yy>60)&(yy<124)&~water)
rgba = np.stack([water*255, np.clip(dist/64,0,1)*255, depth*255, walkable*255],axis=-1).astype(np.uint8)
Image.fromarray(rgba).save(root / 'assets/bathymetry.png')
print(json.dumps({'size':size,'water_pixels':int(water.sum()),'walkable_pixels':int(walkable.sum()),'depth_max':float(depth.max()),'sprite':Image.open(root/'assets/adventurer-imagegen.png').mode}))
