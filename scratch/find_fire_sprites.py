import os, json
from PIL import Image

with open('data/skill_fx/anims.json', 'r', encoding='utf-8') as f:
    anims = json.load(f)

# Find all pngs in assets/skill_fx
dir_path = 'assets/skill_fx'
fire_candidates = []

for fname in os.listdir(dir_path):
    if not fname.endswith('.png'): continue
    path = os.path.join(dir_path, fname)
    anim_key = fname[:-4]
    
    # We want to check if it has bright yellow/orange fire pixels
    try:
        im = Image.open(path).convert('RGBA')
        # Check first frame
        info = anims.get(anim_key, {})
        sz = info.get('size', [im.width, im.height])
        f0 = im.crop((0, 0, sz[0], sz[1]))
        
        # Count bright yellow/orange pixels (R > 210, G > 120, B < 80, A > 50)
        data = list(f0.getdata())
        yellow_fire = [p for p in data if p[0] > 200 and p[1] > 110 and p[2] < 90 and p[3] > 40]
        if len(yellow_fire) > 150:
            fire_candidates.append((anim_key, sz, len(yellow_fire), info.get('offset', [0, 0])))
    except Exception as e:
        pass

fire_candidates.sort(key=lambda x: x[2], reverse=True)
print(f"Total fire candidates: {len(fire_candidates)}")
for c in fire_candidates[:30]:
    print(c)
