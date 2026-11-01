import gzip, json
from collections import deque

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

decoded_cache = {rk: decode_ob(rdata) for rk, rdata in regs.items()}

# Bridge exit: cell at right edge of bridge:
# Region 151, 113: cx=8..12, cy=29..31
# Let's see: from cell (151*16 + 8, 113*32 + 30) = (2424, 3646)
start = (2424, 3646)

visited = set([start])
queue = deque([start])

while queue:
    curr = queue.popleft()
    for dx, dy in [(1,0), (-1,0), (0,1), (0,-1), (1,1), (-1,-1), (1,-1), (-1,1)]:
        nx, ny = curr[0] + dx, curr[1] + dy
        if (nx, ny) in visited: continue
        rx = nx // 16
        cx = nx % 16
        ry = ny // 32
        cy = ny % 32
        ob = decoded_cache.get(f'{rx},{ry}')
        if not ob or len(ob) != 512: continue
        if (ob[cx * 32 + cy] >> 4) == 0:
            visited.add((nx, ny))
            queue.append((nx, ny))

print(f'Total connected cells from bridge exit: {len(visited)}')

# Let's find the regions visited
regions_visited = set()
for p in visited:
    rx = p[0] // 16
    ry = p[1] // 32
    regions_visited.add((rx, ry))

print(f'Regions reachable from bridge exit: {sorted(list(regions_visited))}')
