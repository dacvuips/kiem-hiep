with open(r'D:\game\source_vo-lam-truyen-ky\anh-viet\MiTom_Pak_SPR_v1.1.7\Unpacked_Resources\script\skill\tangmen.lua', 'r', encoding='latin-1') as f:
    text = f.read()

pos1 = text.find('feidaotang150={')
pos2 = text.find('feidaotang150_2={')
print('=== feidaotang150 ===')
print(text[pos1:pos1+800])
print('=== feidaotang150_2 ===')
print(text[pos2:pos2+800])
