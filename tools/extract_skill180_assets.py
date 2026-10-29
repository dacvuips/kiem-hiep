import os
import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

if sys.platform == "win32":
    git_usr_bin = r"C:\Program Files\Git\usr\bin"
    if os.path.exists(git_usr_bin) and git_usr_bin not in os.environ.get("PATH", ""):
        os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vltk_pak
import spr_to_png

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / "assets" / "skill_icons" / "vltk"
FX_DIR = ROOT / "assets" / "skill_fx"
ICON_DIR.mkdir(parents=True, exist_ok=True)
FX_DIR.mkdir(parents=True, exist_ok=True)

CLIENT_DIR = r"E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client"
CLIENT_DIR_OLD = r"D:\game\source_vo-lam-truyen-ky\Client_VLTK\Client_VLTK"

paks = vltk_pak.PakList(CLIENT_DIR, "package1.ini")
paks_old = vltk_pak.PakList(CLIENT_DIR_OLD, "package.ini")

def get_pak_data(path):
    d = paks.read(path)
    if not d:
        d = paks_old.read(path)
    return d

# 1. Skill 180 icons map
SKILL_ICONS = {
    "thieu_lam_kim_quyen_la_han": r"\spr\Ui\技能图标\jj\icon_jj_sl_150.spr",
    "thien_vuong_chinh_chien_bat_phuong": r"\spr\Ui\技能图标\jj\icon_jj_tw_150.spr",
    "ngu_doc_sam_la_doc_hai": r"\spr\Ui\技能图标\jj\icon_jj_wd_150.spr",
    "duong_mon_hap_tinh_tran": r"\spr\Ui\技能图标\jj\icon_jj_tm_150.spr",
    "nga_mi_ba_la_tam_kinh": r"\spr\Ui\技能图标\jj\icon_jj_em_150.spr",
    "thuy_yen_huyen_bang_vo_tac": r"\spr\Ui\技能图标\jj\icon_jj_cy_150.spr",
    "thien_nhan_liet_hoa_phan_thien": r"\spr\Ui\技能图标\jj\icon_jj_tr_150.spr",
    "cai_bang_o_y_quyet": r"\spr\Ui\技能图标\jj\icon_jj_gb_150.spr",
    "vo_dang_chan_vo_that_tiet": r"\spr\Ui\技能图标\jj\icon_jj_wu_150.spr",
    "con_lon_thien_cuong_khi_kinh": r"\spr\Ui\技能图标\jj\icon_jj_kl_150.spr",
}

print("=== Extracting Skill 180 Icons ===")
tmp_spr = ROOT / "tmp_icon.spr"
for skill_id, spr_path in SKILL_ICONS.items():
    out_png = ICON_DIR / f"{skill_id}.png"
    data = get_pak_data(spr_path)
    if data:
        tmp_spr.write_bytes(data)
        try:
            images, _meta = spr_to_png.read_spr(str(tmp_spr))
            images[0].save(out_png, optimize=True)
            print(f" Extracted: {skill_id}.png ({len(data)} bytes)")
        except Exception as e:
            print(f" Error extracting {skill_id}: {e}")
    else:
        print(f" NOT FOUND: {spr_path}")

# 2. Extract 5 element casting animations (門派進階)
ELEMENT_AURA = {
    "tien_giai_kim": r"\spr\skill\门派进阶\金.spr",
    "tien_giai_moc": r"\spr\skill\门派进阶\木.spr",
    "tien_giai_thuy": r"\spr\skill\门派进阶\水.spr",
    "tien_giai_hoa": r"\spr\skill\门派进阶\火.spr",
    "tien_giai_tho": r"\spr\skill\门派进阶\土.spr",
}

print("\n=== Extracting 5 Element Casting Animations ===")
for aura_name, spr_path in ELEMENT_AURA.items():
    out_png = FX_DIR / f"{aura_name}.png"
    data = get_pak_data(spr_path)
    if data:
        tmp_spr.write_bytes(data)
        try:
            spr_to_png.convert(str(tmp_spr), str(out_png))
            print(f" Extracted anim: {aura_name}.png + json")
        except Exception as e:
            print(f" Error converting {aura_name}: {e}")
    else:
        print(f" NOT FOUND: {spr_path}")

if tmp_spr.exists():
    tmp_spr.unlink()
print("\nExtraction completed!")
