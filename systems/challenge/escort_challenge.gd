extends Node
class_name EscortChallenge
## ẢI HỘ TỐNG TIÊU XA THỰC ĐỊA TRÊN ĐẠI BẢN ĐỒ BIỆN KINH NGOẠI THÀNH (MAP 37).
##   - Tuyến đường quan lộ chạy hoàn toàn NGOÀI THÀNH (dọc bờ hào, bìa rừng, nam quan ra đông môn).
##   - Xe tiêu tự tìm đường né toàn bộ vật cản (nhà, cây, tường, hào nước) bằng A*.
##   - Hiển thị đường đứt khúc tìm đường trực tiếp ngoài màn hình (in-world) và trên MiniMap.
##   - Dọn sạch toàn bộ NPC dân làng/quái rác trên map, chỉ giữ lại tiêu xa, người chơi và sơn tặc.
##   - Bảng UI thông tin đỉnh màn hình được thiết kế lại đẹp mắt, gọn gàng, đậm chất kiếm hiệp.

signal finished(success: bool)

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const CountdownOverlay = preload("res://ui/common/countdown_overlay.gd")

const MAP_ID := 37
const MAP_DIR := "res://world/maps/map_37"
const MAP_NAME := "Biện Kinh (Ngoại Thành)"

## Lộ trình chuẩn các mốc quan lộ chạy ngoài thành Biện Kinh (~48.000px, 85 mốc bám sát địa hình)
const WAYPOINTS: Array[Vector2] = [
	Vector2(36320.0, 51424.0),
	Vector2(36608.0, 51392.0),
	Vector2(37600.0, 51312.0),
	Vector2(38144.0, 51328.0),
	Vector2(38144.0, 50800.0),
	Vector2(38144.0, 50304.0),
	Vector2(38304.0, 49888.0),
	Vector2(38688.0, 49808.0),
	Vector2(39136.0, 49776.0),
	Vector2(39776.0, 49360.0),
	Vector2(40224.0, 49296.0),
	Vector2(41216.0, 49248.0),
	Vector2(41728.0, 49264.0),
	Vector2(42240.0, 49776.0),
	Vector2(42720.0, 49792.0),
	Vector2(43264.0, 49808.0),
	Vector2(43744.0, 50288.0),
	Vector2(43904.0, 50800.0),
	Vector2(44256.0, 50800.0),
	Vector2(44288.0, 51312.0),
	Vector2(44640.0, 51312.0),
	Vector2(44736.0, 51856.0),
	Vector2(45216.0, 51904.0),
	Vector2(44768.0, 52352.0),
	Vector2(45248.0, 52416.0),
	Vector2(45920.0, 52816.0),
	Vector2(46304.0, 52864.0),
	Vector2(46848.0, 53360.0),
	Vector2(47360.0, 53360.0),
	Vector2(47360.0, 53872.0),
	Vector2(47392.0, 54368.0),
	Vector2(47264.0, 54432.0),
	Vector2(47872.0, 54896.0),
	Vector2(48384.0, 54896.0),
	Vector2(48832.0, 55392.0),
	Vector2(48864.0, 55952.0),
	Vector2(49920.0, 55920.0),
	Vector2(50208.0, 55808.0),
	Vector2(50368.0, 55376.0),
	Vector2(50752.0, 55408.0),
	Vector2(52000.0, 55328.0),
	Vector2(52480.0, 55376.0),
	Vector2(52992.0, 55408.0),
	Vector2(53600.0, 55024.0),
	Vector2(54016.0, 55008.0),
	Vector2(54496.0, 54912.0),
	Vector2(55552.0, 54896.0),
	Vector2(56000.0, 54912.0),
	Vector2(56160.0, 54496.0),
	Vector2(56576.0, 54400.0),
	Vector2(57568.0, 54336.0),
	Vector2(58144.0, 54416.0),
	Vector2(58752.0, 53984.0),
	Vector2(58592.0, 53968.0),
	Vector2(59168.0, 53872.0),
	Vector2(59584.0, 53856.0),
	Vector2(59680.0, 53408.0),
	Vector2(60256.0, 52880.0),
	Vector2(60576.0, 52864.0),
	Vector2(61152.0, 52816.0),
	Vector2(61216.0, 52368.0),
	Vector2(61344.0, 51872.0),
	Vector2(61632.0, 51808.0),
	Vector2(62144.0, 51824.0),
	Vector2(62752.0, 51392.0),
	Vector2(63200.0, 51312.0),
	Vector2(63200.0, 50800.0),
	Vector2(63232.0, 50384.0),
	Vector2(63392.0, 49904.0),
	Vector2(63776.0, 49824.0),
	Vector2(64384.0, 49328.0),
	Vector2(64736.0, 49312.0),
	Vector2(65248.0, 48752.0),
	Vector2(65280.0, 48304.0),
	Vector2(65792.0, 48256.0),
	Vector2(66272.0, 48224.0),
	Vector2(67296.0, 48192.0),
	Vector2(67808.0, 48240.0),
	Vector2(68352.0, 48208.0),
	Vector2(68896.0, 47808.0),
	Vector2(69376.0, 47776.0),
	Vector2(69856.0, 47712.0),
	Vector2(70912.0, 47680.0),
	Vector2(71232.0, 47648.0),
	Vector2(71296.0, 47296.0)
]

