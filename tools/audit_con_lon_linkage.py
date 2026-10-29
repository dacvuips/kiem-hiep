import re
import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

# 1. Kiểm tra skill linkage trong con_lon.tres
tres_text = (ROOT / "systems" / "sect" / "data" / "con_lon.tres").read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_text, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

lines_dict = {}
for sub_id, body in subresources.items():
    if 'script = ExtResource("3_statline")' in body:
        lbl = re.search(r'label = "([^"]+)"', body)
        tgt = re.search(r'target_skill_id = "([^"]+)"', body)
        lines_dict[sub_id] = {
            "label": lbl.group(1) if lbl else "",
            "target": tgt.group(1) if tgt else ""
        }

skill_ids = set()
skill_list = []
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        sid = re.search(r'id = "([^"]+)"', body).group(1)
        name = re.search(r'skill_name = "([^"]+)"', body).group(1)
        vid = int(re.search(r'vltk_skill_id = (\d+)', body).group(1)) if re.search(r'vltk_skill_id = (\d+)', body) else 0
        lids = re.findall(r'SubResource\("([^"]+)"\)', body)
        targets = []
        for lid in lids:
            if lid in lines_dict and lines_dict[lid]["target"]:
                targets.append((lines_dict[lid]["label"], lines_dict[lid]["target"]))
        skill_ids.add(sid)
        skill_list.append((sid, name, vid, targets))

print("=== 1. KIỂM TRA TARGET_SKILL_ID (SKILL LINKAGE / HỖ TRỢ) ===")
for sid, name, vid, targets in skill_list:
    if targets:
        print(f"\nSkill '{name}' ({sid}, VID {vid}) hỗ trợ:")
        for lbl, tgt in targets:
            exists = tgt in skill_ids
            status = "HỢP LỆ" if exists else "LỖI: KHÔNG TỒN TẠI TRONG CON_LON.TRES!"
            print(f"  -> {tgt} ({status}) | Label: {lbl}")

