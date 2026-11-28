import os

for root, dirs, files in os.walk('tools'):
    for f in files:
        if f.endswith('.py'):
            with open(os.path.join(root, f), 'r', encoding='utf-8', errors='ignore') as fp:
                for line in fp:
                    if 'fx_%' in line or 'fx_{' in line or 'fx_' in line:
                        print(f, line.strip())
                        break
