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
var time_left := PkRules.FIGHT_SEC
var running := false
var done := false
var _prepare := PkRules.PREPARE_SEC
var _leave_in := -1.0
var _player: Node2D
var _bot: PkBot
var _hud: CanvasLayer
var _title: Label
var _clock: Label
var _info: Label
var _arena_cells := {}                   ## ô (Vector2i) của sân đấu đang dùng — đặt người chỉ trong vùng này

func _ready() -> void:
	var pk: Dictionary = GameManager.field_map.get("pk", {})
	mode = int(pk.get("mode", PkRules.Mode.LIEN_DAU)) as PkRules.Mode
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
	_say("%s: còn %d giây nữa bắt đầu." % [PkRules.MODE_NAMES[mode], int(PkRules.PREPARE_SEC)])

func _spawn_bot(opponent: Dictionary) -> void:
	var parent := VltkWorld.entity_parent()
	if parent == null or _player == null:
		push_warning("PkMatch: chưa có map / nhân vật")
		return
	var bot_profile := PlayerProfile.from_dict(opponent) if not opponent.is_empty() else PkBotProfile.create(GameManager.local_profile.level)
	_bot = PkBot.new()
	_bot.name = "PkBot"
	_bot.setup(bot_profile)
	var center := _arena_center(_player.global_position)
	## Ô trống tính theo CHÂN; gốc node = thân (chân thấp hơn FEET_OFFSET).
	var feet := Vector2(0, PkBot.FEET_OFFSET)
	_player.global_position = _free_near(center - Vector2(FIGHTER_GAP, 0)) - feet
	_bot.position = _free_near(center + Vector2(FIGHTER_GAP, 0)) - feet
	_bot.target = _player
	_bot.died.connect(_on_bot_died)
	parent.add_child(_bot)
	_update_info()

## Tâm vùng trống liền lớn nhất quanh `around` (toạ độ map). Không có dữ liệu vật cản thì trả nguyên `around`.
func _arena_center(around: Vector2) -> Vector2:
	var map = VltkWorld.current.map if VltkWorld.current else null
	if map == null:
		return around
	map.prepare_around(around)
	var seen := {}
	var best: Array[Vector2i] = []
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
		var mine := _hp_ratio(_player)
		var theirs := _hp_ratio(_bot)
		_finish(mine > theirs, "Hết giờ — %s còn nhiều sinh lực hơn." % ("bạn" if mine > theirs else "đối thủ"))

func _start_fight() -> void:
	running = true
	if _bot:
		_bot.invulnerable = false
		_bot.active = true
	_say("Bắt đầu thi đấu!")

func _on_bot_died(_b: PkBot) -> void:
	if running and not done:
		_finish(true, "Đối thủ đã trọng thương.")

func _on_player_died() -> void:
	if not done:
		_finish(false, "Bạn đã trọng thương.")

func _finish(win: bool, why: String) -> void:
	if done:
		return
	done = true
	running = false
	if _bot:
		_bot.active = false
		_bot.invulnerable = true
	_title.text = "THẮNG" if win else "THUA"
	_title.add_theme_color_override("font_color", GameUi.GOLD if win else Color(1.0, 0.4, 0.4))
	_say(why)
	_record(win)
	_leave_in = PkRules.LEAVE_AFTER_SEC

func _go_home() -> void:
	GameManager.field_map = {}
	GameManager.is_game_over = false
	get_tree().change_scene_to_file(HUB_SCENE)

static func _hp_ratio(node: Node) -> float:
	if node == null or not is_instance_valid(node) or not ("health" in node) or not ("max_health" in node):
		return 0.0
	return float(node.health) / maxf(float(node.max_health), 1.0)

# ---------------------------------------------------------------- thành tích (cục bộ)

static func _records() -> Dictionary:
	if not FileAccess.file_exists(RECORD_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORD_PATH))
	return parsed if parsed is Dictionary else {}

## {win, lose} của nhân vật ở chế độ `m`.
static func record_of(profile: PlayerProfile, m: PkRules.Mode) -> Dictionary:
	if profile == null:
		return {"win": 0, "lose": 0}
	return _records().get(profile.display_name, {}).get(str(m), {"win": 0, "lose": 0})

func _record(win: bool) -> void:
	var profile := GameManager.local_profile
	if profile == null or OS.has_environment("KIEMHIEP_NO_SAVE"):
		return
	var rec := _records()
	var mine: Dictionary = rec.get(profile.display_name, {})
	var r: Dictionary = mine.get(str(mode), {"win": 0, "lose": 0})
	r["win" if win else "lose"] = int(r.get("win" if win else "lose", 0)) + 1
	mine[str(mode)] = r
	rec[profile.display_name] = mine
	var f := FileAccess.open(RECORD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rec))

# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 20
	add_child(_hud)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-180, 8)
	box.custom_minimum_size = Vector2(360, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	_title = _hud_label(PkRules.MODE_NAMES[mode], 18, GameUi.GOLD)
	_clock = _hud_label("", 26, Color(1, 1, 1))
	_info = _hud_label("", 14, GameUi.TEXT)
	for l in [_title, _clock, _info]:
		box.add_child(l)

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
	if _info == null or _bot == null or _bot.profile == null:
		return
	var sect := SectRegistry.get_by_id(_bot.profile.sect_id)
	_info.text = "Đối thủ: %s · Cấp %d · %s   ·   Sinh lực %d%%   ·   Thuốc %d" % [_bot.profile.display_name, _bot.profile.level,
			sect.sect_name if sect else "?", roundi(_hp_ratio(_bot) * 100.0), _bot.potions_left]

func _say(text: String) -> void:
	if _player and _player.has_method("notify"):
		_player.notify(text)
