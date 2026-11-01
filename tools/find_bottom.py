with open('launcher/launcher.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for l in lines[-80:]:
    print(l, end='')
