extends Node
class_name ViemDeChallenge
## VIÊM ĐẾ BẢO TÀNG (Kho Báu Viêm Đế) — Map 853 thực địa chuẩn VLTK gốc:
##   - Script gốc: script/missions/yandibaozang/ (head.lua, mission.lua, npc.lua, npc_death.lua, yandiduihuan.lua)
##   - Map 853 "Kho Báu Viêm Đế" (\maps\特殊用地\炎帝宝藏)
##   - 3 lộ trình tiến công: Đường A (Chính Đạo), Đường B (Trung Lập), Đường C (Tà Phái).
##   - 10 ải quái & Boss môn phái trấn giữ (Thiên Vương, Thiếu Lâm, Ngũ Độc, Đường Môn, Nga My, Thúy Yên, Thiên Nhẫn, Cái Bang, Võ Đang, Côn Lôn).
##   - Khu vực Hạch Tâm Bảo Tàng: Đại Boss Lương Mi Nhi (ID 1309) & Đồ Đằng Viêm Đế.
##   - Phần thưởng: EXP cực lớn (600.000 EXP/ải, 20.000.000 EXP Boss cuối), Rương Viêm Đế Bí Bảo, Thủy Tinh, Huyền Tinh, Mảnh Đồ Đằng & Trang bị Hoàng Kim.
##   - Chế độ Tổ Đội: Cho phép tạo phòng chờ, mọi người sẵn sàng hết mới vào chơi, các đồng đội cùng xuất chiến và vượt ải.

signal finished(success: bool, elapsed_sec: int)

const DATA_PATH := "res://data/challenge/viem_de_data.json"
const MAP_DIR := "res://world/maps/map_853"
const MAP_ID := 853
const TIME_LIMIT_SEC := 1800.0 ## 30 phút theo YDBZ_LIMIT_FINISH
const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"

const ELEMENT_NAMES := ["Kim", "Mộc", "Thủy", "Hỏa", "Thổ"]

static var _cached_data: Dictionary = {}

var route: String = "a"
var double_exp: bool = false
var stage: int = 1
var time_left: float = TIME_LIMIT_SEC
var running: bool = false
var is_done: bool = false
var total_kills: int = 0
var chests_earned: int = 0
var team_members: Array = []

var _alive_monsters: Array[VltkMonster] = []
var _stage_boss: VltkMonster = null
var _final_boss: VltkMonster = null
var _totem_used: bool = false
var _player: Node2D = null
var _allies: Array[PkBot] = []
var _hud: CanvasLayer = null

var _lbl_stage: Label
var _lbl_target: Label
var _lbl_timer: Label
var _lbl_buff: Label
var _lbl_team: Label
var _btn_nav: Button
var _btn_exit: Button

