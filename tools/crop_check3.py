from PIL import Image
im = Image.open('screen_android.png')
# Center x is ~1725
# y is between Password input (y~700) and Login button (y~860)
# Let's crop x: 1650 to 1850, y: 740 to 820
c = im.crop((1650, 740, 1850, 820))
c.save('crop_register_link2.png')
