extends Node

const StageRewards = preload("res://systems/stage_rewards.gd")
const StageVictoryPopup = preload("res://ui/hud/stage_victory_popup.gd")

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
var stage_cleared: bool = false

func _ready() -> void:
	current_interval = initial_spawn_interval
	if not GameManager.stage_started.is_connected(_on_stage_started):
		GameManager.stage_started.connect(_on_stage_started)

func _on_stage_started(_stage: StageData) -> void:
	elapsed_time = 0.0
	boss_spawned = false
	stage_cleared = false
	time_since_last_spawn = 0.0
	set_process(true)

func _process(delta: float) -> void:
	## Player đã chết hoặc màn đã vượt ải thành công — dừng sinh quái mới ngay
	if GameManager.is_game_over or stage_cleared:
		return

	elapsed_time += delta
	time_since_last_spawn += delta

	var stage: StageData = GameManager.current_stage
	var boss_time := stage.get_boss_spawn_time() if stage != null else 120.0
	if stage and not boss_spawned and elapsed_time >= boss_time and stage.boss_tier:
		boss_spawned = true
		spawn_boss(stage.boss_tier)
		return

	## Khi Boss đã xuất hiện (chặng 3/3 thời gian), dừng sinh thêm quái thường để tập trung quyết chiến Thủ Quan
	if boss_spawned:
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
	boss.global_position = get_boss_spawn_position()
	boss.setup(boss_entry)
	GameManager.notify_boss_spawned()
	if boss.has_signal("died"):
		boss.died.connect(_on_boss_died.bind(boss))

	var tree := get_tree()
	if tree != null:
		var p := tree.get_first_node_in_group("player")
		if p and p.has_method("notify"):
			p.notify("Thủ Quan [%s] đã xuất hiện! Hãy tiêu diệt để Vượt Ải!" % boss_entry.tier.tier_name)

## Tìm vị trí thả Boss cách xa người chơi (ở trung tâm hoặc góc/rìa đối diện)
func get_boss_spawn_position() -> Vector2:
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player") as Node2D if tree else null
	var ppos := player.global_position if player != null else Vector2.ZERO

	# Nếu có đấu trường: ưu tiên thả Boss ở trung tâm đấu trường (nếu cách xa người chơi >= 600px)
	if VltkWorld.has_arena():
		var w := VltkWorld.current
		if w != null and w.arena_rect.has_area():
			var center := w.arena_rect.get_center()
			if ppos == Vector2.ZERO or center.distance_to(ppos) >= 600.0:
				var candidate := w._free_position_near(center)
				if candidate != Vector2.ZERO:
					return candidate

	# Chọn vị trí rìa/góc xa người chơi nhất (>= 800px)
	var best_pos := Vector2.ZERO
	var best_dist := -1.0
	for i in range(12):
		var pos := get_random_spawn_position()
		var dist := pos.distance_to(ppos) if ppos != Vector2.ZERO else 1000.0
		if dist > best_dist:
			best_dist = dist
			best_pos = pos
		if dist >= 800.0:
			return pos
	return best_pos if best_pos != Vector2.ZERO else get_random_spawn_position()

func _on_boss_died(_boss: Node = null) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	if not GameManager.current_stage or GameManager.is_game_over:
		return

	# 1. Đánh dấu vượt ải thành công và LẬP TỨC DỪNG PHÁT SINH QUÁI
	stage_cleared = true
	set_process(false)
	var parent_node := get_parent()
	if parent_node != null:
		var pickup_spawner := parent_node.get_node_or_null("PickupSpawner")
		if pickup_spawner and pickup_spawner.has_method("set_process"):
			pickup_spawner.set_process(false)

	# 2. Quét sạch tất cả quái thường còn lại trên map để bảo đảm an toàn cho người chơi
	var enemies := tree.get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy != _boss:
			enemy.queue_free()
	var monsters := tree.get_nodes_in_group("monster")
	for monster in monsters:
		if is_instance_valid(monster) and monster != _boss:
			monster.queue_free()

	# 3. Ghi nhận mở khoá màn tiếp theo
	var profile := GameManager.local_profile
	if profile == null:
		profile = SaveManager.load_profile()
		GameManager.local_profile = profile

	var cur_stage: StageData = GameManager.current_stage
	var idx: int = -1
	if GameManager != null and GameManager.has_method("get_stage_index"):
		idx = GameManager.get_stage_index(cur_stage)
	if idx < 0 and cur_stage != null:
		idx = StageRewards.get_stage_tier(cur_stage) - 1

	if profile != null and idx >= 0:
		if profile.stages_cleared <= idx:
			profile.stages_cleared = idx + 1
			SaveManager.save_profile(profile)
			SaveManager.flush_online()

	# 4. Trao phần thưởng ngẫu nhiên theo từng màn (cấp càng cao thưởng càng xịn)
	var rewards: Dictionary = {}
	if profile != null:
		rewards = StageRewards.roll_stage_rewards(cur_stage, profile, idx)
	GameManager.notify_stage_completed()
	var p := tree.get_first_node_in_group("player")
	if p and p.has_method("notify"):
		p.notify("Chúc mừng đại hiệp đã đánh bại Thủ Quan và vượt ải thành công!")
	if p and p.has_method("refresh_combat_stats"):
		p.refresh_combat_stats()
	# 5. Hiển thị popup nhận thưởng trực quan
	if rewards.is_empty() and cur_stage != null:
		rewards = {
			"stage_name": cur_stage.stage_name,
			"tier": (idx + 1) if idx >= 0 else 1,
		}
	if not rewards.is_empty():
		StageVictoryPopup.show_reward(self, rewards)

func spawn_enemy() -> void:
	var entry := get_random_unlocked_entry()
	if entry == null or entry.tier.enemy_scene == null:
		return

	var enemy := ObjectPool.acquire(entry.tier.enemy_scene, _entity_parent()) as Node2D
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
	if entry.lock_time > 0.0 and elapsed_time >= entry.lock_time:
		return 0.0
	var time_since_unlock := elapsed_time - entry.unlock_time
	var weight := entry.spawn_weight + entry.weight_change_per_second * time_since_unlock
	return max(0.0, weight)

func get_random_unlocked_entry() -> EnemySpawnEntry:
	var entries := get_current_enemy_entries()
	var unlocked := entries.filter(func(e: EnemySpawnEntry) -> bool:
		if elapsed_time < e.unlock_time:
			return false
		if e.lock_time > 0.0 and elapsed_time >= e.lock_time:
			return false
		return true
	)
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
