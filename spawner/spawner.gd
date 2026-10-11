extends Node

## Danh sách quái dùng khi không có StageData (fallback cho test nhanh trong Editor).
## Khi có GameManager.current_stage, spawner luôn ưu tiên đọc enemy_tiers từ đó.
@export var fallback_enemy_tiers: Array[EnemySpawnEntry] = []

## Khoảng cách spawn tính từ viền camera/viewport
@export var spawn_margin: float = 50.0

## Thời gian giữa 2 lần spawn lúc bắt đầu (giây)
@export var initial_spawn_interval: float = 2.0

## Thời gian giữa 2 lần spawn tối thiểu (không giảm dưới mức này)
@export var min_spawn_interval: float = 0.3

## Mỗi giây, thời gian spawn giảm bao nhiêu (độ khó tăng dần)
@export var interval_decrease_per_second: float = 0.01

## Cứ mỗi khoảng thời gian này (giây), số quái mỗi đợt spawn tăng thêm 1
@export var seconds_per_extra_enemy: float = 30.0

## Hệ số số lượng quái xuất hiện theo thời gian (0.9 = giảm xuống 90%).
const SPAWN_RATE_MULTIPLIER := 0.9

var current_interval: float
var time_since_last_spawn: float = 0.0
var elapsed_time: float = 0.0
var boss_spawned: bool = false

func _ready() -> void:
	current_interval = initial_spawn_interval

func _process(delta: float) -> void:
	## Player đã chết — dừng sinh quái mới ngay, không có ý nghĩa tiếp tục tăng độ khó/spawn
	## thêm quái khi không còn ai để chúng tấn công.
	if GameManager.is_game_over:
		return

	elapsed_time += delta
	time_since_last_spawn += delta

	var stage: StageData = GameManager.current_stage
	if stage and not boss_spawned and elapsed_time >= stage.stage_duration and stage.boss_tier:
		boss_spawned = true
		spawn_boss(stage.boss_tier)
		return

	## SPAWN_RATE_MULTIPLIER < 1 = quái xuất hiện ÍT hơn theo thời gian (khoảng cách giữa 2 đợt giãn ra 1 / hệ số).
	current_interval = max(min_spawn_interval, initial_spawn_interval - elapsed_time * interval_decrease_per_second) / SPAWN_RATE_MULTIPLIER

	if time_since_last_spawn >= current_interval:
		time_since_last_spawn = 0.0
		var enemies_per_wave := 1 + int(elapsed_time / seconds_per_extra_enemy)
		for i in range(enemies_per_wave):
			spawn_enemy()

func spawn_boss(boss_entry: EnemySpawnEntry) -> void:
	if boss_entry.tier.enemy_scene == null:
		return
	var boss := boss_entry.tier.enemy_scene.instantiate()
	_entity_parent().add_child(boss)
	boss.global_position = get_random_spawn_position()
	boss.setup(boss_entry)
	GameManager.notify_boss_spawned()

func spawn_enemy() -> void:
	var entry := get_random_unlocked_entry()
	if entry == null or entry.tier.enemy_scene == null:
		return

	var enemy := entry.tier.enemy_scene.instantiate()
	_entity_parent().add_child(enemy)
	enemy.global_position = get_random_spawn_position()
	enemy.setup(entry)

## Quái sinh vào lớp vật thể của map VLTK (nếu có) để sắp độ sâu cùng nhà/cây; không có map thì như cũ (cha của Spawner).
func _entity_parent() -> Node:
	var p := VltkWorld.entity_parent()
	return p if p != null else get_parent()

func get_current_enemy_entries() -> Array[EnemySpawnEntry]:
	if GameManager.current_stage:
		return GameManager.current_stage.enemy_tiers
	return fallback_enemy_tiers

func get_current_weight(entry: EnemySpawnEntry) -> float:
	var time_since_unlock := elapsed_time - entry.unlock_time
	var weight := entry.spawn_weight + entry.weight_change_per_second * time_since_unlock
	return max(0.0, weight)

func get_random_unlocked_entry() -> EnemySpawnEntry:
	var entries := get_current_enemy_entries()
	var unlocked := entries.filter(func(e): return elapsed_time >= e.unlock_time)
	if unlocked.is_empty():
		return null

	var weights: Array[float] = []
	var total_weight := 0.0
	for entry in unlocked:
		var w := get_current_weight(entry)
		weights.append(w)
		total_weight += w

	if total_weight <= 0.0:
		return unlocked[0]

	var roll := randf() * total_weight
	var cumulative := 0.0
	for i in range(unlocked.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return unlocked[i]

	return unlocked[-1]

func get_random_spawn_position() -> Vector2:
	## Có ô vuông màn chơi trên map chính: quái sinh ở rìa TRONG của ô (không theo viền camera nữa).
	if VltkWorld.has_arena():
		return VltkWorld.random_edge_spawn()
	var camera := get_viewport().get_camera_2d()
	## Vùng nhìn thấy trong thế giới = khung màn hình / zoom camera (zoom < 1 nhìn rộng hơn) — quái phải sinh ra NGOÀI vùng đó.
	var viewport_size := get_viewport().get_visible_rect().size / (camera.zoom if camera else Vector2.ONE)
	var center := camera.global_position if camera else Vector2.ZERO

	var half_width := viewport_size.x / 2.0 + spawn_margin
	var half_height := viewport_size.y / 2.0 + spawn_margin

	var side := randi() % 4
	var pos := Vector2.ZERO
	match side:
		0: # top
			pos = Vector2(randf_range(-half_width, half_width), -half_height)
		1: # bottom
			pos = Vector2(randf_range(-half_width, half_width), half_height)
		2: # left
			pos = Vector2(-half_width, randf_range(-half_height, half_height))
		3: # right
			pos = Vector2(half_width, randf_range(-half_height, half_height))

	return center + pos
