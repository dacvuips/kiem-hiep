extends Node
class_name ThienTamThapChallenge

## HỆ THỐNG ĐIỀU KHIỂN "THIÊN TẦM THÁP"
## Vượt ải liên hoàn từng đợt quái từ heo, nai, nhím, heo rừng... cho đến hết danh sách (hơn 740 ải).
## Quái thường: Máu x2, Dame giữ nguyên, Rớt đồ x3, EXP x2.
## Mỗi 10 ải xuất hiện 1 Đại Boss: Máu x10 quái tiếp theo, Dame bằng quái tiếp theo, Rớt đồ x5.
## Tối đa 3 lượt đi mỗi ngày. Cấp tham gia: 30 trở lên.
## Timeline lượt quái và thông tin ải hiện tại.

signal finished(success: bool, stages_cleared: int)

const DATA_PATH := "res://data/challenge/thien_tam_thap_waves.json"
const RECORDS_PATH := "user://thien_tam_thap_records.json"
const MAP_DIR := "res://world/maps/map_1038"
const MAP_ID := 1038
const MIN_LEVEL := 30
const RUNS_PER_DAY := 3
const WAVE_TIMEOUT := 60.0
const REST_INTERVAL := 2.5
const CENTER_POS := Vector2(51225.0, 51192.0)

const ThienTamThapTrackerHudScript = preload("res://ui/battle/thien_tam_thap_tracker_hud.gd")

var waves_data: Array = []
var current_wave: int = 1
var total_waves: int = 744
var stages_cleared: int = 0
var wave_timer: float = WAVE_TIMEOUT
var is_active: bool = false
var is_game_over: bool = false
var is_resting: bool = false
var rest_timer: float = 0.0

var _hud: CanvasLayer = null
var _alive_monsters: Array[VltkMonster] = []
var _player: Node2D = null

# ---------------------------------------------------------------- Dữ liệu lưu trữ kỷ lục & lượt đi
static func map_entry() -> Dictionary:
	return {
		"id": MAP_ID,
		"name": "Thiên Tầm Tháp",
		"dir": MAP_DIR,
		"level": MIN_LEVEL,
		"thien_tam_thap": true,
		"arena_center": CENTER_POS
	}

static func records() -> Dictionary:
	if not FileAccess.file_exists(RECORDS_PATH):
		return {}
	var text := FileAccess.get_file_as_string(RECORDS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

static func save_records(data: Dictionary) -> void:
	var f := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))

