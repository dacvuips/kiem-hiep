# HÌNH TẠM — KHÔNG ĐƯỢC PHÁT HÀNH

Asset trong thư mục này lấy từ game thương mại (có bản quyền), CHỈ dùng để test gameplay.
Trước khi phát hành, phải thay toàn bộ bằng asset tự làm / có giấy phép, rồi xoá thư mục này.

Kiểm tra còn chỗ nào dùng: tìm chuỗi `placeholder_do_not_ship` trong các file `.tres`/`.tscn`.

| Asset | Nguồn | Đang dùng ở | Cách gỡ |
|---|---|---|---|
| `vltk_jackie_b4sXIfHh/` (sét giáng + nổ, 19 frame) | Võ Lâm Truyền Kỳ, `magic1.big/.../jackie_b4sXIfHh.spr` (chuyển bằng `tools/spr_to_png.py`) | `gem_system/data/attack/loi_kich_skill.tres` → `flight_layers` | Xoá `flight_layers` trong Inspector — skill quay lại animation cũ |
