import os

for root, dirs, files in os.walk('.'):
    # skip .git, .godot
    if '.git' in root or '.godot' in root or 'scratch' in root:
        continue
    for f in files:
        if f.endswith(('.gd', '.tscn', '.json', '.tres')):
            p = os.path.join(root, f)
            try:
                with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
                    content = fp.read()
                    if '1228' in content or 'Chân Võ Thất Tiết' in content or 'Chan Vo' in content:
                        print(f"Found in {p}")
            except:
                pass
