import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)

# Danh sách skill Côn Lôn (gồm cả skill cha và skill con)
con_lon_skills = [
    # Normal / Main
    167, 168, 169, 171, 172, 173, 174, 175, 176, 178, 179, 181, 182, 275, 392, 393, 90, 630,
    # 90
    372, 375, 394,
    # 120
    717,
    # 150
    1080, 1081,
    # 180
    1229,
    # Child / Event skills:
    14, 15, 16, 17, 18, 19, 20, 21, 22, # Sub skills / missiles mentioned in Skills.txt
    373, 374, # Sub skills of 372
    376, 377, # Sub skills of 375
    1108, 1109, # Sub skills of 150
    1239, # Sub skill of 180
]

print("=== KIỂM TRA FX DỮ LIỆU SKILLS.JSON VỚI TỪNG SKILL CÔN LÔN ===")
missing_skills = []
for vid in sorted(set(con_lon_skills)):
    s_vid = str(vid)
    data = skills_fx.get(s_vid)
    if not data:
        missing_skills.append(vid)
        print(f"VID {vid:4d}: [CHƯA CÓ TRONG skills.json]")
        continue
    
    # Check anims
    events = ["cast_anim", "flight_anim", "hit_anim", "vanish_anim", "aura_anim"]
    anim_statuses = []
    for evt in events:
        a_name = data.get(evt)
        if a_name:
            exists = a_name in anims_fx
            anim_statuses.append(f"{evt}={a_name} (exists={exists})")
            # If exists in anims_fx, check image file
            a_data = anims_fx.get(a_name, {})
            png_res = a_data.get("texture_path") or a_data.get("sprite_sheet") or a_data.get("path")
            if png_res:
                real_p = ROOT / png_res.replace("res://", "")
                if not real_p.exists():
                    anim_statuses.append(f"[ERR FILE NOT FOUND: {png_res}]")
    
    print(f"VID {vid:4d}: {data.get('name',''):22s} | Type: {data.get('type',''):10s} | FlySpd: {data.get('fly_speed', 0)} | Radius: {data.get('radius', 0)} | Traj: {data.get('trajectory', '')} | NumMsl: {data.get('missile_count', 1)}")
    if anim_statuses:
        print(f"        -> {', '.join(anim_statuses)}")

print(f"\nTổng missing skills: {len(missing_skills)}: {missing_skills}")
