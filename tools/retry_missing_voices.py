import os
import sys
import json
import asyncio
import edge_tts

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

INDEX_PATH = "audio/voice_transitions/map_voices.json"
VOICE = "vi-VN-NamMinhNeural"

async def generate_single(text, voice, out_path):
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(out_path)

async def main():
    if not os.path.exists(INDEX_PATH):
        print("Index file not found yet.")
        return

    with open(INDEX_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Check which files need regeneration
    to_retry = []
    for slug, info in data.items():
        file_path = info["file"].replace("res://", "")
        if not os.path.exists(file_path) or os.path.getsize(file_path) < 1000:
            if os.path.exists(file_path):
                try:
                    os.remove(file_path)
                except:
                    pass
            to_retry.append((slug, info["name"], info["text"], file_path))

    print(f"Total files needing generation: {len(to_retry)}")
    if not to_retry:
        print("All audio files are complete and valid!")
        return

    success = 0
    failed = 0
    for idx, (slug, name, text, path) in enumerate(to_retry):
        print(f"[{idx+1}/{len(to_retry)}] Generating {os.path.basename(path)}: {text}")
        ok = False
        for attempt in range(4):
            try:
                await generate_single(text, VOICE, path)
                if os.path.exists(path) and os.path.getsize(path) > 1000:
                    ok = True
                    break
            except Exception as e:
                await asyncio.sleep(1.0 * (attempt + 1))
        if ok:
            success += 1
            print(f" -> OK ({os.path.getsize(path)} bytes)")
        else:
            failed += 1
            print(" -> FAILED")
        await asyncio.sleep(0.4)

    print(f"Finished retry! Success: {success}, Failed: {failed}")

if __name__ == "__main__":
    asyncio.run(main())
