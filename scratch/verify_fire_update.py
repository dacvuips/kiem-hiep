import json, os
from PIL import Image

# 1. Verify states.json & anims.json
with open('data/skill_fx/states.json', 'r', encoding='utf-8') as f:
    st = json.load(f)
assert st['100240']['anim'] == 'kinh_dao_fire'
assert st['240']['anim'] == 'kinh_dao_fire'
print('[OK] states.json configured correctly')

with open('data/skill_fx/anims.json', 'r', encoding='utf-8') as f:
    an = json.load(f)
assert 'kinh_dao_fire' in an
print('[OK] anims.json configured correctly')

# 2. Verify assets/skill_fx/kinh_dao_fire.png
tex = Image.open('assets/skill_fx/kinh_dao_fire.png')
assert tex.size == (640, 44)
print(f'[OK] assets/skill_fx/kinh_dao_fire.png valid: {tex.size}')

# 3. Create visual comparison artifact
user_crop = Image.open('scratch/exact_fire_1.png') # 75x42
our_frame0 = tex.crop((0, 0, 80, 44))
our_frame4 = tex.crop((4 * 80, 0, 5 * 80, 44))

comp = Image.new('RGBA', (320, 100), (40, 40, 45, 255))
# Paste user screenshot crop
comp.paste(user_crop, (20, 30))
# Paste frame 0
comp.paste(our_frame0, (120, 30), our_frame0)
# Paste frame 4
comp.paste(our_frame4, (220, 30), our_frame4)

comp.save('scratch/fire_visual_comparison.png')
print('[OK] Saved scratch/fire_visual_comparison.png')
