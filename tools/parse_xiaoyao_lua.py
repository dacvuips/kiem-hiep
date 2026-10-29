import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

lua_path = Path(r"E:/jx15_src/script/skill/xiaoyao.lua")
raw = lua_path.read_bytes()
txt = raw.decode("latin-1")

print(f"File size: {len(txt)} chars")

# Find SKILLS={ ... }
m = re.search(r"SKILLS\s*=\s*\{", txt)
if not m:
    print("SKILLS table not found")
    sys.exit(1)

content = txt[m.end():]
# Let's find each skill block: name = { ... }
# We can find all keys at indentation
skill_blocks = re.findall(r"\n\t([a-zA-Z0-9_]+)\s*=\s*\{([\s\S]*?)\n\t\},?", content)
print(f"Found {len(skill_blocks)} skills in xiaoyao.lua:")
for sname, sbody in skill_blocks:
    # print summary of keys in sbody
    keys = re.findall(r"([a-zA-Z0-9_]+)\s*=", sbody)
    print(f"\n================ SKILL: {sname} ================")
    for line in sbody.strip().splitlines():
        line_clean = line.strip()
        if line_clean and not line_clean.startswith("--"):
            print("  ", line_clean)
