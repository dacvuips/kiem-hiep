import sys
sys.stdout.reconfigure(encoding='utf-8')
with open('launcher/launcher.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, l in enumerate(lines):
    if 'load_resource_pack' in l or 'change_scene' in l or 'start_game' in l or '_boot' in l:
        print(f'{i+1}: {l.strip()[:100]}')
