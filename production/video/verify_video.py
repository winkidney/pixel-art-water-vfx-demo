import argparse,json,re,subprocess,hashlib
from pathlib import Path
from difflib import SequenceMatcher
import cv2,numpy as np
from PIL import Image,ImageDraw
from pypinyin import lazy_pinyin,Style

p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();out=a.out;film=out/'pixel-water-shader.mp4';evidence=out/'evidence';evidence.mkdir(exist_ok=True)
plan=json.loads((Path(__file__).parent/'plan.json').read_text())
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_streams','-show_format','-show_chapters','-of','json',str(film)],text=True))
video=next(x for x in probe['streams'] if x['codec_type']=='video');audio=next(x for x in probe['streams'] if x['codec_type']=='audio')
assert (video['width'],video['height'],video['r_frame_rate'],int(video['nb_read_frames']))==(1920,1080,'60/1',10680)
assert abs(float(probe['format']['duration'])-178)<.01
assert audio['codec_name']=='aac' and int(audio['sample_rate'])==48000
assert len(probe['chapters'])==7
cues=json.loads((out/'subtitle-cues.json').read_text());assert len(cues)==33
assert all(0<=x['start']<x['end']<=178 for x in cues)
assert all(x['end']<=y['start']+.01 for x,y in zip(cues,cues[1:]))
for path,size in [('cover-16x9.png',(1920,1080)),('cover-4x3.png',(1600,1200))]:assert Image.open(out/path).size==size
cap=cv2.VideoCapture(str(film));samples=[];thumbs=[]
for shot in plan['shots']:
    time=shot['start']+min(3,shot['duration']/2);cap.set(cv2.CAP_PROP_POS_MSEC,time*1000);ok,frame=cap.read();assert ok,shot['id']
    samples.append({'id':shot['id'],'time':time,'luma_mean':float(cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY).mean())})
    rgb=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB));thumbs.append(rgb.resize((480,270),Image.Resampling.NEAREST))
    if shot['id'] in ['intro_day','refraction','height','pitfall_mask','refs_tech','refs_art']:rgb.save(evidence/f'frame-{shot["id"]}.png')
sheet=Image.new('RGB',(1920,1620),'#0a171f')
for i,im in enumerate(thumbs):sheet.paste(im,((i%4)*480,(i//4)*270))
sheet.save(evidence/'film-contact-sheet.png')
qr_result={};decoder=cv2.QRCodeDetector()
for name in ['refs_tech','refs_art']:
    im=cv2.imread(str(evidence/f'frame-{name}.png'));ok,decoded,_,_=decoder.detectAndDecodeMulti(im);assert ok,name
    assert all(decoded),decoded
    qr_result[name]=sorted(decoded)
expected_tech=sorted(['https://www.youtube.com/watch?v=DkfKwfjaVx0','https://www.youtube.com/watch?v=RU3EReALbEU','https://www.reddit.com/r/gamedev/comments/1d3cdqq/how_did_sea_of_stars_render_varying_submersion_on/'])
expected_art=sorted(['https://github.com/winkidney/pixel-art-water-vfx-demo','https://huggingface.co/bosonai/higgs-tts-3-4b'])
assert qr_result['refs_tech']==expected_tech and qr_result['refs_art']==expected_art
cap.release()
cmd=['ffmpeg','-hide_banner','-nostats','-i',str(film),'-vf','blackdetect=d=0.5:pix_th=0.08:pic_th=0.98','-af','loudnorm=I=-16:TP=-1.5:LRA=7:print_format=json','-f','null','-']
run=subprocess.run(cmd,capture_output=True,text=True,check=True)
assert 'black_start:' not in run.stderr
metrics=json.loads(re.findall(r'\{\s*"input_i".*?\}',run.stderr,re.S)[-1]);assert float(metrics['input_tp'])<=0
(evidence/'ffmpeg-analysis.txt').write_text(run.stderr)
asr=json.loads((out/'speech-asr-check.json').read_text())
def phonetic(s):return ' '.join(lazy_pinyin(re.sub(r'[^\u4e00-\u9fff]','',s),style=Style.NORMAL))
for row in asr:row['phonetic_similarity']=SequenceMatcher(None,phonetic(row['expected']),phonetic(row['recognized'])).ratio()
(evidence/'speech-asr-check.json').write_text(json.dumps(asr,ensure_ascii=False,indent=2)+'\n')
report={'passed':True,'duration':178,'resolution':[1920,1080],'fps':60,'frames':10680,'chapters':7,'subtitle_cues':33,'sampled_shots':samples,'qr_decoded_from_final_h264':qr_result,'black_segments':[],'audio':metrics,'asr_note':'Independent spot-check only. Traditional/Simplified and homophones differ; not a claim of exact human listening verification.','film_sha256':hashlib.sha256(film.read_bytes()).hexdigest()}
(evidence/'qa-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
(evidence/'media-probe.json').write_text(json.dumps(probe,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':True,'duration':178,'frames':10680,'qr_count':5,'integrated_lufs':metrics['input_i'],'true_peak_dbfs':metrics['input_tp'],'asr_phonetic_min':min(x['phonetic_similarity'] for x in asr)},ensure_ascii=False),flush=True)
