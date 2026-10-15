"""Nguồn dữ liệu VLTK bản 15 phái (jxTP15phai) — mọi importer lấy đường dẫn ở đây.

    python tools/vltk_source.py --extract   # giải nén settings/ + script/ của server ra SERVER (chạy 1 lần)

- CLIENT: client game (data/*.pak). Thứ tự pak theo package1.ini (jxthaipham.pak ĐẦU TIÊN — pak này chứa
  Skills.txt/ảnh của 5 phái mới; package.ini mặc định đặt nó cuối nên bị bản cũ trong slistcache.pak che).
- SERVER: thư mục settings/ + script/ lấy từ home/jxser/server1 trong server/vltk_rootfs.tgz (rootfs WSL).
  Tên file tiếng Trung trong tgz mã GBK; file tên hỏng (không tạo được trên Windows) bị bỏ qua.
Đổi máy: đặt biến môi trường JX15_ROOT / JX15_SERVER.
"""
import os
import sys
import tarfile
from pathlib import Path

ROOT = Path(os.environ.get("JX15_ROOT", r"E:/game/VL/jxTP15phai_WSL/jxTP15phai_WSL"))
CLIENT = ROOT / "Client_jxTP_15phai" / "Client"
PACKAGE_INI = "package1.ini"
ROOTFS = ROOT / "server" / "vltk_rootfs.tgz"
SERVER = Path(os.environ.get("JX15_SERVER", r"E:/jx15_src"))
SETTINGS = SERVER / "settings"
SCRIPT = SERVER / "script"
_SERVER_PREFIX = "home/jxser/server1/"

## Môn phái theo thứ tự settings/faction/门派设定.ini (chỉ số = requiremenpai / GetLastFactionNumber gốc).
SECTS = ["thieu_lam", "thien_vuong_bang", "duong_mon", "ngu_doc_giao", "nga_mi", "thuy_yen_mon", "cai_bang",
         "thien_nhan_giao", "vo_dang", "con_lon", "hoa_son", "vu_hon", "tieu_dao", "duong_gia", "minh_giao"]
## Tên script lua (script/skill/<tên>.lua) / Name trong 门派设定.ini.
SECT_ENGLISH = dict(zip(SECTS, ["shaolin", "tianwang", "tangmen", "wudu", "emei", "cuiyan", "gaibang", "tianren",
                                "wudang", "kunlun", "huashan", "wuhuntang", "xiaoyao", "yangmen", "mingjiao"]))

## data/skill_fx (skills/missiles/states.json) dùng chung khoá số với bản VNG của 10 phái cũ, mà bản 15 phái dùng lại
## nhiều số đó cho đạn/skill con/hình trạng thái KHÁC -> mọi skill con, đạn và trạng thái nhập từ bản 15 phái cộng thêm
## số này (SkillId skill người chơi giữ nguyên). import_vltk_hit_effects.py cộng cho vltk_state_special_id của 5 phái mới.
FX_ID_OFFSET = 100000
NEW_SECTS = SECTS[10:]
## Phái lấy số liệu skill (thuộc tính, hiệu ứng, âm thanh) từ bản 15 phái: 5 phái mới + Ngũ Độc (người dùng chọn theo bản
## mới, gồm Vô Hình Độc). 9 phái cũ còn lại giữ bản VNG (server 15 phái cân bằng lại quá mạnh).
JX15_DATA_SECTS = NEW_SECTS + ["ngu_doc_giao"]

_paks = None


def paks():
    """PakList của client 15 phái (dùng chung, mở 1 lần)."""
    global _paks
    if _paks is None:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import vltk_pak
        _paks = vltk_pak.PakList(str(CLIENT), PACKAGE_INI)
    return _paks


def client_file(path: str):
    """Đọc 1 file trong pak client (đường dẫn kiểu "settings/skills.txt" hoặc "\\spr\\..."); None nếu không có."""
    return paks().read(path)


def settings_file(name: str) -> Path:
    """File settings của SERVER (Skills.txt/Missles.txt/item/...) — không phân biệt hoa thường như Windows."""
    p = SETTINGS / name
    if p.exists():
        return p
    cur = SETTINGS
    for part in Path(name).parts:
        hit = [c for c in cur.iterdir() if c.name.lower() == part.lower()] if cur.is_dir() else []
        if not hit:
            return p
        cur = hit[0]
    return cur


def extract():
    n = bad = 0
    with tarfile.open(ROOTFS, "r:gz", encoding="gbk", errors="replace") as t:
        for m in t:
            if not m.name.startswith((_SERVER_PREFIX + "settings/", _SERVER_PREFIX + "script/")):
                continue
            p = SERVER / m.name[len(_SERVER_PREFIX):]
            try:
                if m.isdir():
                    p.mkdir(parents=True, exist_ok=True)
                elif m.isfile():
                    p.parent.mkdir(parents=True, exist_ok=True)
                    p.write_bytes(t.extractfile(m).read())
                    n += 1
            except OSError:
                bad += 1
    print("Đã giải nén %d file vào %s (bỏ %d tên không hợp lệ)" % (n, SERVER, bad))


if __name__ == "__main__":
    if "--extract" in sys.argv:
        extract()
    else:
        print(__doc__)
