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

# Test walking from current player position forward to the right cliff
script = """
var p = get_tree().get_first_node_in_group("player")
var cur_feet = p.global_position + Vector2(0, 30.0)
var out = []
for i in range(1, 25):
    var target = cur_feet + Vector2(i * 15.0, 0.0) # Moving right
    var blocked = VltkWorld.current.map.is_blocked(target)
    var c = VltkWorld.current.map.world_to_cell(target)
    out.append("dx=%d pos=%s cell=%s blocked=%s" % [i*15, str(target), str(c), str(blocked)])
return "\\n".join(out)
"""
res = eval_godot(script)
print('Moving straight RIGHT (X+):')
print(res.get('value'))

script_diag = """
var p = get_tree().get_first_node_in_group("player")
var cur_feet = p.global_position + Vector2(0, 30.0)
var out = []
for i in range(1, 25):
    var target = cur_feet + Vector2(i * 15.0, i * 8.0) # Moving down-right
    var blocked = VltkWorld.current.map.is_blocked(target)
    var c = VltkWorld.current.map.world_to_cell(target)
    out.append("step=%d pos=%s cell=%s blocked=%s" % [i, str(target), str(c), str(blocked)])
return "\\n".join(out)
"""
res2 = eval_godot(script_diag)
print('\nMoving DOWN-RIGHT:')
print(res2.get('value'))
