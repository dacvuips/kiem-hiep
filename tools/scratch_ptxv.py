import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

tres = Path('systems/sect/data/nga_mi.tres').read_text(encoding='utf-8')
m = re.search(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(?:[^\n]+\n)*?id = "nga_mi_phieu_tuyet_xuyen_van".*?(?=\n\[sub_resource|\n\[resource|\Z)', tres, re.DOTALL)
if m:
    print(m.group(0))
    sub_lines = re.findall(r'SubResource\("([^"]+)"\)', m.group(0))
    for sl in sub_lines:
        sm = re.search(r'\[sub_resource type="Resource" id="' + sl + r'"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres, re.DOTALL)
        if sm:
            print(f"--- StatLine {sl} ---")
            print(sm.group(1))
