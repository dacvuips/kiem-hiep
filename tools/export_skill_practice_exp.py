"""Xuất bảng độ thành thạo kỹ năng luyện (90/120/150) từ settings/npc/player/magic_level_exp.txt gốc.

Mỗi dòng gốc: MAGICID, MAGICNAME, FACTIONID, LEVEL1..LEVELn = độ thành thạo cần để từ cấp n lên n+1
(KMagicLevelExp::GetNextExp). Lấy bản server 15 phái trước, thiếu thì bổ sung từ bản VNG.

Ra: data/skill_practice/magic_level_exp.json  {"<SkillId gốc>": [LEVEL1..LEVEL20]}
Chạy: python tools/export_skill_practice_exp.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "skill_practice" / "magic_level_exp.json"
MAX_TRAIN_LEVEL = 20  # MAX_TRAIN_SKILLEXPLEVEL (SkillDef.h)

SOURCES = [
    Path(r"E:/jx15_src/settings/npc/player/magic_level_exp.txt"),
    Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/npc/player/magic_level_exp.txt"),
]


def read_table(path: Path) -> dict:
    out = {}
    lines = path.read_bytes().decode("gbk", errors="replace").splitlines()
    head = lines[0].split("\t")
    cols = [head.index("LEVEL%d" % i) for i in range(1, MAX_TRAIN_LEVEL + 1)]
    for line in lines[1:]:
        f = line.split("\t")
        if not f or not f[0].strip().isdigit():
            continue
        vals = []
        for c in cols:
            v = f[c].strip() if c < len(f) else ""
            vals.append(int(v) if v.lstrip("-").isdigit() else 0)
        out[f[0].strip()] = vals
    return out


def main() -> int:
    table = {}
    for src in SOURCES:
        if not src.exists():
            print("bỏ qua (không có):", src)
            continue
        for k, v in read_table(src).items():
            table.setdefault(k, v)
        print("đọc", src)
    if not table:
        print("Không tìm thấy magic_level_exp.txt nào")
        return 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    keys = sorted(table, key=int)
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("{\n")
        fh.write(",\n".join('  "%s": %s' % (k, json.dumps(table[k])) for k in keys))
        fh.write("\n}\n")
    print("ghi", OUT, len(keys), "kỹ năng")
    return 0


if __name__ == "__main__":
    sys.exit(main())
