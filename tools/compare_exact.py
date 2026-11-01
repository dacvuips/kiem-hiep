import cv2
import numpy as np

user_img = cv2.imread('C:/Users/Hieu Tran/.gemini/antigravity/brain/5c6d8eff-8cb0-4dcf-bf7b-a0b5d3117f74/.user_uploaded/media_1793333771532_3e49b77c.jpg')
live_crop = cv2.imread('tools/live_player_exact.png')

print('User image shape:', user_img.shape)
print('Live crop shape:', live_crop.shape)

# Find player HP bar in user_img
hsv_user = cv2.cvtColor(user_img, cv2.COLOR_BGR2HSV)
mask_user = cv2.inRange(hsv_user, (35, 100, 100), (85, 255, 255))
contours_user, _ = cv2.findContours(mask_user, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
for c in contours_user:
    x, y, w, h = cv2.boundingRect(c)
    if 20 <= w <= 100 and 2 <= h <= 15:
        print(f'User image HP bar at: x={x}, y={y}, w={w}, h={h}')
        user_crop = user_img[max(0, y-156):min(user_img.shape[0], y+344), max(0, x-227):min(user_img.shape[1], x+273)]
        cv2.imwrite('tools/user_player_exact.png', user_crop)
        print('Saved tools/user_player_exact.png!')
        break
