extends Node
class_name TongKimLolMatch
## Trình điều phối Ải "Tống Kim LOL" (MOBA 1v1 - 5v5)
## Quản lý: Sinh 2 Tướng Soái, Quái trấn thủ 3 cổng, Lính wave 20s, Boss Hoàng Kim 10p,
## Theo dõi sinh lực Tướng, Điểm hạ gục, Phân định Thắng/Thua/Hoà và Trao thưởng EXP x10.

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const CountdownOverlay = preload("res://ui/common/countdown_overlay.gd")

var side: String = "song" ## "song" hoặc "jin"
var team_size: int = 1
var is_online: bool = false
var match_started: bool = false
var _preparing: bool = false

var match_time: float = TongKimLolRules.MATCH_DURATION_SEC
var wave_timer: float = 0.0
var wave_count: int = 0
var creep_buff_multiplier: float = 1.0
var creep_buff_timer: float = 0.0
var boss_timer: float = 0.0
var super_minion_timer: float = 0.0
var pillar_spawned: bool = false
var central_pillar: VltkMonster = null

var general_song: VltkMonster = null
var general_jin: VltkMonster = null
var is_ended: bool = false

var client_hud: TongKimLolClient = null
var state: TongKimLolState = null

var song_kills: int = 0
var song_deaths: int = 0
var jin_kills: int = 0
var jin_deaths: int = 0

func _ready() -> void:
	var field: Dictionary = GameManager.field_map
	var room: Dictionary = field.get("room", {})
	side = str(field.get("pk", {}).get("side", room.get("side", field.get("side", "song"))))
	if side != "jin":
		side = "song"
	team_size = clampi(int(room.get("team_size", 1)), 1, 5)
	is_online = bool(field.get("pk_online", false)) or bool(field.get("pk", {}).get("online", false))

	# 1. Khởi tạo giao diện HUD 2 phe
	client_hud = TongKimLolClient.new()
	client_hud.my_side = side
	client_hud.time_left = match_time
	client_hud.leave_requested.connect(_on_leave_requested)
	client_hud.visible = not is_online
	add_child(client_hud)

	# Khởi tạo state ngay từ đầu và bind vào HUD
	state = TongKimLolState.instance()
	state.init_match(side)
	if client_hud:
		client_hud.bind_state(state)

	# 2. Đặt vị trí xuất phát cho người chơi trong doanh trại phe mình
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.set("battle_side", side)
		var spawn_pos := TongKimLolRules.HOME_SONG_POS if side == "song" else TongKimLolRules.HOME_JIN_POS
		if VltkWorld.current != null and VltkWorld.current.respawn_point != Vector2.INF:
			spawn_pos = VltkWorld.current.respawn_point
		player.global_position = spawn_pos - Vector2(0, VltkWorld.FEET_OFFSET)
		if VltkWorld.current != null:
			VltkWorld.current.respawn_point = spawn_pos
			if VltkWorld.current.map != null:
				VltkWorld.current.map.prepare_around(spawn_pos)
				if VltkWorld.current.map is VltkWorld.SortedMap:
					(VltkWorld.current.map as VltkWorld.SortedMap).warm_up(player.global_position)
		if "suppress_death_popup" in player:
			player.suppress_death_popup = true
		if "died" in player and player.has_signal("died"):
			player.died.connect(_on_player_died)

	if is_online:
		NetClient.arena_message.connect(_on_arena_message)
	else:
		_start_moba_match()

func _on_arena_message(msg: Dictionary) -> void:
	var op := str(msg.get("op", ""))
	if op == "state":
		var st := str(msg.get("state", ""))
		var my_team := str(msg.get("my_team", ""))
		if my_team == "b":
			side = "jin"
		elif my_team == "a":
			side = "song"
		if st in ["prepare", "fight"] and not match_started:
			_start_moba_match()
		elif st == "waiting" and not match_started:
			if client_hud:
				client_hud.visible = false
	elif op == "result":
		var winner := str(msg.get("winner", ""))
		if not is_ended:
			_end_match("song" if winner == "Phe 1" else ("jin" if winner == "Phe 2" else "draw"), str(msg.get("why", "")))

