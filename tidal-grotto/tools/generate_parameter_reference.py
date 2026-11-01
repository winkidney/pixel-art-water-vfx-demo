"""Render the UI/preset schema as a readable parameter reference."""
from pathlib import Path
import json
root = Path(__file__).resolve().parents[1]
schema = json.loads((root / 'assets/water-parameters.json').read_text())
lines = ['# 运行中可调参数', '', f"共 {len(schema['parameters'])} 项。此表由实际面板和预设共用的定义生成。", '', '范围适用于滑杆、数值输入和预设文件。相对调色以各时段基准色为基础，默认色相 0 度、饱和度及亮度各 1 倍。', '']
for group in dict.fromkeys(item['group'] for item in schema['parameters']):
    entries = [item for item in schema['parameters'] if item['group'] == group]
    lines += ['## ' + entries[0]['group_label'], '', '| 参数 | 默认 | 范围 | 单位 | 层级 |', '| --- | --- | --- | --- | --- |']
    for item in entries:
        boolean = item.get('type') == 'bool'
        default = '开' if boolean else f"{item['default']:g}"
        interval = '开 / 关' if boolean else f"{item['min']:g} 至 {item['max']:g}"
        lines.append(f"| {item['label']} | {default} | {interval} | {item.get('unit', '')} | {'常用' if item['common'] else '高级'} |")
    lines.append('')
(root / 'docs/parameter-reference.md').write_text('\n'.join(lines).rstrip() + '\n')
print(f"Generated reference for {len(schema['parameters'])} parameters")
