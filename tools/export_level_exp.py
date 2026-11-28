"""Xuất mốc kinh nghiệm lên cấp nhân vật từ settings/npc/player/level_exp.txt gốc.

Dòng gốc: cột 1 = cấp n, cột 2 = kinh nghiệm cần để từ cấp n lên n+1 (KPlayer::LevelUp / PlayerSet.LevelExp).
Bản server anh-viet, bản patch và bản MiTom giống hệt nhau ở 2 cột này. Lấy nguyên số, không chia/nhân gì.

Ra: data/player/level_exp.json  [cấp 1, cấp 2, ..., cấp 200]
Chạy: python tools/export_level_exp.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "player" / "level_exp.json"
MAX_LEVEL = 200
SOURCE = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/npc/player/level_exp.txt")


def main() -> None:
    table = {}
    for line in SOURCE.read_bytes().decode("gbk", errors="replace").splitlines()[1:]:
        f = line.split("\t")
        if len(f) >= 2 and f[0].strip().isdigit() and f[1].strip().isdigit():
            table[int(f[0])] = int(f[1])
    missing = [lv for lv in range(1, MAX_LEVEL + 1) if lv not in table]
    if missing:
        raise SystemExit("thiếu cấp: %s" % missing)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as fp:
        json.dump([table[lv] for lv in range(1, MAX_LEVEL + 1)], fp)
        fp.write("\n")
    print("OK", OUT, "cấp 1 =", table[1], "cấp 161 =", table[161], "cấp 200 =", table[200])


if __name__ == "__main__":
    main()