static func _save_profile(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var loop := Engine.get_main_loop() as SceneTree
	if loop and loop.root and loop.root.has_node("SaveManager"):
		var sm = loop.root.get_node("SaveManager")
		if sm != null and sm.has_method("save_profile"):
			sm.save_profile(profile)

static func _today() -> String:
	return Time.get_date_string_from_system()

static func _key(profile: PlayerProfile) -> String:
	return profile.display_name if profile and profile.display_name != "" else "local"

static func runs_today(profile: PlayerProfile) -> int:
	var r: Dictionary = records().get(_key(profile), {})
	return int(r.get("runs", {}).get(_today(), 0))

static func add_run(profile: PlayerProfile) -> void:
	var rec := records()
	var k := _key(profile)
	var p: Dictionary = rec.get_or_add(k, {})
	var runs: Dictionary = p.get_or_add("runs", {})
	runs[_today()] = int(runs.get(_today(), 0)) + 1
	save_records(rec)

static func best_stage(profile: PlayerProfile) -> int:
	var r: Dictionary = records().get(_key(profile), {})
	return int(r.get("best_stage", 0))

static func update_best_stage(profile: PlayerProfile, stage: int) -> void:
	var rec := records()
	var k := _key(profile)
	var p: Dictionary = rec.get_or_add(k, {})
	var cur: int = int(p.get("best_stage", 0))
	if stage > cur:
		p["best_stage"] = stage
	if profile != null:
		p["sect_id"] = profile.sect_id
		p["level"] = profile.level
	save_records(rec)

## Lấy danh sách bảng xếp hạng người chơi vượt ải Thiên Tầm Tháp nhiều nhất
static func get_leaderboard(profile: PlayerProfile = null) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var my_name := profile.display_name if profile and profile.display_name != "" else "Hiệp Khách"
	var my_sect := profile.sect_id if profile else ""
	var my_level := profile.level if profile else 30
	var my_stage := best_stage(profile)
	entries.append({
		"name": my_name,
		"sect_id": my_sect,
		"level": my_level,
		"best_stage": my_stage,
		"is_me": true
	})

	var recs := records()
	for p_name in recs:
		if str(p_name) == my_name:
			continue
		var p_data: Dictionary = recs[p_name] if recs[p_name] is Dictionary else {}
		var stage: int = int(p_data.get("best_stage", 0))
		if stage > 0:
			entries.append({
				"name": str(p_name),
				"sect_id": str(p_data.get("sect_id", "")),
				"level": int(p_data.get("level", 80)),
				"best_stage": stage,
				"is_me": false
			})

	# Danh sách cao thủ giang hồ mẫu khi máy chủ chưa có nhiều người chơi
	var default_masters: Array[Dictionary] = [
		{"name": "Độc Cô Cầu Bại", "sect_id": "hoa_son", "level": 120, "best_stage": 268},
		{"name": "Trương Tam Phong", "sect_id": "vo_dang", "level": 118, "best_stage": 252},
		{"name": "Vô Danh Thần Tăng", "sect_id": "thieu_lam", "level": 115, "best_stage": 240},
		{"name": "Tiêu Phong", "sect_id": "cai_bang", "level": 112, "best_stage": 215},
		{"name": "Phong Thanh Dương", "sect_id": "hoa_son", "level": 110, "best_stage": 204},
		{"name": "Dương Quá", "sect_id": "con_lon", "level": 108, "best_stage": 196},
		{"name": "Lệnh Hồ Xung", "sect_id": "hoa_son", "level": 105, "best_stage": 182},
		{"name": "Quách Tĩnh", "sect_id": "cai_bang", "level": 103, "best_stage": 165},
		{"name": "Đoàn Dự", "sect_id": "tieu_dao", "level": 100, "best_stage": 148},
		{"name": "Hư Trúc", "sect_id": "tieu_dao", "level": 98, "best_stage": 130},
		{"name": "Hoàng Dược Sư", "sect_id": "thuy_yen_mon", "level": 95, "best_stage": 115},
	]
	for dm in default_masters:
		var dm_name: String = str(dm["name"])
		if not entries.any(func(e: Dictionary) -> bool: return str(e["name"]) == dm_name):
			var item := dm.duplicate()
			item["is_me"] = false
			entries.append(item)

	# Sắp xếp giảm dần theo số Ải Vượt được nhiều nhất (nếu bằng thì xét theo cấp độ)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: int = int(a.get("best_stage", 0))
		var sb: int = int(b.get("best_stage", 0))
		if sa != sb:
			return sa > sb
		return int(a.get("level", 0)) > int(b.get("level", 0))
	)

	var result: Array[Dictionary] = []
	for idx in entries.size():
		var it: Dictionary = entries[idx].duplicate()
		it["rank"] = idx + 1
		result.append(it)
	return result

static func check_entry(profile: PlayerProfile) -> String:
	if profile == null:
		return "Chưa có thông tin nhân vật."
	if profile.level < MIN_LEVEL:
		return "Cần đạt đẳng cấp %d trở lên mới có thể khiêu chiến Thiên Tầm Tháp." % MIN_LEVEL
	if runs_today(profile) >= RUNS_PER_DAY:
		return "Hôm nay đại hiệp đã tham gia đủ %d/%d lượt Thiên Tầm Tháp. Hãy quay lại vào ngày mai!" % [RUNS_PER_DAY, RUNS_PER_DAY]
	return ""

# ---------------------------------------------------------------- Vòng lặp chính của Ải
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

static func _get_profile() -> PlayerProfile:
	var loop := Engine.get_main_loop() as SceneTree
	if loop and loop.root and loop.root.has_node("GameManager"):
		var gm = loop.root.get_node("GameManager")
		if gm != null:
			if "local_profile" in gm and gm.local_profile != null:
				return gm.local_profile
			if "current_profile" in gm and gm.current_profile != null:
				return gm.current_profile
	return null

func _setup_arena() -> void:
	var profile: PlayerProfile = _get_profile()
	var reason := check_entry(profile)
	if reason != "":
		ChatBox.push_system("[color=#ff3333][Thiên Tầm Tháp][/color] " + reason)
		get_tree().change_scene_to_file("res://ui/character_hub/CharacterHub.tscn")
		return

	# Ghi nhận 1 lượt tham gia hôm nay
	add_run(profile)

	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_player.global_position = CENTER_POS + Vector2(0, 110)
		if "suppress_death_popup" in _player:
			_player.suppress_death_popup = true
		if _player.has_signal("died"):
			_player.died.connect(_on_player_died)

	# Dựng Tracker HUD
	var best_rec := best_stage(profile)
	_hud = ThienTamThapTrackerHudScript.new()
	_hud.setup(waves_data, best_rec)
	_hud.speed_changed.connect(_on_speed_changed)
	_hud.exit_requested.connect(_on_exit_requested)
	_hud.leaderboard_requested.connect(_open_leaderboard)
	add_child(_hud)

	is_active = true
	_start_wave(1)

