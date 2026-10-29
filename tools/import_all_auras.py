"""Nhập TOÀN BỘ Hào Quang (Aura / Quang Hoàn) từ source gốc VLTK (bản 15 phái + VNG + loose files)
và xuất thành dữ liệu sẵn sàng cho GM Grid & Runtime:
  - assets/skill_fx/<anim_key>.png (atlas animation)
  - assets/ui/aura_thumbs/<aura_id>.png (ảnh đại diện thumbnail xem trước trên Grid GM)
  - data/skill_fx/states.json (đăng ký trạng thái Foot/Aura)
  - data/skill_fx/anims.json (thông số frame, size, offset)
  - data/auras/aura_catalog.json (danh mục tổng hợp có tên tiếng Việt, loại, icon, state_id, mô tả)
"""
import os
import sys
import json
import re
import tempfile
from pathlib import Path
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding="utf-8")

import vltk_source
import vltk_pak
import spr_to_png
from import_vltk_skill_fx import luma_key_if_additive, anim_key, MAX_SHEET_WIDTH

ROOT = Path(__file__).resolve().parent.parent
OUT_PNG = ROOT / "assets" / "skill_fx"
OUT_THUMBS = ROOT / "assets" / "ui" / "aura_thumbs"
DATA_DIR = ROOT / "data" / "skill_fx"
CATALOG_DIR = ROOT / "data" / "auras"

LOOSE_OTHERS = r"D:\game\source_vo-lam-truyen-ky\Client_VLTK\Client_VLTK\spr\skill\others"
VNG_CLIENT = r"D:\game\source_vo-lam-truyen-ky\vng\Level Up Games\Vo Lam Truyen Ky 2.0"
STATE_TABLE = "E:/jx15_src/settings/bang_doichieu_trangthai_hieuung.txt"

