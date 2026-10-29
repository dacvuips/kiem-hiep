import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

p = Path("assets/skill_fx/tien_giai_tho.png")
print("tien_giai_tho.png exists:", p.exists(), "size:", p.stat().st_size if p.exists() else 0)

with open("data/skill_fx/missiles.json", "r", encoding="utf-8") as f:
    msls = json.load(f)

with open("data/skill_fx/anims.json", "r", encoding="utf-8") as f:
    anims = json.load(f)

for mid in ["14", "15", "16", "17", "18", "19", "20", "21", "22", "178", "181", "342", "372"]:
    m = msls.get(mid)
    if m:
        fly = m.get("fly_anim")
        hit = m.get("hit_anim")
        vanish = m.get("vanish_anim")
        
        fly_png = Path(f"assets/skill_fx/{fly}.png").exists() if fly else False
        hit_png = Path(f"assets/skill_fx/{hit}.png").exists() if hit else False
        
        print(f"Msl {mid:>4s}: name={m.get('name')} | fly={fly} (exists={fly_png}) | hit={hit} (exists={hit_png}) | vanish={vanish}")
    else:
        print(f"Msl {mid:>4s}: NOT FOUND")
