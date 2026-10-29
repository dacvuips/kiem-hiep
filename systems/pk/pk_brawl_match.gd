extends Node
class_name PkBrawlMatch

const VsScoreBar := preload("res://ui/common/vs_score_bar.gd")
## Trình điều phối Trận Đấu "Lộn Xộn" (Loạn đả 16 người hoặc Đấu đội 1vs1 -> 8vs8)
## - Đấu đơn (Solo): 16 người (1 người chơi + 15 bots), đụng là đánh (Free-For-All).
## - Đấu theo đội (Team): 2 phe Xanh vs Đỏ (1vs1 đến 8vs8), 2 màu riêng biệt.
## - Hạ gục 1 mạng: +300 điểm. Bị hạ gục: -100 điểm.
## - Kết thúc trận: Điểm số x 30 = EXP cộng trực tiếp vào EXP thật của nhân vật.
## - Nút & phím Tab mở Bảng Xếp Hạng hiển thị: Tên, Lv, Kills, Deaths, Liên trảm, Điểm.
## - Điều kiện kết thúc: Đạt đủ số mạng chỉ định (10..200 mạng).

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const PREPARE_SEC := 3.0
const CountdownOverlay = preload("res://ui/common/countdown_overlay.gd")
const RESPAWN_SEC := 3.0
const LEAVE_AFTER_SEC := 8.0

var mode: PkRules.Mode = PkRules.Mode.LON_XON
var brawl_type: String = "solo" ## "solo" hoặc "team"
var team_size: int = 1
var map_id: int = 319
var target_kills: int = 20
var my_side: String = "song" ## "song" = Xanh, "jin" = Đỏ

var running: bool = false
var done: bool = false
var match_time: float = 0.0
var _prepare_time: float = PREPARE_SEC
var _leave_in: float = -1.0

var _player: Node2D = null
var _combatants: Array[Dictionary] = []
var _team_kills: Dictionary = {"blue": 0, "red": 0}

# HUD Controls
var _hud: CanvasLayer
var _vs_bar: VsScoreBar
var _top_panel: PanelContainer
var _score_title_lbl: Label
var _main_score_lbl: Label
var _sub_score_lbl: Label
var _player_stats_lbl: Label
var _clock_lbl: Label
var _kill_feed_box: VBoxContainer
var _marquee_lbl: Label
var _scoreboard_modal: Control
var _scoreboard_list: VBoxContainer
var _btn_scoreboard: Button
var _btn_leave: Button
var _finish_popup: Control

func _ready() -> void:
	var field: Dictionary = GameManager.field_map
	var pk: Dictionary = field.get("pk", {})
	brawl_type = str(pk.get("brawl_type", "solo"))
	team_size = clampi(int(pk.get("team_size", 1)), 1, 8)
	map_id = int(pk.get("map_id", 319))
	target_kills = maxi(10, int(pk.get("target_kills", 20)))
	my_side = str(pk.get("side", "song"))

	_build_hud()
	_clear_map_monsters()

	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		if "suppress_death_popup" in _player:
			_player.suppress_death_popup = true
		if "hurt_invincible" in _player:
			_player.hurt_invincible = false
		if _player.has_signal("died"):
			_player.died.connect(_on_player_died)

	_setup_combatants.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle_scoreboard()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- Dọn dẹp quái trên map
func _clear_map_monsters() -> void:
	if VltkWorld.current != null:
		VltkWorld.current.clear_all_monsters()
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and not node.is_in_group("brawl_fighters") and not node.is_in_group("team_blue") and not node.is_in_group("team_red"):
			node.queue_free()

# ---------------------------------------------------------------- Khởi tạo đấu thủ & Vị trí
func _setup_combatants() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null or _player == null:
		push_warning("PkBrawlMatch: Chưa có map hoặc player.")
		return

	var center := Vector2.ZERO
	if VltkWorld.current:
		center = VltkWorld.current._default_center()
		if VltkWorld.current.map:
			VltkWorld.current.map.prepare_around(center)
		var open_c := VltkWorld.current._open_position_near(center)
		if open_c != Vector2.ZERO:
			center = open_c
	if center == Vector2.ZERO and _player != null:
		center = _player.global_position

	var field: Dictionary = GameManager.field_map
	var pk: Dictionary = field.get("pk", {})
	var p_profile := GameManager.local_profile

	if brawl_type == "solo":
		_setup_solo_match(parent, center, pk, p_profile)
	else:
		_setup_team_match(parent, center, pk, p_profile)

	_say("Trận Đấu Lộn Xộn: chuẩn bị bắt đầu!")
	if _player and "is_invincible" in _player:
		_player.is_invincible = true
	CountdownOverlay.start(self, _start_fight)
	_update_hud()

