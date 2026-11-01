with open('export_presets.cfg', 'r', encoding='utf-8') as f:
    text = f.read()

idx = text.find('[preset.2]')
if idx != -1:
    print(text[idx:idx+1000])