# ---------------------------------------------------------------- DỮ LIỆU & ENTRY
static func load_data() -> Dictionary:
	if _cached_data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var text := FileAccess.get_file_as_string(DATA_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_cached_data = parsed
	return _cached_data

static func map_entry(chosen_route: String = "a", is_double_exp: bool = false, members: Array = []) -> Dictionary:
	var d := load_data()
	var routes: Dictionary = d.get("routes", {})
	var r_info: Dictionary = routes.get(chosen_route, routes.get("a", {}))
	var boat_raw: Array = r_info.get("boat_pos", [60032, 104832])
	var spawn_pt := Vector2(float(boat_raw[0]), float(boat_raw[1]) * 0.5)

	return {
		"id": MAP_ID,
		"name": "Kho Báu Viêm Đế",
		"dir": MAP_DIR,
		"level": 95,
		"viem_de_challenge": true,
		"route": chosen_route,
		"double_exp": is_double_exp,
		"team_members": members,
		"arena_center": spawn_pt,
		"player_spawn_pos": spawn_pt
	}

# ---------------------------------------------------------------- KHỞI TẠO
func _ready() -> void:
	var f: Dictionary = GameManager.field_map
	route = str(f.get("route", "a"))
	double_exp = bool(f.get("double_exp", false))
	team_members = Array(f.get("team_members", []))
	time_left = TIME_LIMIT_SEC
	running = true
	is_done = false
	stage = 1

	call_deferred("_setup_in_world")

func _setup_in_world() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		var root := get_tree().current_scene
		if root:
			_player = root.find_child("Player", true, false) as Node2D

	_setup_hud()
	_setup_allies()
	_start_stage(1)

func _setup_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 25
	add_child(_hud)

	var panel := GameUi.panel(GameUi.PANEL)
	panel.custom_minimum_size = Vector2(360, 125)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 12
	panel.offset_top = 110
	var hud_style := GameUi.box(Color(0.04, 0.05, 0.06, 0.65), Color(0.28, 0.28, 0.24, 0.75), GameUi.RADIUS_PANEL, 1, 10)
	panel.add_theme_stylebox_override("panel", hud_style)
	_hud.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var top_row := HBoxContainer.new()
	vb.add_child(top_row)

	_lbl_stage = SocialUi.label("🏛️ Viêm Đế Bảo Tàng — Ải 1/10", Color(1.0, 0.85, 0.25), 14)
	top_row.add_child(_lbl_stage)

	if double_exp:
		_lbl_buff = SocialUi.label(" [x2 EXP]", Color(0.35, 0.95, 0.45), 12)
		top_row.add_child(_lbl_buff)

	if not team_members.is_empty():
		_lbl_team = SocialUi.label(" [👥 Tổ Đội %d người]" % team_members.size(), Color(0.4, 0.8, 1.0), 12)
		top_row.add_child(_lbl_team)

	_lbl_target = SocialUi.label("Mục tiêu: Đang nạp...", SocialUi.TEXT, 12)
	vb.add_child(_lbl_target)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 8)
	vb.add_child(bot_row)

	_lbl_timer = SocialUi.label("⏳ 30:00", Color(0.4, 0.85, 1.0), 13)
	bot_row.add_child(_lbl_timer)

	_btn_nav = SocialUi.small_button("🧭 Đến Ải")
	_btn_nav.pressed.connect(_on_navigate_pressed)
	bot_row.add_child(_btn_nav)

	_btn_exit = SocialUi.small_button("🚪 Rời")
	_btn_exit.pressed.connect(_on_exit_pressed)
	bot_row.add_child(_btn_exit)

# ---------------------------------------------------------------- ĐỒNG ĐỘI TỔ ĐỘI
func _setup_allies() -> void:
	if team_members.is_empty():
		return
	var parent := VltkWorld.entity_parent()
	if parent == null or _player == null:
		return

	var my_name := ""
	if "profile" in _player and _player.profile:
		my_name = str(_player.profile.display_name)
	elif GameManager.local_profile:
		my_name = str(GameManager.local_profile.display_name)

	for i in team_members.size():
		var m_dict: Dictionary = team_members[i]
		var m_name := str(m_dict.get("name", ""))
		if m_name == my_name:
			continue # Người chơi chính đã có node

		var bot_p: PlayerProfile = null
		if m_dict.has("bot_data") and m_dict["bot_data"] is Dictionary:
			bot_p = PlayerProfile.from_dict(m_dict["bot_data"])
		else:
			var lvl: int = int(m_dict.get("level", 92))
			var s_id: String = str(m_dict.get("sect_id", "vo_dang"))
			bot_p = PkBotProfile.create(lvl, s_id)
			bot_p.display_name = m_name

		var ally := PkBot.new()
		ally.is_match_fighter = true
		ally.name = "ViemDeAlly%d" % i
		ally.setup(bot_p)
		ally.position = _player.position + Vector2(randf_range(-70, 70), randf_range(-50, 50))
		ally.pk_enemy = false
		ally.cast_target_group = &"enemies"
		ally.remove_from_group("enemies")
		ally.add_to_group("allies")
		ally.active = true
		ally.invulnerable = false
		parent.add_child(ally)
		_allies.append(ally)

	if not _allies.is_empty():
		ChatBox.push_system("[color=#55ffff][Viêm Đế Bảo Tàng][/color] %d đồng đội tổ đội đã xuất chiến cùng hiệp khách!" % _allies.size())

