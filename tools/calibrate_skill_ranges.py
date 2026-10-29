"""Căn chỉnh phạm vi đánh skill, vùng ảnh hưởng đạn nổ và cơ chế buff cho 15 phái theo đúng source gốc VLTK.
"""
import os
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

# Read skills
skills_file = r'E:\jx15_skills_utf8.txt'
with open(skills_file, 'r', encoding='utf-8') as f:
    headers = f.readline().strip().split('\t')
    hmap = {h: i for i, h in enumerate(headers)}
    skills = {}
    for line in f:
        row = line.rstrip('\r\n').split('\t')
        if len(row) > hmap['SkillId']:
            sid = row[hmap['SkillId']].strip()
            if sid.isdigit():
                skills[int(sid)] = {k: row[v].strip() if v < len(row) else '' for k, v in hmap.items()}

# Read missiles
missiles_file = r'E:\jx15_src\settings\missles.txt'
with open(missiles_file, 'rb') as f:
    mheaders = f.readline().decode('gbk', 'replace').strip().split('\t')
    mhmap = {h: i for i, h in enumerate(mheaders)}
    missiles = {}
    for line in f:
        row = line.decode('gbk', 'replace').rstrip('\r\n').split('\t')
        if len(row) > mhmap['MissleId']:
            mid = row[mhmap['MissleId']].strip()
            if mid.isdigit():
                missiles[int(mid)] = {k: row[v].strip() if v < len(row) else '' for k, v in mhmap.items()}

print(f"Loaded {len(skills)} skills, {len(missiles)} missiles.")

def to_int(v, d=0):
    try:
        return int(v)
    except:
        return d

def get_skill_missile(s):
    base_skill = to_int(s.get('BaseSkill', 0))
    child_id = to_int(s.get('ChildSkillId', 0))
    style = to_int(s.get('SkillStyle', 0))
    is_aura = to_int(s.get('IsAura', 0))
    
    # Direct missile
    if child_id in missiles and (base_skill == 1 or style == 0):
        return missiles[child_id]
        
    # Aura or sub-skill leading to missile
    if child_id in skills:
        cs = skills[child_id]
        c_child_id = to_int(cs.get('ChildSkillId', 0))
        if c_child_id in missiles:
            return missiles[c_child_id]
            
    # Check start skill or collide skill
    start_skill = to_int(s.get('StartSkillId', 0))
    if start_skill in skills:
        ss = skills[start_skill]
        s_child = to_int(ss.get('ChildSkillId', 0))
        if s_child in missiles:
            return missiles[s_child]
            
    return None

def set_field(block: str, name: str, val: str) -> str:
    pattern = rf"^{name} = .*\n"
    if re.search(pattern, block, re.M):
        return re.sub(pattern, f"{name} = {val}\n", block, flags=re.M)
    else:
        for anchor_name in ["vltk_state_special_id", "vltk_attack_radius", "vltk_missle_form", "is_aura", "target_self", "max_level", "skill_name"]:
            anchor = re.search(rf"^{anchor_name} = .*\n", block, re.M)
            if anchor:
                pos = anchor.end()
                return block[:pos] + f"{name} = {val}\n" + block[pos:]
        return block + f"{name} = {val}\n"

tres_dir = Path(r'D:\game\lam-game\kiem-hiep\systems\sect\data')
updated_sects = 0
total_skills_updated = 0

for tres_path in sorted(tres_dir.glob('*.tres')):
    sect_name = tres_path.stem
    text = tres_path.read_text(encoding='utf-8')
    blocks = re.split(r'(?=\n\[sub_resource)', text)
    
    sect_changed = False
    for bi, block in enumerate(blocks):
        id_m = re.search(r'^vltk_skill_id = (\d+)', block, re.M)
        if not id_m:
            continue
        sid = int(id_m.group(1))
        if sid not in skills:
            continue
            
        s = skills[sid]
        
        # Source target values
        src_att_rad = to_int(s.get('AttackRadius', 0))
        src_form = to_int(s.get('MisslesForm', -1))
        src_enemy = s.get('TargetEnemy', '0') == '1'
        src_ally = s.get('TargetAlly', '0') == '1'
        src_self = s.get('TargetSelf', '0') == '1'
        src_aura = s.get('IsAura', '0') == '1'
        
        m = get_skill_missile(s)
        src_dmg_range = to_int(m.get('DmgRange', 0)) if m else 0
        src_range_dmg = to_int(m.get('IsRangeDmg', 0)) if m else 0
        src_hit_friend = to_int(m.get('CanColFriend', 0)) if m else 0
        
        # Check current values
        cur_att_m = re.search(r'^vltk_attack_radius = (\d+)', block, re.M)
        cur_att = int(cur_att_m.group(1)) if cur_att_m else 0
        cur_dmg_m = re.search(r'^vltk_damage_range = (\d+)', block, re.M)
        cur_dmg = int(cur_dmg_m.group(1)) if cur_dmg_m else 0
        cur_rng_m = re.search(r'^vltk_range_damage = (\d+)', block, re.M)
        cur_rng = int(cur_rng_m.group(1)) if cur_rng_m else 0
        cur_form_m = re.search(r'^vltk_missle_form = (-?\d+)', block, re.M)
        cur_form = int(cur_form_m.group(1)) if cur_form_m else -1
        cur_hit_m = re.search(r'^vltk_hit_friend = (\d+)', block, re.M)
        cur_hit = int(cur_hit_m.group(1)) if cur_hit_m else 0
        
        # Check if change is needed
        needs_update = False
        if cur_att != src_att_rad:
            needs_update = True
        if cur_dmg != src_dmg_range:
            needs_update = True
        if cur_rng != src_range_dmg:
            needs_update = True
        if cur_form != src_form and src_form != -1:
            needs_update = True
        if cur_hit != src_hit_friend:
            needs_update = True
            
        if needs_update:
            new_block = block
            new_block = set_field(new_block, "target_enemy", "true" if src_enemy else "false")
            new_block = set_field(new_block, "target_ally", "true" if src_ally else "false")
            new_block = set_field(new_block, "target_self", "true" if src_self else "false")
            new_block = set_field(new_block, "is_aura", "true" if src_aura else "false")
            if src_form != -1:
                new_block = set_field(new_block, "vltk_missle_form", str(src_form))
            new_block = set_field(new_block, "vltk_attack_radius", str(src_att_rad))
            new_block = set_field(new_block, "vltk_damage_range", str(src_dmg_range))
            new_block = set_field(new_block, "vltk_range_damage", str(src_range_dmg))
            new_block = set_field(new_block, "vltk_hit_friend", str(src_hit_friend))
            
            blocks[bi] = new_block
            sect_changed = True
            total_skills_updated += 1
            print(f"[{sect_name}] Updated Skill ID {sid:4d} ({s.get('SkillName', '')}): "
                  f"AttRad={src_att_rad}, Form={src_form}, DmgRange={src_dmg_range}, RangeDmg={src_range_dmg}, HitFriend={src_hit_friend}")
            
    if sect_changed:
        tres_path.write_text("".join(blocks), encoding='utf-8', newline='\n')
        updated_sects += 1

print(f"\nSUCCESS: Updated {total_skills_updated} skills across {updated_sects} sect files.")
