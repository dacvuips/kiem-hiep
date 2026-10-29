"""Lấy ẢNH VẬT PHẨM (icon trong hành trang / ô trang bị) của mọi món đồ từ client VLTK 15 phái -> assets/items/icons/.

    python -X utf8 -I tools/import_vltk_item_icons.py

Đường dẫn ảnh lấy từ trường "image" của data/items/equipment.json + gold_equipment.json + misc_items.json (cột Image
gốc, VD \\spr\\item\\equip\\closeweapon\\obj-sword01.spr). Sprite đọc qua vltk_source.paks() (pak theo package1.ini,
jxthaipham.pak trước), lấy frame đầu, cắt sát nội dung, lưu <tên file viết thường>.png (+ bản nhỏ icons_small/ cho ô
hành trang). Game tra theo tên file: ItemDatabase.get_icon(). Luôn ghi đè (ảnh bản mới có thể khác bản cũ).
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import spr_to_png  # noqa: E402
import vltk_source  # noqa: E402
from vltk_pak import PakFile, PakList, file_name_to_id, normalize  # noqa: E402

CLIENT = str(vltk_source.CLIENT)
## Client cũ — chỉ dùng khi ảnh không có ở đâu trong client 15 phái (không có thư mục thì bỏ qua).
OLD_CLIENT = r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK"
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


def open_readers():
    """Danh sách hàm đọc theo thứ tự ưu tiên: pak theo package1.ini -> các pak KHÁC trong data/ của client 15 phái
    (vài pak không có trong package1.ini, VD serverlist.pak chứa ~200 ảnh vật phẩm sự kiện) -> client cũ."""
    readers = [vltk_source.paks().read]
    listed = {os.path.normcase(p.path) for p in vltk_source.paks().paks if hasattr(p, "path")}
    data_dir = os.path.join(CLIENT, "data")
    extra = []
    for name in sorted(os.listdir(data_dir)):
        path = os.path.join(data_dir, name)
        if name.lower().endswith(".pak") and os.path.normcase(path) not in listed:
            try:
                extra.append(PakFile(path))
            except Exception:  ## noqa: BLE001 — pak hỏng / không đúng định dạng: bỏ qua
                pass

    def read_extra(path):
        uid = file_name_to_id(normalize(path))
        for pak in extra:
            if uid in pak.index:
                return pak.read(uid)
        return None
    readers.append(read_extra)
    if os.path.isdir(OLD_CLIENT):
        readers.append(PakList(OLD_CLIENT).read)
    return readers


def read_any(readers, path):
    for read in readers:
        data = read(path)
        if data is not None:
            return data
    return None


def main():
    ## đường dẫn ảnh gốc -> tên file png (vật phẩm khác có sẵn trường "icon": tên ASCII, không trùng).
    paths = {}
    for name in ("equipment.json", "gold_equipment.json", "misc_items.json"):
        for item in json.load(open(os.path.join(PROJECT, "data", "items", name), encoding="utf-8")):
            if item.get("image"):
                paths[item["image"]] = item.get("icon") or icon_name(item["image"])
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(SMALL_DIR, exist_ok=True)
    readers = open_readers()
    ok, missing, sizes = 0, [], []
    tmp = os.path.join(OUT_DIR, "_tmp.spr")
    for path in sorted(paths):
        out = os.path.join(OUT_DIR, paths[path] + ".png")
        small_out = os.path.join(SMALL_DIR, paths[path] + ".png")
        if os.path.isfile(out) and os.path.isfile(small_out) and os.path.getsize(out) > 0:
            ok += 1
            continue
        data = read_any(readers, path)
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
    ## Ảnh cũ vẫn giữ (save cũ / thuốc Tống Kim còn dùng) — chỉ báo số ảnh không còn món nào tham chiếu.
    wanted = set(paths.values())
    stale = [n for n in os.listdir(OUT_DIR) if n.endswith(".png") and n[:-4] not in wanted]
    print("ảnh không món nào dùng (giữ nguyên):", len(stale))
    for name in os.listdir(OUT_DIR):
        if name.endswith(".png"):
            small_path = os.path.join(SMALL_DIR, name)
            if not os.path.isfile(small_path):
                make_small(os.path.join(OUT_DIR, name), small_path)
    print("xong %d / %d ảnh" % (ok, len(paths)))
    if sizes:
        print("cỡ lớn nhất:", max(s[0] for s in sizes), "x", max(s[1] for s in sizes))
    for m in missing[:20]:
        print("THIẾU", m)
    print("thiếu tổng:", len(missing))


if __name__ == "__main__":
    main()
