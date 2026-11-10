cfg_path = r'd:\game\lam-game\kiem-hiep\.godot\global_script_class_cache.cfg'
with open(cfg_path, 'r', encoding='utf-8') as f:
    content = f.read()

entries = ''' {
"base": &"RefCounted",
"class": &"DaTauData",
"icon": "",
"is_abstract": false,
"is_tool": false,
"language": &"GDScript",
"path": "res://systems/quest/da_tau_data.gd"
}, {
"base": &"RefCounted",
"class": &"DaTauManager",
"icon": "",
"is_abstract": false,
"is_tool": false,
"language": &"GDScript",
"path": "res://systems/quest/da_tau_manager.gd"
}, {
"base": &"SocialWindow",
"class": &"DaTauWindow",
"icon": "",
"is_abstract": false,
"is_tool": false,
"language": &"GDScript",
"path": "res://ui/events/da_tau_window.gd"
},'''

if 'DaTauData' not in content:
    idx = content.find('list=[') + len('list=[')
    new_content = content[:idx] + entries + content[idx:]
    with open(cfg_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print('Updated global_script_class_cache.cfg successfully!')
else:
    print('Already present in global_script_class_cache.cfg')
