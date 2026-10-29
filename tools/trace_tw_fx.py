import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

tw_skill_ids = [23, 24, 26, 29, 30, 34, 33, 31, 35, 37, 40, 42, 32, 36, 41, 324, 322, 323, 325, 708, 1058, 1059, 1060, 1221]

def anim_status(anim_name):
    if not anim_name:
        return "None"
    in_json = anim_name in anims_fx
    p_png = ROOT / "assets" / "skill_fx" / f"{anim_name}.png"
    p_json = ROOT / "assets" / "skill_fx" / f"{anim_name}.json"
    disk = p_png.exists() and p_json.exists()
    return f"{anim_name} [json:{in_json}, disk:{disk}]"

print("================================================================================")
print("TRUY VẾT CHI TIẾT FX ĐẠN / HÌNH ẢNH CỦA THIÊN VƯƠNG BANG")
print("================================================================================")

for sid in tw_skill_ids:
    s = skills_fx.get(str(sid), {})
    name = s.get("name", "Unknown")
    child = s.get("child", 0)
    child_num = s.get("child_num", 0)
    precast = s.get("precast", "")
    char_anim = s.get("char_anim", 0)
    radius = s.get("attack_radius", 0)
    
    print(f"\n--- Skill {sid}: {name} ---")
    print(f"  Precast: {anim_status(precast)} | CharAnim: {char_anim} | AttackRadius: {radius} | Child: {child} (x{child_num})")
    
    # Check if this skill itself has a missile or start/fly/collide skill
    for evt_field in ["start_skill", "fly_skill", "collide_skill", "vanish_skill"]:
        ev_id = s.get(evt_field, 0)
        if ev_id > 0:
            print(f"  {evt_field}: {ev_id}")

    # Inspect child chain
    curr_child = child
    visited = set()
    while curr_child > 0 and curr_child not in visited:
        visited.add(curr_child)
        c_info = skills_fx.get(str(curr_child), {})
        c_name = c_info.get("name", "ChildSkill")
        c_next = c_info.get("child", 0)
        c_num = c_info.get("child_num", 0)
        c_fly_sk = c_info.get("fly_skill", 0)
        c_coll_sk = c_info.get("collide_skill", 0)
        c_van_sk = c_info.get("vanish_skill", 0)
        
        # Check missile in missiles.json
        m_info = missiles_fx.get(str(curr_child), {})
        m_anim = m_info.get("anim", "")
        m_hit = m_info.get("hit_anim", "")
        m_sound = m_info.get("sound", "")
        m_hit_sound = m_info.get("hit_sound", "")
        m_radius = m_info.get("radius", 0)
        
        print(f"  -> Child {curr_child} ({c_name}): next_child={c_next}(x{c_num}), fly_sk={c_fly_sk}, coll_sk={c_coll_sk}")
        if m_info:
            print(f"     Missile {curr_child}: fly={anim_status(m_anim)}, hit={anim_status(m_hit)}, radius={m_radius}, snd={m_sound}, hit_snd={m_hit_sound}")
        else:
            print(f"     Missile {curr_child}: KHÔNG CÓ TRONG missiles.json!")
        curr_child = c_next
