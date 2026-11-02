"""Render the approved 178s film from real viewport captures and labelled diagrams."""
import argparse,json,math,subprocess,hashlib
from functools import lru_cache
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
import qrcode
from typography import text,width,wrap,audit,mask

P=argparse.ArgumentParser();P.add_argument('--project',type=Path,required=True);P.add_argument('--work',type=Path,required=True);P.add_argument('--out',type=Path,required=True);P.add_argument('--preview',action='store_true');P.add_argument('--audio-file',type=Path,help='Reuse an existing AAC soundtrack without re-encoding.');a=P.parse_args()
source=Path(__file__).parent;plan=json.loads((source/'plan.json').read_text());cues=json.loads((a.out/'subtitle-cues.json').read_text())
C={'bg':'#0a171f','panel':'#112932','grid':'#1a3540','mint':'#a6d3b8','gold':'#e7bb72','white':'#eeedde','muted':'#91aaa9','blue':'#8db9e0','red':'#ec9b8c'}
FONT_STRINGS=[x for s in plan['shots'] for x in [s['title'],s['sub'],*s['lines']]]
capture_report=json.loads((a.work/'captures/capture-report.json').read_text())
raw={j['id']:np.memmap(a.work/'captures'/f'{j["id"]}.rgb',dtype=np.uint8,mode='r',shape=(j['frames'],320,480,3)) for j in capture_report['shots']}
maps=Image.open(a.project/'demo/assets/stone-basin/bathymetry.png').convert('RGBA');map_data=np.array(maps)
assets={}
for i,(name,color) in enumerate([('water',(80,190,215)),('shore',(200,180,110)),('depth',(80,150,230)),('walk',(155,211,179))]):
    channel=map_data[:,:,i]/255
    arr=np.stack([channel*v+9 for v in color],axis=-1).clip(0,255).astype('uint8')
    assets[name]=Image.fromarray(arr)
