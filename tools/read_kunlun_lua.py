import os
import re
import sys
import subprocess
from pathlib import Path

if sys.platform == "win32":
    git_usr_bin = r"C:\Program Files\Git\usr\bin"
    if os.path.exists(git_usr_bin) and git_usr_bin not in os.environ.get("PATH", ""):
        os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

sys.stdout.reconfigure(encoding="utf-8")

def iconv(path: Path) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace")

SKILL_DIR = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill")

for f in ["kunlun.lua", "tuytien_tacot.lua"]:
    p = SKILL_DIR / f
    if p.exists():
        print(f"=== {f} ===")
        text = iconv(p)
        print(text[:3000])
        print("..." if len(text) > 3000 else "")
