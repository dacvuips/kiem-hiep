path = r'D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\script\skill\advancedskill.lua'
with open(path, 'r', encoding='gb18030', errors='ignore') as f:
    lines = f.readlines()

in_wd = False
for i, line in enumerate(lines):
    if 'wd_adskill' in line:
        in_wd = True
        print(f"--- Line {i+1} ---")
    if in_wd:
        print(line, end='')
        if line.strip().startswith('end') and 'function' not in line:
            # check if it closes the block
            pass
