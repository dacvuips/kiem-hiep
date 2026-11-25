with open('player/sect_skill_controller.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    if any(k in l for k in ['180', 'autoreply', 'con_lon', 'thien_vuong', 'chan_vo', 'reply']):
        print(f"{i+1}: {l.strip()}")
