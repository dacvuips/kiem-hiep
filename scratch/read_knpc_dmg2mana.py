import os

cpp_root = r'D:\game\source_vo-lam-truyen-ky\VS2022\Source-VS2022-20260926T022613Z-1-002\Source-VS2022'
p = None
for root, dirs, files in os.walk(cpp_root):
    if 'KNpc.cpp' in files:
        p = os.path.join(root, 'KNpc.cpp')
        break

if p:
    print("Found KNpc.cpp at:", p)
    with open(p, 'r', encoding='gb18030', errors='ignore') as f:
        lines = f.readlines()
    for i in range(2695, 2725):
        print(f"{i+1}: {lines[i]}", end='')
