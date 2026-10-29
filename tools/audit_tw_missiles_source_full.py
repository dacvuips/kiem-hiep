import os
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

missles_txt_path = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Missles.txt"
res_m = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", missles_txt_path], capture_output=True)
missiles_lines = res_m.stdout.decode("utf-8", "replace").splitlines()
m_header = missiles_lines[0].split("\t")

# Map missile id -> info
source_missiles = {}
for line in missiles_lines[1:]:
    if not line.strip(): continue
    cols = line.split("\t")
    if cols[0].strip().isdigit():
        mid = int(cols[0].strip())
        source_missiles[mid] = {
            "id": mid,
            "name": cols[1].strip() if len(cols) > 1 else "",
            "coll_range": cols[6].strip() if len(cols) > 6 else "",
            "is_range_dmg": cols[7].strip() if len(cols) > 7 else "",
            "dmg_range": cols[8].strip() if len(cols) > 8 else "",
            "speed": cols[11].strip() if len(cols) > 11 else "",
            "fly_anim": cols[29].strip() if len(cols) > 29 else "",
            "hit_anim": cols[32].strip() if len(cols) > 32 else "",
            "vanish_anim": cols[35].strip() if len(cols) > 35 else "",
            "fly_snd": cols[31].strip() if len(cols) > 31 else "",
            "hit_snd": cols[34].strip() if len(cols) > 34 else "",
        }

tw_mids = [63, 138, 139, 140, 141, 159, 160, 219, 220, 221, 222, 224, 225, 284, 320, 326, 327, 348, 349, 350, 404, 405, 406, 407, 408, 1077, 1084, 1086, 1087, 1088, 1221, 1231]

print("=== TẤT CẢ MISSILE LIÊN QUAN TỚI THIÊN VƯƠNG BANG TRONG MISSLES.TXT GỐC ===")
for mid in tw_mids:
    if mid in source_missiles:
        m = source_missiles[mid]
        print(f"Missile ID {mid:4d}: {m['name']:25s} | CollRange:{m['coll_range']:3s} | DmgRange:{m['dmg_range']:3s} | Spd:{m['speed']:3s} | FlyAnim:{m['fly_anim']} | HitAnim:{m['hit_anim']} | HitSnd:{m['hit_snd']}")
    else:
        print(f"Missile ID {mid:4d}: KHÔNG TÌM THẤY TRONG MISSLES.TXT")
