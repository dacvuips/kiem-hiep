sf = r'D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\settings\Skills.txt'
with open(sf, 'rb') as f:
    for i in range(25):
        line = f.readline()
        if i in [10, 20, 21]:
            cols = line.strip().split(b'\t')
            print(f"Line {i}: {cols[0]}")
