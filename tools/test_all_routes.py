import os
import gzip
import json
import sys
from heapq import heappush, heappop

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

# Cell size: 32x16
# Map origin: rx=144, ry=110. Total 13 cols of regions, 9 rows of regions.
COLS = 13 * 16 # 208
ROWS = 9 * 32  # 288

grid = [[False for _ in range(ROWS)] for _ in range(COLS)]
for rk, r in regs.items():
    rx, ry = map(int, rk.split(","))
    if not (144 <= rx <= 156 and 110 <= ry <= 118):
        continue
    base_x = (rx - 144) * 16
    base_y = (ry - 110) * 32
    runs = r.get("ob", [])
    arr = []
    for i in range(0, len(runs), 2):
        arr.extend([runs[i]] * runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
    for cx in range(16):
        for cy in range(32):
            if (arr[cx * 32 + cy] >> 4) == 0:
                grid[base_x + cx][base_y + cy] = True

def cell_of_world(wx, wy):
    return (int(wx / 32) - 144 * 16, int(wy / 16) - 110 * 32)

def world_of_cell(cx, cy):
    return ((cx + 144 * 16) * 32 + 16, (cy + 110 * 32) * 16 + 8)

def astar(start_cell, end_cell):
    if not (0 <= start_cell[0] < COLS and 0 <= start_cell[1] < ROWS):
        return None, "Start out of bounds"
    if not (0 <= end_cell[0] < COLS and 0 <= end_cell[1] < ROWS):
        return None, "End out of bounds"
    if not grid[start_cell[0]][start_cell[1]]:
        return None, "Start is solid"
    if not grid[end_cell[0]][end_cell[1]]:
        return None, "End is solid"

    pq = [(0, 0, start_cell)]
    dist = {start_cell: 0}
    parent = {}

    def h(c):
        return abs(c[0] - end_cell[0]) + abs(c[1] - end_cell[1])

    while pq:
        f, g_cost, curr = heappop(pq)
        if curr == end_cell:
            path = []
            while curr in parent:
                path.append(curr)
                curr = parent[curr]
            path.append(start_cell)
            return path[::-1], "OK"

        if g_cost > dist.get(curr, 1e9):
            continue

        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = curr[0] + dx, curr[1] + dy
            if 0 <= nx < COLS and 0 <= ny < ROWS and grid[nx][ny]:
                nxt = (nx, ny)
                cost = g_cost + 1
                if cost < dist.get(nxt, 1e9):
                    dist[nxt] = cost
                    parent[nxt] = curr
                    heappush(pq, (cost + h(nxt), cost, nxt))

    return None, "No path found (BLOCKED)"

# Test key routes on the minimap
routes = [
    # Route A: Spawn -> South road going West
    ("Spawn -> South Fork (150,118)", (77400, 60500), (76900, 60500)),
    ("South Fork -> West Fork (148,118)", (76900, 60500), (75900, 60600)),
    ("West Fork -> Far West Start (146,118)", (75900, 60600), (74800, 60500)),
    
    # Route B: Far West Path heading North
    ("Far West Start -> West Path Mid (146,116)", (74800, 60500), (74800, 59500)),
    ("West Path Mid -> West Forest Clearing (146,114)", (74800, 59500), (74800, 58500)),
    ("West Forest Clearing -> North-West Meadow (147,113)", (74800, 58500), (75400, 57900)),
    
    # Route C: Central Path heading North
    ("West Fork -> Central Pass (148,115)", (75900, 60600), (76000, 59000)),
    ("Central Pass -> North-West Meadow (148,113)", (76000, 59000), (75800, 58000)),
    
    # Route D: North-West Meadow to Bridge
    ("North-West Meadow -> Bridge West Landing (151,113)", (75800, 58000), (77450, 58100)),
    
    # Route E: Spawn straight to Bridge
    ("Spawn -> Bridge West Landing (151,113)", (77400, 60500), (77450, 58100)),
    
    # Route F: Crossing the Wooden Bridge
    ("Bridge West Landing (151,113) -> Bridge East Landing (153,114)", (77450, 58100), (78400, 58500)),
    
    # Route G: Bridge East Landing -> Waterfall
    ("Bridge East Landing -> Waterfall (154,114)", (78400, 58500), (79000, 58600)),
    
    # Route H: Waterfall -> South-East Path
    ("Waterfall -> South-East Path (154,116)", (79000, 58600), (79000, 59500)),
    ("South-East Path -> South-East End (155,117)", (79000, 59500), (79400, 60200)),
    
    # Route I: Bridge East Landing -> North-East Cliff
    ("Bridge East Landing -> North-East Cliff (154,113)", (78400, 58500), (78900, 58000)),
]

print("=== KIỂM TRA ĐƯỜNG ĐI TRÊN TẤT CẢ TUYẾN MINIMAP ===")
for name, p_start, p_end in routes:
    c_start = cell_of_world(*p_start)
    c_end = cell_of_world(*p_end)
    path, msg = astar(c_start, c_end)
    status = "OK" if path else f"FAIL ({msg})"
    dist_str = f"{len(path)} cells" if path else "-"
    print(f"[{status:20s}] {name} (dist={dist_str})")
