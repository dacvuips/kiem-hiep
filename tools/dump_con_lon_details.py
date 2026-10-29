import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
TRES_PATH = ROOT / "systems" / "sect" / "data" / "con_lon.tres"

text = TRES_PATH.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', text, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

lines_dict = {}
for sub_id, body in subresources.items():
    if 'script = ExtResource("3_statline")' in body:
        lbl = re.search(r'label = "([^"]+)"', body)
        v1 = re.search(r'value_at_level_1 = ([\d\.\-]+)', body)
        vmax = re.search(r'value_at_max_level = ([\d\.\-]+)', body)
        sfx = re.search(r'suffix = "([^"]*)"', body)
        tgt = re.search(r'target_skill_id = "([^"]+)"', body)
        is_rng = 'is_range = true' in body
        min1 = re.search(r'min_at_level_1 = ([\d\.\-]+)', body)
        max1 = re.search(r'max_at_level_1 = ([\d\.\-]+)', body)
        min_max = re.search(r'min_at_max_level = ([\d\.\-]+)', body)
        max_max = re.search(r'max_at_max_level = ([\d\.\-]+)', body)
        
        lines_dict[sub_id] = {
            "label": lbl.group(1) if lbl else "",
            "v1": float(v1.group(1)) if v1 else 0.0,
            "vmax": float(vmax.group(1)) if vmax else 0.0,
            "suffix": sfx.group(1) if sfx else "",
            "target": tgt.group(1) if tgt else "",
            "is_range": is_rng,
            "min1": float(min1.group(1)) if min1 else 0.0,
            "max1": float(max1.group(1)) if max1 else 0.0,
            "min_max": float(min_max.group(1)) if min_max else 0.0,
            "max_max": float(max_max.group(1)) if max_max else 0.0,
        }

skills = []
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        m_sid = re.search(r'id = "([^"]+)"', body)
        m_name = re.search(r'skill_name = "([^"]+)"', body)
        m_vid = re.search(r'vltk_skill_id = (\d+)', body)
        m_req = re.search(r'req_level = (\d+)', body)
        m_max = re.search(r'max_level = (\d+)', body)
        m_school = re.search(r'school_text = "([^"]+)"', body)
        m_cat = re.search(r'category = (\d+)', body)
        m_wp = re.search(r'weapon_limit = ([\d\-]+)', body)
        m_aura = re.search(r'is_aura = (true|false)', body)
        m_hid = re.search(r'is_hidden = (true|false)', body)
        m_desc = re.search(r'description = "([^"]+)"', body)
        m_icon = re.search(r'icon = ExtResource\("([^"]+)"\)', body)
        
        line_ids = re.findall(r'SubResource\("([^"]+)"\)', body)
        attr_lines = [lines_dict[lid] for lid in line_ids if lid in lines_dict]
                
        skills.append({
            "id": m_sid.group(1) if m_sid else "",
            "name": m_name.group(1) if m_name else "",
            "vid": int(m_vid.group(1)) if m_vid else 0,
            "req": int(m_req.group(1)) if m_req else 1,
            "max": int(m_max.group(1)) if m_max else 20,
            "school": m_school.group(1) if m_school else "",
            "cat": int(m_cat.group(1)) if m_cat else 0,
            "wp": int(m_wp.group(1)) if m_wp else -2,
            "is_aura": m_aura.group(1) == "true" if m_aura else False,
            "is_hidden": m_hid.group(1) == "true" if m_hid else False,
            "desc": m_desc.group(1) if m_desc else "",
            "icon": m_icon.group(1) if m_icon else "",
            "attrs": attr_lines
        })

for i, s in enumerate(sorted(skills, key=lambda x: (x['is_hidden'], x['req'], x['vid']))):
    hid_str = "[HIDDEN] " if s['is_hidden'] else ""
    print(f"\n{i+1:2d}. {hid_str}{s['name']} (ID: {s['id']}, VID: {s['vid']}, Req: {s['req']}, Max: {s['max']}, Wp: {s['wp']})")
    print(f"    Mô tả: {s['desc']}")
    for a in s['attrs']:
        if a['is_range']:
            val_str = f"Lvl1: {a['min1']}-{a['max1']} -> LvlMax: {a['min_max']}-{a['max_max']}{a['suffix']}"
        else:
            val_str = f"Lvl1: {a['v1']} -> LvlMax: {a['vmax']}{a['suffix']}"
        tgt_str = f" [Hỗ trợ -> {a['target']}]" if a['target'] else ""
        print(f"    * {a['label']}: {val_str}{tgt_str}")
