import sys
import re
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tools")
import mark_player_skills as mps

ROOT = Path(__file__).resolve().parent.parent

print("=== CHECK BÍ KÍP 180 IN MISC_ITEMS.JSON ===")
with open(ROOT / "data" / "items" / "misc_items.json", "r", encoding="utf-8") as f:
    items = json.load(f)
for it in items:
    if "180" in it.get("name", ""):
        print(f"Item ID: {it.get('id'):20s} | Name: {it.get('name'):35s} | Desc: {it.get('description')}")

print("\n=== CHECK SECT FILES FOR 180 SKILLS ===")
sect_dir = ROOT / "systems" / "sect" / "data"
for sf in sect_dir.glob("*.tres"):
    txt = sf.read_text(encoding="utf-8")
    m = re.findall(r'skill_name = "([^"]+)"[\s\S]*?req_level = 180', txt)
    if not m:
        # check if req_level = 180 anywhere
        m2 = re.findall(r'req_level = 180[\s\S]*?skill_name = "([^"]+)"', txt)
        if m2: m = m2
    print(f"Sect {sf.name:20s}: {m if m else 'No 180 skill'}")