func _process(delta: float) -> void:
	if not running or is_done:
		return
	time_left -= delta
	if _lbl_timer:
		var mins := int(maxf(time_left, 0.0)) / 60
		var secs := int(maxf(time_left, 0.0)) % 60
		_lbl_timer.text = "⏳ %02d:%02d" % [mins, secs]

	if time_left <= 0.0:
		_on_timeout()
		return

	_update_allies_ai()

func _update_allies_ai() -> void:
	if _allies.is_empty():
		return
	for ally in _allies:
		if ally == null or not is_instance_valid(ally) or (ally.has_method("is_dead") and ally.is_dead()):
			continue
		if ally.target == null or not is_instance_valid(ally.target) or (ally.target.has_method("is_dead") and ally.target.is_dead()):
			# Tìm quái hoặc boss gần nhất để đánh
			var nearest_enemy: Node2D = null
			var min_dist := 1200.0
			if _final_boss and is_instance_valid(_final_boss) and not _final_boss.is_dead():
				nearest_enemy = _final_boss
			elif _stage_boss and is_instance_valid(_stage_boss) and not _stage_boss.is_dead():
				nearest_enemy = _stage_boss
			else:
				for mon in _alive_monsters:
					if is_instance_valid(mon) and not mon.is_dead():
						var d := ally.position.distance_to(mon.position)
						if d < min_dist:
							min_dist = d
							nearest_enemy = mon

			if nearest_enemy != null:
				ally.target = nearest_enemy
			elif _player != null and is_instance_valid(_player):
				# Nếu không có quái xung quanh, đi theo người chơi
				if ally.position.distance_to(_player.position) > 160.0:
					ally.velocity = (_player.position - ally.position).normalized() * 180.0
				else:
					ally.velocity = Vector2.ZERO

# ---------------------------------------------------------------- TIẾN TRÌNH CÁC ẢI
func _start_stage(s_num: int) -> void:
	stage = s_num
	_alive_monsters.clear()
	_stage_boss = null

	var d := load_data()
	var routes: Dictionary = d.get("routes", {})
	var r_info: Dictionary = routes.get(route, routes.get("a", {}))
	var stages: Array = r_info.get("stages", [])

	if s_num > stages.size():
		_enter_final_chamber()
		return

	var s_data: Dictionary = stages[s_num - 1]
	var s_name := str(s_data.get("name", "Ải %d" % s_num))
	var b_name := str(s_data.get("boss_name", "Thủ Lĩnh"))
	var series: int = int(s_data.get("series", 0))
	var elem_name: String = ELEMENT_NAMES[clampi(series, 0, 4)]
	if _lbl_stage:
		_lbl_stage.text = "🏛️ %s (Hệ %s) — Ải %d/10" % [s_name, elem_name, s_num]

	var coords: Array = s_data.get("coords", [])
	var minion_tpl: int = int(s_data.get("minion_tpl", 1299))
	var minion_name: String = str(s_data.get("minion_name", "Đệ Tử Trấn Ải"))

	# Di chuyển người chơi & đồng đội đến vị trí ải mới
	if not coords.is_empty():
		var stage_entry_raw: Array = coords[0]
		var stage_entry_pos := Vector2(float(stage_entry_raw[0]), float(stage_entry_raw[1]) * 0.5)
		if s_num > 1:
			_teleport_team(stage_entry_pos)

	# GIAI ĐOẠN 1: Tạo 14 quái hộ vệ của ải (Chuẩn VLTK gốc)
	var spawn_count := mini(coords.size(), 14)
	for i in spawn_count:
		var raw_c: Array = coords[i]
		var pos := Vector2(float(raw_c[0]), float(raw_c[1]) * 0.5)
		_spawn_monster(minion_tpl, minion_name, 95, series, 180000, pos, false)

	_update_target_label()
	ChatBox.push_system("[color=#ffd700][Viêm Đế Bảo Tàng][/color] Đã tiến vào %s (Hệ %s)! Hãy quét sạch 14 hộ vệ để khiêu chiến %s!" % [s_name, elem_name, b_name])

