import os
import re
import sys
import json
import subprocess
from pathlib import Path

os.environ["PATH"] = r"C:\Program Files\Git\usr\bin;" + os.environ.get("PATH", "")
sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
TRES_PATH = ROOT / "systems" / "sect" / "data" / "thuy_yen_mon.tres"
CUIYAN_LUA = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/cuiyan.lua")
ADVANCED_LUA = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/advancedskill.lua")
SKILLS_TXT = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt")
MISSLES_TXT = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Missles.txt")

with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_json = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_json = json.load(f)

def iconv(path: Path) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace")

skills_txt_lines = iconv(SKILLS_TXT).split("\n")
sk_header = [h.strip() for h in skills_txt_lines[0].split("\t")]
sk_col = {h: i for i, h in enumerate(sk_header)}

skills_txt_map = {}
for line in skills_txt_lines[1:]:
    p = line.split("\t")
    if len(p) > sk_col["SkillId"] and p[sk_col["SkillId"]].strip().isdigit():
        sid = int(p[sk_col["SkillId"]].strip())
        skills_txt_map[sid] = {h: p[sk_col[h]].strip() if len(p) > sk_col[h] else "" for h in sk_header if h in sk_col}

missles_txt_lines = iconv(MISSLES_TXT).split("\n")
ms_header = [h.strip() for h in missles_txt_lines[0].split("\t")]
ms_col = {h: i for i, h in enumerate(ms_header)}
missles_txt_map = {}
for line in missles_txt_lines[1:]:
    p = line.split("\t")
    if len(p) > ms_col["MissleId"] and p[ms_col["MissleId"]].strip().isdigit():
        mid = int(p[ms_col["MissleId"]].strip())
        missles_txt_map[mid] = {h: p[ms_col[h]].strip() if len(p) > ms_col[h] else "" for h in ms_header if h in ms_col}

# Parse thuy_yen_mon.tres
tres_content = TRES_PATH.read_text(encoding="utf-8")
subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

tres_skills = []
for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        sid = re.search(r'id = "([^"]+)"', body).group(1)
        name = re.search(r'skill_name = "([^"]+)"', body).group(1)
        v_id = re.search(r'vltk_skill_id = (\d+)', body)
        req = re.search(r'req_level = (\d+)', body)
        max_l = re.search(r'max_level = (\d+)', body)
        school = re.search(r'school_text = "([^"]+)"', body)
        cat = re.search(r'category = (\d+)', body)
        wp = re.search(r'weapon_limit = ([\d\-]+)', body)
        hs = re.search(r'horse_limit = ([\d\-]+)', body)
        aura = re.search(r'is_aura = (true|false)', body)
        hidden = re.search(r'is_hidden = (true|false)', body)
        
        # parse vltk_attribs
        m_attr = re.search(r'vltk_attribs = \{(.*?)\n\}', body, re.DOTALL)
        attribs = {}
        if m_attr:
            for line in m_attr.group(1).splitlines():
                line = line.strip()
                m_kv = re.match(r'"([^"]+)":\s*\[(.*)\]', line)
                if m_kv:
                    attribs[m_kv.group(1)] = m_kv.group(2)
        
        tres_skills.append({
            "sub_id": sub_id,
            "id": sid,
            "name": name,
            "vltk_id": int(v_id.group(1)) if v_id else 0,
            "req_level": int(req.group(1)) if req else 0,
            "max_level": int(max_l.group(1)) if max_l else 20,
            "school": school.group(1) if school else "",
            "category": int(cat.group(1)) if cat else 0,
            "weapon_limit": int(wp.group(1)) if wp else -2,
            "horse_limit": int(hs.group(1)) if hs else 0,
            "is_aura": aura.group(1) == "true" if aura else False,
            "is_hidden": hidden.group(1) == "true" if hidden else False,
            "attribs": attribs
        })

print(f"Total skills in thuy_yen_mon.tres: {len(tres_skills)}")

print("\n" + "="*80)
print("CHI TIẾT TỪNG SKILL CỦA THÚY YÊN MÔN:")
print("="*80)

for s in sorted(tres_skills, key=lambda x: (x["req_level"], x["vltk_id"])):
    vid = s["vltk_id"]
    status_str = "[ẨN/CHƯA DÙNG]" if s["is_hidden"] else "[HIỆN THỊ]"
    print(f"\n>>> {status_str} Skill: {s['name']} (id: '{s['id']}', VLTK_ID: {vid})")
    print(f"    - Yêu cầu cấp: {s['req_level']} | Cấp tối đa: {s['max_level']} | Nhánh: {s['school']}")
    print(f"    - Loại: {'BỊ ĐỘNG' if s['category']==1 else ('HÀO QUANG' if s['is_aura'] else 'CHỦ ĐỘNG')} | Vũ khí: {s['weapon_limit']} | Ngựa: {s['horse_limit']}")
    print(f"    - Thuộc tính vltk_attribs ({len(s['attribs'])}): {', '.join(s['attribs'].keys())}")
    
    # Check in skills.json
    s_json = skills_json.get(str(vid), {})
    if s_json:
        precast = s_json.get("precast", "")
        child_id = s_json.get("child", 0)
        c_num = s_json.get("child_num", 0)
        form = s_json.get("form", 0)
        fly_evt = s_json.get("fly_event", 0)
        fly_sk = s_json.get("fly_skill", 0)
        col_evt = s_json.get("collide_event", 0)
        col_sk = s_json.get("collide_skill", 0)
        print(f"    - Visual Fx (skills.json): Form={form}, ChildId={child_id} (x{c_num}), Precast='{precast}' (exists: {precast in anims_json})")
        print(f"      FlyEvent: {fly_evt} -> Skill {fly_sk} | CollideEvent: {col_evt} -> Skill {col_sk}")
        
        # Check missile
        if child_id and child_id in missles_txt_map:
            m_info = missles_txt_map[child_id]
            print(f"      Missle #{child_id} ({m_info.get('MissleName')}): Speed={m_info.get('Speed')}, Life={m_info.get('LifeTime')}, DmgRange={m_info.get('DmgRange')}")
            print(f"         AnimFly={m_info.get('AnimFile2')} | AnimHit={m_info.get('AnimFile4')}")
    else:
        print(f"    - Visual Fx: CHƯA CÓ TRONG skills.json!")
