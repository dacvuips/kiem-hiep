from PIL import Image, ImageChops, ImageEnhance
import numpy as np

f1 = Image.open("scratch/f1_clean.png")
f2 = Image.open("scratch/f2_clean.png")
w, h = f1.size

def morph_frame(base1, base2, weight2, shift_x=0, shift_y=0, brightness=1.0):
    # Blend base1 and base2
    blended = Image.blend(base1, base2, weight2)
    # Apply subtle shift
    if shift_x != 0 or shift_y != 0:
        shifted = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        shifted.paste(blended, (shift_x, shift_y))
        blended = shifted
    # Apply subtle brightness/warmth
    if brightness != 1.0:
        enh = ImageEnhance.Brightness(blended)
        blended = enh.enhance(brightness)
    return blended

frames = []
# 8 frames loop:
frames.append(f1) # 0
frames.append(morph_frame(f1, f2, 0.25, shift_x=-1, shift_y=0, brightness=1.05)) # 1
frames.append(morph_frame(f1, f2, 0.50, shift_x=0, shift_y=-1, brightness=1.02)) # 2
frames.append(morph_frame(f1, f2, 0.75, shift_x=1, shift_y=0, brightness=0.98)) # 3
frames.append(f2) # 4
frames.append(morph_frame(f2, f1, 0.25, shift_x=1, shift_y=0, brightness=1.04)) # 5
frames.append(morph_frame(f2, f1, 0.50, shift_x=0, shift_y=0, brightness=1.00)) # 6
frames.append(morph_frame(f2, f1, 0.75, shift_x=-1, shift_y=0, brightness=0.97)) # 7

# Create horizontal spritesheet: 8 * 80 = 640 x 44
sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
for i, fr in enumerate(frames):
    sheet.paste(fr, (i * w, 0))

sheet.save("scratch/kinh_dao_fire_sheet.png")
print("Saved scratch/kinh_dao_fire_sheet.png, size:", sheet.size)

# Also save animated GIF for preview
frames[0].save(
    "scratch/kinh_dao_fire_preview.gif",
    save_all=True,
    append_images=frames[1:],
    duration=100,
    loop=0,
    disposal=2
)
print("Saved scratch/kinh_dao_fire_preview.gif")
