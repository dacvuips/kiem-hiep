with open(r'E:\jx15_src\settings\missles.txt', 'r', encoding='latin-1') as f:
    headers = f.readline().strip().split('\t')
    for line in f:
        p = line.strip().split('\t')
        if len(p) > 2 and p[0] in ['331', '359', '149', '150']:
            print(f'=== Missile {p[0]} ({p[1]}) ===')
            for col in ['DmgInterval', 'LifeTime', 'IsRangeDmg', 'DmgRange', 'CollidRange', 'AutoExplode']:
                idx = headers.index(col)
                print(f'  {col}: {p[idx]}')
