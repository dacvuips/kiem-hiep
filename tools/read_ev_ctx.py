with open('systems/skill_fx/vltk_skill_caster.gd', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('func _resolve_event_context(')
print(text[idx:idx+1500])
