import socket
import json

def eval_godot(expr):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(2.0)
    msg = json.dumps({'cmd': 'evaluate', 'expression': expr}).encode('utf-8')
    sock.sendto(msg, ('127.0.0.1', 6971))
    try:
        data, _ = sock.recvfrom(4096)
        return json.loads(data.decode('utf-8'))
    except Exception as e:
        return {'error': str(e)}

print('Player position:', eval_godot('get_tree().get_first_node_in_group("player").global_position'))
print('Current scene:', eval_godot('get_tree().current_scene.name'))
print('Map dir:', eval_godot('VltkWorld.current.map_dir if VltkWorld.current else "no vltk world"'))
print('Map class:', eval_godot('VltkWorld.current.map.get_class() if VltkWorld.current and VltkWorld.current.map else "no map"'))
print('Arena rect:', eval_godot('VltkWorld.current.arena_rect if VltkWorld.current else "no vltk world"'))
print('Loaded chunks count:', eval_godot('VltkWorld.current.map._chunks.size() if VltkWorld.current and VltkWorld.current.map else 0'))
print('Obs count:', eval_godot('VltkWorld.current.map._obs.size() if VltkWorld.current and VltkWorld.current.map else 0'))
