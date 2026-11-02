"""Restore the archived lossless game captures into a caller-chosen work folder."""
import argparse,json,subprocess,shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);a=p.parse_args();src=Path(__file__).parent/'capture-assets';dest=a.work/'captures';dest.mkdir(parents=True,exist_ok=True)
report=json.loads((src/'capture-report.json').read_text())
for item in report['shots']:
    name=item['id'];path=dest/f'{name}.rgb'
    if not path.exists():subprocess.run(['ffmpeg','-v','error','-y','-i',str(src/f'{name}.mp4'),'-f','rawvideo','-pix_fmt','rgb24',str(path)],check=True)
    if not (dest/f'{name}.png').exists():
        subprocess.run(['ffmpeg','-v','error','-y','-ss',str(item['seconds']/2),'-i',str(src/f'{name}.mp4'),'-frames:v','1',str(dest/f'{name}.png')],check=True)
shutil.copy2(src/'capture-report.json',dest/'capture-report.json')
audio=Path(__file__).parent/'narration-assets'
if audio.exists():
    target=a.work/'audio';target.mkdir(parents=True,exist_ok=True)
    for path in audio.iterdir():
        if path.is_file():shutil.copy2(path,target/path.name)
print('Prepared',len(report['shots']),'real game clips')
