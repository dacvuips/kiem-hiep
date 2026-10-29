import os
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

# 1. Map skill ID to tres ID and name
vltk_to_tres = {
    4: ("thieu_lam_con_phap", "Thiếu Lâm Côn Pháp"),
    6: ("thieu_lam_dao_phap", "Thiếu Lâm Đao Pháp"),
    8: ("thieu_lam_quyen_phap", "Thiếu Lâm Quyền Pháp"),
    10: ("thieu_lam_kim_cang_phuc_ma", "Kim Cang Phục Ma"),
    14: ("thieu_lam_hang_long_buu_vu", "Hàng Long Bất Vũ"),
    15: ("thieu_lam_bat_dong_minh_vuong", "Bất Động Minh Vương"),
    16: ("thieu_lam_la_han_tran", "La Hán Trận"),
    20: ("thieu_lam_su_tu_hong", "Sư Tử Hống"),
    11: ("thieu_lam_hoanh_tao_luc_hop", "Hoành Tảo Lục Hợp"),
    19: ("thieu_lam_ma_ha_vo_luong", "Ma Ha Vô Lượng"),
    271: ("thieu_lam_long_trao_ho_trao", "Long Trảo Hổ Trảo"),
    272: ("thieu_lam_long_trao_ho_trao", "Long Trảo Hổ Trảo (Đạn con)"),
    21: ("thieu_lam_dich_can_kinh", "Dịch Cân Kinh"),
    273: ("thieu_lam_nhu_lai_thien_diep", "Như Lai Thiên Diệp"),
    317: ("thieu_lam_dat_ma_do_giang", "Đạt Ma Độ Giang (Đạn con)"),
    318: ("thieu_lam_dat_ma_do_giang", "Đạt Ma Độ Giang"),
    319: ("thieu_lam_hoanh_tao_thien_quan", "Hoành Tảo Thiên Quân"),
    321: ("thieu_lam_vo_tuong_tram", "Vô Tướng Trảm"),
    709: ("thieu_lam_dai_thua_nhu_lai_chu", "Đại Thừa Như Lai Chú"),
    1055: ("thieu_lam_dai_luc_kim_cang_chuong", "Đại Lực Kim Cang Chưởng"),
    1083: ("thieu_lam_dai_luc_kim_cang_chuong", "Đại Lực Kim Cang Chưởng (Đạn con)"),
    1056: ("thieu_lam_vi_da_hien_xu", "Vi Đà Hiến Xử"),
    1057: ("thieu_lam_tam_gioi_quy_thien", "Tam Giới Quy Thiền"),
    1220: ("thieu_lam_kim_quyen_la_han", "Kim Quyền La Hán"),
}

# Read shaolin.lua
p_lua = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/shaolin.lua"
res = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_lua], capture_output=True)
lua_text = res.stdout.decode("utf-8", "replace")

# Read 150 skills lua if any
p_150 = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/advancedskill.lua"
res150 = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_150], capture_output=True)
lua_150 = res150.stdout.decode("utf-8", "replace")

print("=== KIỂM TRA TOÀN BỘ CÁC SKILL TRONG SHAOLIN.LUA ===")

# Parse skills in shaolin.lua
skill_blocks = re.findall(r'(\w+)\s*=\s*\{\s*--([^\n]*)\n(.*?)\n\t\},', lua_text, re.DOTALL)
for sk_var, sk_comment, sk_body in skill_blocks:
    print(f"\n--- {sk_var} ({sk_comment.strip()}) ---")
    # find addskilldamage
    add_damages = re.findall(r'addskilldamage(\d+)\s*=\s*\{\s*\[1\]\s*=\s*\{\{1,(\d+)\},\{2,\d+\}\},\s*\[3\]\s*=\s*\{\{1,(\d+)\},\{20,(\d+)', sk_body)
    for num, tgt_id, val1, val20 in add_damages:
        tgt_int = int(tgt_id)
        tres_match = vltk_to_tres.get(tgt_int, (str(tgt_int), "Unknown"))
        print(f"  addskilldamage{num}: Hỗ trợ cho VLTK ID {tgt_int} ({tres_match[1]} - [{tres_match[0]}]): {val1}% -> {val20}%")
