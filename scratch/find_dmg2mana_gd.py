import os

for root, dirs, files in os.walk('.'):
    if any(x in root for x in ['.git', '.godot', 'scratch', 'build']):
        continue
    for f in files:
        if f.endswith('.gd'):
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
                c = fp.read()
                if 'damage2addmana' in c or 'damage_to_mana' in c or 'currentdamage2mana' in c.lower():
                    print(f"Match in {p}")
                    for line_no, line in enumerate(c.splitlines(), 1):
                        if any(k in line.lower() for k in ['damage2addmana', 'damage_to_mana', 'currentdamage2mana']):
                            print(f"  {line_no}: {line.strip()}")
