import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "data" / "items" / "misc_items.json", "r", encoding="utf-8") as f:
    items = json.load(f)

con_lon_bks = [i for i in items if "côn lôn" in i.get("name", "").lower() or "con_lon" in i.get("id", "").lower()]
print(f"Tìm thấy {len(con_lon_bks)} vật phẩm liên quan Côn Lôn trong misc_items.json:")
for bk in con_lon_bks:
    print(f"  ID: {bk.get('id')} | Name: {bk.get('name')} | Desc: {bk.get('description')} | Icon: {bk.get('icon')}")
