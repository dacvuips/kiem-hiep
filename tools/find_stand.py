with open('systems/skill_fx/vltk_missile.gd', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('MoveKind.STAND')
while idx != -1:
    print(text[idx-50:idx+400])
    print('---')
    idx = text.find('MoveKind.STAND', idx + 1)
