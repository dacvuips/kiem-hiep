import os
import sys
import re
import json
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

ROOT = Path(__file__).resolve().parent.parent

# Load Skills.txt
p_skills = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt"
res2 = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_skills], capture_output=True)
skills_text = res2.stdout.decode("utf-8", "replace")
skills_lines = skills_text.split("\n")
skill_headers = [h.strip() for h in skills_lines[0].split("\t")]
skill_col_map = {h: i for i, h in enumerate(skill_headers)}

skills_by_id = {}
for line in skills_lines[1:]:
    cols = line.split("\t")
    if len(cols) > 2 and cols[2].strip().isdigit():
        sid = int(cols[2].strip())
        skills_by_id[sid] = {h: cols[skill_col_map[h]].strip() if skill_col_map[h] < len(cols) else "" for h in skill_headers}

# Danh sách skill Nga Mi chính thức từ factionhead.lua:
# Kiếm pháp:
#   85: Nhất Diệp Tri Thu (lv 10)
#   77: Nga My Kiếm Pháp (lv 10 - passive)
#  385: Thôi Song Vọng Nguyệt (lv 30)
#   88: Bất Diệt Bất Tuyệt (lv 60)
#  328: Tam Nga Tề Tuyết (lv 90)
# 1061: Kiếm Hoa Vãn Tinh (lv 150)
# Chưởng pháp:
#   80: Phiêu Tuyết Xuyên Vân (lv 10)
#   79: Nga My Chưởng Pháp (lv 10 - passive)
#   82: Tứ Tượng Đồng Quy (lv 30)
#   91: Phật Quang Phổ Chiếu (lv 60)
#  380: Phong Sương Toái Ảnh (lv 90)
# 1062: Băng Vũ Lạc Tinh (lv 150)
# Hỗ trợ / Trấn phái:
#   93: Từ Hàng Phổ Độ (lv 20 - hồi máu)
#   89: Mộng Điệp (lv 30 - hào quang)
#   86: Lưu Thủy (lv 40 - bùa/hào quang chạy nhanh)
#   92: Phật Tâm Từ Hữu (lv 50 - tăng sinh lực)
#  282: Thanh Âm Phạn Xướng (lv 60 - giảm thời gian hiệu ứng)
#  252: Phật Pháp Vô Biên (lv 60 - trấn phái)
#  332: Phổ Độ Chúng Sinh (lv 90 - hào quang cứu nhân độ thế)
#  712: Bế Nguyệt Phất Trần (lv 120 - bùa bảo hộ hào quang)
# 1224: Ba La Tâm Kinh (lv 180 - tuyệt kỹ ngũ hành Thủy)

emei_ids = [77, 79, 80, 85, 93, 385, 82, 89, 86, 92, 88, 91, 282, 252, 328, 380, 332, 712, 1061, 1062, 1224]

print(f"Total canonical Emei skills: {len(emei_ids)}")

print("\n" + "="*100)
print(f"{'ID':<5} | {'Skill Name':<25} | {'ReqL':<5} | {'MaxL':<5} | {'Eqt':<5} | {'Horse':<5} | {'Style':<6} | {'Aura':<5} | {'Anim':<5} | {'Start/Fly/Coll/Van'}")
print("="*100)
for sid in sorted(emei_ids, key=lambda x: (int(skills_by_id[x]['ReqLevel']) if x in skills_by_id and skills_by_id[x]['ReqLevel'].isdigit() else 0, x)):
    if sid not in skills_by_id:
        print(f"ID {sid} NOT IN SKILLS.TXT!")
        continue
    d = skills_by_id[sid]
    chain = f"{d.get('StartSkillId','')}/{d.get('FlySkillId','')}/{d.get('CollidSkillId','')}/{d.get('VanishedSkillId','')}"
    print(f"{sid:<5} | {d['SkillName']:<25} | {d['ReqLevel']:<5} | {d['MaxLevel']:<5} | {d['EqtLimit']:<5} | {d['HorseLimit']:<5} | {d['SkillStyle']:<6} | {d['IsAura']:<5} | {d['CharAnimId']:<5} | {chain}")

# Tra cứu các child skill / sub missile liên quan
print("\n" + "="*100)
print("CHI TIẾT HIỆU ỨNG VÀ CÁC SKILL LIÊN HOÀN (SUB-SKILLS / FLY / IMPACT):")
print("="*100)
for sid in emei_ids:
    if sid not in skills_by_id: continue
    d = skills_by_id[sid]
    child = d.get('ChildSkillId', '')
    start_s = d.get('StartSkillId', '')
    fly_s = d.get('FlySkillId', '')
    coll_s = d.get('CollidSkillId', '')
    van_s = d.get('VanishedSkillId', '')
    print(f"\n[ID {sid}] {d['SkillName']} (Style: {d['SkillStyle']}, Form: {d['MisslesForm']}, AtkRadius: {d['AttackRadius']}, PreCastSpr: {d['PreCastSpr']})")
    print(f"   Target: Enemy={d['TargetEnemy']}, Ally={d['TargetAlly']}, Self={d['TargetSelf']} | DoHurt: {d['DoHurt']}")
    print(f"   FlySkill: {fly_s} | CollidSkill: {coll_s} | VanishSkill: {van_s} | StartSkill: {start_s} | ChildSkill: {child} (num: {d.get('ChildSkillNum','')})")
    
    # Check related sub skills
    related = [x for x in [start_s, fly_s, coll_s, van_s, child] if x and x.isdigit() and int(x) > 0]
    for r in related:
        rid = int(r)
        if rid in skills_by_id:
            rd = skills_by_id[rid]
            print(f"      -> SubSkill [{rid}] {rd['SkillName']}: Style={rd['SkillStyle']}, PreCast={rd['PreCastSpr']}, Form={rd['MisslesForm']}, CollidSkill={rd.get('CollidSkillId','')}")
