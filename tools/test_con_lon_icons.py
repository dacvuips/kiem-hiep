import sys
import re
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

tres = Path("systems/sect/data/con_lon.tres").read_text(encoding="utf-8")
icons = re.findall(r'path="res://(assets/skill_icons/vltk/[^"]+)"', tres)
print(f"Total icon paths in con_lon.tres: {len(icons)}")
all_ok = True
for ic in icons:
    p = Path(ic)
    sz = p.stat().st_size if p.exists() else 0
    ok = p.exists() and sz > 0
    if not ok:
        all_ok = False
    print(f"  {p.name:38s}: exists={p.exists()} ({sz} bytes)")
print("ALL ICONS OK!" if all_ok else "SOME ICONS MISSING!")
