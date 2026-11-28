with open('systems/effects/status_effect_controller.gd', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('func _process(')
if idx == -1:
    idx = text.find('func _physics_process(')
print(text[idx:idx+800])
