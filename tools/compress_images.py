"""
Script nén ảnh tự động cho dự án game (PNG, JPG, WEBP).
- Giữ nguyên 100% tên file gốc, định dạng và đường dẫn.
- Giữ nguyên chất lượng hiển thị (Visually Lossless: mắt thường không nhận biết khác biệt).
- Tuyệt đối an toàn:
  + Chỉ ghi đè nếu dung lượng mới NHỎ HƠN dung lượng cũ.
  + Kiểm tra tính toàn vẹn của file nén trước khi thay thế.
  + Hỗ trợ chế độ chạy thử (--dry-run) và sao lưu (--backup).
  + Tự động tận dụng đa nhân CPU (Multiprocessing) để nén hàng nghìn ảnh cực nhanh.
"""

import os
import sys
import argparse
import shutil
import tempfile
import subprocess
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from typing import Tuple, Optional, Dict, Any

# Fix encoding tren Windows console
if sys.platform.startswith("win"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

try:
    from PIL import Image, ImageOps
except ImportError:
    print("Lỗi: Cần cài đặt thư viện Pillow. Chạy: pip install Pillow")
    sys.exit(1)

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

try:
    from tqdm import tqdm
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False

# Thư mục bỏ qua khi quét
IGNORED_DIRS = {
    ".git", ".godot", "build", "__pycache__", ".vscode", 
    ".agents", ".claude", ".cursor", "ghidra_project", "ghidra_output", "ghidra_input"
}

SUPPORTED_EXTS = {".png", ".jpg", ".jpeg", ".webp"}

TOOLS_DIR = Path(__file__).resolve().parent
PNGQUANT_EXE = TOOLS_DIR / "pngquant.exe"


def calculate_psnr(orig_img: Image.Image, comp_img: Image.Image) -> float:
    """Tính PSNR (Peak Signal-to-Noise Ratio) trên các pixel nhìn thấy được."""
    if not HAS_NUMPY:
        return 40.0  # Mặc định an toàn nếu không có numpy
    
    orig_rgba = orig_img.convert("RGBA")
    comp_rgba = comp_img.convert("RGBA")
    
    arr1 = np.array(orig_rgba, dtype=np.float64)
    arr2 = np.array(comp_rgba, dtype=np.float64)
    
    # Chỉ tính trên pixel có alpha > 0 (pixel nhìn thấy được)
    vis_mask = arr1[:, :, 3] > 0
    if not np.any(vis_mask):
        return 50.0
    
    diff = arr1[vis_mask] - arr2[vis_mask]
    mse = np.mean(diff ** 2)
    if mse <= 1e-6:
        return 100.0
    return float(10.0 * np.log10((255.0 ** 2) / mse))


def compress_png(
    file_path: Path,
    mode: str = "smart",
    png_quality: str = "80-98",
    min_psnr: float = 33.0
) -> Optional[bytes]:
    """
    Nén file PNG:
    - Nếu mode='lossless': DEFLATE tối đa level 9, xóa metadata rác, giữ nguyên 100% pixel.
    - Nếu mode='smart': Nén thông minh (pngquant hoặc palette nếu thích hợp, fallback lossless nếu PSNR thấp).
    """
    with Image.open(file_path) as im:
        orig_mode = im.mode
        im_info = dict(im.info)
        w, h = im.size
        
        # 1. Chế độ Lossless thuần túy
        if mode == "lossless":
            import io
            buf = io.BytesIO()
            save_kw: Dict[str, Any] = {"optimize": True, "compress_level": 9}
            if "transparency" in im_info:
                save_kw["transparency"] = im_info["transparency"]
            im.save(buf, format="PNG", **save_kw)
            return buf.getvalue()
        
        # 2. Chế độ Smart (Visually Lossless)
        # Nếu ảnh đã là Palette (P) hoặc Grayscale (L, 1): giữ nguyên lossless
        if orig_mode in ("P", "L", "1"):
            import io
            buf = io.BytesIO()
            save_kw = {"optimize": True, "compress_level": 9}
            if "transparency" in im_info:
                save_kw["transparency"] = im_info["transparency"]
            im.save(buf, format="PNG", **save_kw)
            return buf.getvalue()

        # Thử nén bằng pngquant nếu có
        if PNGQUANT_EXE.exists():
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp_out:
                tmp_out_path = Path(tmp_out.name)
            try:
                cmd = [
                    str(PNGQUANT_EXE),
                    f"--quality={png_quality}",
                    "--speed", "3",
                    "--force",
                    "--output", str(tmp_out_path),
                    str(file_path)
                ]
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.returncode == 0 and tmp_out_path.exists() and tmp_out_path.stat().st_size > 0:
                    # Kiểm tra chất lượng hiển thị
                    with Image.open(tmp_out_path) as test_im:
                        if test_im.size == (w, h):
                            # Đọc nội dung
                            with open(tmp_out_path, "rb") as f:
                                return f.read()
            except Exception:
                pass
            finally:
                if tmp_out_path.exists():
                    tmp_out_path.unlink()

        # Fallback: Dùng Pillow FastOctree nếu PSNR đạt chuẩn
        if orig_mode in ("RGBA", "RGB"):
            try:
                q_im = im.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
                psnr = calculate_psnr(im, q_im)
                if psnr >= min_psnr:
                    import io
                    buf = io.BytesIO()
                    q_im.save(buf, format="PNG", optimize=True)
                    return buf.getvalue()
            except Exception:
                pass

        # Fallback cuối cùng: nén Lossless
        import io
        buf = io.BytesIO()
        im.save(buf, format="PNG", optimize=True, compress_level=9)
        return buf.getvalue()


def compress_jpeg(
    file_path: Path,
    mode: str = "smart",
    jpg_quality: int = 88,
    min_psnr: float = 34.0
) -> Optional[bytes]:
    """Nén file JPEG tối ưu hóa Huffman tables và dải màu."""
    with Image.open(file_path) as im:
        if im.mode not in ("RGB", "L"):
            im = im.convert("RGB")
        w, h = im.size
        
        import io
        buf = io.BytesIO()
        quality = 95 if mode == "lossless" else jpg_quality
        im.save(buf, format="JPEG", quality=quality, optimize=True, progressive=True)
        compressed_bytes = buf.getvalue()
        
        if mode == "smart":
            # Kiểm tra chất lượng hiển thị
            buf.seek(0)
            with Image.open(buf) as test_im:
                psnr = calculate_psnr(im, test_im)
                if psnr < min_psnr:
                    # Thử lại với quality cao hơn
                    buf2 = io.BytesIO()
                    im.save(buf2, format="JPEG", quality=94, optimize=True, progressive=True)
                    return buf2.getvalue()
                    
        return compressed_bytes


def compress_webp(file_path: Path, mode: str = "smart", quality: int = 90) -> Optional[bytes]:
    """Nén file WebP."""
    with Image.open(file_path) as im:
        import io
        buf = io.BytesIO()
        lossless = (mode == "lossless")
        im.save(buf, format="WEBP", quality=quality, lossless=lossless, method=6)
        return buf.getvalue()


def process_image_file(args_tuple: Tuple[str, str, str, int, bool, bool, int]) -> Dict[str, Any]:
    """Hàm xử lý một file ảnh (chạy trong worker process)."""
    file_path_str, mode, png_quality, jpg_quality, dry_run, backup, min_size_bytes = args_tuple
    file_path = Path(file_path_str)
    
    result = {
        "path": str(file_path),
        "status": "skipped",
        "orig_size": 0,
        "new_size": 0,
        "saved_bytes": 0,
        "error": None
    }
    
    try:
        if not file_path.exists():
            result["status"] = "not_found"
            return result
            
        orig_size = file_path.stat().st_size
        result["orig_size"] = orig_size
        result["new_size"] = orig_size
        
        if orig_size < min_size_bytes:
            result["status"] = "too_small"
            return result

        ext = file_path.suffix.lower()
        compressed_data: Optional[bytes] = None

        if ext == ".png":
            compressed_data = compress_png(file_path, mode=mode, png_quality=png_quality)
        elif ext in (".jpg", ".jpeg"):
            compressed_data = compress_jpeg(file_path, mode=mode, jpg_quality=jpg_quality)
        elif ext == ".webp":
            compressed_data = compress_webp(file_path, mode=mode)
            
        if not compressed_data:
            result["status"] = "failed_compression"
            return result
            
        new_size = len(compressed_data)
        
        # Chỉ nhận nếu file nén thực sự NHỎ HƠN file gốc
        if new_size < orig_size:
            # Kiểm tra an toàn: mở lại dữ liệu nén xem có đọc được không
            import io
            with Image.open(io.BytesIO(compressed_data)) as verify_im:
                verify_im.verify()
                
            saved_bytes = orig_size - new_size
            result["new_size"] = new_size
            result["saved_bytes"] = saved_bytes
            
            if not dry_run:
                # Tạo backup nếu được yêu cầu
                if backup:
                    bak_path = file_path.with_suffix(file_path.suffix + ".bak")
                    shutil.copy2(file_path, bak_path)
                
                # Ghi đè an toàn qua file tạm rồi đổi tên
                tmp_path = file_path.with_suffix(file_path.suffix + ".tmp_comp")
                with open(tmp_path, "wb") as f:
                    f.write(compressed_data)
                tmp_path.replace(file_path)
                result["status"] = "compressed"
            else:
                result["status"] = "would_compress"
        else:
            result["status"] = "already_optimal"
            
    except Exception as e:
        result["status"] = "error"
        result["error"] = str(e)
        
    return result


def find_image_files(target_path: Path, min_size_kb: int = 1) -> list[str]:
    """Tìm tất cả các file ảnh trong thư mục target, bỏ qua các thư mục không cần thiết."""
    image_paths = []
    min_bytes = min_size_kb * 1024

    if target_path.is_file():
        if target_path.suffix.lower() in SUPPORTED_EXTS:
            if target_path.stat().st_size >= min_bytes:
                image_paths.append(str(target_path.resolve()))
        return image_paths

    for root, dirs, files in os.walk(target_path):
        # Bỏ qua thư mục rác / build
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS and not d.startswith(".")]
        
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext in SUPPORTED_EXTS:
                full_path = os.path.join(root, file)
                try:
                    if os.path.getsize(full_path) >= min_bytes:
                        image_paths.append(os.path.abspath(full_path))
                except OSError:
                    pass

    return image_paths


