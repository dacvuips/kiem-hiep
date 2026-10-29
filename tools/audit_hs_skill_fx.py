import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_json = json.load(f)

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles_json = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_json = json.load(f)

hs_skill_ids = [1347, 1349, 1350, 1351, 1354, 1355, 1358, 1360, 1363, 1364, 1365, 1368, 1369, 1372, 1374, 1375, 1376, 1378, 1379, 1380, 1381, 1382, 1384]

print(f"{'SkillId':<8} {'Name':<30} {'InSkillsJSON':<15} {'CharAnim':<10} {'Child':<10} {'Start':<10} {'Radius':<10}")
print("=" * 95)

for sid in hs_skill_ids:
    s_sid = str(sid)
    sk = skills_json.get(s_sid)
    if sk:
        print(f"{sid:<8} {sk.get('name',''):<30} {'FOUND':<15} {sk.get('char_anim',0):<10} {sk.get('child',0):<10} {sk.get('start_skill',0):<10} {sk.get('attack_radius',0):<10}")
    else:
        print(f"{sid:<8} {'???':<30} {'NOT FOUND':<15}")
