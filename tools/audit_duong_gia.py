import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

# 1. Parse duong_gia.tres
tres_path = ROOT / "systems" / "sect" / "data" / "duong_gia.tres"
tres_content = tres_path.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

stat_lines_map = {}
for sub_id, body in subresources.items():
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
        
        stat_lines_map[sub_id] = {
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
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        skill_id = re.search(r'id = "([^"]+)"', body).group(1)
        name = re.search(r'skill_name = "([^"]+)"', body).group(1)
        vltk_id = re.search(r'vltk_skill_id = (\d+)', body)
        req_lvl = re.search(r'req_level = (\d+)', body)
        max_lvl = re.search(r'max_level = (\d+)', body)
        school = re.search(r'school_text = "([^"]+)"', body)
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)
        cat = re.search(r'category = (\d+)', body)
        tres_skills[int(vltk_id.group(1))] = {
            "id": skill_id,
            "name": name,
            "req_level": int(req_lvl.group(1)) if req_lvl else 0,
            "max_level": int(max_lvl.group(1)) if max_lvl else 20,
            "school": school.group(1) if school else "",
            "category": int(cat.group(1)) if cat else 0,
            "lines": [stat_lines_map.get(l, {}) for l in lines]
        }

# Read yangmen.lua
lua_path = Path("E:/jx15_src/script/skill/yangmen.lua")
text = lua_path.read_text(encoding="gbk", errors="replace")

# Print detailed comparison
print(f"Loaded {len(tres_skills)} skills from duong_gia.tres")
for vid, s in sorted(tres_skills.items(), key=lambda x: (x[1]["req_level"], x[0])):
    print(f"\n================================================================================")
    print(f"SKILL [{vid}] {s['name']} (ID: {s['id']}) - Cấp {s['req_level']} - {s['school']}")
    print(f"================================================================================")
    print("Các dòng trong duong_gia.tres:")
    for l in s["lines"]:
        val = ""
        if l.get("v1") is not None:
            val = f"{l['v1']} -> {l['vmax']}{l['suffix']}"
        elif l.get("min1") is not None:
            val = f"({l['min1']}~{l['max1']}) -> ({l['minmax']}~{l['maxmax']}){l['suffix']}"
        tgt = f" [TARGET: {l['target']}]" if l.get("target") else (" [TARGET: MISSING!]" if "liên kết" in l.get("label", "").lower() else "")
        print(f"  * {l.get('label')}: {val}{tgt}")
