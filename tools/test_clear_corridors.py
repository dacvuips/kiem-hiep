import os
import gzip
import json
import sys
from heapq import heappush, heappop
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    chunk_data = json.load(f)

regs = chunk_data["r"]

# Define all road corridors to clear
road_clears = {
    # 1. Main North Road from Spawn to Bridge (already cleared in 151,114..118, preserve rock pocket 151,116 cx=2,cy=4)
    "151,118": [(cx, cy) for cx in range(0, 14) for cy in range(0, 16)],
    "151,117": [(cx, cy) for cx in range(0, 14) for cy in range(0, 32)],
    "151,116": [(cx, cy) for cx in range(0, 14) for cy in range(0, 32) if not (cx in (2, 3) and cy in (4, 5, 6))],
    "151,115": [(cx, cy) for cx in range(0, 14) for cy in range(0, 32)],
    "151,114": [(cx, cy) for cx in range(0, 14) for cy in range(0, 32)],
    
    # 2. Wooden Bridge crossing & landings
    "151,113": [(cx, cy) for cx in range(0, 16) for cy in range(16, 32)], # Bridge west landing & deck
    "152,114": [(cx, cy) for cx in range(10, 16) for cy in range(5, 16)],  # Bridge deck east end
    "153,114": [(cx, cy) for cx in range(0, 16) for cy in range(4, 16)] +  # Bridge east landing
               [(cx, cy) for cx in range(0, 12) for cy in range(16, 32)], # Path heading south to waterfall
               
    # 3. Eastern Waterfall & South-East Path
    "154,114": [(cx, cy) for cx in range(0, 12) for cy in range(4, 18)],  # Waterfall road entrance
    "155,116": [(cx, cy) for cx in range(0, 8) for cy in range(0, 32)],   # Eastern mountain corridor
    "155,117": [(cx, cy) for cx in range(0, 8) for cy in range(0, 32)],   # Eastern mountain corridor south
    
    # 4. North-East Cliff Path
    "154,113": [(cx, cy) for cx in range(8, 16) for cy in range(24, 32)],
    "155,113": [(cx, cy) for cx in range(0, 8) for cy in range(24, 32)],
    
    # 5. Western Forest Path
    "146,116": [(cx, cy) for cx in range(4, 13) for cy in range(0, 12)],  # Road through forest
    "145,115": [(cx, cy) for cx in range(8, 16) for cy in range(2, 16)],  # Western road bend
    
    # 6. North-West Approach to Bridge
    "150,113": [(cx, cy) for cx in range(3, 12) for cy in range(0, 15)],  # Meadow to bridge path
    "149,113": [(cx, cy) for cx in range(6, 16) for cy in range(0, 12)],
    
    # 7. Central Forest Pass
    "148,114": [(cx, cy) for cx in range(2, 9) for cy in range(0, 12)],
    "148,115": [(cx, cy) for cx in range(0, 7) for cy in range(0, 18)],
    
    # 8. Southern Path West of Spawn
    "150,118": [(cx, cy) for cx in range(0, 2) for cy in range(8, 12)],
    "149,118": [(cx, cy) for cx in range(0, 2) for cy in range(6, 11)],
    "148,118": [(cx, cy) for cx in range(0, 2) for cy in range(7, 12)] +
               [(cx, cy) for cx in range(14, 16) for cy in range(8, 12)],
}

# Apply to in-memory grid
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
    arr = bytearray()
    for i in range(0, len(runs), 2):
        arr.extend([runs[i] & 0xff] * runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
        
    # Apply clears for this region
    if rk in road_clears:
        for cx, cy in road_clears[rk]:
            arr[cx * 32 + cy] = 0
            
    for cx in range(16):
        for cy in range(32):
            if (arr[cx * 32 + cy] >> 4) == 0:
                grid[base_x + cx][base_y + cy] = True

# A* test
def astar(start_cell, end_cell):
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

def cell_of_world(wx, wy):
    return (int(wx / 32) - 144 * 16, int(wy / 16) - 110 * 32)

routes = [
    ("Spawn -> South Fork (150,118)", (77400, 60500), (76900, 60500)),
    ("South Fork -> West Fork (148,118)", (76900, 60500), (75900, 60600)),
    ("West Fork -> Far West Start (146,118)", (75900, 60600), (74800, 60500)),
    ("Far West Start -> West Path Mid (146,116)", (74800, 60500), (74800, 59500)),
    ("West Path Mid -> West Forest Clearing (146,114)", (74800, 59500), (74800, 58500)),
    ("West Forest Clearing -> North-West Meadow (147,113)", (74800, 58500), (75400, 57900)),
    ("West Fork -> Central Pass (148,115)", (75900, 60600), (76000, 59000)),
    ("Central Pass -> North-West Meadow (148,113)", (76000, 59000), (75800, 58000)),
    ("North-West Meadow -> Bridge West Landing (151,113)", (75800, 58000), (77450, 58100)),
    ("Spawn -> Bridge West Landing (151,113)", (77400, 60500), (77450, 58100)),
    ("Bridge West Landing (151,113) -> Bridge East Landing (153,114)", (77450, 58100), (78400, 58500)),
    ("Bridge East Landing -> Waterfall (154,114)", (78400, 58500), (79000, 58600)),
    ("Waterfall -> South-East Path (154,116)", (79000, 58600), (79000, 59500)),
    ("South-East Path -> South-East End (155,117)", (79000, 59500), (79400, 60200)),
    ("Bridge East Landing -> North-East Cliff (154,113)", (78400, 58500), (78900, 58000)),
    # Full round trip: Spawn -> West -> NW Meadow -> Bridge -> Waterfall -> SE End
    ("Grand Tour: Spawn -> Far West -> NW Meadow", (77400, 60500), (75400, 57900)),
    ("Grand Tour: NW Meadow -> Across Bridge -> SE End", (75400, 57900), (79400, 60200)),
]

print("=== KIỂM TRA ĐƯỜNG ĐI TRÊN TẤT CẢ TUYẾN SAU KHI DỌN DẸP HÀNH LANG ===")
all_ok = True
for name, p_start, p_end in routes:
    c_start = cell_of_world(*p_start)
    c_end = cell_of_world(*p_end)
    path, msg = astar(c_start, c_end)
    status = "OK" if path else f"FAIL ({msg})"
    if not path:
        all_ok = False
    dist_str = f"{len(path)} cells" if path else "-"
    print(f"[{status:20s}] {name} (dist={dist_str})")

print(f"\n=> KẾT QUẢ TỔNG THỂ: {'TẤT CẢ TUYẾN ĐỀU THÔNG THOÁNG (PASS 100%)' if all_ok else 'VẪN CÒN ĐIỂM BỊ KẸT'}")