func _start_moba_match() -> void:
	if match_started or _preparing:
		return
	_preparing = true
	if client_hud:
		client_hud.my_side = side
		client_hud.visible = true

	# 1. Khởi tạo trạng thái nhân vật & tiến trình trận đấu
	if state == null:
		state = TongKimLolState.instance()
		state.init_match(side)
	if client_hud:
		client_hud.bind_state(state)
	var p_node := get_tree().get_first_node_in_group("player") as Node2D
	if p_node:
		p_node.set("battle_side", side)
		if "is_invincible" in p_node:
			p_node.is_invincible = true

	# 2. Sinh 2 Tướng Soái tối cao
	_spawn_generals.call_deferred()

	# 3. Sinh 3 cụm lính gác cổng (30 quái xa / cổng)
	_spawn_gate_guardians.call_deferred()

	# Đếm ngược 3 giây 1, 2, 3, GO trước khi khai chiến
	CountdownOverlay.start(self, func() -> void:
		_preparing = false
		match_started = true
		if p_node and is_instance_valid(p_node) and "is_invincible" in p_node:
			p_node.is_invincible = false
		ChatBox.push_system("[color=#ffd700][Tống Kim LOL][/color] Trận đấu Ải Tống Kim LOL bắt đầu! Hãy tiêu diệt Tướng địch để giành chiến thắng!")
	)

func _process(delta: float) -> void:
	if is_ended or not match_started:
		return

	match_time -= delta
	if match_time <= 0.0:
		_end_match("draw", "Hết 40 phút thi đấu, hai phe bất phân thắng bại!")
		return

	# Cập nhật máu 2 Tướng Soái lên Toolbar
	var song_hp_pct := general_song.health / general_song.max_health if general_song and is_instance_valid(general_song) and not general_song.is_dead() else 0.0
	var jin_hp_pct := general_jin.health / general_jin.max_health if general_jin and is_instance_valid(general_jin) and not general_jin.is_dead() else 0.0
	client_hud.update_generals(song_hp_pct, jin_hp_pct)

	# 1. Xử lý xuất wave lính (mỗi 20 giây xuất 1 đợt)
	wave_timer += delta
	if wave_timer >= TongKimLolRules.WAVE_INTERVAL_SEC:
		wave_timer = 0.0
		wave_count += 1
		_spawn_wave()

	# 2. Xử lý gia tăng sức mạnh lính (mỗi 5 phút tăng 30% HP và Sát thương)
	creep_buff_timer += delta
	if creep_buff_timer >= TongKimLolRules.CREEP_BUFF_INTERVAL_SEC:
		creep_buff_timer = 0.0
		creep_buff_multiplier *= TongKimLolRules.CREEP_BUFF_RATE
		client_hud.show_marquee_announcement("Đã trôi qua 5 phút! Lính của cả hai phe được tăng 30% sức mạnh!")

	# 3. Xử lý xuất Boss Hoàng Kim (mỗi 10 phút)
	boss_timer += delta
	if boss_timer >= TongKimLolRules.BOSS_INTERVAL_SEC:
		boss_timer = 0.0
		_spawn_golden_boss()

	# 4. Xử lý xuất Siêu Lính (máu x8, dame như cũ) mỗi 10 phút
	super_minion_timer += delta
	if super_minion_timer >= TongKimLolRules.SUPER_MINION_INTERVAL_SEC:
		super_minion_timer = 0.0
		_spawn_super_minions()

	# 5. Xử lý xuất Long Trụ Thượng Cổ phút thứ 15
	var elapsed_sec := TongKimLolRules.MATCH_DURATION_SEC - match_time
	if elapsed_sec >= TongKimLolRules.PILLAR_SPAWN_TIME_SEC and not pillar_spawned:
		pillar_spawned = true
		_spawn_central_pillar()

