import os

cpp_root = r'D:\game\source_vo-lam-truyen-ky\VS2022\Source-VS2022-20260926T022613Z-1-002\Source-VS2022'
p = os.path.join(cpp_root, 'Core', 'Src', 'KNpc.cpp')
if not os.path.exists(p):
    # search KNpc.cpp
    for root, dirs, files in os.walk(cpp_root):
        if 'KNpc.cpp' in files:
            p = os.path.join(root, 'KNpc.cpp')
            break

with open(p, 'r', encoding='gb18030', errors='ignore') as f:
    lines = f.readlines()

for i in range(2730, 2765):
    if i < len(lines):
        print(f"{i+1}: {lines[i]}", end='')
