with open('export_presets.cfg', 'r', encoding='utf-8') as f:
    text = f.read()

import re
presets = re.findall(r'\[preset\.(\d+)\][^\[]+name="([^"]+)"', text)
for num, name in presets:
    print(f'Preset {num}: {name}')

idx = text.find('[preset.0]')
if idx != -1:
    print(text[idx:idx+800])
