extends Node
class_name HonorDefenseChallenge

## HỆ THỐNG ĐIỀU KHIỂN "BẢO VỆ TRỤ DANH DỰ" (HONOR PILLAR DEFENSE)
## Quản lý toàn bộ vòng lặp 200 đợt quái, 4 cổng sinh quái, kỹ năng buff môn phái,
## Trụ Danh Dự, Boss Đồng Minh, thanh tiến trình HUD và trao thưởng khi hoàn thành.

signal finished(success: bool, waves_cleared: int)

const DATA_PATH := "res://data/battle/honor_defense_waves.json"
const MAP_DIR := "res://world/maps/map_1001"
const WAVE_INTERVAL := 20.0
const CENTER_POS := Vector2(50777, 50366)  ## Tâm bục giữa hoa văn rồng đá map 1001 toạ độ VLTK (198/196)

# 4 cổng xuất phát thả quái (Bắc, Nam, Tây, Đông) dẫn vào Long Trụ
const GATE_OFFSETS := [
	Vector2(183, -1606), # Cổng Bắc (199/190)
	Vector2(183, 1626),  # Cổng Nam (199/203)
	Vector2(-1353, 58),  # Cổng Tây (193/197)
	Vector2(1207, 74)    # Cổng Đông (203/197)
]

var waves_data: Array = []
var current_wave: int = 1
var total_waves: int = 200
var wave_timer: float = WAVE_INTERVAL
var defense_points: int = 200   ## Điểm khởi đầu tặng người chơi mua thủ hạ
var is_active: bool = false
var is_game_over: bool = false

var _pillar: HonorPillar = null
var _hud: HonorDefenseTrackerHud = null
var _shop_win: HonorDefenseShopWindow = null
var _alive_monsters: Array[VltkMonster] = []
var _allies: Array[AllyDefenseBoss] = []
var _player: Node2D = null

static func map_entry() -> Dictionary:
	return {
		"id": 1001,
		"name": "Bảo Vệ Trụ Danh Dự (Lâm An)",
		"dir": MAP_DIR,
		"level": 100,
		"honor_defense": true,
		"arena_center": CENTER_POS
	}

func _ready() -> void:
	_load_waves_data()
	call_deferred("_setup_arena")

