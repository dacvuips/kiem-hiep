import os
import sys
import subprocess
import re
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

p_emei = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/emei.lua"
res = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_emei], capture_output=True)
text = res.stdout.decode("utf-8", "replace")

# Tìm tất cả skill blocks
# pattern: name={ ... }
matches = re.findall(r'\n\t([a-zA-Z0-9_]+)\s*=\s*\{(?:\s*--([^\n]+))?', text)
print(f"Tổng số skill blocks trong emei.lua: {len(matches)}")
for m in matches:
    print(f"  * {m[0]:<25} | Ghi chú: {m[1]}")
