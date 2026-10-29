import os
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
tres_path = ROOT / "systems" / "sect" / "data" / "tieu_dao.tres"
tres_content = tres_path.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

print(f"Total subresources in tieu_dao.tres: {len(subresources)}")

skills = []
stat_lines = {}
for sub_id, body in subresources.items():
    if 'script = ExtResource("3_statline")' in body:
        stat_lines[sub_id] = body
    elif 'script = ExtResource("2_skill")' in body:
        sid = re.search(r'id = "([^"]+)"', body)
        name = re.search(r'skill_name = "([^"]+)"', body)
        v_id = re.search(r'vltk_skill_id = (\d+)', body)
        req = re.search(r'req_level = (\d+)', body)
        max_l = re.search(r'max_level = (\d+)', body)
        school = re.search(r'school_text = "([^"]+)"', body)
        cat = re.search(r'category = (\d+)', body)
        wp = re.search(r'weapon_limit = ([\d\-]+)', body)
        hs = re.search(r'horse_limit = ([\d\-]+)', body)
        aura = re.search(r'is_aura = (true|false)', body)
        hidden = re.search(r'is_hidden = (true|false)', body)
        icon = re.search(r'icon_texture = ExtResource\("([^"]+)"\)', body)
        desc = re.search(r'description = "([^"]+)"', body)
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)
        skills.append({
            "sub_id": sub_id,
            "id": sid.group(1) if sid else "",
            "name": name.group(1) if name else "",
            "vltk_id": int(v_id.group(1)) if v_id else 0,
            "req_level": int(req.group(1)) if req else 0,
            "max_level": int(max_l.group(1)) if max_l else 20,
            "school": school.group(1) if school else "",
            "category": int(cat.group(1)) if cat else 0,
            "weapon_limit": int(wp.group(1)) if wp else -2,
            "horse_limit": int(hs.group(1)) if hs else 0,
            "is_aura": aura.group(1) == "true" if aura else False,
            "is_hidden": hidden.group(1) == "true" if hidden else False,
            "icon": icon.group(1) if icon else "",
            "desc": desc.group(1) if desc else "",
            "num_lines": len(lines),
            "lines": lines
        })

print(f"Total skills parsed: {len(skills)}")
skills.sort(key=lambda s: (s["school"], s["req_level"], s["vltk_id"]))
for i, s in enumerate(skills, 1):
    cat_str = "Bị động" if s["category"] == 1 else ("Hào quang" if s["is_aura"] else "Chủ động")
    hid = " [HIDDEN]" if s["is_hidden"] else ""
    print(f"{i:2d}. [{s['school']:8s}] Lv{s['req_level']:3d} | {s['name']:25s} (id: {s['id']:25s}, vltk_id: {s['vltk_id']:4d}) | {cat_str:9s} | max={s['max_level']} wp={s['weapon_limit']}{hid}")
