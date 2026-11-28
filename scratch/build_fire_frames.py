from PIL import Image, ImageFilter
import numpy as np

img = Image.open(r"C:\Users\Hieu Tran\.gemini\antigravity\brain\ada8bb06-2815-4df3-9d4f-012012770254\.user_uploaded\media_1795527296772_5ac734f3.png").convert("RGBA")

# Sand color in original screenshot
sand = np.array([184.0, 157.0, 108.0])

# Crop 1: Tẩu Thạch fire
# Exact box in original: x=75..147, y=55..92
crop1 = img.crop((75, 55, 147, 92))
w1, h1 = crop1.size

# Crop 2: Mạc Tặc fire
# Exact box in original: x=166..234, y=28..64
crop2 = img.crop((166, 28, 234, 64))
w2, h2 = crop2.size

print(f"Crop 1 size: {w1}x{h1}, Crop 2 size: {w2}x{h2}")

# Standard target frame size: 80 width, 44 height
FRAME_W = 80
FRAME_H = 44

def clean_fire_frame(crop):
    arr = np.array(crop.convert("RGB")).astype(float)
    h, w, _ = arr.shape
    out = np.zeros((FRAME_H, FRAME_W, 4), dtype=np.uint8)
    
    # center placement
    ox = (FRAME_W - w) // 2
    oy = (FRAME_H - h) // 2
    
    for y in range(h):
        for x in range(w):
            c = arr[y, x]
            # Fire characteristics:
            # R is high, G is high, B is noticeably lower than G
            # On sand (184, 157, 108):
            # Fire adds red and yellow light
            r_diff = max(0.0, c[0] - sand[0])
            g_diff = max(0.0, c[1] - sand[1])
            b_diff = c[2] - sand[2]
            
            # Fire intensity
            intensity = r_diff * 1.8 + g_diff * 1.2 - max(0.0, b_diff) * 1.5
            
            # Direct color test: yellow-orange flame
            is_core = (c[0] > 230 and c[1] > 180 and c[2] < 120)
            is_body = (c[0] > 210 and c[1] > 140 and c[2] < 115)
            is_edge = (c[0] > 195 and c[1] > 130 and c[2] < 120 and intensity > 10)
            
            if is_core:
                alpha = 255
                rgb = [255, min(255, int(c[1] * 1.1)), max(20, int(c[2] * 0.7))]
            elif is_body:
                alpha = min(255, int(180 + intensity * 1.2))
                rgb = [255, int(c[1]), max(15, int(c[2] * 0.6))]
            elif is_edge:
                alpha = min(200, max(40, int(intensity * 3.0)))
                rgb = [min(255, int(c[0] * 1.15)), int(c[1] * 0.9), max(0, int(c[2] * 0.5))]
            else:
                alpha = 0
                rgb = [0, 0, 0]
                
            if alpha > 0:
                out[oy + y, ox + x] = [rgb[0], rgb[1], rgb[2], alpha]
                
    return Image.fromarray(out, "RGBA")

f1 = clean_fire_frame(crop1)
f2 = clean_fire_frame(crop2)

f1.save("scratch/f1_clean.png")
f2.save("scratch/f2_clean.png")
print("Saved clean f1 and f2 frames")
