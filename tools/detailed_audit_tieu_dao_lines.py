import sys
import re
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent

tres = (ROOT / "systems" / "sect" / "data" / "tieu_dao.tres").read_text(encoding="utf-8")

subres = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres, re.DOTALL):
    subres[m.group(1)] = m.group(2)

statlines = {}
for sub_id, body in subres.items():
    if 'script = ExtResource("3_statline")' in body:
        lbl = re.search(r'label = "([^"]+)"', body)
        is_rng = 'is_range = true' in body
        v1 = re.search(r'value_at_level_1 = ([\d\.\-]+)', body)
        vm = re.search(r'value_at_max_level = ([\d\.\-]+)', body)
        min1 = re.search(r'min_at_level_1 = ([\d\.\-]+)', body)
        max1 = re.search(r'max_at_level_1 = ([\d\.\-]+)', body)
        minm = re.search(r'min_at_max_level = ([\d\.\-]+)', body)
        maxm = re.search(r'max_at_max_level = ([\d\.\-]+)', body)
        suf = re.search(r'suffix = "([^"]*)"', body)
        tgt = re.search(r'target_skill_id = "([^"]*)"', body)
        statlines[sub_id] = {
            "label": lbl.group(1) if lbl else "",
            "is_range": is_rng,
            "v1": float(v1.group(1)) if v1 else 0.0,
            "vm": float(vm.group(1)) if vm else 0.0,
            "min1": float(min1.group(1)) if min1 else 0.0,
            "max1": float(max1.group(1)) if max1 else 0.0,
            "minm": float(minm.group(1)) if minm else 0.0,
            "maxm": float(maxm.group(1)) if maxm else 0.0,
            "suffix": suf.group(1) if suf else "",
            "target": tgt.group(1) if tgt else ""
        }

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
            "id": sid,
            "name": name,
            "vid": int(vid.group(1)) if vid else 0,
            "req": int(req.group(1)) if req else 0,
            "max": int(max_l.group(1)) if max_l else 20,
            "cat": "Bị động" if (cat and cat.group(1) == "1") else "Chủ động",
            "school": school.group(1) if school else "",
            "desc": desc.group(1) if desc else "",
            "lines": lines
        })

print(f"=== TIÊU DAO SKILLS AUDIT IN TIEU_DAO.TRES ({len(skills)} skills) ===")
for s in sorted(skills, key=lambda x: (x["school"], x["req"], x["vid"])):
    print(f"\n[{s['school']}] Lv{s['req']} - {s['name']} (id: {s['id']}, vltk_id: {s['vid']}, max_lv: {s['max']}, {s['cat']})")
    for lid in s["lines"]:
        st = statlines.get(lid, {})
        if st.get("is_range"):
            val_str = f"min {st['min1']}->{st['minm']}, max {st['max1']}->{st['maxm']}{st['suffix']}"
        else:
            val_str = f"{st['v1']} -> {st['vm']}{st['suffix']}"
        tgt_str = f" -> target: {st['target']}" if st.get("target") else ""
        print(f"   * {st.get('label')}: {val_str}{tgt_str}")
