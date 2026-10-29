import json
import re
import os
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = r"C:\Program Files\Git\usr\bin;" + os.environ.get("PATH", "")

ROOT = Path(__file__).resolve().parent.parent
SRC_BASE = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server")
ICONV_EXE = r"C:\Program Files\Git\usr\bin\iconv.exe"

def iconv(path: Path) -> str:
    res = subprocess.run([ICONV_EXE, "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                         capture_output=True, check=True)
    return res.stdout.decode("utf-8", "replace")

print("================================================================================")
print("              AUDIT CHI TIẾT KỸ NĂNG VÕ ĐANG PHÁI (SOURCE GỐC VS GODOT)          ")
print("================================================================================")

# 1. Load Skills.txt
skills_txt_lines = iconv(SRC_BASE / "settings" / "Skills.txt").splitlines()
sk_header = [h.strip() for h in skills_txt_lines[0].split("\t")]
sk_col = {h: i for i, h in enumerate(sk_header)}
skills_txt_map = {}
for line in skills_txt_lines[1:]:
    p = line.split("\t")
    if len(p) > sk_col["SkillId"] and p[sk_col["SkillId"]].strip().isdigit():
        sid = int(p[sk_col["SkillId"]].strip())
        skills_txt_map[sid] = {h: p[sk_col[h]].strip() if len(p) > sk_col[h] else "" for h in sk_header if h in sk_col}

# 2. Load Missles.txt
missles_txt_lines = iconv(SRC_BASE / "settings" / "Missles.txt").splitlines()
ms_header = [h.strip() for h in missles_txt_lines[0].split("\t")]
ms_col = {h: i for i, h in enumerate(ms_header)}
missles_txt_map = {}
for line in missles_txt_lines[1:]:
    p = line.split("\t")
    if len(p) > ms_col["MissleId"] and p[ms_col["MissleId"]].strip().isdigit():
        mid = int(p[ms_col["MissleId"]].strip())
        missles_txt_map[mid] = {h: p[ms_col[h]].strip() if len(p) > ms_col[h] else "" for h in ms_header if h in ms_col}

# 3. Load JSONs
with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)
with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)
with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

# 4. Load vo_dang.tres
tres_path = ROOT / "systems" / "sect" / "data" / "vo_dang.tres"
tres_content = tres_path.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

stat_lines_map = {}
for sub_id, body in subresources.items():
    if 'script = ExtResource("3_statline")' in body:
        lbl = re.search(r'label = "([^"]+)"', body)
        v1 = re.search(r'value_at_level_1 = ([\d\.\-]+)', body)
        vmax = re.search(r'value_at_max_level = ([\d\.\-]+)', body)
        suffix = re.search(r'suffix = "([^"]*)"', body)
        target = re.search(r'target_skill_id = "([^"]+)"', body)
        stat_lines_map[sub_id] = {
            "label": lbl.group(1) if lbl else "",
            "v1": float(v1.group(1)) if v1 else 0.0,
            "vmax": float(vmax.group(1)) if vmax else 0.0,
            "suffix": suffix.group(1) if suffix else "",
            "target": target.group(1) if target else ""
        }

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
        icon_m = re.search(r'icon = ExtResource\("([^"]+)"\)', body)
        lines = re.findall(r'SubResource\("([^"]+)"\)', body)
        
        m_attr = re.search(r'vltk_attribs = \{(.*?)\n\}', body, re.DOTALL)
        attribs = {}
        if m_attr:
            for l in m_attr.group(1).splitlines():
                l = l.strip()
                m_kv = re.match(r'"([^"]+)":\s*\[(.*)\]', l)
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
            "icon": icon_m.group(1) if icon_m else "",
            "stat_lines": [stat_lines_map.get(sl, {}) for sl in lines if sl in stat_lines_map],
            "attribs": attribs,
            "body": body
        })

print(f"\n1. KIỂM TRA TỪNG SKILL TRONG vo_dang.tres (Tổng cộng {len(tres_skills)} skills):")
print("-" * 80)

for s in sorted(tres_skills, key=lambda x: (x["req_level"], x["vltk_id"], x["id"])):
    vid = s["vltk_id"]
    status_tag = "[ẨN/CON]" if s["is_hidden"] else "[CHÍNH]"
    print(f"\n>>> {status_tag} {s['id']} (VLTK ID: {vid}) - {s['name']}")
    print(f"    Yêu cầu: Cấp {s['req_level']}, Max cấp {s['max_level']}, Nhánh: {s['school']}")
    print(f"    Vũ khí: {s['weapon_limit']}, Cưỡi ngựa: {s['horse_limit']}")
    
    # Check vltk_skill_id
    if vid == 0:
        print(f"    [CẢNH BÁO] vltk_skill_id = 0! Chưa gắn ID gốc của VLTK!")
    elif vid in skills_txt_map:
        sk_src = skills_txt_map[vid]
        print(f"    [SOURCE GỐC] Tên: '{sk_src['SkillName']}', Child/Missile: {sk_src.get('ChildSkillId')}, CastAnim: {sk_src.get('CastAnim')}")
    else:
        print(f"    [CẢNH BÁO] vltk_skill_id {vid} không có trong Skills.txt!")
        
    # Check Visual Fx
    fx = skills_fx.get(str(vid), {})
    if fx:
        child_id = fx.get("child", 0)
        cnum = fx.get("child_num", 0)
        form = fx.get("form", 0)
        fly_evt = fx.get("fly_event", 0)
        col_evt = fx.get("collide_event", 0)
        fly_sk = fx.get("fly_skill", 0)
        col_sk = fx.get("collide_skill", 0)
        precast = fx.get("precast", "")
        
        m_info = missiles_fx.get(str(child_id), {}) if child_id else {}
        fly_anim = m_info.get("fly", "")
        hit_anim = m_info.get("hit", "")
        dmg_range = m_info.get("range", 0)
        
        fly_exist = fly_anim in anims_fx if fly_anim else True
        hit_exist = hit_anim in anims_fx if hit_anim else True
        pre_exist = precast in anims_fx if precast else True
        
        print(f"    [VISUAL FX] Form: {form}, Child Missle: #{child_id} (x{cnum}), Range: {dmg_range}")
        print(f"      Precast: '{precast}' (Sẵn sàng: {pre_exist})")
        print(f"      Fly Anim: '{fly_anim}' (Sẵn sàng: {fly_exist})")
        print(f"      Hit Anim: '{hit_anim}' (Sẵn sàng: {hit_exist})")
        if fly_evt or fly_sk:
            print(f"      FlyEvent: {fly_evt} -> Skill {fly_sk}")
        if col_evt or col_sk:
            print(f"      CollideEvent: {col_evt} -> Skill {col_sk}")
    else:
        if vid > 0:
            print(f"    [VISUAL FX] CHƯA CÓ TRONG skills.json (vid: {vid})!")

    # Check Stat Lines (Synergy & Stats)
    synergies = [sl for sl in s["stat_lines"] if "liên kết" in sl["label"] or sl["target"]]
    other_stats = [sl for sl in s["stat_lines"] if sl not in synergies]
    if synergies:
        print(f"    [HỖ TRỢ LIÊN KẾT / SYNERGY] ({len(synergies)} nhánh):")
        for syn in synergies:
            tgt = syn["target"] if syn["target"] else "[CHƯA CÓ target_skill_id!]"
            print(f"      -> {syn['label']}: +{syn['v1']}% -> +{syn['vmax']}% (Target: {tgt})")
    print(f"    [THUỘC TÍNH NẠP / vltk_attribs] ({len(s['attribs'])} attrs): {', '.join(s['attribs'].keys())}")
