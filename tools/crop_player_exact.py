import cv2

im = cv2.imread('tools/live_game_screenshot.png')
crop = im[170:670, 390:890]
cv2.imwrite('tools/live_player_exact.png', crop)
print('Saved tools/live_player_exact.png!')
