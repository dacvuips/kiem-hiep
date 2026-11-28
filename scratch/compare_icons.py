from PIL import Image

user_img = Image.open('C:/Users/Hieu Tran/.gemini/antigravity/brain/99687a94-2823-477b-93b5-171ef51f610c/.user_uploaded/media_1795490549271_451792d6.png')
# The user image is 521 x 459
# Let's crop the icon box in the screenshot:
# Looking at the screenshot, the icon box is on the left side below title
# roughly x: 45 to 150, y: 100 to 200
cropped_icon = user_img.crop((50, 107, 146, 203))
cropped_icon.save('scratch/user_cropped_icon.png')

proj_icon = Image.open('assets/skill_icons/vltk/vo_dang_chan_vo_that_tiet.png')
print("Project icon size:", proj_icon.size)
print("Cropped icon size:", cropped_icon.size)
