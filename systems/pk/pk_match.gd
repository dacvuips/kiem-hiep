extends Node
class_name PkMatch
## 1 TRẬN PK trên đấu trường (map 397) — tạo bởi main.gd khi GameManager.field_map có "pk" (PkRules.arena_entry):
##   chuẩn bị PkRules.PREPARE_SEC giây (2 bên đứng yên, chưa nhận sát thương) -> đấu tối đa PkRules.FIGHT_SEC giây ->
##   1 bên trọng thương là thua; hết giờ thì bên còn nhiều % sinh lực hơn thắng -> ghi thắng/thua -> về Character Hub.
## Đối thủ hiện là bot (PkBot, hồ sơ trong field.pk.opponent); đấu người thật online là bước sau.

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const RECORD_PATH := "user://pk_records.json"
const FIGHTER_GAP := 120.0                ## mỗi bên đứng cách tâm sân chừng này (px) lúc vào trận
## Tìm sân: đấu trường gốc là lưới ô đấu có rào, điểm xuất phát của map có thể nằm trên rào -> lấy mẫu quanh điểm xuất phát,
## loang theo ô không vật cản, chọn vùng liền lớn nhất (= lòng 1 ô đấu).
const ARENA_SEARCH_PX := 1400.0
const ARENA_SAMPLE_PX := 160.0
const ARENA_MAX_CELLS := 30000

var mode: PkRules.Mode = PkRules.Mode.LIEN_DAU
var team_size: int = 1
var time_left := PkRules.FIGHT_SEC
var running := false
var done := false
var _prepare := PkRules.PREPARE_SEC
var _leave_in := -1.0
var _player: Node2D
var _bot: PkBot
var _allies: Array[PkBot] = []
var _enemies: Array[PkBot] = []
var _hud: CanvasLayer
var _title: Label
var _clock: Label
var _info: Label
var _reject_button: Button
var _arena_cells := {}                   ## ô (Vector2i) của sân đấu đang dùng — đặt người chỉ trong vùng này

func _ready() -> void:
	var pk: Dictionary = GameManager.field_map.get("pk", {})
	mode = int(pk.get("mode", PkRules.Mode.LIEN_DAU)) as PkRules.Mode
	team_size = clampi(int(pk.get("team_size", 1)), 1, 8)
	_build_hud()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		if "suppress_death_popup" in _player:
			_player.suppress_death_popup = true
		if "hurt_invincible" in _player:
			_player.hurt_invincible = false
		if _player.has_signal("died"):
			_player.died.connect(_on_player_died)
	_spawn_bot.call_deferred(pk.get("opponent", {}))
	_say("%s [%s]: còn %d giây nữa bắt đầu." % [PkRules.MODE_NAMES[mode], PkRules.format_name(team_size), int(PkRules.PREPARE_SEC)])

func _spawn_bot(opponent: Dictionary) -> void:
	var pk: Dictionary = GameManager.field_map.get("pk", {})
	team_size = clampi(int(pk.get("team_size", 1)), 1, 8)
	var parent := VltkWorld.entity_parent()
	if parent == null or _player == null:
		push_warning("PkMatch: chưa có map / nhân vật")
		return
	var center := _arena_center(_player.global_position)
	var slots: Dictionary = PkRules.get_spawn_slots(center, team_size)
	var slots_a: Array = slots["team_a"]
	var slots_b: Array = slots["team_b"]
	var feet := Vector2(0, PkBot.FEET_OFFSET)

	# Đặt vị trí người chơi tại slot 0 của Team A
	_player.global_position = _free_near(slots_a[0]) - feet

	# Sinh các bot đồng minh (Team A: slot 1 .. team_size - 1)
	var team_a_data: Array = pk.get("team_a", [])
	for i in range(1, team_size):
		var bot_p: PlayerProfile = null
		if i < team_a_data.size() and team_a_data[i] is Dictionary and team_a_data[i].has("bot_data"):
			bot_p = PlayerProfile.from_dict(team_a_data[i]["bot_data"])
		elif i < team_a_data.size() and team_a_data[i] is Dictionary and team_a_data[i].has("name"):
			bot_p = PkBotProfile.create(int(team_a_data[i].get("level", GameManager.local_profile.level)), str(team_a_data[i].get("sect_id", "")))
		else:
			bot_p = PkBotProfile.create(GameManager.local_profile.level)
		var ally := PkBot.new()
		ally.name = "PkAlly%d" % i
		ally.setup(bot_p)
		ally.position = _free_near(slots_a[i]) - feet
		ally.pk_enemy = false
		ally.cast_target_group = &"enemies"
		ally.remove_from_group("enemies")
		ally.add_to_group("allies")
		ally.died.connect(func(_b: PkBot) -> void: _on_fighter_died(ally, false))
		parent.add_child(ally)
		_allies.append(ally)

	# Sinh các bot đối thủ (Team B: slot 0 .. team_size - 1)
	var team_b_data: Array = pk.get("team_b", [])
	for i in range(0, team_size):
		var bot_p: PlayerProfile = null
		if i == 0 and not opponent.is_empty():
			bot_p = PlayerProfile.from_dict(opponent)
		elif i < team_b_data.size() and team_b_data[i] is Dictionary and team_b_data[i].has("bot_data"):
			bot_p = PlayerProfile.from_dict(team_b_data[i]["bot_data"])
		elif i < team_b_data.size() and team_b_data[i] is Dictionary and team_b_data[i].has("name"):
			bot_p = PkBotProfile.create(int(team_b_data[i].get("level", GameManager.local_profile.level)), str(team_b_data[i].get("sect_id", "")))
		else:
			var sect_id := GameManager.local_profile.sect_id if mode == PkRules.Mode.DAI_HOI else ""
			bot_p = PkBotProfile.create(GameManager.local_profile.level, sect_id)
		var enemy := PkBot.new()
		enemy.name = "PkBot%d" % i
		enemy.setup(bot_p)
		enemy.position = _free_near(slots_b[i]) - feet
		enemy.pk_enemy = true
		enemy.cast_target_group = &"player"
		enemy.target = _player
		enemy.died.connect(func(_b: PkBot) -> void: _on_fighter_died(enemy, true))
		parent.add_child(enemy)
		_enemies.append(enemy)

	if not _enemies.is_empty():
		_bot = _enemies[0]
	_update_info()

