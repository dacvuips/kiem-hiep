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

ob114 = decode_ob(regs['151,114'])

print('Region 151,114 cy = 0..10 for ALL cx = 0..15:')
print('CY | ' + ' '.join([f'c{cx:02d}' for cx in range(16)]))
for cy in range(11):
    row = []
    for cx in range(16):
        v = ob114[cx * 32 + cy]
        tag = 'X' if (v >> 4) != 0 else '.'
        row.append(f'{v:02x}({tag})')
    print(f'{cy:02d} | ' + ' '.join(row))