## Danh sách ID quái phục kích VLTK gốc
const MONSTER_SON_TAC_LIST: Array[int] = [163, 164, 165, 166, 167, 168, 169] ## Sơn tặc 01..07
const MONSTER_SON_TAC := 163         ## Sơn tặc mặc định
const MONSTER_DAU_LINH := 141        ## Sơn tặc đầu lĩnh
const MONSTER_DAU_MUC := 1856        ## Sơn tặc đầu mục
const MONSTER_THAN_BI := 1049        ## Thần bí sơn tặc
const MONSTER_TRAI_CHU := 1054       ## Sơn tặc trại chủ
const MONSTER_SON_TAC_VUONG := 1055  ## Sơn tặc vương

const EscortCartScript = preload("res://systems/challenge/escort_cart.gd")
const EscortManagerScript = preload("res://systems/challenge/escort_manager.gd")

var cart_data: Dictionary = {}
var cart_node: CharacterBody2D
var player_role: String = "defender" ## "defender" hoặc "raider"
var _raider_damage: Dictionary = {}  ## Ghi nhận sát thương cướp tiêu của từng người
var _team_bots: Array[CharacterBody2D] = []
var is_finished: bool = false
var _wave_triggered: Dictionary = {}
var _current_wave: int = 0
var _bandits: Array[VltkMonster] = []

# Node vẽ đường đứt khúc ngoài thực địa
var _route_line_node: Node2D

# HUD elements
var _hud: CanvasLayer
var _title_lbl: Label
var _role_lbl: Label
var _cart_hp_bar: ProgressBar
var _hp_text: Label
var _progress_bar: ProgressBar
var _prog_text: Label
var _status_lbl: Label
var _alert_box: PanelContainer
var _alert_lbl: Label
var _leave_timer: float = -1.0

## Tính toán vị trí và waypoint kế tiếp theo % tiến độ
static func get_progress_pos_and_idx(wps: Array[Vector2], prog_pct: float) -> Dictionary:
	if wps.is_empty():
		return {"pos": Vector2.ZERO, "idx": 0}
	if wps.size() == 1 or prog_pct <= 0.0:
		return {"pos": wps[0], "idx": 1}
	if prog_pct >= 95.0:
		return {"pos": wps[-1], "idx": wps.size() - 1}

	var total_len := 0.0
	var lens: Array[float] = []
	for i in range(wps.size() - 1):
		var d := wps[i].distance_to(wps[i + 1])
		lens.append(d)
		total_len += d

	var target_d := total_len * (prog_pct / 100.0)
	var accum := 0.0
	for i in range(lens.size()):
		var l := lens[i]
		if accum + l >= target_d:
			var remain := target_d - accum
			var t := (remain / l) if l > 0.0 else 0.0
			var p := wps[i].lerp(wps[i + 1], t)
			var next_idx: int = i + 1
			if t >= 0.99:
				next_idx = mini(i + 2, wps.size() - 1)
			return {"pos": p, "idx": next_idx}
		accum += l

	return {"pos": wps[-1], "idx": wps.size() - 1}

static func map_entry(cart: Dictionary, role: String = "defender") -> Dictionary:
	var prog_pct: float = float(cart.get("progress_pct", 0.0))
	var now := int(Time.get_unix_time_from_system())
	var start_unix := int(cart.get("start_unix", now))
	var dur := int(cart.get("duration_sec", 600))
	if dur > 0 and now > start_unix:
		var time_pct := (float(now - start_unix) / float(dur)) * 100.0
		prog_pct = clampf(maxf(prog_pct, time_pct), 0.0, 95.0)

	var pos_info := get_progress_pos_and_idx(WAYPOINTS, prog_pct)
	var start_pos: Vector2 = pos_info.get("pos", WAYPOINTS[0])
	var center_pos := start_pos
	if role == "raider":
		center_pos = WAYPOINTS[WAYPOINTS.size() - 1]

	return {
		"id": MAP_ID,
		"name": "Biện Kinh Ngoại Thành - Hộ Tống Tiêu Xa",
		"dir": MAP_DIR,
		"level": 50,
		"escort_field": true,
		"cart_data": cart,
		"player_role": role,
		"arena_center": center_pos
	}

func _ready() -> void:
	cart_data = GameManager.field_map.get("cart_data", {})
	player_role = str(GameManager.field_map.get("player_role", "defender"))
	_build_hud()
	_clear_ambient_npcs()
	_spawn_cart.call_deferred()

func _clear_ambient_npcs() -> void:
	# Bỏ hết các NPC dân làng và quái rác có sẵn trên map
	for node in get_tree().get_nodes_in_group("npc_actor"):
		if is_instance_valid(node):
			node.queue_free()
	for mon in get_tree().get_nodes_in_group("monster"):
		if is_instance_valid(mon) and not _bandits.has(mon):
			mon.queue_free()

	# Chặn việc sinh thêm NPC từ các chunk nạp ngầm
	if VltkWorld.current != null and VltkWorld.current.map != null:
		VltkWorld.current.map.npc_spawned.connect(func(node: Node2D, _d: Dictionary) -> void:
			if is_instance_valid(node):
				node.queue_free()
		)

