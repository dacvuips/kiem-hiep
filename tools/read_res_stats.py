with open('player/sect_skill_controller.gd', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('func _resolve_stats(')
print(text[idx:idx+1500])
