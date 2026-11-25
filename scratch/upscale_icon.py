from PIL import Image

proj_icon = Image.open('assets/skill_icons/vltk/vo_dang_chan_vo_that_tiet.png')
upscaled = proj_icon.resize((96, 96), Image.NEAREST)
upscaled.save('scratch/proj_icon_96.png')
print("Saved upscaled icon")
