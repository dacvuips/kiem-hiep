with open(r'E:\jx15_src\settings\npcres\状态图形对照表.txt', 'rb') as f:
    lines = f.read().decode('gbk', 'replace').splitlines()

for i, line in enumerate(lines):
    print(f"{i}: {line}")
