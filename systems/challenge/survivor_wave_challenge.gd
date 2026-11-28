extends Node
class_name SurvivorWaveChallenge
## HỆ THỐNG VƯỢT ẢI LUYỆN CÔNG OFFLINE (SURVIVOR WAVE ACTION)
##
## Thiết kế theo đúng đặc tả của người dùng:
## - Bản đồ ban đầu sạch bóng quái (clear hết quái tĩnh của map).
## - Quái xuất hiện liên tục và tự động chạy dí theo nhân vật để đánh (Aggro Swarm).
## - Đợt 1: 50 quái (loại quái 1 của map). Diệt hết -> Xuất hiện Boss 1 (loại 1, kích thước x10, máu x30).
## - Đợt 2: 100 quái (loại quái 2 khác loại 1). Diệt hết -> Xuất hiện Boss 2 (loại 2, kích thước x10, máu x30).
## - Đợt 3: 200 quái (loại quái 3 khác loại 1 & 2). Diệt hết -> Xuất hiện Boss 3 (loại 3, kích thước x10, máu x30).
## - Tiêu diệt Boss 3 -> Hoàn thành Ải, đánh giá 3 sao và mở khóa ải kế tiếp!

const StageVictoryPopup = preload("res://ui/hud/stage_victory_popup.gd")
const StageRewards = preload("res://systems/stage_rewards.gd")
const SelectedSkillsWindow = preload("res://ui/hud/selected_skills_window.gd")

const WAVE_TARGETS := {
	1: 300,
	2: 600,
	3: 1000
}

## Hệ số máu quái theo đợt: Đợt 1 x1 (bình thường), Đợt 2 x3, Đợt 3 x6
const WAVE_HP_MULTIPLIERS := {
	1: 1.0,
	2: 3.0,
	3: 6.0
}

## Thời gian xuất 1 đợt lính: 10 giây / đợt
const SPAWN_INTERVAL := 10.0
const CREEPS_PER_WAVE := {
	1: 20,
	2: 35,
	3: 50
}
const MAX_ACTIVE_CREEPS := {
	1: 60,
	2: 90,
	3: 120
}

var current_wave: int = 1
var wave_monsters_spawned: int = 0
var wave_monsters_killed: int = 0
var boss_active: bool = false
var current_boss: VltkMonster = null
var _alive_monsters: Array[VltkMonster] = []

var _monster_types: Array[Dictionary] = []
var _current_wave_creep_hp: float = 33.33
var _player: Node2D = null
var _map_entry: Dictionary = {}
var _tier: int = 1
var _stage_cleared: bool = false
var _wave_started: bool = false
var elapsed_time: float = 0.0
var _spawn_timer: float = 0.0
var _wave_time: float = 0.0
var _is_transitioning: bool = false

# HUD
var _hud: CanvasLayer
var _title_lbl: Label
var _wave_lbl: Label
var _progress_lbl: Label
var _clock_lbl: Label
var _score_lbl: Label
var _banner_lbl: Label
var _banner_timer: float = 0.0

