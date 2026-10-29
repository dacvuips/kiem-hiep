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

# Parse nga_mi.tres
tres_path = ROOT / "systems" / "sect" / "data" / "nga_mi.tres"
tres_content = tres_path.read_text(encoding="utf-8")

subresources = {}
for m in re.finditer(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\[sub_resource|\n\[resource|\Z)', tres_content, re.DOTALL):
    subresources[m.group(1)] = m.group(2)

print("="*100)
print("CHI TIẾT TỪNG SKILL TRONG nga_mi.tres:")
print("="*100)

for sub_id, body in subresources.items():
    if 'script = ExtResource("2_skill")' in body:
        sid = re.search(r'id = "([^"]+)"', body).group(1)
        name = re.search(r'skill_name = "([^"]+)"', body).group(1)
        v_id_m = re.search(r'vltk_skill_id = (\d+)', body)
        v_id = int(v_id_m.group(1)) if v_id_m else 0
        req_m = re.search(r'req_level = (\d+)', body)
        req = int(req_m.group(1)) if req_m else 0
        max_l_m = re.search(r'max_level = (\d+)', body)
        max_l = int(max_l_m.group(1)) if max_l_m else 20
        school_m = re.search(r'school_text = "([^"]+)"', body)
        school = school_m.group(1) if school_m else ""
        cat_m = re.search(r'category = (\d+)', body)
        cat = int(cat_m.group(1)) if cat_m else 0
        wp_m = re.search(r'weapon_limit = ([\d\-]+)', body)
        wp = int(wp_m.group(1)) if wp_m else -2
        hs_m = re.search(r'horse_limit = ([\d\-]+)', body)
        hs = int(hs_m.group(1)) if hs_m else 0
        aura_m = re.search(r'is_aura = (true|false)', body)
        aura = aura_m.group(1) == "true" if aura_m else False
        hidden_m = re.search(r'is_hidden = (true|false)', body)
        hidden = hidden_m.group(1) == "true" if hidden_m else False
        
        stat_line_ids = re.findall(r'SubResource\("([^"]+)"\)', body)
        
        print(f"\nSKILL: [{sid}] | Tên: {name} | VLTK ID: {v_id} | Req: {req} | Max: {max_l} | Nhánh: {school} | Hidden: {hidden}")
        print(f"       Category: {cat} | Weapon: {wp} | Horse: {hs} | Aura: {aura}")
        
        # Check matching VLTK data
        if v_id in skills_by_id:
            vd = skills_by_id[v_id]
            print(f"       -> [VLTK GỐC] Tên: {vd['SkillName']} | ReqL: {vd['ReqLevel']} | MaxL: {vd['MaxLevel']} | Eqt: {vd['EqtLimit']} | Horse: {vd['HorseLimit']} | Aura: {vd['IsAura']} | Style: {vd['SkillStyle']} | Anim: {vd['CharAnimId']} | Radius: {vd['AttackRadius']}")
            # Liệt kê các thuộc tính có trong Skills.txt (L1, L20)
            l1_attribs = []
            l20_attribs = []
            for k in range(1, 11):
                pk = f"Param{k}Data"
                if pk in vd and vd[pk]:
                    val = vd[pk]
                    if val != "0" and val != "":
                        l1_attribs.append(f"P{k}:{vd.get(f'Param{k}Style','')}:{val}")
            if l1_attribs:
                print(f"          Params: {', '.join(l1_attribs[:5])}")
        else:
            print(f"       -> [VLTK GỐC] KHÔNG TÌM THẤY VLTK ID {v_id}!")
            
        # Print stat lines
        for slid in stat_line_ids:
            if slid in subresources:
                sbody = subresources[slid]
                lbl_m = re.search(r'label = "([^"]+)"', sbody)
                v1_m = re.search(r'value_at_level_1 = ([\d\.\-]+)', sbody)
                vmax_m = re.search(r'value_at_max_level = ([\d\.\-]+)', sbody)
                suf_m = re.search(r'suffix = "([^"]+)"', sbody)
                tgt_m = re.search(r'target_skill_id = "([^"]+)"', sbody)
                
                lbl = lbl_m.group(1) if lbl_m else ""
                v1 = v1_m.group(1) if v1_m else ""
                vmax = vmax_m.group(1) if vmax_m else ""
                suf = suf_m.group(1) if suf_m else ""
                tgt = tgt_m.group(1) if tgt_m else ""
                tgt_str = f" -> Target: [{tgt}]" if tgt else ""
                print(f"          * {lbl}: {v1} -> {vmax} {suf}{tgt_str}")
