import json
import os

with open('data/skill_fx/anims.json', 'r', encoding='utf-8') as f:
    anims = json.load(f)

print(f'Total anims: {len(anims)}')
count = 0
for k, v in anims.items():
    if not isinstance(v, dict):
        continue
    sz = v.get('size', [0, 0])
    if 60 <= sz[0] <= 120 and 20 <= sz[1] <= 60:
        count += 1
        print(f"{k}: size={sz}, frames={v.get('frames')}, dirs={v.get('dirs')}, offset={v.get('offset')}")
        if count >= 40:
            print("... and more")
            break