func _open_leaderboard() -> void:
	var lb_script: GDScript = load("res://ui/ranking/thien_tam_thap_leaderboard_window.gd")
	if lb_script != null:
		var profile := _get_profile()
		lb_script.open(self, profile)

func _process(delta: float) -> void:
	if not is_active or is_game_over:
		return

	if is_resting:
		rest_timer -= delta
		if rest_timer <= 0.0:
			is_resting = false
			if current_wave < total_waves:
				current_wave += 1
				_start_wave(current_wave)
			else:
				_finish_game(true)
		return

	wave_timer -= delta
	if _hud != null:
		_hud.update_status(current_wave, stages_cleared, wave_timer, _alive_monsters.size())

	# Nếu hết thời gian đợt mà còn quái: quái đợt sau vẫn sẽ xuất kích để tăng độ thử thách
	if wave_timer <= 0.0:
		if current_wave < total_waves:
			current_wave += 1
			_start_wave(current_wave)
		else:
			_finish_game(stages_cleared > 0)

func _start_wave(w_num: int) -> void:
	if w_num - 1 >= waves_data.size():
		_finish_game(true)
		return

	var w_info: Dictionary = waves_data[w_num - 1]
	var m_id: int = int(w_info.get("monster_id", 43))
	var m_lvl: int = int(w_info.get("level", 30))
	var series: int = int(w_info.get("series", 0))
	var is_boss: bool = bool(w_info.get("is_boss_wave", false))

	wave_timer = WAVE_TIMEOUT

	# 1. Sinh 8 quái thường xếp vòng tròn quanh tâm
	var creep_count := 8
	for i in range(creep_count):
		var angle := (float(i) / float(creep_count)) * TAU
		var offset := Vector2(cos(angle) * 220.0, sin(angle) * 130.0) + Vector2(randf_range(-20, 20), randf_range(-15, 15))
		_spawn_creep(m_id, m_lvl, series, CENTER_POS + offset)

	# 2. Nếu là đợt Boss (mỗi 10 ải): Sinh Đại Boss ngay tại tâm
	if is_boss:
		var b_data: Dictionary = w_info.get("boss", {})
		var boss_id: int = int(b_data.get("monster_id", 456))
		var boss_name: String = str(b_data.get("name", "Đại Boss"))
		var next_mid: int = int(b_data.get("next_monster_id", m_id))
		var next_lvl: int = int(b_data.get("next_monster_level", m_lvl))
		_spawn_boss(boss_id, m_lvl, series, CENTER_POS, boss_name, next_mid, next_lvl)

	if _hud != null:
		_hud.update_status(current_wave, stages_cleared, wave_timer, _alive_monsters.size())
		_hud.refresh_tracker()

	var boss_txt := " [color=#ff3333]👑 XUẤT HIỆN ĐẠI BOSS![/color]" if is_boss else ""
	ChatBox.push_system("[color=#00ffff][Thiên Tầm Tháp][/color] Bắt đầu [b]Ải %d[/b]! Quái: %s (Cấp %d)%s" % [
		w_num,
		str(w_info.get("monster_name", "Quái")),
		m_lvl,
		boss_txt
	])

func _spawn_creep(m_id: int, lvl: int, element: int, spawn_pos: Vector2) -> void:
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
	m.ai_enabled = true
	m.target = _player

	# Máu nâng lên x2, Dame giữ nguyên
	var base_hp := MonsterData.stat_at_level(m.data, "life", lvl)
	if base_hp <= 0:
		base_hp = int(20 + lvl * 6)
	var calculated_hp := float(base_hp) * 2.0
	m.hp_override = maxi(1, int(calculated_hp))
	m.max_health = calculated_hp
	m.health = calculated_hp

	# Rớt đồ x3, EXP x2
	m.drop_multiplier = 3
	m.exp_multiplier = 2.0

	m.died.connect(_on_monster_died)
	parent.add_child(m)
	_alive_monsters.append(m)

