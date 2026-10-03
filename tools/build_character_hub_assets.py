"""Dựng asset cho màn Nhân Vật (CharacterHub) từ ảnh mockup AI-gen — chạy lại khi đổi mockup:

    python tools/build_character_hub_assets.py

Mockup là 1 ảnh phẳng có sẵn số liệu mẫu (tên, cấp, chỉ số, tiền...). Script này:
  1. XOÁ các chữ/số động khỏi ảnh (inpaint) -> character_hub_bg.png, để Godot vẽ số thật lên.
  2. TÁCH hình nhân vật (GrabCut) ra PNG nền trong suốt: NỮ lấy từ mockup này, NAM lấy từ ảnh
     màn Chọn Nhân Vật -> portrait_female.png / portrait_male.png (đổi theo giới tính đã chọn).
  3. Cắt icon ổ khoá + viên ngọc từ ô gắn ngọc -> icon_lock.png / icon_gem.png.

Toạ độ đều theo pixel của ảnh gốc 1672x941 (cùng hệ với anchor trong CharacterHub.tscn).
Khi có asset vẽ tách lớp chuẩn thì bỏ script này, thay file PNG trực tiếp.
"""
import os

import cv2
import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..")
HUB_SRC = os.path.join(ROOT, "ui/character_hub/source/character_hub_mockup.png")
SELECT_SRC = os.path.join(ROOT, "ui/character_select/character_select_bg.png")
OUT = os.path.join(ROOT, "ui/character_hub")

## Vùng chữ/số động cần xoá: (x1, y1, x2, y2)
TEXT_REGIONS = [
    (1008, 40, 1105, 72), (1250, 40, 1330, 72), (1475, 40, 1575, 72),  ## tiền tệ
    (680, 135, 875, 172),  ## tên nhân vật
    (700, 188, 756, 212), (798, 188, 892, 212),  ## Lv + Tông môn
    (352, 805, 532, 888),  ## tên ải + tiến độ
    (1512, 866, 1565, 894),  ## "Lv. 2" của Dược Viên
    (1612, 176, 1656, 215),  ## chấm "!" Nhiệm Vụ
]
STAT_VALUE_ROWS_Y = [303, 339, 376, 413, 450, 486, 523, 613, 649]
TEXT_REGIONS += [(1272, y - 14, 1366, y + 14) for y in STAT_VALUE_ROWS_Y]

FEMALE_RECT = (598, 226, 910, 702)  ## trên mockup hub
MALE_RECT = (330, 296, 640, 778)  ## trên ảnh Chọn Nhân Vật

## Nét "chắc chắn là nhân vật" (toạ độ LOCAL trong rect) giúp GrabCut không cắt mất tóc/mặt —
## mỗi nét: (danh sách điểm, độ dày). Hình tròn ghi dạng ([tâm], -bán_kính).
FEMALE_FG_HINTS = [
    ([(165, 30), (165, 420)], 30), ([(165, 80)], -22),
    ([(150, 60), (100, 150), (70, 200)], 14),
    ([(130, 200), (240, 200)], 30), ([(80, 300), (250, 300)], 20), ([(120, 350), (220, 350)], 20),
]
FEMALE_BG_HINTS = [(0, 160, 45, 285), (0, 0, 80, 90), (230, 0, 312, 100), (0, 380, 40, 476), (270, 300, 312, 476), (0, 448, 312, 476)]
MALE_FG_HINTS = [
    ([(150, 20), (150, 380)], 30), ([(155, 75)], -22),
    ([(140, 40), (100, 90), (75, 140)], 12),
    ([(85, 180), (225, 180)], 30), ([(60, 300), (220, 300)], 24), ([(40, 340), (120, 340)], 14),
    ([(100, 360), (100, 460)], 20), ([(190, 360), (190, 460)], 20),
    ([(225, 215), (255, 215)], 8), ([(262, 230), (262, 300)], 5),
]
MALE_BG_HINTS = [(135, 0, 180, 14), (214, 150, 234, 185), (128, 385, 165, 470), (212, 305, 230, 420), (192, 0, 210, 45), (195, 5, 285, 110), (235, 110, 285, 195), (232, 305, 285, 470), (0, 0, 30, 300), (285, 0, 310, 482), (0, 0, 90, 30), (210, 0, 310, 40), (0, 470, 310, 482)]
## Chi tiết mảnh (lọn tóc, vạt áo, dép) GrabCut không bắt được — xoá thêm khỏi nền.
HOLE_EXTRA = [(612, 300, 690, 520), (606, 480, 645, 550), (855, 520, 892, 630), (755, 635, 810, 698)]
## Mẫu màu giấy nền thẻ nhân vật (ảnh Chọn Nhân Vật) để bóc phần còn sót quanh NAM.
PARCHMENT_SAMPLE = (575, 330, 625, 420)
LOCK_CROP = (372, 214, 422, 272)
GEM_CROP = (222, 206, 292, 272)


def text_mask(img, rect):
    """Chỉ đánh dấu pixel khác hẳn màu nền của vùng (chữ), inpaint đẹp hơn xoá cả khung chữ nhật."""
    x1, y1, x2, y2 = rect
    roi = img[y1:y2, x1:x2].astype(np.int16)
    median = np.median(roi.reshape(-1, 3), axis=0)
    diff = np.abs(roi - median).sum(axis=2)
    m = (diff > 70).astype(np.uint8) * 255
    m = cv2.dilate(m, np.ones((5, 5), np.uint8))
    full = np.zeros(img.shape[:2], np.uint8)
    full[y1:y2, x1:x2] = m
    return full


