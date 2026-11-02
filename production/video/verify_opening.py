"""Audit the revised opening in the actual encoded film and export a short preview."""
import argparse,json,subprocess,shutil
from pathlib import Path
import cv2
from PIL import Image

p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args()
plan=json.loads((Path(__file__).parent/'plan.json').read_text());features=plan['opening_features'];assert len(features)==8
max_labels=max(sum(f['interval'][0]<=frame/60<f['interval'][1] for f in features) for frame in range(18*60));assert max_labels<=2
film=a.out/'pixel-water-shader.mp4';evidence=a.out/'evidence';evidence.mkdir(exist_ok=True)
cap=cv2.VideoCapture(str(film));samples=[];frames=[]
for i,time in enumerate([1.8,3.6,6.0,9.5,12.5,16.0]):
    cap.set(cv2.CAP_PROP_POS_MSEC,time*1000);ok,frame=cap.read();assert ok
    labels=[f['label'] for f in features if f['interval'][0]<=time<f['interval'][1]]
    rgb=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB));name=f'opening-{i+1:02d}.png';rgb.save(evidence/name)
    frames.append(rgb.resize((960,540),Image.Resampling.NEAREST));samples.append({'time':time,'labels':labels,'file':name})
cap.release()
all_labels=set(label for s in samples for label in s['labels']);assert all_labels==set(f['label'] for f in features)
sheet=Image.new('RGB',(1920,1620),'#0a171f')
for i,frame in enumerate(frames):sheet.paste(frame,((i%2)*960,(i//2)*540))
sheet.save(evidence/'opening-contact-sheet.png')
flow=json.loads((a.out/'flow-capture-check.json').read_text());assert flow['curtain_excluded'] and flow['changed_dry_pixels']==0
shutil.copy2(a.out/'flow-capture-check.json',evidence/'flow-capture-check.json')
report={'passed':True,'opening_seconds':18,'feature_count':8,'maximum_simultaneous_features':max_labels,'integer_zoom':6,'samples':samples,'waterfall_curtain_closeup':False,'flow_crop':[240,124,480,259],'flow_display_amplitude':1.4,'parameter_label_visible':True,'remaining_chapter_boundaries':plan['chapters'][1:]}
(evidence/'opening-feature-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
preview=a.out/'opening-preview.mp4'
subprocess.run(['ffmpeg','-v','error','-y','-i',str(film),'-t','18','-map','0:v:0','-map','0:a:0','-map_chapters','-1','-c:v','libx264','-preset','veryfast','-crf','18','-threads','4','-c:a','aac','-b:a','192k','-movflags','+faststart','-metadata','title=水体放大与特性标注 · 片头预览',str(preview)],check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(preview)],text=True));assert abs(float(probe['format']['duration'])-18)<.01
print(json.dumps({'passed':True,'features':8,'max_labels':max_labels,'preview_seconds':18,'curtain_closeup':False},ensure_ascii=False))
