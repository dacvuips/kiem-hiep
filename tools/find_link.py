import sys
sys.stdout.reconfigure(encoding='utf-8')
from PIL import Image
import numpy as np

c_arr = np.array(Image.open('crop_register_link2.png'))
txt_mask = (c_arr[:, :, 0] > 200) & (c_arr[:, :, 1] > 200) & (c_arr[:, :, 2] > 150)
rows, cols = np.where(txt_mask)
c_dk = cols[(cols > 30) & (cols < 140)]
r_dk = rows[(cols > 30) & (cols < 140)]
if len(c_dk) > 0:
    min_x, max_x = c_dk.min() + 1650, c_dk.max() + 1650
    min_y, max_y = r_dk.min() + 740, r_dk.max() + 740
    print(f'Dang ky link bounding box: X=[{min_x}, {max_x}], Y=[{min_y}, {max_y}]')
    print(f'Center: X={(min_x + max_x)//2}, Y={(min_y + max_y)//2}')
