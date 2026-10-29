import os
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

ROOT = Path(__file__).resolve().parent.parent

# Read duong_mon.tres
tres_path = ROOT / "systems" / "sect" / "data" / "duong_mon.tres"
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
        skill_id = re.search(r'id = "([^"]+)"', body)
        name = re.search(r'skill_name = "([^"]+)"', body)
        vltk_id = re.search(r'vltk_skill_id = (\d+)', body)
        req_lvl = re.search(r'req_level = (\d+)', body)
        max_lvl = re.search(r'max_level = (\d+)', body)
        school = re.search(r'school_text = "([^"]+)"', body)
        is_hidden = re.search(r'is_hidden = (true|false)', body)
        is_aura = re.search(r'is_aura = (true|false)', body)
        category = re.search(r'category = (\d+)', body)
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)
        sid = skill_id.group(1) if skill_id else ""
        tres_skills[sid] = {
            "id": sid,
            "name": name.group(1) if name else "",
            "vltk_id": int(vltk_id.group(1)) if vltk_id else None,
            "req_level": int(req_lvl.group(1)) if req_lvl else 0,
            "max_level": int(max_lvl.group(1)) if max_lvl else 20,
            "school": school.group(1) if school else "",
            "is_hidden": is_hidden.group(1) == "true" if is_hidden else False,
            "is_aura": is_aura.group(1) == "true" if is_aura else False,
            "category": int(category.group(1)) if category else 0,
            "lines": [stat_lines_map.get(l, {}) for l in lines]
        }

# Read tangmen.lua
p_lua = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/tangmen.lua"
res = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_lua], capture_output=True)
lua_text = res.stdout.decode("utf-8", "replace") if res.returncode == 0 else ""

print("="*80)
print("SO SÁNH TỪNG KỸ NĂNG ĐƯỜNG MÔN VỚI SOURCE GỐC LUA:")
print("="*80)

for sid, s in sorted(tres_skills.items(), key=lambda x: (x[1]["req_level"], x[1]["vltk_id"] or 0)):
    print(f"\n--- [{s['req_level']}] {s['name']} (ID: {s['id']}, VLTK: {s['vltk_id']}) ---")
    for l in s["lines"]:
        target_info = f" -> [{l['target']}]" if l.get("target") else ""
        val_info = ""
        if l.get("v1") is not None:
            val_info = f"{l['v1']} ~ {l['vmax']}{l['suffix']}"
        elif l.get("min1") is not None:
            val_info = f"({l['min1']}~{l['max1']}) -> ({l['minmax']}~{l['maxmax']}){l['suffix']}"
        print(f"    * {l['label']}: {val_info}{target_info}")
