from PIL import Image

im = Image.open('tools/live_game_screenshot.png')
print('Screenshot size:', im.size)

# Let's save a thumbnail or inspect what scene it is
# Check color of center of screen
w, h = im.size
print('Center pixel (RGBA):', im.getpixel((w//2, h//2)))

# Check some regions
# Top left: UI bar
# Bottom right: buttons
# Save an informative description
for y in range(0, h, 100):
    row_colors = [im.getpixel((x, y))[:3] for x in range(0, w, 200)]
    print(f'y={y:3d}: ', row_colors)