# Điều khiển Tạm Dừng & Tốc Độ Trận Đấu
var is_paused: bool = false
var _pause_btn: Button = null
var _pause_overlay: Control = null
var _speed_btn: Button = null
var current_speed_idx: int = 0
const SPEED_STEPS := [1.0, 2.0, 4.0]
const SPEED_LABELS := ["⏩ 1x", "⏩ 2x", "⏩ 4x"]
const SPEED_COLORS := [
	Color(0.88, 0.88, 0.92),
	Color(0.3, 0.95, 0.65),
	Color(1.0, 0.85, 0.25)
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("survivor_challenge")
	SurvivorManager.reset()
	PlayerStats.enemies_killed = 0
	PlayerStats.current_score = 0
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_map_entry = GameManager.field_map
	_tier = int(_map_entry.get("tier", MapCatalog.tier_of_level(int(_map_entry.get("level", 10)))))
	if _tier <= 0:
		_tier = 1

	# Nạp pool kỹ năng tấn công môn phái đúng theo vũ khí đang cầm
	var p_prof := GameManager.local_profile
	var s_id: String = p_prof.sect_id if p_prof != null and p_prof.sect_id != "" else "vo_dang"
	var w_class: int = Equipment.get_weapon_class(p_prof.equipment) if p_prof != null else -1
	SurvivorManager.init_pool(s_id, w_class)

	_init_monster_types()
	_build_hud()

	# Quét sạch bất kỳ quái tĩnh nào còn sót lại trên map
	_sweep_initial_map_monsters()

	# Cấu hình thanh skill: ẩn các slot skill và hiện nút Võ Công Đã Chọn
	_setup_survivor_skill_bar()

	# Lắng nghe khi kỹ năng được chọn (qua PlayerStats hoặc UI)
	PlayerStats.survivor_skills_changed.connect(func(_skills: Dictionary) -> void:
		if not _wave_started and not PlayerStats.survivor_skills.is_empty():
			_on_initial_skill_selected()
	)

	# Hiển thị bảng chọn kỹ năng khởi đầu. Đợt 1 chỉ bắt đầu sau khi người chơi đã chọn xong!
	_open_initial_skill_selection()

func _setup_survivor_skill_bar() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var skill_bar := tree.get_first_node_in_group(SkillBarUI.GROUP) as SkillBarUI
	if skill_bar == null and tree.current_scene != null:
		skill_bar = tree.current_scene.get_node_or_null("UI/SkillBarUI") as SkillBarUI
	if skill_bar == null and tree.current_scene != null:
		skill_bar = tree.current_scene.find_child("SkillBarUI", true, false) as SkillBarUI
	if skill_bar != null and skill_bar.has_method("enable_survivor_mode"):
		skill_bar.enable_survivor_mode(true)

func _open_initial_skill_selection() -> void:
	var level_up_ui: Node = null
	if get_parent() != null:
		level_up_ui = get_parent().get_node_or_null("LevelUpUi")
		if level_up_ui == null:
			level_up_ui = get_parent().get_node_or_null("UI/LevelUpUI")
	if level_up_ui == null and get_tree() != null:
		level_up_ui = get_tree().get_first_node_in_group("level_up_ui")

	# Nếu đã có kỹ năng khởi đầu (ví dụ được nạp trước hoặc trong mock test), bắt đầu ngay
	if not PlayerStats.survivor_skills.is_empty():
		_on_initial_skill_selected()
		return

	if level_up_ui and level_up_ui.has_method("show_initial_skill_selection"):
		# Dừng thời gian và tạm dừng toàn bộ game khi đang chọn kỹ năng khởi đầu
		get_tree().paused = true
		if not level_up_ui.is_connected("initial_skill_selected", _on_initial_skill_selected):
			level_up_ui.connect("initial_skill_selected", _on_initial_skill_selected)
		level_up_ui.show_initial_skill_selection()
	else:
		# Fallback nếu không có UI (ví dụ trong test case headless): bắt đầu đợt 1 luôn
		_start_wave(1)

func _on_initial_skill_selected() -> void:
	if _wave_started:
		return
	_wave_started = true
	if get_tree() != null:
		get_tree().paused = false
	_start_wave(1)

func _process(delta: float) -> void:
	if _stage_cleared or GameManager.is_game_over:
		return

	# DỪNG THỜI GIAN VÀ TIẾN TRÌNH KHI ĐANG TẠM DỪNG HOẶC ĐANG CHỌN KỸ NĂNG
	if not _wave_started or get_tree().paused:
		return

	elapsed_time += delta
	_update_hud_display()

	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _banner_lbl != null:
			var tw := create_tween()
			tw.tween_property(_banner_lbl, "modulate:a", 0.0, 0.4)

	# Khi Boss đang sống hoặc đang chờ chuyển đợt thì không spawn quái thường
	if boss_active or _is_transitioning:
		return

	var target_count: int = WAVE_TARGETS.get(current_wave, 300)

	if wave_monsters_spawned < target_count:
		_wave_time += delta
		_spawn_timer += delta

		# Nhịp sinh quái: mỗi 10 giây xuất 1 đợt lính (SPAWN_INTERVAL), hoặc nếu quái trên sân còn ít (< 15) thì bổ sung ngay
		if _spawn_timer >= SPAWN_INTERVAL or _alive_monsters.size() < 15:
			_spawn_timer = 0.0
			_spawn_wave_batch()

func _init_monster_types() -> void:
	_monster_types.clear()
	var raw_mons: Array = _map_entry.get("monsters", [])
	for m in raw_mons:
		if m is Dictionary:
			var tid: int = int(m.get("t", -1))
			# Bỏ qua cọc gỗ / bao cát / mộc nhân
			if tid in [413, 414, 415]:
				continue
			if not MonsterData.monster(tid).is_empty():
				_monster_types.append(m.duplicate())

	# Nếu map có ít hơn 3 loại quái, mượn thêm quái cùng mốc cấp tier từ MapCatalog
	if _monster_types.size() < 3:
		var tier_maps := MapCatalog.in_tier(_tier)
		for tm in tier_maps:
			for tm_mon in tm.get("monsters", []):
				var t_id: int = int(tm_mon.get("t", -1))
				if t_id in [413, 414, 415]:
					continue
				var exists := false
				for existing in _monster_types:
					if int(existing.get("t", -1)) == t_id:
						exists = true
						break
				if not exists and not MonsterData.monster(t_id).is_empty():
					_monster_types.append(tm_mon.duplicate())
					if _monster_types.size() >= 3:
						break
			if _monster_types.size() >= 3:
				break

	# Fallback an toàn nếu vẫn trống
	if _monster_types.is_empty():
		_monster_types.append({"t": 31, "name": "Kim Miêu", "level": _tier * 10})
		_monster_types.append({"t": 42, "name": "Hươu đốm", "level": _tier * 10})
		_monster_types.append({"t": 43, "name": "Heo trắng", "level": _tier * 10})

func _sweep_initial_map_monsters() -> void:
	var w := VltkWorld.current
	if w != null and w.has_method("clear_all_monsters"):
		w.clear_all_monsters()

	var tree := get_tree()
	if tree == null:
		return
	for m in tree.get_nodes_in_group("monster"):
		if is_instance_valid(m) and not (m in _alive_monsters) and m != current_boss:
			m.queue_free()
	for e in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not (e in _alive_monsters) and e != current_boss:
			e.queue_free()

func _start_wave(wave_num: int) -> void:
	_wave_started = true
	current_wave = wave_num
	wave_monsters_spawned = 0
	wave_monsters_killed = 0
	boss_active = false
	current_boss = null
	_is_transitioning = false
	_wave_time = 0.0
	_spawn_timer = 0.0

	var type_info := _get_wave_monster_type(wave_num)
	var mname := str(type_info.get("name", "Quái"))
	var total_target: int = int(WAVE_TARGETS.get(wave_num, 100))

	_show_banner("⚔️ ĐỢT %d BẮT ĐẦU: %d [%s] XUẤT HIỆN!" % [wave_num, total_target, mname], Color(1.0, 0.85, 0.25))

	# Khởi đầu đợt: xuất hiện đợt lính đầu tiên
	_spawn_wave_batch()

func _spawn_wave_batch() -> void:
	var target_count: int = WAVE_TARGETS.get(current_wave, 300)
	var max_active: int = MAX_ACTIVE_CREEPS.get(current_wave, 40)
	var per_wave: int = CREEPS_PER_WAVE.get(current_wave, 10)

	# Dọn dẹp quái đã chết hoặc không còn hợp lệ khỏi _alive_monsters
	var valid_alive: Array[VltkMonster] = []
	for al in _alive_monsters:
		if is_instance_valid(al) and not (al.has_method("is_dead") and al.is_dead()) and al._state != VltkMonster.State.DEAD:
			valid_alive.append(al)
	_alive_monsters = valid_alive

	var remaining := target_count - wave_monsters_spawned
	if remaining <= 0:
		return
	var available := max_active - _alive_monsters.size()
	if available <= 0:
		return
	var count := mini(per_wave, mini(remaining, available))
	for i in count:
		_spawn_creep()

func _get_wave_monster_type(wave_num: int) -> Dictionary:
	if _monster_types.is_empty():
		return {}
	var idx := (wave_num - 1) % _monster_types.size()
	return _monster_types[idx]

## Lấy thứ tự map trong nhóm cấp tier (1x, 2x, 3x...): 1-based (map 1 = 1, map 2 = 2...)
func _get_map_index_in_tier() -> int:
	var mid := int(_map_entry.get("id", -1))
	if mid <= 0:
		return 1
	var tier_maps := MapCatalog.in_tier(_tier)
	for i in range(tier_maps.size()):
		if int(tier_maps[i].get("id", -1)) == mid:
			return i + 1
	return 1

## Hệ số máu theo thứ tự map trong nhóm cấp: map 1 x1, map 2 x2, map 3 x3...
func _get_tier_map_hp_mult() -> float:
	var idx := _get_map_index_in_tier()
	return float(maxi(1, idx))

## Hệ số sát thương theo thứ tự map trong nhóm cấp: map 1 x1, map 2 x1.5, map 3 x2...
func _get_tier_map_damage_mult() -> float:
	var idx := _get_map_index_in_tier()
	return 1.0 + float(maxi(1, idx) - 1) * 0.5

func _entity_parent() -> Node:
	var p := VltkWorld.entity_parent()
	return p if p != null else (get_parent() if get_parent() != null else self)

func _spawn_creep() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var mon_info := _get_wave_monster_type(current_wave)
	var mid: int = int(mon_info.get("t", -1))
	var mlvl: int = int(mon_info.get("level", _tier * 10))
	var mname: String = str(mon_info.get("name", "Quái"))

	var base_data := MonsterData.monster(mid)
	var parent := _entity_parent()
	if base_data.is_empty() or parent == null:
		return

	var m := VltkMonster.new()
	m.monster_id = mid
	m.data = base_data.duplicate()
	m.data["name"] = mname
	# Đảm bảo xuất hiện đầy đủ cả 5 hệ ngũ hành: Kim (0), Mộc (1), Thủy (2), Hỏa (3), Thổ (4)
	m.data["series"] = wave_monsters_spawned % 5
	m.data["ai_mode"] = 1
	m.level = mlvl
	m.is_survivor_monster = true
	m.target = _player
	m.ai_enabled = true

	var spawn_pos := _get_spawn_position(950.0, 1050.0)
	m.position = spawn_pos

	var base_hp := MonsterData.stat_at_level(m.data, "life", mlvl)
	if base_hp <= 0:
		base_hp = int(25 + mlvl * 8)
	var wave_mult: float = float(WAVE_HP_MULTIPLIERS.get(current_wave, 1.0))
	var map_hp_mult := _get_tier_map_hp_mult()
	# Giảm máu tất cả các quái xuống còn 1/3 so với trước
	var final_hp := maxf(1.0, (float(base_hp) * wave_mult * map_hp_mult) / 3.0)
	m.hp_override = int(final_hp)
	m.max_health = final_hp
	m.health = final_hp
	m.damage_multiplier = _get_tier_map_damage_mult()

	m.died.connect(func(_mon = null): _on_creep_died(m))
	m.tree_exiting.connect(func(): _alive_monsters.erase(m))
	parent.add_child(m)
	_current_wave_creep_hp = m.max_health
	_alive_monsters.append(m)
	wave_monsters_spawned += 1

func _spawn_boss() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	boss_active = true
	var mon_info := _get_wave_monster_type(current_wave)
	var mid: int = int(mon_info.get("t", -1))
	var mlvl: int = int(mon_info.get("level", _tier * 10))
	var mname: String = str(mon_info.get("name", "Quái"))

	var base_data := MonsterData.monster(mid)
	var parent := _entity_parent()
	if base_data.is_empty() or parent == null:
		return

	var boss := VltkMonster.new()
	boss.monster_id = mid
	boss.data = base_data.duplicate()
	boss.data["name"] = "👑 [THỦ QUAN ĐỢT %d] %s" % [current_wave, mname]
	boss.data["series"] = (current_wave - 1) % 5
	boss.data["ai_mode"] = 1
	boss.level = mlvl
	boss.is_survivor_boss = true
	boss.is_survivor_monster = true
	boss.gold_boss = true
	boss.target = _player
	boss.ai_enabled = true

	# YÊU CẦU ĐẶC TẢ: KÍCH THƯỚC GIẢM XUỐNG 1/2 (5.0 lần)
	boss.scale_factor = 5.0

	# YÊU CẦU ĐẶC TẢ: MÁU NHIỀU GẤP 30 LẦN QUÁI TRƯỚC ĐÓ
	var boss_hp := _current_wave_creep_hp * 30.0
	boss.hp_override = int(boss_hp)

	var spawn_pos := _get_spawn_position(550.0, 750.0)
	boss.position = spawn_pos

	boss.died.connect(func(_b = null): _on_boss_died(boss))
	parent.add_child(boss)
	boss.max_health = boss_hp
	boss.health = boss_hp
	boss.damage_multiplier = _get_tier_map_damage_mult()
	current_boss = boss

	_show_banner("⚠️ THỦ QUAN ĐỢT %d XUẤT HIỆN! MÁU x30 - KÍCH THƯỚC x5!" % current_wave, Color(1.0, 0.25, 0.2))

func _on_creep_died(m: VltkMonster = null, _extra = null) -> void:
	if m != null:
		_alive_monsters.erase(m)
	wave_monsters_killed += 1

	var target_count: int = WAVE_TARGETS.get(current_wave, 300)
	if wave_monsters_killed >= target_count and not boss_active and not _is_transitioning:
		# Dọn dẹp các quái thường còn sót nếu có để tập trung đánh Boss
		for rem in _alive_monsters:
			if is_instance_valid(rem):
				rem.queue_free()
		_alive_monsters.clear()
		_spawn_boss()

func _on_boss_died(boss: VltkMonster = null, _extra = null) -> void:
	boss_active = false
	current_boss = null
	_is_transitioning = true

	if current_wave == 1:
		_show_banner("🎉 ĐÃ HẠ THỦ QUAN ĐỢT 1! CHUẨN BỊ ĐỢT 2 (600 QUÁI)...", Color(0.3, 1.0, 0.5))
		await get_tree().create_timer(2.5).timeout
		_start_wave(2)
	elif current_wave == 2:
		_show_banner("🎉 ĐÃ HẠ THỦ QUAN ĐỢT 2! CHUẨN BỊ ĐỢT 3 (1000 QUÁI)...", Color(0.3, 1.0, 0.5))
		await get_tree().create_timer(2.5).timeout
		_start_wave(3)
	elif current_wave == 3:
		_show_banner("🏆 HOÀN THÀNH TOÀN BỘ 3 ĐỢT VƯỢT ẢI THÀNH CÔNG!", Color(1.0, 0.9, 0.2))
		await get_tree().create_timer(1.5).timeout
		_on_stage_completed()

func _on_stage_completed() -> void:
	_stage_cleared = true

	# Đánh giá hoàn thành 3 sao theo GDD:
	# - Thời gian <= 900s (15 phút)
	# - Điểm số >= 2500
	# - Tiêu diệt đủ quái (>= 350 con)
	var time_ok := elapsed_time <= 900.0
	var score_ok := PlayerStats.current_score >= 2500
	var kills_ok := PlayerStats.enemies_killed >= 350
	var total_stars := 1
	if time_ok and score_ok and kills_ok:
		total_stars = 3
	elif (time_ok and score_ok) or (score_ok and kills_ok) or (time_ok and kills_ok):
		total_stars = 2

	var stars_info: Dictionary = {
		"total_stars": total_stars,
		"time_passed": time_ok,
		"score_passed": score_ok,
		"kills_passed": kills_ok,
		"elapsed_time": elapsed_time,
		"score": PlayerStats.current_score,
		"kills": PlayerStats.enemies_killed
	}

	# Lưu dữ liệu vào Profile
	var profile: PlayerProfile = GameManager.local_profile
	if profile == null:
		profile = SaveManager.load_profile()
		GameManager.local_profile = profile

	var stage_idx := _tier - 1
	if profile != null:
		if profile.stages_cleared <= stage_idx:
			profile.stages_cleared = stage_idx + 1
		profile.set_stage_stars(stage_idx, total_stars)
		SaveManager.save_profile(profile)
		SaveManager.flush_online()

	var is_offline_luyen: bool = GameModeManager.is_offline() or GameManager.field_map.get("survivor_mode", false)
	var mult: int = 10 if is_offline_luyen else 1
	var rewards: Dictionary = {
		"stage_name": str(_map_entry.get("name", "Vượt Ải Luyện Công")),
		"tier": _tier,
		"stars_info": stars_info,
		"gold": 5000 * _tier * mult,
		"exp": 10000 * _tier * mult
	}

	StageVictoryPopup.show_reward(self, rewards)
	Engine.time_scale = 1.0
	if is_paused:
		_toggle_pause(false)
	if _pause_btn != null:
		_pause_btn.disabled = true
	if _speed_btn != null:
		_speed_btn.disabled = true

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if get_tree() != null:
		get_tree().paused = false
	is_paused = false

func _get_spawn_position(min_dist: float = 650.0, max_dist: float = 850.0) -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var ppos := _player.global_position
	var angle := randf() * TAU
	var dist := randf_range(min_dist, max_dist)
	var target_pt := ppos + Vector2(cos(angle), sin(angle)) * dist

	var w := VltkWorld.current
	if w != null:
		if w.arena_rect.has_area():
			target_pt = VltkWorld.clamp_to_arena(target_pt)
		if w.map != null:
			var open_pt := w._open_position_near(target_pt)
			if open_pt != Vector2.ZERO and not w.map.is_blocked(open_pt):
				return open_pt
			# Nếu vị trí xa bị kẹt núi đá, tìm vị trí thoáng gần player hơn
			var fallback_pt := w._open_position_near(ppos + (target_pt - ppos).normalized() * 450.0)
			if fallback_pt != Vector2.ZERO and not w.map.is_blocked(fallback_pt):
				return fallback_pt
	return target_pt

# ---------------------------------------------------------------- HUD & GIAO DIỆN
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 20
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud)

	var root_box := VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	root_box.position = Vector2(-220, 24)
	root_box.custom_minimum_size = Vector2(440, 0)
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root_box)

	var map_name := str(_map_entry.get("name", "Vượt Ải"))
	_title_lbl = _create_label("⚔️ VƯỢT ẢI LUYỆN CÔNG: %s (%dx)" % [map_name, _tier], 18, Color(1.0, 0.85, 0.35))

	# Hàng đơn kết hợp: ĐỢT X / 3 • Tiêu diệt: Y / Z quái
	var wave_info_row := HBoxContainer.new()
	wave_info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_info_row.add_theme_constant_override("separation", 10)

	_wave_lbl = _create_label("ĐỢT 1 / 3", 18, Color(1.0, 0.45, 0.35))
	var dot_lbl := _create_label("•", 16, Color(0.7, 0.75, 0.8))
	_progress_lbl = _create_label("Tiêu diệt: 0 / 300 quái", 16, Color(1.0, 1.0, 1.0))
	wave_info_row.add_child(_wave_lbl)
	wave_info_row.add_child(dot_lbl)
	wave_info_row.add_child(_progress_lbl)

	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 24)
	_clock_lbl = _create_label("⏱ 00:00", 14, Color(0.8, 0.9, 1.0))
	_score_lbl = _create_label("⭐ Điểm: 0 | Hạ: 0", 14, Color(0.9, 1.0, 0.6))
	sub_row.add_child(_clock_lbl)
	sub_row.add_child(_score_lbl)

	root_box.add_child(_title_lbl)
	root_box.add_child(wave_info_row)
	root_box.add_child(sub_row)

	# Bảng điều khiển Tốc Độ & Tạm Dừng ở góc dưới-phải (ngay trên nút chữ nhật Võ Công Đã Chọn)
	var br_panel := PanelContainer.new()
	br_panel.name = "SurvivorSpeedPausePanel"
	br_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_panel.offset_left = -140.0
	br_panel.offset_top = -186.0
	br_panel.offset_right = -14.0
	br_panel.offset_bottom = -154.0
	var br_sb := StyleBoxEmpty.new()
	br_panel.add_theme_stylebox_override("panel", br_sb)
	_hud.add_child(br_panel)

	var br_box := HBoxContainer.new()
	br_box.alignment = BoxContainer.ALIGNMENT_CENTER
	br_box.add_theme_constant_override("separation", 6)
	br_panel.add_child(br_box)

	# Nút Tốc Độ Trận Đấu (1x -> 2x -> 4x)
	_speed_btn = Button.new()
	_speed_btn.custom_minimum_size = Vector2(60, 32)
	_update_speed_button()
	_speed_btn.pressed.connect(_toggle_speed)
	var speed_sc := Shortcut.new()
	var ev_t := InputEventKey.new()
	ev_t.keycode = KEY_T
	speed_sc.events = [ev_t]
	_speed_btn.shortcut = speed_sc
	br_box.add_child(_speed_btn)

	# Nút Tạm Dừng / Tiếp Tục
	_pause_btn = Button.new()
	_pause_btn.text = "⏸ Dừng"
	_pause_btn.custom_minimum_size = Vector2(60, 32)
	_pause_btn.tooltip_text = "Tạm dừng trận đấu (Phím Space / P)"
	var pause_sb := StyleBoxFlat.new()
	pause_sb.bg_color = Color(0.18, 0.25, 0.35, 0.95)
	pause_sb.border_width_left = 1
	pause_sb.border_width_top = 1
	pause_sb.border_width_right = 1
	pause_sb.border_width_bottom = 1
	pause_sb.border_color = Color(0.4, 0.65, 0.9)
	pause_sb.corner_radius_top_left = 4
	pause_sb.corner_radius_top_right = 4
	pause_sb.corner_radius_bottom_left = 4
	pause_sb.corner_radius_bottom_right = 4
	_pause_btn.add_theme_stylebox_override("normal", pause_sb)
	_pause_btn.add_theme_font_size_override("font_size", 12)
	_pause_btn.pressed.connect(_on_pause_toggle_pressed)
	var sc := Shortcut.new()
	var ev_space := InputEventKey.new()
	ev_space.keycode = KEY_SPACE
	var ev_p := InputEventKey.new()
	ev_p.keycode = KEY_P
	sc.events = [ev_space, ev_p]
	_pause_btn.shortcut = sc
	br_box.add_child(_pause_btn)

	_build_pause_overlay()

	# Banner thông báo lớn ở giữa màn hình
	_banner_lbl = Label.new()
	_banner_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner_lbl.position = Vector2(-400, -60)
	_banner_lbl.custom_minimum_size = Vector2(800, 60)
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_lbl.add_theme_font_size_override("font_size", 28)
	_banner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_lbl.modulate.a = 0.0
	_hud.add_child(_banner_lbl)

