"""Script loại bỏ lớp viền / hộp nhiễu trắng mờ (alpha <= 10, RGB >= 240)
trong các file assets/skill_fx/*.png do luma_key_if_additive của SPR để lại.
"""
import os
import sys
from PIL import Image

SKILL_FX_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "skill_fx")

def clean_file(path: str) -> int:
    try:
        im = Image.open(path).convert("RGBA")
    except Exception:
        return 0

    raw = bytearray(im.tobytes())
    cleaned = 0
    total = len(raw) // 4
    for i in range(0, len(raw), 4):
        r, g, b, a = raw[i], raw[i+1], raw[i+2], raw[i+3]
        if r >= 240 and g >= 240 and b >= 240 and 0 < a <= 10:
            raw[i] = raw[i+1] = raw[i+2] = raw[i+3] = 0
            cleaned += 1

    # Chỉ ghi đè nếu có ít nhất 50 pixel nhiễu trắng mờ
    if cleaned >= 50:
        fixed_im = Image.frombytes("RGBA", im.size, bytes(raw))
        fixed_im.save(path, optimize=True)
    return cleaned

def main():
    if not os.path.isdir(SKILL_FX_DIR):
        print("Không tìm thấy thư mục:", SKILL_FX_DIR)
        return

    files = [f for f in os.listdir(SKILL_FX_DIR) if f.endswith(".png")]
    print(f"Bắt đầu quét {len(files)} file trong {SKILL_FX_DIR}...")
    
    total_cleaned_files = 0
    total_cleaned_pixels = 0
    
    for f in sorted(files):
        p = os.path.join(SKILL_FX_DIR, f)
        count = clean_file(p)
        if count >= 50:
            total_cleaned_files += 1
            total_cleaned_pixels += count
            print(f"  Đã dọn {f}: {count} pixel nhiễu trắng")

    print(f"\nHoàn tất! Đã xử lý {total_cleaned_files} files, loại bỏ {total_cleaned_pixels} pixel trắng mờ.")

if __name__ == "__main__":
    main()
