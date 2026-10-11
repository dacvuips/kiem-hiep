"""Tạo ảnh thu nhỏ (tối đa 96px) cho từng bộ hình quái: frame đầu của động tác đứng, quay xuống (hướng 0).

    python tools/make_monster_thumbs.py

Đọc data/monsters/resources.json + anims.json + assets/monster/*.png (do import_vltk_monsters.py xuất) -> assets/monster_thumbs/<bộ hình>.png
(PNG RGBA nhỏ vài KB, importer "keep" — game tự đọc, dùng cho lưới danh sách quái ở popup thử quái).
"""
import json
import os
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from import_vltk_avatar import write_keep_import  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data/monsters"
SHEETS = ROOT / "assets/monster"
OUT = ROOT / "assets/monster_thumbs"
SIZE = 96
ORDER = ["fight_stand", "stand1", "stand2", "fight_walk", "walk", "hurt", "fight_run", "run"]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    resources = json.loads((DATA / "resources.json").read_text(encoding="utf-8"))
    anims = json.loads((DATA / "anims.json").read_text(encoding="utf-8"))
    made = 0
    for res, acts in resources.items():
        act = next((acts[a] for a in ORDER if a in acts), None)
        if not act:
            continue
        key = act["anim"]
        meta = anims.get(key)
        sheet_path = SHEETS / (key + ".png")
        if not meta or not sheet_path.exists():
            continue
        w, h = meta["size"]
        cols = meta["cols"]
        sheet = Image.open(sheet_path).convert("RGBA")
        frame = sheet.crop((0, 0, w, h))  # frame 0, hướng 0 (xuống)
        box = frame.getbbox()
        if not box:
            continue
        frame = frame.crop(box)
        scale = min(SIZE / frame.width, SIZE / frame.height, 1.0)
        if scale < 1.0:
            frame = frame.resize((max(1, round(frame.width * scale)), max(1, round(frame.height * scale))), Image.LANCZOS)
        out = OUT / (res + ".png")
        frame.save(out, optimize=True)
        write_keep_import(str(out))
        made += 1
    print("đã tạo", made, "ảnh thu nhỏ")


if __name__ == "__main__":
    main()