# ---------------------------------------------------------------- Sinh Tướng Soái
func _spawn_generals() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null:
		return

	# Tướng Tống
	general_song = VltkMonster.new()
	general_song.monster_id = 636
	general_song.data = MonsterData.monster(general_song.monster_id).duplicate()
	general_song.data["name"] = "Tống Quân Nguyên Soái"
	general_song.battle_side = "song"
	general_song.level = 95
	general_song.gold_boss = true
	general_song.is_moba_general = true
	general_song.ai_enabled = true
	general_song.moba_damage_multiplier = TongKimLolRules.GENERAL_DAMAGE_MULT
	general_song.position = TongKimLolRules.GENERAL_SONG_POS
	general_song.hp_override = int(TongKimLolRules.GENERAL_MAX_HP)
	general_song.died.connect(func(_m) -> void: _end_match("jin", "Tướng Tống đã tử trận! Phe Kim giành chiến thắng!"))
	parent.add_child(general_song)
	general_song.max_health = TongKimLolRules.GENERAL_MAX_HP
	general_song.health = general_song.max_health
	if general_song._health_bar:
		general_song._health_bar.set_max_health(general_song.max_health)
		general_song._health_bar.set_health(general_song.health)

	# Tướng Kim
	general_jin = VltkMonster.new()
	general_jin.monster_id = 642
	general_jin.data = MonsterData.monster(general_jin.monster_id).duplicate()
	general_jin.data["name"] = "Kim Quốc Nguyên Soái"
	general_jin.battle_side = "jin"
	general_jin.level = 95
	general_jin.gold_boss = true
	general_jin.is_moba_general = true
	general_jin.ai_enabled = true
	general_jin.moba_damage_multiplier = TongKimLolRules.GENERAL_DAMAGE_MULT
	general_jin.position = TongKimLolRules.GENERAL_JIN_POS
	general_jin.hp_override = int(TongKimLolRules.GENERAL_MAX_HP)
	general_jin.died.connect(func(_m) -> void: _end_match("song", "Tướng Kim đã tử trận! Phe Tống giành chiến thắng!"))
	parent.add_child(general_jin)
	general_jin.max_health = TongKimLolRules.GENERAL_MAX_HP
	general_jin.health = general_jin.max_health
	if general_jin._health_bar:
		general_jin._health_bar.set_max_health(general_jin.max_health)
		general_jin._health_bar.set_health(general_jin.health)

# ---------------------------------------------------------------- Quái Trấn Thủ Cổng
func _spawn_gate_guardians() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null:
		return

	# 3 Cổng Phe Tống
	for gate_pos in TongKimLolRules.GATES_SONG:
		_spawn_guardian_cluster(parent, gate_pos, "song")

	# 3 Cổng Phe Kim
	for gate_pos in TongKimLolRules.GATES_JIN:
		_spawn_guardian_cluster(parent, gate_pos, "jin")

func _spawn_guardian_cluster(parent: Node, center_pos: Vector2, cluster_side: String) -> void:
	var count := TongKimLolRules.GATE_GUARDIAN_COUNT
	var angle_step := TAU / float(count)
	for i in count:
		var m := VltkMonster.new()
		var is_melee := i % 2 == 0
		m.monster_id = TongKimLolRules.CREEP_MELEE_TPL if is_melee else TongKimLolRules.CREEP_RANGED_TPL
		m.data = MonsterData.monster(m.monster_id).duplicate()
		var type_name := "Thủ Vệ Giáo Binh" if is_melee else "Thủ Vệ Cung Thủ"
		m.data["name"] = "%s %s" % ["Tống" if cluster_side == "song" else "Kim", type_name]
		m.battle_side = cluster_side
		m.level = 65
		m.ai_enabled = true
		m.moba_damage_multiplier = TongKimLolRules.GUARDIAN_DAMAGE_MULT
		m.hp_override = TongKimLolRules.GUARDIAN_MAX_HP

		var offset := Vector2(cos(i * angle_step), sin(i * angle_step)) * randf_range(30.0, 100.0)
		m.position = center_pos + offset
		m.died.connect(_on_creep_died.bind(cluster_side))
		parent.add_child(m)
		m.max_health = float(TongKimLolRules.GUARDIAN_MAX_HP)
		m.health = m.max_health
		if m._health_bar:
			m._health_bar.set_max_health(m.max_health)
			m._health_bar.set_health(m.health)

