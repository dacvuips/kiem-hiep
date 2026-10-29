import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims = json.load(f)

tw_missiles = [63, 138, 139, 140, 141, 159, 160, 219, 220, 221, 222, 224, 225, 284, 320, 326, 327, 348, 349, 350, 404, 405, 406, 407, 408]

print("=== KIỂM TRA THỰC TẾ ANIMS CỦA THIÊN VƯƠNG MISSILES TRONG missiles.json ===")
for mid in tw_missiles:
    m = missiles.get(str(mid))
    if not m:
        print(f"Missile {mid:4d}: KHÔNG CÓ TRONG missiles.json")
        continue
    
    anims_arr = m.get("anims", [])
    # 0: wait, 1: fly, 2: vanish, 3: collide/hit
    fly = anims_arr[1] if len(anims_arr) > 1 else None
    hit = anims_arr[3] if len(anims_arr) > 3 else None
    
    fly_key = fly.get("anim") if fly else "None"
    hit_key = hit.get("anim") if hit else "None"
    
    fly_disk = (ROOT / "assets" / "skill_fx" / f"{fly_key}.png").exists() if fly_key != "None" else True
    hit_disk = (ROOT / "assets" / "skill_fx" / f"{hit_key}.png").exists() if hit_key != "None" else True
    
    print(f"Missile {mid:4d} ({m.get('name', ''):25s}):")
    print(f"  Speed:{m.get('speed', 0):2d} | ColRange:{m.get('collide_range', 0):2d} | DmgRange:{m.get('dmg_range', 0):2d} | MoveKind:{m.get('move_kind', 0)}")
    print(f"  FlyAnim: {fly_key} (disk_png: {fly_disk}) | HitAnim: {hit_key} (disk_png: {hit_disk})")
