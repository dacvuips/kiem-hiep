"""Gom toàn bộ sprite của 57 map vào thư mục chung world/maps/shared_sprites/.
Loại bỏ 3,040 file sprite trùng lặp giữa các map, giải phóng ~106 MB PNG thô
và ~168 MB dung lượng .ctex đóng gói trong maps.pck.

Chạy:
    python tools/consolidate_map_sprites.py [--dry-run]
"""
import os
import shutil
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parent.parent
MAPS_DIR = ROOT / "world" / "maps"
SHARED_DIR = MAPS_DIR / "shared_sprites"


def main():
    dry_run = "--dry-run" in sys.argv
    print(f"=== {'[DRY-RUN] ' if dry_run else ''}Gom Sprite Dùng Chung Cho 57 Bản Đồ ===")

    if not dry_run:
        SHARED_DIR.mkdir(parents=True, exist_ok=True)

    all_sprites = list(MAPS_DIR.glob("*/sprites/*.png"))
    # Exclude shared_sprites if it was somehow scanned
    all_sprites = [p for p in all_sprites if p.parent.parent.name != "shared_sprites"]

    print(f"Tổng số sprite quét được: {len(all_sprites)} files")

    unique_names: dict[str, Path] = {}
    duplicates: list[Path] = []

    for p in all_sprites:
        name = p.name
        if name not in unique_names:
            unique_names[name] = p
        else:
            duplicates.append(p)

    print(f"Số sprite độc nhất: {len(unique_names)}")
    print(f"Số file trùng lặp sẽ loại bỏ: {len(duplicates)}")

    total_orig_bytes = sum(p.stat().st_size for p in all_sprites)
    unique_bytes = sum(p.stat().st_size for p in unique_names.values())
    saved_bytes = total_orig_bytes - unique_bytes

    print(f"Dung lượng ban đầu: {total_orig_bytes / (1024*1024):.2f} MB")
    print(f"Dung lượng sau khi gom: {unique_bytes / (1024*1024):.2f} MB")
    print(f"Tiết kiệm PNG thô: {saved_bytes / (1024*1024):.2f} MB")

    if dry_run:
        print("[DRY-RUN] Hoàn tất kiểm tra, chưa thay đổi file.")
        return

    # Bước 1: Copy các unique sprite vào shared_sprites
    copied = 0
    for name, src_path in unique_names.items():
        dst_path = SHARED_DIR / name
        if not dst_path.exists():
            shutil.copy2(src_path, dst_path)
            copied += 1
    print(f"Đã copy {copied} sprite mới vào {SHARED_DIR.relative_to(ROOT)}")

    # Kiểm tra tính toàn vẹn: mọi unique sprite phải tồn tại ở SHARED_DIR
    missing = [name for name in unique_names if not (SHARED_DIR / name).exists()]
    if missing:
        print(f"LỖI: Có {len(missing)} sprite bị thiếu trong shared_sprites! Huỷ bỏ dọn dẹp.")
        sys.exit(1)

    # Bước 2: Xoá các file PNG và .import trong từng map_xxx/sprites
    removed_png = 0
    removed_import = 0
    for p in all_sprites:
        try:
            p.unlink()
            removed_png += 1
        except Exception as e:
            print(f"Lỗi xoá {p}: {e}")

        import_file = p.with_name(p.name + ".import")
        if import_file.exists():
            try:
                import_file.unlink()
                removed_import += 1
            except Exception as e:
                print(f"Lỗi xoá {import_file}: {e}")

    # Bước 3: Xoá các thư mục sprites rỗng
    removed_dirs = 0
    for map_folder in MAPS_DIR.iterdir():
        if map_folder.is_dir() and map_folder.name.startswith("map_"):
            s_dir = map_folder / "sprites"
            if s_dir.exists() and s_dir.is_dir():
                try:
                    if not any(s_dir.iterdir()):
                        s_dir.rmdir()
                        removed_dirs += 1
                except Exception:
                    pass

    print(f"Đã xoá {removed_png} file PNG và {removed_import} file .import trong các thư mục map.")
    print(f"Đã dọn dẹp {removed_dirs} thư mục sprites rỗng.")
    print("HOÀN TẤT THÀNH CÔNG!")


if __name__ == "__main__":
    main()
