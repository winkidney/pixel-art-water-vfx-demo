"""Recreate the selected Q8 clone locally; keep raw audio and exact requests."""
import argparse,hashlib,json,os,re,socket,subprocess,time,urllib.request
from pathlib import Path
import numpy as np
import soundfile as sf

p=argparse.ArgumentParser()
p.add_argument('--work',type=Path,required=True)
p.add_argument('--runtime-root',type=Path,required=True,help='Folder containing runtime/ and models/. Weights are not distributed with the video.')
p.add_argument('--ids',nargs='*')
p.add_argument('--split-ids',nargs='*',default=['refs_tech'],help='Split a problematic long request at sentence stops without changing the narration text.')
a=p.parse_args();src=Path(__file__).parent;root=a.runtime_root
audio=a.work/'audio';audio.mkdir(parents=True,exist_ok=True)
logs=audio/'higgs-logs';logs.mkdir(exist_ok=True)
rawdir=audio/'raw';rawdir.mkdir(exist_ok=True)
def sha(path):return hashlib.file_digest(path.open('rb'),'sha256').hexdigest()
model=root/'models/higgs-audio-v3-tts-4b-q8_0.gguf'
assert sha(model)=='cfa5cc01adcd199dfcf1baf0f610aa474cda83418fd1802aa6defa82d956a0e4'
binary=next((root/'runtime/audiocpp').rglob('audiocpp_server'))
libraries={str(binary.parent)}
for base in ['audiocpp','cuda-libs','nccl']:libraries.update(str(x.parent) for x in (root/'runtime'/base).rglob('*.so*'))
env=os.environ.copy();env['LD_LIBRARY_PATH']=':'.join(sorted(libraries))+':'+env.get('LD_LIBRARY_PATH','');env['OMP_NUM_THREADS']='4'
reference=src/'reference/female-zf001.wav';reftext=(src/'reference/female-zf001.txt').read_text().strip()
with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
config={'host':'127.0.0.1','port':port,'backend':'cuda','device':0,'threads':4,'lazy_load':True,'max_loaded_models':1,'ui':False,'models':[{'id':'higgs','family':'higgs_audio_tts','path':str(model.resolve()),'task':'clon','mode':'offline'}]}
config_path=logs/'server.json';config_path.write_text(json.dumps(config,indent=2))
command=[str(binary.resolve()),'--config',str(config_path.resolve()),'--no-ui','--log']
plan=json.loads((src/'plan.json').read_text());report=[];started=time.monotonic()
provenance={'model':'bosonai/higgs-tts-3-4b','quantization':'Q8_0','quantized_revision':'874fcb41ececda20bcbc0782d6b4ea7f7d069ea8','model_sha256':sha(model),'runtime':'audio.cpp v0.9.3 CUDA','binary_sha256':sha(binary),'reference_sha256':sha(reference),'reference_text':reftext,'seed':20261102,'options':{'text_chunk_size':40},'sampling':'audio.cpp defaults: temperature 0.8, top_p 0.8, top_k 30','reference_origin':'Synthetic Kokoro zf_001 recording, 15.05 seconds; no human impersonation','postprocessing':'Trim only leading/trailing near-silence, retaining 80ms/140ms margins. No pitch or emotion changes. Raw files preserved.'}
(logs/'method.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
with (logs/'inference.log').open('w') as log:
    process=subprocess.Popen(command,cwd=binary.parent,env=env,stdout=log,stderr=log)
    try:
        url=f'http://127.0.0.1:{port}';deadline=time.monotonic()+30
        while True:
            if process.poll() is not None:raise RuntimeError('Higgs server exited; inspect inference.log')
            try:
                with urllib.request.urlopen(url+'/health',timeout=2) as response:json.load(response)
                break
            except OSError:
                if time.monotonic()>deadline:raise RuntimeError('Higgs server readiness timed out')
                time.sleep(.25)
        with urllib.request.urlopen(url+'/v1/models?include_params=true',timeout=5) as response:(logs/'declared-options.json').write_bytes(response.read())
        for shot in plan['shots']:
            records=[];chunks=[]
            for i,line in enumerate(shot['lines']):
                stem=f'{shot["id"]}-{i:02d}';path=audio/(stem+'.wav');raw=rawdir/(stem+'.wav');request_path=logs/(stem+'.json')
                if a.ids and shot['id'] not in a.ids and not path.exists():continue
                payload={'model':'higgs','input':line,'voice_ref':str(reference.resolve()),'reference_text':reftext,'seed':20261102,'options':{'text_chunk_size':40}}
                key=hashlib.sha256(json.dumps({'input':line,'method':provenance},sort_keys=True,ensure_ascii=False).encode()).hexdigest()
                if shot['id'] in a.split_ids:key=hashlib.sha256((key+'split-at-sentence-stops').encode()).hexdigest()
                cached=json.loads(request_path.read_text()) if request_path.exists() else {}
                if path.exists() and cached.get('cache_key')==key:
                    wav,sr=sf.read(path,dtype='float32')
                else:
                    tick=time.monotonic();parts=[x for x in re.findall(r'[^。！？]+[。！？]?',line) if x] if shot['id'] in a.split_ids else [line]
                    signals=[];requests=[]
                    for j,part in enumerate(parts):
                        actual=dict(payload,input=part);requests.append(actual)
                        request=urllib.request.Request(url+'/v1/audio/speech',data=json.dumps(actual,ensure_ascii=False).encode(),headers={'Content-Type':'application/json'})
                        part_path=raw if len(parts)==1 else rawdir/(stem+f'-part{j}.wav')
                        with urllib.request.urlopen(request,timeout=300) as response:part_path.write_bytes(response.read())
                        part_wav,sr=sf.read(part_path,dtype='float32');assert sr==24000
                        signals.append(part_wav)
                    if len(parts)>1:sf.write(raw,np.concatenate(signals),sr,subtype='PCM_16')
                    signal,sr=sf.read(raw,dtype='float32');assert sr==24000 and signal.ndim==1 and np.isfinite(signal).all()
                    assert np.max(np.abs(signal))<1 and np.sqrt(np.mean(signal**2))>1e-5
                    n=480;pad=np.pad(signal,(0,(-len(signal))%n));rms=np.sqrt(np.mean(pad.reshape(-1,n)**2,axis=1));active=np.flatnonzero(rms>10**(-48/20));assert len(active)
                    begin=max(0,int(active[0]*n)-1920);end=min(len(signal),int((active[-1]+1)*n)+3360)
                    wav=signal[begin:end];sf.write(path,wav,sr,subtype='PCM_16')
                    cached={'cache_key':key,'requests':requests,'inference_seconds':round(time.monotonic()-tick,3),'raw_sha256':sha(raw),'raw_seconds':len(signal)/sr,'trim_start_seconds':begin/sr,'trim_end_seconds':(len(signal)-end)/sr,'final_sha256':sha(path),'final_seconds':len(wav)/sr}
                    request_path.write_text(json.dumps(cached,ensure_ascii=False,indent=2)+'\n')
                path.with_suffix('.txt').write_text(line)
                assert sr==24000
                records.append({'text':line,'file':path.name,'seconds':len(wav)/sr,'sha256':sha(path)})
                chunks.extend([wav,np.zeros(2400,dtype=np.float32)])
                print(json.dumps({'id':stem,'seconds':len(wav)/sr},ensure_ascii=False),flush=True)
            if not records:continue
            combined=np.concatenate(chunks);sf.write(audio/(shot['id']+'.wav'),combined,24000,subtype='PCM_16')
            report.append({'id':shot['id'],'voice':'Higgs TTS 3 Q8_0, fixed synthetic zf_001 reference','seconds':len(combined)/24000,'budget':shot['duration'],'sentences':records})
    finally:
        if process.poll() is None:
            process.terminate()
            try:process.wait(timeout=15)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
        (logs/'shutdown.json').write_text(json.dumps({'pid':process.pid,'exit_code':process.returncode,'wall_seconds':round(time.monotonic()-started,3),'temporary_server_stopped':True},indent=2)+'\n')
(audio/'speech-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('COMPLETE',len(report),'shots; own server stopped',flush=True)