func _setup_solo_match(parent: Node, center: Vector2, pk: Dictionary, p_profile: PlayerProfile) -> void:
	_player.add_to_group("brawl_fighters")
	_player.set("cast_target_group", &"brawl_fighters")
	_player.set("pk_enemy", true)

	var spawn_points := _generate_scattered_spawns(center, 16)
	_player.global_position = spawn_points[0] - Vector2(0, PkBot.FEET_OFFSET)
	if VltkWorld.current:
		VltkWorld.current.respawn_point = spawn_points[0]
		if VltkWorld.current.map:
			VltkWorld.current.map.prepare_around(spawn_points[0])
			if VltkWorld.current.map is VltkWorld.SortedMap:
				(VltkWorld.current.map as VltkWorld.SortedMap).warm_up(_player.global_position)

	# Đấu thủ 0 là Player
	var p_data := {
		"id": 0,
		"name": p_profile.display_name if p_profile else "Hiệp Khách",
		"level": p_profile.level if p_profile else 90,
		"sect_name": SectRegistry.get_by_id(p_profile.sect_id).sect_name if (p_profile and SectRegistry.get_by_id(p_profile.sect_id)) else "Vô môn phái",
		"is_player": true,
		"team": "solo",
		"kills": 0,
		"deaths": 0,
		"streak": 0,
		"max_streak": 0,
		"score": 0,
		"node": _player,
		"spawn_pos": spawn_points[0] - Vector2(0, PkBot.FEET_OFFSET),
		"respawn_timer": 0.0,
		"is_dead": false
	}
	_combatants.append(p_data)

	# 15 Bots
	var solo_combatants: Array = pk.get("solo_combatants", [])
	for i in range(1, 16):
		var bot_prof: PlayerProfile = null
		if i < solo_combatants.size() and solo_combatants[i] is Dictionary and solo_combatants[i].has("bot_data"):
			bot_prof = PlayerProfile.from_dict(solo_combatants[i]["bot_data"])
		else:
			bot_prof = PkBotProfile.create(p_profile.level if p_profile else 90)

		var sect := SectRegistry.get_by_id(bot_prof.sect_id)
		var bot := PkBot.new()
		bot.is_match_fighter = true
		bot.name = "BrawlBot_%d" % i
		bot.setup(bot_prof)
		bot.position = spawn_points[i] - Vector2(0, PkBot.FEET_OFFSET)
		bot.cast_target_group = &"brawl_fighters"
		bot.add_to_group("brawl_fighters")
		bot.add_to_group("enemies")
		bot.pk_enemy = true
		bot.invulnerable = true
		bot.active = false
		parent.add_child(bot)

		var b_data := {
			"id": i,
			"name": bot_prof.display_name,
			"level": bot_prof.level,
			"sect_name": sect.sect_name if sect else "Vô môn phái",
			"is_player": false,
			"team": "solo",
			"kills": 0,
			"deaths": 0,
			"streak": 0,
			"max_streak": 0,
			"score": 0,
			"node": bot,
			"spawn_pos": spawn_points[i] - Vector2(0, PkBot.FEET_OFFSET),
			"respawn_timer": 0.0,
			"is_dead": false
		}
		_combatants.append(b_data)
		bot.died.connect(_on_bot_died.bind(b_data))

