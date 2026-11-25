from PIL import Image
import numpy as np

img = Image.open(r"C:\Users\Hieu Tran\.gemini\antigravity\brain\ada8bb06-2815-4df3-9d4f-012012770254\.user_uploaded\media_1795527296772_5ac734f3.png").convert("RGBA")

# In VLTK, skill FX sprites are rendered with additive blending (or alpha blending on ground).
# In the client, Fire effects (like fire on head) use additive blending:
# Result_Color = Ground_Color + Sprite_Color
# This means:
# Sprite_Color = max(0, Result_Color - Ground_Color)!
# Let's verify this mathematical property!

# Let's take ground samples around Fire 1 (Tẩu Thạch):
# Left of fire: x=40..70, y=60..85
# Below fire: x=80..140, y=95..105 (above the text)
# Right of fire: x=145..160, y=70..85
ground_left = np.array(img.crop((40, 60, 70, 85)).convert("RGB"))
mean_ground = ground_left.mean(axis=(0,1))
print("Mean ground left:", mean_ground)

# Let's calculate Sprite_Color = np.clip(Pixel_Color - mean_ground, 0, 255)
f1_area = np.array(img.crop((70, 48, 150, 94)).convert("RGB"))
diff1 = np.clip(f1_area.astype(float) - mean_ground, 0, 255)

# Alpha can be computed from the brightness or max channel
alpha1 = np.clip(np.max(diff1, axis=2) * 1.5, 0, 255).astype(np.uint8)
rgba1 = np.dstack([diff1.astype(np.uint8), alpha1])

im1 = Image.fromarray(rgba1, "RGBA")
im1.save("scratch/fire1_extracted_additive.png")
print("Saved fire1_extracted_additive.png, size:", im1.size)

# Same for Fire 2 (Mạc Tặc):
f2_area = np.array(img.crop((160, 22, 235, 68)).convert("RGB"))
diff2 = np.clip(f2_area.astype(float) - mean_ground, 0, 255)
alpha2 = np.clip(np.max(diff2, axis=2) * 1.5, 0, 255).astype(np.uint8)
rgba2 = np.dstack([diff2.astype(np.uint8), alpha2])
im2 = Image.fromarray(rgba2, "RGBA")
im2.save("scratch/fire2_extracted_additive.png")
print("Saved fire2_extracted_additive.png, size:", im2.size)
