from PIL import Image
import numpy as np

im1 = Image.open('assets/skill_icons/vltk/vo_dang_chan_vo_that_tiet.png')
# let's crop the icon in uploaded image:
# In the uploaded image (521, 459), the icon is at approx x: 50..150, y: 110..210
im2 = Image.open('C:/Users/Hieu Tran/.gemini/antigravity/brain/99687a94-2823-477b-93b5-171ef51f610c/.user_uploaded/media_1795490549271_451792d6.png')

im1.save('scratch/icon_project.png')
print("Saved icon project to scratch/icon_project.png")
