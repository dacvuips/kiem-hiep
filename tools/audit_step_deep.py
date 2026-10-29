import os
import sys
import json
import re
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

ROOT = Path(__file__).resolve().parent.parent

# 1. Đọc emei.lua để lấy toàn bộ thông số skill
p_emei = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/emei.lua"
res = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_emei], capture_output=True)
emei_lua = res.stdout.decode("utf-8", "replace")

# 2. Đọc Skills.txt
p_skills = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt"
res2 = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_skills], capture_output=True)
skills_text = res2.stdout.decode("utf-8", "replace")
skills_lines = skills_text.split("\n")
headers = [h.strip() for h in skills_lines[0].split("\t")]
col_map = {h: i for i, h in enumerate(headers)}

skills_by_id = {}
for line in skills_lines[1:]:
    cols = line.split("\t")
    if len(cols) > 2 and cols[2].strip().isdigit():
        sid = int(cols[2].strip())
        skills_by_id[sid] = {h: cols[col_map[h]].strip() if col_map[h] < len(cols) else "" for h in headers}

# 3. Đọc Missiles.txt
p_missiles = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Missiles.txt"
res3 = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_missiles], capture_output=True)
missiles_text = res3.stdout.decode("utf-8", "replace")
missiles_lines = missiles_text.split("\n")
m_headers = [h.strip() for h in missiles_lines[0].split("\t")]
m_col_map = {h: i for i, h in enumerate(m_headers)}

missiles_by_id = {}
for line in missiles_lines[1:]:
    cols = line.split("\t")
    if len(cols) > 2 and cols[2].strip().isdigit():
        mid = int(cols[2].strip())
        missiles_by_id[mid] = {h: cols[m_col_map[h]].strip() if m_col_map[h] < len(cols) else "" for h in m_headers}

# 4. Kiểm tra tài nguyên skill 180 Nga Mi
icon_180 = ROOT / "assets" / "skill_icons" / "vltk" / "nga_mi_ba_la_tam_kinh.png"
aura_180_png = ROOT / "assets" / "skill_fx" / "tien_giai_thuy.png"
aura_180_json = ROOT / "assets" / "skill_fx" / "tien_giai_thuy.json"

print("=== KIỂM TRA TÀI NGUYÊN SKILL 180 NGA MI ===")
print(f"Icon 180 exists: {icon_180.exists()} ({icon_180.stat().st_size if icon_180.exists() else 0} bytes)")
print(f"Aura Thủy PNG exists: {aura_180_png.exists()} ({aura_180_png.stat().st_size if aura_180_png.exists() else 0} bytes)")
print(f"Aura Thủy JSON exists: {aura_180_json.exists()} ({aura_180_json.stat().st_size if aura_180_json.exists() else 0} bytes)")

# 5. Phân tích nguyên nhân Băng Sát bị rỗng số trong nga_mi.tres
print("\n=== NGUYÊN NHÂN BĂNG SÁT BỊ RỖNG TRONG nga_mi.tres ===")
tres_path = ROOT / "systems" / "sect" / "data" / "nga_mi.tres"
tres_content = tres_path.read_text(encoding="utf-8")
for m in re.finditer(r'label = "Băng sát".*?value_at_level_1 = (.*?)\n.*?value_at_max_level = (.*?)\n', tres_content, re.DOTALL):
    print(f"Băng sát line found: v1='{m.group(1)}', vmax='{m.group(2)}'")

# 6. Kiểm tra cấu hình skill 180 trong nga_mi.tres
print("\n=== SKILL 180 TRONG nga_mi.tres ===")
m_180 = re.search(r'id = "nga_mi_ba_la_tam_kinh".*?(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL)
if m_180:
    print(m_180.group(0)[:500])
