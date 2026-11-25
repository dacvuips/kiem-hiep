with open('tests/test_vo_anh_xuyen_play.gd', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('player.combat_stats.deadly_strike_p = 72', 'player.combat_stats.deadly_strike_enhance_p = 72')
with open('tests/test_vo_anh_xuyen_play.gd', 'w', encoding='utf-8') as f:
    f.write(text)
print('Updated test script')
