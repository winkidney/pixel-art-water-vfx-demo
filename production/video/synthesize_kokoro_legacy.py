"""Synthesize short Mandarin sentences with a documented Kokoro female voice."""
import argparse, json, os, hashlib
from pathlib import Path
import numpy as np
import soundfile as sf
import torch

parser=argparse.ArgumentParser()
parser.add_argument('--work',type=Path,required=True)
parser.add_argument('--sample',action='store_true')
parser.add_argument('--allow-download',action='store_true',help='Allow first-time public model download into the selected work cache.')
args=parser.parse_args()
work=args.work
os.environ.setdefault('HF_HOME',str(work/'cache/huggingface'))
os.environ.setdefault('XDG_CACHE_HOME',str(work/'cache'))
if not args.allow_download:os.environ['HF_HUB_OFFLINE']='1'
from kokoro import KModel,KPipeline
torch.set_num_threads(4)
repo='hexgrad/Kokoro-82M-v1.1-zh'
model=KModel(repo_id=repo).to('cpu').eval()
pipeline=KPipeline(lang_code='z',repo_id=repo,model=model)
plan=json.loads((Path(__file__).parent/'plan.json').read_text())
out=work/'audio';out.mkdir(exist_ok=True)
report=[]
for shot in plan['shots'][:1] if args.sample else plan['shots']:
    records=[];chunks=[]
    for i,line in enumerate(shot['lines']):
        path=out/f'{shot["id"]}-{i:02d}.wav'
        stamp=path.with_suffix('.txt')
        if path.exists() and stamp.exists() and stamp.read_text()==line:
            wav,sr=sf.read(path,dtype='float32');assert sr==24000
        else:
            results=list(pipeline(line,voice='zf_001',speed=1.05))
            wav=np.concatenate([r.audio.numpy() for r in results])
            sf.write(path,wav,24000,subtype='PCM_16')
            stamp.write_text(line)
        records.append({'text':line,'file':path.name,'seconds':len(wav)/24000})
        chunks.extend([wav,np.zeros(2400,dtype=np.float32)])
    combined=np.concatenate(chunks)
    sf.write(out/f'{shot["id"]}.wav',combined,24000,subtype='PCM_16')
    item={'id':shot['id'],'voice':'zf_001','seconds':len(combined)/24000,'budget':shot['duration'],'sentences':records}
    report.append(item)
    print(json.dumps({k:v for k,v in item.items() if k!='sentences'},ensure_ascii=False),flush=True)
(out/('sample-report.json' if args.sample else 'speech-report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
