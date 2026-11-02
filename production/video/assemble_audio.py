import argparse,json,subprocess
from pathlib import Path
import numpy as np
import soundfile as sf

p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(exist_ok=True,parents=True)
plan=json.loads((Path(__file__).parent/'plan.json').read_text());report=json.loads((a.work/'audio/speech-report.json').read_text());byid={x['id']:x for x in report}
track=np.zeros(178*48000,dtype=np.float32);cues=[];summary=[]
for shot in plan['shots']:
    info=byid[shot['id']];factor=max(1,info['seconds']/(shot['duration']-.45))
    assert factor<=1.12,(shot['id'],factor)
    processed=a.work/'audio'/f'{shot["id"]}-timed.wav'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(a.work/'audio'/f'{shot["id"]}.wav'),'-af',f'atempo={factor:.9f}','-ar','48000',str(processed)],check=True)
    wav,sr=sf.read(processed,dtype='float32');offset=round((shot['start']+.20)*48000)
    assert offset+len(wav)<=round((shot['start']+shot['duration']-.15)*48000)+4800
    track[offset:offset+len(wav)]=wav
    cursor=shot['start']+.20
    for sentence in info['sentences']:
        length=sentence['seconds']/factor
        cues.append({'start':cursor,'end':cursor+length,'text':sentence['text'].replace('戈多','Godot'),'shot':shot['id']})
        cursor+=length+.1/factor
    summary.append({'id':shot['id'],'tempo':factor,'audio_seconds':len(wav)/48000,'shot_end':shot['start']+shot['duration'],'audio_end':offset/48000+len(wav)/48000})
sf.write(a.work/'audio/assembled.wav',track,48000,subtype='PCM_16')
subprocess.run(['ffmpeg','-v','error','-y','-i',str(a.work/'audio/assembled.wav'),'-af','loudnorm=I=-16:TP=-1.5:LRA=7','-ar','48000',str(a.out/'narration.wav')],check=True)
def stamp(s):
    ms=round(s*1000);return f'{ms//3600000:02d}:{ms//60000%60:02d}:{ms//1000%60:02d},{ms%1000:03d}'
(a.out/'subtitles.srt').write_text('\n\n'.join(f'{i+1}\n{stamp(c["start"])} --> {stamp(c["end"])}\n{c["text"]}' for i,c in enumerate(cues))+'\n')
(a.out/'subtitle-cues.json').write_text(json.dumps(cues,ensure_ascii=False,indent=2)+'\n')
(a.out/'audio-timing.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
metadata=[';FFMETADATA1','title='+plan['title'],'artist=Pixel-art water VFX experiment','comment=Godot real GPU captures; Higgs TTS 3 Q8_0; fixed synthetic female reference; 2026-11-02']
for start,end,label,title in plan['chapters']:metadata.extend(['[CHAPTER]','TIMEBASE=1/1000',f'START={start*1000}',f'END={end*1000}','title='+title])
(a.out/'chapters.ffmetadata').write_text('\n'.join(metadata)+'\n')
print(json.dumps({'sentences':len(cues),'seconds':len(track)/48000,'maximum_tempo':max(x['tempo'] for x in summary)},ensure_ascii=False))
