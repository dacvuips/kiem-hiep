import re
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(".")
tres_path = ROOT / "systems" / "sect" / "data" / "minh_giao.tres"
tres_content = tres_path.read_text(encoding="utf-8")

# Parse subresources
subresources = {}
# Match [sub_resource type="..." id="..."] ... until next [sub_resource or [resource]
pattern = r'\[sub_resource type="([^"]+)" id="([^"]+)"\](.*?)(?=\n\[sub_resource|\n\[resource\]|\Z)'
for m in re.finditer(pattern, tres_content, re.DOTALL):
    stype = m.group(1)
    sid = m.group(2)
    body = m.group(3)
    subresources[sid] = {"type": stype, "body": body}

# Find all skills
skills = []
statlines = {}

for sid, data in subresources.items():
    if data["type"] == "Resource" and 'script = ExtResource("3_statline")' in data["body"]:
        b = data["body"]
        label = re.search(r'label = "([^"]+)"', b)
        v1 = re.search(r'value_at_level_1 = ([\d\.\-]+)', b)
        vmax = re.search(r'value_at_max_level = ([\d\.\-]+)', b)
        tgt = re.search(r'target_skill_id = "([^"]+)"', b)
        suffix = re.search(r'suffix = "([^"]+)"', b)
        statlines[sid] = {
            "label": label.group(1) if label else "",
            "v1": float(v1.group(1)) if v1 else 0.0,
            "vmax": float(vmax.group(1)) if vmax else 0.0,
            "target": tgt.group(1) if tgt else "",
            "suffix": suffix.group(1) if suffix else "",
        }

for sid, data in subresources.items():
    if data["type"] == "Resource" and 'script = ExtResource("2_skill")' in data["body"]:
        b = data["body"]
        skill_id = re.search(r'\nid = "([^"]+)"', b)
        sname = re.search(r'\nskill_name = "([^"]+)"', b)
        vid = re.search(r'\nvltk_skill_id = (\d+)', b)
        req = re.search(r'\nreq_level = (\d+)', b)
        max_l = re.search(r'\nmax_level = (\d+)', b)
        active = re.search(r'\nis_active = (true|false)', b)
        hidden = re.search(r'\nis_hidden = (true|false)', b)
        school = re.search(r'\nschool_text = "([^"]+)"', b)
        m_form = re.search(r'\nvltk_missle_form = (\d+)', b)
        atk_rad = re.search(r'\nvltk_attack_radius = (\d+)', b)
        dmg_rng = re.search(r'\nvltk_damage_range = (\d+)', b)
        rng_dmg = re.search(r'\nvltk_range_damage = (\d+)', b)
        icon = re.search(r'\nicon = ExtResource\("([^"]+)"\)', b)
        st_refs = re.findall(r'SubResource\("([^"]+)"\)', b)
        attribs = re.search(r'\nvltk_attribs = (\{.*?\})', b, re.DOTALL)
        
        skills.append({
            "id": skill_id.group(1) if skill_id else "",
            "name": sname.group(1) if sname else "",
            "vltk_id": int(vid.group(1)) if vid else 0,
            "req": int(req.group(1)) if req else 0,
            "max_level": int(max_l.group(1)) if max_l else 0,
            "is_active": active.group(1) == "true" if active else False,
            "is_hidden": hidden.group(1) == "true" if hidden else False,
            "school": school.group(1) if school else "",
            "missile_form": int(m_form.group(1)) if m_form else 0,
            "atk_radius": int(atk_rad.group(1)) if atk_rad else 0,
            "damage_range": int(dmg_rng.group(1)) if dmg_rng else 0,
            "range_damage": int(rng_dmg.group(1)) if rng_dmg else 0,
            "icon": icon.group(1) if icon else "",
            "stat_refs": [r for r in st_refs if r in statlines],
            "has_attribs": bool(attribs),
        })

skills.sort(key=lambda s: (s["req"], s["vltk_id"]))

print("=== 1. KIỂM TRA TOÀN BỘ SKILL MINH GIÁO TRONG TRES ===")
skill_ids_in_tres = {s["id"] for s in skills}
for s in skills:
    links = []
    for r in s["stat_refs"]:
        st = statlines[r]
        if st["target"]:
            valid = st["target"] in skill_ids_in_tres
            links.append(f"-> {st['target']} ({st['v1']}%..{st['vmax']}%) [Valid: {valid}]")
    link_str = ", ".join(links) if links else "None"
    print(f"[{s['req']:3d}] ID {s['vltk_id']:4d} | {s['name']:25s} | Active:{str(s['is_active']):5s} | Hidden:{str(s['is_hidden']):5s} | Links: {link_str}")

print("\n=== 2. KIỂM TRA FX VÀ HÌNH ẢNH (skills.json, missiles.json, anims.json) ===")
with open(ROOT / "data/skill_fx/skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)
with open(ROOT / "data/skill_fx/missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)
with open(ROOT / "data/skill_fx/anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

for s in skills:
    vid_str = str(s["vltk_id"])
    fx_entry = skills_fx.get(vid_str)
    if not fx_entry:
        print(f"Skill {s['vltk_id']} ({s['name']}): CHƯA CÓ TRONG skills.json!")
    else:
        # Check missile / anim
        cast_anim = fx_entry.get("cast_anim", "")
        flying_missile = fx_entry.get("flying_missile", 0)
        vanish_missile = fx_entry.get("vanish_missile", 0)
        collision_missile = fx_entry.get("collision_missile", 0)
        
        # Check if flying missile exists
        m_flying = missiles_fx.get(str(flying_missile)) if flying_missile else None
        fly_anim = m_flying.get("flying_anim", "") if m_flying else ""
        hit_anim = m_flying.get("vanish_anim", "") if m_flying else ""
        
        fly_ok = fly_anim in anims_fx if fly_anim else False
        hit_ok = hit_anim in anims_fx if hit_anim else False
        
        print(f"Skill {s['vltk_id']:4d} ({s['name']:25s}): FX OK | CastAnim: {cast_anim} | Missile: {flying_missile} (FlyAnim:{fly_anim}[{fly_ok}], HitAnim:{hit_anim}[{hit_ok}])")
