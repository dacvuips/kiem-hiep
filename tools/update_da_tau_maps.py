import json
import os
import gzip
import sys

sys.stdout.reconfigure(encoding='utf-8')

CATALOG_PATH = r'd:\game\lam-game\kiem-hiep\data\maps\map_catalog.json'
MAPS_DIR = r'd:\game\lam-game\kiem-hiep\world\maps'

with open(CATALOG_PATH, 'r', encoding='utf-8') as f:
    cat = json.load(f)

def get_rates(level):
    if level < 20:
        return 0.04, 0.008
    elif level < 50:
        return 0.06, 0.012
    elif level < 75:
        return 0.07, 0.014
    elif level < 95:
        return 0.08, 0.016
    else:
        return 0.09, 0.018

# Cập nhật drop rates cho các map hiện có
for m in cat['maps']:
    lvl = m.get('level', 50)
    dd_rate, mc_rate = get_rates(lvl)
    m['drop_diadochi_rate'] = dd_rate
    m['drop_matchi_rate'] = mc_rate

new_maps_info = {
    8: {'name': 'Tần Lăng tầng 1', 'kind': 'Cave', 'level': 60},
    144: {'name': 'Dược Vương Động tầng 4', 'kind': 'Cave', 'level': 90},
    164: {'name': 'Thiên Tâm tháp tầng 1', 'kind': 'Cave', 'level': 70},
    165: {'name': 'Thiên Tâm tháp tầng 2', 'kind': 'Cave', 'level': 70},
    166: {'name': 'Thiên Tâm tháp tầng 3', 'kind': 'Cave', 'level': 75},
    206: {'name': 'Tần Lăng tầng 2', 'kind': 'Cave', 'level': 80},
    207: {'name': 'Tần Lăng tầng 3', 'kind': 'Cave', 'level': 85},
}

cat_ids = {m['id'] for m in cat['maps']}

for mid, info in new_maps_info.items():
    if mid in cat_ids:
        continue
    folder = os.path.join(MAPS_DIR, f'map_{mid}')
    if not os.path.isdir(folder):
        continue
    
    spawns_path = os.path.join(folder, 'spawns.json.gz')
    monsters = []
    npc_count = 0
    if os.path.exists(spawns_path):
        with gzip.open(spawns_path, 'rt', encoding='utf-8') as gz:
            sp_data = json.load(gz)
            npc_count = len(sp_data) if isinstance(sp_data, list) else 0
            m_counts = {}
            for sp in (sp_data if isinstance(sp_data, list) else []):
                t = sp.get('t', 0)
                name = sp.get('name', 'Quái')
                lvl = sp.get('level', info['level'])
                key = (t, name, lvl)
                m_counts[key] = m_counts.get(key, 0) + 1
            for (t, name, lvl), cnt in m_counts.items():
                monsters.append({'t': t, 'name': name, 'level': lvl, 'count': cnt})
    
    dd_rate, mc_rate = get_rates(info['level'])
    entry = {
        'id': mid,
        'name': info['name'],
        'kind': info['kind'],
        'level': info['level'],
        'monster_count': npc_count,
        'monsters': monsters,
        'dir': f'res://world/maps/map_{mid}',
        'folder': f'res://world/maps/map_{mid}',
        'drop_diadochi_rate': dd_rate,
        'drop_matchi_rate': mc_rate,
    }
    cat['maps'].append(entry)
    print(f"Added map_{mid}: {info['name']} (monsters: {npc_count})")

with open(CATALOG_PATH, 'w', encoding='utf-8') as f:
    json.dump(cat, f, ensure_ascii=False, indent=2)

print('Updated map_catalog.json successfully!')
