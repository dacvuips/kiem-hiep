import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
tres_path = ROOT / "systems" / "sect" / "data" / "vo_dang.tres"
content = tres_path.read_text(encoding="utf-8")

# 1. Map of SubResources to update with target_skill_id and descriptive label
synergy_updates = {
    "SubResource_3": ("Tăng sát thương Thiên Địa Vô Cực", "vo_dang_thien_dia_vo_cuc"),
    "SubResource_4": ("Tăng sát thương Vô Ngã Vô Kiếm", "vo_dang_vo_nga_vo_kiem"),
    "SubResource_5": ("Tăng sát thương Tạo Hóa Thái Thanh", "vo_dang_tao_hoa_thai_thanh"),
    "SubResource_8": ("Tăng sát thương Nhân Kiếm Hợp Nhất", "vo_dang_nhan_kiem_hop_nhat"),
    "SubResource_9": ("Tăng sát thương Tam Hoàn Thao Nguyệt", "vo_dang_tam_hoan_thao_nguyet"),
    "SubResource_10": ("Tăng sát thương Kiếm Thùy Tinh Hà", "vo_dang_kiem_thuy_tinh_ha"),
    "SubResource_12": ("Tăng sát thương Huyền Nhất Vô Tượng", "vo_dang_huyen_nhat_vo_tuong"),
    "SubResource_13": ("Tăng sát thương Kiếm Minh Thương Khung", "vo_dang_kiem_minh_thuong_khung"),
    "SubResource_27": ("Tăng sát thương Thiên Địa Vô Cực", "vo_dang_thien_dia_vo_cuc"),
    "SubResource_28": ("Tăng sát thương Tạo Hóa Thái Thanh", "vo_dang_tao_hoa_thai_thanh"),
    "SubResource_40": ("Tăng sát thương Thiên Địa Vô Cực", "vo_dang_thien_dia_vo_cuc"),
    "SubResource_41": ("Tăng sát thương Tạo Hóa Thái Thanh", "vo_dang_tao_hoa_thai_thanh"),
    "SubResource_47": ("Tăng sát thương Nhân Kiếm Hợp Nhất", "vo_dang_nhan_kiem_hop_nhat"),
    "SubResource_48": ("Tăng sát thương Kiếm Thùy Tinh Hà", "vo_dang_kiem_thuy_tinh_ha"),
    "SubResource_64": ("Tăng sát thương Tạo Hóa Thái Thanh", "vo_dang_tao_hoa_thai_thanh"),
    "SubResource_70": ("Tăng sát thương Kiếm Thùy Tinh Hà", "vo_dang_kiem_thuy_tinh_ha"),
}

for sub_id, (label, target_id) in synergy_updates.items():
    pattern = r'(\[sub_resource type="Resource" id="' + sub_id + r'"\]\nscript = ExtResource\("3_statline"\)\nlabel = ")[^"]+("[\s\S]*?suffix = "%")'
    def repl(m, lbl=label, tgt=target_id):
        body = m.group(1) + lbl + m.group(2)
        if 'target_skill_id =' not in body:
            body += f'\ntarget_skill_id = "{tgt}"'
        return body
    content, n = re.subn(pattern, repl, content)
    print(f"Updated {sub_id} -> {label} (target: {target_id}): {n} replacement(s)")

# 2. Update vltk_skill_id for sub-skills
skill_id_updates = {
    "vo_dang_kiem_khi_tung_hoanh": 367,
    "vo_dang_thai_cuc_vo_y": 366,
    "vo_dang_no_loi_lien_hoan_kich": 377,
    "vo_dang_huyen_nhat_vo_tuong": 162,
    "vo_dang_thai_cuc_kiem_y": 371,
    "vo_dang_xuat_u_bat_nhiem_hieu_ung": 738,
    "vo_dang_kiem_minh_thuong_khung": 1107,
    "vo_dang_kiem_vu_dieu_nguyet": 1105,
}

for sk_id, real_vid in skill_id_updates.items():
    pattern = r'(id = "' + sk_id + r'"[\s\S]*?vltk_skill_id = )0'
    content, n = re.subn(pattern, r'\g<1>' + str(real_vid), content)
    print(f"Updated vltk_skill_id for {sk_id} -> {real_vid}: {n} replacement(s)")

tres_path.write_text(content, encoding="utf-8")
print("\n=> Cập nhật vo_dang.tres thành công!")
