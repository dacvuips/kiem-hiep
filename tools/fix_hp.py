with open('tests/test_vo_anh_xuyen_play.gd', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('add_child(enemy)', '''add_child(enemy)
	enemy.max_health = 500000.0
	enemy.health = 500000.0
	if enemy.combat_stats:
		enemy.combat_stats.max_health = 500000
		enemy.combat_stats.current_health = 500000''')

with open('tests/test_vo_anh_xuyen_play.gd', 'w', encoding='utf-8') as f:
    f.write(text)
print('Updated enemy to Super Moc Nhan HP')
