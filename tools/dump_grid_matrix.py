import gzip, json

with gzip.open('world/maps/map_2/chunks/4_3.json.gz', 'rt', encoding='utf-8') as f:
    data = json.load(f)

regs = data.get('r', {})

def decode_ob(rdata):
    runs = rdata.get('ob', [])
    arr = bytearray()
    for i in range(0, len(runs), 2):
        val = runs[i] & 0xff
        cnt = runs[i+1]
        arr.extend([val] * cnt)
    return arr

ob113 = decode_ob(regs['151,113'])
ob114 = decode_ob(regs['151,114'])

print('=== 151,113 cy 20..31 ===')
print('CY | ' + ' '.join([f'cx{cx:02d}' for cx in range(16)]))
for cy in range(20, 32):
    row = []
    for cx in range(16):
        v = ob113[cx * 32 + cy]
        tag = 'X' if (v >> 4) != 0 else '.'
        row.append(f'{v:02x}({tag})')
    print(f'{cy:02d} | ' + ' '.join(row))

print('\n=== 151,114 cy 0..6 ===')
print('CY | ' + ' '.join([f'cx{cx:02d}' for cx in range(16)]))
for cy in range(7):
    row = []
    for cx in range(16):
        v = ob114[cx * 32 + cy]
        tag = 'X' if (v >> 4) != 0 else '.'
        row.append(f'{v:02x}({tag})')
    print(f'{cy:02d} | ' + ' '.join(row))
