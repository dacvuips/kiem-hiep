import sys
import os
import re
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

# Parse huashan.lua
lua_path = r"E:\jx15_src\script\skill\huashan.lua"
lua_content = open(lua_path, "r", encoding="gbk", errors="ignore").read()

# Also let's check tools/vltk_source.py
sys.path.insert(0, str(Path(__file__).resolve().parent))
import vltk_source

# Read hoa_son.tres
ROOT = Path(__file__).resolve().parent.parent
tres_path = ROOT / "systems" / "sect" / "data" / "hoa_son.tres"
tres_content = tres_path.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

stat_lines_map = {}
for sid, body in subresources.items():
    if 'script = ExtResource("3_statline")' in body:
        lbl = re.search(r'label = "([^"]+)"', body)
        v1 = re.search(r'value_at_level_1 = ([\d\.\-]+)', body)
        vmax = re.search(r'value_at_max_level = ([\d\.\-]+)', body)
        min1 = re.search(r'min_at_level_1 = ([\d\.\-]+)', body)
        minmax = re.search(r'min_at_max_level = ([\d\.\-]+)', body)
        max1 = re.search(r'max_at_level_1 = ([\d\.\-]+)', body)
        maxmax = re.search(r'max_at_max_level = ([\d\.\-]+)', body)
        suffix = re.search(r'suffix = "([^"]*)"', body)
        target = re.search(r'target_skill_id = "([^"]+)"', body)
        stat_lines_map[sid] = {
            "label": lbl.group(1) if lbl else "",
            "v1": float(v1.group(1)) if v1 else None,
            "vmax": float(vmax.group(1)) if vmax else None,
            "min1": float(min1.group(1)) if min1 else None,
            "minmax": float(minmax.group(1)) if minmax else None,
            "max1": float(max1.group(1)) if max1 else None,
            "maxmax": float(maxmax.group(1)) if maxmax else None,
            "suffix": suffix.group(1) if suffix else "",
            "target": target.group(1) if target else ""
        }

tres_skills = {}
for sid, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        skill_id = re.search(r'id = "([^"]+)"', body)
        name = re.search(r'skill_name = "([^"]+)"', body)
        vltk_id = re.search(r'vltk_skill_id = (\d+)', body)
        req_lvl = re.search(r'req_level = (\d+)', body)
        max_lvl = re.search(r'max_level = (\d+)', body)
        school = re.search(r'school_text = "([^"]+)"', body)
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)
        
        tres_skills[int(vltk_id.group(1))] = {
            "id": skill_id.group(1),
            "name": name.group(1),
            "req_level": int(req_lvl.group(1)),
            "max_level": int(max_lvl.group(1)),
            "school": school.group(1) if school else "",
            "stats": [stat_lines_map.get(l, {}) for l in lines]
        }

print("==========================================================================")
print(f"TOTAL SKILLS IN HOA_SON.TRES: {len(tres_skills)}")
print("==========================================================================")

for vid, sk in sorted(tres_skills.items(), key=lambda x: (x[1]['school'], x[1]['req_level'])):
    print(f"\n[{sk['school']}] ID:{vid} {sk['name']} ({sk['id']}) - ReqLv:{sk['req_level']} MaxLv:{sk['max_level']}")
    for st in sk['stats']:
        val_str = ""
        if st.get('v1') is not None:
            val_str = f"{st['v1']} -> {st['vmax']}"
        elif st.get('min1') is not None:
            val_str = f"{st['min1']}~{st['max1']} -> {st['minmax']}~{st['maxmax']}"
        target_str = f" [Target: {st['target']}]" if st.get('target') else ""
        print(f"    - {st['label']}: {val_str}{st['suffix']}{target_str}")
