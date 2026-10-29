import sys
import re
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
lua_path = r"E:\jx15_src\script\skill\huashan.lua"
content = open(lua_path, "r", encoding="gbk", errors="ignore").read()

# Find start of SKILLS={
start_pos = content.find("SKILLS={")
if start_pos == -1:
    start_pos = content.find("SKILLS = {")

# Split by top-level keys in SKILLS
skills_code = content[start_pos:]

# Find all entries like \tkey_name={
entries = re.findall(r'\n\t([a-zA-Z0-9_]+)\s*=\s*\{', skills_code)
print(f"Total skills defined in SKILLS in huashan.lua: {len(entries)}")
print("Skill table names:", entries)

# Now for each entry, print its full content
for name in entries:
    pattern = rf'\n\t{name}\s*=\s*\{{(.*?)\n\t\}},'
    m = re.search(pattern, skills_code, re.DOTALL)
    if not m:
        # try without comma
        pattern = rf'\n\t{name}\s*=\s*\{{(.*?)\n\t\}}'
        m = re.search(pattern, skills_code, re.DOTALL)
    
    print(f"\n==================== SKILL: {name} ====================")
    if m:
        body = m.group(1)
        # print non-empty lines
        for l in body.splitlines():
            if l.strip() and not l.strip().startswith("--"):
                print("  ", l.strip())
    else:
        print("   (Could not parse body)")
