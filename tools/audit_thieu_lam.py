import os
import re
import sys
import json
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

# 1. Parse thieu_lam.tres
tres_path = ROOT / "systems" / "sect" / "data" / "thieu_lam.tres"
tres_content = tres_path.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    sub_id, body = m.group(1), m.group(2)
    subresources[sub_id] = body

# Parse stat lines
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

# Parse skills
skills = []
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        skill_id = re.search(r'id = "([^"]+)"', body)
        name = re.search(r'skill_name = "([^"]+)"', body)
        vltk_id = re.search(r'vltk_skill_id = (\d+)', body)
        req_lvl = re.search(r'req_level = (\d+)', body)
        max_lvl = re.search(r'max_level = (\d+)', body)
        school = re.search(r'school_text = "([^"]+)"', body)
        is_hidden = re.search(r'is_hidden = (true|false)', body)
        is_aura = re.search(r'is_aura = (true|false)', body)
        category = re.search(r'category = (\d+)', body)
        wp_limit = re.search(r'weapon_limit = ([\d\-]+)', body)
        hs_limit = re.search(r'horse_limit = ([\d\-]+)', body)
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)

        skills.append({
            "sub_id": sub_id,
            "id": skill_id.group(1) if skill_id else "",
            "name": name.group(1) if name else "",
            "vltk_id": int(vltk_id.group(1)) if vltk_id else None,
            "req_level": int(req_lvl.group(1)) if req_lvl else 0,
            "max_level": int(max_lvl.group(1)) if max_lvl else 20,
            "school": school.group(1) if school else "",
            "is_hidden": is_hidden.group(1) == "true" if is_hidden else False,
            "is_aura": is_aura.group(1) == "true" if is_aura else False,
            "category": int(category.group(1)) if category else 0,
            "weapon_limit": int(wp_limit.group(1)) if wp_limit else -2,
            "horse_limit": int(hs_limit.group(1)) if hs_limit else 0,
            "lines": [stat_lines_map.get(l, {"label": "??", "raw": l}) for l in lines]
        })

print("================================================================================")
print(f"CHI TIẾT 21 SKILL THIẾU LÂM TRONG thieu_lam.tres")
print("================================================================================")

active_skills = [s for s in skills if not s["is_hidden"]]
for s in sorted(active_skills, key=lambda x: (x["req_level"], x["vltk_id"] or 0)):
    cat_str = "PASSIVE" if s["category"] == 1 else ("AURA" if s["is_aura"] else "ACTIVE")
    print(f"\n[Skill ID: {s['id']}] - Tên: {s['name']} (VLTK ID: {s['vltk_id']})")
    print(f"  Loại: {cat_str} | Cấp yêu cầu: {s['req_level']} | Cấp tối đa: {s['max_level']} | Nhánh: {s['school']} | Vũ khí: {s['weapon_limit']} | Ngựa: {s['horse_limit']}")
    print(f"  Các dòng chỉ số ({len(s['lines'])} dòng):")
    for l in s["lines"]:
        target_info = f" -> hỗ trợ cho [{l['target']}]" if l.get("target") else ""
        val_info = ""
        if l.get("v1") is not None:
            val_info = f"{l['v1']} ~ {l['vmax']}{l['suffix']}"
        elif l.get("min1") is not None:
            val_info = f"({l['min1']}~{l['max1']}) -> ({l['minmax']}~{l['maxmax']}){l['suffix']}"
        print(f"    - {l['label']}: {val_info}{target_info}")
