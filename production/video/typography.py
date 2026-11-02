"""Native 12px bitmap masks, integer scales, explicit missing-glyph audit."""
from functools import lru_cache
from pathlib import Path
import math
from PIL import Image,ImageDraw,ImageFont
FONT=Path(__file__).parent/'fonts/zlabs-pixel-12px-m-cn.ttf'
NATIVE=ImageFont.truetype(str(FONT),12)
@lru_cache(maxsize=4096)
def mask(value,size=36):
    assert size%12==0, 'Pixel typography uses integer multiples of 12.'
    box=NATIVE.getbbox(value)
    im=Image.new('1',(max(1,math.ceil(NATIVE.getlength(value))),max(1,box[3]-box[1])))
    ImageDraw.Draw(im).text((0,-box[1]),value,font=NATIVE,fill=1)
    return im.convert('L').resize((im.width*(size//12),im.height*(size//12)),Image.Resampling.NEAREST)
def width(value,size=36):return mask(value,size).width
def text(im,xy,value,size=36,color='#eeeede',shadow=False):
    m=mask(value,size)
    if shadow:im.paste('#07131a',(xy[0]+size//12,xy[1]+size//12),m)
    im.paste(color,xy,m)
    return m.size
def wrap(value,size,maxwidth):
    rows=[];line=''
    for ch in value:
        if line and width(line+ch,size)>maxwidth:rows.append(line);line=''
        line+=ch
    if line:rows.append(line)
    return rows
def audit(strings):
    unknown=NATIVE.getmask(chr(0x10ffff));sig=(unknown.size,bytes(unknown))
    missing=[]
    for ch in sorted(set(''.join(strings))):
        if ch.isspace():continue
        glyph=NATIVE.getmask(ch)
        if (glyph.size,bytes(glyph))==sig:missing.append(ch)
    if missing:raise ValueError('Missing pixel glyphs: '+repr(missing))
    return len(set(''.join(strings)))
