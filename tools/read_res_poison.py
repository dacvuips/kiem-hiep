with open('player/sect_skill_controller.gd', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('stats.poison_tick_damage')
print(text[idx-200:idx+800])
