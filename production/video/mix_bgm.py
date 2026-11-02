"""Add the supplied music under the existing voice, preserving encoded video."""
import argparse,hashlib,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--video',type=Path,required=True);p.add_argument('--narration',type=Path,required=True);p.add_argument('--music',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--music-db',type=float,default=-14)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
assert a.video.resolve()!=(a.out/'pixel-water-shader.mp4').resolve(),'Choose a separate output directory to preserve the input video.'
def run(cmd):return subprocess.run(cmd,check=True,capture_output=True,text=True)
def sha(path):return hashlib.file_digest(path.open('rb'),'sha256').hexdigest()
graph=(
    '[0:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=mono,asplit=2[voice][side];'
    '[voice]pan=stereo|c0=0.70710678*c0|c1=0.70710678*c0[center];'
    f'[1:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,atrim=duration=178,apad=whole_dur=178,volume={a.music_db}dB,'
    'afade=t=in:st=0:d=1.5,afade=t=out:st=175:d=3[bed];'
    '[bed][side]sidechaincompress=threshold=0.1:ratio=3:attack=35:release=550:knee=2.82843:makeup=1[ducked];'
    '[center][ducked]amix=inputs=2:duration=first:normalize=0:dropout_transition=0,'
    'alimiter=limit=0.841395:level=0:latency=1,atrim=duration=178,asetpts=PTS-STARTPTS[mixed]')
track=a.out/'soundtrack.wav'
run(['ffmpeg','-v','error','-y','-i',str(a.narration),'-i',str(a.music),'-filter_complex',graph,'-map','[mixed]','-ar','48000','-c:a','pcm_s24le',str(track)])
film=a.out/'pixel-water-shader.mp4'
run(['ffmpeg','-v','error','-y','-i',str(a.video),'-i',str(track),'-map','0:v:0','-map','1:a:0','-map_metadata','0','-map_chapters','0','-c:v','copy','-c:a','aac','-b:a','256k','-ar','48000','-t','178','-metadata:s:a:0','language=zho','-metadata:s:a:0','title=Higgs female narration + reduced background music','-movflags','+faststart',str(film)])
run(['ffmpeg','-v','error','-y','-i',str(film),'-map','0:a:0','-c:a','copy','-vn','-map_chapters','-1','-movflags','+faststart',str(a.out/'soundtrack.m4a')])
def video_hash(path):
    return run(['ffmpeg','-v','error','-i',str(path),'-map','0:v:0','-c:v','copy','-f','hash','-hash','sha256','-']).stdout.strip()
before=video_hash(a.video);after=video_hash(film);assert before==after
probe=json.loads(run(['ffprobe','-v','error','-show_streams','-show_format','-show_chapters','-of','json',str(film)]).stdout)
audio=[s for s in probe['streams'] if s['codec_type']=='audio'];assert len(audio)==1 and audio[0]['channels']==2 and audio[0]['sample_rate']=='48000'
assert abs(float(probe['format']['duration'])-178)<.01
receipt={'music_file':a.music.name,'music_sha256':sha(a.music),'input_video_sha256':sha(a.video),'input_narration_sha256':sha(a.narration),'output_video_sha256':sha(film),'duration_seconds':178,'music_gain_db':a.music_db,'voice_gain_db':0,'voice_spatial_mapping':'Mono centered at equal total power in stereo','music_fade_in_seconds':1.5,'music_fade_out_start':175,'music_fade_out_seconds':3,'sidechain':{'threshold':.1,'ratio':3,'attack_ms':35,'release_ms':550},'safety_limiter_dbfs':-1.5,'video_stream_hash_before':before,'video_stream_hash_after':after,'video_stream_unchanged':True,'single_mixed_audio_stream':True,'audio_channels':2,'filter':graph,'music_source':'User supplied file. Embedded metadata says made with suno. Original retained unchanged.'}
(a.out/'bgm-mix-check.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'mixed':str(film),'music_gain_db':a.music_db,'video_stream_unchanged':True,'audio_streams':1,'channels':2},ensure_ascii=False))
