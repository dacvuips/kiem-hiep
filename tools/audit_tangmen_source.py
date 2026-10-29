import csv
import sys
import re
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

skills_txt_path = Path(r"D:\game\source_vo-lam-truyen-ky\Client_VLTK\Client_VLTK\settings\skills.txt")
lines = skills_txt_path.read_bytes().decode("gbk", errors="replace").splitlines()

header = lines[0].split("\t")
col_map = {col: i for i, col in enumerate(header)}

def get_field(parts, field):
    idx = col_map.get(field, -1)
    if 0 <= idx < len(parts):
        return parts[idx].strip()
    return ""

tangmen_skills = []
for line in lines[1:]:
    if not line.strip():
        continue
    parts = line.split("\t")
    script = get_field(parts, "LvlSetScript")
    sk_id = get_field(parts, "SkillId")
    sk_name = get_field(parts, "SkillName")
    
    # Also check if it's 150 skill or 180 skill that might be in advancedskill or other scripts
    # or if skill ID is known Tangmen (like 1069, 1070, 1071, 1110, 1223)
    is_tm = "tangmen" in script.lower() or sk_id in ["1069", "1070", "1071", "1110", "1223"]
    if is_tm:
        tangmen_skills.append({
            "id": int(sk_id) if sk_id.isdigit() else -1,
            "name": sk_name,
            "req_lvl": get_field(parts, "ReqLevel"),
            "max_lvl": get_field(parts, "MaxLevel"),
            "style": get_field(parts, "SkillStyle"),
            "script": script,
            "param1": get_field(parts, "Param1"),
            "param2": get_field(parts, "Param2"),
            "is_aura": get_field(parts, "IsAura"),
            "is_phys": get_field(parts, "IsPhysical"),
            "attack_radius": get_field(parts, "AttackRadius"),
            "char_anim": get_field(parts, "CharAnimId"),
            "pre_cast_spr": get_field(parts, "PreCastSpr"),
            "man_snd": get_field(parts, "ManCastSnd"),
            "fm_snd": get_field(parts, "FMCastSnd"),
            "fly_skill": get_field(parts, "FlySkillId"),
            "start_skill": get_field(parts, "StartSkillId"),
            "collid_skill": get_field(parts, "CollidSkillId"),
            "vanish_skill": get_field(parts, "VanishedSkillId"),
            "child_skill": get_field(parts, "ChildSkillId"),
            "child_num": get_field(parts, "ChildSkillNum"),
            "eqt_limit": get_field(parts, "EqtLimit"),
            "horse_limit": get_field(parts, "HorseLimit"),
        })

print(f"Tổng số skill Đường Môn tìm thấy trong Client_VLTK/skills.txt: {len(tangmen_skills)}")
for s in sorted(tangmen_skills, key=lambda x: (int(x["req_lvl"]) if x["req_lvl"].isdigit() else 999, x["id"])):
    print(f"Lvl {s['req_lvl']:>3} | ID: {s['id']:>4} | Name: {s['name']:<25} | Max: {s['max_lvl']:>2} | Anim: {s['char_anim']:>2} | Radius: {s['attack_radius']:>4} | Child: {s['child_skill']:<4} | Fly: {s['fly_skill']:<4} | Script: {s['script']}")
