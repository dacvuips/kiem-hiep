import os
import gzip
import json
import sys
from collections import deque

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

# Coordinate system:
# Map bounds: rx: 144..156 (13 regions), ry: 110..118 (9 regions)
# Total cells: cols = 13 * 16 = 208, rows = 9 * 32 = 288
# Local cell (gx, gy) where gx in 0..207, gy in 0..287
# World pos:
# x = (144 * 16 + gx) * 32
# y = (110 * 32 + gy) * 16

# Build 2D boolean grid: free[gx][gy]
grid = [[False for _ in range(288)] for _ in range(208)]
val_grid = [[0xff for _ in range(288)] for _ in range(208)]

for rk, r in regs.items():
    rx, ry = map(int, rk.split(","))
    if not (144 <= rx <= 156 and 110 <= ry <= 118):
        continue
    base_gx = (rx - 144) * 16
    base_gy = (ry - 110) * 32
    
    ob_runs = r.get("ob", [])
    arr = []
    for i in range(0, len(ob_runs), 2):
        arr.extend([ob_runs[i]] * ob_runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
        
    for cx in range(16):
        for cy in range(32):
            gx = base_gx + cx
            gy = base_gy + cy
            v = arr[cx * 32 + cy]
            val_grid[gx][gy] = v
            # Walkable if (v >> 4) == 0
            if (v >> 4) == 0:
                grid[gx][gy] = True

# Find connected components of walkable cells
visited = [[False for _ in range(288)] for _ in range(208)]
components = []

for x in range(208):
    for y in range(288):
        if grid[x][y] and not visited[x][y]:
            comp = []
            q = deque([(x, y)])
            visited[x][y] = True
            while q:
                cur_x, cur_y = q.popleft()
                comp.append((cur_x, cur_y))
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = cur_x + dx, cur_y + dy
                    if 0 <= nx < 208 and 0 <= ny < 288:
                        if grid[nx][ny] and not visited[nx][ny]:
                            visited[nx][ny] = True
                            q.append((nx, ny))
            components.append(comp)

components.sort(key=len, reverse=True)
print(f"Total connected walkable components: {len(components)}")
for i, c in enumerate(components[:10]):
    rx_set = set(p[0] // 16 + 144 for p in c)
    ry_set = set(p[1] // 32 + 110 for p in c)
    print(f"Component {i}: {len(c)} cells, spans rx={min(rx_set)}..{max(rx_set)}, ry={min(ry_set)}..{max(ry_set)}")

# Find which component contains the SPAWN point
spawn_x, spawn_y = 77400, 60500
spawn_gx = int(spawn_x / 32) - 144 * 16
spawn_gy = int(spawn_y / 16) - 110 * 32
print(f"Spawn cell gx={spawn_gx}, gy={spawn_gy}, free={grid[spawn_gx][spawn_gy]}")

spawn_comp_idx = -1
for i, c in enumerate(components):
    if (spawn_gx, spawn_gy) in set(c):
        spawn_comp_idx = i
        break
print(f"Spawn is in Component {spawn_comp_idx} with {len(components[spawn_comp_idx])} cells")
