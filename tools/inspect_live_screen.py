import cv2
import numpy as np
from PIL import Image

im = Image.open('tools/live_game_screenshot.png')
print('Image size:', im.size)

# Crop the whole screen into 4 quadrants or save a resized image for inspection
resized = im.resize((640, 360))
resized.save('tools/live_resized.png')
print('Saved tools/live_resized.png')
