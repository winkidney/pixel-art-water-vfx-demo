"""Package the complete distributable checkout; local caches remain outside."""
import argparse,hashlib,json,os,subprocess,zipfile
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--working-tree',action='store_true',help='Explicitly include uncommitted working files.');p.add_argument('--dry-run',action='store_true');p.add_argument('--out',type=Path);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
def git(*args):return subprocess.run(['git','-C',str(root),*args],capture_output=True,text=True)
top=git('rev-parse','--show-toplevel');is_repo=top.returncode==0 and Path(top.stdout.strip()).resolve()==root.resolve()
dirty=git('status','--porcelain').stdout.strip() if is_repo else 'not a Git checkout'
if dirty and not a.working_tree:raise SystemExit('Working tree has changes; use --working-tree to package an explicitly labelled snapshot.')
commit=git('rev-parse','HEAD').stdout.strip() if is_repo else None
excluded={'.git','.local','.godot','__pycache__','captures'};files=[]
for folder,dirs,names in os.walk(root):
    dirs[:]=[d for d in dirs if d not in excluded]
    for name in names:
        path=Path(folder)/name
        if path.suffix in {'.zip','.avi','.pyc'}:continue
        files.append(path)
files.sort();summary={'files':len(files),'bytes':sum(p.stat().st_size for p in files),'commit':commit,'uncommitted_snapshot':bool(dirty),'dry_run':a.dry_run}
if a.dry_run:print(json.dumps(summary,ensure_ascii=False,indent=2));raise SystemExit()
archive=a.out or root/'.local/dist/pixel-art-water-vfx-demo.zip';archive.parent.mkdir(parents=True,exist_ok=True);temp=archive.with_suffix('.zip.tmp')
with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as package:
    for path in files:package.write(path,path.relative_to(root))
    package.comment=json.dumps({'source_commit':commit,'uncommitted_snapshot':bool(dirty)},ensure_ascii=False).encode()
with zipfile.ZipFile(temp) as package:
    assert package.testzip() is None and 'demo/project.godot' in package.namelist()
    for path in files:assert hashlib.sha256(package.read(str(path.relative_to(root)))).hexdigest()==hashlib.file_digest(path.open('rb'),'sha256').hexdigest()
temp.replace(archive);summary.update(path=str(archive),zip_bytes=archive.stat().st_size,sha256=hashlib.file_digest(archive.open('rb'),'sha256').hexdigest(),crc_and_source_hashes='passed')
(archive.parent/'package-report.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');print(json.dumps(summary,ensure_ascii=False,indent=2))