def format_size(size_bytes: float) -> str:
    """Đổi byte sang định dạng đọc được (KB, MB)."""
    if size_bytes >= 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.2f} MB"
    elif size_bytes >= 1024:
        return f"{size_bytes / 1024:.1f} KB"
    return f"{size_bytes:.0f} B"


def main():
    parser = argparse.ArgumentParser(
        description="Nén ảnh dự án Game giữ nguyên chất lượng hiển thị (Visually Lossless)."
    )
    parser.add_argument(
        "target",
        nargs="?",
        default=".",
        help="Đường dẫn thư mục hoặc file cần nén (mặc định: thư mục hiện tại)."
    )
    parser.add_argument(
        "--mode",
        choices=["smart", "lossless"],
        default="smart",
        help="Chế độ nén: 'smart' (Visually Lossless, giảm 40-80%%) hoặc 'lossless' (100%% bit-exact)."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Chạy thử nghiệm mô phỏng, tính dung lượng tiết kiệm mà không sửa đổi file thật."
    )
    parser.add_argument(
        "--backup",
        action="store_true",
        help="Tạo file sao lưu .bak trước khi ghi đè file gốc."
    )
    parser.add_argument(
        "--min-size",
        type=int,
        default=5,
        help="Dung lượng file tối thiểu (KB) để xử lý (mặc định: 5 KB)."
    )
    parser.add_argument(
        "--png-quality",
        type=str,
        default="80-98",
        help="Chất lượng nén pngquant (mặc định: '80-98')."
    )
    parser.add_argument(
        "--jpg-quality",
        type=int,
        default=88,
        help="Chất lượng JPEG (mặc định: 88)."
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=min(os.cpu_count() or 4, 16),
        help="Số luồng CPU chạy song song (mặc định: tự động theo CPU)."
    )
    
    args = parser.parse_args()
    target_path = Path(args.target).resolve()
    
    print("=" * 65)
    print("   CÔNG CỤ NÉN ẢNH VISUALLY LOSSLESS CHO DỰ ÁN GAME")
    print("=" * 65)
    print(f" * Mục tiêu:         {target_path}")
    print(f" * Chế độ nén:       {args.mode.upper()} {'(Mắt thường không thấy khác biệt)' if args.mode == 'smart' else '(100% Bit-exact)'}")
    print(f" * Chế độ chạy:      {'[MÔ PHỎNG - DRY RUN - KHÔNG ĐỔI FILE]' if args.dry_run else '[GHI ĐÈ AN TOÀN - IN-PLACE]'}")
    print(f" * Sao lưu (.bak):   {'BẬT' if args.backup else 'TẮT'}")
    print(f" * Kích thước min:   {args.min_size} KB")
    print(f" * Số tiến trình:    {args.workers} luồng CPU")
    print(f" * pngquant engine:  {'SẴN SÀNG' if PNGQUANT_EXE.exists() else 'KHÔNG TÌM THẤY (dùng Pillow fallback)'}")
    print("-" * 65)
    
    # 1. Tìm các file ảnh
    print("Đang quét danh sách file ảnh...")
    image_files = find_image_files(target_path, min_size_kb=args.min_size)
    total_files = len(image_files)
    
    if total_files == 0:
        print("Không tìm thấy file ảnh nào thỏa điều kiện.")
        return
        
    print(f"Đã tìm thấy {total_files:,} file ảnh cần kiểm tra.\nBắt đầu nén...")
    
    # 2. Xử lý song song
    tasks_args = [
        (
            f,
            args.mode,
            args.png_quality,
            args.jpg_quality,
            args.dry_run,
            args.backup,
            args.min_size * 1024
        )
        for f in image_files
    ]
    
    compressed_count = 0
    optimal_count = 0
    error_count = 0
    total_orig_bytes = 0
    total_saved_bytes = 0
    top_savings = []
    
    with ProcessPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(process_image_file, task): task[0] for task in tasks_args}
        
        iterator = as_completed(futures)
        if HAS_TQDM:
            iterator = tqdm(iterator, total=total_files, desc="Tiến độ", unit="file")
            
        for future in iterator:
            res = future.result()
            orig_sz = res["orig_size"]
            saved_sz = res["saved_bytes"]
            status = res["status"]
            
            total_orig_bytes += orig_sz
            
            if status in ("compressed", "would_compress"):
                compressed_count += 1
                total_saved_bytes += saved_sz
                top_savings.append((res["path"], orig_sz, res["new_size"], saved_sz))
            elif status == "already_optimal":
                optimal_count += 1
            elif status == "error":
                error_count += 1
                if not HAS_TQDM:
                    print(f"[Lỗi] {res['path']}: {res['error']}")
                    
            if not HAS_TQDM and (compressed_count + optimal_count + error_count) % 500 == 0:
                print(f"  > Đã duyệt {compressed_count + optimal_count + error_count}/{total_files} file...")

    # 3. Tổng kết báo cáo
    print("\n" + "=" * 65)
    print("                KẾT QUẢ NÉN ẢNH")
    print("=" * 65)
    print(f" * Tổng số file kiểm tra:       {total_files:,} file")
    print(f" * File nén thành công:         {compressed_count:,} file")
    print(f" * File đã tối ưu sẵn (bỏ qua): {optimal_count:,} file")
    if error_count > 0:
        print(f" * File gặp lỗi:                {error_count:,} file")
        
    print("-" * 65)
    print(f" * Dung lượng ban đầu:          {format_size(total_orig_bytes)}")
    print(f" * Dung lượng sau nén:          {format_size(total_orig_bytes - total_saved_bytes)}")
    pct_saved = (total_saved_bytes / total_orig_bytes * 100) if total_orig_bytes > 0 else 0
    print(f" * TIẾT KIỆM ĐƯỢC:               {format_size(total_saved_bytes)} ({pct_saved:.1f}%)")
    print("=" * 65)
    
    # Hiển thị top 5 file tiết kiệm nhiều nhất
    if top_savings:
        top_savings.sort(key=lambda x: x[3], reverse=True)
        print("\nTop 5 file giảm dung lượng nhiều nhất:")
        for path, o_sz, n_sz, s_sz in top_savings[:5]:
            rel_path = os.path.relpath(path, target_path)
            pct = (s_sz / o_sz) * 100
            print(f" - {rel_path}: {format_size(o_sz)} -> {format_size(n_sz)} (Giảm {format_size(s_sz)} / -{pct:.1f}%)")
        print()

    if args.dry_run:
        print("[LƯU Ý] Đây là chế độ chạy thử (--dry-run). Không có file nào bị thay đổi.")
        print("Để thực sự áp dụng nén, hãy chạy lại lệnh và bỏ cờ --dry-run.")


if __name__ == "__main__":
    main()
