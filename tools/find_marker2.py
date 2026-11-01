with open('launcher/launcher.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, l in enumerate(lines):
    if 'BOOT_MARKER' in l and i > 50:
        for j in range(max(0, i-5), min(len(lines), i+20)):
            print(lines[j], end='')
