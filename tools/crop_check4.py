from PIL import Image
im = Image.open('screen_android.png')
# Top-left has '< Đổi Chế Độ Chơi'
# Let's crop from (100, 50) to (700, 150)
c = im.crop((100, 50, 700, 150))
c.save('crop_back.png')
