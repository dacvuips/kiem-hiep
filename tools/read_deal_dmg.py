with open('systems/skill_fx/vltk_cast_context.gd', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('func deal_damage(')
print(text[idx:idx+1500])
