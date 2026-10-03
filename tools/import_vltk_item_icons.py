"""Lấy ẢNH VẬT PHẨM (icon trong hành trang / ô trang bị) của mọi món đồ từ client VLTK gốc -> assets/items/icons/.

    python tools/import_vltk_item_icons.py

Đường dẫn ảnh lấy từ trường "image" của data/items/equipment.json + gold_equipment.json (cột Image gốc, VD
\\spr\\item\\equip\\closeweapon\\obj-sword01.spr). Sprite đọc qua tools/vltk_pak.py (file rời hoặc trong .pak), lấy
frame đầu, cắt sát nội dung, lưu <tên file viết thường>.png (+ bản nhỏ icons_small/ cho ô hành trang). Game tra theo
tên file: ItemDatabase.get_icon().
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from vltk_pak import PakList  # noqa: E402
import spr_to_png  # noqa: E402

CLIENT = r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK"
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT, "assets", "items", "icons")
## Bản NHỎ cho ô hành trang (ô 54px, lòng 48px): ảnh lớn hơn được thu nhỏ trước bằng Lanczos (nét hơn nhiều so với
## để Godot thu nhỏ lúc chạy); ảnh vừa ô giữ nguyên — game vẽ đúng kích thước gốc, không phóng to.
SMALL_DIR = os.path.join(PROJECT, "assets", "items", "icons_small")
SMALL_SIZE = 48


def make_small(src_png, dst_png):
    im = Image.open(src_png).convert("RGBA")
    scale = min(1.0, SMALL_SIZE / im.width, SMALL_SIZE / im.height)
    if scale < 1.0:
        ## Thu nhỏ ở dạng màu nhân sẵn alpha (RGBa) để viền trong suốt không bị quầng tối.
        size = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
        im = im.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    im.save(dst_png, optimize=True)


def icon_name(image_path):
    return os.path.splitext(os.path.basename(image_path.replace("\\", "/")))[0].lower()


def main():
    paths = set()
    for name in ("equipment.json", "gold_equipment.json"):
        for item in json.load(open(os.path.join(PROJECT, "data", "items", name), encoding="utf-8")):
            if item.get("image"):
                paths.add(item["image"])
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(SMALL_DIR, exist_ok=True)
    paks = PakList(CLIENT)
    ok, missing, sizes = 0, [], []
    tmp = os.path.join(OUT_DIR, "_tmp.spr")
    for path in sorted(paths):
        out = os.path.join(OUT_DIR, icon_name(path) + ".png")
        if os.path.isfile(out):
            ok += 1
            continue
        data = paks.read(path)
        if data is None:
            missing.append(path)
            continue
        open(tmp, "wb").write(data)
        try:
            images, _meta = spr_to_png.read_spr(tmp)
        except Exception as e:  ## noqa: BLE001 — file hỏng: bỏ qua
            missing.append("%s (%s)" % (path, e))
            continue
        frame = images[0]
        box = frame.getbbox()
        if box:
            frame = frame.crop(box)
        frame.save(out, optimize=True)
        sizes.append(frame.size)
        ok += 1
    if os.path.isfile(tmp):
        os.remove(tmp)
    for name in os.listdir(OUT_DIR):
        if name.endswith(".png"):
            make_small(os.path.join(OUT_DIR, name), os.path.join(SMALL_DIR, name))
    print("xong %d / %d ảnh" % (ok, len(paths)))
    if sizes:
        print("cỡ lớn nhất:", max(s[0] for s in sizes), "x", max(s[1] for s in sizes))
    for m in missing[:20]:
        print("THIẾU", m)
    print("thiếu tổng:", len(missing))


if __name__ == "__main__":
    main()