# ---------------------------------------------------------------- Xuất Lính Theo Đợt
func _spawn_wave() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null and get_tree():
		parent = get_tree().current_scene
	if parent == null:
		return

	# Đếm số lính lane đang sống trên sân (chỉ đếm lính hành quân is_lane_creep, không đếm thủ vệ cổng, tướng soái hay boss)
	var live_song := 0
	var live_jin := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is VltkMonster and not node.is_dead() and node.is_lane_creep and not node.gold_boss:
			if node.battle_side == "song":
				live_song += 1
			elif node.battle_side == "jin":
				live_jin += 1

	# Số lính mỗi cổng: mỗi đợt 20 giây tăng 1 lính (đợt 1 ra 1 lính, đợt 2 ra 2 lính, đợt 3 ra 3, đợt 4 ra 4...)
	var per_gate: int = TongKimLolRules.minions_per_gate_for_wave(wave_count)

	for gate_idx in 3:
		var song_gate: Vector2 = TongKimLolRules.GATES_SONG[gate_idx]
		var jin_gate: Vector2 = TongKimLolRules.GATES_JIN[gate_idx]

		# Lính Tống xuất từ cổng Tống tiến về phía cổng Kim
		if live_song < TongKimLolRules.MAX_LANE_MINIONS_PER_SIDE:
			for i in per_gate:
				_spawn_lane_minion(parent, song_gate, jin_gate, "song", i, gate_idx)
				live_song += 1

		# Lính Kim xuất từ cổng Kim tiến về phía cổng Tống
		if live_jin < TongKimLolRules.MAX_LANE_MINIONS_PER_SIDE:
			for i in per_gate:
				_spawn_lane_minion(parent, jin_gate, song_gate, "jin", i, gate_idx)
				live_jin += 1

func _spawn_lane_minion(parent: Node, start_pos: Vector2, target_gate: Vector2, minion_side: String, idx: int, lane_idx: int) -> void:
	var m := VltkMonster.new()
	var is_melee := idx % 2 == 0
	m.monster_id = TongKimLolRules.CREEP_MELEE_TPL if is_melee else TongKimLolRules.CREEP_RANGED_TPL
	m.data = MonsterData.monster(m.monster_id).duplicate()
	var type_name := "Bộ Binh" if is_melee else "Cung Thủ"
	m.data["name"] = "%s %s" % ["Tống" if minion_side == "song" else "Kim", type_name]
	var elem: int = idx % 5
	m.data["series"] = elem
	m.battle_side = minion_side
	m.level = 50 + int(wave_count * 1.5)
	m.ai_enabled = true
	m.is_lane_creep = true
	m.lane_waypoints = TongKimLolRules.get_lane_waypoints(lane_idx, minion_side)
	m.lane_waypoint_idx = 0
	m.moba_damage_multiplier = TongKimLolRules.CREEP_DAMAGE_MULT * creep_buff_multiplier

	var base_hp: int = TongKimLolRules.CREEP_MELEE_HP if is_melee else TongKimLolRules.CREEP_RANGED_HP
	m.hp_override = int(float(base_hp) * creep_buff_multiplier)

	var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
	m.position = start_pos + offset
	m.died.connect(_on_creep_died.bind(minion_side))
	parent.add_child(m)

	m.max_health = float(m.hp_override)
	m.health = m.max_health
	if m._health_bar:
		m._health_bar.set_max_health(m.max_health)
		m._health_bar.set_health(m.health)

