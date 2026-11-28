"""Tạo thoại cảnh báo vòng bo PUBG (giọng nam trầm, đọc nhanh) -> audio/sfx/pubg/*.mp3.

Chạy:  python tools/generate_pubg_zone_voices.py
Cần:   pip install edge-tts
"""
import asyncio
import os
import sys

import edge_tts

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

VOICE = "vi-VN-NamMinhNeural"   # giọng nam
RATE = "+15%"                   # đọc nhanh, dứt khoát
PITCH = "-14Hz"                 # trầm

LINES = [
    ("zone_warn_120.mp3", "Hiệp khách lưu ý! Vòng bo sẽ thu hẹp lại sau một trăm hai mươi giây nữa. Hãy nhanh chóng di chuyển vào trong vòng bo ngay!"),
    ("zone_warn_60.mp3", "Hiệp khách lưu ý! Vòng bo sẽ thu hẹp lại sau sáu mươi giây nữa. Hãy nhanh chóng di chuyển vào trong vòng bo ngay!"),
]


async def main() -> None:
    out_dir = os.path.join("audio", "sfx", "pubg")
    os.makedirs(out_dir, exist_ok=True)
    for filename, text in LINES:
        out_path = os.path.join(out_dir, filename)
        if os.path.exists(out_path) and os.path.getsize(out_path) > 0 and "--force" not in sys.argv:
            print(f"[TTS] Đã có {out_path}, bỏ qua (thêm --force để tạo lại)")
            continue
        tmp_path = out_path + ".tmp"   # ghi ra file tạm, thành công mới thay file cũ (lỗi không làm mất thoại đang có)
        for attempt in range(1, 13):
            try:
                await edge_tts.Communicate(text, VOICE, rate=RATE, pitch=PITCH).save(tmp_path)
                if os.path.getsize(tmp_path) > 0:
                    os.replace(tmp_path, out_path)
                    print(f"[TTS] {out_path} ({os.path.getsize(out_path)} bytes)")
                    break
            except Exception as e:  # mạng chập chờn / rate-limit
                print(f"[TTS] Thử lại lần {attempt}: {e}")
                await asyncio.sleep(3.0)
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        await asyncio.sleep(1.5)


if __name__ == "__main__":
    asyncio.run(main())