func _setup_team_match(parent: Node, center: Vector2, pk: Dictionary, p_profile: PlayerProfile) -> void:
	var team_a_data: Array = pk.get("team_a", [])
	var team_b_data: Array = pk.get("team_b", [])
	var player_team := "blue" if my_side == "song" else "red"

	var spawns_blue := _generate_team_spawns(center + Vector2(-360, 0), team_size)
	var spawns_red := _generate_team_spawns(center + Vector2(360, 0), team_size)

	# Thiết lập Player
	if player_team == "blue":
		_player.global_position = spawns_blue[0] - Vector2(0, PkBot.FEET_OFFSET)
		if VltkWorld.current:
			VltkWorld.current.respawn_point = spawns_blue[0]
		_player.add_to_group("team_blue")
		_player.set("cast_target_group", &"team_red")
	else:
		_player.global_position = spawns_red[0] - Vector2(0, PkBot.FEET_OFFSET)
		if VltkWorld.current:
			VltkWorld.current.respawn_point = spawns_red[0]
		_player.add_to_group("team_red")
		_player.set("cast_target_group", &"team_blue")

	if VltkWorld.current and VltkWorld.current.map:
		VltkWorld.current.map.prepare_around(_player.global_position + Vector2(0, PkBot.FEET_OFFSET))
		if VltkWorld.current.map is VltkWorld.SortedMap:
			(VltkWorld.current.map as VltkWorld.SortedMap).warm_up(_player.global_position)

	var p_data := {
		"id": 0,
		"name": p_profile.display_name if p_profile else "Hiệp Khách",
		"level": p_profile.level if p_profile else 90,
		"sect_name": SectRegistry.get_by_id(p_profile.sect_id).sect_name if (p_profile and SectRegistry.get_by_id(p_profile.sect_id)) else "Vô môn phái",
		"is_player": true,
		"team": player_team,
		"kills": 0,
		"deaths": 0,
		"streak": 0,
		"max_streak": 0,
		"score": 0,
		"node": _player,
		"spawn_pos": _player.global_position,
		"respawn_timer": 0.0,
		"is_dead": false
	}
	_combatants.append(p_data)

	# Sinh Team Blue (Phe Xanh)
	for i in team_size:
		if player_team == "blue" and i == 0:
			continue # Slot 0 là player
		var bot_prof: PlayerProfile = null
		if i < team_a_data.size() and team_a_data[i] is Dictionary and team_a_data[i].has("bot_data"):
			bot_prof = PlayerProfile.from_dict(team_a_data[i]["bot_data"])
		else:
			bot_prof = PkBotProfile.create(p_profile.level if p_profile else 90)

		var sect := SectRegistry.get_by_id(bot_prof.sect_id)
		var bot := PkBot.new()
		bot.is_match_fighter = true
		bot.name = "BlueBot_%d" % i
		bot.setup(bot_prof)
		bot.position = spawns_blue[i] - Vector2(0, PkBot.FEET_OFFSET)
		bot.cast_target_group = &"team_red"
		bot.add_to_group("team_blue")
		bot.brawl_team = "blue"
		bot.invulnerable = true
		bot.active = false
		if player_team == "red":
			bot.add_to_group("enemies")
			bot.pk_enemy = true
		else:
			bot.remove_from_group("enemies")
			bot.pk_enemy = false
		parent.add_child(bot)
		bot.set_name_color(Color(0.25, 0.65, 1.0), "[Phe Xanh]")

		var b_data := {
			"id": _combatants.size(),
			"name": bot_prof.display_name,
			"level": bot_prof.level,
			"sect_name": sect.sect_name if sect else "Vô môn phái",
			"is_player": false,
			"team": "blue",
			"kills": 0,
			"deaths": 0,
			"streak": 0,
			"max_streak": 0,
			"score": 0,
			"node": bot,
			"spawn_pos": bot.position,
			"respawn_timer": 0.0,
			"is_dead": false
		}
		_combatants.append(b_data)
		bot.died.connect(_on_bot_died.bind(b_data))

	# Sinh Team Red (Phe Đỏ)
	for i in team_size:
		if player_team == "red" and i == 0:
			continue # Slot 0 là player
		var bot_prof: PlayerProfile = null
		if i < team_b_data.size() and team_b_data[i] is Dictionary and team_b_data[i].has("bot_data"):
			bot_prof = PlayerProfile.from_dict(team_b_data[i]["bot_data"])
		else:
			bot_prof = PkBotProfile.create(p_profile.level if p_profile else 90)

		var sect := SectRegistry.get_by_id(bot_prof.sect_id)
		var bot := PkBot.new()
		bot.is_match_fighter = true
		bot.name = "RedBot_%d" % i
		bot.setup(bot_prof)
		bot.position = spawns_red[i] - Vector2(0, PkBot.FEET_OFFSET)
		bot.cast_target_group = &"team_blue"
		bot.add_to_group("team_red")
		bot.brawl_team = "red"
		bot.invulnerable = true
		bot.active = false
		if player_team == "blue":
			bot.add_to_group("enemies")
			bot.pk_enemy = true
		else:
			bot.remove_from_group("enemies")
			bot.pk_enemy = false
		parent.add_child(bot)
		bot.set_name_color(Color(1.0, 0.35, 0.35), "[Phe Đỏ]")

		var b_data := {
			"id": _combatants.size(),
			"name": bot_prof.display_name,
			"level": bot_prof.level,
			"sect_name": sect.sect_name if sect else "Vô môn phái",
			"is_player": false,
			"team": "red",
			"kills": 0,
			"deaths": 0,
			"streak": 0,
			"max_streak": 0,
			"score": 0,
			"node": bot,
			"spawn_pos": bot.position,
			"respawn_timer": 0.0,
			"is_dead": false
		}
		_combatants.append(b_data)
		bot.died.connect(_on_bot_died.bind(b_data))

func _generate_scattered_spawns(center: Vector2, count: int) -> Array[Vector2]:
	var list: Array[Vector2] = []
	var min_bound := center - Vector2(2000.0, 2000.0)
	var max_bound := center + Vector2(2000.0, 2000.0)
	if VltkWorld.current and VltkWorld.current.map and VltkWorld.current.map.data:
		var rect: Array = VltkWorld.current.map.data.get("rect", [])
		if rect.size() >= 4:
			min_bound = Vector2(float(rect[0]) * 512.0 + 80.0, float(rect[1]) * 512.0 + 80.0)
			max_bound = Vector2((float(rect[2]) + 1.0) * 512.0 - 80.0, (float(rect[3]) + 1.0) * 512.0 - 80.0)
	for i in count:
		var angle := float(i) * TAU / float(count)
		var dist := 180.0 + float(i % 3) * 90.0
		var pos := center + Vector2(cos(angle), sin(angle)) * dist
		pos.x = clampf(pos.x, min_bound.x, max_bound.x)
		pos.y = clampf(pos.y, min_bound.y, max_bound.y)
		if VltkWorld.current:
			if VltkWorld.current.map:
				VltkWorld.current.map.prepare_around(pos)
			pos = VltkWorld.current._open_position_near(pos)
		list.append(pos)
	return list