func _load_waves_data() -> void:
	if FileAccess.file_exists(DATA_PATH):
		var text := FileAccess.get_file_as_string(DATA_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and parsed.has("waves"):
			waves_data = parsed["waves"]
			total_waves = waves_data.size()

func _setup_arena() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_player.global_position = CENTER_POS + Vector2(0, 100)

	# 1. Sinh Trụ Danh Dự tại tâm bục
	_pillar = HonorPillar.new()
	_pillar.name = "HonorPillar"
	_pillar.global_position = CENTER_POS
	_pillar.destroyed.connect(_on_pillar_destroyed)
	var parent := VltkWorld.entity_parent()
	if parent != null:
		parent.add_child(_pillar)
	else:
		add_child(_pillar)

	# 2. Dựng Tracker HUD trên đỉnh màn hình
	_hud = HonorDefenseTrackerHud.new()
	_hud.setup(waves_data)
	_hud.open_shop_requested.connect(_open_shop)
	_hud.speed_changed.connect(_on_speed_changed)
	add_child(_hud)

	is_active = true
	_start_wave(1)

func _process(delta: float) -> void:
	if not is_active or is_game_over:
		return

	wave_timer -= delta
	if _pillar != null and is_instance_valid(_pillar):
		_hud.update_status(current_wave, wave_timer, _pillar.health, _pillar.max_health, defense_points)

	# Cứ 20s sẽ ra 1 đợt mới
	if wave_timer <= 0.0:
		_on_wave_timer_expired()

func _on_wave_timer_expired() -> void:
	# Thưởng điểm thủ trụ cho đợt vừa qua
	defense_points += 150 + int(current_wave * 5)
	if _shop_win != null and is_instance_valid(_shop_win):
		_shop_win.set_points(defense_points)

	if current_wave < total_waves:
		current_wave += 1
		wave_timer = WAVE_INTERVAL
		_start_wave(current_wave)
	else:
		# Hoàn thành trọn vẹn 200 đợt!
		_finish_game(true)

func _start_wave(w_num: int) -> void:
	if w_num - 1 >= waves_data.size():
		return

	var w_info: Dictionary = waves_data[w_num - 1]
	var m_id: int = int(w_info.get("monster_id", 11))
	var m_lvl: int = int(w_info.get("level", w_num))
	var element: int = int(w_info.get("element", 0))
	var buff_info: Dictionary = w_info.get("buff", {})
	var is_boss: bool = w_info.get("is_boss_wave", false)

	# Sinh 20 quái chia đều cho 4 cổng (mỗi cổng 5 quái)
	var monsters_per_gate := 5
	for gate_idx in GATE_OFFSETS.size():
		var gate_pos: Vector2 = CENTER_POS + GATE_OFFSETS[gate_idx]
		for i in range(monsters_per_gate):
			var spawn_pos := gate_pos + Vector2(randf_range(-120, 120), randf_range(-120, 120))
			_spawn_creep(m_id, m_lvl, element, spawn_pos, buff_info)

	# Nếu là đợt Boss: sinh thêm 1 Boss (máu boss giảm 1/2 từ x15 xuống x7.5) tại cổng ngẫu nhiên
	if is_boss:
		var b_data: Dictionary = w_info.get("boss", {})
		var boss_id: int = int(b_data.get("monster_id", 1006))
		var boss_name: String = str(b_data.get("name", "Đại Boss"))
		var hp_mult: float = float(b_data.get("hp_multiplier", 7.5))
		var gate_pos_boss: Vector2 = CENTER_POS + GATE_OFFSETS[randi() % GATE_OFFSETS.size()]
		_spawn_boss(boss_id, m_lvl, element, gate_pos_boss, boss_name, buff_info, hp_mult)

	if _hud != null:
		_hud.update_status(current_wave, wave_timer, _pillar.health, _pillar.max_health, defense_points)
		_hud._update_tracker()

func _spawn_creep(m_id: int, lvl: int, element: int, spawn_pos: Vector2, buff_info: Dictionary) -> void:
	var base_data := MonsterData.monster(m_id)
	var parent := VltkWorld.entity_parent()
	if base_data.is_empty() or parent == null:
		return

	var m := VltkMonster.new()
	m.monster_id = m_id
	m.data = base_data.duplicate()
	m.data["series"] = element
	m.level = lvl
	m.position = spawn_pos
	m.is_honor_defense_creep = true
	m.target = _pillar   ## Quái di chuyển vào đánh Trụ, không đánh người chơi
	m.died.connect(_on_monster_died)
	parent.add_child(m)
	_alive_monsters.append(m)

	_apply_buff_to_monster(m, buff_info)

func _spawn_boss(boss_id: int, lvl: int, element: int, spawn_pos: Vector2, boss_name: String, buff_info: Dictionary, hp_multiplier: float = 7.5) -> void:
	var base_data := MonsterData.monster(boss_id)
	var parent := VltkWorld.entity_parent()
	if base_data.is_empty() or parent == null:
		return

	var m := VltkMonster.new()
	m.monster_id = boss_id
	m.data = base_data.duplicate()
	m.data["name"] = "👑 " + boss_name
	m.data["series"] = element
	m.level = lvl
	m.position = spawn_pos
	m.is_honor_defense_creep = true
	m.target = _pillar
	m.scale = Vector2(1.4, 1.4)
	m.died.connect(_on_monster_died)
	parent.add_child(m)

	# Máu Boss (giảm 1/2 từ x15 xuống x7.5)
	var base_hp := MonsterData.stat_at_level(m.data, "life", lvl)
	m.max_health = float(base_hp) * hp_multiplier
	m.health = m.max_health
	if m._health_bar != null and m._health_bar.has_method("set_max_health"):
		m._health_bar.set_max_health(m.max_health)
		m._health_bar.set_health(m.health)

	_alive_monsters.append(m)
	_apply_buff_to_monster(m, buff_info)

func _apply_buff_to_monster(m: VltkMonster, buff_info: Dictionary) -> void:
	var b_type := str(buff_info.get("type", ""))
	var b_val := float(buff_info.get("value", 0))

	# Áp dụng hiệu ứng buff
	match b_type:
		"speed", "speed_dodge", "super_speed":
			if m.status_controller != null:
				m.status_controller.apply_speed_buff(b_val / 100.0, 999.0)
		"max_hp":
			m.max_health *= (1.0 + b_val / 100.0)
			m.health = m.max_health
		"dmg_reduce":
			if m.combat_stats != null:
				m.combat_stats.defense += int(b_val * 10)
		"heal_aura":
			# Quái tự hồi phục
			var t := Timer.new()
			t.wait_time = 3.0
			t.timeout.connect(func() -> void:
				if is_instance_valid(m) and not m.is_dead():
					m.heal(m.max_health * 0.05)
			)
			m.add_child(t)
			t.start()
		"aura_poison":
			# Nhuộm màu tím biểu thị khí độc
			m.modulate = Color(0.8, 0.4, 1.0)
		"freeze_attacker":
			# Nhuộm màu xanh băng tuyết
			m.modulate = Color(0.4, 0.8, 1.0)

func _on_monster_died(m: VltkMonster) -> void:
	_alive_monsters.erase(m)

func _open_shop() -> void:
	if _shop_win != null and is_instance_valid(_shop_win):
		return
	_shop_win = HonorDefenseShopWindow.new()
	_shop_win.set_points(defense_points)
	_shop_win.boss_purchased.connect(_on_boss_purchased)
	add_child(_shop_win)

func _on_boss_purchased(boss_id: String, cost: int) -> void:
	defense_points -= cost
	if _hud != null:
		_hud.update_status(current_wave, wave_timer, _pillar.health, _pillar.max_health, defense_points)

	# Sinh Boss Đồng Minh bảo vệ Trụ
	var ally := AllyDefenseBoss.new()
	var spawn_pos: Vector2 = CENTER_POS + Vector2(randf_range(-140, 140), randf_range(-140, 140))
	ally.global_position = spawn_pos
	
	var ally_names := {
		"tanker": "Thiên Vương Thiết Kỵ",
		"healer": "Nga Mi Thánh Nữ",
		"trapper": "Đường Môn Cơ Quan Sư",
		"sword": "Võ Đang Kiếm Thánh",
		"beast": "Thiên Sơn Thần Thú"
	}
	# HP của boss đồng minh giảm 20 lần theo tương quan bể máu trụ mới (50.000 HP)
	var ally_hps := {
		"tanker": 50000.0,
		"healer": 20000.0,
		"trapper": 25000.0,
		"sword": 35000.0,
		"beast": 75000.0
	}
	ally.setup(boss_id, ally_names.get(boss_id, "Hộ Vệ"), current_wave + 20, ally_hps.get(boss_id, 25000.0), _pillar)
	
	var parent := VltkWorld.entity_parent()
	if parent != null:
		parent.add_child(ally)
	else:
		add_child(ally)
	_allies.append(ally)

func _on_pillar_destroyed() -> void:
	if is_game_over:
		return
	_finish_game(false)

func _on_speed_changed(mult: float) -> void:
	Engine.time_scale = mult

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _finish_game(success: bool) -> void:
	Engine.time_scale = 1.0
	is_game_over = true
	is_active = false

	# Tính toán phần thưởng
	var waves_cleared := current_wave if success else maxi(0, current_wave - 1)
	var exp_gained := waves_cleared * 25000
	var gold_gained := waves_cleared * 35000

	var profile: PlayerProfile = GameManager.current_profile if "current_profile" in GameManager else null
	if profile != null:
		if profile.has_method("gain_exp"):
			profile.gain_exp(exp_gained)
		profile.gold += gold_gained

		# Quà tặng mốc đặc biệt
		if waves_cleared >= 30:
			_award_misc_item(profile, "6_1_400", 1)  # Sát thủ giản
		if waves_cleared >= 60:
			_award_misc_item(profile, "4_489_1", 1)  # Lệnh bài Phong Lăng Độ
		if waves_cleared >= 100:
			_award_misc_item(profile, "6_1_400", 2)
			_award_misc_item(profile, "4_489_1", 2)
			_award_misc_item(profile, "6_1_2416", 1) # Lâm An Huyết Chiến Lệnh

		SaveManager.save_profile(profile)

	# Hiển thị thông báo kết thúc
	_show_victory_popup(success, waves_cleared, exp_gained, gold_gained)
	finished.emit(success, waves_cleared)

static func _bold_font() -> Font:
	return GameUi.game_font_bold()

func _award_misc_item(profile: PlayerProfile, misc_id: String, count: int = 1) -> void:
	if profile == null:
		return
	for i in range(count):
		var it: ItemInstance = ItemGenerator.generate_misc(misc_id)
		if it != null:
			profile.add_item(it)

func _show_victory_popup(success: bool, cleared: int, exp_pts: int, gold_pts: int) -> void:
	var popup := CanvasLayer.new()
	popup.layer = 150
	add_child(popup)

	# Lớp nền tối mờ nhẹ nhìn xuyên chiến trường
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.35)
	popup.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(center)

	# Khung bảng kết quả bán trong suốt (60% nhìn xuyên chiến trường)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(480, 320)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.07, 0.12, 0.60)
	st.border_color = Color(1.0, 0.85, 0.3, 0.9) if success else Color(0.95, 0.3, 0.3, 0.9)
	st.border_width_left = 2
	st.border_width_right = 2
	st.border_width_top = 2
	st.border_width_bottom = 2
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 20
	st.content_margin_bottom = 20
	box.add_theme_stylebox_override("panel", st)
	center.add_child(box)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)

	var title := Label.new()
	title.text = "★ CHIẾN THẮNG HUY HOÀNG ★" if success else "☠ PHÒNG THỦ THẤT BẠI ☠"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _bold_font())
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if success else Color(1.0, 0.35, 0.35))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	v.add_child(title)

	var result_lbl := Label.new()
	result_lbl.text = "Số ải đã vượt qua: %d / %d đợt" % [cleared, total_waves]
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_override("font", _bold_font())
	result_lbl.add_theme_font_size_override("font_size", 16)
	result_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	result_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	result_lbl.add_theme_constant_override("outline_size", 3)
	v.add_child(result_lbl)

	var reward_lbl := Label.new()
	reward_lbl.text = "Phần Thưởng:\n+ %d Điểm Kinh Nghiệm (EXP)\n+ %d Lượng Vàng\n" % [exp_pts, gold_pts]
	if cleared >= 30:
		reward_lbl.text += "+ 1 Sát Thủ Giản\n"
	if cleared >= 60:
		reward_lbl.text += "+ 1 Lệnh Bài Phong Lăng Độ\n"
	if cleared >= 100:
		reward_lbl.text += "+ 1 Lâm An Huyết Chiến Lệnh\n"
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.add_theme_font_override("font", _bold_font())
	reward_lbl.add_theme_font_size_override("font_size", 14)
	reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	reward_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	reward_lbl.add_theme_constant_override("outline_size", 3)
	v.add_child(reward_lbl)

	var exit_btn := Button.new()
	exit_btn.text = "Rời Chiến Trường"
	exit_btn.custom_minimum_size = Vector2(180, 42)
	exit_btn.add_theme_font_override("font", _bold_font())
	exit_btn.add_theme_font_size_override("font_size", 14)
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var btn_st := StyleBoxFlat.new()
	btn_st.bg_color = Color(0.12, 0.16, 0.22, 0.85)
	btn_st.border_color = Color(0.85, 0.7, 0.3, 0.9) if success else Color(0.9, 0.35, 0.35, 0.9)
	btn_st.border_width_left = 1
	btn_st.border_width_right = 1
	btn_st.border_width_top = 1
	btn_st.border_width_bottom = 1
	btn_st.set_corner_radius_all(6)
	exit_btn.add_theme_stylebox_override("normal", btn_st)

	var btn_hov := btn_st.duplicate() as StyleBoxFlat
	btn_hov.bg_color = Color(0.2, 0.26, 0.35, 0.95)
	btn_hov.border_color = Color(1.0, 0.85, 0.45, 1.0)
	exit_btn.add_theme_stylebox_override("hover", btn_hov)

	var btn_press := btn_st.duplicate() as StyleBoxFlat
	btn_press.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	exit_btn.add_theme_stylebox_override("pressed", btn_press)

	exit_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5) if success else Color(1.0, 0.8, 0.8))
	exit_btn.pressed.connect(func() -> void:
		popup.queue_free()
		get_tree().change_scene_to_file("res://ui/character_hub/CharacterHub.tscn")
	)
	v.add_child(exit_btn)