def cut_out(img, rect, fg_hints, bg_hints):
    x1, y1, x2, y2 = rect
    mask = np.full(img.shape[:2], cv2.GC_BGD, np.uint8)
    mask[y1:y2, x1:x2] = cv2.GC_PR_FGD
    for bx1, by1, bx2, by2 in bg_hints:
        mask[y1 + by1:y1 + by2, x1 + bx1:x1 + bx2] = cv2.GC_BGD
    for points, width in fg_hints:
        pts = [(x1 + px, y1 + py) for px, py in points]
        if width < 0:
            cv2.circle(mask, pts[0], -width, cv2.GC_FGD, -1)
        else:
            cv2.polylines(mask, [np.array(pts, np.int32)], False, cv2.GC_FGD, width)
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(img, mask, None, bgd, fgd, 10, cv2.GC_INIT_WITH_MASK)
    fg = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    ## Giữ mảng liền lớn nhất (bỏ đốm nền lọt vào), làm mượt viền 1px.
    n, labels, stats, _ = cv2.connectedComponentsWithStats(fg)
    if n > 1:
        biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        fg = np.where(labels == biggest, 255, 0).astype(np.uint8)
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    return fg


def peel_background_color(img, alpha, sample_rect, threshold=45, iterations=40):
    """Bóc dần (từ viền vào trong) các pixel CÓ MÀU GIỐNG NỀN còn sót sau GrabCut — chỉ bóc pixel
    kề vùng đã trong suốt, nên mặt/tay nằm bên trong viền tóc/áo không bị ăn mất."""
    x1, y1, x2, y2 = sample_rect
    bg_color = np.median(img[y1:y2, x1:x2].reshape(-1, 3), axis=0)
    similar = np.linalg.norm(img.astype(np.float32) - bg_color, axis=2) < threshold
    alpha = alpha.copy()
    kernel = np.ones((3, 3), np.uint8)
    for _ in range(iterations):
        near_transparent = cv2.dilate((alpha == 0).astype(np.uint8), kernel) > 0
        peel = near_transparent & similar & (alpha > 0)
        if not peel.any():
            break
        alpha[peel] = 0
    return alpha


def save_rgba(img, alpha, path):
    rgba = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = alpha
    ys, xs = np.nonzero(alpha)
    rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    cv2.imwrite(path, rgba)
    return xs.min(), ys.min(), xs.max(), ys.max()


if __name__ == "__main__":
    hub = cv2.imread(HUB_SRC)
    select = cv2.imread(SELECT_SRC)

    female_alpha = cut_out(hub, FEMALE_RECT, FEMALE_FG_HINTS, FEMALE_BG_HINTS)
    print("female bbox", save_rgba(hub, female_alpha, os.path.join(OUT, "portrait_female.png")))
    male_alpha = cut_out(select, MALE_RECT, MALE_FG_HINTS, MALE_BG_HINTS)
    male_alpha = peel_background_color(select, male_alpha, PARCHMENT_SAMPLE)
    print("male bbox", save_rgba(select, male_alpha, os.path.join(OUT, "portrait_male.png")))

    for name, (x1, y1, x2, y2) in {"icon_lock": LOCK_CROP, "icon_gem": GEM_CROP}.items():
        cv2.imwrite(os.path.join(OUT, name + ".png"), hub[y1:y2, x1:x2])

    mask = np.zeros(hub.shape[:2], np.uint8)
    for rect in TEXT_REGIONS:
        mask |= text_mask(hub, rect)
    clean = cv2.inpaint(hub, mask, 6, cv2.INPAINT_TELEA)

    ## Lỗ nhân vật quá lớn để inpaint từng pixel (ra vệt nhoè) — inpaint ở độ phân giải 1/4 rồi
    ## phóng lại cho ra mảng mờ mịn, trộn viền mềm. Godot đặt quầng sáng + portrait che lên trên.
    hole = cv2.dilate(female_alpha, np.ones((31, 31), np.uint8))
    for x1, y1, x2, y2 in HOLE_EXTRA:
        hole[y1:y2, x1:x2] = 255
    small = cv2.resize(clean, None, fx=0.25, fy=0.25, interpolation=cv2.INTER_AREA)
    small_hole = cv2.resize(hole, (small.shape[1], small.shape[0]), interpolation=cv2.INTER_NEAREST)
    small_hole = cv2.dilate(small_hole, np.ones((3, 3), np.uint8))
    filled = cv2.resize(cv2.inpaint(small, small_hole, 5, cv2.INPAINT_TELEA), (clean.shape[1], clean.shape[0]), interpolation=cv2.INTER_CUBIC)
    filled = cv2.GaussianBlur(filled, (0, 0), 6)
    feather = cv2.GaussianBlur(hole.astype(np.float32) / 255.0, (0, 0), 4)[:, :, None]
    clean = (clean * (1 - feather) + filled * feather).astype(np.uint8)
    cv2.imwrite(os.path.join(OUT, "character_hub_bg.png"), clean)
    print("ok")
