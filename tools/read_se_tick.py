with open('systems/effects/status_effect.gd', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('func tick(')
print(text[idx:idx+800])