# Bảng tên tiếng Việt & phân loại cho các aura
AURA_NAMES = {
    # Vòng sáng ngũ sắc / cơ bản
    "hongguanhuan": ("Hồng Quang Hoàn", "Vòng Sáng Đỏ rực lửa uy dũng", "Vòng Sáng"),
    "lvguagnhuan": ("Lục Quang Hoàn", "Vòng Sáng Lục sắc sinh mệnh", "Vòng Sáng"),
    "languanhuan": ("Lam Quang Hoàn", "Vòng Sáng Lam ngọc thanh khiết", "Vòng Sáng"),
    "jinguanhuan": ("Kim Quang Hoàn", "Vòng Sáng Hoàng Kim chói lọi", "Vòng Sáng"),
    "heiguanhuan": ("Hắc Quang Hoàn", "Vòng Sáng Hắc Ám huyền bí", "Vòng Sáng"),
    "vip_guanghuan": ("Hào Quang VIP", "Vòng Sáng Tôn Quý Hoàng Kim", "VIP & Sự Kiện"),
    "huoyan_guanghuan": ("Hỏa Diễm Quang Hoàn", "Vòng Sáng Rực Lửa GM", "Vòng Sáng"),
    "anying_guanghuan": ("Ám Ảnh Quang Hoàn", "Vòng Sáng Ma Quái Huyền Bí", "Vòng Sáng"),
    "qijian_guanghuan": ("Thất Kiếm Quang Hoàn", "Thất Kiếm Trận Hộ Thể", "Vòng Sáng"),
    "xiangjiao_guanghuan": ("Hương Tiêu Quang Hoàn", "Vòng Sáng Hương Tiêu Vàng", "Vòng Sáng"),

    # Phi Phong & Danh hiệu đỉnh cao
    "title_yl": ("Phi Phong Ngự Phong", "Vòng Sáng Phi Phong Cấp 6", "Phi Phong & Danh Hiệu"),
    "title_bj": ("Phi Phong Tiềm Long", "Vòng Sáng Phi Phong Cấp 7", "Phi Phong & Danh Hiệu"),
    "title_zw": ("Phi Phong Xuất Trần", "Vòng Sáng Phi Phong Cấp 8", "Phi Phong & Danh Hiệu"),
    "title_dg": ("Phi Phong Kình Thiên", "Vòng Sáng Phi Phong Cấp 9", "Phi Phong & Danh Hiệu"),
    "title_ab": ("Phi Phong Vô Cực", "Vòng Sáng Phi Phong Cấp 10 (Chí Tôn)", "Phi Phong & Danh Hiệu"),
    "title_new_yl": ("Tân Phi Phong Ngự Phong", "Hào Quang Phi Phong Ngự Phong Tân Tiến", "Phi Phong & Danh Hiệu"),
    "title_new_bj": ("Tân Phi Phong Tiềm Long", "Hào Quang Phi Phong Tiềm Long Tân Tiến", "Phi Phong & Danh Hiệu"),
    "title_new_zw": ("Tân Phi Phong Xuất Trần", "Hào Quang Phi Phong Xuất Trần Tân Tiến", "Phi Phong & Danh Hiệu"),
    "title_new_dg": ("Tân Phi Phong Kình Thiên", "Hào Quang Phi Phong Kình Thiên Tân Tiến", "Phi Phong & Danh Hiệu"),
    "title_new_ab": ("Tân Phi Phong Vô Cực", "Hào Quang Phi Phong Vô Cực Tuyệt Đỉnh", "Phi Phong & Danh Hiệu"),

    "jianxiazhizun": ("Kiếm Hiệp Chí Tôn", "Hào Quang Đệ Nhất Kiếm Hiệp VLTK", "Phi Phong & Danh Hiệu"),
    "wulinhaojie": ("Võ Lâm Hào Kiệt", "Hào Quang Anh Hùng Xuất Chúng", "Phi Phong & Danh Hiệu"),
    "jianghugaoshou": ("Giang Hồ Cao Thủ", "Hào Quang Bậc Thầy Giang Hồ", "Phi Phong & Danh Hiệu"),
    "dubutianxia": ("Độc Bộ Thiên Hạ", "Hào Quang Độc Bộ Thiên Hạ Quán Tuyệt", "Phi Phong & Danh Hiệu"),
    "xiridaxia": ("Tích Nhật Đại Hiệp", "Hào Quang Đại Hiệp Vang Danh", "Phi Phong & Danh Hiệu"),
    "jianwangzhixia": ("Kiếm Vương Chi Hạ", "Hào Quang Kiếm Vương Tái Thế", "Phi Phong & Danh Hiệu"),
    "jingyingsaiguanjun": ("Quán Quân Tinh Anh Sái", "Hào Quang Vô Địch Giải Đấu Tinh Anh", "VIP & Sự Kiện"),
    "jingyingsaiyajun": ("Á Quân Tinh Anh Sái", "Hào Quang Hạng Nhì Giải Đấu Tinh Anh", "VIP & Sự Kiện"),
    "jingyingsaijijun": ("Quý Quân Tinh Anh Sái", "Hào Quang Hạng Ba Giải Đấu Tinh Anh", "VIP & Sự Kiện"),
    "huangdi": ("Hoàng Đế Chí Tôn", "Hào Quang Cửu Ngũ Chí Tôn", "Phi Phong & Danh Hiệu"),
    "tianzi": ("Thiên Tử Giáng Trần", "Hào Quang Con Trời Oai Vọng", "Phi Phong & Danh Hiệu"),
    "dachengxiang": ("Đại Thừa Tướng", "Hào Quang Thừa Tướng Đầu Triều", "Phi Phong & Danh Hiệu"),
    "bingmayuanshuai": ("Binh Mã Nguyên Soái", "Hào Quang Đại Tướng Quân Thống Lĩnh", "Phi Phong & Danh Hiệu"),
    "xianfengguan": ("Tiên Phong Quan", "Hào Quang Tiên Phong Xung Trận", "Phi Phong & Danh Hiệu"),
    "ib_citymaster": ("Thành Chủ Thiên Hạ", "Hào Quang Bá Chủ Thành Trì", "Phi Phong & Danh Hiệu"),
    "chaoji_diyibang": ("Siêu Cấp Đệ Nhất Bang", "Hào Quang Bang Hội Hùng Mạnh Nhất", "VIP & Sự Kiện"),
    "pkno1tong": ("Đệ Nhất Bang PK", "Hào Quang Quán Quân PK Bang Hội", "VIP & Sự Kiện"),
    "longzhidui2": ("Long Chi Đội", "Hào Quang Đội Chiến Long Thần", "VIP & Sự Kiện"),
    "daithanh": ("Hào Quang Tề Thiên Đại Thánh", "Hào Quang Hoàng Kim Thần Giới", "VIP & Sự Kiện"),
    "sieuthan": ("Hào Quang Siêu Thần", "Vòng Sáng Siêu Thần Rực Rỡ", "VIP & Sự Kiện"),
    "tranthien": ("Hào Quang Trấn Thiên", "Vòng Sáng Trấn Giữ Càn Khôn", "VIP & Sự Kiện"),
    "phongvan": ("Hào Quang Phong Vân", "Vòng Sáng Phong Vân Biến Ảo", "VIP & Sự Kiện"),

    # Môn phái
    "sl_07": ("La Hán Trận", "Hào Quang Phản Đòn Thiếu Lâm", "Môn Phái"),
    "wd_07": ("Thất Tinh Trận", "Hào Quang Tăng Sát Thương Võ Đang", "Môn Phái"),
    "mag_tr_14": ("Ngũ Hành Trận", "Hào Quang Trận Pháp Thiên Nhẫn", "Môn Phái"),
    "wdu_06": ("Vô Hình Độc", "Hào Quang Độc Sát Ngũ Độc", "Môn Phái"),
    "mag_em_08": ("Lưu Thủy", "Hào Quang Tăng Tốc Độ Chạy Nga Mi", "Môn Phái"),
    "mag_em_10": ("Phật Tâm Từ Hữu", "Hào Quang Hồi Phục Sinh Lực/Nội Lực Nga Mi", "Môn Phái"),
    "mag_em_06": ("Thu Phong Diệp", "Hào Quang Thu Phong Diệp Nga Mi", "Môn Phái"),
    "mag_em_07": ("Túy Tiên Vọng Nguyệt", "Hào Quang Túy Tiên Vọng Nguyệt Nga Mi", "Môn Phái"),
    "mag_em_09": ("Mộng Điệp", "Hào Quang Mộng Điệp Nga Mi", "Môn Phái"),
    "em_qingyin": ("Thanh Âm Phạn Xướng", "Hào Quang Kháng Tất Cả Nga Mi", "Môn Phái"),
    "em_biyue": ("Phổ Độ Chúng Sinh", "Hào Quang Phổ Độ Chúng Sinh Nga Mi", "Môn Phái"),
    "mag_gb_12": ("Đả Cẩu Trận", "Hào Quang Trận Pháp Cái Bang", "Môn Phái"),

    # Sự kiện & Tiện ích
    "xingyunxing": ("Hạnh Vận Tinh", "Ngôi Sao May Mắn Quanh Chân", "VIP & Sự Kiện"),
    "taskfinish": ("Nhiệm Vụ Hoàn Thành", "Vòng Sáng Vinh Quang Hoàn Thành", "VIP & Sự Kiện"),
    "top_tong_bangzhu": ("Hào Quang Bang Chủ", "Vòng Sáng Bang Chủ Đệ Nhất Bang", "VIP & Sự Kiện"),
    "top_tong_bangzhong": ("Hào Quang Bang Chúng", "Vòng Sáng Thành Viên Bang", "VIP & Sự Kiện"),
    "dati": ("Trạng Nguyên Đáp Đề", "Hào Quang Học Vấn Đáp Đề", "VIP & Sự Kiện"),
    "vip_sc": ("Hào Quang VIP Tinh Diệu", "Vòng Sáng Tinh Quang Tôn Quý", "VIP & Sự Kiện"),
    "vip_sr": ("Hào Quang VIP Xích Diễm", "Vòng Sáng Xích Diễm Tôn Quý", "VIP & Sự Kiện"),
    "vip_sp": ("Hào Quang VIP Tử Kim", "Vòng Sáng Tử Kim Tôn Quý", "VIP & Sự Kiện"),
}