# ---------------------------------------------------------------- Siêu Lính Mỗi 10 Phút
func _spawn_super_minions() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null and get_tree():
		parent = get_tree().current_scene
	if parent == null:
		return

	var song_gate: Vector2 = TongKimLolRules.GATES_SONG[1]
	var jin_gate: Vector2 = TongKimLolRules.GATES_JIN[1]
	_spawn_super_minion(parent, song_gate, "song", 1)
	_spawn_super_minion(parent, jin_gate, "jin", 1)

	if client_hud:
		client_hud.show_marquee_announcement("Đã trôi qua 10 phút! Siêu Binh Lính (máu x8) hai phe xuất kích tại đường Giữa!")
	ChatBox.push_system("[color=#ffd700][Tống Kim LOL][/color] Siêu Binh Lính (máu x8, sát thương lính thường) của hai phe đã xuất trận tại đường Giữa!")

func _spawn_super_minion(parent: Node, start_pos: Vector2, minion_side: String, lane_idx: int) -> void:
	var m := VltkMonster.new()
	m.monster_id = TongKimLolRules.CREEP_MELEE_TPL
	m.data = MonsterData.monster(m.monster_id).duplicate()
	m.data["name"] = "%s Đại Tiên Phong Binh" % ["Tống" if minion_side == "song" else "Kim"]
	m.data["series"] = randi() % 5
	m.battle_side = minion_side
	m.level = 65 + int(wave_count * 1.5)
	m.ai_enabled = true
	m.is_lane_creep = true
	m.lane_waypoints = TongKimLolRules.get_lane_waypoints(lane_idx, minion_side)
	m.lane_waypoint_idx = 0
	m.moba_damage_multiplier = TongKimLolRules.CREEP_DAMAGE_MULT * creep_buff_multiplier

	var base_hp: float = float(TongKimLolRules.CREEP_MELEE_HP) * TongKimLolRules.SUPER_MINION_HP_MULT
	m.hp_override = int(base_hp * creep_buff_multiplier)

	var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
	m.position = start_pos + offset
	m.died.connect(_on_creep_died.bind(minion_side))
	parent.add_child(m)

	m.max_health = float(m.hp_override)
	m.health = m.max_health
	if m._health_bar:
		m._health_bar.set_max_health(m.max_health)
		m._health_bar.set_health(m.health)

# ---------------------------------------------------------------- Trụ Trung Tâm Phút 15
func _spawn_central_pillar() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null and get_tree():
		parent = get_tree().current_scene
	if parent == null:
		return

	central_pillar = VltkMonster.new()
	central_pillar.monster_id = 528
	central_pillar.data = MonsterData.monster(central_pillar.monster_id).duplicate()
	central_pillar.data["name"] = "Long Trụ Thượng Cổ"
	central_pillar.battle_side = "neutral"
	central_pillar.level = 90
	central_pillar.ai_enabled = false
	central_pillar.hp_override = int(TongKimLolRules.PILLAR_HP * creep_buff_multiplier)
	central_pillar.position = TongKimLolRules.MAP_CENTER_POS
	central_pillar.died.connect(_on_pillar_destroyed)
	parent.add_child(central_pillar)

	central_pillar.max_health = float(central_pillar.hp_override)
	central_pillar.health = central_pillar.max_health
	if central_pillar._health_bar:
		central_pillar._health_bar.set_max_health(central_pillar.max_health)
		central_pillar._health_bar.set_health(central_pillar.health)

	if client_hud:
		client_hud.show_marquee_announcement("Phút 15: Long Trụ Thượng Cổ xuất hiện tại trung tâm! Phe nào kết liễu sẽ triệu hồi Đại Boss!")
	ChatBox.push_system("[color=#ffd700][Tống Kim LOL][/color] Long Trụ Thượng Cổ đã giáng lâm tại trung tâm chiến trường! Phe nào kết liễu sẽ triệu hồi Đại Boss trợ chiến!")

