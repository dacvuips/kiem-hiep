from PIL import Image
import numpy as np

img = Image.open(r"C:\Users\Hieu Tran\.gemini\antigravity\brain\ada8bb06-2815-4df3-9d4f-012012770254\.user_uploaded\media_1795527296772_5ac734f3.png").convert("RGBA")

# Ground sand color
ground = np.array([184.0, 157.0, 108.0])

def unblend(crop_img):
    arr = np.array(crop_img.convert("RGB")).astype(float)
    h, w, _ = arr.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    
    for y in range(h):
        for x in range(w):
            c = arr[y, x]
            # distance from ground
            # fire pixels are characterized by high Red (>190), high Green (>140), low Blue (<110)
            # or significantly higher R/G than ground
            diff = c - ground
            # fireness metric
            fireness = (c[0] - ground[0]) * 1.5 + (c[1] - ground[1]) * 1.0 - (c[2] - ground[2]) * 1.2
            # also check if pixel is yellow/orange: R > 200 and G > 120 and B < 120
            is_fire = (c[0] > 195 and c[1] > 130 and c[2] < 120) or (fireness > 20)
            
            if is_fire and fireness > 5:
                # Alpha is high in core, soft at edges
                alpha = min(255, max(0, int(fireness * 3.5)))
                # If bright core, alpha is 255
                if c[0] > 230 and c[1] > 170:
                    alpha = 255
                # Color of fire
                # For alpha blended: Color = (Pixel - (1-alpha)*Ground) / alpha
                a_norm = max(alpha / 255.0, 0.2)
                fire_rgb = (c - (1.0 - a_norm) * ground) / a_norm
                fire_rgb = np.clip(fire_rgb, 0, 255).astype(np.uint8)
                
                # Boost warmth of fire
                fire_rgb[0] = max(fire_rgb[0], 220)
                out[y, x] = [fire_rgb[0], fire_rgb[1], fire_rgb[2], alpha]
            else:
                out[y, x] = [0, 0, 0, 0]
    return Image.fromarray(out, "RGBA")

f1_clean = unblend(img.crop((70, 48, 150, 94)))
f1_clean.save("scratch/f1_unblended.png")

f2_clean = unblend(img.crop((160, 22, 235, 68)))
f2_clean.save("scratch/f2_unblended.png")
print("Saved f1_unblended and f2_unblended")
