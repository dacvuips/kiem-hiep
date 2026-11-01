import sys
sys.stdout.reconfigure(encoding='utf-8')
with open('launcher/launcher.gd', 'r', encoding='utf-8') as f:
    text = f.read()

import re
for m in re.finditer(r'installed\.json', text):
    start = max(0, m.start() - 200)
    end = min(len(text), m.end() + 200)
    print(text[start:end])
    print('='*50)
