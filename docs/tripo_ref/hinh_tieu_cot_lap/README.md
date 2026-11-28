# Hình Tiêu Cốt Lập (Ngũ Độc, skill 1066) — ảnh đưa Tripo

Chiêu gốc gồm 4 lớp hình (assets/skill_fx). Chỉ 3 lớp có "vật thể" làm model được; lớp còn lại là tia sáng.

| Ảnh | Lấy từ | Trong chiêu | Làm bằng |
|---|---|---|---|
| `1_ban_tay_ma.png` | `wd_youhunshiying_c` (đạn, 16 hướng) | bàn tay ma bay tới mục tiêu | **Tripo** (mesh) |
| `2_dau_lau.png` | `wd_youhunshiying_d` (phụ) | đầu lâu lửa xanh khi trúng | **Tripo** (mesh) |
| `3_ho_tay_troi_len.png` | `wd_xingxiaoguli_c` (U Hồn Phệ ảnh) | hố đất, nhiều bàn tay trồi lên | **Tripo** (mesh) |
| — | `wd_xingxiaoguli_d` | tia sáng xanh lấp lánh lúc tan | **Godot** (hạt GPUParticles3D) |

`goc/` là frame gốc chưa phóng (để đối chiếu). Ảnh 1024×1024, nền trắng, đã bỏ quầng mờ.

## Cách đưa lên Tripo

Image to 3D, tải từng ảnh + dán câu lệnh (Prompt) dưới đây. Tải về **.glb**. Không cần Rig (không có xương).
Hình gốc rất nhỏ (bàn tay chỉ 28×83 điểm ảnh) nên nên vẽ lại bằng AI trước (cùng câu lệnh) rồi mới đưa lên.

**1. Bàn tay ma**
> stylized ghostly zombie hand and forearm, fingers spread open, glowing toxic green skin, purple veins at the wrist, fading torn wisps at the forearm end, low poly game asset, wuxia fantasy, single object

**2. Đầu lâu**
> stylized screaming skull, toxic green glowing bone, wrapped in purple-blue spirit flame, hollow eye sockets, open jaw, low poly game asset, wuxia poison magic, single object

**3. Hố tay trồi lên**
> round dark cracked ground crater with toxic green slime splashes, four ghostly green zombie arms reaching up out of it, low poly game asset, top-down friendly, wuxia poison magic

## Lưu ý

- Ánh sáng xanh / lửa / quầng mờ **không** nên để Tripo nặn: model chỉ cần hình khối + màu,
  phát sáng làm trong Godot (vật liệu emission xanh + hạt). Nếu Tripo nặn cả quầng lửa thì sẽ ra cục đặc xấu.
- Model nên quay mặt +Z, gốc ở đáy (hố tay) hoặc tâm (bàn tay, đầu lâu).
- Map 3D hiện vẽ đạn chiêu bằng khối; chưa có chỗ gắn model chiêu (cần nối mã hình `wd_...` -> thư mục model).
