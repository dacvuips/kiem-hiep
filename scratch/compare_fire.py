import os
from PIL import Image

ref_img = Image.open('scratch/exact_fire_tau_thach.png').convert('RGBA')
print(f'Reference fire crop: size={ref_img.size}')

candidates = [
    'assets/skill_fx/gb_150_zhanggai_huo_acfa.png',
    'assets/skill_fx/sjzh_huo_7ac0.png',
    'assets/skill_fx/tr_150_jihuoliaoyuan_c_df65.png',
    'assets/campfire/sjzh_huo_sheet.png',
    'assets/campfire/yandihuoyan_sheet.png',
]

for c in candidates:
    if os.path.exists(c):
        im = Image.open(c)
        print(f'{c}: size={im.size}')
