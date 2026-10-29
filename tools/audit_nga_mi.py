import os
import sys
import re
import json
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

ROOT = Path(__file__).resolve().parent.parent

# 1. Tra cứu factionhead.lua
p_faction = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/header/factionhead.lua"
res = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_faction], capture_output=True)
faction_text = res.stdout.decode("utf-8", "replace")

# 2. Tra cứu Skills.txt
p_skills = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt"
res2 = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_skills], capture_output=True)
skills_text = res2.stdout.decode("utf-8", "replace")
skills_lines = skills_text.split("\n")
skill_headers = [h.strip() for h in skills_lines[0].split("\t")]
skill_col_map = {h: i for i, h in enumerate(skill_headers)}

skills_by_id = {}
for line in skills_lines[1:]:
    cols = line.split("\t")
    if len(cols) > 2 and cols[2].strip().isdigit():
        sid = int(cols[2].strip())
        skills_by_id[sid] = {h: cols[skill_col_map[h]].strip() if skill_col_map[h] < len(cols) else "" for h in skill_headers}

# Tìm phần định nghĩa Emei trong factionhead.lua
print("================================================================================")
print("=== FACTIONHEAD.LUA (CÁC BẢNG LIÊN QUAN ĐẾN NGA MI) ===")
print("================================================================================")
for line in faction_text.split("\n"):
    if "EMEI" in line or "emei" in line.lower() or "nga_mi" in line.lower():
        print(line)

# Tra cứu nga_mi.tres hiện tại
tres_path = ROOT / "systems" / "sect" / "data" / "nga_mi.tres"
tres_content = tres_path.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

sect_skills = []
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        sid_m = re.search(r'id = "([^"]+)"', body)
        name_m = re.search(r'skill_name = "([^"]+)"', body)
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

        sect_skills.append({
            "id": sid_m.group(1) if sid_m else sub_id,
            "name": name_m.group(1) if name_m else "",
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
            "lines": lines,
            "body": body
        })

print("\n================================================================================")
print(f"=== DANH SÁCH SKILL HIỆN CÓ TRONG nga_mi.tres ({len(sect_skills)} skills) ===")
print("================================================================================")
for i, s in enumerate(sorted(sect_skills, key=lambda x: (x["req_level"], x["vltk_id"]))):
    cat_name = "PASSIVE" if s["category"] == 1 else ("AURA" if s["is_aura"] else "ACTIVE")
    hide_flag = "[HIDDEN] " if s["is_hidden"] else ""
    print(f"{i+1:2d}. {hide_flag}[{s['id']:30s}] | Name: {s['name']:25s} | VLTK ID: {s['vltk_id']:4d} | Req: {s['req_level']:3d} | Cat: {cat_name:7s} | Nhánh: {s['school']} | Wp: {s['weapon_limit']:2d} | Lines: {s['num_lines']}")
