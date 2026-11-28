import json
states = json.load(open('data/skill_fx/states.json', encoding='utf-8'))
anims = json.load(open('data/skill_fx/anims.json', encoding='utf-8'))
for sid, st in states.items():
    if st.get('type') == 'Head':
        a_key = st.get('anim')
        a = anims.get(a_key, {})
        print(f"State {sid:6}: anim={a_key:25} size={a.get('size')} offset={a.get('offset')}")
