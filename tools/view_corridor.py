from PIL import Image

im = Image.open('world/maps/map_79/minimap.jpg')
# (53680 / 512 - 100) * 64 = 310
# (50280 / 512 - 97) * 64 = 77
px, py = 310, 77

# Print a 40x40 character map of the minimap around (px, py)
# 1 character = 2 pixels on minimap = 16 pixels in world
for dy in range(-15, 16):
    line = f"{py+dy:3d} (y={194 + (py+dy)/32:.1f}): "
    for dx in range(-25, 26):
        x = px + dx
        y = py + dy
        if dx == 0 and dy == 0:
            line += "P" # Player
        elif 0 <= x < im.width and 0 <= y < im.height:
            r, g, b = im.getpixel((x, y))[:3]
            bright = (r + g + b) // 3
            if bright < 20:
                line += " " # Outside/Void/Black
            elif bright < 50:
                line += "." # Floor
            else:
                line += "#" # Wall/Structure
        else:
            line += " "
    print(line)