func _spawn_cart() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null:
		await get_tree().process_frame
		parent = VltkWorld.entity_parent()
	if parent == null:
		return

	# Dọn dẹp lại lần nữa sau khi map nạp xong
	_clear_ambient_npcs()

	# Tính toán tiến trình hiện tại để khôi phục vị trí xe chính xác
	var prog_pct: float = float(cart_data.get("progress_pct", 0.0))
	var now := int(Time.get_unix_time_from_system())
	var start_unix := int(cart_data.get("start_unix", now))
	var dur := int(cart_data.get("duration_sec", 600))
	if dur > 0 and now > start_unix:
		var time_pct := (float(now - start_unix) / float(dur)) * 100.0
		prog_pct = clampf(maxf(prog_pct, time_pct), 0.0, 95.0)

	var pos_info := get_progress_pos_and_idx(WAYPOINTS, prog_pct)
	var start_pos: Vector2 = pos_info.get("pos", WAYPOINTS[0])
	var start_idx: int = int(pos_info.get("idx", 1))

	if prog_pct >= 15.0:
		_wave_triggered[1] = true
	if prog_pct >= 30.0:
		_wave_triggered[2] = true
	if prog_pct >= 45.0:
		_wave_triggered[3] = true
	if prog_pct >= 60.0:
		_wave_triggered[4] = true
	if prog_pct >= 75.0:
		_wave_triggered[5] = true
	if prog_pct >= 90.0:
		_wave_triggered[6] = true

	# Tạo Tiêu Xa (Tự động né vật cản theo A*)
	cart_node = EscortCartScript.new()
	cart_node.setup(cart_data, WAYPOINTS, start_idx, int(prog_pct))
	cart_node.position = start_pos
	cart_node.arrived.connect(_on_cart_arrived)
	cart_node.destroyed.connect(_on_cart_destroyed)
	cart_node.hp_changed.connect(_on_cart_hp_changed)
	cart_node.damaged_by.connect(_on_cart_damaged_by)
	parent.add_child(cart_node)

	# Node vẽ đường đứt khúc tìm đường ngoài màn hình (in-world)
	_route_line_node = Node2D.new()
	_route_line_node.z_index = -1 # Nằm sát mặt đất dưới chân xe và quái
	_route_line_node.draw.connect(_draw_in_world_route)
	parent.add_child(_route_line_node)

	# Định vị người chơi theo Phe:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		if "is_invincible" in player:
			player.is_invincible = true
		if player_role == "raider":
			# Phe Cướp Tiêu xuất hiện ở tọa độ KẾT THÚC vận tiêu để chặn đầu
			var end_pos: Vector2 = WAYPOINTS[WAYPOINTS.size() - 1]
			player.position = end_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			player.add_to_group("team_raider")
			player.remove_from_group("team_defender")
			cart_node.add_to_group("enemies")
			cart_node.remove_from_group("allies")
			ChatBox.push_system("⚔️ BẠN ĐÃ VÀO PHE CƯỚP TIÊU! Xuất hiện ở cổng đích để chặn đầu và đánh vỡ tiêu xa!")
		else:
			# Phe Hộ Tiêu xuất hiện ở ngay cạnh xe tiêu
			player.position = start_pos + Vector2(-50, 20)
			player.add_to_group("team_defender")
			player.remove_from_group("team_raider")
			cart_node.add_to_group("allies")
			cart_node.remove_from_group("enemies")
			ChatBox.push_system("🛡️ BẠN ĐÃ VÀO PHE HỘ TIÊU! Xuất hiện cạnh tiêu xa để bảo vệ hàng hóa cập bến!")

	_spawn_team_participants(parent, start_pos)
	_update_hud()

	# Đếm ngược 3 giây trước khi bắt đầu chiến đấu
	CountdownOverlay.start(self, func() -> void:
		if player and is_instance_valid(player) and "is_invincible" in player:
			player.is_invincible = false
		for b in _team_bots:
			if is_instance_valid(b) and b is PkBot:
				b.invulnerable = false
				b.active = true
	)

func _spawn_team_participants(parent: Node2D, cart_pos: Vector2) -> void:
	# Chế độ Online: Tuyệt đối không sinh bot tham gia
	if not GameModeManager.allows_bot():
		return
	var defs: Array = cart_data.get("defenders", [])
	var raiders: Array = cart_data.get("raiders", [])
	var end_pos: Vector2 = WAYPOINTS[WAYPOINTS.size() - 1]
	var my_name := GameManager.local_profile.display_name if GameManager.local_profile else ""

	# Đồng đội hộ tiêu
	for d_name in defs:
		if str(d_name) == my_name:
			continue
		var b_pos := cart_pos + Vector2(randf_range(-60, 60), randf_range(-40, 40))
		_spawn_participant_bot(parent, str(d_name), "defender", b_pos)

	# Đối thủ cướp tiêu (xuất hiện tại tọa độ kết thúc để đón đầu)
	for r_name in raiders:
		if str(r_name) == my_name:
			continue
		var r_pos := end_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		_spawn_participant_bot(parent, str(r_name), "raider", r_pos)

func _spawn_participant_bot(parent: Node2D, bot_name: String, team: String, spawn_pos: Vector2) -> void:
	var prof := PkBotProfile.create(55)
	prof.display_name = bot_name
	var bot := PkBot.new()
	bot.setup(prof)
	bot.position = spawn_pos
	bot.brawl_team = team
	bot.invulnerable = true
	bot.active = false
	if team == "defender":
		bot.add_to_group("team_defender")
		bot.cast_target_group = &"team_raider"
		bot.set_name_color(Color(0.25, 0.70, 1.0), "[Phe Xanh - Hộ Tiêu]")
		if player_role == "raider":
			bot.add_to_group("enemies")
			bot.pk_enemy = true
		else:
			bot.remove_from_group("enemies")
			bot.pk_enemy = false
	else:
		bot.add_to_group("team_raider")
		bot.cast_target_group = &"team_defender"
		bot.set_name_color(Color(1.0, 0.35, 0.35), "[Phe Đỏ - Cướp Tiêu]")
		if player_role == "defender":
			bot.add_to_group("enemies")
			bot.pk_enemy = true
		else:
			bot.remove_from_group("enemies")
			bot.pk_enemy = false
	parent.add_child(bot)
	_team_bots.append(bot)

