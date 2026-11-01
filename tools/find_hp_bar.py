import cv2
import numpy as np

im = cv2.imread('tools/live_game_screenshot.png')
# Green health bar color is bright green: B around 30, G around 200..255, R around 30
hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV)
# Green mask: H: 35..85, S: 100..255, V: 100..255
mask = cv2.inRange(hsv, (35, 100, 100), (85, 255, 255))
contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

print(f'Found {len(contours)} green regions')
for c in contours:
    x, y, w, h = cv2.boundingRect(c)
    if 20 <= w <= 100 and 2 <= h <= 15:
        print(f'Possible player HP bar at: x={x}, y={y}, w={w}, h={h}')
