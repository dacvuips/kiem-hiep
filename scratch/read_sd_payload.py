with open('systems/sect/skill_definition.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    if 'get_state_payload' in l or 'chan_vo' in l:
        for j in range(max(0, i-2), min(len(lines), i+30)):
            print(f"{j+1}: {lines[j]}", end='')
        print('='*40)