func _spawn_stage_boss() -> void:
	var d := load_data()
	var routes: Dictionary = d.get("routes", {})
	var r_info: Dictionary = routes.get(route, routes.get("a", {}))
	var stages: Array = r_info.get("stages", [])
	if stage > stages.size():
		return
	var s_data: Dictionary = stages[stage - 1]
	var b_name := str(s_data.get("boss_name", "Thủ Lĩnh"))
	var series: int = int(s_data.get("series", 0))
	var boss_tpl: int = int(s_data.get("boss_tpl", 1289))

	var boss_raw: Array = s_data.get("boss_pos", [59200, 106112])
	var fallback_pos := Vector2(float(boss_raw[0]), float(boss_raw[1]) * 0.5)
	var b_pos := _player.position + Vector2(120, 0) if _player and is_instance_valid(_player) else fallback_pos
	_stage_boss = _spawn_monster(boss_tpl, b_name, 95, series, 650000, b_pos, true, false)
	var elem_name: String = ELEMENT_NAMES[clampi(series, 0, 4)]
	_update_target_label()
	ChatBox.push_system("[color=#ff3333][Viêm Đế Bảo Tàng][/color] 🔥 Đã tiêu diệt sạch 14 hộ vệ! Thủ Lĩnh [b]%s[/b] (Hệ %s) đã xuất hiện! Tiêu diệt Thủ Lĩnh để phá giải kết giới qua ải!" % [b_name, elem_name])

func _teleport_team(target_pos: Vector2) -> void:
	if _player and is_instance_valid(_player):
		_player.global_position = target_pos
		if _player.has_method("reset_navigation"):
			_player.reset_navigation()
	for ally in _allies:
		if ally and is_instance_valid(ally) and not ally.is_dead():
			ally.global_position = target_pos + Vector2(randf_range(-60, 60), randf_range(-40, 40))
			ally.health = ally.max_health # Hồi phục khi qua ải

# Bảng chiêu thức 9x thập đại môn phái trang bị cho quái nhỏ (hộ vệ/môn đệ trấn ải)
const MINION_9X_SKILLS := {
	1299: [[325, 20], [326, 20], [325, 20], [324, 20]], # Thiên Vương: Truy Phong Quyết, Phá Thiên Trảm (9x)
	1300: [[318, 20], [319, 20], [321, 20], [318, 20]], # Thiếu Lâm: Đạt Ma Độ Giang, Hoành Tảo Thiên Quân, Vô Tướng Trảm (9x)
	1301: [[353, 20], [354, 20], [353, 20], [354, 20]], # Ngũ Độc: Âm Phong Thực Cốt, Thiên Cương Độc Thủ (9x)
	1302: [[302, 20], [342, 20], [339, 20], [302, 20]], # Đường Môn: Bạo Vũ Lê Hoa, Cửu Cung Phi Tinh, Nhiếp Hồn Nguyệt ảnh (9x)
	1303: [[328, 20], [380, 20], [328, 20], [380, 20]], # Nga My: Tam Nga Tề Tuyết, Phong Sương Toái ảnh (9x)
	1304: [[336, 20], [337, 20], [336, 20], [337, 20]], # Thúy Yên: Băng Tung Vô ảnh, Băng Tâm Tiên Tử (9x)
	1305: [[361, 20], [362, 20], [361, 20], [362, 20]], # Thiên Nhẫn: Vân Long Kích, Thiên Ngoại Lưu Tinh (9x)
	1306: [[357, 20], [359, 20], [357, 20], [359, 20]], # Cái Bang: Phi Long Tại Thiên, Thiên Hạ Vô Cẩu (9x)
	1307: [[368, 20], [365, 20], [368, 20], [365, 20]], # Võ Đang: Nhân Kiếm Hợp Nhất, Thiên Địa Vô Cực (9x)
	1308: [[372, 20], [375, 20], [372, 20], [375, 20]], # Côn Lôn: Ngạo Tuyết Tiêu Phong, Lôi động Cửu Thiên (9x)
}

