import sys
sys.stdout.reconfigure(encoding='utf-8')
with open('launcher/launcher.gd', 'r', encoding='utf-8') as f:
    text = f.read()

import re
idx = text.find('BOOT_MARKER')
while idx != -1:
    print(text[idx-50:idx+400])
    print('='*50)
    idx = text.find('BOOT_MARKER', idx + 1)
