import json
import sys

sys.stdout.reconfigure(encoding="utf-8")

with open("data/monsters/monsters.json", "r", encoding="utf-8") as f:
    monsters = json.load(f)

boss_ids = [740, 566, 741, 742, 582, 743, 568, 567, 744, 583, 745, 563, 564, 565, 562, 746, 747, 513, 523, 511, 1038]

if isinstance(monsters, list):
    m_dict = {m.get("id"): m for m in monsters if isinstance(m, dict)}
elif isinstance(monsters, dict):
    raw = monsters.get("monsters", monsters)
    if isinstance(raw, list):
        m_dict = {m.get("id"): m for m in raw if isinstance(m, dict)}
    elif isinstance(raw, dict):
        m_dict = raw
    else:
        m_dict = {}

for bid in boss_ids:
    m = m_dict.get(bid) or m_dict.get(str(bid))
    if m:
        print(f"[OK] ID {bid:4d}: {m.get('name', 'N/A'):<22} | res: {m.get('res', 'N/A'):<10} | lv: {m.get('level', 0):<3} | series: {m.get('series', 0)}")
    else:
        print(f"[MISSING] ID {bid} not in monsters.json!")