func _on_cart_damaged_by(source: Node, amount: int) -> void:
	if source == null:
		return
	var src_name := ""
	if source.is_in_group("player"):
		src_name = GameManager.local_profile.display_name if GameManager.local_profile else "Player"
	elif source.has_method("get") and source.get("display_name") != null:
		src_name = str(source.get("display_name"))
	elif source.name != "":
		src_name = source.name

	if src_name != "":
		_raider_damage[src_name] = int(_raider_damage.get(src_name, 0)) + amount

func _process(delta: float) -> void:
	if is_finished:
		if _leave_timer > 0.0:
			_leave_timer -= delta
			if _leave_timer <= 0.0:
				_return_to_hub()
		return

	if cart_node == null or not is_instance_valid(cart_node):
		return

	_update_hud()
	_check_ambush_triggers()
	_update_bandits_ai(delta)
	_update_team_bots_ai(delta)

	if _route_line_node != null and is_instance_valid(_route_line_node):
		_route_line_node.queue_redraw()

func _update_team_bots_ai(_delta: float) -> void:
	if cart_node == null or not is_instance_valid(cart_node):
		return
	for b in _team_bots:
		if is_instance_valid(b) and not b.is_dead():
			var d_cart := b.global_position.distance_to(cart_node.global_position)
			if b.brawl_team == "raider":
				if d_cart > 160.0:
					var dir := (cart_node.global_position - b.global_position).normalized()
					b.velocity = dir * 120.0
					b.move_and_slide()
				elif d_cart < 80.0 and randf() < 0.04:
					cart_node.take_damage_from(b, randi_range(250, 450))
			elif b.brawl_team == "defender":
				if d_cart > 120.0:
					var dir := (cart_node.global_position - b.global_position).normalized()
					b.velocity = dir * 100.0
					b.move_and_slide()

	if _route_line_node != null and is_instance_valid(_route_line_node):
		_route_line_node.queue_redraw()

## Vẽ đường đứt khúc tìm đường trực tiếp ngoài màn hình (in-world ground line)
func _draw_in_world_route() -> void:
	if cart_node == null or not is_instance_valid(cart_node):
		return

	var pts: Array[Vector2] = [cart_node.global_position]
	var cur_w_idx: int = int(cart_node.get("current_waypoint_idx"))

	# Lấy thêm các mốc A* trung gian nếu có
	var sub_pts: PackedVector2Array = cart_node.get("_sub_path") if cart_node.get("_sub_path") != null else PackedVector2Array()
	var sub_idx: int = int(cart_node.get("_sub_idx"))
	if not sub_pts.is_empty():
		for k in range(sub_idx, sub_pts.size()):
			pts.append(sub_pts[k])

	for idx in range(cur_w_idx, WAYPOINTS.size()):
		pts.append(WAYPOINTS[idx])

	if pts.size() < 2:
		return

	var col_glow := Color(0.1, 0.75, 1.0, 0.35)
	var col_line := Color(0.3, 0.95, 1.0, 0.85)
	var col_dot := Color(1.0, 0.9, 0.25, 0.9)

	for i in range(pts.size() - 1):
		var p1 := pts[i]
		var p2 := pts[i + 1]
		if p1.distance_squared_to(p2) > 4.0:
			# Đường đứt khúc viền sáng
			_route_line_node.draw_dashed_line(p1, p2, col_glow, 6.0, 14.0, true)
			_route_line_node.draw_dashed_line(p1, p2, col_line, 2.5, 14.0, true)
			# Chấm tròn chỉ hướng tại các mốc
			_route_line_node.draw_circle(p2, 3.5, col_dot)

func _check_ambush_triggers() -> void:
	var prog: int = int(cart_node.get("progress_percent"))
	if prog >= 15 and not _wave_triggered.has(1):
		_wave_triggered[1] = true
		_spawn_ambush_wave(1)
	elif prog >= 30 and not _wave_triggered.has(2):
		_wave_triggered[2] = true
		_spawn_ambush_wave(2)
	elif prog >= 45 and not _wave_triggered.has(3):
		_wave_triggered[3] = true
		_spawn_ambush_wave(3)
	elif prog >= 60 and not _wave_triggered.has(4):
		_wave_triggered[4] = true
		_spawn_ambush_wave(4)
	elif prog >= 75 and not _wave_triggered.has(5):
		_wave_triggered[5] = true
		_spawn_ambush_wave(5)
	elif prog >= 90 and not _wave_triggered.has(6):
		_wave_triggered[6] = true
		_spawn_ambush_wave(6)