func _generate_team_spawns(team_center: Vector2, count: int) -> Array[Vector2]:
	var list: Array[Vector2] = []
	var min_bound := team_center - Vector2(2000.0, 2000.0)
	var max_bound := team_center + Vector2(2000.0, 2000.0)
	if VltkWorld.current and VltkWorld.current.map and VltkWorld.current.map.data:
		var rect: Array = VltkWorld.current.map.data.get("rect", [])
		if rect.size() >= 4:
			min_bound = Vector2(float(rect[0]) * 512.0 + 80.0, float(rect[1]) * 512.0 + 80.0)
			max_bound = Vector2((float(rect[2]) + 1.0) * 512.0 - 80.0, (float(rect[3]) + 1.0) * 512.0 - 80.0)
	var spacing := 50.0
	for i in count:
		var y_off := (float(i) - float(count - 1) / 2.0) * spacing
		var pos := team_center + Vector2(0, y_off)
		pos.x = clampf(pos.x, min_bound.x, max_bound.x)
		pos.y = clampf(pos.y, min_bound.y, max_bound.y)
		if VltkWorld.current:
			if VltkWorld.current.map:
				VltkWorld.current.map.prepare_around(pos)
			pos = VltkWorld.current._open_position_near(pos)
		list.append(pos)
	return list

# ---------------------------------------------------------------- Vòng lặp trận đấu
func _process(delta: float) -> void:
	if _leave_in >= 0.0:
		_leave_in -= delta
		if _clock_lbl:
			_clock_lbl.text = "Trở về thành sau %d giây" % ceili(maxf(_leave_in, 0.0))
		if _vs_bar:
			_vs_bar.set_timer("Rời sau %ds" % ceili(maxf(_leave_in, 0.0)))
		if _leave_in <= 0.0:
			_leave_in = -1.0
			_go_home()
		return

	if done:
		return

	match_time += delta
	if not running:
		_prepare_time -= delta
		if _clock_lbl:
			_clock_lbl.text = ""
		if _vs_bar:
			_vs_bar.set_timer("Sắp bắt đầu")
		if _prepare_time <= 0.0:
			_start_fight()
		return

	# Cập nhật đồng hồ trận
	var time_str := "%02d:%02d" % [int(match_time) / 60, int(match_time) % 60]
	if _clock_lbl:
		_clock_lbl.text = time_str
	if _vs_bar:
		_vs_bar.set_timer(time_str)

	# Xử lý hồi sinh các đấu thủ đã tử trận
	for c in _combatants:
		if c.is_dead and c.respawn_timer > 0.0:
			c.respawn_timer -= delta
			if c.respawn_timer <= 0.0:
				_respawn_combatant(c)

	# Điều phối mục tiêu AI cho các Bot
	_retarget_all_bots()

func _start_fight() -> void:
	if running or done:
		return
	running = true
	if _player and "is_invincible" in _player:
		_player.is_invincible = false
	_say("Trận đấu bắt đầu! Mục tiêu: %d mạng!" % target_kills)
	for c in _combatants:
		var node: Node2D = c.node
		if node and is_instance_valid(node) and not c.is_dead:
			if node is PkBot:
				node.invulnerable = false
				node.active = true
	_retarget_all_bots()
	_update_hud()

func _retarget_all_bots() -> void:
	if not running or done:
		return
	for c in _combatants:
		if c.is_player or c.is_dead:
			continue
		var bot: PkBot = c.node as PkBot
		if bot == null or not is_instance_valid(bot) or bot.is_dead():
			continue
		if bot.target == null or not is_instance_valid(bot.target) or (bot.target.has_method("is_dead") and bot.target.is_dead()) or bot.target == bot:
			bot.target = _find_best_target_for(c)

