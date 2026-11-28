from PIL import Image

f_source = Image.open('scratch/jx_matched_pngs/a2bd_frame_0.png')
f_user = Image.open('scratch/exact_fire_1.png')

# Create comparison canvas
canvas = Image.new('RGBA', (260, 80), (35, 35, 40, 255))
canvas.paste(f_user, (20, 20))
canvas.paste(f_source, (140, 18), f_source)
canvas.save('scratch/exact_source_vs_screenshot.png')
print("Saved scratch/exact_source_vs_screenshot.png")
