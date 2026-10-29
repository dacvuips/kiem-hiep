import sys, re
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
tres_path = ROOT / "systems" / "sect" / "data" / "vo_dang.tres"
content = tres_path.read_text(encoding="utf-8")

subskill_vids = {
    "vo_dang_kiem_khi_tung_hoanh": 367,
    "vo_dang_thai_cuc_vo_y": 366,
    "vo_dang_no_loi_lien_hoan_kich": 377,
    "vo_dang_huyen_nhat_vo_tuong": 162,
    "vo_dang_thai_cuc_kiem_y": 371,
    "vo_dang_xuat_u_bat_nhiem_hieu_ung": 738,
    "vo_dang_kiem_minh_thuong_khung": 1107,
    "vo_dang_kiem_vu_dieu_nguyet": 1105,
    "vo_dang_tao_hoa_thai_thanh_va_cham": 1087, # sub-skill of 1078
}

for sid, vid in subskill_vids.items():
    # Check if vltk_skill_id already exists in this block
    pattern = r'(id = "' + sid + r'"\n)(?!vltk_skill_id)'
    if re.search(pattern, content):
        content = re.sub(pattern, r'\g<1>vltk_skill_id = ' + str(vid) + '\n', content)
        print(f"Added vltk_skill_id = {vid} for {sid}")
    else:
        print(f"Already had or could not find {sid}")

tres_path.write_text(content, encoding="utf-8")
print("Saved vo_dang.tres!")
