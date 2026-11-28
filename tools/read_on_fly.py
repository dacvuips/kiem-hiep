with open('systems/skill_fx/vltk_missile.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(275, 310):
    print(f'{i+1}: {lines[i]}', end='')
