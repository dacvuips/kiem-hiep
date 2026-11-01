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

pos = '(77523.61, 58350.04)'
feet = 'Vector2(77523.61, 58350.04 + 30.0)' # FEET_OFFSET is 30!
print('Player feet:', eval_godot(feet))
print('is_blocked at feet:', eval_godot(f'VltkWorld.current.map.is_blocked({feet})'))
print('Cell at feet:', eval_godot(f'VltkWorld.current.map.world_to_cell({feet})'))

# Check cell value in _obs of the live game!
print('Check _obs of live game for region 151,113:')
script = """
var c = VltkWorld.current.map.world_to_cell(Vector2(77523.61, 58380.04))
var rx = floori(c.x / 16.0)
var ry = floori(c.y / 32.0)
var ob = VltkWorld.current.map._obs.get("%d,%d" % [rx, ry])
var idx = (c.x - rx * 16) * 32 + (c.y - ry * 32)
return "rx=%d ry=%d cx=%d cy=%d val=0x%02x blocked=%s" % [rx, ry, c.x - rx*16, c.y - ry*32, ob[idx], str((ob[idx] >> 4) != 0)]
"""
print(eval_godot(script))

# Check what happens when trying to move right in the live game!
slide_test = """
var feet = Vector2(77523.61, 58380.04)
var vel = Vector2(250.0, 0.0) # Moving right
var res = VltkWorld.slide_velocity(feet, vel, 0.016, false, false)
return "slide_velocity moving right: " + str(res)
"""
print(eval_godot(slide_test))

slide_down_right = """
var feet = Vector2(77523.61, 58380.04)
var vel = Vector2(200.0, 100.0)
var res = VltkWorld.slide_velocity(feet, vel, 0.016, false, false)
return "slide_velocity moving down-right: " + str(res)
"""
print(eval_godot(slide_down_right))
