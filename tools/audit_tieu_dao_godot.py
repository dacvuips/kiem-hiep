import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    msls = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims = json.load(f)

print(f"Total missiles in missiles.json: {len(msls)}")

test_ids = [
    "536", "537", "538", "539", "540", "541", "543", "544", "545", "546", "547", "548",
    "100536", "100537", "100538", "100539", "100540", "100541", "100543", "100544", "100545", "100546", "100547", "100548"
]

for mid in test_ids:
    if mid in msls:
        m = msls[mid]
        fly_a = m.get('fly_anim', '')
        col_a = m.get('col_anim', '')
        van_a = m.get('van_anim', '')
        print(f"Missile {mid:8s}: kind={m.get('move_kind')} | spd={m.get('speed')} | dmg_rad={m.get('dmg_range')} | col_rad={m.get('col_range')} | fly={fly_a} ({fly_a in anims}) | col={col_a} ({col_a in anims}) | van={van_a} ({van_a in anims})")
    else:
        print(f"Missile {mid:8s}: NOT FOUND in missiles.json")
