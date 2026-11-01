"""Package a clean Git checkout, excluding caches and local presets."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

root = Path(__file__).resolve().parents[2]
def git(*args):
    return subprocess.check_output(['git', '-C', str(root), *args])
if git('status', '--porcelain').strip():
    raise SystemExit('Commit or preserve current changes before packaging a clean source version.')
commit = git('rev-parse', 'HEAD').decode().strip()
files = git('ls-files', '-z').decode().split('\0')
prefixes = ('tidal-grotto/', 'docs/', 'designs/stone-basin-widefall-v5/', 'evidence/stone-basin/', 'evidence/parameters/')
extras = {'README.md', 'CONTEXT.md', 'stone-basin-runtime-comparison.png', 'stone-basin-day-night-demo.mp4', 'parameter-workbench-demo.mp4', 'parameter-workbench-preview.png'}
selected = [name for name in files if name and (name.startswith(prefixes) or name in extras)]
archive = root / 'stone-basin-godot4.zip'
temporary = root / 'stone-basin-godot4.zip.tmp'
with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as out:
    for name in selected:
        out.write(root / name, name)
    out.comment = ('Source commit ' + commit + '; caches and local presets excluded.').encode()
with zipfile.ZipFile(temporary) as package:
    assert package.testzip() is None
    assert 'tidal-grotto/project.godot' in package.namelist()
    for name in package.namelist():
        assert not name.startswith('/') and '..' not in Path(name).parts and '.godot/' not in name
        assert hashlib.sha256(package.read(name)).digest() == hashlib.sha256((root / name).read_bytes()).digest()
temporary.replace(archive)
report = {'commit': commit, 'files': len(selected), 'bytes': archive.stat().st_size, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'crc_and_source_hashes': 'passed'}
(root / 'work').mkdir(exist_ok=True)
(root / 'work/package-report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