func _spawn_ambush_wave(wave_num: int) -> void:
	_current_wave = wave_num
	var cart_pos: Vector2 = cart_node.global_position
	var parent := VltkWorld.entity_parent()
	if parent == null:
		return

	# Cấu hình 6 trạm phục kích dọc lộ trình (mỗi trạm 4 - 6 sơn tặc vừa phải)
	var spawn_queue: Array[Dictionary] = []

	match wave_num:
		1:
			# Trạm 1 (15%): 4 Sơn tặc tiền trạm
			for i in 4:
				var m_id: int = MONSTER_SON_TAC_LIST[randi() % MONSTER_SON_TAC_LIST.size()]
				spawn_queue.append({"id": m_id, "lvl": 45})
		2:
			# Trạm 2 (30%): 4 Sơn tặc + 1 Sơn Tặc Đầu Mục (5 tên)
			for i in 4:
				var m_id: int = MONSTER_SON_TAC_LIST[randi() % MONSTER_SON_TAC_LIST.size()]
				spawn_queue.append({"id": m_id, "lvl": 48})
			spawn_queue.append({"id": MONSTER_DAU_MUC, "lvl": 50})
		3:
			# Trạm 3 (45%): 4 Sơn tặc + 1 Tây Nam Sơn Tặc Đầu Lĩnh (5 tên)
			for i in 4:
				var m_id: int = MONSTER_SON_TAC_LIST[randi() % MONSTER_SON_TAC_LIST.size()]
				spawn_queue.append({"id": m_id, "lvl": 50})
			spawn_queue.append({"id": MONSTER_DAU_LINH, "lvl": 52})
		4:
			# Trạm 4 (60%): 4 Sơn tặc + 1 Thần Bí Sơn Tặc (5 tên)
			for i in 4:
				var m_id: int = MONSTER_SON_TAC_LIST[randi() % MONSTER_SON_TAC_LIST.size()]
				spawn_queue.append({"id": m_id, "lvl": 52})
			spawn_queue.append({"id": MONSTER_THAN_BI, "lvl": 55})
		5:
			# Trạm 5 (75%): 4 Sơn tặc + 1 Sơn Tặc Trại Chủ (5 tên)
			for i in 4:
				var m_id: int = MONSTER_SON_TAC_LIST[randi() % MONSTER_SON_TAC_LIST.size()]
				spawn_queue.append({"id": m_id, "lvl": 55})
			spawn_queue.append({"id": MONSTER_TRAI_CHU, "lvl": 58})
		6:
			# Trạm 6 (90%): 4 Sơn tặc + 1 Đầu Lĩnh + 1 Sơn Tặc Vương (6 tên)
			for i in 4:
				var m_id: int = MONSTER_SON_TAC_LIST[randi() % MONSTER_SON_TAC_LIST.size()]
				spawn_queue.append({"id": m_id, "lvl": 56})
			spawn_queue.append({"id": MONSTER_DAU_LINH, "lvl": 58})
			spawn_queue.append({"id": MONSTER_SON_TAC_VUONG, "lvl": 60})

	# Sinh quái tản đều quanh xe tiêu
	var total_mon := spawn_queue.size()
	for i in total_mon:
		var entry: Dictionary = spawn_queue[i]
		var angle: float = (TAU * float(i) / float(total_mon)) + randf_range(-0.15, 0.15)
		var dist: float = randf_range(110.0, 180.0)
		var spawn_pos: Vector2 = cart_pos + Vector2(cos(angle) * dist, sin(angle) * dist)
		_spawn_bandit(entry["id"], entry["lvl"], spawn_pos)

	_update_alert_text()
	ChatBox.push_system("⚠️ BÁO ĐỘNG: Sơn tặc phục kích tại trạm %d (%d tên) đang tấn công tiêu xa!" % [wave_num, total_mon])

func _update_alert_text() -> void:
	if _alert_box == null:
		return
	if _bandits.is_empty():
		_alert_box.visible = false
	else:
		_alert_box.visible = true
		_alert_lbl.text = "⚠️ SƠN TẶC PHỤC KÍCH TRẠM %d! (Còn lại: %d tên)" % [_current_wave, _bandits.size()]

func _spawn_bandit(tpl_id: int, lvl: int, pos: Vector2) -> void:
	var base := MonsterData.monster(tpl_id)
	var parent := VltkWorld.entity_parent()
	if base.is_empty() or parent == null:
		return
	var m := VltkMonster.new()
	m.monster_id = tpl_id
	m.data = base.duplicate()
	m.level = lvl
	m.position = pos
	m.ai_enabled = true
	m.died.connect(func(mon: VltkMonster) -> void:
		_bandits.erase(mon)
		_update_alert_text()
		if _bandits.is_empty():
			ChatBox.push_system("🛡️ Đã tiêu diệt toàn bộ sơn tặc tại trạm %d! Tiêu xa tiếp tục an toàn lăn bánh." % _current_wave)
	)
	parent.add_child(m)
	_bandits.append(m)

func _update_bandits_ai(_delta: float) -> void:
	if cart_node == null or not is_instance_valid(cart_node):
		return
	for b in _bandits:
		if is_instance_valid(b) and not b.is_dead():
			var dist := b.global_position.distance_to(cart_node.global_position)
			if dist < 80.0 and randf() < 0.05:
				cart_node.take_damage_from(b, randi_range(250, 500))

func _on_cart_hp_changed(cur: int, _max_h: int) -> void:
	var cart_id := str(cart_data.get("id", ""))
	if cart_id != "" and cart_node != null:
		EscortManagerScript.update_cart(cart_id, cur, cart_node.progress_percent)

## Lấy danh sách thành viên của một phe ĐANG CÓ MẶT VÀ CÒN SỐNG trong map
func _get_surviving_members(team: String) -> Array:
	var survivors: Array = []
	var player: Node = get_tree().get_first_node_in_group("player")
	var is_player_alive: bool = (player != null and is_instance_valid(player) and not bool(player.get("is_dead")))

	if player_role == team and is_player_alive:
		var p_name := GameManager.local_profile.display_name if GameManager.local_profile else "Player"
		survivors.append(p_name)

	for b in _team_bots:
		if is_instance_valid(b) and not b.is_dead() and b.brawl_team == team:
			survivors.append(b.display_name if b.get("display_name") != null else b.name)

	return survivors

