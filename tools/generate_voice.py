"""
Công cụ xuất file Audio Text-to-Speech (TTS) cho game Kiếm Hiệp
Sử dụng thư viện edge-tts với giọng đọc AI tiếng Việt chất lượng cao.

Cách dùng:
    python tools/generate_voice.py --text "Nội dung cần đọc" --voice nam --output audio/sfx/death_notify.mp3
Các tùy chọn giọng:
    nam : vi-VN-NamMinhNeural (Nam Minh - trầm ấm, uy nghiêm kiếm hiệp)
    nu  : vi-VN-HoaiMyNeural  (Hoài My  - truyền cảm, mượt mà)
"""

import argparse
import asyncio
import os
import sys

# Ensure UTF-8 output on Windows console
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

VOICES = {
    "nam": "vi-VN-NamMinhNeural",
    "nu": "vi-VN-HoaiMyNeural",
    "namminh": "vi-VN-NamMinhNeural",
    "hoaimy": "vi-VN-HoaiMyNeural",
}

async def generate(text: str, voice_key: str, output_path: str, rate: str = "+0%", pitch: str = "+0Hz"):
    import edge_tts
    
    voice = VOICES.get(voice_key.lower(), voice_key)
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    
    print(f"[TTS] Đang tạo audio...")
    print(f"  - Giọng: {voice}")
    print(f"  - Nội dung: \"{text}\"")
    print(f"  - File xuất: {output_path}")
    
    communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    await communicate.save(output_path)
    print(f"[TTS] Xuất thành công: {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Tạo file âm thanh tiếng Việt từ Text")
    parser.add_argument("--text", type=str, default="Các hạ đã bị trọng thương, về thành dưỡng sức ngay!", help="Đoạn text cần đọc")
    parser.add_argument("--voice", type=str, default="nam", help="Giọng đọc: 'nam' (Nam Minh) hoặc 'nu' (Hoài My)")
    parser.add_argument("--output", type=str, default="audio/sfx/death_notify.mp3", help="Đường dẫn file mp3 đầu ra")
    parser.add_argument("--rate", type=str, default="+0%", help="Tốc độ đọc (VD: +10%%, -15%%)")
    parser.add_argument("--pitch", type=str, default="+0Hz", help="Cao độ giọng (VD: +5Hz, -5Hz)")
    
    args = parser.parse_args()
    asyncio.run(generate(args.text, args.voice, args.output, args.rate, args.pitch))

if __name__ == "__main__":
    main()