func _spawn_monster(tpl: int, m_name: String, lvl: int, series: int, hp: int, pos: Vector2, is_boss: bool, is_final: bool = false) -> VltkMonster:
	var base := MonsterData.monster(tpl)
	var parent := VltkWorld.entity_parent()
	if base.is_empty() or parent == null:
		return null

	var m := VltkMonster.new()
	m.monster_id = tpl
	m.data = base.duplicate()
	m.data["name"] = m_name
	m.data["series"] = series
	if MINION_9X_SKILLS.has(tpl):
		m.data["skills"] = MINION_9X_SKILLS[tpl].duplicate(true)
	m.data["keep_skills"] = true
	m.data["skill_levels_exact"] = true
	m.level = lvl
	m.hp_override = hp
	m.position = pos
	m.ai_enabled = true
	m.add_to_group("viem_de")

	if is_final:
		m.died.connect(func(_dm: VltkMonster) -> void:
			_on_final_boss_died(m)
		)
	else:
		m.died.connect(func(_dm: VltkMonster) -> void:
			_on_monster_died(m, is_boss)
		)

	parent.add_child(m)

	if is_boss:
		m.add_to_group("bosses")
	else:
		_alive_monsters.append(m)

	return m

func _on_monster_died(m: VltkMonster, is_boss: bool) -> void:
	total_kills += 1
	if stage >= 11:
		_alive_monsters.erase(m)
		_update_target_label()
		return
	if is_boss:
		_stage_boss = null
		_on_stage_cleared()
	else:
		_alive_monsters.erase(m)
		_update_target_label()
		# Khi tiêu diệt hết 14 quái hộ vệ, gọi Thủ Lĩnh xuất hiện (Chuẩn VLTK gốc)
		if _alive_monsters.is_empty():
			if _stage_boss == null or not is_instance_valid(_stage_boss):
				_spawn_stage_boss()

func _update_target_label() -> void:
	if _lbl_target == null:
		return
	if stage >= 11:
		if _final_boss and is_instance_valid(_final_boss) and not _final_boss.is_dead():
			var g_count := _alive_monsters.size()
			if g_count > 0:
				_lbl_target.text = "Đại Boss: Lương Mi Nhi | Vệ binh còn: %d" % g_count
			else:
				_lbl_target.text = "Đại Boss: Lương Mi Nhi (Hạ Boss mở Rương Viêm Đế!)"
		else:
			_lbl_target.text = "Đã chinh phục Kho Báu Viêm Đế!"
		return
	if _stage_boss and is_instance_valid(_stage_boss) and not _stage_boss.is_dead():
		_lbl_target.text = "Thủ lĩnh: %s (Tiêu diệt để qua ải!)" % str(_stage_boss.data.get("name", "Boss"))
	elif not _alive_monsters.is_empty():
		_lbl_target.text = "Hộ vệ còn lại: %d con (Hạ hết gọi Boss)" % _alive_monsters.size()
	else:
		_lbl_target.text = "Đang triệu hồi Thủ Lĩnh..."

# ---------------------------------------------------------------- VƯỢT ẢI THÀNH CÔNG
func _on_stage_cleared() -> void:
	var base_exp := 600000
	var exp_reward := base_exp * 2 if double_exp else base_exp

	var profile := GameManager.local_profile
	if profile:
		profile.add_exp(exp_reward)

	var chest_text := ""
	# Ải chẵn 2, 4, 6, 8, 10 tặng Rương Viêm Đế Bí Bảo
	if stage % 2 == 0:
		var n_chests := (2 if double_exp else 1)
		chests_earned += n_chests
		chest_text = " · Nhận %d Rương Viêm Đế Bí Bảo" % n_chests
		if profile:
			for i in n_chests:
				var chest_it := ItemGenerator.generate_misc("6_1_2805")
				if chest_it != null:
					profile.add_item(chest_it)
			var w_script: GDScript = load("res://ui/events/viem_de_window.gd")
			if w_script != null:
				var rec: Dictionary = w_script._get_records_for(profile)
				rec["chests"] = int(rec.get("chests", 0)) + n_chests
				w_script._save_records_for(rec, profile)

	if profile:
		SaveManager.save_profile(profile)
		SaveManager.flush_online()

	ChatBox.push_system("[color=#55ff55][Viêm Đế Bảo Tàng][/color] Vượt qua Ải %d thành công! Nhận %s EXP%s!" % [
		stage, InventoryPopup.format_money(exp_reward), chest_text
	])

	# Dọn dẹp quái cũ còn sót
	for mon in _alive_monsters:
		if is_instance_valid(mon) and not mon.is_dead():
			mon.queue_free()
	_alive_monsters.clear()
	if _stage_boss and is_instance_valid(_stage_boss) and not _stage_boss.is_dead():
		_stage_boss.queue_free()
		_stage_boss = null

	if stage < 10:
		stage += 1
		_start_stage(stage)
	else:
		_enter_final_chamber()