## Tâm vùng trống liền lớn nhất quanh `around` (toạ độ map). Không có dữ liệu vật cản thì trả nguyên `around`.
func _arena_center(around: Vector2) -> Vector2:
	if PkRules.ARENA_CENTER != Vector2.ZERO:
		around = PkRules.ARENA_CENTER
	var map = VltkWorld.current.map if VltkWorld.current else null
	if map == null:
		return around
	map.prepare_around(around)
	var seen := {}
	var best: Array[Vector2i] = []
	var center_cell: Vector2i = map.world_to_cell(around)
	if not map.is_blocked(map.cell_to_world(center_cell)):
		best = _flood(map, center_cell, seen)
	if best.is_empty():
		var steps := int(ARENA_SEARCH_PX / ARENA_SAMPLE_PX)
		for gy in range(-steps, steps + 1):
			for gx in range(-steps, steps + 1):
				var seed: Vector2i = map.world_to_cell(around + Vector2(gx, gy) * ARENA_SAMPLE_PX)
				if seen.has(seed) or map.is_blocked(map.cell_to_world(seed)):
					continue
				var comp := _flood(map, seed, seen)
				if comp.size() > best.size():
					best = comp
	if best.is_empty():
		return around
	for c in best:
		_arena_cells[c] = true
	var sum := Vector2.ZERO
	for c in best:
		sum += map.cell_to_world(c)
	var mid := sum / best.size()
	var nearest := best[0]
	for c in best:
		if map.cell_to_world(c).distance_squared_to(mid) < map.cell_to_world(nearest).distance_squared_to(mid):
			nearest = c
	return map.cell_to_world(nearest)

