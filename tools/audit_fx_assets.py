import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

tm_skill_ids = [
    "43", "45", "347", "303", "47", "50", "54", "343", "345", "349",
    "48", "58", "249", "341", "302", "339", "342", "351", "710",
    "1069", "1070", "1071", "1110", "1223"
]

print("="*80)
print("AUDIT HIỆU ỨNG SKILL (FX, ĐẠN BAY, VA CHẠM, BIẾN MẤT) CHO ĐƯỜNG MÔN:")
print("="*80)

def check_anim(anim_name):
    if not anim_name:
        return "None"
    if anim_name not in anims_fx:
        return f"MISSING in anims.json ({anim_name})"
    
    # check png on disk
    # typically in assets/skill_fx/<anim_name>.png or art/skill_fx/<anim_name>.png
    p1 = ROOT / "assets" / "skill_fx" / f"{anim_name}.png"
    p2 = ROOT / "art" / "skill_fx" / f"{anim_name}.png"
    p3 = ROOT / "assets" / "skill_fx" / f"{anim_name}.json"
    exists = p1.exists() or p2.exists()
    return f"OK ({anim_name})" if exists else f"NO PNG on disk ({anim_name})"

def check_missile(msl_id):
    mid_str = str(msl_id)
    if mid_str == "0":
        return "None"
    if mid_str not in missiles_fx:
        return f"MISSING in missiles.json ({mid_str})"
    m = missiles_fx[mid_str]
    anims_arr = m.get("anims", [])
    anims_desc = []
    labels = ["Wait", "Fly", "Collide", "Vanish"]
    for i, a in enumerate(anims_arr):
        if a and isinstance(a, dict) and a.get("anim"):
            an = a["anim"]
            st = check_anim(an)
            anims_desc.append(f"{labels[i]}={st}")
    
    anims_str = ", ".join(anims_desc) if anims_desc else "NO ANIM"
    radius = m.get("collide_range", 0)
    life = m.get("life", 0)
    speed = m.get("speed", 0)
    mname = m.get("name", "")
    return f"Missile {mid_str} ({mname}): [{anims_str}], r={radius}, spd={speed}, life={life}"

for sid in tm_skill_ids:
    if sid not in skills_fx:
        print(f"\n[SKILL {sid}] THIẾU HOÀN TOÀN TRONG skills.json!")
        continue
    s = skills_fx[sid]
    name = s.get("name", "")
    form = s.get("form", 0)
    radius = s.get("attack_radius", 0)
    precast = s.get("precast", "")
    pre_status = check_anim(precast) if precast else "None"
    
    child = s.get("child", 0)
    fly = s.get("fly_skill", 0)
    col = s.get("collide_skill", 0)
    van = s.get("vanish_skill", 0)
    
    print(f"\n[Skill {sid:<4}] {name:<26} | Form: {form:>2} | Range: {radius:>3} | Precast: {pre_status}")
    if child:
        print(f"   -> Child (Đạn bay chính):  {check_missile(child)}")
    if fly:
        print(f"   -> Fly (Đạn vệt/phụ bay):  {check_missile(fly)}")
    if col:
        print(f"   -> Collide (Đạn nổ/chạm):  {check_missile(col)}")
    if van:
        print(f"   -> Vanish (Đạn biến mất):  {check_missile(van)}")
