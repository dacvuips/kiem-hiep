import os
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

skills_txt_path = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt"
res = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", skills_txt_path], capture_output=True)
lines = res.stdout.decode("utf-8", "replace").splitlines()

header = lines[0].split("\t")

# Map of skill ID -> details
all_tw_skills = {}
for line in lines[1:]:
    if not line.strip():
        continue
    cols = line.split("\t")
    if len(cols) > 71:
        sid_str = cols[2].strip()
        if not sid_str.isdigit():
            continue
        sid = int(sid_str)
        sname = cols[0].strip()
        script = cols[71].strip()
        desc = cols[113].strip() if len(cols) > 113 else ""
        icon = cols[5].strip() if len(cols) > 5 else ""
        lr = cols[12].strip() if len(cols) > 12 else ""
        child_id = cols[20].strip() if len(cols) > 20 else ""
        child_num = cols[22].strip() if len(cols) > 22 else ""
        is_exp = cols[68].strip() if len(cols) > 68 else ""
        req_level = cols[70].strip() if len(cols) > 70 else ""
        max_level = cols[111].strip() if len(cols) > 111 else ""
        fly_id = cols[47].strip() if len(cols) > 47 else ""
        coll_id = cols[50].strip() if len(cols) > 50 else ""
        van_id = cols[52].strip() if len(cols) > 52 else ""

        if "tianwang" in script.lower() or "tianwang" in sname.lower() or "thiên vương" in sname.lower() or "thiên vương" in desc.lower():
            all_tw_skills[sid] = {
                "id": sid,
                "name": sname,
                "script": script,
                "icon": icon,
                "lr": lr,
                "req_level": req_level,
                "max_level": max_level,
                "child_id": child_id,
                "child_num": child_num,
                "fly_id": fly_id,
                "coll_id": coll_id,
                "van_id": van_id,
                "is_exp": is_exp,
                "desc": desc
            }

print(f"Tìm thấy {len(all_tw_skills)} skill liên quan tới Tianwang trong Skills.txt:")
for sid, info in sorted(all_tw_skills.items()):
    print(f"ID {sid:4d}: {info['name']:30s} | Req: {info['req_level']:3s} | Max: {info['max_level']:3s} | Script: {info['script']} | Child: {info['child_id']} (x{info['child_num']}) | Fly: {info['fly_id']} | Coll: {info['coll_id']}")
