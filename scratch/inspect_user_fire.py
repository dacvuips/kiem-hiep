from PIL import Image

img = Image.open(r"C:\Users\Hieu Tran\.gemini\antigravity\brain\ada8bb06-2815-4df3-9d4f-012012770254\.user_uploaded\media_1795527296772_5ac734f3.png").convert("RGBA")
print("Full Image 2 size:", img.size)

# The image shows two monsters: "Tẩu Thạch" on the left, and "Mạc Tặc" on the right.
# Let's crop both fire areas and inspect them
# Tẩu Thạch fire is around x=50..140, y=80..130
# Mạc Tặc fire is around x=130..220, y=40..90
crop1 = img.crop((40, 70, 140, 130))
crop1.save("scratch/fire1_crop.png")

crop2 = img.crop((120, 30, 220, 90))
crop2.save("scratch/fire2_crop.png")
print("Saved fire1_crop and fire2_crop")
