sf = r'D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\settings\Skills.txt'
with open(sf, 'rb') as f:
    for i in range(30):
        line = f.readline()
        try:
            text_gb = line.decode('gb18030', errors='replace')
            cols = text_gb.strip().split('\t')
            print(f"{i}: ID={cols[2] if len(cols)>2 else ''} | Name={cols[0]}")
        except Exception as e:
            print(e)
