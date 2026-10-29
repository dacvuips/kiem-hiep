import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
tres_path = ROOT / "systems" / "sect" / "data" / "tieu_dao.tres"
tres = tres_path.read_text(encoding="utf-8")

# Extract sect properties
m_name = re.search(r'sect_name = "([^"]+)"', tres)
m_elem = re.search(r'element = (\d+)', tres)
m_camp = re.search(r'camp = (\d+)', tres)
m_gender = re.search(r'gender_limit = (\d+)', tres)
m_wp = re.search(r'weapon_limit = (\d+)', tres)

print(f"Sect: {m_name.group(1) if m_name else ''} | Element: {m_elem.group(1) if m_elem else ''} | Camp: {m_camp.group(1) if m_camp else ''} | Gender: {m_gender.group(1) if m_gender else ''} | Wp: {m_wp.group(1) if m_wp else ''}")

# Extract subresources
subres = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres, re.DOTALL):
    subres[m.group(1)] = m.group(2)

# Parse statlines
statlines = {}
for sub_id, body in subres.items():
    if 'script = ExtResource("3_statline")' in body:
        stat_name = re.search(r'stat_name = "([^"]+)"', body)
        base = re.search(r'base_value = ([\d\.\-]+)', body)
        growth = re.search(r'growth_per_level = ([\d\.\-]+)', body)
        desc = re.search(r'description = "([^"]+)"', body)
        statlines[sub_id] = {
            "name": stat_name.group(1) if stat_name else "",
            "base": float(base.group(1)) if base else 0.0,
            "growth": float(growth.group(1)) if growth else 0.0,
            "desc": desc.group(1) if desc else ""
        }

# Parse skills
skills = []
for sub_id, body in subres.items():
    if 'script = ExtResource("2_skill")' in body:
        sid = re.search(r'id = "([^"]+)"', body).group(1)
        name = re.search(r'skill_name = "([^"]+)"', body).group(1)
        vid = re.search(r'vltk_skill_id = (\d+)', body)
        req = re.search(r'req_level = (\d+)', body)
        max_l = re.search(r'max_level = (\d+)', body)
        cat = re.search(r'category = (\d+)', body)
        school = re.search(r'school_text = "([^"]+)"', body)
        desc = re.search(r'description = "([^"]+)"', body)
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)
        skills.append({
            "sub_id": sub_id,
            "id": sid,
            "name": name,
            "vid": int(vid.group(1)) if vid else 0,
            "req": int(req.group(1)) if req else 0,
            "max_level": int(max_l.group(1)) if max_l else 20,
            "category": int(cat.group(1)) if cat else 0,
            "school": school.group(1) if school else "",
            "desc": desc.group(1) if desc else "",
            "lines": lines
        })

print(f"\nTotal skills in tieu_dao.tres: {len(skills)}")
for s in sorted(skills, key=lambda x: (x["school"], x["req"], x["vid"])):
    cat_str = "BỊ ĐỘNG" if s["category"] == 1 else "CHỦ ĐỘNG"
    print(f"\n--- [{s['school']}] Lv{s['req']} | {s['name']} (ID: {s['id']}, VLTK: {s['vid']}, {cat_str}, MaxLv: {s['max_level']}) ---")
    if s["desc"]:
        print(f"    Mô tả: {s['desc']}")
    for lid in s["lines"]:
        st = statlines.get(lid, {})
        print(f"    * {st.get('name')}: base={st.get('base')}, growth={st.get('growth')} (Line: {st.get('desc')})")
