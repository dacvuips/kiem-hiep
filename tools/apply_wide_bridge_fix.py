import gzip, json

with gzip.open('world/maps/map_2/chunks/4_3.json.gz', 'rt', encoding='utf-8') as f:
    chunk_data = json.load(f)

def decode_ob(runs):
    arr = bytearray()
    for i in range(0, len(runs), 2):
        val = runs[i] & 0xff
        cnt = runs[i+1]
        arr.extend([val] * cnt)
    return arr

def encode_ob(byte_arr):
    runs = []
    if not byte_arr:
        return runs
    curr_val = byte_arr[0]
    count = 1
    for b in byte_arr[1:]:
        if b == curr_val:
            count += 1
        else:
            runs.extend([curr_val, count])
            curr_val = b
            count = 1
    runs.extend([curr_val, count])
    return runs

ob113 = decode_ob(chunk_data['r']['151,113']['ob'])
ob114 = decode_ob(chunk_data['r']['151,114']['ob'])

# Cells to clear in 151,113:
# cx=4: cy=27, 28, 29
# cx=5: cy=28, 29, 30
# cx=6: cy=28, 29, 30
# cx=7: cy=29, 30
# cx=8: cy=29, 30
# cx=9: cy=29, 30
# cx=10: cy=29, 30
# cx=11: cy=29, 30
# cx=12: cy=29, 30
clear_113 = [
    (4, 27), (4, 28), (4, 29),
    (5, 28), (5, 29), (5, 30),
    (6, 28), (6, 29), (6, 30),
    (7, 29), (7, 30),
    (8, 29), (8, 30),
    (9, 29), (9, 30),
    (10, 29), (10, 30),
    (11, 29), (11, 30),
    (12, 29)
]

for cx, cy in clear_113:
    idx = cx * 32 + cy
    ob113[idx] = 0x00

# Cells to clear in 151,114:
clear_114 = [
    (5, 1), (6, 1)
]
for cx, cy in clear_114:
    idx = cx * 32 + cy
    ob114[idx] = 0x00

chunk_data['r']['151,113']['ob'] = encode_ob(ob113)
chunk_data['r']['151,114']['ob'] = encode_ob(ob114)

with gzip.open('world/maps/map_2/chunks/4_3.json.gz', 'wt', encoding='utf-8') as f:
    json.dump(chunk_data, f, separators=(',', ':'))

print('Updated 4_3.json.gz with wide bridge path and smooth exit to right landmass!')
