import sys, json, os
sys.stdout.reconfigure(encoding='utf-8')

CATALOG = r"data/maps/map_catalog.json"
cat = json.load(open(CATALOG, encoding='utf-8'))
maps = cat.get('maps', [])

# Map groups and their rates
LL1_2_MAPS = {11, 20, 37, 53, 54, 70, 121, 162, 176}
LL3_5_MAPS = {2, 8, 21, 41, 70, 90, 92, 122, 140}
LL6_10_MAPS = {9, 24, 38, 39, 40, 42, 55, 56, 66, 72, 76, 79, 94, 114, 116, 117, 118, 119, 120, 123, 132, 142, 163, 164, 165, 166, 169, 182, 194, 196, 206, 319}
LL11_20_MAPS = {10, 75, 93, 124, 143, 144, 181, 198, 199, 200, 201, 202, 203, 204, 205, 207, 224, 225, 226, 227, 320, 321, 322}

updated = 0
for m in maps:
    mid = m.get('id')
    if mid in LL1_2_MAPS:
        m['drop_diadochi_rate'] = 0.04
        m['drop_matchi_rate'] = 0.008
        updated += 1
    elif mid in LL3_5_MAPS:
        m['drop_diadochi_rate'] = 0.06
        m['drop_matchi_rate'] = 0.012
        updated += 1
    elif mid in LL6_10_MAPS:
        m['drop_diadochi_rate'] = 0.07
        m['drop_matchi_rate'] = 0.014
        updated += 1
    elif mid in LL11_20_MAPS:
        m['drop_diadochi_rate'] = 0.085
        m['drop_matchi_rate'] = 0.017
        updated += 1

with open(CATALOG, 'w', encoding='utf-8') as f:
    json.dump(cat, f, ensure_ascii=False, indent=2)

print(f"Updated drop rates for {updated} maps in {CATALOG}")