func _on_pillar_destroyed(_pillar: VltkMonster) -> void:
	var winning_side := central_pillar.last_attacker_side if central_pillar and central_pillar.last_attacker_side in ["song", "jin"] else side
	var side_name := "Tống" if winning_side == "song" else "Kim"

	_spawn_ancient_boss(winning_side)

	if client_hud:
		client_hud.show_marquee_announcement("Phe %s đã kết liễu Long Trụ! Triệu hồi Đại Boss Thượng Cổ (Máu x10, Dame x6)!" % side_name)
	ChatBox.push_system("[color=#ffd700][Tống Kim LOL][/color] Phe [color=%s]%s[/color] đã xuất sắc kết liễu Long Trụ! Đại Boss Thượng Cổ xuất trận trợ chiến!" % ["#5cd882" if winning_side == "song" else "#ff6666", side_name])

func _spawn_ancient_boss(b_side: String) -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null and get_tree():
		parent = get_tree().current_scene
	if parent == null:
		return

	var boss_id: int = TongKimLolRules.BOSS_GOLD_SONG_IDS.pick_random() if b_side == "song" else TongKimLolRules.BOSS_GOLD_JIN_IDS.pick_random()
	var boss := VltkMonster.new()
	boss.monster_id = boss_id
	boss.data = MonsterData.monster(boss_id).duplicate()
	var prefix := "[Tống] " if b_side == "song" else "[Kim] "
	boss.data["name"] = prefix + "Thượng Cổ - " + str(boss.data.get("name", "Hoàng Kim"))
	boss.level = 95
	boss.gold_boss = true
	boss.ai_enabled = true
	boss.battle_side = b_side
	boss.is_lane_creep = true
	boss.lane_waypoints = TongKimLolRules.get_lane_waypoints(1, b_side)
	boss.lane_waypoint_idx = 1
	boss.position = TongKimLolRules.MAP_CENTER_POS

	boss.moba_damage_multiplier = TongKimLolRules.CREEP_DAMAGE_MULT * TongKimLolRules.ANCIENT_BOSS_DAMAGE_MULT * creep_buff_multiplier
	var base_hp: float = float(TongKimLolRules.GOLDEN_BOSS_MAX_HP) * TongKimLolRules.ANCIENT_BOSS_HP_MULT
	boss.hp_override = int(base_hp * creep_buff_multiplier)
	boss.died.connect(_on_creep_died.bind(b_side))

	parent.add_child(boss)
	boss.max_health = float(boss.hp_override)
	boss.health = boss.max_health
	if boss._health_bar:
		boss._health_bar.set_max_health(boss.max_health)
		boss._health_bar.set_health(boss.health)

# ---------------------------------------------------------------- Boss Hoàng Kim
func _spawn_golden_boss() -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null and get_tree():
		parent = get_tree().current_scene
	if parent == null:
		return

	# Lựa chọn ngẫu nhiên Boss Hoàng Kim cho phe Tống và phe Kim
	var song_id: int = TongKimLolRules.BOSS_GOLD_SONG_IDS.pick_random()
	var jin_id: int = TongKimLolRules.BOSS_GOLD_JIN_IDS.pick_random()

	# 1. Sinh Boss Hoàng Kim phe Tống (ở phía Tây trung tâm)
	var boss_song := create_golden_boss(song_id, "song", TongKimLolRules.MAP_CENTER_POS + Vector2(-150.0, 0.0), 1, creep_buff_multiplier)
	boss_song.died.connect(_on_creep_died.bind("song"))
	parent.add_child(boss_song)

	# 2. Sinh Boss Hoàng Kim phe Kim (ở phía Đông trung tâm)
	var boss_jin := create_golden_boss(jin_id, "jin", TongKimLolRules.MAP_CENTER_POS + Vector2(150.0, 0.0), 1, creep_buff_multiplier)
	boss_jin.died.connect(_on_creep_died.bind("jin"))
	parent.add_child(boss_jin)

	# 3. Hai Boss Hoàng Kim lập tức khoá mục tiêu vào nhau và giao chiến rực lửa
	boss_song.target = boss_jin
	boss_jin.target = boss_song

	var name_song: String = str(boss_song.data.get("name", "Boss Tống"))
	var name_jin: String = str(boss_jin.data.get("name", "Boss Kim"))
	if client_hud:
		client_hud.show_marquee_announcement("Đại Boss Hoàng Kim hai phe [%s] và [%s] xuất hiện quyết chiến tại trung tâm!" % [name_song, name_jin])
	ChatBox.push_system("[color=#ffd700][Tống Kim LOL][/color] Hào kiệt chú ý: Boss Hoàng Kim [color=#5cd882]%s[/color] (Tống) và [color=#ff6666]%s[/color] (Kim) đang đại chiến tại trung tâm chiến trường!" % [name_song, name_jin])