func _spawn_boss(boss_id: int, lvl: int, element: int, spawn_pos: Vector2, boss_name: String, next_mid: int, next_lvl: int) -> void:
	var base_data := MonsterData.monster(boss_id)
	var parent := VltkWorld.entity_parent()
	if base_data.is_empty() or parent == null:
		return

	# Lấy thông tin quái tiếp theo để tính Máu x10 và Dame bằng quái tiếp theo
	var next_data := MonsterData.monster(next_mid)
	var next_base_hp := MonsterData.stat_at_level(next_data, "life", next_lvl)
	if next_base_hp <= 0:
		next_base_hp = int(20 + next_lvl * 6)
	var next_hp := float(next_base_hp) * 2.0  ## Máu quái tiếp theo (đã nhân 2 máu)
	var boss_hp := next_hp * 10.0            ## Máu gấp 10 lần quái tiếp theo

	# Dame bằng dame của quái tiếp theo
	var next_min_dmg := MonsterData.stat_at_level(next_data, "min_damage", next_lvl)
	var next_max_dmg := MonsterData.stat_at_level(next_data, "max_damage", next_lvl)
	if next_min_dmg <= 0 and next_max_dmg <= 0:
		var k := (float(next_data.get("min_damage_param", 100)) + float(next_data.get("max_damage_param", 100))) / 200.0
		var test_d := (8.0 + next_lvl * 3.0) * k
		next_min_dmg = int(test_d)
		next_max_dmg = int(test_d)
	var boss_dmg_range := Vector2(float(next_min_dmg), float(maxi(next_min_dmg, next_max_dmg)))

	var b := VltkMonster.new()
	b.monster_id = boss_id
	b.data = base_data.duplicate()
	b.data["name"] = "👑 " + boss_name
	b.data["series"] = element
	b.level = lvl
	b.position = spawn_pos
	b.ai_enabled = true
	b.target = _player
	b.scale = Vector2(1.35, 1.35)
	b.gold_boss = true

	b.hp_override = maxi(1, int(boss_hp))
	b.max_health = boss_hp
	b.health = boss_hp
	b.damage_range_override = boss_dmg_range

	# Đồ rớt nhiều gấp 5 lần bình thường
	b.drop_multiplier = 5
	b.exp_multiplier = 2.0

	b.died.connect(_on_monster_died)
	parent.add_child(b)
	_alive_monsters.append(b)

func _on_monster_died(m: VltkMonster) -> void:
	_alive_monsters.erase(m)
	if _hud != null:
		_hud.update_status(current_wave, stages_cleared, wave_timer, _alive_monsters.size())

	if _alive_monsters.is_empty() and not is_resting and not is_game_over:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	stages_cleared += 1
	var profile: PlayerProfile = _get_profile()
	update_best_stage(profile, stages_cleared)

	ChatBox.push_system("[color=#ffd700][Thiên Tầm Tháp][/color] 🎉 Chúc mừng đại hiệp đã vượt qua [b]Ải %d[/b]! (Vượt thành công %d ải)" % [
		current_wave,
		stages_cleared
	])

	if _hud != null:
		_hud.update_status(current_wave, stages_cleared, 0.0, 0)

	is_resting = true
	rest_timer = REST_INTERVAL

func _on_player_died(_killer = null) -> void:
	if is_game_over:
		return
	ChatBox.push_system("[color=#ff3333][Thiên Tầm Tháp][/color] Đại hiệp đã kiệt sức trước đợt quái!")
	_finish_game(false)

func _on_speed_changed(mult: float) -> void:
	Engine.time_scale = mult

func _on_exit_requested() -> void:
	_finish_game(false)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _finish_game(success: bool) -> void:
	Engine.time_scale = 1.0
	is_game_over = true
	is_active = false

	# Thưởng EXP & Vàng theo số ải đã vượt
	var exp_gained := stages_cleared * 20000
	var gold_gained := stages_cleared * 25000

	var profile: PlayerProfile = _get_profile()
	if profile != null:
		if profile.has_method("gain_exp"):
			profile.gain_exp(exp_gained)
		profile.gold += gold_gained

		# Quà tặng theo mốc ải vượt qua
		if stages_cleared >= 50:
			_award_misc_item(profile, "6_1_400", 1)  # Sát thủ giản
		if stages_cleared >= 100:
			_award_misc_item(profile, "4_489_1", 1)  # Lệnh bài Phong Lăng Độ
		if stages_cleared >= 200:
			_award_misc_item(profile, "6_1_2416", 1) # Lâm An Huyết Chiến Lệnh

		_save_profile(profile)

	_show_result_popup(success, stages_cleared, exp_gained, gold_gained)
	finished.emit(success, stages_cleared)