func _on_cart_arrived() -> void:
	if is_finished:
		return
	is_finished = true

	var cart_id := str(cart_data.get("id", ""))
	if cart_id != "":
		EscortManagerScript.finish_cart(cart_id)

	_clear_local_active_cart()

	var r_gold: int = int(cart_data.get("reward_gold", 120000))
	var r_exp: int = int(cart_data.get("reward_exp", 150000))
	var dep_gold: int = int(cart_data.get("deposit_gold", 0))
	var dep_jade: int = int(cart_data.get("deposit_jade", 0))

	# Tính lượng máu mất đi và lượng máu còn lại của xe
	var c_cur_hp: int = int(cart_node.current_hp) if cart_node != null else 0
	var c_max_hp: int = maxi(1, int(cart_node.max_hp) if cart_node != null else 60000)
	var lost_hp: int = clamp(c_max_hp - c_cur_hp, 0, c_max_hp)
	var lost_pct: float = float(lost_hp) / float(c_max_hp)
	var rem_pct: float = clampf(float(c_cur_hp) / float(c_max_hp), 0.0, 1.0)

	# Kiểm tra người chơi còn sống và có mặt trong map không (chết/out = không nhận được gì)
	var player: Node = get_tree().get_first_node_in_group("player")
	var is_player_alive: bool = (player != null and is_instance_valid(player) and not bool(player.get("is_dead")))

	if not is_player_alive:
		_show_defeat_banner("💀 BẠN ĐÃ TỬ TRẬN / RỜI MAP!", "Dù trước đó có thành tích nhưng do tử trận / không có mặt trong map lúc kết thúc, hiệp khách không nhận được gì.")
		_leave_timer = 5.0
		return

	if player_role == "defender":
		# Phe Hộ Tiêu: Tiêu xa về đích an toàn, thưởng chia đều cho thành viên hộ tiêu còn sống trong map
		var surviving_defs := _get_surviving_members("defender")
		var num_defs: int = maxi(1, surviving_defs.size())
		var def_gold_pool: int = int(float(r_gold) * rem_pct)
		var def_exp_pool: int = int(float(r_exp) * rem_pct)
		var share_gold: int = int(float(def_gold_pool) / float(num_defs))
		var share_exp: int = int(float(def_exp_pool) / float(num_defs))

		var my_name := GameManager.local_profile.display_name if GameManager.local_profile else ""
		var is_owner := (str(cart_data.get("owner_name", "")) == my_name)
		if is_owner:
			share_gold += int(float(dep_gold) * rem_pct)

		var p := GameManager.local_profile
		if p:
			p.gold += share_gold
			p.add_exp(share_exp)
			if is_owner and dep_jade > 0:
				p.jade += dep_jade
			SaveManager.save_profile(p)
			SaveManager.flush_online()

		_show_victory_banner(
			"🎉 PHE HỘ TIÊU CẬP BẾN THÀNH CÔNG!",
			"Tiêu xa cập bến (còn %d%% sinh lực). Thưởng chia đều cho %d hộ tiêu còn sống trong map:" % [int(rem_pct * 100.0), num_defs],
			share_gold, share_exp, is_owner
		)
	else:
		# Phe Cướp Tiêu: Xe về đích, thưởng đoạt được dựa vào % máu mất đi của xe và chia đều cho người còn sống
		var surviving_raiders := _get_surviving_members("raider")
		var num_raiders: int = maxi(1, surviving_raiders.size())

		var total_loot_gold := r_gold + dep_gold
		var total_loot_exp := r_exp
		var raid_gold_pool := int(float(total_loot_gold) * lost_pct)
		var raid_exp_pool := int(float(total_loot_exp) * lost_pct)

		var share_gold := int(float(raid_gold_pool) / float(num_raiders))
		var share_exp := int(float(raid_exp_pool) / float(num_raiders))

		if lost_pct <= 0.01 or share_gold <= 0:
			_show_defeat_banner("💀 CƯỚP TIÊU THẤT BẠI!", "Tiêu xa đã cập bến nguyên vẹn (mất 0% máu). Phe cướp tiêu không đoạt được chiến lợi phẩm.")
		else:
			var p := GameManager.local_profile
			if p:
				p.gold += share_gold
				p.add_exp(share_exp)
				SaveManager.save_profile(p)
				SaveManager.flush_online()

			_show_victory_banner(
				"💰 CƯỚP ĐƯỢC %d%% CHIẾN LỢI PHẨM!" % int(lost_pct * 100.0),
				"Xe về đích nhưng bị cướp mất %d%% máu! Phần thưởng đoạt được chia đều cho %d hảo thủ còn sống trong map:" % [int(lost_pct * 100.0), num_raiders],
				share_gold, share_exp, false
			)

	_leave_timer = 6.0