## Khởi tạo 1 Boss Hoàng Kim chuẩn MOBA
static func create_golden_boss(boss_id: int, b_side: String, spawn_pos: Vector2, lane_idx: int = 1, buff_mult: float = 1.0) -> VltkMonster:
	var boss := VltkMonster.new()
	boss.monster_id = boss_id
	boss.data = MonsterData.monster(boss_id).duplicate()
	var prefix := "[Tống] " if b_side == "song" else "[Kim] "
	boss.data["name"] = prefix + str(boss.data.get("name", "Boss Hoàng Kim"))
	boss.level = 95
	boss.gold_boss = true
	boss.ai_enabled = true
	boss.battle_side = b_side
	boss.is_lane_creep = true
	boss.lane_waypoints = TongKimLolRules.get_lane_waypoints(lane_idx, b_side)
	boss.lane_waypoint_idx = 1 # Tiến theo đường giữa về phía cứ điểm đối phương
	boss.position = spawn_pos

	# Sát thương: hơn quái thường 3 lần (TongKimLolRules.GOLDEN_BOSS_DAMAGE_MULT = 3.0)
	boss.moba_damage_multiplier = TongKimLolRules.GOLDEN_BOSS_DAMAGE_MULT

	# Máu: nhiều hơn lính thường 20 lần (TongKimLolRules.GOLDEN_BOSS_MAX_HP = 70.000 HP, nhân theo buff_mult)
	var base_hp := TongKimLolRules.GOLDEN_BOSS_MAX_HP
	boss.hp_override = int(float(base_hp) * buff_mult)
	boss.max_health = float(boss.hp_override)
	boss.health = boss.max_health
	if boss._health_bar:
		boss._health_bar.set_max_health(boss.max_health)
		boss._health_bar.set_health(boss.health)

	return boss

# ---------------------------------------------------------------- Hạ Gục & Phần Thưởng
func _on_creep_died(m: VltkMonster, creep_side: String) -> void:
	if is_ended:
		return
	# Thưởng EXP và rơi cọc tiền nhặt khi quái bị tiêu diệt
	if creep_side != side:
		var gold_amt: int = TongKimLolRules.CREEP_BASE_GOLD
		if m.gold_boss and not m.is_moba_general:
			gold_amt = TongKimLolRules.CREEP_BASE_GOLD * 10
			state.add_match_exp(TongKimLolRules.CREEP_BASE_EXP * 10.0)
			if client_hud:
				client_hud.show_marquee_announcement("Đại Boss phe địch đã bị tiêu diệt!")
			ChatBox.push_system("[color=#ffd700][Tống Kim LOL][/color] Hào kiệt tiêu diệt thành công Boss phe địch, nhận 1.000 EXP và cọc tiền rơi ra!")
		else:
			state.add_match_exp(TongKimLolRules.CREEP_BASE_EXP)

		var parent := m.get_parent()
		if parent:
			GroundDrop.spawn_drops(parent, m.position, [{"type": "money", "amount": gold_amt}])

