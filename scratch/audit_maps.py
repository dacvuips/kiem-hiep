import json
from collections import defaultdict

with open('data/maps/map_catalog.json', 'r', encoding='utf-8') as f:
    cat = json.load(f)

with open('data/monsters/npc_levels.json', 'r', encoding='utf-8') as f:
    nl = json.load(f)

npcs = nl.get('npcs', {})
pool = nl.get('pool', [])

with open('data/monsters/monsters.json', 'r', encoding='utf-8') as f:
    monsters_data = json.load(f)

def get_base_exp(mid, mlv, series=0):
    per = npcs.get(str(mid), {}).get(str(series), {})
    if 'Exp' in per:
        vals = pool[per['Exp']]
        idx = max(0, min(mlv - 1, len(vals) - 1))
        return vals[idx]
    m = monsters_data.get(str(mid), {})
    s = m.get('stats', {})
    if 'exp' in s:
        p = s['exp']
        lv = float(mlv)
        val = p[1]*lv*lv + p[2]*lv + p[3]
        return int(val * p[0] / 100.0)
    return m.get('exp', 0)

print(f"Total maps in catalog: {len(cat['maps'])}")
by_lvl = defaultdict(list)

for m in cat['maps']:
    mid = m.get('id')
    mname = m.get('name')
    mlevel = m.get('level', 0)
    mons = m.get('monsters', [])
    m_info = {'id': mid, 'name': mname, 'level': mlevel, 'monsters': []}
    for mon in mons:
        tid = mon.get('t', 0)
        tname = mon.get('name', '')
        tlv = mon.get('level', mlevel)
        base_exp = get_base_exp(tid, tlv)
        m_info['monsters'].append({
            'tid': tid,
            'name': tname,
            'level': tlv,
            'base_exp': base_exp,
            'count': mon.get('count', 0)
        })
    by_lvl[mlevel].append(m_info)

with open('scratch/audit_maps_exp.txt', 'w', encoding='utf-8') as out:
    for lvl in sorted(by_lvl.keys()):
        maps = by_lvl[lvl]
        out.write(f"\n==================== CẤP {lvl} ({len(maps)} maps) ====================\n")
        for m in maps:
            if not m['monsters']:
                out.write(f"[{m['id']:4d}] {m['name']:<32} | KHÔNG CÓ QUÁI\n")
                continue
            mon_strs = []
            for mon in m['monsters']:
                mon_strs.append(f"{mon['name']} (Lv{mon['level']}: {mon['base_exp']} exp)")
            out.write(f"[{m['id']:4d}] {m['name']:<32} | {', '.join(mon_strs)}\n")

print("Audit written to scratch/audit_maps_exp.txt")
