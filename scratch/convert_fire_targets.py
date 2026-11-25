import sys, os
sys.path.insert(0, 'tools')
import vltk_source, spr_to_png

targets = [
    r'spr\skill\npc\投石火.spr',
    r'spr\skill\npc\投石火爆炸.spr',
    r'spr\skill\tm\地焰火.spr',
    r'spr\skill\tr\zd_业火焚城.spr',
    r'spr\skill\tr\业火焚城.spr',
    r'spr\skill\天忍\mag_tr_06_火盾.spr',
    r'spr\skill\天忍\mag_tr_bz1_爆炸效果.spr',
    r'spr\skill\昆仑\kl_08_烈火红尘.spr',
]

os.makedirs('scratch/fire_check', exist_ok=True)
for spr in targets:
    data = vltk_source.client_file(spr)
    if data:
        base = os.path.basename(spr).replace('.spr', '')
        tmp_spr = f'scratch/fire_check/{base}.spr'
        out_png = f'scratch/fire_check/{base}.png'
        with open(tmp_spr, 'wb') as f:
            f.write(data)
        try:
            meta = spr_to_png.convert(tmp_spr, out_png)
            print(f'Converted {spr}: size=({meta["frame_width"]}, {meta["frame_height"]}), frames={meta["frames"]}')
        except Exception as e:
            print(f'Error converting {spr}: {e}')
    else:
        print(f'NOT FOUND: {spr}')
