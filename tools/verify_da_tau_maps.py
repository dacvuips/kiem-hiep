import sys, os, json, re
sys.stdout.reconfigure(encoding='utf-8')

cat = json.load(open('data/maps/map_catalog.json', encoding='utf-8'))
cat_by_id = {m['id']: m for m in cat['maps']}

with open('systems/quest/da_tau_data.gd', 'r', encoding='utf-8') as f:
    code = f.read()

godot_map_ids = set(int(x) for x in re.findall(r'"godot_map_id":\s*(\d+)', code))
print(f"Total unique godot_map_ids in FINDMAPS_DATA: {len(godot_map_ids)}")

missing_folders = []
missing_in_catalog = []
for mid in sorted(godot_map_ids):
    folder = f'world/maps/map_{mid}'
    if not os.path.isdir(folder):
        missing_folders.append(mid)
    if mid not in cat_by_id:
        missing_in_catalog.append(mid)

print("Missing folders in world/maps:", missing_folders)
print("Missing in catalog:", missing_in_catalog)
