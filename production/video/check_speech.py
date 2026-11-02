"""Independent ASR spot-check of synthesized narration; not the subtitle source."""
import argparse,json,re,os,hashlib
from pathlib import Path
from difflib import SequenceMatcher
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
from faster_whisper import WhisperModel
model=WhisperModel('small',device='cpu',compute_type='int8',cpu_threads=4,download_root=str(a.work/'cache/asr'))
plan=json.loads((Path(__file__).parent/'plan.json').read_text());report=[]
previous={}
if (a.out/'speech-asr-check.json').exists():previous={r['id']:r for r in json.loads((a.out/'speech-asr-check.json').read_text())}
def norm(s):return re.sub(r'[^\u4e00-\u9fff0-9a-z]','',s.lower())
for shot in plan['shots']:
    expected=''.join(shot['lines'])
    audio_sha256=hashlib.sha256((a.work/'audio'/f'{shot["id"]}.wav').read_bytes()).hexdigest()
    if shot['id'] in previous and previous[shot['id']]['expected']==expected and previous[shot['id']].get('audio_sha256')==audio_sha256:
        report.append(previous[shot['id']]);continue
    segments,info=model.transcribe(str(a.work/'audio'/f'{shot["id"]}.wav'),language='zh',beam_size=3,vad_filter=False,condition_on_previous_text=False)
    actual=''.join(s.text for s in segments)
    similarity=SequenceMatcher(None,norm(expected),norm(actual)).ratio()
    row={'id':shot['id'],'expected':expected,'recognized':actual,'similarity':similarity,'audio_sha256':audio_sha256}
    report.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
(a.out/'speech-asr-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
