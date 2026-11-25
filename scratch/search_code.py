import os

src_dir = r"D:\game\source_vo-lam-truyen-ky\VS2022\Source-VS2022-20260926T022613Z-1-002\Source-VS2022"
for root, dirs, files in os.walk(src_dir):
    for f in files:
        if f.endswith((".cpp", ".h")):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="gbk", errors="ignore") as fp:
                for idx, line in enumerate(fp):
                    lower = line.lower()
                    if '"special"' in lower:
                        print(f"{filepath}:{idx+1}: {line.strip()}")
