from PIL import Image

im = Image.open('assets/skill_fx/tien_giai_tho.png')
print("tien_giai_tho:", im.size, im.mode)

im2 = Image.open('assets/skill_fx/fx_819444ff.png')
print("fx_819444ff:", im2.size, im2.mode)
