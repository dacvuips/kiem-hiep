import json, gzip
from collections import deque

with gzip.open('world/maps/map_79/chunks/3_3.json.gz', 'rt') as f:
    chunk_data = json.load(f)

regions = {}
for rk, rval in chunk_data['r'].items():
    rx, ry = map(int, rk.split(','))
    runs = rval.get('ob', [])
    arr = bytearray()
    j = 0
    while j + 1 < len(runs):
        v = runs[j] & 0xff
        cnt = runs[j+1]
        arr.extend([v] * cnt)
        j += 2
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
    regions[(rx, ry)] = arr[:512]

def is_free(cx, cy):
    rx = cx // 16
    ry = cy // 32
    arr = regions.get((rx, ry))
    if arr is None:
        return False
    idx = (cx - rx * 16) * 32 + (cy - ry * 32)
    return (arr[idx] >> 4) == 0

# Spawn 1 (at 209, 196): cell (1677, 3142)
start_cell = (1677, 3142)

# Monsters are at ry=99, rx=104:
# py ~ 50872 -> cy = 50872 / 16 = 3179
# px ~ 53438 -> cx = 53438 / 32 = 1670
monster_cells = [
    (1670, 3179),
    (1661, 3179),
    (1668, 3183),
    (1710, 3192),
    (1626, 3219),
]

# Let's flood fill from start_cell to see all reachable cells:
queue = deque([start_cell])
visited = {start_cell}
while queue:
    cur = queue.popleft()
    for d in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        nxt = (cur[0] + d[0], cur[1] + d[1])
        if nxt not in visited and is_free(*nxt):
            visited.add(nxt)
            queue.append(nxt)

print(f'Total reachable cells from (209, 196): {len(visited)}')
for mc in monster_cells:
    print(f'Can reach monster at cell {mc}? -> {mc in visited}')

min_cx = min(c[0] for c in visited)
max_cx = max(c[0] for c in visited)
min_cy = min(c[1] for c in visited)
max_cy = max(c[1] for c in visited)

print(f'Reachable range: cx=[{min_cx}, {max_cx}] (coord_x=[{min_cx*32//256}, {max_cx*32//256}])')
print(f'Reachable range: cy=[{min_cy}, {max_cy}] (coord_y=[{min_cy*16//256}, {max_cy*16//256}])')