static func _flood(map: Node, seed: Vector2i, seen: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var queue: Array[Vector2i] = [seed]
	seen[seed] = true
	while not queue.is_empty() and out.size() < ARENA_MAX_CELLS:
		var c: Vector2i = queue.pop_back()
		out.append(c)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and not map.is_blocked(map.cell_to_world(n)):
				seen[n] = true
				queue.append(n)
	return out

## Ô của sân đấu (_arena_cells) gần `p` nhất — không rơi vào túi trống nhỏ bị rào kín (lòng giá vũ khí...).
func _free_near(p: Vector2) -> Vector2:
	var map = VltkWorld.current.map if VltkWorld.current else null
	if map == null or _arena_cells.is_empty():
		return p
	var c: Vector2i = map.world_to_cell(p)
	if _arena_cells.has(c):
		return map.cell_to_world(c)
	for r in range(1, 60):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				for cand in [c + Vector2i(dx, dy), c + Vector2i(dy, dx)]:
					if _arena_cells.has(cand):
						return map.cell_to_world(cand)
	return p

func _process(delta: float) -> void:
	if _leave_in >= 0.0:
		_leave_in -= delta
		_clock.text = "Rời đấu trường sau %d giây" % ceili(maxf(_leave_in, 0.0))
		if _leave_in <= 0.0:
			_leave_in = -1.0
			_go_home()
		return
	if done:
		return
	_update_info()
	if not running:
		_prepare -= delta
		_clock.text = "Chuẩn bị %d" % ceili(maxf(_prepare, 0.0))
		if _prepare <= 0.0:
			_start_fight()
		return
	time_left -= delta
	_clock.text = TimeChallenge.format_time(maxi(0, ceili(time_left)))
	if time_left <= 0.0:
		var alive_a := _alive_count(_allies) + (1 if _player_alive() else 0)
		var alive_b := _alive_count(_enemies)
		if alive_a != alive_b:
			_finish(alive_a > alive_b, "Hết giờ — phe ta còn nhiều người sống sót hơn (%d vs %d)." % [alive_a, alive_b])
		else:
			var hp_a := _total_hp_ratio([_player] + _allies)
			var hp_b := _total_hp_ratio(_enemies)
			_finish(hp_a >= hp_b, "Hết giờ — %s còn nhiều sinh lực hơn." % ("bạn" if hp_a >= hp_b else "đối thủ"))

func _start_fight() -> void:
	running = true
	if _reject_button:
		_reject_button.visible = false
	for a in _allies:
		if is_instance_valid(a):
			a.invulnerable = false
			a.active = true
			a.target = _pick_target_for(a, _enemies)
	for e in _enemies:
		if is_instance_valid(e):
			e.invulnerable = false
			e.active = true
			var targets: Array = [_player]
			targets.append_array(_allies)
			e.target = _pick_target_for(e, targets)
	_say("Bắt đầu thi đấu thể thức %s!" % PkRules.format_name(team_size))

func _pick_target_for(_attacker: Node2D, candidate_group: Array) -> Node2D:
	var alive: Array[Node2D] = []
	for c in candidate_group:
		if c != null and is_instance_valid(c) and not (c.has_method("is_dead") and c.is_dead()):
			alive.append(c as Node2D)
	if alive.is_empty():
		return null
	return alive[randi() % alive.size()]

func _retarget_fighters() -> void:
	for a in _allies:
		if is_instance_valid(a) and not a.is_dead():
			if a.target == null or not is_instance_valid(a.target) or (a.target.has_method("is_dead") and a.target.is_dead()):
				a.target = _pick_target_for(a, _enemies)
	for e in _enemies:
		if is_instance_valid(e) and not e.is_dead():
			if e.target == null or not is_instance_valid(e.target) or (e.target.has_method("is_dead") and e.target.is_dead()):
				var targets: Array = [_player]
				targets.append_array(_allies)
				e.target = _pick_target_for(e, targets)

func _player_alive() -> bool:
	return _player != null and is_instance_valid(_player) and not (_player.has_method("is_dead") and _player.is_dead())

func _alive_count(bots: Array[PkBot]) -> int:
	var c := 0
	for b in bots:
		if is_instance_valid(b) and not b.is_dead():
			c += 1
	return c

func _on_reject_opponent() -> void:
	if done or running:
		return
	done = true
	running = false
	if _reject_button:
		_reject_button.visible = false
	for e in _enemies:
		if is_instance_valid(e):
			e.active = false
			e.queue_free()
	_enemies.clear()
	for a in _allies:
		if is_instance_valid(a):
			a.active = false
			a.queue_free()
	_allies.clear()
	_bot = null
	_title.text = "TỪ CHỐI ĐỐI THỦ"
	_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_clock.text = "Trận đấu không bắt đầu"
	_say("Đã từ chối đối thủ. Trận đấu không bắt đầu.")
	_leave_in = 3.0

func _on_fighter_died(_fighter: PkBot, _is_enemy: bool) -> void:
	if not running or done:
		return
	var alive_enemies := _alive_count(_enemies)
	var alive_allies := _alive_count(_allies) + (1 if _player_alive() else 0)
	if alive_enemies == 0:
		_finish(true, "Đối phương đã bị quét sạch!")
	elif alive_allies == 0:
		_finish(false, "Toàn đội đã trọng thương!")
	else:
		_retarget_fighters()

func _on_bot_died(_b: PkBot) -> void:
	_on_fighter_died(_b, true)

func _on_player_died() -> void:
	if not done:
		var alive_allies := _alive_count(_allies)
		if alive_allies == 0:
			_finish(false, "Bạn và toàn đội đã trọng thương.")
		else:
			_say("Bạn đã trọng thương! Đang theo dõi đồng đội tiếp tục chiến đấu...")
			_retarget_fighters()

func _finish(win: bool, why: String) -> void:
	if done:
		return
	done = true
	running = false
	if _reject_button:
		_reject_button.visible = false
	for a in _allies:
		if is_instance_valid(a):
			a.active = false
			a.invulnerable = true
	for e in _enemies:
		if is_instance_valid(e):
			e.active = false
			e.invulnerable = true
	var delta := record_result(mode, win)
	var pts_text := ""
	if delta != 0:
		pts_text = " (+%d điểm)" % delta if delta > 0 else " (%d điểm)" % delta
	_title.text = ("THẮNG" if win else "THUA") + pts_text
	_title.add_theme_color_override("font_color", GameUi.GOLD if win else Color(1.0, 0.4, 0.4))
	var say_text := why
	if delta != 0 and GameManager.local_profile:
		say_text += " (Điểm BXH: %d)" % GameManager.local_profile.pk_points
	_say(say_text)
	_leave_in = PkRules.LEAVE_AFTER_SEC

func _go_home() -> void:
	GameManager.field_map = {}
	GameManager.is_game_over = false
	get_tree().change_scene_to_file(HUB_SCENE)

static func _hp_ratio(node: Node) -> float:
	if node == null or not is_instance_valid(node) or not ("health" in node) or not ("max_health" in node):
		return 0.0
	return float(node.health) / maxf(float(node.max_health), 1.0)

static func _total_hp_ratio(group: Array) -> float:
	var total_hp := 0.0
	var total_max := 0.0
	for node in group:
		if node != null and is_instance_valid(node) and ("health" in node) and ("max_health" in node):
			total_hp += float(node.health)
			total_max += maxf(float(node.max_health), 1.0)
	return total_hp / maxf(total_max, 1.0)

# ---------------------------------------------------------------- thành tích (cục bộ)

static func _records() -> Dictionary:
	if not FileAccess.file_exists(RECORD_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORD_PATH))
	return parsed if parsed is Dictionary else {}

