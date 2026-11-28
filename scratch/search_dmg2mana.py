import os

cpp_root = r'D:\game\source_vo-lam-truyen-ky\VS2022\Source-VS2022-20260926T022613Z-1-002\Source-VS2022'

for root, dirs, files in os.walk(cpp_root):
    for f in files:
        if f.endswith(('.cpp', '.h')):
            p = os.path.join(root, f)
            with open(p, 'r', encoding='gb18030', errors='ignore') as fp:
                for line_no, line in enumerate(fp, 1):
                    if 'm_CurrentDamage2Mana' in line:
                        print(f"{f}:{line_no}: {line.strip()}")
