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

print("=== KIỂM TRA BASE VÀ MISSILE RESOLUTION CHO CÁC SKILL THIÊN VƯƠNG ===")
for sid in tw_skill_ids:
    s = skills_fx.get(str(sid), {})
    name = s.get("name", "Unknown")
    base = s.get("base", 0)
    child = s.get("child", 0)
    child_num = s.get("child_num", 0)
    style = s.get("style", 0)
    form = s.get("form", 0)
    
    # Check if missile exists for child
    m_exists = str(child) in missiles_fx
    m_info = missiles_fx.get(str(child), {})
    m_anim = m_info.get("anim", "")
    m_hit = m_info.get("hit_anim", "")
    
    # Check if child is in skills
    c_is_skill = str(child) in skills_fx
    c_s = skills_fx.get(str(child), {})
    c_base = c_s.get("base", 0)
    c_child = c_s.get("child", 0)
    c_m_exists = str(c_child) in missiles_fx
    c_m_info = missiles_fx.get(str(c_child), {})
    
    print(f"\nSkill {sid:4d}: {name:25s} | Style:{style} | Form:{form} | Base:{base} | Child:{child} (x{child_num})")
    print(f"  Missile for child({child}): exists={m_exists}, anim='{m_anim}', hit='{m_hit}'")
    if c_is_skill:
        print(f"  Child is also Skill({child}): Base={c_base}, NextChild={c_child}, NextChildMissileExists={c_m_exists}, hit='{c_m_info.get('hit_anim')}'")
