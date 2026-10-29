import zipfile
import os
import json

zip_path = os.path.expandvars(r'%APPDATA%\Godot\export_templates\4.7.2.stable\web_release.zip')
tools_dir = os.path.dirname(os.path.abspath(__file__))
project_dir = os.path.abspath(os.path.join(tools_dir, ".."))
web_dir = os.path.join(project_dir, "build", "web")

pck_path = os.path.join(web_dir, 'index.pck')
wasm_path = os.path.join(web_dir, 'index.wasm')

pck_size = os.path.getsize(pck_path) if os.path.exists(pck_path) else 1376861852
wasm_size = os.path.getsize(wasm_path) if os.path.exists(wasm_path) else 38820072

with zipfile.ZipFile(zip_path, 'r') as z:
    # 1. Restore clean index.js
    with open(os.path.join(web_dir, 'index.js'), 'wb') as f:
        f.write(z.read('godot.js'))
    print('[OK] Restored clean index.js from Godot official template')

    # 2. Generate clean index.html
    template = z.read('godot.html').decode('utf-8')

config = {
    'args': [],
    'canvasResizePolicy': 2,
    'emscriptenPoolSize': 8,
    'ensureCrossOriginIsolationHeaders': True,
    'executable': 'index',
    'experimentalVK': True,
    'fileSizes': {
        'index.pck': pck_size,
        'index.wasm': wasm_size
    },
    'focusCanvas': True,
    'gdextensionLibs': [],
    'godotPoolSize': 4
}

head_include = '<link id="-gd-engine-icon" rel="icon" type="image/png" href="index.icon.png" />\n\t\t<link rel="apple-touch-icon" href="index.apple-touch-icon.png"/>'

html = template.replace('$GODOT_PROJECT_NAME', 'JX1 Idle Origin - Võ Lâm Truyền Kỳ')
html = html.replace('$GODOT_SPLASH_COLOR', '#000000')
html = html.replace('$GODOT_SPLASH_CLASSES', 'fullsize--true')
html = html.replace('$GODOT_SPLASH', 'index.png')
html = html.replace('$GODOT_HEAD_INCLUDE', head_include)
html = html.replace('$GODOT_URL', 'index.js')
html = html.replace('$GODOT_CONFIG', json.dumps(config, indent=2))
html = html.replace('$GODOT_THREADS_ENABLED', 'true')

with open(os.path.join(web_dir, 'index.html'), 'w', encoding='utf-8') as f:
    f.write(html)
print(f'[OK] Generated clean index.html (experimentalVK=True, clean Godot loader, pck={pck_size})')