func _on_cart_destroyed() -> void:
	if is_finished:
		return
	is_finished = true

	var cart_id := str(cart_data.get("id", ""))
	if cart_id != "":
		EscortManagerScript.destroy_cart(cart_id)

	_clear_local_active_cart()

	var r_gold: int = int(cart_data.get("reward_gold", 120000))
	var r_exp: int = int(cart_data.get("reward_exp", 150000))
	var dep_gold: int = int(cart_data.get("deposit_gold", 0))

	# Hết máu giữa chừng -> % máu mất đi là 100%
	var lost_pct: float = 1.0

	# Kiểm tra người chơi còn sống và có mặt trong map không (chết/out = không nhận được gì)
	var player: Node = get_tree().get_first_node_in_group("player")
	var is_player_alive: bool = (player != null and is_instance_valid(player) and not bool(player.get("is_dead")))

	if not is_player_alive:
		_show_defeat_banner("💀 BẠN ĐÃ TỬ TRẬN / RỜI MAP!", "Dù trước đó có thành tích nhưng do tử trận / không có mặt trong map lúc kết thúc, hiệp khách không nhận được gì.")
		_leave_timer = 5.0
		return

	if player_role == "raider":
		# Phe Cướp Tiêu: Xe hết máu giữa chừng (mất 100% máu) -> cướp trọn 100% chiến lợi phẩm và chia đều cho người còn sống
		var surviving_raiders := _get_surviving_members("raider")
		var num_raiders: int = maxi(1, surviving_raiders.size())

		var total_loot_gold := r_gold + dep_gold
		var total_loot_exp := r_exp
		var raid_gold_pool := int(float(total_loot_gold) * lost_pct)
		var raid_exp_pool := int(float(total_loot_exp) * lost_pct)

		var share_gold := int(float(raid_gold_pool) / float(num_raiders))
		var share_exp := int(float(raid_exp_pool) / float(num_raiders))

		var p := GameManager.local_profile
		if p:
			p.gold += share_gold
			p.add_exp(share_exp)
			SaveManager.save_profile(p)
			SaveManager.flush_online()

		_show_victory_banner(
			"💰 CƯỚP TIÊU TOÀN THẮNG (MẤT 100% MÁU)!",
			"Tiêu xa đã hết máu giữa chừng! Toàn bộ chiến lợi phẩm được chia đều cho %d hảo thủ còn sống trong map:" % num_raiders,
			share_gold, share_exp, false
		)
	else:
		# Phe Hộ Tiêu: Xe hết máu giữa chừng, thất bại hoàn toàn!
		_show_defeat_banner("💀 HỘ TIÊU THẤT BẠI!", "Tiêu xa đã hết máu giữa chừng và bị phá hủy hoàn toàn. Hàng hóa bị phe cướp đoạt sạch!")

	_leave_timer = 6.0

func _clear_local_active_cart(count_as_run: bool = false) -> void:
	var esc_win: GDScript = load("res://ui/events/escort_window.gd")
	var rec_path: String = esc_win.get_record_path(GameManager.local_profile) if esc_win != null else "user://escort_records.json"
	if FileAccess.file_exists(rec_path):
		var txt := FileAccess.get_file_as_string(rec_path)
		var rec: Variant = JSON.parse_string(txt)
		if rec is Dictionary:
			if count_as_run:
				var today := Time.get_date_string_from_system()
				var runs: Dictionary = rec.get("runs", {})
				runs[today] = int(runs.get(today, 0)) + 1
				rec["runs"] = runs
			rec.erase("active_cart")
			var f := FileAccess.open(rec_path, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(rec, " "))

# ---------------------------------------------------------------- THIẾT KẾ BẢNG VẬN TIÊU BÊN TRÁI MÀN HÌNH
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 25
	add_child(_hud)

	# Bảng Hộ Tống Tiêu Xa đặt gọn gàng ở bên trái màn hình (Left Docked Tracker Board)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 115)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 14
	panel.offset_top = 105
	panel.offset_right = 264
	panel.offset_bottom = 220

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.55) # Nền trong suốt hơn
	style.border_color = Color(0.85, 0.72, 0.28, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	_hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	margin.add_child(vb)

	# 1. Dòng Tiêu Đề: Tên Xe + Phe + Trạng thái
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vb.add_child(row1)

	_title_lbl = Label.new()
	_title_lbl.text = "%s" % str(cart_data.get("cart_name", "Tiêu Xa Gỗ"))
	_title_lbl.add_theme_font_size_override("font_size", 12)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
	row1.add_child(_title_lbl)

	_role_lbl = Label.new()
	_role_lbl.text = "[🛡️ Phe Xanh - Hộ Tiêu]" if player_role == "defender" else "[⚔️ Phe Đỏ - Cướp Tiêu]"
	_role_lbl.add_theme_font_size_override("font_size", 11)
	_role_lbl.add_theme_color_override("font_color", Color(0.25, 0.70, 1.0) if player_role == "defender" else Color(1.0, 0.35, 0.35))
	row1.add_child(_role_lbl)

	var sep_space := Control.new()
	sep_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sep_space)

	_status_lbl = Label.new()
	_status_lbl.text = "Di Chuyển"
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.5))
	row1.add_child(_status_lbl)

	# 2. Mục Sinh Lực (HP) - Thanh sinh lực nhỏ còn 1/2
	var hp_header := HBoxContainer.new()
	vb.add_child(hp_header)

	var hp_icon := Label.new()
	hp_icon.text = "❤️ Sinh lực:"
	hp_icon.add_theme_font_size_override("font_size", 10)
	hp_icon.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hp_header.add_child(hp_icon)

	var hp_sep := Control.new()
	hp_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_header.add_child(hp_sep)

	_hp_text = Label.new()
	_hp_text.text = "60.000 / 60.000 (100%)"
	_hp_text.add_theme_font_size_override("font_size", 10)
	_hp_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	hp_header.add_child(_hp_text)

	_cart_hp_bar = ProgressBar.new()
	_cart_hp_bar.custom_minimum_size = Vector2(0, 5)
	_cart_hp_bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.22, 0.22)
	hp_fill.set_corner_radius_all(2)
	_cart_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	vb.add_child(_cart_hp_bar)

	# 3. Mục Tiến Độ - Thanh tiến độ nhỏ còn 1/2
	var prog_header := HBoxContainer.new()
	vb.add_child(prog_header)

	var prog_icon := Label.new()
	prog_icon.text = "🚩 Tiến độ:"
	prog_icon.add_theme_font_size_override("font_size", 10)
	prog_icon.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	prog_header.add_child(prog_icon)

	var prog_sep := Control.new()
	prog_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_header.add_child(prog_sep)

	_prog_text = Label.new()
	_prog_text.text = "0%"
	_prog_text.add_theme_font_size_override("font_size", 10)
	_prog_text.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	prog_header.add_child(_prog_text)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 4)
	_progress_bar.show_percentage = false
	var prog_fill := StyleBoxFlat.new()
	prog_fill.bg_color = Color(0.2, 0.75, 0.95)
	prog_fill.set_corner_radius_all(2)
	_progress_bar.add_theme_stylebox_override("fill", prog_fill)
	vb.add_child(_progress_bar)

	# 4. Nút Bấm Đi Theo / Đuổi Bắt Tiêu Xa
	var follow_btn := Button.new()
	follow_btn.text = "👣 Đi Theo Hộ Tiêu" if player_role == "defender" else "🎯 Đuổi Bắt Tiêu Xa"
	follow_btn.custom_minimum_size = Vector2(0, 22)
	follow_btn.add_theme_font_size_override("font_size", 10)
	follow_btn.pressed.connect(_on_follow_btn_pressed)
	vb.add_child(follow_btn)

	# 5. Cảnh Báo Phục Kích Sơn Tặc - Đưa ra giữa màn hình, ngay dưới thanh máu nhân vật
	_alert_box = PanelContainer.new()
	_alert_box.custom_minimum_size = Vector2(340, 28)
	_alert_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alert_box.offset_left = -170
	_alert_box.offset_top = 54
	_alert_box.offset_right = 170
	_alert_box.offset_bottom = 82
	_alert_box.visible = false

	var al_st := StyleBoxFlat.new()
	al_st.bg_color = Color(0.18, 0.03, 0.03, 0.78)
	al_st.border_color = Color(1.0, 0.3, 0.3, 0.85)
	al_st.set_border_width_all(1.5)
	al_st.set_corner_radius_all(5)
	_alert_box.add_theme_stylebox_override("panel", al_st)
	_hud.add_child(_alert_box)

	_alert_lbl = Label.new()
	_alert_lbl.text = "⚠️ SƠN TẶC PHỤC KÍCH TRẠM 1!"
	_alert_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_alert_lbl.add_theme_font_size_override("font_size", 11)
	_alert_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	_alert_box.add_child(_alert_lbl)

