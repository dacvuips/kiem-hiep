import socket
import json
import random

def eval_new_port(expr):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    # bind to a random free port each time
    sock.bind(('127.0.0.1', random.randint(20000, 50000)))
    sock.settimeout(2.0)
    
    payload = json.dumps({'cmd': 'evaluate', 'expression': expr}).encode('utf-8')
    sock.sendto(payload, ('127.0.0.1', 6971))
    
    try:
        resp, _ = sock.recvfrom(4096)
        return json.loads(resp.decode('utf-8'))
    except Exception as e:
        return {'error': str(e)}
    finally:
        sock.close()

print('Result:', eval_new_port('get_tree().get_first_node_in_group("player").global_position'))
