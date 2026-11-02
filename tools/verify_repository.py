"""Check local documentation links, Godot resources and current delivery hashes."""
from pathlib import Path
import ast,hashlib,json,os,re,sys
from urllib.parse import unquote

root=Path(__file__).resolve().parents[1]
skip={'.git','.local','.godot','__pycache__','captures'}
files=[]
for folder,dirs,names in os.walk(root):
    dirs[:]=[d for d in dirs if d not in skip]
    files.extend(Path(folder)/n for n in names)
errors=[];links=0;resources=0;python_files=0
for path in files:
    if path.suffix in {'.md','.html'}:
        content=path.read_text()
        refs=re.findall(r'!?\[[^\]\n]*\]\(([^\)\n]+)\)',content)
        refs+=re.findall(r'(?:href|src)=["\x27]([^"\x27]+)',content) if path.suffix=='.html' else []
        for href in refs:
            if href.startswith(('https:','http:','mailto:','data:','#','plugin:','app:')):continue
            target=unquote(href.split('#')[0].strip('<>'))
            if not target:continue
            links+=1
            resolved=(path.parent/target).resolve()
            if not resolved.exists():errors.append(f'{path.relative_to(root)}: broken link {href}')
    if path.suffix=='.py':
        python_files+=1
        try:ast.parse(path.read_text())
        except SyntaxError as error:errors.append(f'{path.relative_to(root)}: {error}')
    if path.suffix in {'.gd','.tscn','.godot'} and path.is_relative_to(root/'demo'):
        for resource in re.findall(r'["\x27](res://[^"\x27]+)["\x27]',path.read_text()):
            if any(c in resource for c in ['%','{','*']):continue
            target=root/'demo'/resource.removeprefix('res://')
            if target.exists():resources+=1
            elif re.search(r'\.(?:png|gd|gdshader|tscn|json)$',resource):errors.append(f'{path.relative_to(root)}: missing resource {resource}')
manifest=root/'production/video/delivery-manifest.json';hashes=0
if manifest.exists():
    data=json.loads(manifest.read_text())
    if data.get('path_base')!='repository_root':errors.append('Video delivery manifest must use repository-root paths')
    for item in data['files']:
        path=root/item['path']
        if not path.is_file():errors.append('Manifest file missing: '+item['path']);continue
        if hashlib.file_digest(path.open('rb'),'sha256').hexdigest()!=item['sha256']:errors.append('Manifest hash mismatch: '+item['path'])
        hashes+=1
print(json.dumps({'passed':not errors,'markdown_and_html_links':links,'godot_resource_references':resources,'python_files':python_files,'delivery_hashes':hashes,'errors':errors},ensure_ascii=False,indent=2))
raise SystemExit(1 if errors else 0)
