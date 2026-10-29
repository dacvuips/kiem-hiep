import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
tres_path = ROOT / "systems" / "sect" / "data" / "vo_dang.tres"
content = tres_path.read_text(encoding="utf-8")

# 1. Synergy mappings: SubResource_ID -> (new_label, target_skill_id)
synergy_map = {
    # Nộ Lôi Chỉ
    "SubResource_3": ("Tăng sát thương Thiên Địa Vô Cực", "vo_dang_thien_dia_vo_cuc"),
    "SubResource_4": ("Tăng sát thương Vô Ngã Vô Kiếm", "vo_dang_vo_nga_vo_kiem"),
    "SubResource_5": ("Tăng sát thương Tạo Hóa Thái Thanh", "vo_dang_tao_hoa_thai_thanh"),
    
    # Thương Hải Minh Nguyệt
    "SubResource_18": ("Tăng sát thương Nhân Kiếm Hợp Nhất", "vo_dang_nhan_kiem_hop_nhat"),
    "SubResource_19": ("Tăng sát thương Tam Hoàn Thao Nguyệt", "vo_dang_tam_hoan_thao_nguyet"),
    "SubResource_20": ("Tăng sát thương Kiếm Thùy Tinh Hà", "vo_dang_kiem_thuy_tinh_ha"),
    
    # Kiếm Phi Kinh Thiên
    "SubResource_29": ("Tăng sát thương Huyền Nhất Vô Tượng", "vo_dang_huyen_nhat_vo_tuong"),
    "SubResource_30": ("Tăng sát thương Kiếm Minh Thương Khung", "vo_dang_kiem_minh_thuong_khung"),
    
    # Bác Cấp Nhi Phục
    "SubResource_41": ("Tăng sát thương Thiên Địa Vô Cực", "vo_dang_thien_dia_vo_cuc"),
    "SubResource_42": ("Tăng sát thương Tạo Hóa Thái Thanh", "vo_dang_tao_hoa_thai_thanh"),
    
    # Vô Ngã Vô Kiếm
    "SubResource_48": ("Tăng sát thương Thiên Địa Vô Cực", "vo_dang_thien_dia_vo_cuc"),
    "SubResource_49": ("Tăng sát thương Tạo Hóa Thái Thanh", "vo_dang_tao_hoa_thai_thanh"),
    
    # Tam Hoàn Thao Nguyệt
    "SubResource_63": ("Tăng sát thương Nhân Kiếm Hợp Nhất", "vo_dang_nhan_kiem_hop_nhat"),
    "SubResource_64": ("Tăng sát thương Kiếm Thùy Tinh Hà", "vo_dang_kiem_thuy_tinh_ha"),
    
    # Thiên Địa Vô Cực
    "SubResource_69": ("Tăng sát thương Tạo Hóa Thái Thanh", "vo_dang_tao_hoa_thai_thanh"),
    
    # Nhân Kiếm Hợp Nhất
    "SubResource_88": ("Tăng sát thương Kiếm Thùy Tinh Hà", "vo_dang_kiem_thuy_tinh_ha"),
}

for sub_id, (lbl, tgt) in synergy_map.items():
    pattern = r'(\[sub_resource type="Resource" id="' + sub_id + r'"\]\nscript = ExtResource\("3_statline"\)\nlabel = ")[^"]+("[\s\S]*?suffix = "%")'
    m = re.search(pattern, content)
    if m:
        repl = m.group(1) + lbl + m.group(2)
        if 'target_skill_id =' not in repl:
            repl += f'\ntarget_skill_id = "{tgt}"'
        content = content[:m.start()] + repl + content[m.end():]
        print(f"Updated {sub_id} -> '{lbl}', target='{tgt}'")
    else:
        print(f"ERROR: Could not find {sub_id}")

# 2. Sub-skill VLTK IDs
subskill_vids = {
    "vo_dang_kiem_khi_tung_hoanh": 367,
    "vo_dang_thai_cuc_vo_y": 366,
    "vo_dang_no_loi_lien_hoan_kich": 377,
    "vo_dang_huyen_nhat_vo_tuong": 162,
    "vo_dang_thai_cuc_kiem_y": 371,
    "vo_dang_xuat_u_bat_nhiem_hieu_ung": 738,
    "vo_dang_kiem_minh_thuong_khung": 1107,
    "vo_dang_kiem_vu_dieu_nguyet": 1105,
    "vo_dang_tao_hoa_thai_thanh_va_cham": 1087,
}

for sid, vid in subskill_vids.items():
    # Only match id = "..." at start of line (not target_skill_id)
    pattern = r'(?m)^id = "' + sid + r'"$'
    m = re.search(pattern, content)
    if m:
        # Check if vltk_skill_id already exists in the next 10 lines
        after = content[m.end():m.end()+300]
        if 'vltk_skill_id =' not in after:
            content = content[:m.end()] + f'\nvltk_skill_id = {vid}' + content[m.end():]
            print(f"Added vltk_skill_id = {vid} for {sid}")
        else:
            print(f"Already has vltk_skill_id for {sid}")
    else:
        print(f"ERROR: Could not find line '^id = \"{sid}\"$'")

tres_path.write_text(content, encoding="utf-8")
print("\n=> Áp dụng cập nhật hoàn tất cho vo_dang.tres!")
