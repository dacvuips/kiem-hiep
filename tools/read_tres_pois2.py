with open('systems/sect/data/duong_mon.tres', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('id = "duong_mon_vo_anh_xuyen"')
while idx != -1:
    idx2 = text.find('id = "duong_mon_vo_anh_xuyen"', idx + 1)
    if idx2 != -1 and 'script = ExtResource("2_skill")' in text[idx:idx2]:
        print(text[idx:idx2])
        break
    idx = idx2