plate=Image.open(a.project/'evidence/parameters/scene-regression/day/plate.png').convert('RGB')
atlas=Image.open(a.project/'demo/assets/adventurer-imagegen.png').convert('RGBA');cell=atlas.crop((0,0,atlas.width//2,atlas.height//2));alpha=np.array(cell)[:,:,3]>64;yy,xx=np.where(alpha);sprite=cell.crop((xx.min(),yy.min(),xx.max()+1,yy.max()+1)).resize((32,44),Image.Resampling.NEAREST)
ss=np.array(sprite);y,x=np.indices((44,32));height=(1-y/43)+((np.abs(x/31-.5)*2)**2)*.065;shade=(height.clip(0,1)*255).astype('uint8');height_sprite=Image.fromarray(np.dstack([shade,shade,shade,ss[:,:,3]]))

def tag(im,xy,label,color=None,size=24):
    color=color or C['mint'];w=width(label,size)+28;h=size+20
    ImageDraw.Draw(im).rectangle((xy[0],xy[1],xy[0]+w,xy[1]+h),fill=C['bg'],outline=color,width=2)
    text(im,(xy[0]+14,xy[1]+10),label,size,color);return w,h

def arrow(draw,start,end,color='#a6d3b8',width_=4):
    draw.line((*start,*end),fill=color,width=width_);angle=math.atan2(end[1]-start[1],end[0]-start[0]);length=14
    draw.polygon([end,(end[0]-length*math.cos(angle-.6),end[1]-length*math.sin(angle-.6)),(end[0]-length*math.cos(angle+.6),end[1]-length*math.sin(angle+.6))],fill=color)

def lines(im,xy,rows,size=36,color=None,gap=20):
    y=xy[1]
    for row in rows:
        text(im,(xy[0],y),row,size,color or C['white']);y+=size+gap
    return y

def source_frame(name,t):
    frames=raw[name];idx=int(t*60)%len(frames)
    return Image.fromarray(np.asarray(frames[idx]))

@lru_cache(maxsize=64)
def qr(url):
    code=qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,box_size=1,border=4);code.add_data(url);code.make(fit=True)
    return code.make_image(fill_color='black',back_color='white').convert('RGB')

def qr_box(im,url,box):
    code=qr(url);maxside=box[2];scale=max(1,maxside//code.width);code=code.resize((code.width*scale,code.height*scale),Image.Resampling.NEAREST)
    im.paste(code,(box[0]+(maxside-code.width)//2,box[1]+(maxside-code.height)//2))

def base(shot):
    im=Image.new('RGB',(1920,1080),C['bg']);d=ImageDraw.Draw(im)
    for x in range(0,1920,48):d.line((x,116,x,910),fill=C['grid'])
    for y in range(116,910,48):d.line((0,y,1920,y),fill=C['grid'])
    d.rectangle((0,0,1919,115),fill='#102129');d.rectangle((0,0,1919,5),fill=C['mint'])
    title_size=48 if width(shot['title'],48)<1440 else 36
    text(im,(48,24),shot['title'],title_size,C['white'])
    text(im,(48,82),shot['sub'],24,C['mint'])
    text(im,(1510,33),'GODOT WATER LAB',24,C['gold'])
    text(im,(1510,75),'4.7.2 / 2D / 60 FPS',24,C['muted'])
    return im

def full_game(im,name,t,large=False):
    if large:
        frame=source_frame(name,t).crop((0,12,480,282)).resize((1440,810),Image.Resampling.NEAREST);im.paste(frame,(240,116))
    else:
        frame=source_frame(name,t).resize((960,640),Image.Resampling.NEAREST);im.paste(frame,(48,208))
        ImageDraw.Draw(im).rectangle((46,206,1010,850),outline='#547e83',width=2)

def opening_zoom(im,name,t,crop):
    frame=source_frame(name,t).crop(crop).resize((1440,810),Image.Resampling.NEAREST)
    im.paste(frame,(240,116))
    ImageDraw.Draw(im).rectangle((238,116,1681,925),outline='#547e83',width=2)

def opening_callout(im,label,xy,world,crop,color):
    target=(round(240+(world[0]-crop[0])*6),round(116+(world[1]-crop[1])*6))
    assert 240<=target[0]<1680 and 116<=target[1]<926,(label,target)
    w=width(label,36)+28;h=60
    assert 240<=xy[0] and xy[0]+w<=1680 and 116<=xy[1] and xy[1]+h<=925
    assert not (xy[0]<=target[0]<=xy[0]+w and xy[1]<=target[1]<=xy[1]+h),(label,target,xy)
    d=ImageDraw.Draw(im)
    arrow(d,(xy[0]+w//2,xy[1]+h//2),target,color,3)
    d.ellipse((target[0]-7,target[1]-7,target[0]+7,target[1]+7),outline=color,width=2)
    d.rectangle((xy[0],xy[1],xy[0]+w,xy[1]+h),fill=C['bg'],outline=color,width=2)
    text(im,(xy[0]+14,xy[1]+12),label,36,color)

def opening(im,id,t):
    if id=='intro_day':
        if t<1:
            full_game(im,'day',t,True)
        elif t<4.5:
            crop=(80,145,320,280)
            opening_zoom(im,'caustics_on',t-1,crop)
            if t<2.9:opening_callout(im,'通透水底与深浅渐变',(1110,168),(270,176),crop,C['mint'])
            else:opening_callout(im,'水下焦散',(300,750),(160,240),crop,C['gold'])
            opening_callout(im,'像素折射',(1080,740),(210,225),crop,C['blue'])
        else:
            crop=(45,170,285,305);local=t-4.5
            opening_zoom(im,'ripples',local,crop)
            opening_callout(im,'岸线泡沫',(300,170),(77,253),crop,C['white'])
            radius=(local%2)*15+2
            opening_callout(im,'交互涟漪',(1110,770),(207+radius,208),crop,C['blue'])
    elif id=='intro_night':
        if t<3:
            crop=(240,124,480,259)
            opening_zoom(im,'intro_flow',t,crop)
            radius=((6+t)*2.8+math.pi/2)/.22
            opening_callout(im,'落点汇流',(1110,170),(395-.6*radius,108+.8*radius/1.8),crop,C['gold'])
            tag(im,(300,835),'仅汇流演示 · 折射幅度 1.40 px',C['muted'],24)
        else:
            crop=(110,110,350,245)
            opening_zoom(im,'environment',t-3,crop)
            opening_callout(im,'冷暖环境反光',(880,170),(309,176),crop,C['blue'])
            d=ImageDraw.Draw(im);warm=(444,410)
            arrow(d,(1000,230),warm,C['gold'],3)
            d.ellipse((warm[0]-7,warm[1]-7,warm[0]+7,warm[1]+7),outline=C['gold'],width=2)
    elif id=='intro_immersion':
        sample=t+.25;fraction=(int(sample*60)%360)/359
        px=113+132*fraction;py=207-47*fraction
        left=max(0,min(240,int(px)-120));top=max(0,min(185,int(py)-80));crop=(left,top,left+240,top+135)
        opening_zoom(im,'entry',sample,crop)
        immersion=min(.96,float(map_data[int(py),int(px),2])/255*1.15)
        surface_y=py-33*immersion*.55+immersion*5
        opening_callout(im,'渐进浸没与曲面水线',(1110,170),(px,surface_y),crop,C['mint'])

def comparison(im,left,right,t,labels=('关闭','开启'),crop=(20,30,460,310),scale=2):
    d=ImageDraw.Draw(im)
    for i,name in enumerate([left,right]):
        x=48+i*944;d.rectangle((x-2,204,x+882,812),fill=C['panel'],outline='#547e83',width=2)
        frame=source_frame(name,t).crop(crop);frame=frame.resize((frame.width*scale,frame.height*scale),Image.Resampling.NEAREST)
        assert frame.width<=880 and frame.height<=560
        im.paste(frame,(x+(880-frame.width)//2,240+(560-frame.height)//2))
        tag(im,(x+16,156),labels[i],C['muted'] if i==0 else C['mint'])

def text_panel(im,heading,rows):
    text(im,(1080,216),heading,48,C['gold'])
    y=307
    for row in rows:
        for r in wrap(row,36,760):text(im,(1080,y),r,36,C['white']);y+=52
        y+=27

def semantic(im,t):
    labels=[('water','R · 水域',C['blue']),('shore','G · 距岸',C['gold']),('depth','B · 水深',C['blue']),('walk','A · 可走',C['mint'])]
    for i,(key,label,color) in enumerate(labels):
        x=48+(i%2)*480;y=182+(i//2)*340
        im.paste(assets[key],(x,y));tag(im,(x+12,y+12),label,color)
    text_panel(im,'数据不是美术颜色',[
        '水域约束绘制和折射边界',
        '距岸驱动泡沫往复',
        '水深驱动色阶与浸没',
        '可走范围服务导航',
        '水下石头不等于干地'])

def stack(im,t):
    full_game(im,'day',t)
    entries=['底图：海床与材质','水面：深浅、折射与光纹','瀑布：水幕、落点与汇流','倒影 + 含浸没处理的角色','前景：按脚点重画遮挡']
    current=min(4,int(t/1.65))
    d=ImageDraw.Draw(im)
    for i,label in enumerate(entries):
        y=210+i*125;col=C['gold'] if i==current else C['mint']
        d.rectangle((1080,y,1850,y+86),fill=C['panel'],outline=col,width=3 if i==current else 1)
        text(im,(1104,y+25),f'{i+1}  '+label,36,col)
        if i<4:arrow(d,(1465,y+90),(1465,y+118),C['muted'],3)

def refraction(im,t):
    comparison(im,'refraction_off','refraction_on',t,('折射关闭','像素折射开启'),(120,145,340,285),4)
    d=ImageDraw.Draw(im)
    for i in range(6):
        x=118+i*98;y=860+int(math.sin(t*1.3+i)*12)
        arrow(d,(x,y),(x+int(math.sin(i+t)*18),y+int(math.cos(t+i)*10)),C['blue'],3)
    text(im,(1080,850),'floor(位移 + 0.5)',36,C['gold'])
    text(im,(1080,897),'岸外采样 → 退回原像素',24,C['mint'])

def height_diagram(im,t):
    d=ImageDraw.Draw(im)
    for x0,sp,label in [(125,sprite,'角色原图'),(530,height_sprite,'局部高度')]:
        d.rectangle((x0-35,208,x0+355,788),fill=C['panel'],outline='#547e83',width=2)
        sp=sp.resize((320,440),Image.Resampling.NEAREST);im.paste(sp,(x0,270),sp)
        tag(im,(x0-8,164),label)
        surface=.18+.37*(.5-.5*math.cos(t*.65))
        pts=[]
        for j in range(321):
            local=j/320;yy=270+(1-surface+((abs(local-.5)*2)**2)*.065)*440
            pts.append((x0+j,yy))
        d.line(pts,fill=C['gold'],width=5)
    frame=source_frame('entry',t).crop((135,110,265,220)).resize((650,550),Image.Resampling.NEAREST);im.paste(frame,(1170,248))
    text(im,(1080,170),'地图深度 → 浸没量',36,C['mint'])
    text(im,(1080,828),'纵向梯度 + 横向曲线',36,C['gold'])
    text(im,(1080,880),'低于水位的像素进入水下处理',24,C['muted'])

def parameter_frame(im,t,source_time):
    # This is an existing real full-window recording, not a fabricated UI.
    data=parameter_frames[int((source_time+t)*60)%len(parameter_frames)]
    frame=Image.fromarray(np.asarray(data));im.paste(frame,(48,130))
    text(im,(1510,240),'158',120,C['gold'])
    lines(im,(1510,420),['实时参数','默认值','有效范围','命名预设'],36,C['mint'],40)

parameter_path=a.work/'captures/parameter-ui.rgb'
if not parameter_path.exists():
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(a.project/'media/demos/parameter-workbench.mp4'),'-an','-pix_fmt','rgb24','-f','rawvideo',str(parameter_path)],check=True)
parameter_frames=np.memmap(parameter_path,dtype=np.uint8,mode='r',shape=(parameter_path.stat().st_size//(800*1440*3),800,1440,3))

def pitfall_stack(im,t):
    comparison(im,'caustics_on','caustics_on',t,('问题：静态纹理叠加动态亮线','修正：清理后按需叠加'),(90,150,310,290),4)
    # Deliberately labelled explanatory reconstruction, not historical footage.
    crop_mask=map_data[150:290,90:310,0]>.5
    yy,xx=np.indices(crop_mask.shape);field=np.abs(np.sin(xx*.17+t*.9)*np.sin(yy*.14-t*.6));static=np.abs(np.sin(xx*.23)*np.sin(yy*.19))
    overlay=np.zeros((140,220,4),dtype=np.uint8);overlay[:,:,:3]=[200,242,218];overlay[:,:,3]=((field<.13)|(static<.10))*crop_mask*150
    ov=Image.fromarray(overlay).resize((880,560),Image.Resampling.NEAREST);im.paste(ov,(48,240),ov)
    tag(im,(64,830),'原理复现 · 非历史故障录像',C['gold'])
    text(im,(1040,848),'先减静态高频，再调动态强度',36,C['mint'])

def pitfall_mask(im,t):
    # Exact failure mechanism: G/B copied from neighbours into non-water pixels.
    from scipy.ndimage import binary_dilation
    comparison(im,'foam_on','foam_on',t,('问题：技术图通道被修补','修正：禁用边缘修复'),(20,30,460,310),2)
    water=map_data[:,:,0]>127
    leak=binary_dilation(water,iterations=3)&~water
    wrong=np.zeros((320,480,4),dtype=np.uint8);wrong[:,:,:3]=[110,213,227];wrong[:,:,3]=leak*210
    overlay=Image.fromarray(wrong).crop((20,30,460,310)).resize((880,560),Image.Resampling.NEAREST);im.paste(overlay,(48,240),overlay)
    tag(im,(64,830),'原理复现 · 越界区域着色示意',C['gold'])
    text(im,(1040,844),'fix_alpha_border = false',36,C['mint'])
    text(im,(1040,893),'数据遮罩独立导入 + 岸外像素检查',24,C['white'])

def refs_tech(im):
    refs=[
      ('How I Created 2D Pixel Art Water For My Indie Game','Fishy Games · 二维分层、扰动与倒影','youtube.com/watch?v=DkfKwfjaVx0','https://www.youtube.com/watch?v=DkfKwfjaVx0'),
      ('How I Created Pixel Art Oceans | Pixel Perfect','Red Giraffe · 深度、泡沫与像素尺度','youtube.com/watch?v=RU3EReALbEU','https://www.youtube.com/watch?v=RU3EReALbEU'),
      ('How did Sea of Stars render varying submersion on water?','r/gamedev · 社区方案推测，非官方解密','reddit.com/comments/1d3cdqq','https://www.reddit.com/r/gamedev/comments/1d3cdqq/how_did_sea_of_stars_render_varying_submersion_on/')]
    d=ImageDraw.Draw(im)
    for i,(title,desc,url,full) in enumerate(refs):
        y=160+i*239;d.rectangle((48,y,1872,y+211),fill=C['panel'],outline='#547e83',width=2)
        text(im,(74,y+25),title,24,C['white']);text(im,(74,y+82),desc,36,C['mint']);text(im,(74,y+151),url,24,C['blue']);qr_box(im,full,(1650,y+17,180))
    text(im,(60,897),'引擎资料：docs.godotengine.org · 完整链接见随片参考清单',24,C['muted'])

def refs_art(im):
    lines(im,(60,172),['风格参考','用户提供的像素 JRPG 水景截图'],36,C['mint'],24)
    lines(im,(60,335),['场景与角色素材','ImageGen 原创生成 · 提示词与来源已归档'],36,C['white'],24)
    lines(im,(60,510),['Z 工坊像素黑体 12px','字体原生像素字形 / SIL OFL 1.1'],36,C['white'],24)
    text(im,(60,650),'女声参考：Kokoro zf_001 合成录音',24,C['muted'])
    text(im,(60,693),'配音：Higgs TTS 3 Q8_0',36,C['mint'])
    text(im,(60,745),'Boson AI Higgs Audio · AI 合成旁白',24,C['white'])
    text(im,(60,782),'huggingface.co/bosonai/higgs-tts-3-4b',24,C['blue'])
    text(im,(60,817),'github.com/winkidney/pixel-art-water-vfx-demo',24,C['blue'])
    text(im,(60,867),'项目文档与制作源文件 · 私人仓库需访问权限',24,C['muted'])
    qr_box(im,'https://huggingface.co/bosonai/higgs-tts-3-4b',(1320,620,225))
    qr_box(im,'https://github.com/winkidney/pixel-art-water-vfx-demo',(1590,620,225))
    frame=source_frame('night',2).crop((60,20,420,260)).resize((720,480),Image.Resampling.NEAREST);im.paste(frame,(1150,140))
    tag(im,(1170,170),'Godot 实机',C['mint'])

def draw_scene(shot,t):
    im=templates[shot['id']].copy();id=shot['id']
    if id in ['intro_day','intro_night','intro_immersion']:
        opening(im,id,t)
    elif id=='semantic':pass
    elif id=='stack':stack(im,t)
    elif id=='refraction':refraction(im,t)
    elif id in ['depth','caustics','foam']:
        crop={'depth':(20,30,460,310),'caustics':(90,150,310,290),'foam':(45,145,265,285)}[id];scale=2 if id=='depth' else 4
        comparison(im,id+'_off',id+'_on',t,('效果关闭','效果开启'),crop,scale)
        note={'depth':'海床可读性 + 水色体积感','caustics':'图案密度与亮度，需要一起控制','foam':'沿距离场移动，不在干地画白边'}[id]
        text(im,(56,851),note,36,C['mint'])
    elif id=='ripples':
        full_game(im,'ripples',t);text_panel(im,'事件驱动的水面反馈',['点击 / 移动 / 空格','椭圆环向外扩散','同时影响亮线与折射','寿命 2.8 s · 速度 15 px/s'])
    elif id=='falls':
        full_game(im,'falls',t);text_panel(im,'一股水流，三个区域',['水幕：双相滚动采样','落点：径向扰动与明暗','主水域：衰减汇流波','只在对应遮罩内更新'])
    elif id=='environment':
        full_game(im,'environment',t);text_panel(im,'二维光色关系',['桥身：原画颜色投影','冷月光 / 暖灯：破碎光带','锚点按本场景手工校准','不是三维反射相机'])
    elif id=='height':height_diagram(im,t)
    elif id=='immersion':
        full_game(im,'entry',t);frame=source_frame('entry',t).crop((100,100,280,220)).resize((720,480),Image.Resampling.NEAREST);im.paste(frame,(1125,280));tag(im,(1125,180),'水线局部放大',C['gold']);text(im,(1090,807),'水下染色 + 透明 + 扰动',36,C['mint']);text(im,(1090,864),'倒影：翻转 + 压缩 + 扰动',24,C['white'])
    elif id=='occlusion':comparison(im,'occlusion_off','occlusion_on',t,('无前景遮挡','按脚点恢复前景'),(136,59,224,129),8)
    elif id=='parameters':parameter_frame(im,t,.5)
    elif id=='color':comparison(im,'color_day','color_night',t,('白天：共享调整','夜晚：保留基准光色'))
    elif id=='preset':parameter_frame(im,t,14.0)
    elif id=='pitfall_stack':pitfall_stack(im,t)
    elif id=='pitfall_mask':pitfall_mask(im,t)
    elif id=='pitfall_waterline':
        comparison(im,'waterline_bad','deep',t,('未匹配比例 · 水线倍率 0.80','按角色校准 · 水线倍率 0.55'),(210,120,280,190),8)
        tag(im,(64,830),'原理复现 · 实机参数对照',C['gold']);text(im,(1040,848),'水线、下沉、出水点一起校准',36,C['mint'])
    elif id in ['refs_tech','refs_art']:pass
    else:raise ValueError(id)
    return im

templates={}
for shot in plan['shots']:
    im=base(shot)
    if shot['id']=='semantic':semantic(im,0)
    if shot['id']=='refs_tech':refs_tech(im)
    if shot['id']=='refs_art':refs_art(im)
    templates[shot['id']]=im

def finish(im,absolute):
    d=ImageDraw.Draw(im);d.rectangle((0,925,1919,1004),fill=C['bg'])
    cue=next((c for c in cues if c['start']<=absolute<c['end']),None)
    if cue:
        rows=wrap(cue['text'],36,1776);assert len(rows)<=2,(cue['text'],rows)
        yy=934 if len(rows)==2 else 949
        for row in rows:text(im,((1920-width(row,36))//2,yy),row,36,C['white']);yy+=38
    current=next(i for i,c in enumerate(plan['chapters']) if c[0]<=absolute<c[1]);d.rectangle((0,1004,1919,1079),fill='#102129')
    totalw=1824;bounds=[48]
    for start,end,_,_ in plan['chapters']:bounds.append(bounds[-1]+round((end-start)/178*totalw))
    bounds[-1]=1872
    for i,(start,end,label,title) in enumerate(plan['chapters']):
        x1,x2=bounds[i:i+2];d.rectangle((x1,1021,x2-2,1066),fill='#2c4149')
        if absolute>=end:d.rectangle((x1,1021,x2-2,1066),fill=C['mint'])
        elif absolute>=start:d.rectangle((x1,1021,x1+int((x2-x1-2)*(absolute-start)/(end-start)),1066),fill=C['gold'])
        color=C['bg'] if i<current else C['white'];label_x=int((x1+x2-width(label,24))/2)
        text(im,(label_x,1033),label,24,color)
        if i==current:
            filled=x1+int((x2-x1-2)*(absolute-start)/(end-start))
            glyph=mask(label,24);cut=max(0,min(glyph.width,filled-label_x))
            if cut:im.paste(C['bg'],(label_x,1033),glyph.crop((0,0,cut,glyph.height)))
    timer=f'{int(absolute)//60:02d}:{int(absolute)%60:02d} / 02:58'
    # Compact time lives inside the top header, away from the subtitle and chapter strip.
    d.rectangle((1715,113,1919,145),fill=C['bg']);text(im,(1730,118),timer,24,C['muted'])
    return im

audit(FONT_STRINGS+['原理复现','白天','夜晚','像素折射','技术与美术参考'])
a.out.mkdir(parents=True,exist_ok=True)
if a.preview:
    for shot in plan['shots']:
        t=min(shot['duration']/2,3.0);finish(draw_scene(shot,t),shot['start']+t).save(a.out/f'preview-{shot["id"]}.png')
    thumbs=Image.new('RGB',(1920,math.ceil(len(plan['shots'])/4)*270),C['bg'])
    for i,shot in enumerate(plan['shots']):
        frame=Image.open(a.out/f'preview-{shot["id"]}.png').resize((480,270),Image.Resampling.NEAREST);thumbs.paste(frame,((i%4)*480,(i//4)*270))
    thumbs.save(a.out/'storyboard-contact-sheet.png');print('PREVIEWS',len(plan['shots']))
else:
    target=a.out/'picture.mp4'
    cmd=['ffmpeg','-v','error','-y','-f','rawvideo','-pixel_format','rgb24','-video_size','1920x1080','-framerate','60','-i','pipe:0','-an','-c:v','libx264','-preset','veryfast','-crf','18','-threads','6','-pix_fmt','yuv420p','-movflags','+faststart',str(target)]
    process=subprocess.Popen(cmd,stdin=subprocess.PIPE)
    try:
        for shot in plan['shots']:
            print('RENDER',shot['id'],flush=True)
            for frame in range(shot['duration']*60):
                t=frame/60;im=finish(draw_scene(shot,t),shot['start']+t);process.stdin.write(im.tobytes())
        process.stdin.close();assert process.wait()==0
    except BaseException:
        process.kill();raise
    final=a.out/'pixel-water-shader.mp4'
    audio_file=a.audio_file or a.out/'narration.wav'
    audio_options=['-c:a','copy'] if a.audio_file else ['-c:a','aac','-b:a','192k','-ar','48000']
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(target),'-i',str(audio_file),'-f','ffmetadata','-i',str(a.out/'chapters.ffmetadata'),'-map','0:v:0','-map','1:a:0','-map_metadata','2','-map_chapters','2','-c:v','copy',*audio_options,'-t','178','-movflags','+faststart',str(final)],check=True)
    print('COMPLETE',final,flush=True)
