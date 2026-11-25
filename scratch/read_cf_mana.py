with open('systems/combat/combat_formulas.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    if any(k in l for k in ['mana_absorbed', 'mana_shield', 'manashield', 'mana_absorb', 'toa_vong']):
        print(f"{i+1}: {l.strip()}")
