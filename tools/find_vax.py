with open('systems/sect/data/duong_mon.tres', 'r', encoding='utf-8') as f:
    text = f.read()

import re
matches = [m.start() for m in re.finditer('id = "duong_mon_vo_anh_xuyen"', text)]
print('Matches count:', len(matches))
for m in matches:
    # check if this block is ExtResource("2_skill")
    chunk = text[max(0, m-100):min(len(text), m+600)]
    if 'ExtResource("2_skill")' in chunk:
        print('Found Skill Definition at pos', m)
        print(chunk)
