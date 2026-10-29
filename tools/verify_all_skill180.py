import json
import re
import os
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

errors = []

# 1. Verify JSON files
print("=== 1. Verifying JSON files ===")
for jf in ["data/skill_fx/anims.json", "data/skill_fx/skills.json", "data/items/misc_items.json"]:
    p = ROOT / jf
    try:
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        print(f" OK: {jf} ({len(data)} entries)")
    except Exception as e:
        errors.append(f"JSON Error in {jf}: {e}")

# 2. Check skill 180 icons exist
print("\n=== 2. Verifying Skill 180 Icons ===")
icon_ids = [
    "thieu_lam_kim_quyen_la_han", "thien_vuong_chinh_chien_bat_phuong",
    "ngu_doc_sam_la_doc_hai", "duong_mon_hap_tinh_tran",
    "nga_mi_ba_la_tam_kinh", "thuy_yen_huyen_bang_vo_tac",
    "thien_nhan_liet_hoa_phan_thien", "cai_bang_o_y_quyet",
    "vo_dang_chan_vo_that_tiet", "con_lon_thien_cuong_khi_kinh"
]
for iid in icon_ids:
    png = ROOT / "assets" / "skill_icons" / "vltk" / f"{iid}.png"
    if png.exists() and png.stat().st_size > 0:
        print(f" OK Icon: {iid}.png ({png.stat().st_size} bytes)")
    else:
        errors.append(f"Missing icon: {png}")

# 3. Check 5 Element animations
print("\n=== 3. Verifying 5-Element Aura Animations ===")
for aura in ["tien_giai_kim", "tien_giai_moc", "tien_giai_thuy", "tien_giai_hoa", "tien_giai_tho"]:
    png = ROOT / "assets" / "skill_fx" / f"{aura}.png"
    meta = ROOT / "assets" / "skill_fx" / f"{aura}.json"
    if png.exists() and meta.exists():
        print(f" OK Aura: {aura} (png={png.stat().st_size}b, meta={meta.stat().st_size}b)")
    else:
        errors.append(f"Missing aura file for {aura}")

# 4. Check Sect .tres files
print("\n=== 4. Verifying Sect .tres files ===")
tres_files = [
    ("thieu_lam.tres", "thieu_lam_kim_quyen_la_han", 1220),
    ("thien_vuong_bang.tres", "thien_vuong_chinh_chien_bat_phuong", 1221),
    ("ngu_doc_giao.tres", "ngu_doc_sam_la_doc_hai", 1222),
    ("duong_mon.tres", "duong_mon_hap_tinh_tran", 1223),
    ("nga_mi.tres", "nga_mi_ba_la_tam_kinh", 1224),
    ("thuy_yen_mon.tres", "thuy_yen_huyen_bang_vo_tac", 1225),
    ("thien_nhan_giao.tres", "thien_nhan_liet_hoa_phan_thien", 1226),
    ("cai_bang.tres", "cai_bang_o_y_quyet", 1227),
    ("vo_dang.tres", "vo_dang_chan_vo_that_tiet", 1228),
    ("con_lon.tres", "con_lon_thien_cuong_khi_kinh", 1229),
]

for fn, sid, vid in tres_files:
    p = ROOT / "systems" / "sect" / "data" / fn
    txt = p.read_text(encoding="utf-8")
    if sid not in txt:
        errors.append(f"{fn} missing skill id {sid}")
    if f"vltk_skill_id = {vid}" not in txt:
        errors.append(f"{fn} missing vltk_skill_id {vid}")
    if f"vicon_{sid}" not in txt:
        errors.append(f"{fn} missing icon ext_resource vicon_{sid}")

    # Check that the SubResource is properly declared and linked in skills array
    m_sub = re.search(r'\[sub_resource type="Resource" id="([^"]+)"\]\nscript = ExtResource\("2_skill"\)\nid = "' + sid + '"', txt)
    if not m_sub:
        errors.append(f"{fn} could not find SubResource block for {sid}")
    else:
        sub_id = m_sub.group(1)
        if f'SubResource("{sub_id}")' not in txt.split("[resource]")[-1]:
            errors.append(f"{fn} SubResource {sub_id} not linked in [resource] skills array")
        else:
            print(f" OK Tres: {fn} -> {sid} ({sub_id}) linked!")

# 5. Check Bí kíp in misc_items.json
print("\n=== 5. Verifying Bí kíp in misc_items.json ===")
with open(ROOT / "data" / "items" / "misc_items.json", "r", encoding="utf-8") as f:
    items = json.load(f)
bk_180 = [i for i in items if "Bí Kíp 180" in i.get("name", "")]
print(f" Found {len(bk_180)}/15 Bí Kíp 180 items.")
if len(bk_180) != 15:
    errors.append(f"Expected 15 Bí kíp 180, found {len(bk_180)}")

if errors:
    print("\n--- ERRORS FOUND ---")
    for e in errors:
        print("  X", e)
    sys.exit(1)
else:
    print("\nALL CHECKS PASSED PERFECTLY!")
