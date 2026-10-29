import re
import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
TRES_PATH = ROOT / "systems" / "sect" / "data" / "con_lon.tres"

text = TRES_PATH.read_text(encoding="utf-8")

# Extract SubResources
subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', text, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

print(f"Tổng số sub_resources trong con_lon.tres: {len(subresources)}")

# Resource skills array
res_part = text.split("[resource]")[-1]
linked_sub_ids = re.findall(r'SubResource\("([^"]+)"\)', res_part)
print(f"Số skill được link trong [resource]: {len(linked_sub_ids)}")

skills = []
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body or 'script = ExtResource("2_' in body or 'skill_name' in body:
        m_sid = re.search(r'id = "([^"]+)"', body)
        m_name = re.search(r'skill_name = "([^"]+)"', body)
        m_vid = re.search(r'vltk_skill_id = (\d+)', body)
        m_req = re.search(r'req_level = (\d+)', body)
        m_max = re.search(r'max_level = (\d+)', body)
        m_school = re.search(r'school_text = "([^"]+)"', body)
        m_cat = re.search(r'category = (\d+)', body)
        m_wp = re.search(r'weapon_limit = ([\d\-]+)', body)
        m_hs = re.search(r'horse_limit = ([\d\-]+)', body)
        m_aura = re.search(r'is_aura = (true|false)', body)
        m_hid = re.search(r'is_hidden = (true|false)', body)
        m_desc = re.search(r'description = "([^"]+)"', body)
        m_icon = re.search(r'icon = ExtResource\("([^"]+)"\)', body)
        
        # Lines
        line_ids = re.findall(r'SubResource\("([^"]+)"\)', body)
        
        skills.append({
            "sub_id": sub_id,
            "id": m_sid.group(1) if m_sid else "",
            "name": m_name.group(1) if m_name else "",
            "vid": int(m_vid.group(1)) if m_vid else 0,
            "req": int(m_req.group(1)) if m_req else 1,
            "max": int(m_max.group(1)) if m_max else 20,
            "school": m_school.group(1) if m_school else "",
            "cat": int(m_cat.group(1)) if m_cat else 0,
            "wp": int(m_wp.group(1)) if m_wp else -2,
            "hs": int(m_hs.group(1)) if m_hs else 0,
            "is_aura": m_aura.group(1) == "true" if m_aura else False,
            "is_hidden": m_hid.group(1) == "true" if m_hid else False,
            "desc": m_desc.group(1) if m_desc else "",
            "icon": m_icon.group(1) if m_icon else "",
            "lines": line_ids,
            "is_linked": sub_id in linked_sub_ids,
            "body": body
        })

print(f"\nTìm thấy {len(skills)} skill definitions:")
for i, s in enumerate(sorted(skills, key=lambda x: (x['req'], x['vid']))):
    cat_str = "PASSIVE" if s['cat'] == 1 else ("AURA" if s['is_aura'] else "ACTIVE")
    hid_str = "[HIDDEN]" if s['is_hidden'] else ""
    link_str = "[LINKED]" if s['is_linked'] else "[NOT LINKED!]"
    print(f"{i+1:2d}. VID {s['vid']:4d} | ID: {s['id']:32s} | Name: {s['name']:25s} | Req: {s['req']:3d} | Max: {s['max']:2d} | Wp: {s['wp']:2d} | {cat_str:7s} | {s['school']:12s} | Lines: {len(s['lines']):2d} | {link_str} {hid_str}")