def get_all_paks():
    jx15 = vltk_source.paks()
    paks = list(jx15.paks)
    if os.path.exists(VNG_CLIENT):
        for f in os.listdir(os.path.join(VNG_CLIENT, "data")):
            if f.endswith(".pak"):
                paks.append(vltk_pak.PakFile(os.path.join(VNG_CLIENT, "data", f)))
    return paks


def read_spr_data(all_paks, spr_path):
    # 1. Thử đọc từ loose file nếu có
    base_name = os.path.basename(spr_path.replace("/", "\\"))
    loose = os.path.join(LOOSE_OTHERS, base_name)
    if os.path.isfile(loose):
        return open(loose, "rb").read()

    # 2. Thử đọc từ paks
    norm = vltk_pak.normalize(spr_path)
    uid = vltk_pak.file_name_to_id(norm)
    for p in all_paks:
        if uid in p.index:
            try:
                return p.read(uid)
            except Exception:
                pass
    return None


def export_single_aura(key, spr_data, anim_cache):
    fd, tmp_name = tempfile.mkstemp(suffix=".spr")
    with os.fdopen(fd, "wb") as f:
        f.write(spr_data)
    try:
        images, meta = spr_to_png.read_spr(tmp_name)
    except Exception as e:
        return None
    finally:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass

    boxes = [im.getbbox() for im in images if im.getbbox()]
    if not boxes:
        return None

    left, top = min(b[0] for b in boxes), min(b[1] for b in boxes)
    right, bottom = max(b[2] for b in boxes), max(b[3] for b in boxes)
    w, h = right - left, bottom - top
    count = len(images)
    cols = max(1, min(count, MAX_SHEET_WIDTH // max(w, 1)))
    rows = (count + cols - 1) // cols
    sheet = Image.new("RGBA", (w * cols, h * rows))
    for i, im in enumerate(images):
        sheet.paste(im.crop((left, top, right, bottom)), ((i % cols) * w, (i // cols) * h))

    OUT_PNG.mkdir(parents=True, exist_ok=True)
    out_file = OUT_PNG / f"{key}.png"
    luma_key_if_additive(sheet)
    sheet.save(out_file, optimize=True)

    anim_cache[key] = {
        "cols": cols,
        "dirs": meta.get("directions", 1),
        "frames": count,
        "offset": [left, top],
        "size": [w, h],
    }

    # Tạo thumbnail ảnh tĩnh xem trước (lấy frame tiêu biểu ở giữa)
    OUT_THUMBS.mkdir(parents=True, exist_ok=True)
    thumb_idx = min(len(images) // 2, len(images) - 1)
    thumb_im = images[thumb_idx].crop((left, top, right, bottom))
    # Resize vừa vặn trong khung 72x72 có lề
    tw, th = thumb_im.size
    scale = min(64.0 / max(tw, 1), 64.0 / max(th, 1))
    nw, nh = max(1, int(tw * scale)), max(1, int(th * scale))
    thumb_im = thumb_im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    canvas.paste(thumb_im, ((72 - nw) // 2, (72 - nh) // 2))
    thumb_file = OUT_THUMBS / f"{key}.png"
    canvas.save(thumb_file, optimize=True)

    return anim_cache[key]


def find_friendly_info(spr_path, status_id):
    lower = spr_path.lower()
    for pattern, info in AURA_NAMES.items():
        if pattern in lower:
            return info
    # Tên mặc định suy diễn từ tên file
    base = os.path.splitext(os.path.basename(spr_path.replace("/", "\\")))[0]
    clean_name = base.replace("_", " ").title()
    return (f"Hào Quang {clean_name}", f"Hào quang trạng thái #{status_id}", "Khác")


def main():
    print("=== BẮT ĐẦU QUÉT & NHẬP TOÀN BỘ HÀO QUANG (AURA) VLTK ===")
    all_paks = get_all_paks()
    print(f"Đã nạp {len(all_paks)} file pak từ client VLTK.")

    anims_path = DATA_DIR / "anims.json"
    states_path = DATA_DIR / "states.json"
    anims = json.loads(anims_path.read_text(encoding="utf-8")) if anims_path.exists() else {}
    states = json.loads(states_path.read_text(encoding="utf-8")) if states_path.exists() else {}

    # Đọc bảng trạng thái
    lines = open(STATE_TABLE, encoding="gbk", errors="ignore").readlines()
    print(f"Bảng bang_doichieu_trangthai_hieuung.txt có {len(lines)} dòng.")

    catalog = []
    seen_anims = set()
    processed_count = 0

    # 1. Duyệt tất cả dòng trong bảng trạng thái
    for idx in range(1, len(lines)):
        parts = lines[idx].strip().split("\t")
        if len(parts) < 3:
            continue
        status_name, spr_path, stype = parts[0], parts[1].strip(), parts[2].strip()
        play_mode = parts[3].strip() if len(parts) > 3 else "Loop"
        is_foot = stype.lower() == "foot"
        is_aura = any(w in spr_path.lower() for w in ["guanghuan", "title", "halo", "aura", "xingyun", "dati", "vip"])

        if not (is_foot or is_aura):
            continue

        spr_data = read_spr_data(all_paks, spr_path)
        if not spr_data:
            continue

        key = anim_key(spr_path)
        if key not in anims or not (OUT_PNG / f"{key}.png").exists():
            anim_info = export_single_aura(key, spr_data, anims)
            if not anim_info:
                continue
        else:
            # Vẫn tạo thumbnail nếu chưa có
            if not (OUT_THUMBS / f"{key}.png").exists():
                export_single_aura(key, spr_data, anims)

        anim_data = anims[key]
        frames = anim_data["frames"]
        dirs = anim_data["dirs"]
        interval = max(1, int(parts[8])) if len(parts) > 8 and parts[8].strip().isdigit() else 18

        # Cập nhật states.json
        states[str(idx)] = {
            "anim": key,
            "type": "Foot" if is_foot else "Body",
            "loop": play_mode == "Loop",
            "back_start": 0,
            "back_end": 0,
            "frames": frames,
            "dirs": dirs,
            "interval": interval,
        }

        name, desc, category = find_friendly_info(spr_path, idx)
        thumb_res = f"res://assets/ui/aura_thumbs/{key}.png"

        catalog.append({
            "id": f"state_{idx}",
            "state_id": idx,
            "name": name,
            "desc": desc,
            "category": category,
            "anim_key": key,
            "spr_path": spr_path,
            "thumb": thumb_res,
            "type": "Foot" if is_foot else "Body",
            "frames": frames,
            "interval": interval,
        })
        seen_anims.add(key)
        processed_count += 1
        print(f"  [{idx:3d}] {name:<30} -> {key}")

    # 2. Duyệt thêm các file loose trong Client_VLTK/spr/skill/others nếu chưa có trong catalog
    if os.path.exists(LOOSE_OTHERS):
        custom_id = 9000
        for f in sorted(os.listdir(LOOSE_OTHERS)):
            if not f.lower().endswith(".spr"):
                continue
            try:
                f.encode("gbk")
            except (UnicodeEncodeError, UnicodeDecodeError):
                continue
            spr_path = f"\\spr\\skill\\others\\{f}"
            try:
                key = anim_key(spr_path)
            except Exception:
                continue
            if key in seen_anims:
                continue
            loose_file = os.path.join(LOOSE_OTHERS, f)
            spr_data = open(loose_file, "rb").read()
            if not spr_data or len(spr_data) < 32:
                continue

            anim_info = export_single_aura(key, spr_data, anims)
            if not anim_info:
                continue

            custom_id += 1
            states[str(custom_id)] = {
                "anim": key,
                "type": "Foot",
                "loop": True,
                "back_start": 0,
                "back_end": 0,
                "frames": anim_info["frames"],
                "dirs": anim_info["dirs"],
                "interval": 18,
            }

            name, desc, category = find_friendly_info(f, custom_id)
            thumb_res = f"res://assets/ui/aura_thumbs/{key}.png"

            catalog.append({
                "id": f"custom_{custom_id}",
                "state_id": custom_id,
                "name": name,
                "desc": desc,
                "category": category,
                "anim_key": key,
                "spr_path": spr_path,
                "thumb": thumb_res,
                "type": "Foot",
                "frames": anim_info["frames"],
                "interval": 18,
            })
            seen_anims.add(key)
            processed_count += 1
            print(f"  [L{custom_id}] {name:<30} -> {key}")

    # Lưu lại anims.json và states.json
    anims_path.write_text(json.dumps(anims, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    states_path.write_text(json.dumps(states, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")

    # Lưu danh mục tổng hợp aura_catalog.json
    CATALOG_DIR.mkdir(parents=True, exist_ok=True)
    catalog_path = CATALOG_DIR / "aura_catalog.json"
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"\n=== HOÀN TẤT: Tổng cộng {len(catalog)} hào quang đã được nhập vào hệ thống! ===")
    print(f"Dữ liệu danh mục lưu tại: {catalog_path}")


if __name__ == "__main__":
    main()
