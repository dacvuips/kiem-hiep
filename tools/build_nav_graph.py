"""Dựng đồ thị tìm đường TOÀN MAP (tầng thô) cho map chia khối: world/main_map/nav_graph.bin

Lưới vật cản gốc quá lớn (hàng trăm triệu ô) để chạy A* thẳng, nên game tìm đường 2 tầng:
  - tầng thô (file này): mỗi VÙNG 512x512 px (16x32 ô) tách thành các "mảng đất liền" (ô trống nối nhau 4 hướng trong vùng);
    mỗi mảng là 1 nút, 2 nút nối nhau khi 2 mảng ở 2 vùng kề nhau có cặp ô trống sát nhau qua mép vùng.
    A* trên đồ thị này tìm được đường vòng khắp map (đi ngược, vòng xa...), không chỉ nhắm thẳng về phía đích.
  - tầng chi tiết (game, VltkWorld.find_path): A* ô lưới quanh nhân vật, đi lần lượt qua các nút của lộ trình thô.

Định dạng (little-endian, nén gzip):
  b"NAVG", u32 version=1, u32 node_count, u32 edge_count,
  node_count x u32: rx | ry << 10 | cx << 21 | cy << 25   (vùng rx, ry; ô đại diện cx 0..15, cy 0..31 trong vùng)
  edge_count x (u32 a, u32 b)

Chạy lại mỗi khi cập nhật map (tools/update_main_map.py):
  python tools/build_nav_graph.py [world/main_map]
"""
import glob
import gzip
import json
import os
import struct
import sys
import time

COLS, ROWS = 16, 32          # ô mỗi vùng (cols_per_region, rows_per_region)
CELLS = COLS * ROWS
MIN_COMPONENT = 4            # mảng nhỏ hơn chừng này ô (khe kẹt giữa vật cản) bỏ qua


def decode_free(runs):
    """RLE [giá trị, số ô, ...] theo thứ tự q -> ô (q // 32, q % 32); ô bị chặn khi (giá trị >> 4) != 0. Trả list bool trống."""
    free = [True] * CELLS
    i = 0
    for j in range(0, len(runs) - 1, 2):
        n = int(runs[j + 1])
        if (int(runs[j]) >> 4) != 0:
            for q in range(i, min(i + n, CELLS)):
                free[q] = False
        i += n
    return free


def components(free):
    """Gán nhãn mảng (4 hướng). Trả (labels: list[int] -1 = chặn, reps: list[(cx, cy)], sizes)."""
    labels = [-1] * CELLS
    reps, sizes = [], []
    for start in range(CELLS):
        if not free[start] or labels[start] != -1:
            continue
        lab = len(reps)
        stack = [start]
        labels[start] = lab
        cells = []
        while stack:
            q = stack.pop()
            cells.append(q)
            x, y = divmod(q, ROWS)
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < COLS and 0 <= ny < ROWS:
                    nq = nx * ROWS + ny
                    if free[nq] and labels[nq] == -1:
                        labels[nq] = lab
                        stack.append(nq)
        # ô đại diện: ô của mảng gần trọng tâm nhất (toạ độ px để ô 32x16 không lệch)
        mx = sum(c // ROWS for c in cells) / len(cells)
        my = sum(c % ROWS for c in cells) / len(cells)
        best = min(cells, key=lambda c: ((c // ROWS - mx) * 32) ** 2 + ((c % ROWS - my) * 16) ** 2)
        reps.append(divmod(best, ROWS))
        sizes.append(len(cells))
    return labels, reps, sizes


def main():
    sys.stdout.reconfigure(encoding="utf-8")   # console Windows (cp1252) không in được tiếng Việt
    map_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("world", "main_map")
    t0 = time.time()
    regions = {}
    for f in glob.glob(os.path.join(map_dir, "chunks", "*.json.gz")):
        with gzip.open(f) as fh:
            doc = json.load(fh)
        for key, reg in doc["r"].items():
            rx, ry = (int(v) for v in key.split(","))
            regions[(rx, ry)] = reg.get("ob", [])
    print("vùng: %d (%.1fs)" % (len(regions), time.time() - t0))

    node_of = {}      # (rx, ry) -> (labels, [node id theo nhãn hoặc -1])
    nodes = []
    for (rx, ry), runs in regions.items():
        labels, reps, sizes = components(decode_free(runs))
        ids = []
        for lab, (cx, cy) in enumerate(reps):
            if sizes[lab] < MIN_COMPONENT:
                ids.append(-1)
                continue
            ids.append(len(nodes))
            nodes.append(rx | ry << 10 | cx << 21 | cy << 25)
        node_of[(rx, ry)] = (labels, ids)
    print("nút: %d (%.1fs)" % (len(nodes), time.time() - t0))

    edges = set()
    for (rx, ry), (labels, ids) in node_of.items():
        right = node_of.get((rx + 1, ry))
        if right:
            for y in range(ROWS):
                a, b = labels[(COLS - 1) * ROWS + y], right[0][y]
                if a >= 0 and b >= 0 and ids[a] >= 0 and right[1][b] >= 0:
                    edges.add((ids[a], right[1][b]))
        down = node_of.get((rx, ry + 1))
        if down:
            for x in range(COLS):
                a, b = labels[x * ROWS + ROWS - 1], down[0][x * ROWS]
                if a >= 0 and b >= 0 and ids[a] >= 0 and down[1][b] >= 0:
                    edges.add((ids[a], down[1][b]))
    print("cạnh: %d (%.1fs)" % (len(edges), time.time() - t0))

    out = bytearray(b"NAVG")
    out += struct.pack("<III", 1, len(nodes), len(edges))
    out += struct.pack("<%dI" % len(nodes), *nodes)
    flat = [v for e in sorted(edges) for v in e]
    out += struct.pack("<%dI" % len(flat), *flat)
    path = os.path.join(map_dir, "nav_graph.bin")
    with open(path, "wb") as fh:
        fh.write(gzip.compress(bytes(out), 9))
    print("ghi %s: %.1f KB (%.1fs)" % (path, os.path.getsize(path) / 1024, time.time() - t0))


if __name__ == "__main__":
    main()
