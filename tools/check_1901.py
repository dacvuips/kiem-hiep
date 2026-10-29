import sys
import re
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

lua_path = Path(r"E:/jx15_src/script/skill/xiaoyao.lua")
txt = lua_path.read_bytes().decode("latin-1")

# Find shencang or 1901
for line in txt.splitlines():
    if any(k in line.lower() for k in ['1901', '1902', '1903', 'shencang', 'cang', 'maidanh', 'mai']):
        print(line)