func _find_best_target_for(seeker: Dictionary) -> Node2D:
	var best_target: Node2D = null
	var min_dist_sq := INF
	var seeker_node: Node2D = seeker.node
	if seeker_node == null or not is_instance_valid(seeker_node):
		return null

	for cand in _combatants:
		if cand.id == seeker.id or cand.is_dead:
			continue
		# Nếu là đấu đội: không đánh cùng phe
		if brawl_type == "team" and cand.team == seeker.team:
			continue
		var node: Node2D = cand.node
		if node == null or not is_instance_valid(node) or (node.has_method("is_dead") and node.is_dead()):
			continue
		var dist_sq := seeker_node.global_position.distance_squared_to(node.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_target = node
	return best_target

# ---------------------------------------------------------------- Hạ gục & Hồi sinh
func _on_bot_died(bot: PkBot, victim_data: Dictionary) -> void:
	if done:
		return
	var killer_node: Node = bot.last_attacker
	var killer_data := _find_combatant_by_node(killer_node)
	_handle_kill(killer_data, victim_data)

func _on_player_died() -> void:
	if done:
		return
	var victim_data: Dictionary = _combatants[0]
	var killer_node: Node = _player.get("last_attacker") as Node if "last_attacker" in _player else null
	var killer_data := _find_combatant_by_node(killer_node)
	_handle_kill(killer_data, victim_data)

func _find_combatant_by_node(node: Node) -> Dictionary:
	if node != null and is_instance_valid(node):
		for c in _combatants:
			if c.node == node:
				return c
	# Nếu không rõ kẻ đánh cuối: ngẫu nhiên 1 đối thủ còn sống
	var candidates: Array[Dictionary] = []
	for c in _combatants:
		if not c.is_dead and (brawl_type == "solo" or c.team != "blue"):
			candidates.append(c)
	return candidates.pick_random() if not candidates.is_empty() else {}

func _handle_kill(killer: Dictionary, victim: Dictionary) -> void:
	victim.deaths += 1
	victim.streak = 0
	victim.score = maxi(0, int(victim.get("score", 0)) - 100)
	victim.is_dead = true
	victim.respawn_timer = RESPAWN_SEC

	var killer_name := "Bí Ẩn"
	var victim_name := str(victim.get("name", "Đối Thủ"))

	if not killer.is_empty():
		killer.kills += 1
		killer.streak += 1
		killer.max_streak = maxi(killer.max_streak, killer.streak)
		killer.score = maxi(0, int(killer.get("score", 0)) + 300)
		killer_name = str(killer.get("name", "Bí Ẩn"))

		if brawl_type == "team" and _team_kills.has(killer.team):
			_team_kills[killer.team] += 1

		# Thông báo liên trảm đặc biệt
		if killer.streak >= 3:
			var streak_title := "Tam Liên Trảm" if killer.streak == 3 else ("Ngũ Liên Trảm" if killer.streak == 5 else ("Bách Bộ Xuyên Dương (%d mạng)" % killer.streak))
			_show_marquee("%s đạt chuỗi [%s]!" % [killer_name, streak_title])

	_add_kill_feed(killer_name, victim_name)
	_update_hud()
	_check_win_condition()

func _add_kill_feed(killer_name: String, victim_name: String) -> void:
	if _kill_feed_box == null:
		return
	var lbl := Label.new()
	lbl.text = "⚔ %s hạ gục %s (+300đ)" % [killer_name, victim_name]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	_kill_feed_box.add_child(lbl)
	# Tự động xoá sau 3 giây
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

func _respawn_combatant(c: Dictionary) -> void:
	c.is_dead = false
	c.respawn_timer = 0.0
	var node: Node2D = c.node
	if node == null or not is_instance_valid(node):
		return

	# Tìm vị trí hồi sinh an toàn
	var spawn_pos: Vector2 = c.spawn_pos
	if brawl_type == "solo" and VltkWorld.current:
		var center := VltkWorld.current._default_center()
		var rand_angle := randf() * TAU
		var rand_dist := randf_range(200, 450)
		var p := center + Vector2(cos(rand_angle), sin(rand_angle)) * rand_dist
		if VltkWorld.current.map:
			VltkWorld.current.map.prepare_around(p)
		spawn_pos = VltkWorld.current._open_position_near(p)

	if c.is_player and node.has_method("respawn_at"):
		node.respawn_at(spawn_pos)
		if VltkWorld.current:
			VltkWorld.current.respawn_point = spawn_pos
			if VltkWorld.current.map is VltkWorld.SortedMap:
				(VltkWorld.current.map as VltkWorld.SortedMap).warm_up(node.global_position)
		_say("Bạn đã hồi sinh! Tiếp tục chiến đấu!")
	elif node is PkBot and node.has_method("respawn_at"):
		node.respawn_at(spawn_pos)

	_update_hud()

# ---------------------------------------------------------------- Kiểm tra Thắng/Thua
func _check_win_condition() -> void:
	if done:
		return

	if brawl_type == "solo":
		var leader := _get_leader()
		if leader.kills >= target_kills:
			_finish_match(leader.is_player, "Đấu thủ [%s] đã đạt mốc %d mạng hạ gục!" % [leader.name, target_kills])
	else:
		if _team_kills["blue"] >= target_kills:
			var won := my_side == "song"
			_finish_match(won, "Phe Xanh đã đạt mốc %d mạng hạ gục!" % target_kills)
		elif _team_kills["red"] >= target_kills:
			var won := my_side == "jin"
			_finish_match(won, "Phe Đỏ đã đạt mốc %d mạng hạ gục!" % target_kills)

func _get_leader() -> Dictionary:
	var sorted: Array = _combatants.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.kills != b.kills:
			return a.kills > b.kills
		return a.score > b.score
	)
	return sorted[0] if not sorted.is_empty() else _combatants[0]

