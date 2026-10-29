import sys
import re
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent

for fn in ['hoa_son.tres', 'minh_giao.tres', 'tieu_dao.tres', 'duong_gia.tres', 'vu_hon.tres']:
    p = ROOT / 'systems' / 'sect' / 'data' / fn
    txt = p.read_text(encoding='utf-8')
    reqs = re.findall(r'req_level = (\d+)', txt)
    skills_180 = [m for m in re.finditer(r'skill_name = "([^"]+)"[\s\S]*?req_level = (\d+)', txt) if m.group(2) == '180']
    print(f"{fn:16s}: max_req={max([int(x) for x in reqs]) if reqs else 0} | 180 skills={[m.group(1) for m in skills_180]}")