func _create_label(txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _show_banner(txt: String, col: Color) -> void:
	if _banner_lbl == null:
		return
	_banner_lbl.text = txt
	_banner_lbl.add_theme_color_override("font_color", col)
	_banner_lbl.modulate.a = 1.0
	_banner_timer = 3.0

func _update_hud_display() -> void:
	if _hud == null:
		return

	# Cập nhật thời gian
	@warning_ignore("integer_division")
	var mins := int(elapsed_time) / 60
	var secs := int(elapsed_time) % 60
	_clock_lbl.text = "⏱ %02d:%02d" % [mins, secs]
	_score_lbl.text = "⭐ Điểm: %d | Hạ: %d" % [PlayerStats.current_score, PlayerStats.enemies_killed]

	var target_count: int = WAVE_TARGETS.get(current_wave, 300)
	if boss_active and current_boss != null and is_instance_valid(current_boss):
		_wave_lbl.text = "⚠️ QUYẾT CHIẾN THỦ QUAN ĐỢT %d!" % current_wave
		_wave_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		_progress_lbl.text = "Máu Thủ Quan: %d / %d" % [int(current_boss.health), int(current_boss.max_health)]
		_progress_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		_wave_lbl.text = "ĐỢT %d / 3" % current_wave
		_wave_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		_progress_lbl.text = "Tiêu diệt: %d / %d quái" % [wave_monsters_killed, target_count]
		_progress_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func _build_pause_overlay() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.add_child(_pause_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 240)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.08, 0.98)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.68, 0.3)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "⏸ TRẬN ĐẤU ĐANG TẠM DỪNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	vb.add_child(title)

	var sub_lbl := Label.new()
	sub_lbl.text = "Toàn bộ chiến trường luyện công đã được đóng băng.\nĐại hiệp có thể tiếp tục hoặc rời ải."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	vb.add_child(sub_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vb.add_child(btn_row)

	var resume_btn := Button.new()
	resume_btn.name = "ResumeButton"
	resume_btn.text = "▶ Tiếp Tục"
	resume_btn.custom_minimum_size = Vector2(130, 42)
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color(0.2, 0.58, 0.28)
	r_sb.border_width_left = 1
	r_sb.border_width_top = 1
	r_sb.border_width_right = 1
	r_sb.border_width_bottom = 1
	r_sb.border_color = Color(0.4, 0.85, 0.45)
	r_sb.corner_radius_top_left = 6
	r_sb.corner_radius_top_right = 6
	r_sb.corner_radius_bottom_left = 6
	r_sb.corner_radius_bottom_right = 6
	resume_btn.add_theme_stylebox_override("normal", r_sb)
	resume_btn.add_theme_font_size_override("font_size", 15)
	resume_btn.pressed.connect(func() -> void: _toggle_pause(false))

	var resume_shortcut := Shortcut.new()
	var esc_ev := InputEventKey.new()
	esc_ev.keycode = KEY_ESCAPE
	var space_ev := InputEventKey.new()
	space_ev.keycode = KEY_SPACE
	resume_shortcut.events = [esc_ev, space_ev]
	resume_btn.shortcut = resume_shortcut
	btn_row.add_child(resume_btn)

	var quit_btn := Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "⬅ Rời Ải"
	quit_btn.custom_minimum_size = Vector2(130, 42)
	var q_sb := StyleBoxFlat.new()
	q_sb.bg_color = Color(0.5, 0.2, 0.2)
	q_sb.border_width_left = 1
	q_sb.border_width_top = 1
	q_sb.border_width_right = 1
	q_sb.border_width_bottom = 1
	q_sb.border_color = Color(0.8, 0.35, 0.35)
	q_sb.corner_radius_top_left = 6
	q_sb.corner_radius_top_right = 6
	q_sb.corner_radius_bottom_left = 6
	q_sb.corner_radius_bottom_right = 6
	quit_btn.add_theme_stylebox_override("normal", q_sb)
	quit_btn.add_theme_font_size_override("font_size", 15)
	quit_btn.pressed.connect(_on_exit_pressed)
	btn_row.add_child(quit_btn)

func _on_pause_toggle_pressed() -> void:
	_toggle_pause(not is_paused)

func _toggle_pause(p_paused: bool) -> void:
	if _stage_cleared or GameManager.is_game_over:
		return
	is_paused = p_paused
	if get_tree() != null:
		get_tree().paused = is_paused

	if VltkWorld.current != null:
		VltkWorld.current.process_mode = Node.PROCESS_MODE_PAUSABLE if is_paused else Node.PROCESS_MODE_INHERIT

	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_PAUSABLE if is_paused else Node.PROCESS_MODE_INHERIT

	if _pause_btn != null:
		if is_paused:
			_pause_btn.text = "▶ Tiếp Tục"
			_pause_btn.modulate = Color(1.3, 1.3, 0.4)
		else:
			_pause_btn.text = "⏸ Dừng"
			_pause_btn.modulate = Color.WHITE

	if _pause_overlay != null:
		_pause_overlay.visible = is_paused
		if is_paused:
			var res_btn = _pause_overlay.find_child("ResumeButton", true, false) as Button
			if res_btn != null:
				res_btn.grab_focus()

func _toggle_speed() -> void:
	current_speed_idx = (current_speed_idx + 1) % SPEED_STEPS.size()
	var mult: float = SPEED_STEPS[current_speed_idx]
	Engine.time_scale = mult
	_update_speed_button()
	_show_banner("⚡ TỐC ĐỘ TRẬN ĐẤU: %s (x%.1f)" % [SPEED_LABELS[current_speed_idx], mult], SPEED_COLORS[current_speed_idx])

func _update_speed_button() -> void:
	if _speed_btn == null:
		return
	_speed_btn.text = SPEED_LABELS[current_speed_idx]
	_speed_btn.tooltip_text = "Tốc độ trận đấu: %s (Bấm để tăng tốc 1x -> 2x -> 4x, Phím T)" % SPEED_LABELS[current_speed_idx]
	var sb := StyleBoxFlat.new()
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	if current_speed_idx == 0:
		sb.bg_color = Color(0.18, 0.22, 0.28, 0.95)
		sb.border_color = Color(0.4, 0.55, 0.7)
	elif current_speed_idx == 1:
		sb.bg_color = Color(0.12, 0.32, 0.22, 0.95)
		sb.border_color = Color(0.35, 0.9, 0.6)
	else:
		sb.bg_color = Color(0.38, 0.2, 0.08, 0.95)
		sb.border_color = Color(1.0, 0.75, 0.25)
	_speed_btn.add_theme_stylebox_override("normal", sb)
	_speed_btn.add_theme_color_override("font_color", SPEED_COLORS[current_speed_idx])
	_speed_btn.add_theme_font_size_override("font_size", 12)

func _on_exit_pressed() -> void:
	Engine.time_scale = 1.0
	if get_tree() != null:
		get_tree().paused = false
	is_paused = false
	if has_node("/root/SceneTransition"):
		get_node("/root/SceneTransition").change_scene("res://ui/character_hub/CharacterHub.tscn", "Sảnh Chính")
	else:
		get_tree().change_scene_to_file("res://ui/character_hub/CharacterHub.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_pause_toggle_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_V:
			SelectedSkillsWindow.toggle_window(self)
			get_viewport().set_input_as_handled()
			return
