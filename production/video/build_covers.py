"""Independent screenshot-first 16:9 and 4:3 covers with native pixel typography."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw
from typography import text,width,audit,mask

p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
src=Path(__file__).parent;plan=json.loads((src/'plan.json').read_text());title=plan['title']
C={'bg':'#0b1c26','panel':'#112a34','grid':'#1c3540','white':'#eeedde','mint':'#a6d3b8','gold':'#e7bb72','muted':'#8ba9a6','blue':'#a1cde1'}
audit([title,'Godot 复刻','《星之海》','通透像素','水体效果','2D 水面 Shader','原理拆解','Sea of Stars','折射 · 涟漪 · 角色入水','白天 / 通透水底','夜晚 / 冷暖反光','实机画面 / 2D 水体'])
capture_paths={n:src/'cover-assets'/f'{n}.png' if (src/'cover-assets'/f'{n}.png').exists() else a.work/'captures'/f'{n}.png' for n in ['day','night']}
images={n:Image.open(capture_paths[n]).convert('RGB') for n in ['day','night']}
def sha(path):return hashlib.file_digest(path.open('rb'),'sha256').hexdigest()
receipts=[]
for w,h,aspect in [(1920,1080,'16x9'),(1600,1200,'4x3')]:
    wide=w==1920;split=768 if wide else 700;x=60
    im=Image.new('RGB',(w,h),C['bg']);d=ImageDraw.Draw(im)
    d.rectangle((split,0,w-1,h-1),fill=C['panel'])
    for xx in range(split,w,48):d.line((xx,0,xx,h),fill=C['grid'])
    for yy in range(0,h,48):d.line((split,yy,w,yy),fill=C['grid'])
    d.rectangle((0,0,w-1,7),fill=C['mint']);d.rectangle((0,h-8,w-1,h-1),fill=C['gold'])
    d.line((split-12,48,split-12,h-48),fill='#34545a',width=2)
    boxes=[];shots=[]
    def put(value,xy,size,color,shadow=False,region=None):
        ww,hh=mask(value,size).size
        assert 0<=xy[0] and 0<=xy[1] and xy[0]+ww+(size//12 if shadow else 0)<=w and xy[1]+hh+(size//12 if shadow else 0)<=h,(aspect,value)
        if region:assert xy[0]+ww<=region,(aspect,value,ww,region)
        text(im,xy,value,size,color,shadow);boxes.append({'text':value,'xy':list(xy),'size':size,'bounds':[xy[0],xy[1],xy[0]+ww,xy[1]+hh]})
    put('Godot 复刻',(x,72),72,C['white'],True,split-30)
    put('《星之海》',(x-12,196 if wide else 216),108,C['gold'],True,split-30)
    put('通透像素',(x,356 if wide else 382),120,C['mint'],True,split-30)
    put('水体效果',(x,500 if wide else 530),120,C['white'],True,split-30)
    put('Sea of Stars',(x+4,654 if wide else 688),36,C['muted'],False,split-30)
    ribbon_y=744 if wide else 795;ribbon_w=split-x-48
    d.rectangle((x,ribbon_y,x+ribbon_w,ribbon_y+73),fill=C['gold'])
    put('2D 水面 Shader',(x+20,ribbon_y+14),48,C['bg'],False,x+ribbon_w-12)
    put('原理拆解',(x,ribbon_y+105),60,C['mint'],True,split-30)
    put('折射 · 涟漪 · 角色入水',(x,h-83),24,C['muted'],False,split-30)
    crop=(90,80,378,296) if wide else (80,30,380,320)
    scale=4 if wide else 3;hero=images['day'].crop(crop)
    hero=hero.resize((hero.width*scale,hero.height*scale),Image.Resampling.NEAREST)
    hx=split;hy=112 if wide else 142
    assert hx+hero.width==w and hy+hero.height<h-10
    im.paste(hero,(hx,hy));d=ImageDraw.Draw(im)
    d.rectangle((hx,hy,hx+hero.width-1,hy+hero.height-1),outline='#547e83',width=3)
    shots.append({'source':'day.png','sha256':sha(capture_paths['day']),'crop':list(crop),'integer_scale':scale,'xy':[hx,hy]})
    put('实机画面 / 2D 水体',(split+36,54 if wide else 74),24,C['mint'])
    nx=w-508;ny=h-294
    night_crop=(118,100,358,220);night=images['night'].crop(night_crop).resize((480,240),Image.Resampling.NEAREST)
    d.rectangle((nx-8,ny-42,nx+488,ny+248),fill=C['bg'],outline=C['mint'],width=2)
    put('夜晚 / 冷暖反光',(nx+10,ny-31),24,C['mint'])
    im.paste(night,(nx,ny))
    shots.append({'source':'night.png','sha256':sha(capture_paths['night']),'crop':list(night_crop),'integer_scale':2,'xy':[nx,ny]})
    day_label='白天 / 通透水底';lx=split+28;ly=hy+24
    d=ImageDraw.Draw(im);d.rectangle((lx-10,ly-8,lx+width(day_label,24)+10,ly+32),fill=C['bg'])
    put(day_label,(lx,ly),24,C['white'])
    path=a.out/f'cover-{aspect}.png';im.save(path)
    receipts.append({'file':path.name,'size':[w,h],'publication_title':title,'source':'Unmodified Godot real viewport screenshots, cropped and enlarged at integer scales','font_sha256':sha(src/'fonts/zlabs-pixel-12px-m-cn.ttf'),'text_bounds_verified':True,'text_boxes':boxes,'screenshots':shots,'sha256':sha(path)})
(a.out/'cover-receipt.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([{'file':r['file'],'size':r['size'],'text_bounds_verified':True} for r in receipts],ensure_ascii=False))
