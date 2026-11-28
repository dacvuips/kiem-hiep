import os

for root, dirs, files in os.walk('.'):
    if any(x in root for x in ['.git', '.godot', 'scratch', 'build']):
        continue
    for f in files:
        if f.endswith('.gd'):
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
                c = fp.read()
                if 'chan_vo_that_tiet' in c.lower() or 'damage2addmana' in c or 'autoreplyskill' in c:
                    print(f"Match in {p}")