## {win, lose, points} của nhân vật ở chế độ `m`.
static func record_of(profile: PlayerProfile, m: PkRules.Mode) -> Dictionary:
	if profile == null:
		return {"win": 0, "lose": 0, "points": 0}
	var r: Dictionary = _records().get(profile.display_name, {}).get(str(m), {"win": 0, "lose": 0, "points": 0})
	if not r.has("points") and profile:
		r["points"] = profile.pk_points
	return r

func _record(win: bool) -> void:
	record_result(mode, win)

## Ghi 1 trận thắng / thua ở chế độ `m` cho nhân vật đang chơi (trận bot PkMatch + trận online ArenaClient).
## Trả về số điểm thay đổi (+10, -2, hoặc 0).
static func record_result(m: PkRules.Mode, win: bool) -> int:
	var profile := GameManager.local_profile
	var delta := 0
	if PkRules.has_rank_points(m):
		delta = PkRules.WIN_POINTS if win else -PkRules.LOSE_POINTS
		if profile:
			profile.pk_points = maxi(0, profile.pk_points + delta)
	if profile == null or OS.has_environment("KIEMHIEP_NO_SAVE"):
		return delta
	var rec := _records()
	var mine: Dictionary = rec.get(profile.display_name, {})
	var r: Dictionary = mine.get(str(m), {"win": 0, "lose": 0})
	r["win" if win else "lose"] = int(r.get("win" if win else "lose", 0)) + 1
	r["points"] = profile.pk_points
	mine[str(m)] = r
	rec[profile.display_name] = mine
	var f := FileAccess.open(RECORD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rec))
	return delta

# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 20
	add_child(_hud)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-220, 52)
	box.custom_minimum_size = Vector2(440, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	var title_text: String = ("%s [%s]" % [str(PkRules.MODE_NAMES.get(mode, "")), PkRules.format_name(team_size)]) if mode == PkRules.Mode.THACH_DAU else str(PkRules.MODE_NAMES.get(mode, ""))
	_title = _hud_label(title_text, 18, GameUi.GOLD)
	_clock = _hud_label("", 26, Color(1, 1, 1))
	_info = _hud_label("", 14, GameUi.TEXT)
	for l in [_title, _clock, _info]:
		box.add_child(l)
	if PkRules.can_kick(mode):
		_reject_button = GameUi.button("Từ chối đối thủ")
		_reject_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_reject_button.pressed.connect(_on_reject_opponent)
		box.add_child(_reject_button)

func _hud_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _update_info() -> void:
	if _info == null:
		return
	if team_size > 1:
		var alive_a := _alive_count(_allies) + (1 if _player_alive() else 0)
		var alive_b := _alive_count(_enemies)
		_info.text = "Thể thức: %s   ·   Phe ta: %d/%d sống   vs   Phe địch: %d/%d sống" % [
			PkRules.format_name(team_size), alive_a, team_size, alive_b, team_size
		]
	elif _bot and _bot.profile:
		var sect := SectRegistry.get_by_id(_bot.profile.sect_id)
		_info.text = "Đối thủ: %s · Cấp %d · %s   ·   Sinh lực %d%%   ·   Thuốc %d" % [_bot.profile.display_name, _bot.profile.level,
				sect.sect_name if sect else "?", roundi(_hp_ratio(_bot) * 100.0), _bot.potions_left]

func _say(text: String) -> void:
	if _player and _player.has_method("notify"):
		_player.notify(text)
