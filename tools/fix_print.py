with open('tests/test_vo_anh_xuyen_play.gd', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('stats.damage, stats.poison_tick_damage', 'stats.damage, stats.poison_tick_damage, stats.extra_damage_ranges')
text = text.replace('%f, poison_tick=%d', '%f, poison_tick=%d, extra=%s')
with open('tests/test_vo_anh_xuyen_play.gd', 'w', encoding='utf-8') as f:
    f.write(text)
print('Updated print')
