import sys
sys.stdout.reconfigure(encoding='utf-8')
with open('ui/login/Login.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

import re
pattern = re.compile(r'\[node name="([^"]+)" type="([^"]+)" parent="Stage"\]([^\[]+)')
for m in pattern.finditer(text):
    name, node_type, body = m.group(1), m.group(2), m.group(3)
    offsets = {}
    for line in body.splitlines():
        if line.strip().startswith('offset_'):
            offsets[line.split('=')[0].strip()] = line.split('=')[1].strip()
        if 'mouse_filter' in line or 'action_mode' in line or 'text' in line or 'focus_mode' in line:
            offsets[line.split('=')[0].strip()] = line.split('=')[1].strip()
    print(f'{name} ({node_type}): {offsets}')
