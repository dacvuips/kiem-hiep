import os

spr_set = set()
for root, dirs, files in os.walk(r'E:\jx15_src'):
    for f in files:
        if f.endswith(('.txt', '.ini', '.lua', '.tab')):
            p = os.path.join(root, f)
            try:
                with open(p, 'r', encoding='gbk', errors='ignore') as fp:
                    for line in fp:
                        if '.spr' in line.lower():
                            for part in line.split():
                                if '.spr' in part.lower():
                                    spr_set.add(part.strip(';,\\\'"'))
            except:
                pass

print('Found spr count in E:\\jx15_src:', len(spr_set))
with open('scratch/found_spr_list.txt', 'w', encoding='utf-8') as out:
    for s in sorted(spr_set):
        out.write(s + '\n')
