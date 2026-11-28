from PIL import Image

im = Image.open('C:/Users/Hieu Tran/.gemini/antigravity/brain/f4482a95-b51a-4dfe-bc84-e2958d55744d/.user_uploaded/media_1795413701510_dd93c098.jpg')
# Crop around Moc Nhan: (100, 100, 250, 240)
im.crop((100, 100, 250, 240)).save('tools/crop_mocnhan.png')
print('Cropped Moc Nhan region')
