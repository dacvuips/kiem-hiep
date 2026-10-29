import os
import re
import sys
import json
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

if sys.platform == "win32":
    git_usr_bin = r"C:\Program Files\Git\usr\bin"
    if os.path.exists(git_usr_bin) and git_usr_bin not in os.environ.get("PATH", ""):
        os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

def iconv(path: Path) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace")

SKILLS_TXT = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt")
MISSILES_TXT = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Missles.txt")

with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

# Đọc Skills.txt gốc
txt_content = iconv(SKILLS_TXT)
lines = txt_content.splitlines()
header = lines[0].split("\t")
col_idx = {h.strip(): i for i, h in enumerate(header)}

skills_txt_map = {}
for line in lines[1:]:
    p = line.split("\t")
    if len(p) > col_idx.get("SkillId", 0):
        try:
            sk_id = int(p[col_idx["SkillId"]].strip())
            skills_txt_map[sk_id] = {h: p[i].strip() if i < len(p) else "" for h, i in col_idx.items()}
        except Exception:
            pass

# Đọc Missles.txt gốc
msl_txt_content = iconv(MISSILES_TXT)
msl_lines = msl_txt_content.splitlines()
msl_header = msl_lines[0].split("\t")
msl_col_idx = {h.strip(): i for i, h in enumerate(msl_header)}
missiles_txt_map = {}
for line in msl_lines[1:]:
    p = line.split("\t")
    if len(p) > msl_col_idx.get("MissleId", 0):
        try:
            m_id = int(p[msl_col_idx["MissleId"]].strip())
            missiles_txt_map[m_id] = {h: p[i].strip() if i < len(p) else "" for h, i in msl_col_idx.items()}
        except Exception:
            pass

con_lon_skills = [
    (167, "Côn Lôn Đao pháp", "Bị động"),
    (168, "Côn Lôn Kiếm pháp", "Bị động"),
    (169, "Hô Phong Pháp", "Đánh ngoại / lôi"),
    (171, "Thanh Phong phù", "Buff thân pháp"),
    (179, "Cuồng Lôi Chấn Địa", "Đánh lôi / nội"),
    (392, "Thúc Phược Chú", "Bùa nguyền"),
    (174, "Ki Bán phù", "Bùa làm chậm"),
    (172, "Thiên Tế Tấn Lôi", "Đánh lôi"),
    (173, "Thiên Thanh Địa Trọc", "Buff kháng"),
    (178, "Nhất Khí Tam Thanh", "Buff dame / chí mạng"),
    (393, "Bắc Minh Đáo Hải", "Buff hồi máu / mana"),
    (175, "Khi Hàn Ngạo Tuyết", "Bùa làm chậm tốc xuất chiêu"),
    (181, "Khí Tâm phù", "Bùa choáng"),
    (90,  "Mê Tung ảo ảnh", "Buff giảm chậm/choáng"),
    (176, "Cuồng Phong Sậu Điện", "Đánh lôi / ngoại"),
    (182, "Ngũ Lôi Chánh Pháp", "Đánh lôi / nội"),
    (275, "Sương Ngạo Côn Lôn", "Trấn phái bị động"),
    (630, "Huyền Thiên Vô Cực", "Bị động khiên 110"),
    (372, "Ngạo Tuyết Tiêu Phong", "Đao 90"),
    (375, "Lôi Động Cửu Thiên", "Kiếm 90"),
    (394, "Túy Tiên Tá Cốt", "Bùa 90"),
    (717, "Lưỡng Nghi Chân Khí", "Bị động 120"),
    (1080, "Cửu Thiên Cương Phong", "Đao 150"),
    (1081, "Thiên Lôi Chấn Nhạc", "Kiếm 150"),
    (1229, "Thiên Cương Khí Kính", "Cao cấp 180"),
]

print("=== SO SÁNH CHI TIẾT FX & THÔNG SỐ VLTK GỐC VS GODOT FX ===")

for vid, vname, vkind in con_lon_skills:
    gok = skills_txt_map.get(vid, {})
    fx = skills_fx.get(str(vid), {})
    
    char_anim = gok.get("CharAnimId", "")
    form = gok.get("MisslesForm", "")
    child_id = gok.get("ChildSkillId", "")
    attack_radius = gok.get("AttackRadius", "")
    is_physical = gok.get("IsPhysical", "")
    target_enemy = gok.get("TargetEnemy", "")
    target_self = gok.get("TargetSelf", "")
    
    fx_char_anim = fx.get("char_anim", "")
    fx_form = fx.get("form", "")
    fx_child = fx.get("child", "")
    fx_radius = fx.get("attack_radius", "")
    fx_precast = fx.get("precast", "")
    
    # Check precast anim
    precast_ok = "Không có"
    if fx_precast:
        p_data = anims_fx.get(fx_precast, {})
        p_path = p_data.get("path") or p_data.get("texture_path") or p_data.get("sprite_sheet", "")
        real_p = ROOT / p_path.replace("res://", "") if p_path else None
        p_exists = real_p.exists() if real_p else False
        precast_ok = f"{fx_precast} (exists={p_exists})"
        
    # Check child missile
    child_str = "None"
    if child_id and child_id != "0":
        m_data = missiles_fx.get(str(child_id), {})
        m_txt = missiles_txt_map.get(int(child_id), {}) if child_id.isdigit() else {}
        
        # Flight anim
        fl_key = m_data.get("flight_anim", "")
        fl_exists = fl_key in anims_fx
        # Hit anim
        hit_key = m_data.get("hit_anim", "")
        hit_exists = hit_key in anims_fx
        
        # DmgRange
        dmg_range_txt = m_txt.get("DmgRange", "")
        is_range_dmg = m_txt.get("IsRangeDmg", "")
        child_str = f"ChildId {child_id} (DmgRange={dmg_range_txt}, RangeDmg={is_range_dmg}) | Flight: {fl_key} (exists={fl_exists}), Hit: {hit_key} (exists={hit_exists})"
    
    print(f"\n[{vid:4d}] {vname:25s} ({vkind})")
    print(f"  Gốc : CharAnim={char_anim}, Form={form}, Radius={attack_radius}, Phys={is_physical}, Enemy={target_enemy}, Self={target_self}, Child={child_id}")
    print(f"  Godot: CharAnim={fx_char_anim}, Form={fx_form}, Radius={fx_radius}, Precast={precast_ok}")
    if child_str != "None":
        print(f"  Đạn/Hiệu ứng: {child_str}")
