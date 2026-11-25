with open('systems/sect/data/duong_mon.tres', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('id = "duong_mon_vo_anh_xuyen"')
print(text[idx:idx+800])
