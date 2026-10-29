import json
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

# 1. Load duong_mon.tres
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

# 2. Load skills_fx (data/skill_fx/skills.json)
with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

# Check all synergies
print("\n" + "="*80)
print("CHI TIẾT MẠNG LƯỚI TƯƠNG HỖ (SYNERGY) CỦA ĐƯỜNG MÔN:")
print("="*80)
for sid, s in sorted(tres_skills.items(), key=lambda x: (x[1]["req_level"], x[1]["vltk_id"] or 0)):
    synergies = [l for l in s["lines"] if l.get("target")]
    if synergies:
        print(f"\n{s['name']} (ID: {s['id']}) hỗ trợ:")
        for syn in synergies:
            tgt = syn["target"]
            tgt_name = tres_skills[tgt]["name"] if tgt in tres_skills else "KHÔNG TỒN TẠI!"
            status = "HỢP LỆ" if tgt in tres_skills else "LỖI HỎNG!"
            print(f"  -> [{tgt}] ({tgt_name}): {syn['v1']}% ~ {syn['vmax']}% | {status}")

# Check all skills
all_valid_ids = set(tres_skills.keys())

for s in sorted(tres_skills.values(), key=lambda x: (x["req_level"], x["vltk_id"] or 0)):
    vid_str = str(s["vltk_id"]) if s["vltk_id"] else "NONE"
    fx_entry = skills_fx.get(vid_str, {})
    has_fx = vid_str in skills_fx
    
    # Check FX chain
    child_id = fx_entry.get("child", 0)
    fly_skill = fx_entry.get("fly_skill", 0)
    collide_skill = fx_entry.get("collide_skill", 0)
    vanish_skill = fx_entry.get("vanish_skill", 0)
    precast_anim = fx_entry.get("precast", "")
    form = fx_entry.get("form", 0)
    attack_radius = fx_entry.get("attack_radius", 0)
    
    # Check synergy targets
    invalid_synergies = []
    for l in s["lines"]:
        tgt = l.get("target")
        if tgt and tgt not in all_valid_ids:
            invalid_synergies.append((l.get("label"), tgt))
            
    print(f"\n[Skill: {s['id']}] - {s['name']} (Lv {s['req_level']}) | VLTK ID: {vid_str} | Hidden: {s['is_hidden']}")
    print(f"  FX Data: {'Có trong skills.json' if has_fx else 'THIẾU TRONG skills.json!'}")
    if has_fx:
        print(f"    Form={form}, Radius={attack_radius}, Precast={precast_anim}, Child={child_id}, Fly={fly_skill}, Collide={collide_skill}, Vanish={vanish_skill}")
    if invalid_synergies:
        print(f"    CẢNH BÁO: Target synergy không tồn tại:")
        for lbl, tgt in invalid_synergies:
            print(f"      * {lbl} -> {tgt} (KHÔNG TỒN TẠI TRONG TRES!)")
