import os
import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "data" / "skill_fx" / "skills.json", "r", encoding="utf-8") as f:
    skills_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "missiles.json", "r", encoding="utf-8") as f:
    missiles_fx = json.load(f)

with open(ROOT / "data" / "skill_fx" / "anims.json", "r", encoding="utf-8") as f:
    anims_fx = json.load(f)

tl_skills = [
    (4, "Thiếu Lâm Côn Pháp", "thieu_lam_con_phap"),
    (6, "Thiếu Lâm Đao Pháp", "thieu_lam_dao_phap"),
    (8, "Thiếu Lâm Quyền Pháp", "thieu_lam_quyen_phap"),
    (10, "Kim Cang Phục Ma", "thieu_lam_kim_cang_phuc_ma"),
    (14, "Hàng Long Bất Vũ", "thieu_lam_hang_long_buu_vu"),
    (15, "Bất Động Minh Vương", "thieu_lam_bat_dong_minh_vuong"),
    (16, "La Hán Trận", "thieu_lam_la_han_tran"),
    (20, "Sư Tử Hống", "thieu_lam_su_tu_hong"),
    (11, "Hoành Tảo Lục Hợp", "thieu_lam_hoanh_tao_luc_hop"),
    (19, "Ma Ha Vô Lượng", "thieu_lam_ma_ha_vo_luong"),
    (271, "Long Trảo Hổ Trảo", "thieu_lam_long_trao_ho_trao"),
    (21, "Dịch Cân Kinh", "thieu_lam_dich_can_kinh"),
    (273, "Như Lai Thiên Diệp", "thieu_lam_nhu_lai_thien_diep"),
    (318, "Đạt Ma Độ Giang", "thieu_lam_dat_ma_do_giang"),
    (319, "Hoành Tảo Thiên Quân", "thieu_lam_hoanh_tao_thien_quan"),
    (321, "Vô Tướng Trảm", "thieu_lam_vo_tuong_tram"),
    (709, "Đại Thừa Như Lai Chú", "thieu_lam_dai_thua_nhu_lai_chu"),
    (1055, "Đại Lực Kim Cang Chưởng", "thieu_lam_dai_luc_kim_cang_chuong"),
    (1056, "Vi Đà Hiến Xử", "thieu_lam_vi_da_hien_xu"),
    (1057, "Tam Giới Quy Thiền", "thieu_lam_tam_gioi_quy_thien"),
    (1220, "Kim Quyền La Hán", "thieu_lam_kim_quyen_la_han"),
]

def check_anim_asset(anim_name):
    if not anim_name:
        return "None"
    entry = anims_fx.get(anim_name)
    if not entry:
        # Check directly on disk in assets/skill_fx
        png1 = ROOT / "assets" / "skill_fx" / f"{anim_name}.png"
        if png1.exists():
            return f"OK (on disk: {anim_name}.png)"
        return f"MISSING in anims.json & disk: {anim_name}"
    
    # anims.json has entry
    tex = entry.get("tex", "")
    png_path = ROOT / tex if tex else None
    if png_path and png_path.exists():
        return f"OK ({tex}, {entry.get('frames')}f, {entry.get('dirs')}d)"
    else:
        # check if anim_name.png is in assets/skill_fx
        alt = ROOT / "assets" / "skill_fx" / f"{anim_name}.png"
        if alt.exists():
            return f"OK (alt on disk: {anim_name}.png)"
        return f"MISSING FILE ({tex})"

print("================================================================================")
print("KIỂM TRA CHI TIẾT TỪNG SKILL THIẾU LÂM: HIỆU ỨNG XUẤT CHIÊU, ĐẠN BAY, TRÚNG ĐÍCH")
print("================================================================================")

for sid, name, slug in tl_skills:
    s_key = str(sid)
    s = skills_fx.get(s_key, {})
    style = s.get("style", 0)
    form = s.get("form", 0)
    char_anim = s.get("char_anim", 0)
    precast = s.get("precast", "")
    child = s.get("child", 0)
    child_num = s.get("child_num", 0)
    atk_rad = s.get("attack_radius", 0)
    
    print(f"\n[{sid:4d}] {name} ({slug}):")
    print(f"  - Style: {style} (0=Đạn, 1=Cận chiến, 2=Hào quang, 3=Bị động/Trạng thái)")
    print(f"  - Động tác nhân vật (CharAnimId): {char_anim} (9=Đánh quyền/gậy, 10=Đánh chém/quét, 11=Thi triển phép, 14=Đứng yên/Bị động)")
    print(f"  - Tầm thi triển: {atk_rad} logic units")
    print(f"  - PreCast (Ảnh xuất chiêu tại người): {precast} -> {check_anim_asset(precast)}")
    
    # Check missiles
    # In VLTK: child can be a missile ID or child skill ID. If child is a skill, check that skill's missile or child
    m_ids = []
    if child > 0:
        m_ids.append(str(child))
    m_ids.append(s_key)
    
    checked_missiles = set()
    for mid in m_ids:
        if mid in missiles_fx and mid not in checked_missiles:
            checked_missiles.add(mid)
            m = missiles_fx[mid]
            anims = m.get("anims", [None]*4)
            flight_anim = anims[1].get("anim") if len(anims) > 1 and anims[1] else ""
            hit_anim = anims[3].get("anim") if len(anims) > 3 and anims[3] else ""
            if not hit_anim and len(anims) > 2 and anims[2]:
                hit_anim = anims[2].get("anim")
            
            print(f"  - Missile ID {mid} ({m.get('name', '')}):")
            print(f"    + Dạng bay (MoveKind): {m.get('move_kind')} (0=Tại chỗ/vùng, 1=Bay thẳng, 2=Đuổi, etc.)")
            print(f"    + Ảnh đạn bay (Flight): '{flight_anim}' -> {check_anim_asset(flight_anim)}")
            print(f"    + Ảnh trúng đích (Hit/Impact): '{hit_anim}' -> {check_anim_asset(hit_anim)}")
            print(f"    + Phạm vi sát thương: RangeDmg={m.get('range_dmg')} | DmgRange={m.get('dmg_range')} ô (±{m.get('dmg_range',0)//2} ô)")
            print(f"    + Tốc độ bay: {m.get('speed')} | Thời gian sống: {m.get('life')} frame")