func _finish_match(player_won: bool, reason: String) -> void:
	if done:
		return
	done = true
	running = false

	# Ngừng các bot
	for c in _combatants:
		var node: Node2D = c.node
		if node and is_instance_valid(node):
			if node is PkBot:
				node.active = false
				node.invulnerable = true

	# Tính điểm & EXP thực tế
	var p_data: Dictionary = _combatants[0]
	var p_score: int = int(p_data.get("score", 0))
	var exp_gained: int = maxi(0, p_score * 30)

	# Cộng vào EXP thực tế nhân vật
	if GameManager.local_profile and exp_gained > 0:
		GameManager.local_profile.add_exp(exp_gained)
		SaveManager.save_profile(GameManager.local_profile)

	_show_finish_popup(player_won, reason, exp_gained, p_data)
	_leave_in = LEAVE_AFTER_SEC

# ---------------------------------------------------------------- HUD & Giao diện
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 25
	add_child(_hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)

	# 1. Bảng điểm trung tâm trên đỉnh màn hình: Banner tỷ số VS (căn giữa)
	_vs_bar = VsScoreBar.new()
	_vs_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_vs_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_vs_bar.offset_left = -230.0
	_vs_bar.offset_right = 230.0
	_vs_bar.offset_top = 48.0
	_vs_bar.offset_bottom = 112.0
	if brawl_type == "solo":
		_vs_bar.set_sides("Bạn", 0, 0, "Đối Thủ")
	else:
		_vs_bar.set_sides("Phe Xanh", 0, 0, "Phe Đỏ")
	root.add_child(_vs_bar)

	# 2. Kill Feed bên trái màn hình
	_kill_feed_box = VBoxContainer.new()
	_kill_feed_box.position = Vector2(16, 120)
	_kill_feed_box.custom_minimum_size = Vector2(240, 160)
	_kill_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_feed_box.add_theme_constant_override("separation", 4)
	root.add_child(_kill_feed_box)

	# 3. Dải thông báo Marquee giữa màn hình
	_marquee_lbl = _create_hud_label("", 16, Color(1.0, 0.8, 0.2))
	_marquee_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_marquee_lbl.position = Vector2(-300, 156)
	_marquee_lbl.custom_minimum_size = Vector2(600, 26)
	_marquee_lbl.visible = false
	root.add_child(_marquee_lbl)

	# 4. Các nút chức năng trận đấu — đặt trên chỗ để bình bơm máu (QuickItemBar)
	var btn_row := HBoxContainer.new()
	btn_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bottom_margin := QuickItemBar.TOP_OFFSET + 8.0
	var right_margin := QuickItemBar.RIGHT
	var btn_height := 32.0
	var btn_width := 123.0

	btn_row.offset_right = -right_margin
	btn_row.offset_left = -right_margin - (btn_width * 2 + 8)
	btn_row.offset_bottom = -bottom_margin
	btn_row.offset_top = -bottom_margin - btn_height
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)

	_btn_scoreboard = GameUi.button("BXH (Tab)")
	_btn_scoreboard.custom_minimum_size = Vector2(btn_width, btn_height)
	_btn_scoreboard.add_theme_font_size_override("font_size", 13)
	_btn_scoreboard.tooltip_text = "Xem bảng xếp hạng trận đấu (phím Tab)"
	_btn_scoreboard.pressed.connect(_toggle_scoreboard)
	btn_row.add_child(_btn_scoreboard)

	_btn_leave = GameUi.button("Rời trận")
	_btn_leave.custom_minimum_size = Vector2(btn_width, btn_height)
	_btn_leave.add_theme_font_size_override("font_size", 13)
	_btn_leave.tooltip_text = "Rời khỏi trận đấu về thành"
	_btn_leave.pressed.connect(_on_leave_clicked)
	btn_row.add_child(_btn_leave)

	# 5. Dựng trước Scoreboard modal
	_build_scoreboard_modal(root)

func _create_hud_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _update_hud() -> void:
	if brawl_type == "solo":
		var leader := _get_leader()
		var p_data: Dictionary = _combatants[0] if not _combatants.is_empty() else {}
		var p_kills: int = int(p_data.get("kills", 0))

		if _vs_bar:
			_vs_bar.set_left("Bạn", p_kills)
			_vs_bar.set_right(leader.name, leader.kills)
	else:
		var blue_k: int = int(_team_kills.get("blue", 0))
		var red_k: int = int(_team_kills.get("red", 0))
		if _vs_bar:
			_vs_bar.set_left("Phe Xanh", blue_k)
			_vs_bar.set_right("Phe Đỏ", red_k)

	if _scoreboard_modal and _scoreboard_modal.visible:
		_refresh_scoreboard_table()

	if _scoreboard_modal and _scoreboard_modal.visible:
		_refresh_scoreboard_table()

