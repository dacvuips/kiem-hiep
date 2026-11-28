import os

for root, dirs, files in os.walk('.'):
    if any(x in root for x in ['.git', '.godot', 'scratch', 'build']):
        continue
    for f in files:
        if f.endswith('.gd'):
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
                c = fp.read()
                if 'trigger_auto_reply_skills' in c:
                    print(f"Match in {p}")
                    for line_no, line in enumerate(c.splitlines(), 1):
                        if 'trigger_auto_reply_skills' in line:
                            print(f"  {line_no}: {line.strip()}")
