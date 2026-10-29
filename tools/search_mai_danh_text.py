import sys
import os
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

def search_text_in_dir(dir_path, keywords):
    p = Path(dir_path)
    if not p.exists(): return
    for root, dirs, files in os.walk(p):
        for f in files:
            if f.endswith(('.lua', '.txt', '.ini', '.tab')):
                fp = Path(root) / f
                try:
                    raw = fp.read_bytes()
                    # try utf-8, latin-1, cp1258
                    for enc in ['utf-8', 'latin-1', 'cp1258']:
                        try:
                            txt = raw.decode(enc)
                            for kw in keywords:
                                if kw in txt.lower():
                                    print(f"[{kw}] in {fp}")
                                    # print matching line
                                    for l in txt.splitlines():
                                        if kw in l.lower():
                                            print("   ", l.strip()[:100])
                                    break
                            break
                        except Exception:
                            pass
                except Exception:
                    pass

search_text_in_dir(r"E:/jx15_src", ["mai danh", "ẩn tính", "ẩn tích", "maidanh"])
search_text_in_dir(r"D:/game/lam-game/kiem-hiep", ["mai danh", "ẩn tính", "ẩn tích", "maidanh"])
