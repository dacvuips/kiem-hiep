import os
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

ROOT = Path(__file__).resolve().parent.parent

# Read thien_vuong_bang.tres
tres_path = ROOT / "systems" / "sect" / "data" / "thien_vuong_bang.tres"
tres_content = tres_path.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

stat_lines_map = {}
for sub_id, body in subresources.items():
    if 'script = ExtResource("3_statline")' in body:
        lbl = re.search(r'label = "([^"]+)"', body)
        v1 = re.search(r'value_at_level_1 = ([\d\.\-]+)', body)
        vmax = re.search(r'value_at_max_level = ([\d\.\-]+)', body)
        target = re.search(r'target_skill_id = "([^"]+)"', body)
        stat_lines_map[sub_id] = {
            "label": lbl.group(1) if lbl else "",
            "v1": float(v1.group(1)) if v1 else 0.0,
            "vmax": float(vmax.group(1)) if vmax else 0.0,
            "target": target.group(1) if target else "",
            "raw": body
        }

tres_skills = {}
vltk_to_id = {}
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        sid = re.search(r'id = "([^"]+)"', body).group(1)
        name = re.search(r'skill_name = "([^"]+)"', body).group(1)
        vid = int(re.search(r'vltk_skill_id = (\d+)', body).group(1))
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)
        tres_skills[sid] = {
            "id": sid,
            "name": name,
            "vltk_id": vid,
            "lines": [stat_lines_map[l] for l in lines if l in stat_lines_map]
        }
        vltk_to_id[vid] = sid

# Read tianwang.lua
p_lua = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/tianwang.lua"
res_lua = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_lua], capture_output=True)
lua_text = res_lua.stdout.decode("utf-8", "replace")

# Also add child skills mapping to parent skills
# In VLTK:
# 322 (Phá Thiên Trảm) -> child is 326
# 323 (Truy Tinh Trục Nguyệt) -> child is 327
# 324 (Thừa Long Quyết) -> child is 407
# 325 (Truy Phong Quyết) -> child is 408
# 1058 (Hào Hùng Trảm) -> child is 1084 / 1086
# 1059 (Tung Hoành Bát Hoang) -> child is 1087
# 1060 (Bá Vương Tạm Kim) -> child is 1088
child_to_parent = {
    326: 322,
    327: 323,
    407: 324,
    408: 325,
    1084: 1058,
    1086: 1058,
    1087: 1059,
    1088: 1060,
    219: 30,
    220: 32,
    221: 35,
    222: 37,
    224: 40,
    225: 41,
    404: 34,
    405: 29,
    406: 31,
}

for c, p in child_to_parent.items():
    if p in vltk_to_id:
        vltk_to_id[c] = vltk_to_id[p]

skill_blocks = re.findall(r'(\w+)\s*=\s*\{\s*--([^\n]*)\n(.*?)\n\t\},', lua_text, re.DOTALL)

print("================================================================================")
print("KIỂM TRA HỖ TRỢ LẪN NHAU (SYNERGY) TỪ TIANWANG.LUA VS THIEN_VUONG_BANG.TRES")
print("================================================================================")

for sk_var, sk_comment, sk_body in skill_blocks:
    # find all addskilldamage
    add_damages = re.findall(r'addskilldamage(\d+)\s*=\s*\{\s*\[1\]\s*=\s*\{\{1,(\d+)\},\{2,\d+\}\},\s*\[3\]\s*=\s*\{\{1,(\d+)\},\{20,(\d+)', sk_body)
    if not add_damages:
        continue
    
    print(f"\nSource Lua: {sk_var} ({sk_comment.strip()})")
    for num, tgt_id_str, val1, val20 in add_damages:
        tgt_int = int(tgt_id_str)
        mapped_id = vltk_to_id.get(tgt_int, "NOT_FOUND")
        mapped_name = tres_skills.get(mapped_id, {}).get("name", "Unknown") if mapped_id != "NOT_FOUND" else "Unknown"
        print(f"  Lua addskilldamage{num}: target VLTK ID {tgt_int} -> Tres ID: [{mapped_id}] ({mapped_name}) | Giá trị: {val1}% -> {val20}%")

print("\n================================================================================")
print("CHI TIẾT CÁC DÒNG LIÊN KẾT ĐANG CÓ TRONG THIEN_VUONG_BANG.TRES")
print("================================================================================")
for sid, s in tres_skills.items():
    syn_lines = [l for l in s["lines"] if "liên kết" in l["label"].lower() or l["target"] != ""]
    if syn_lines:
        print(f"\nSkill [{sid}] ({s['name']}):")
        for l in syn_lines:
            tgt_name = tres_skills.get(l['target'], {}).get('name', 'KHÔNG TÌM THẤY') if l['target'] else "TRỐNG!"
            status = "OK" if l['target'] and l['target'] in tres_skills else "LỖI HOẶC TRỐNG"
            print(f"  - {l['label']} ({l['v1']} -> {l['vmax']}%) | Target: [{l['target']}] ({tgt_name}) -> {status}")
