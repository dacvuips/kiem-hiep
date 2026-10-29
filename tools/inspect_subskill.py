import sys
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")
lines = Path("systems/sect/data/vo_dang.tres").read_text(encoding="utf-8").splitlines()
sub_ids = [
    "vo_dang_kiem_khi_tung_hoanh",
    "vo_dang_thai_cuc_vo_y",
    "vo_dang_no_loi_lien_hoan_kich",
    "vo_dang_huyen_nhat_vo_tuong",
    "vo_dang_thai_cuc_kiem_y",
    "vo_dang_xuat_u_bat_nhiem_hieu_ung",
    "vo_dang_kiem_minh_thuong_khung",
    "vo_dang_kiem_vu_dieu_nguyet",
    "vo_dang_tao_hoa_thai_thanh_va_cham"
]
for i, l in enumerate(lines):
    for sid in sub_ids:
        if f'id = "{sid}"' in l:
            print(f"--- {sid} at line {i+1} ---")
            for j in range(max(0, i-2), min(len(lines), i+25)):
                print(f"{j+1}: {lines[j]}")
