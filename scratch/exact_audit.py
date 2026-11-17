import json
from collections import defaultdict

with open('data/monsters/monsters.json', 'r', encoding='utf-8') as f:
    monsters_data = json.load(f)

with open('data/monsters/npc_levels.json', 'r', encoding='utf-8') as f:
    nl = json.load(f)

npcs = nl.get('npcs', {})
pool = nl.get('pool', [])

with open('data/maps/map_catalog.json', 'r', encoding='utf-8') as f:
    cat = json.load(f)

def level_table(mid, series=0):
    per = npcs.get(str(mid), {}).get(str(series), {})
    out = {}
    for field, idx in per.items():
        out[field] = pool[int(idx)]
    return out

def level_value(table, key, level):
    vals = table.get(key, [])
    if not vals:
        return -1
    idx = max(0, min(level - 1, len(vals) - 1))
    return vals[idx]

def stat_at_level(m_dict, stat, level):
    table = m_dict.get('level_table', {})
    LEVEL_KEYS = {'life': 'Life', 'exp': 'Exp', 'attack_rating': 'AttackRating', 'defense': 'Defense',
                  'min_damage': 'MinDamage', 'max_damage': 'MaxDamage'}
    if table and stat in LEVEL_KEYS:
        v = level_value(table, LEVEL_KEYS[stat], level)
        if v >= 0:
            return v
    s = m_dict.get('stats', {})
    if stat not in s:
        return -1
    p = s[stat]
    lv = float(max(1, level))
    val = p[1]*lv*lv + p[2]*lv + p[3]
    return int(val * p[0] / 100.0)

def get_monster_exp(tid, level, series=0):
    raw_m = monsters_data.get(str(tid), {})
    m = dict(raw_m)
    lt = level_table(tid, series)
    if lt:
        m['level_table'] = lt
    return stat_at_level(m, 'exp', level)

def self_exp(player_level, target_level, exp):
    if exp <= 0:
        return 0
    diff = abs(player_level - target_level)
    got = 0
    if player_level >= target_level and target_level >= 100:
        got = exp - exp * diff // 200
    elif diff <= 5:
        got = exp
    elif diff <= 15:
        got = exp * (295 - 19 * diff) // 200
    else:
        got = 1
    return max(1, got)

# Check all maps
issues = []
all_map_reports = []

for m in cat['maps']:
    mid = m.get('id')
    mname = m.get('name')
    mlevel = m.get('level', 0)
    mons = m.get('monsters', [])
    m_rep = {'id': mid, 'name': mname, 'level': mlevel, 'mons': []}
    for mon in mons:
        tid = mon.get('t', 0)
        tname = mon.get('name', '')
        tlv = mon.get('level', mlevel)
        tcount = mon.get('count', 0)
        base_exp = get_monster_exp(tid, tlv)
        
        # Test exp for level-matched player (tlv) and player level 153
        exp_matched = self_exp(tlv, tlv, base_exp)
        exp_at_153 = self_exp(153, tlv, base_exp)
        
        mon_info = {
            'tid': tid, 'name': tname, 'level': tlv, 'count': tcount,
            'base_exp': base_exp, 'exp_matched': exp_matched, 'exp_at_153': exp_at_153
        }
        m_rep['mons'].append(mon_info)
        
        if base_exp <= 1:
            issues.append(f"Map {mid} ({mname}) quái '{tname}' (ID {tid}, Lv {tlv}): base_exp = {base_exp} <= 1!")
            
    all_map_reports.append(m_rep)

print(f"Total issues found: {len(issues)}")
for iss in issues:
    print("  ISSUE:", iss)

with open('scratch/detailed_exp_report.json', 'w', encoding='utf-8') as f:
    json.dump(all_map_reports, f, ensure_ascii=False, indent=2)

print("Report saved to scratch/detailed_exp_report.json")
