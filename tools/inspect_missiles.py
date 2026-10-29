import json
import sys
import os
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = r"C:\Program Files\Git\usr\bin;" + os.environ.get("PATH", "")

ROOT = Path(".")
SRC_BASE = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server")
ICONV_EXE = r"C:\Program Files\Git\usr\bin\iconv.exe"

def iconv(path: Path) -> str:
    res = subprocess.run([ICONV_EXE, "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                         capture_output=True, check=True)
    return res.stdout.decode("utf-8", "replace")

# Missles.txt in source
missles_txt_lines = iconv(SRC_BASE / "settings" / "Missles.txt").splitlines()
ms_header = [h.strip() for h in missles_txt_lines[0].split("\t")]
ms_col = {h: i for i, h in enumerate(ms_header)}
missles_txt_map = {}
for line in missles_txt_lines[1:]:
    p = line.split("\t")
    if len(p) > ms_col["MissleId"] and p[ms_col["MissleId"]].strip().isdigit():
        mid = int(p[ms_col["MissleId"]].strip())
        missles_txt_map[mid] = {h: p[ms_col[h]].strip() if len(p) > ms_col[h] else "" for h in ms_header if h in ms_col}

with open(ROOT / "data/skill_fx/missiles.json", "r", encoding="utf-8") as f:
    missiles = json.load(f)
with open(ROOT / "data/skill_fx/anims.json", "r", encoding="utf-8") as f:
    anims = json.load(f)

print("=== SO SÁNH MISSILES TRONG SOURCE GỐC VS MISSILES.JSON ===")
mids = [24, 25, 26, 27, 28, 29, 92, 95, 110, 173, 174, 175, 176, 182, 211, 274, 340, 341, 367, 369, 1238]
for mid in mids:
    m_json = missiles.get(str(mid), {})
    m_src = missles_txt_map.get(mid, {})
    
    src_name = m_src.get("MissleName", "Unknown")
    src_fly = m_src.get("AnimFile2", "")
    src_hit = m_src.get("AnimFile4", "")
    src_speed = m_src.get("Speed", "")
    src_life = m_src.get("LifeTime", "")
    src_range = m_src.get("DmgRange", "")
    
    j_fly = m_json.get("fly", "")
    j_hit = m_json.get("hit", "")
    j_speed = m_json.get("speed", 0)
    j_range = m_json.get("range", 0)
    
    fly_in_anims = j_fly in anims if j_fly else False
    hit_in_anims = j_hit in anims if j_hit else False
    
    print(f"\nMissile #{mid:4d} [{src_name}]:")
    print(f"  SOURCE : Speed={src_speed}, Range={src_range}, Life={src_life}")
    print(f"           Fly={src_fly} | Hit={src_hit}")
    print(f"  JSON   : Speed={j_speed}, Range={j_range}")
    print(f"           Fly={j_fly} (Exists in anims.json: {fly_in_anims}) | Hit={j_hit} (Exists in anims.json: {hit_in_anims})")