# ---------------------------------------------------------------- HẠCH TÂM BẢO TÀNG & LƯƠNG MI NHI
func _enter_final_chamber() -> void:
	stage = 11
	if _lbl_stage:
		_lbl_stage.text = "👑 Hạch Tâm Viêm Đế Bảo Tàng"
	if _lbl_target:
		_lbl_target.text = "Mục tiêu: Đánh bại Lương Mi Nhi & 10 Hộ Vệ Trấn Ải"

	ChatBox.push_system("[color=#ffd700][Viêm Đế Bảo Tàng][/color] Chúc mừng hào kiệt đã vượt qua toàn bộ 10 Ải! Tiến vào Hạch Tâm đối đầu Đại Boss [b]Lương Mi Nhi[/b] và 10 Hộ Vệ Trấn Thủ!")

	var d := load_data()
	var fc: Dictionary = d.get("final_chamber", {})
	var boss_raw: Array = fc.get("boss_pos", [56960, 114400])
	var b_pos := Vector2(float(boss_raw[0]), float(boss_raw[1]) * 0.5)

	# Di chuyển cả đội đến trước Hạch Tâm
	_teleport_team(b_pos + Vector2(0, 300))

	# Spawn Lương Mi Nhi (Tpl 1309) với is_boss=true, is_final=true
	_final_boss = _spawn_monster(1309, "Lương Mi Nhi", 95, 3, 2900000, b_pos, true, true)

	# GIAI ĐOẠN ẢI CUỐI: Triệu hồi 10 Hộ Vệ Thập Đại Môn Phái (theo tọa độ wayfinial.txt gốc)
	var coords: Array = fc.get("spawn_coords", [])
	var guardians: Array = fc.get("guardians", [])
	for i in mini(coords.size(), guardians.size()):
		var g_info: Dictionary = guardians[i]
		var raw_c: Array = coords[i]
		var g_pos := Vector2(float(raw_c[0]), float(raw_c[1]) * 0.5)
		var g_tpl: int = int(g_info.get("tpl", 1310 + i))
		var g_name: String = str(g_info.get("name", "Hộ Vệ Viêm Đế"))
		var g_series: int = int(g_info.get("series", 0))
		var g_hp: int = int(g_info.get("hp", 750000))
		var gm := _spawn_monster(g_tpl, g_name, 95, g_series, g_hp, g_pos, true, false)
		if gm != null:
			_alive_monsters.append(gm)

	# Spawn Đồ Đằng Viêm Đế (Totem) bên cạnh
	var totem_raw: Array = fc.get("totem_pos", [56960, 114000])
	var t_pos := Vector2(float(totem_raw[0]), float(totem_raw[1]) * 0.5)
	_spawn_totem(t_pos)

	_update_target_label()

