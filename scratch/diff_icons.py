from PIL import Image
import numpy as np

p1 = r'assets/skill_icons/vltk/vo_dang_chan_vo_that_tiet.png'
p2 = r'D:\game\source_vo-lam-truyen-ky\anh-viet\MiTom_Pak_SPR_v1.1.7\Unpacked_Resources\spr\ui\技能图标\jj\icon_jj_wu_150.png'

im1 = Image.open(p1).convert('RGBA')
im2 = Image.open(p2).convert('RGBA')
print("Size 1:", im1.size, "Size 2:", im2.size)

arr1 = np.array(im1)
arr2 = np.array(im2)
diff = np.abs(arr1.astype(int) - arr2.astype(int))
print("Max diff:", np.max(diff))
