import os
import sys
import re
import json
import asyncio
import unicodedata
import edge_tts

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')


VOICE = "vi-VN-NamMinhNeural"
OUTPUT_DIR = "audio/voice_transitions"
CATALOG_PATH = "data/maps/map_catalog.json"
INDEX_PATH = os.path.join(OUTPUT_DIR, "map_voices.json")

def slugify(text: str) -> str:
    text = unicodedata.normalize('NFD', text)
    text = "".join(c for c in text if unicodedata.category(c) != 'Mn')
    text = text.replace('đ', 'd').replace('Đ', 'D')
    text = re.sub(r'[^a-zA-Z0-9]+', '_', text).strip('_').lower()
    return text

def clean_name(raw: str) -> str:
    s = raw.strip()
    s = re.sub(r'^Ải\s+\d+\s*·\s*', '', s)
    s = re.sub(r'\s*·.*$', '', s)
    s = re.sub(r'\s*\(\d+x?\)$', '', s)
    s = re.sub(r'\s*\(\d+\)$', '', s)
    # Fix typos in source data if any
    if s == "ác Bá Địa Đạo":
        s = "Ác Bá Địa Đạo"
    if s == "Trường Gian Nguyên Đầu":
        s = "Trường Giang Nguyên Đầu"
    if s == "Thanh khê Động":
        s = "Thanh Khê Động"
    if s == "Đáy Động Đình Hồ tầng 1":
        s = "Đáy Động Đình Hồ Tầng 1"
    if s == "Trường Bạch Sơn Nam 1":
        s = "Trường Bạch Sơn Nam"
    if s == "Trường Bạch Sơn Bắc 1":
        s = "Trường Bạch Sơn Bắc"
    if s == "Mạc Cao Quật (1)":
        s = "Mạc Cao Quật"
    if s.startswith("Thiên Tâm tháp"):
        s = s.replace("tháp", "Tháp")
    if s.startswith("Tần Lăng tầng"):
        s = s.replace("tầng", "Tầng")
    if s.startswith("Dược Vương Động tầng"):
        s = s.replace("tầng", "Tầng")
    return s.strip()

async def generate_file_with_retry(text: str, voice: str, out_path: str, max_retries: int = 3):
    if os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
        return True
    
    for attempt in range(max_retries):
        try:
            communicate = edge_tts.Communicate(text, voice)
            await communicate.save(out_path)
            if os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
                return True
        except Exception as e:
            if attempt == max_retries - 1:
                print(f"Error generating {out_path}: {e}")
                return False
            await asyncio.sleep(1.0 * (attempt + 1))
    return False

async def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Load catalog
    catalog = []
    if os.path.exists(CATALOG_PATH):
        with open(CATALOG_PATH, 'r', encoding='utf-8') as f:
            catalog = json.load(f).get('maps', [])
            
    map_dict = {}
    
    # Process catalog maps
    for m in catalog:
        raw = m.get('name', '').strip()
        c = clean_name(raw)
        if not c:
            continue
        slug = slugify(c)
        if slug not in map_dict:
            map_dict[slug] = {
                "name": c,
                "slug": slug,
                "file": f"{slug}.mp3",
                "raw_variants": set(),
                "text": f"Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào {c}!"
            }
        map_dict[slug]["raw_variants"].add(raw)
        map_dict[slug]["raw_variants"].add(c)
        if m.get('id'):
            map_dict[slug]["raw_variants"].add(f"map_{m.get('id')}")
            
    # Add special areas / stages
    specials = [
        ("Về Thành Dưỡng Sức", "ve_thanh_duong_suc", "Huynh đài hãy nắm chặt yên cương, ta cùng về thành dưỡng sức!"),
        ("Sơn Trang", "son_trang", "Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào Sơn Trang!"),
        ("Nguyệt Ca Đảo", "nguyet_ca_dao", "Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào Nguyệt Ca Đảo!"),
        ("Linh Lung Tháp", "linh_lung_thap", "Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào Linh Lung Tháp!"),
        ("Khu Chuẩn Bị Linh Lung Tháp", "khu_chuan_bi_linh_lung_thap", "Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào Khu Chuẩn Bị Linh Lung Tháp!"),
        ("Hiệp Phong Luận Kiếm", "hiep_phong_luan_kiem", "Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào Hiệp Phong Luận Kiếm!"),
        ("Bảo Vệ Trụ Danh Dự", "bao_ve_tru_danh_du", "Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào Bảo Vệ Trụ Danh Dự!"),
        ("Chiến Trường Tống Kim", "tong_kim_dai_chien", "Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào Chiến Trường Tống Kim!"),
        ("Mặc Định", "default_transition", "Huynh đài hãy nắm chặt yên cương, ta cùng lên đường xuất chinh!")
    ]
    
    for name, slug, text in specials:
        if slug not in map_dict:
            map_dict[slug] = {
                "name": name,
                "slug": slug,
                "file": f"{slug}.mp3",
                "raw_variants": {name, slug},
                "text": text
            }
        else:
            map_dict[slug]["text"] = text
            map_dict[slug]["raw_variants"].add(name)

    # 12 Stage Names
    for i in range(1, 13):
        stage_title = f"Ải {i}"
        # also match stage raw
        stage_prefix = f"Ải {i} ·"
        for slug, data in map_dict.items():
            for rv in list(data["raw_variants"]):
                if rv in [
                    "Giang Tân Thôn (1x)", "Hoa Sơn (2x)", "Thanh Thành Sơn (3x)", "Thục Cương Sơn (4x)",
                    "Tây Phục Ngưu Sơn (5x)", "Hoàng Hà Nguyên Đầu (6x)", "Hành Sơn (7x)", "Lâm Du Quan (8x)",
                    "Chân Núi Trường Bạch (9x)", "Trường Bạch Sơn Nam (10x)", "Trường Bạch Sơn Bắc (11x)", "Nguyệt Ca Đảo (12x)"
                ]:
                    data["raw_variants"].add(f"Ải {i} · {rv}")

    print(f"Total unique map transition voices to generate: {len(map_dict)}")

    # Generate each file
    success = 0
    failed = 0
    items = list(map_dict.values())
    
    for idx, item in enumerate(items):
        out_path = os.path.join(OUTPUT_DIR, item["file"])
        if os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
            success += 1
            continue
            
        print(f"[{idx+1}/{len(items)}] Generating {item['file']}: {item['text']}")
        ok = await generate_file_with_retry(item["text"], VOICE, out_path)
        if ok:
            success += 1
        else:
            failed += 1
        await asyncio.sleep(0.15)
        
    print(f"\nCompleted! Success: {success}, Failed: {failed}")
    
    # Save index json
    index_data = {}
    for slug, item in map_dict.items():
        index_data[slug] = {
            "name": item["name"],
            "file": f"res://{OUTPUT_DIR}/{item['file']}".replace("\\", "/"),
            "text": item["text"],
            "variants": list(item["raw_variants"])
        }
        
    with open(INDEX_PATH, 'w', encoding='utf-8') as f:
        json.dump(index_data, f, ensure_ascii=False, indent=2)
        
    print(f"Index written to {INDEX_PATH}")

if __name__ == "__main__":
    asyncio.run(main())
