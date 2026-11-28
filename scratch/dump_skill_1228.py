sf = r'D:\game\source_vo-lam-truyen-ky\VS2022\Server+Client-001\bin\client\settings\Skills.txt'

with open(sf, 'rb') as f:
    header = [h.decode('ascii', errors='ignore') for h in f.readline().strip().split(b'\t')]
    for line in f:
        cols = line.strip().split(b'\t')
        if len(cols) > 2 and cols[2].decode('ascii', errors='ignore') == '1228':
            print(f"Total columns: {len(cols)}")
            for idx, (col_name, val) in enumerate(zip(header, cols)):
                val_str = val.decode('gb18030', errors='replace')
                if val_str != '' and val_str != '-1' and val_str != '0':
                    print(f"[{idx}] {col_name}: {val_str}")
