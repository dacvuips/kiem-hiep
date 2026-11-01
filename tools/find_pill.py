from PIL import Image
import numpy as np

im = Image.open('screen_android.png')
arr = np.array(im)
h, w, _ = arr.shape

# Let's search for the golden border of CreateAccountButton:
# The button is a pill shape with a golden border.
# Let's look around y from 1000 to 1150, x from 1400 to 2100:
# Let's find pixels with golden color around the pill border (e.g. R>150, G>130, B<90):
# Or let's inspect the bounding box of crop_create_center.png in screen_android.png:
# In crop_check2.py we did:
# c = im.crop((1500, 1000, 2000, 1150))
# Let's see the position of text inside that crop:
c_arr = np.array(Image.open('crop_create_center.png'))
print('Crop shape:', c_arr.shape)

# Inside the crop (500 width, 150 height), where is the pill button?
# Let's find rows and cols where the dark pill background (R~30-50, G~50-70, B~55-75) exists:
pill_mask = (c_arr[:, :, 0] > 25) & (c_arr[:, :, 0] < 60) & \
            (c_arr[:, :, 1] > 45) & (c_arr[:, :, 1] < 80) & \
            (c_arr[:, :, 2] > 50) & (c_arr[:, :, 2] < 90)

rows, cols = np.where(pill_mask)
if len(rows) > 0:
    min_y, max_y = rows.min() + 1000, rows.max() + 1000
    min_x, max_x = cols.min() + 1500, cols.max() + 1500
    print(f'Pill button bounding box in full screen: X=[{min_x}, {max_x}], Y=[{min_y}, {max_y}]')
    print(f'Center: X={(min_x + max_x)//2}, Y={(min_y + max_y)//2}')
else:
    print('Pill mask not matched')