func _show_marquee(text: String) -> void:
	if _marquee_lbl == null:
		return
	_marquee_lbl.text = text
	_marquee_lbl.visible = true
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if is_instance_valid(_marquee_lbl):
			_marquee_lbl.visible = false
	)

# ---------------------------------------------------------------- Bảng Xếp Hạng (Scoreboard)
func _build_scoreboard_modal(parent: Control) -> void:
	_scoreboard_modal = Control.new()
	_scoreboard_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scoreboard_modal.visible = false
	parent.add_child(_scoreboard_modal)

	# Nền tối mờ
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_scoreboard_modal.visible = false
	)
	_scoreboard_modal.add_child(overlay)

	# Khung bảng điểm
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-360, -230)
	frame.custom_minimum_size = Vector2(720, 460)
	_scoreboard_modal.add_child(frame)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16, 0.96)
	sb.border_color = Color(0.85, 0.7, 0.25, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", sb)

	var modal_vbox := VBoxContainer.new()
	modal_vbox.add_theme_constant_override("separation", 10)
	frame.add_child(modal_vbox)

	var header_lbl := _create_hud_label("BẢNG XẾP HẠNG CHIẾN TÍCH - LỘN XỘN", 18, Color(1.0, 0.85, 0.3))
	modal_vbox.add_child(header_lbl)

	var sub_lbl := _create_hud_label("Bản đồ: %s  ·  Mục tiêu: %d mạng  ·  Hạ gục: +300 điểm / Bị diệt: -100 điểm" % [
		PkRules.get_brawl_map_info(map_id).name, target_kills
	], 12, Color(0.7, 0.75, 0.85))
	modal_vbox.add_child(sub_lbl)

	# Tiêu đề các cột
	var col_header := HBoxContainer.new()
	col_header.add_theme_constant_override("separation", 8)
	modal_vbox.add_child(col_header)

	var headers: Array[Array] = [
		["Hạng", 50, HORIZONTAL_ALIGNMENT_CENTER],
		["Nhân vật", 200, HORIZONTAL_ALIGNMENT_LEFT],
		["Cấp", 50, HORIZONTAL_ALIGNMENT_CENTER],
		["Hạ gục", 70, HORIZONTAL_ALIGNMENT_CENTER],
		["Bị diệt", 70, HORIZONTAL_ALIGNMENT_CENTER],
		["Liên trảm", 80, HORIZONTAL_ALIGNMENT_CENTER],
		["Điểm", 80, HORIZONTAL_ALIGNMENT_CENTER]
	]
	for h in headers:
		var l := Label.new()
		l.text = h[0]
		l.custom_minimum_size.x = h[1]
		l.horizontal_alignment = h[2]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		col_header.add_child(l)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_vbox.add_child(scroll)

	_scoreboard_list = VBoxContainer.new()
	_scoreboard_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scoreboard_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_scoreboard_list)

	var btn_close := GameUi.button("Đóng (Phím Tab)")
	btn_close.custom_minimum_size = Vector2(160, 36)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(func() -> void: _scoreboard_modal.visible = false)
	modal_vbox.add_child(btn_close)

func _toggle_scoreboard() -> void:
	if _scoreboard_modal:
		_scoreboard_modal.visible = not _scoreboard_modal.visible
		if _scoreboard_modal.visible:
			_refresh_scoreboard_table()

func _refresh_scoreboard_table() -> void:
	if _scoreboard_list == null:
		return
	for c in _scoreboard_list.get_children():
		c.queue_free()

	# Sắp xếp theo Điểm giảm dần, sau đó theo Kills
	var sorted: Array = _combatants.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score:
			return a.score > b.score
		return a.kills > b.kills
	)

	for rank in sorted.size():
		var data: Dictionary = sorted[rank]
		var row := PanelContainer.new()
		var row_sb := StyleBoxFlat.new()
		if data.is_player:
			row_sb.bg_color = Color(0.25, 0.2, 0.08, 0.85)
			row_sb.border_color = Color(1.0, 0.8, 0.2, 0.9)
			row_sb.set_border_width_all(1)
		else:
			row_sb.bg_color = Color(0.12, 0.14, 0.18, 0.6) if rank % 2 == 0 else Color(0.09, 0.1, 0.13, 0.6)
		row_sb.set_corner_radius_all(4)
		row.add_theme_stylebox_override("panel", row_sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		# 1. Hạng
		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % (rank + 1)
		rank_lbl.custom_minimum_size.x = 50
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if rank < 3 else Color.WHITE)
		hbox.add_child(rank_lbl)

		# 2. Tên + Phái / Phe
		var name_box := HBoxContainer.new()
		name_box.custom_minimum_size.x = 200
		var team_prefix := ""
		var team_color := Color.WHITE
		if brawl_type == "team":
			if data.team == "blue":
				team_prefix = "[Xanh] "
				team_color = Color(0.3, 0.7, 1.0)
			else:
				team_prefix = "[Đỏ] "
				team_color = Color(1.0, 0.4, 0.4)
		var name_lbl := Label.new()
		name_lbl.text = "%s%s (%s)" % [team_prefix, data.name, data.sect_name]
		name_lbl.clip_text = true
		name_lbl.add_theme_color_override("font_color", team_color if brawl_type == "team" else (Color(1.0, 0.85, 0.3) if data.is_player else Color.WHITE))
		name_box.add_child(name_lbl)
		hbox.add_child(name_box)

		# 3. Cấp
		var lv_lbl := Label.new()
		lv_lbl.text = str(data.level)
		lv_lbl.custom_minimum_size.x = 50
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(lv_lbl)

		# 4. Kills
		var k_lbl := Label.new()
		k_lbl.text = str(data.kills)
		k_lbl.custom_minimum_size.x = 70
		k_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		hbox.add_child(k_lbl)

		# 5. Deaths
		var d_lbl := Label.new()
		d_lbl.text = str(data.deaths)
		d_lbl.custom_minimum_size.x = 70
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		hbox.add_child(d_lbl)

		# 6. Liên trảm
		var s_lbl := Label.new()
		s_lbl.text = str(data.streak)
		s_lbl.custom_minimum_size.x = 80
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		hbox.add_child(s_lbl)

		# 7. Điểm
		var score_lbl := Label.new()
		score_lbl.text = str(data.score)
		score_lbl.custom_minimum_size.x = 80
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		hbox.add_child(score_lbl)

		_scoreboard_list.add_child(row)

