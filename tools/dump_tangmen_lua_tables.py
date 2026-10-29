import os
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

os.environ["PATH"] = r"C:\Program Files\Git\usr\bin;" + os.environ.get("PATH", "")

p_lua = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/tangmen.lua"
res = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_lua], capture_output=True)
lua_text = res.stdout.decode("utf-8", "replace")

# Print all tables in tangmen.lua with their full body
tables = re.findall(r'(\w+)\s*=\s*\{\s*--([^\n]*)\n(.*?)\n\t\},', lua_text, re.DOTALL)
print(f"Total tables: {len(tables)}")
for name, comment, body in tables:
    print("="*60)
    print(f"TABLE: {name} ({comment.strip()})")
    print("="*60)
    for line in body.splitlines():
        l = line.strip()
        if l and not l.startswith("--"):
            print("  ", l)
