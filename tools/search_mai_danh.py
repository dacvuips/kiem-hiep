import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tools")
import mark_player_skills as mps

files = [
    r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt",
    r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK/settings/skills.txt",
    r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK/settings/skills1.txt",
    r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK/settings/skills2.txt",
    r"E:/jx15_src/settings/Skills.txt",
    r"D:/game/source_vo-lam-truyen-ky/VS2022/Server+Client-001/bin/Server/Server/settings/Skills.txt"
]

print("=== SEARCHING SKILLS.TXT FILES ===")
for fp in files:
    p = Path(fp)
    if not p.exists(): continue
    try:
        txt = mps.iconv(p)
    except Exception:
        try:
            txt = p.read_text(encoding="gbk", errors="replace")
        except Exception:
            txt = p.read_text(encoding="utf-8", errors="replace")
    
    lines = txt.splitlines()
    for line in lines[1:]:
        c = line.split("\t")
        if len(c) > 0:
            name = c[0]
            for kw in ["mai danh", "ẩn tính", "ẩn tích", "thâm tàng", "thân danh", "mai", "tàng"]:
                if kw in name.lower():
                    sid = c[2] if len(c) > 2 else "?"
                    icon = c[5] if len(c) > 5 else ""
                    print(f"File {p.name}: ID {sid} - \"{name}\" | Icon: {icon}")
