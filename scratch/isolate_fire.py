from PIL import Image
import numpy as np

img = Image.open(r"C:\Users\Hieu Tran\.gemini\antigravity\brain\ada8bb06-2815-4df3-9d4f-012012770254\.user_uploaded\media_1795527296772_5ac734f3.png").convert("RGBA")
# Ground background color sample from sand (x=10, y=10)
sand = np.array(img.crop((10, 10, 30, 30)).convert("RGB"))
mean_sand = sand.mean(axis=(0, 1))
print("Mean sand color:", mean_sand)

# Fire 1 bounding box:
# Name "Tẩu Thạch" is at y=110..130, x=50..130
# Fire is above the name: y=75..110, x=55..135
c1 = img.crop((50, 70, 140, 115))
c1.save("scratch/fire1_isolated.png")

# Fire 2 bounding box:
# Name "Mạc Tặc" is at y=80..100, x=140..200
# Fire is above "Mạc Tặc": y=40..78, x=140..220
c2 = img.crop((140, 40, 220, 85))
c2.save("scratch/fire2_isolated.png")

print("c1 size:", c1.size, "c2 size:", c2.size)