# ---------------------------------------------------------------- Bảng Kết Thúc & Trao Thưởng
func _show_finish_popup(player_won: bool, reason: String, exp_gained: int, p_data: Dictionary) -> void:
	_finish_popup = PanelContainer.new()
	_finish_popup.set_anchors_preset(Control.PRESET_CENTER)
	_finish_popup.position = Vector2(-250, -180)
	_finish_popup.custom_minimum_size = Vector2(500, 360)
	_hud.add_child(_finish_popup)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.97)
	sb.border_color = Color(1.0, 0.8, 0.2) if player_won else Color(0.8, 0.3, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	_finish_popup.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_finish_popup.add_child(vbox)

	var title_lbl := _create_hud_label("CHIẾN THẮNG!" if player_won else "KẾT THÚC TRẬN ĐẤU", 26,
			Color(1.0, 0.85, 0.2) if player_won else Color(1.0, 0.4, 0.4))
	vbox.add_child(title_lbl)

	var reason_lbl := _create_hud_label(reason, 14, Color(0.8, 0.85, 0.95))
	reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(reason_lbl)

	# Bảng chi tiết điểm
	var stats_frame := PanelContainer.new()
	var stats_sb := StyleBoxFlat.new()
	stats_sb.bg_color = Color(0.14, 0.16, 0.22, 0.8)
	stats_sb.set_corner_radius_all(6)
	stats_frame.add_theme_stylebox_override("panel", stats_sb)
	vbox.add_child(stats_frame)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_frame.add_child(stats_vbox)

	stats_vbox.add_child(_create_hud_label("Số mạng hạ gục: %d   ·   Số lần tử trận: %d" % [
		int(p_data.get("kills", 0)), int(p_data.get("deaths", 0))
	], 13, Color.WHITE))

	stats_vbox.add_child(_create_hud_label("Liên trảm tối đa: %d   ·   Điểm chiến tích: %d" % [
		int(p_data.get("max_streak", 0)), int(p_data.get("score", 0))
	], 13, Color(1.0, 0.85, 0.4)))

	stats_vbox.add_child(_create_hud_label("EXP THỰC TẾ NHẬN ĐƯỢC: +%d EXP (Điểm x 30)" % exp_gained, 16, Color(0.3, 1.0, 0.4)))

	if GameManager.local_profile:
		stats_vbox.add_child(_create_hud_label("Nhân vật hiện tại: Cấp %d (%d / %d EXP)" % [
			GameManager.local_profile.level,
			GameManager.local_profile.current_exp,
			GameManager.local_profile.get_exp_to_next_level()
		], 12, Color(0.7, 0.8, 0.9)))

	var btn_leave := GameUi.button("Rời về thành ngay")
	btn_leave.custom_minimum_size = Vector2(180, 40)
	btn_leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_leave.pressed.connect(_go_home)
	vbox.add_child(btn_leave)

func _on_leave_clicked() -> void:
	SocialWindow.confirm(self, "Rời trận", "Bạn có chắc chắn muốn rời trận Đấu Lộn Xộn không?", func() -> void:
		_finish_match(false, "Người chơi tự rời trận đấu.")
		_go_home()
	)

func _go_home() -> void:
	GameManager.field_map = {}
	GameManager.is_game_over = false
	get_tree().change_scene_to_file(HUB_SCENE)

func _say(text: String) -> void:
	if _player and _player.has_method("notify"):
		_player.notify(text)
	ChatBox.push_system("[color=#ffd700][Lộn Xộn][/color] %s" % text)
