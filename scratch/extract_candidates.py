import sys, os
sys.path.insert(0, 'tools')
import vltk_source, spr_to_png

spr_candidates = [
    r'spr\skill\others\2012yanhua1.spr',
    r'spr\skill\others\2012yanhua3.spr',
    r'spr\skill\天忍\mag_bz_huo1_爆炸效果.spr',
    r'spr\skill\天忍\mag_bz_huo3_爆炸效果.spr',
    r'spr\skill\天忍\mag_bz_huo4_爆炸效果.spr',
    r'spr\item\songjin\sjzh_huo.spr',
    r'spr\obj\item\yandihuoyan.spr',
    r'spr\skill\1502\gb\gb_150_zhanggai_huo.spr',
    r'spr\skill\150\tr\tr_150_jihuoliaoyuan_c.spr',
]

os.makedirs('scratch/candidate_sprs', exist_ok=True)

for spr in spr_candidates:
    data = vltk_source.client_file(spr)
    if data:
        base = os.path.basename(spr).replace('.spr', '')
        tmp_spr = f'scratch/candidate_sprs/{base}.spr'
        out_png = f'scratch/candidate_sprs/{base}.png'
        with open(tmp_spr, 'wb') as f:
            f.write(data)
        try:
            meta = spr_to_png.convert(tmp_spr, out_png)
            print(f'Converted {spr} -> {out_png}: {meta}')
        except Exception as e:
            print(f'Error converting {spr}: {e}')
    else:
        print(f'NOT FOUND: {spr}')