func _on_follow_btn_pressed() -> void:
	if cart_node != null and is_instance_valid(cart_node):
		if cart_node.has_method("_player_start_following"):
			cart_node._player_start_following()

func _update_hud() -> void:
	if cart_node == null or not is_instance_valid(cart_node):
		return
	var c_max_hp: int = int(cart_node.get("max_hp"))
	var c_cur_hp: int = int(cart_node.get("current_hp"))
	var c_prog: int = int(cart_node.get("progress_percent"))
	var pct: int = int((float(c_cur_hp) / float(maxi(c_max_hp, 1))) * 100.0)

	_cart_hp_bar.max_value = float(maxi(c_max_hp, 1))
	_cart_hp_bar.value = float(c_cur_hp)
	_hp_text.text = "%s / %s (%d%%)" % [
		InventoryPopup.format_money(c_cur_hp),
		InventoryPopup.format_money(c_max_hp),
		pct
	]

	_progress_bar.max_value = 100.0
	_progress_bar.value = float(c_prog)
	_prog_text.text = "%d%%" % c_prog

	# Nhấp nháy cảnh báo nếu đang có sơn tặc phục kích
	if _alert_box.visible:
		var t := Time.get_ticks_msec() / 1000.0
		_alert_box.modulate.a = 0.75 + sin(t * 8.0) * 0.25

func _show_victory_banner(title_text: String, sub_text: String, gold: int, exp_pts: int, is_owner: bool = false) -> void:
	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 220)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.08, 0.1, 0.95)
	st.border_color = Color(1.0, 0.85, 0.25)
	st.set_border_width_all(3)
	st.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", st)
	box.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = sub_text
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vb.add_child(sub)

	var rew := Label.new()
	var tag_owner := " (gồm cọc)" if is_owner else ""
	rew.text = "🎁 Phần thưởng nhận được: +%s Lượng%s  ·  +%s EXP" % [
		InventoryPopup.format_money(gold),
		tag_owner,
		InventoryPopup.format_money(exp_pts)
	]
	rew.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rew.add_theme_font_size_override("font_size", 14)
	rew.add_theme_color_override("font_color", Color(0.2, 0.95, 0.45))
	vb.add_child(rew)

	var btn := Button.new()
	btn.text = "Về Character Hub (6s)"
	btn.custom_minimum_size = Vector2(200, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_return_to_hub)
	vb.add_child(btn)

func _show_defeat_banner(title_text: String = "💀 TIÊU XA ĐÃ BỊ PHÁ HỦY!", sub_text: String = "Phe cướp tiêu đã cướp sạch hàng hóa trên xe. Phe hộ tiêu thất bại.") -> void:
	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 180)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.04, 0.04, 0.95)
	st.border_color = Color(0.9, 0.25, 0.25)
	st.set_border_width_all(3)
	st.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", st)
	box.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = sub_text
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vb.add_child(sub)

	var btn := Button.new()
	btn.text = "Về Character Hub (5s)"
	btn.custom_minimum_size = Vector2(180, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_return_to_hub)
	vb.add_child(btn)

func _return_to_hub() -> void:
	GameManager.game_mode = GameManager.GameMode.STAGE
	GameManager.field_map = {}
	get_tree().change_scene_to_file(HUB_SCENE)
