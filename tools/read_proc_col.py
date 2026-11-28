with open('systems/skill_fx/vltk_missile.gd', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('func _process_collision_at(')
print(text[idx:idx+900])
