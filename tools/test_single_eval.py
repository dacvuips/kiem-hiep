import socket
import json

def test_eval():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('127.0.0.1', 0)) # bind local port
    sock.settimeout(3.0)
    
    # Simple single-line expression:
    expr = 'get_tree().get_first_node_in_group("player").global_position'
    payload = json.dumps({'cmd': 'evaluate', 'expression': expr}).encode('utf-8')
    sock.sendto(payload, ('127.0.0.1', 6971))
    
    try:
        resp, _ = sock.recvfrom(4096)
        print('Eval response:', json.loads(resp.decode('utf-8')))
    except Exception as e:
        print('Eval error:', e)
    finally:
        sock.close()

test_eval()
