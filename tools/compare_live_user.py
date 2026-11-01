import cv2
import numpy as np

img1 = cv2.imread('C:/Users/Hieu Tran/.gemini/antigravity/brain/5c6d8eff-8cb0-4dcf-bf7b-a0b5d3117f74/.user_uploaded/media_1793333771532_3e49b77c.jpg')
img2 = cv2.imread('tools/live_game_screenshot.png')

print('User image size:', img1.shape)
print('Live game size:', img2.shape)

# Let's save a side by side comparison or crop the player from live_game_screenshot
# In live game, where is the player on screen?
# Viewport is 1280x720. Camera follows player, so player is near (640, 360) on screen!
# Let's crop 400x400 around center: (440..840, 160..560)
player_crop = img2[160:560, 440:840]
cv2.imwrite('tools/live_player_crop.png', player_crop)
print('Saved tools/live_player_crop.png!')
