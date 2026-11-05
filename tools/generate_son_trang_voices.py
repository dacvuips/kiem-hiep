import asyncio
import json
import os
import sys
import edge_tts

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

async def main():
    json_path = os.path.join("data", "son_trang", "welcome_dialogues.json")
    with open(json_path, "r", encoding="utf-8") as f:
        dialogues = json.load(f)

    out_dir = os.path.join("audio", "sfx", "son_trang")
    os.makedirs(out_dir, exist_ok=True)

    voice = "vi-VN-HoaiMyNeural"
    # Tốc độ nhanh hơn (+20%), cao độ nâng nhẹ (+5Hz) tạo phong cách hoạt bát, dứt khoát, thanh mảnh chuẩn NPC game kiếm hiệp
    rate = "+20%"
    pitch = "+5Hz"

    for item in dialogues:
        filename = item["file"]
        text = item["text"]
        out_path = os.path.join(out_dir, filename)
        
        print(f"[TTS] Đang tạo thoại {item['id']}: {filename} (rate={rate}, pitch={pitch})...")
        for attempt in range(1, 4):
            try:
                communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
                await communicate.save(out_path)
                print(f"[TTS] Thành công: {out_path} ({os.path.getsize(out_path)} bytes)")
                break
            except Exception as e:
                print(f"[TTS] Thử lại lần {attempt} do lỗi: {e}")
                await asyncio.sleep(2.5)
        
        # Chờ 2 giây giữa các request để tránh rate-limit
        await asyncio.sleep(2.0)

if __name__ == "__main__":
    asyncio.run(main())
