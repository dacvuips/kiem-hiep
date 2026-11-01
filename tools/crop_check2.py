from PIL import Image
im = Image.open('screen_android.png')
# The button is further right:
# In crop1, it started around x=1350.
# So the button is centered around x=1750, y=1050!
# Let's crop from 1500 to 2000, 1000 to 1150:
c = im.crop((1500, 1000, 2000, 1150))
c.save('crop_create_center.png')