func _award_misc_item(profile: PlayerProfile, misc_id: String, count: int = 1) -> void:
	if profile == null:
		return
	for i in range(count):
		var it: ItemInstance = ItemGenerator.generate_misc(misc_id)
		if it != null:
			profile.add_item(it)

func _show_result_popup(success: bool, cleared: int, exp_pts: int, gold_pts: int) -> void:
	var popup := CanvasLayer.new()
	popup.layer = 150
	add_child(popup)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.45)
	popup.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(center)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(480, 320)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.07, 0.12, 0.75)
	st.border_color = Color(1.0, 0.85, 0.3, 0.9) if success else Color(0.95, 0.35, 0.35, 0.9)
	st.border_width_left = 2
	st.border_width_right = 2
	st.border_width_top = 2
	st.border_width_bottom = 2
	st.set_corner_radius_all(10)
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
	title.text = "★ HOÀN THÀNH THIÊN TẦM THÁP ★" if success else "⚔️ KẾT THÚC KHIÊU CHIẾN ⚔️"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", GameUi.game_font_bold())
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if success else Color(1.0, 0.4, 0.4))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	v.add_child(title)

	var result_lbl := Label.new()
	result_lbl.text = "Số ải đã vượt qua: Vượt %d ải (Tổng %d ải)" % [cleared, total_waves]
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_override("font", GameUi.game_font_bold())
	result_lbl.add_theme_font_size_override("font_size", 16)
	result_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	result_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	result_lbl.add_theme_constant_override("outline_size", 3)
	v.add_child(result_lbl)

	var reward_lbl := Label.new()
	reward_lbl.text = "Phần Thưởng Nhận Được:\n+ %d Điểm Kinh Nghiệm (EXP)\n+ %d Lượng Vàng\n" % [exp_pts, gold_pts]
	if cleared >= 50:
		reward_lbl.text += "+ 1 Sát Thủ Giản\n"
	if cleared >= 100:
		reward_lbl.text += "+ 1 Lệnh Bài Phong Lăng Độ\n"
	if cleared >= 200:
		reward_lbl.text += "+ 1 Lâm An Huyết Chiến Lệnh\n"
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.add_theme_font_override("font", GameUi.game_font_bold())
	reward_lbl.add_theme_font_size_override("font_size", 14)
	reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	reward_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	reward_lbl.add_theme_constant_override("outline_size", 3)
	v.add_child(reward_lbl)

	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 16)
	v.add_child(act_row)

	var bxh_btn := Button.new()
	bxh_btn.text = "🏆 Xem BXH"
	bxh_btn.custom_minimum_size = Vector2(160, 42)
	bxh_btn.add_theme_font_override("font", GameUi.game_font_bold())
	bxh_btn.add_theme_font_size_override("font_size", 14)
	bxh_btn.focus_mode = Control.FOCUS_NONE
	bxh_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bxh_st := StyleBoxFlat.new()
	bxh_st.bg_color = Color(0.18, 0.15, 0.08, 0.9)
	bxh_st.border_color = Color(0.9, 0.75, 0.3, 0.9)
	bxh_st.border_width_left = 1
	bxh_st.border_width_right = 1
	bxh_st.border_width_top = 1
	bxh_st.border_width_bottom = 1
	bxh_st.set_corner_radius_all(6)
	bxh_btn.add_theme_stylebox_override("normal", bxh_st)
	bxh_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	bxh_btn.pressed.connect(_open_leaderboard)
	act_row.add_child(bxh_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Rời Tháp Trở Về"
	exit_btn.custom_minimum_size = Vector2(160, 42)
	exit_btn.add_theme_font_override("font", GameUi.game_font_bold())
	exit_btn.add_theme_font_size_override("font_size", 14)
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var btn_st := StyleBoxFlat.new()
	btn_st.bg_color = Color(0.12, 0.16, 0.22, 0.85)
	btn_st.border_color = Color(0.85, 0.7, 0.3, 0.9)
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

	exit_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	exit_btn.pressed.connect(func() -> void:
		popup.queue_free()
		get_tree().change_scene_to_file("res://ui/character_hub/CharacterHub.tscn")
	)
	act_row.add_child(exit_btn)