func _spawn_totem(pos: Vector2) -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null:
		return
	var totem := Area2D.new()
	totem.position = pos
	totem.name = "YandiTotem"

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 45.0
	col.shape = circle
	totem.add_child(col)

	var lbl := SocialUi.label("🔥 ĐỒ ĐẰNG VIÊM ĐẾ (Chạm để nhận Chúc Phúc)", Color(1.0, 0.85, 0.25), 13, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.position = Vector2(-150, -40)
	totem.add_child(lbl)

	totem.body_entered.connect(func(body: Node) -> void:
		if body == _player and not _totem_used:
			_activate_totem()
	)
	parent.add_child(totem)

func _activate_totem() -> void:
	_totem_used = true
	var profile := GameManager.local_profile
	if profile:
		profile.current_hp = profile.max_hp
		profile.current_mana = profile.max_mana
		profile.gold += 200000

		# Trao 1 Mảnh Đồ Đằng Viêm Đế vào hành trang nhân vật
		var frag_it := ItemGenerator.generate_misc("6_1_1685")
		if frag_it != null:
			profile.add_item(frag_it)

		var w_script: GDScript = load("res://ui/events/viem_de_window.gd")
		if w_script != null:
			var rec: Dictionary = w_script._get_records_for(profile)
			rec["totem_fragments"] = int(rec.get("totem_fragments", 0)) + 1
			w_script._save_records_for(rec, profile)

		SaveManager.save_profile(profile)
		SaveManager.flush_online()

		ChatBox.push_system("[color=#ffff00][Đồ Đằng Viêm Đế][/color] Chúc Phúc Thần Nông: Toàn bộ Sinh lực & Nội lực hồi phục 100%! Nhận thêm 200.000 Lượng và 1 Mảnh Đồ Đằng Viêm Đế!")

func _on_final_boss_died(_m: VltkMonster) -> void:
	if is_done:
		return
	is_done = true
	running = false

	var final_exp := 20000000 * (2 if double_exp else 1)
	var profile := GameManager.local_profile
	var boss_chests := (4 if double_exp else 2)
	chests_earned += boss_chests

	if profile:
		profile.add_exp(final_exp)
		profile.gold += 1500000

		# Trao 2-4 Rương Viêm Đế Bí Bảo trực tiếp vào hành trang
		for i in boss_chests:
			var chest_it := ItemGenerator.generate_misc("6_1_2805")
			if chest_it != null:
				profile.add_item(chest_it)

		# Trao 3-5 Mảnh Đồ Đằng Viêm Đế trực tiếp vào hành trang
		var drop_frags := randi_range(3, 5)
		for i in drop_frags:
			var frag_it := ItemGenerator.generate_misc("6_1_1685")
			if frag_it != null:
				profile.add_item(frag_it)

		# Tăng lượt hoàn thành hôm nay & cập nhật records
		var w_script: GDScript = load("res://ui/events/viem_de_window.gd")
		if w_script != null:
			var rec: Dictionary = w_script._get_records_for(profile)
			var today := Time.get_date_string_from_system()
			var runs_dict: Dictionary = rec.get("runs", {})
			runs_dict[today] = int(runs_dict.get(today, 0)) + 1
			rec["runs"] = runs_dict
			rec["chests"] = int(rec.get("chests", 0)) + boss_chests
			rec["totem_fragments"] = int(rec.get("totem_fragments", 0)) + drop_frags
			w_script._save_records_for(rec, profile)

		SaveManager.save_profile(profile)
		SaveManager.flush_online()

	# Rớt đồ quý hiếm trên đất
	if _final_boss and is_instance_valid(_final_boss):
		_spawn_final_loot(_final_boss.position)

	# Dọn dẹp quái hộ vệ còn sót tại Hạch Tâm
	for mon in _alive_monsters:
		if is_instance_valid(mon) and not mon.is_dead():
			mon.queue_free()
	_alive_monsters.clear()

	# Hiện thông báo chiến thắng
	_show_victory_dialog(final_exp)

func _spawn_final_loot(at_pos: Vector2) -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null:
		return
	var drops: Array = []
	# Rơi ngân lượng
	for i in 6:
		drops.append({"type": "money", "amount": randi_range(200000, 500000)})
	# Rơi Thủy Tinh (Lam/Tử/Lục)
	for tt_id in ["4_238_1", "4_239_1", "4_240_1"]:
		var tt_it := ItemGenerator.generate_misc(tt_id)
		if tt_it != null:
			drops.append({"type": "item", "item": tt_it})
	# Rơi Mảnh Đồ Đằng Viêm Đế trên đất
	for i in 3:
		var frag_it := ItemGenerator.generate_misc("6_1_1685")
		if frag_it != null:
			drops.append({"type": "item", "item": frag_it})
	# Rơi Rương Viêm Đế Bí Bảo trên đất
	var chest_it := ItemGenerator.generate_misc("6_1_2805")
	if chest_it != null:
		drops.append({"type": "item", "item": chest_it})

	GroundDrop.spawn_drops(parent, at_pos, drops)

func _show_victory_dialog(earned_exp: int) -> void:
	var dlg := SocialWindow.new("BẢO TÀNG VIÊM ĐẾ ĐÃ ĐƯỢC CHINH PHỤC!", "Tiêu diệt thành công Boss Cuối Lương Mi Nhi", 520.0)
	dlg.body.add_child(SocialUi.label("🎉 CHÚC MỪNG ĐẠI HIỆP ĐẠI PHÁ VIÊM ĐẾ!", Color(1.0, 0.85, 0.25), 18, HORIZONTAL_ALIGNMENT_CENTER))

	var team_txt := "Đồng Đội: Cùng tổ đội %d hiệp khách bình định bảo tàng!\n" % (team_members.size() if not team_members.is_empty() else 1)
	var info := SocialUi.label("Toàn bộ 10 ải và Hạch Tâm Viêm Đế đã được bình định thành công!\n\n%sPhần Thưởng Thu Được:\n+ %s EXP\n+ 1.500.000 Lượng\n+ %d Rương Viêm Đế Bí Bảo\n+ Các bảo vật rơi đầy mặt đất!" % [
		team_txt,
		InventoryPopup.format_money(earned_exp),
		chests_earned + 2
	], SocialUi.TEXT, 13)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg.body.add_child(info)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dlg.body.add_child(btn_row)

	var btn_hub := SocialUi.stone_button("Về Thành Thị", Vector2(160, 40))
	btn_hub.pressed.connect(func() -> void:
		dlg.queue_free()
		_return_to_hub()
	)
	btn_row.add_child(btn_hub)

	SocialWindow.present(self, dlg, &"viem_de_victory")

# ---------------------------------------------------------------- THAO TÁC HUD & ĐIỀU HƯỚNG
func _on_navigate_pressed() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var target_pos := Vector2.ZERO
	if _final_boss and is_instance_valid(_final_boss) and not _final_boss.is_dead():
		target_pos = _final_boss.position
	elif _stage_boss and is_instance_valid(_stage_boss) and not _stage_boss.is_dead():
		target_pos = _stage_boss.position
	elif not _alive_monsters.is_empty() and is_instance_valid(_alive_monsters[0]):
		target_pos = _alive_monsters[0].position

	if target_pos != Vector2.ZERO:
		if _player.has_method("move_to"):
			_player.move_to(target_pos)
		elif _player.has_method("walk_to"):
			_player.walk_to(target_pos)
		ChatBox.push_system("[color=#55ffff][Viêm Đế Bảo Tàng][/color] Đang tự động di chuyển đến vị trí mục tiêu...")

func _on_exit_pressed() -> void:
	SocialWindow.ask_yes_no(self, "Rời Viêm Đế Bảo Tàng", "Đại hiệp có chắc chắn muốn rời khỏi bảo tàng không?\nTiến trình vượt ải hiện tại sẽ kết thúc.", func(yes: bool) -> void:
		if yes:
			_return_to_hub()
	, "Rời Khỏi", "Ở Lại")

func _on_timeout() -> void:
	is_done = true
	running = false
	SocialWindow.info(self, "Hết Giờ", "Đã hết thời gian 30 phút thám hiểm Viêm Đế Bảo Tàng! Nhân vật sẽ được đưa về thành thị.")
	get_tree().create_timer(3.0).timeout.connect(_return_to_hub)

func _return_to_hub() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.queue_free()
	for ally in _allies:
		if ally and is_instance_valid(ally):
			ally.queue_free()
	_allies.clear()
	GameManager.field_map = {}
	get_tree().change_scene_to_file(HUB_SCENE)
