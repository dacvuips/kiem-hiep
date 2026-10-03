"""Chuyển file .spr (định dạng Kingsoft/JX — Võ Lâm Truyền Kỳ) sang PNG để dùng trong Godot.

    python tools/spr_to_png.py <file.spr hoặc thư mục> <thư mục output>

Mỗi file .spr -> 1 sprite sheet PNG (các frame xếp ngang, cùng kích thước khung gốc, đã căn theo
toạ độ lệch của từng frame nên animation không bị giật) + 1 file .json mô tả (số frame, số hướng,
tâm/điểm neo, interval). Truyền thư mục thì chuyển toàn bộ .spr bên trong (giữ cấu trúc thư mục).

Cấu trúc file (little-endian):
  Header 32 byte: "SPR\\0", Width, Height, CenterX, CenterY, Frames, Colors, Directions, Interval, 6 WORD dự trữ
  Palette: Colors x (R, G, B)
  Bảng offset: Frames x (DWORD offset, DWORD length) — offset tính từ ngay sau bảng này
  Mỗi frame: Width, Height, OffsetX, OffsetY (WORD) + dữ liệu RLE theo từng dòng:
    [count][alpha] — alpha = 0: bỏ qua count pixel trong suốt;
                     alpha > 0: tiếp theo là count byte chỉ số màu, cùng độ trong suốt alpha.
"""
import json
import os
import struct
import sys

from PIL import Image

HEADER = struct.Struct("<4s8H12x")


def read_spr(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, width, height, cx, cy, frames, colors, directions, interval = HEADER.unpack_from(data, 0)
    if magic[:3] != b"SPR":
        raise ValueError("không phải file SPR Kingsoft")
    pos = HEADER.size
    palette = [tuple(data[pos + i * 3: pos + i * 3 + 3]) for i in range(colors)]
    pos += colors * 3
    offsets = [struct.unpack_from("<II", data, pos + i * 8) for i in range(frames)]
    base = pos + frames * 8

    images = []
    for offset, _length in offsets:
        p = base + offset
        fw, fh, ox, oy = struct.unpack_from("<4H", data, p)
        p += 8
        pixels = bytearray(fw * fh * 4)
        x = y = 0
        while y < fh:
            count, alpha = data[p], data[p + 1]
            p += 2
            if alpha:
                for i in range(count):
                    r, g, b = palette[data[p + i]]
                    k = (y * fw + x + i) * 4
                    pixels[k:k + 4] = bytes((r, g, b, alpha))
                p += count
            x += count
            if x >= fw:
                x = 0
                y += 1
        frame = Image.frombytes("RGBA", (fw, fh), bytes(pixels))
        ## Đặt frame vào khung chung Width x Height theo toạ độ lệch — mọi frame cùng 1 hệ toạ độ.
        canvas = Image.new("RGBA", (width, height))
        canvas.alpha_composite(frame, (ox, oy))
        images.append(canvas)

    meta = {
        "frame_width": width,
        "frame_height": height,
        "center": [cx, cy],
        "frames": frames,
        "directions": max(directions, 1),
        "frames_per_direction": frames // max(directions, 1),
        "interval": interval,
    }
    return images, meta


def crop_to_content(images, meta):
    """Cắt bớt vùng trong suốt thừa CHUNG cho mọi frame (giữ đồng bộ vị trí), cập nhật lại tâm."""
    boxes = [im.getbbox() for im in images if im.getbbox()]
    if not boxes:
        return images, meta
    left = min(b[0] for b in boxes)
    top = min(b[1] for b in boxes)
    right = max(b[2] for b in boxes)
    bottom = max(b[3] for b in boxes)
    images = [im.crop((left, top, right, bottom)) for im in images]
    meta = dict(meta, frame_width=right - left, frame_height=bottom - top,
                center=[meta["center"][0] - left, meta["center"][1] - top])
    return images, meta


def convert(spr_path, out_png):
    images, meta = read_spr(spr_path)
    images, meta = crop_to_content(images, meta)
    w, h = meta["frame_width"], meta["frame_height"]
    sheet = Image.new("RGBA", (w * len(images), h))
    for i, im in enumerate(images):
        sheet.paste(im, (i * w, 0))
    os.makedirs(os.path.dirname(out_png) or ".", exist_ok=True)
    sheet.save(out_png)
    with open(os.path.splitext(out_png)[0] + ".json", "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    return meta


if __name__ == "__main__":
    src, out_dir = sys.argv[1], sys.argv[2]
    if os.path.isfile(src):
        name = os.path.splitext(os.path.basename(src))[0]
        print(convert(src, os.path.join(out_dir, name + ".png")))
    else:
        ok = fail = 0
        for root, _dirs, files in os.walk(src):
            for file in files:
                if not file.lower().endswith(".spr"):
                    continue
                rel = os.path.relpath(os.path.join(root, file), src)
                try:
                    convert(os.path.join(root, file), os.path.join(out_dir, os.path.splitext(rel)[0] + ".png"))
                    ok += 1
                except Exception as e:  ## noqa: BLE001 — 1 file lỗi không dừng cả lô
                    fail += 1
                    print("LỖI", rel, e)
        print(f"xong: {ok} file, lỗi {fail}")
