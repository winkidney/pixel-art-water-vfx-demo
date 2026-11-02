"""Package video authoring sources while retaining repository-relative paths."""
from pathlib import Path
import argparse,hashlib,json,zipfile
p=argparse.ArgumentParser();p.add_argument('--out',type=Path);p.add_argument('--dry-run',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[1];source=root/'production/video'
files=[path for path in source.rglob('*') if path.is_file() and '__pycache__' not in path.parts and path.suffix!='.pyc']
files.extend(root/name for name in ['docs/video-production.md','docs/video-references.md','media/video/title.txt','media/video/description.txt','media/video/chapters.txt','media/video/subtitles.srt'])
summary={'files':len(files),'bytes':sum(p.stat().st_size for p in files),'contains':'Authoring code, original captures, narration, fonts, supplied music and sources. Model weights and final movies excluded.'}
if a.dry_run:print(json.dumps(summary,indent=2));raise SystemExit()
archive=a.out or root/'.local/dist/video-source.zip';archive.parent.mkdir(parents=True,exist_ok=True);temporary=archive.with_suffix('.zip.tmp')
with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as package:
    for path in sorted(files):package.write(path,path.relative_to(root))
    package.comment=b'Video authoring sources, repository-relative layout.'
with zipfile.ZipFile(temporary) as package:
    assert package.testzip() is None
    for path in files:assert hashlib.sha256(package.read(str(path.relative_to(root)))).hexdigest()==hashlib.file_digest(path.open('rb'),'sha256').hexdigest()
temporary.replace(archive);summary.update(path=str(archive),sha256=hashlib.file_digest(archive.open('rb'),'sha256').hexdigest(),crc_and_source_hashes='passed');print(json.dumps(summary,indent=2))
