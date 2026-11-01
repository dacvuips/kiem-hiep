from PIL import Image
im = Image.open('screen_android.png')
w, h = im.size

# Let's crop the area around where "Chưa có tài khoản? Đăng ký ngay" should be:
# In the screenshot, looking at screen_android.png:
# It's at the bottom center.
# Let's crop x: 1400 - 300 to 1400 + 300 (1100 to 1700), y: 950 to 1150
crop1 = im.crop((1400 - 350, 950, 1400 + 350, 1150))
crop1.save('crop_create_btn.png')

# Also crop around RegisterLink ("Đăng ký"):
# x: 1400 - 100 to 1400 + 200, y: 700 to 850
crop2 = im.crop((1400 - 150, 700, 1400 + 200, 850))
crop2.save('crop_register_link.png')
print('Cropped successfully')
