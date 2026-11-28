sf = r'D:\game\source_vo-lam-truyen-ky\VS2022\Server+Client-001\bin\client\settings\Skills.txt'

with open(sf, 'rb') as f:
    header = [h.decode('ascii', errors='ignore') for h in f.readline().strip().split(b'\t')]
    for line in f:
        cols = line.strip().split(b'\t')
        if len(cols) > 2 and cols[2].decode('ascii', errors='ignore') in ['1228', '1238']:
            sid = cols[2].decode('ascii', errors='ignore')
            print(f"=== Skill ID: {sid} ===")
            for idx, (col_name, val) in enumerate(zip(header, cols)):
                val_str = val.decode('gb18030', errors='replace')
                if any(k in col_name.lower() for k in ['spr', 'anim', 'sound', 'snd', 'state', 'special', 'msls', 'missle', 'form', 'child', 'icon']):
                    print(f"  {col_name} ({idx}): {val_str}")
