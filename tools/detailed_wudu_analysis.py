import re
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

tres_path = Path("systems/sect/data/ngu_doc_giao.tres")
content = tres_path.read_text(encoding="utf-8")

# Parse sub resources
sections = content.split('[sub_resource type="Resource" id="')

statlines = {}
skills = {}

for sec in sections[1:]:
    lines = sec.split("\n")
    sub_id = lines[0].split('"')[0]
    sec_body = "\n".join(lines[1:])
    if 'script = ExtResource("3_statline")' in sec_body:
        label = re.search(r'label = "([^"]+)"', sec_body)
        val1 = re.search(r'value_at_level_1 = ([\d\.\-]+)', sec_body)
        valmax = re.search(r'value_at_max_level = ([\d\.\-]+)', sec_body)
        suffix = re.search(r'suffix = "([^"]*)"', sec_body)
        target = re.search(r'target_skill_id = "([^"]*)"', sec_body)
        statlines[sub_id] = {
            "sub_id": sub_id,
            "label": label.group(1) if label else "",
            "v1": float(val1.group(1)) if val1 else 0.0,
            "vmax": float(valmax.group(1)) if valmax else 0.0,
            "suffix": suffix.group(1) if suffix else "",
            "target": target.group(1) if target else ""
        }
    elif 'script = ExtResource("2_skill")' in sec_body:
        sid = re.search(r'id = "([^"]+)"', sec_body)
        sname = re.search(r'skill_name = "([^"]+)"', sec_body)
        vltk_id = re.search(r'vltk_skill_id = (-?\d+)', sec_body)
        req_lvl = re.search(r'req_level = (\d+)', sec_body)
        max_lvl = re.search(r'max_level = (\d+)', sec_body)
        school_text = re.search(r'school_text = "([^"]+)"', sec_body)
        is_active = re.search(r'is_active = (true|false)', sec_body)
        is_main_attack = re.search(r'is_main_attack = (true|false)', sec_body)
        is_aura = re.search(r'is_aura = (true|false)', sec_body)
        target_enemy = re.search(r'target_enemy = (true|false)', sec_body)
        target_ally = re.search(r'target_ally = (true|false)', sec_body)
        target_self = re.search(r'target_self = (true|false)', sec_body)
        missle_form = re.search(r'vltk_missle_form = (-?\d+)', sec_body)
        dmg_range = re.search(r'vltk_damage_range = (-?\d+)', sec_body)
        range_dmg = re.search(r'vltk_range_damage = (-?\d+)', sec_body)
        attack_radius = re.search(r'vltk_attack_radius = (-?\d+)', sec_body)
        parent_id = re.search(r'parent_skill_id = "([^"]*)"', sec_body)
        is_hidden = re.search(r'is_hidden = (true|false)', sec_body)
        
        # stat refs
        stats_refs = re.findall(r'SubResource\("([^"]+)"\)', sec_body)
        
        # icon ext resource id
        icon_res = re.search(r'icon = ExtResource\("([^"]+)"\)', sec_body)
        
        # attribs
        attribs_match = re.search(r'vltk_attribs = (\{.*?\n\})', sec_body, re.DOTALL)
        
        skill_id_val = sid.group(1) if sid else ""
        skills[skill_id_val] = {
            "sub_id": sub_id,
            "id": skill_id_val,
            "name": sname.group(1) if sname else "",
            "vltk_id": int(vltk_id.group(1)) if vltk_id else -1,
            "req_level": int(req_lvl.group(1)) if req_lvl else 0,
            "max_level": int(max_lvl.group(1)) if max_lvl else 0,
            "school_text": school_text.group(1) if school_text else "",
            "is_active": is_active.group(1) == "true" if is_active else True,
            "is_main_attack": is_main_attack.group(1) == "true" if is_main_attack else False,
            "is_aura": is_aura.group(1) == "true" if is_aura else False,
            "target_enemy": target_enemy.group(1) == "true" if target_enemy else False,
            "target_ally": target_ally.group(1) == "true" if target_ally else False,
            "target_self": target_self.group(1) == "true" if target_self else False,
            "missle_form": int(missle_form.group(1)) if missle_form else -1,
            "dmg_range": int(dmg_range.group(1)) if dmg_range else 0,
            "range_dmg": int(range_dmg.group(1)) if range_dmg else 0,
            "attack_radius": int(attack_radius.group(1)) if attack_radius else 0,
            "parent_id": parent_id.group(1) if parent_id else "",
            "is_hidden": is_hidden.group(1) == "true" if is_hidden else False,
            "stat_refs": stats_refs,
            "icon_res": icon_res.group(1) if icon_res else "",
            "attribs_raw": attribs_match.group(1) if attribs_match else "{}"
        }

# Inspect icons in ext_resources
icons_map = {}
for m in re.finditer(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', content):
    icons_map[m.group(2)] = m.group(1)

print(f"Total skills parsed: {len(skills)}")

# Load fx
with open('data/skill_fx/skills.json', 'r', encoding='utf-8') as f:
    skills_fx = json.load(f)
with open('data/skill_fx/missiles.json', 'r', encoding='utf-8') as f:
    missiles = json.load(f)

# Analyze each skill
for sid, s in sorted(skills.items(), key=lambda x: (x[1]['req_level'], x[1]['vltk_id'])):
    icon_path = icons_map.get(s['icon_res'], "NO ICON")
    icon_exists = Path(icon_path.replace("res://", "")).exists() if icon_path != "NO ICON" else False
    
    # Check link synergy
    links = []
    stat_list = []
    for ref in s['stat_refs']:
        st = statlines.get(ref)
        if st:
            stat_list.append(f"{st['label']}: {st['v1']}->{st['vmax']}{st['suffix']}")
            if st['target']:
                target_skill = skills.get(st['target'])
                target_name = target_skill['name'] if target_skill else f"MISSING({st['target']})"
                links.append(f"-> {target_name} ({st['v1']}->{st['vmax']}{st['suffix']})")
                
    # Check fx
    fx_entry = skills_fx.get(str(s['vltk_id'])) if s['vltk_id'] > 0 else None
    
    print("=" * 80)
    print(f"[{s['req_level']:3d}] {s['name']} (ID: {s['id']}, VLTK_ID: {s['vltk_id']})")
    print(f"      School: {s['school_text']} | Active: {s['is_active']} | Main: {s['is_main_attack']} | Aura: {s['is_aura']}")
    print(f"      Icon: {icon_path} (Exists: {icon_exists})")
    print(f"      Targets: Enemy={s['target_enemy']}, Ally={s['target_ally']}, Self={s['target_self']}")
    print(f"      Form={s['missle_form']}, DmgRange={s['dmg_range']}, RangeDmg={s['range_dmg']}, AtkRadius={s['attack_radius']}")
    if s['parent_id']:
        print(f"      Parent Skill: {s['parent_id']}")
    if links:
        print(f"      Synergy Links: {', '.join(links)}")
    if fx_entry:
        cid = fx_entry.get('child', 0)
        m = missiles.get(str(cid), {}) if cid else {}
        print(f"      FX: char_anim={fx_entry.get('char_anim')}, precast={fx_entry.get('precast')}, child={cid} (name={m.get('name')}, kind={m.get('move_kind')}, spd={m.get('speed')}, life={m.get('life')})")
    else:
        print(f"      FX: NO ENTRY IN skills.json (VLTK_ID={s['vltk_id']})")
    print(f"      Stats count: {len(stat_list)}")
