import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
skills_json_path = ROOT / "data" / "skill_fx" / "skills.json"
anims_json_path = ROOT / "data" / "skill_fx" / "anims.json"

with open(skills_json_path, "r", encoding="utf-8") as f:
    skills_fx = json.load(f)

with open(anims_json_path, "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

thuy_yen_vids = [86, 95, 96, 97, 99, 100, 102, 105, 108, 109, 111, 113, 114, 269, 336, 337, 713, 1063, 1064, 1225]
# Also child skills:
child_vids = [6, 7, 8, 9, 10, 12, 111, 146, 147, 326, 338, 354, 382, 1235]

print("=== CHECK SKILL_FX DATA IN skills.json ===")
for vid in sorted(thuy_yen_vids + child_vids):
    s_vid = str(vid)
    data = skills_fx.get(s_vid)
    if data:
        # Check anims referenced
        anims = []
        for evt in ["cast_anim", "flight_anim", "hit_anim", "vanish_anim", "aura_anim"]:
            if data.get(evt):
                a_name = data.get(evt)
                exists = a_name in anims_fx
                anims.append(f"{evt}={a_name} (exists={exists})")
        print(f"ID {vid:4d}: {data.get('name','')} | fly_speed={data.get('fly_speed')} | radius={data.get('radius')} | is_aura={data.get('is_aura')} | {', '.join(anims)}")
    else:
        print(f"ID {vid:4d}: NOT FOUND in skills.json!")
