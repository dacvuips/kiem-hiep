import os

skill_files = [
    r'D:\game\source_vo-lam-truyen-ky\anh-viet\JXWin Anh Việt-20260926T075907Z-1-002\JXWin Anh Việt\Client anhviet pas 123456\Client123456\settings\Skills.txt',
    r'D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\settings\Skills.txt',
    r'D:\game\source_vo-lam-truyen-ky\VS2022\Server+Client-001\bin\client\settings\Skills.txt'
]

for sf in skill_files:
    if not os.path.exists(sf):
        continue
    print("=== File:", sf)
    with open(sf, 'r', encoding='gb18030', errors='ignore') as f:
        header = f.readline().strip().split('\t')
        id_idx = header.index('SkillId') if 'SkillId' in header else 2
        name_idx = header.index('SkillName') if 'SkillName' in header else 0
        desc_idx = header.index('SkillDesc') if 'SkillDesc' in header else -1
        print(f"Header: name_idx={name_idx}, id_idx={id_idx}, desc_idx={desc_idx}")
        
        for line_no, line in enumerate(f, 2):
            cols = line.strip().split('\t')
            name = cols[name_idx] if len(cols) > name_idx else ''
            sid = cols[id_idx] if len(cols) > id_idx else ''
            
            # search keywords
            keywords = ['Chân Võ', 'Thất Tiết', 'Thất tiết', 'Chân vũ', 'Chân Vũ', 'Võ Đang', 'Vo Dang', 'that tiet', 'That Tiet', 'zhenwu', 'ZhenWu', '真武', '七截']
            if any(k in line for k in keywords):
                print(f"Line {line_no}: ID={sid}, Name={name}")
