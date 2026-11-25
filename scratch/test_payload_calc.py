# Python reproduction of skill_definition.gd eval_level_points & get_state_payload
def eval_level_points(points, level):
    count = len(points) // 3
    if count == 0: return 0
    if count == 1: return int(points[1])
    seg = 1
    if level > points[(count - 1) * 3]:
        p_pre_idx = (count - 2) * 3
        p_last_idx = (count - 1) * 3
        x1 = points[p_pre_idx]
        y1 = points[p_pre_idx + 1]
        x2 = points[p_last_idx]
        y2 = points[p_last_idx + 1]
        if x2 == x1: return int(y2)
        return int((y2 - y1) * (level - x1) / (x2 - x1) + y1)
    for i in range(1, count):
        if level <= points[i * 3]:
            seg = i
            break
    p1_idx = (seg - 1) * 3
    p2_idx = seg * 3
    x1 = points[p1_idx]
    y1 = points[p1_idx + 1]
    x2 = points[p2_idx]
    y2 = points[p2_idx + 1]
    if x2 == x1: return int(y2)
    return int((y2 - y1) * (level - x1) / (x2 - x1) + y1)

# PackedFloat32Array(1, 50, 0, 20, 200, 0)
val_1 = eval_level_points([1, 50, 0, 20, 200, 0], 20)
# frames: PackedFloat32Array(1, 90, 0, 20, 270, 0) -> 90 frames = 5s, 270 frames = 15s (18 frames/sec)
frames_20 = eval_level_points([1, 90, 0, 20, 270, 0], 20)
print(f"damage2addmana_p at lv 20: val={val_1}%, frames={frames_20} ({frames_20/18}s)")
val_series = eval_level_points([1, 20, 0, 20, 50, 0], 20)
print(f"seriesdamage_p at lv 20: val={val_series}%")
