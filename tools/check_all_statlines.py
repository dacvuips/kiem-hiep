import re, sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
txt = Path("systems/sect/data/vo_dang.tres").read_text(encoding="utf-8")

for m in re.finditer(r'\[sub_resource type="Resource" id="(SubResource_\d+)"\]\nscript = ExtResource\("3_statline"\)\nlabel = "([^"]+)"[\s\S]*?(?=suffix|\Z)', txt):
    sub_id = m.group(1)
    lbl = m.group(2)
    body = m.group(0)
    tgt_m = re.search(r'target_skill_id = "([^"]*)"', body)
    tgt = tgt_m.group(1) if tgt_m else ""
    v1_m = re.search(r'value_at_level_1 = ([\d\.\-]+)', body)
    v1 = v1_m.group(1) if v1_m else ""
    vmax_m = re.search(r'value_at_max_level = ([\d\.\-]+)', body)
    vmax = vmax_m.group(1) if vmax_m else ""
    if tgt or "liên kết" in lbl or "sát thương" in lbl.lower():
        print(f"{sub_id:18s} | {lbl:35s} | target: '{tgt}' | v1: {v1} -> vmax: {vmax}")
