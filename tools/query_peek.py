import socket
import json

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(2.0)
msg = json.dumps({'cmd': 'screenshot'}).encode('utf-8')
sock.sendto(msg, ('127.0.0.1', 6971))
try:
    data, _ = sock.recvfrom(4096)
    print('Response:', data.decode('utf-8'))
except Exception as e:
    print('Error:', e)
