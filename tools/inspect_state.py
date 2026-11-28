import sys
sys.path.append('tools')
from inspect_live_game import eval_godot

print('Field map:', eval_godot('GameManager.field_map'))
print('Profile:', eval_godot('GameManager.local_profile.name if GameManager.local_profile else "none"'))
print('Level:', eval_godot('GameManager.local_profile.level if GameManager.local_profile else 0'))
print('Current scene:', eval_godot('get_tree().current_scene.name'))
print('VltkWorld map_dir:', eval_godot('VltkWorld.current.map_dir if VltkWorld.current else "none"'))
print('Player pos:', eval_godot('get_tree().get_first_node_in_group("player").global_position if get_tree().get_first_node_in_group("player") else "none"'))