func _on_player_died() -> void:
	if is_ended:
		return
	if side == "song":
		song_deaths += 1
		jin_kills += 1
	else:
		jin_deaths += 1
		song_kills += 1

	client_hud.update_scores(song_kills, song_deaths, jin_kills, jin_deaths)
	var killer_side := "jin" if side == "song" else "song"
	client_hud.add_kill_feed("Đối Thủ", killer_side, GameManager.local_profile.display_name, side)

	# Tự động hồi sinh tại Doanh trại sau 8 giây
	await get_tree().create_timer(8.0).timeout
	if not is_ended:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			var home_pos := TongKimLolRules.HOME_SONG_POS if side == "song" else TongKimLolRules.HOME_JIN_POS
			if VltkWorld.current != null and VltkWorld.current.respawn_point != Vector2.INF:
				home_pos = VltkWorld.current.respawn_point
			var spawn_feet := home_pos
			var spawn_avatar := spawn_feet - Vector2(0, VltkWorld.FEET_OFFSET)
			if player.has_method("respawn_at"):
				player.respawn_at(spawn_avatar)
			elif player.has_method("revive"):
				player.global_position = spawn_avatar
				player.revive()
			if VltkWorld.current != null and VltkWorld.current.map != null:
				VltkWorld.current.map.prepare_around(spawn_feet)
				if VltkWorld.current.map is VltkWorld.SortedMap:
					(VltkWorld.current.map as VltkWorld.SortedMap).warm_up(player.global_position)
			ChatBox.push_system("[color=#60ff60]Bạn đã hồi sinh tại Đại Doanh![/color]")

func on_enemy_player_killed(enemy_name: String) -> void:
	if side == "song":
		song_kills += 1
		jin_deaths += 1
	else:
		jin_kills += 1
		song_deaths += 1

	state.add_match_exp(TongKimLolRules.CREEP_BASE_EXP * TongKimLolRules.PLAYER_KILL_EXP_MULT)
	state.add_gold(int(TongKimLolRules.CREEP_BASE_GOLD * TongKimLolRules.PLAYER_KILL_GOLD_MULT))

	client_hud.update_scores(song_kills, song_deaths, jin_kills, jin_deaths)
	var enemy_side := "jin" if side == "song" else "song"
	client_hud.add_kill_feed(GameManager.local_profile.display_name, side, enemy_name, enemy_side)

# ---------------------------------------------------------------- Kết Thúc Trận Đấu
func _end_match(winner_side: String, reason: String) -> void:
	if is_ended:
		return
	is_ended = true

	var is_win: bool = winner_side == side
	var is_draw: bool = winner_side == "draw"

	# Trao thưởng EXP thực tế x10
	var reward_exp := state.finish_and_reward()

	# Hiển thị thông báo kết thúc
	var title := "CHIẾN THẮNG!" if is_win else ("HÒA TRẬN!" if is_draw else "THẤT BẠI!")
	var result_color := "#60ff60" if is_win else ("#ffd700" if is_draw else "#ff4444")
	client_hud.show_marquee_announcement("[%s] %s" % [title, reason])

	ChatBox.push_system("[color=%s][%s][/color] %s" % [result_color, title, reason])
	ChatBox.push_system("[color=#ffd700]Phần thưởng: Bạn nhận được %d EXP thực tế (x10 EXP trong trận)![/color]" % reward_exp)

	# Đợi 5 giây rồi trở về Character Hub
	await get_tree().create_timer(5.0).timeout
	_return_to_hub()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_leave_requested()

func _on_leave_requested() -> void:
	if is_ended:
		_return_to_hub()
		return
	SocialWindow.confirm(self, "Rời Ải", "Bạn có chắc chắn muốn rời trận Tống Kim LOL không?", func() -> void:
		state.finish_and_reward()
		_return_to_hub()
	)

func _return_to_hub() -> void:
	TongKimLolState.cleanup_tk_items()
	is_ended = true
	set_process(false)
	if client_hud and is_instance_valid(client_hud):
		client_hud.queue_free()
	GameManager.field_map = {}
	get_tree().change_scene_to_file(HUB_SCENE)
