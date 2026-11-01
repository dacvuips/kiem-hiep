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

print(eval_godot('return "hello world"'))
