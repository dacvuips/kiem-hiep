import os
import sys
import asyncio
import edge_tts

if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

samples = [
    {
        "file": "audio_samples/giong_chuan.mp3",
        "text": "Xin chào chư vị huynh đệ. Ta là Nam Minh. Chúc các vị một ngày hành tẩu giang hồ thuận buồm xuôi gió!",
        "voice": "vi-VN-NamMinhNeural",
        "rate": "+0%",
        "pitch": "+0Hz",
        "desc": "Giọng tiêu chuẩn / Giới thiệu tự nhiên"
    },
    {
        "file": "audio_samples/tien_boi_tram_am.mp3",
        "text": "Thiếu hiệp, võ học vô biên, dục tốc bất đạt. Muốn bước chân vào giang hồ tranh hùng, trước tiên tâm pháp phải thật vững vàng.",
        "voice": "vi-VN-NamMinhNeural",
        "rate": "-12%",
        "pitch": "-12Hz",
        "desc": "Giọng Tiền bối / Bang chủ trầm ấm, uy nghiêm"
    },
    {
        "file": "audio_samples/dai_hiep_hao_sang.mp3",
        "text": "Gặp chuyện bất bình, rút kiếm tương trợ! Kẻ nào dám ỷ mạnh hiếp yếu, trước tiên hãy hỏi qua thanh kiếm trong tay ta!",
        "voice": "vi-VN-NamMinhNeural",
        "rate": "+6%",
        "pitch": "-2Hz",
        "desc": "Giọng Kiếm khách / Đại hiệp hào sảng, mạnh mẽ"
    }
]

async def generate():
    os.makedirs("audio_samples", exist_ok=True)
    for s in samples:
        print(f"Generating {s['file']}...")
        communicate = edge_tts.Communicate(s["text"], s["voice"], rate=s["rate"], pitch=s["pitch"])
        await communicate.save(s["file"])
    print("All samples generated successfully!")

if __name__ == "__main__":
    asyncio.run(generate())

