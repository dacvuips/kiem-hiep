import cv2
import numpy as np

img1 = cv2.imread('tools/user_player_exact.png')
img2 = cv2.imread('tools/live_player_exact.png')

# Let's check difference
diff = cv2.absdiff(cv2.resize(img1, (500, 500)), img2)
print('Mean pixel difference between user screenshot crop and live screenshot crop:', diff.mean())
