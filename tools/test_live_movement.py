import socket
import json
import time

def send_peek(data_dict):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(2.0)
    msg = json.dumps(data_dict).encode('utf-8')
    sock.sendto(msg, ('127.0.0.1', 6971))
    try:
        data, _ = sock.recvfrom(4096)
        return json.loads(data.decode('utf-8'))
    except Exception as e:
        return {'error': str(e)}

def eval_expr(expr):
    return send_peek({'cmd': 'evaluate', 'expression': expr})

pos_before = eval_expr('get_tree().get_first_node_in_group("player").global_position')
print('Player pos before:', pos_before)

# Inject move_right
print('Injecting move_right pressed=True...')
send_peek({'cmd': 'input', 'type': 'action', 'action': 'move_right', 'pressed': True})
time.sleep(0.5)
send_peek({'cmd': 'input', 'type': 'action', 'action': 'move_right', 'pressed': False})
print('Injected move_right pressed=False.')

pos_after_right = eval_expr('get_tree().get_first_node_in_group("player").global_position')
print('Player pos after move_right:', pos_after_right)

# Inject move_down
print('Injecting move_down pressed=True...')
send_peek({'cmd': 'input', 'type': 'action', 'action': 'move_down', 'pressed': True})
time.sleep(0.5)
send_peek({'cmd': 'input', 'type': 'action', 'action': 'move_down', 'pressed': False})
print('Injected move_down pressed=False.')

pos_after_down = eval_expr('get_tree().get_first_node_in_group("player").global_position')
print('Player pos after move_down:', pos_after_down)

# Inject diagonal move_right + move_down
print('Injecting move_right + move_down pressed=True...')
send_peek({'cmd': 'input', 'type': 'action', 'action': 'move_right', 'pressed': True})
send_peek({'cmd': 'input', 'type': 'action', 'action': 'move_down', 'pressed': True})
time.sleep(0.8)
send_peek({'cmd': 'input', 'type': 'action', 'action': 'move_right', 'pressed': False})
send_peek({'cmd': 'input', 'type': 'action', 'action': 'move_down', 'pressed': False})

pos_after_diag = eval_expr('get_tree().get_first_node_in_group("player").global_position')
print('Player pos after diag:', pos_after_diag)
