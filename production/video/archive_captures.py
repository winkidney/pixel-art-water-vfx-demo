"""Store lossless RGB footage with exact roundtrip verification."""
import argparse,json,subprocess,hashlib
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--dest',type=Path,required=True);a=p.parse_args();a.dest.mkdir(exist_ok=True,parents=True)
report=json.loads((a.work/'captures/capture-report.json').read_text())
def encode(item):
    name=item['id'];src=a.work/'captures'/f'{name}.rgb';dest=a.dest/f'{name}.mp4'
    subprocess.run(['ffmpeg','-v','error','-y','-f','rawvideo','-pixel_format','rgb24','-video_size','480x320','-framerate','60','-i',str(src),'-an','-c:v','libx264rgb','-crf','0','-preset','fast','-threads','2','-movflags','+faststart',str(dest)],check=True)
    process=subprocess.Popen(['ffmpeg','-v','error','-i',str(dest),'-f','rawvideo','-pix_fmt','rgb24','pipe:1'],stdout=subprocess.PIPE)
    digest=hashlib.sha256()
    while chunk:=process.stdout.read(1024*1024):digest.update(chunk)
    assert process.wait()==0
    original=hashlib.sha256()
    with src.open('rb') as f:
        while chunk:=f.read(1024*1024):original.update(chunk)
    assert digest.digest()==original.digest(),name
    return {'id':name,'frames':item['frames'],'raw_sha256':original.hexdigest(),'file_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'bytes':dest.stat().st_size,'roundtrip':'bit-exact RGB'}
with ThreadPoolExecutor(max_workers=2) as pool:receipts=list(pool.map(encode,report['shots']))
(a.dest/'capture-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
(a.dest/'lossless-receipts.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'clips':len(receipts),'bytes':sum(x['bytes'] for x in receipts),'rgb_roundtrip':'passed'}))
