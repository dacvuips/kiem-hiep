import os

cpp_root = r'D:\game\source_vo-lam-truyen-ky\VS2022\Source-VS2022-20260926T022613Z-1-002\Source-VS2022'

matches = []
for root, dirs, files in os.walk(cpp_root):
    for f in files:
        if f.endswith(('.cpp', '.h', '.lua')):
            p = os.path.join(root, f)
            try:
                with open(p, 'r', encoding='gb18030', errors='ignore') as fp:
                    content = fp.read()
                    if 'autoreplyskill' in content or 'damage2addmana_p' in content or '1228' in content:
                        for line_no, line in enumerate(content.splitlines(), 1):
                            if any(k in line for k in ['autoreplyskill', 'damage2addmana_p']):
                                print(f"{f}:{line_no}: {line.strip()}")
            except Exception as e:
                pass
