extends Node
class_name LinhLungThapChallenge

## ẢI LINH LUNG THÁP — Đấu trường vượt tháp 7 tầng & Cầm Long Trụ
## Chuẩn theo phiên bản Võ Lâm Truyền Kỳ 2.0 (Hoàng Kim Phong Mã):
## 1. Phòng Chờ 5 Phút: Báo danh vào Map #1037 đếm ngược 5 phút chờ đấu thủ.
## 2. Cơ chế Ẩn Danh: Nhân vật và toàn bộ đấu thủ đổi tên thành "Người Bí Ẩn".
## 3. Sinh Tồn Hỗn Chiến: Quái thủ tháp và Người Bí Ẩn cùng tồn tại trên từng tầng.
## 4. Thăng Tầng: Tiêu diệt quái (+1 tiến độ) hoặc hạ Người Bí Ẩn (+3 tiến độ) để lên tầng cao hơn.
## 5. Giáng Tầng (Loại Trừ): Bị hạ gục tại Tầng N (N >= 2) sẽ bị rơi tụt xuống Tầng N - 1.
## 6. Cầm Long Trụ: Đứng trong phạm vi trụ (250px) để tích lũy điểm cá nhân định kỳ mỗi 3 giây.
## 7. Phần thưởng: Rương Linh Lung Tháp Đoạt Khôi, Đúc Thiết, Huyền Tinh và EXP dồi dào.

signal finished(success: bool, score: int, max_floor: int)

const DATA_PATH := "res://data/challenge/linh_lung_thap_challenge.json"
const RECORD_PATH := "user://linh_lung_thap.json"
const ENTRY_ITEM_ID := "4_999_0"
const ENTRY_ITEM_NAME := "Lệnh Bài Linh Lung Tháp"
const CHEST_ITEM_ID := "4_999_1"
const CHEST_ITEM_NAME := "Rương Linh Lung Tháp Đoạt Khôi"
const ENTRY_FEE := 50000
const MIN_LEVEL := 80
const MIN_PLAYERS := 5
const RUNS_PER_DAY := 3
const TIME_LIMIT_SEC := 1500.0  ## 25 phút chuẩn VNG
const TOTAL_FLOORS := 7
const PILLAR_RANGE := 250.0
const PILLAR_TICK_SEC := 3.0
const LEAVE_AFTER_SEC := 10.0
const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"

const CountdownOverlay = preload("res://ui/common/countdown_overlay.gd")

static var _data: Dictionary = {}

## Runtime variables
var current_floor := 1
var floor_score := 0
var kills_in_floor := 0
var score := 0
var time_left := TIME_LIMIT_SEC
var running := false
var done := false
var max_floor_reached := 1
var _leave_in := -1.0
var _pillar_timer := 0.0
var _is_capturing := false
var _orig_player_name := ""
var _player: Node2D
var _alive: Array[VltkMonster] = []
var _alive_bots: Array[PkBot] = []
var _pillar_node: Node2D

const MONSTER_RESPAWN_SEC := 6.0
var _respawn_queue: Array[Dictionary] = []
var _bot_climb_timer := 25.0
var _bot_advance_timer := 35.0

## HUD nodes
var _hud: CanvasLayer
var _floor_label: Label
var _kills_label: Label
var _score_label: Label
var _clock_label: Label
var _pillar_status_label: Label

# ---------------------------------------------------------------- DỮ LIỆU & QUY TẮC BÁO DANH

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data

static func rules() -> Dictionary:
	return data().get("rules", {})

static func floors() -> Array:
	return data().get("floors", [])

static func floor_data(f_idx: int) -> Dictionary:
	var fls := floors()
	if f_idx >= 1 and f_idx <= fls.size():
		return fls[f_idx - 1]
	return {}

static func target_floor_score(fl: int) -> int:
	var fd := floor_data(fl)
	return int(fd.get("target_score", 150 + (fl - 1) * 100))

static func map_entry() -> Dictionary:
	var d := data()
	return {
		"id": int(d.get("map", 1038)),
		"name": "Linh Lung Tháp",
		"dir": str(d.get("map_dir", "res://world/maps/map_1038")),
		"level": MIN_LEVEL,
		"linh_lung_thap": true
	}

static func prep_map_entry() -> Dictionary:
	var d := data()
	return {
		"id": int(d.get("prep_map", 1037)),
		"name": "Khu Chuẩn Bị Linh Lung Tháp",
		"dir": str(d.get("prep_map_dir", "res://world/maps/map_1037")),
		"level": MIN_LEVEL,
		"linh_lung_prep": true
	}

static func _records() -> Dictionary:
	if not FileAccess.file_exists(RECORD_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORD_PATH))
	return parsed if parsed is Dictionary else {}

static func _save_records(rec: Dictionary) -> void:
	var f := FileAccess.open(RECORD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rec, " "))

static func _key(profile: PlayerProfile) -> String:
	return profile.display_name if profile and profile.display_name != "" else "local"

static func _today() -> String:
	return Time.get_date_string_from_system()

static func runs_today(profile: PlayerProfile) -> int:
	var r: Dictionary = _records().get(_key(profile), {})
	return int(r.get("runs", {}).get(_today(), 0))

static func best_floor(profile: PlayerProfile) -> int:
	return int(_records().get(_key(profile), {}).get("best_floor", 0))

static func best_score(profile: PlayerProfile) -> int:
	return int(_records().get(_key(profile), {}).get("best_score", 0))

static func format_time(sec: int) -> String:
	var m := int(sec / 60)
	var s := sec % 60
	return "%02d:%02d" % [m, s]

static func _money(amount: int) -> String:
	if amount >= 10000:
		return "%s vạn" % String.num(float(amount) / 10000.0, 1).trim_suffix(".0")
	return str(amount)

static func entry_item_count(profile: PlayerProfile) -> int:
	if profile == null:
		return 0
	var n := 0
	for it in profile.inventory:
		if it != null and (it.misc_id == ENTRY_ITEM_ID or it.get_base().get("name", "") == ENTRY_ITEM_NAME):
			n += maxi(it.count, 1)
	return n

static func check_entry(profile: PlayerProfile) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var api = tree.root.get_node_or_null("AccountApi")
		if api != null and api.has_method("is_gm") and api.is_gm():
			return ""
	if profile == null:
		return "Chưa có nhân vật."
	if profile.level < MIN_LEVEL:
		return "Cần đạt đẳng cấp %d (8x) trở lên mới có thể khiêu chiến Linh Lung Tháp." % MIN_LEVEL
	if runs_today(profile) >= RUNS_PER_DAY:
		return "Hôm nay đại hiệp đã tham gia đủ %d lượt Linh Lung Tháp. Hãy quay lại vào ngày mai!" % RUNS_PER_DAY
	var item_cnt := entry_item_count(profile)
	if item_cnt <= 0 and profile.gold < ENTRY_FEE:
		return "Cần 1 %s hoặc %s lượng để báo danh." % [ENTRY_ITEM_NAME, _money(ENTRY_FEE)]
	return ""

static func pay_entry(profile: PlayerProfile) -> bool:
	if check_entry(profile) != "":
		return false
	var used_item := false
	for i in profile.inventory.size():
		var it: ItemInstance = profile.inventory[i]
		if it != null and (it.misc_id == ENTRY_ITEM_ID or it.get_base().get("name", "") == ENTRY_ITEM_NAME):
			if it.count > 1:
				it.count -= 1
			else:
				profile.inventory.remove_at(i)
			used_item = true
			break
	if not used_item:
		profile.gold = maxi(0, profile.gold - ENTRY_FEE)

	# Ghi nhận số lượt hôm nay
	var rec := _records()
	var k := _key(profile)
	var p: Dictionary = rec.get_or_add(k, {})
	var runs: Dictionary = p.get_or_add("runs", {})
	runs[_today()] = int(runs.get(_today(), 0)) + 1
	_save_records(rec)
	return true

## Tặng 1 Lệnh bài vào hành trang để thử nghiệm
static func claim_test_item(profile: PlayerProfile) -> bool:
	if profile == null:
		return false
	var it: ItemInstance = ItemGenerator.generate_misc(ENTRY_ITEM_ID)
	if it == null:
		it = ItemInstance.new()
		it.misc_id = ENTRY_ITEM_ID
		it.count = 1
	profile.inventory.append(it)
	return true

# ---------------------------------------------------------------- RUNTIME GAMEPLAY

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		if "display_name" in _player:
			_orig_player_name = str(_player.display_name)
			_player.display_name = "Người Bí Ẩn"
		if "suppress_death_popup" in _player:
			_player.suppress_death_popup = true
		var e_pos: Array = data().get("entry", [51200, 101888])
		_player.position = Vector2(float(e_pos[0]), float(e_pos[1]) * 0.5)
		if _player.has_signal("died"):
			_player.died.connect(_on_player_died)

	_build_hud()
	_spawn_pillar()
	_say("Đại hiệp đã tiến vào Linh Lung Tháp! Danh tính ẩn danh: Người Bí Ẩn.")

	CountdownOverlay.start(self, func() -> void:
		if not running:
			running = true
			_enter_floor(1)
	)

func _exit_tree() -> void:
	# Khôi phục tên gốc và popup cái chết cho nhân vật khi rời khỏi tháp
	if _player != null and is_instance_valid(_player):
		if "display_name" in _player and _orig_player_name != "":
			_player.display_name = _orig_player_name
		if "suppress_death_popup" in _player:
			_player.suppress_death_popup = false

	for b in _alive_bots:
		if is_instance_valid(b):
			b.queue_free()
	_alive_bots.clear()

func _process(delta: float) -> void:
	if _leave_in > 0.0:
		_leave_in -= delta
		if _leave_in <= 0.0:
			_leave_in = -1.0
			_return_player_to_city()
		return

	if not running or done:
		return

	# Đếm ngược thời gian
	time_left = maxf(0.0, time_left - delta)
	if _clock_label != null:
		_clock_label.text = "⏱️ %s" % format_time(int(ceil(time_left)))

	if time_left <= 0.0:
		_finish(false, "Hết thời gian khiêu chiến!")
		return

	# Dọn dẹp quái đã chết / không còn hợp lệ trong mảng _alive
	for i in range(_alive.size() - 1, -1, -1):
		var m := _alive[i]
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			_alive.remove_at(i)

	# Dọn dẹp bot đã chết / không còn hợp lệ trong mảng _alive_bots
	for i in range(_alive_bots.size() - 1, -1, -1):
		var b := _alive_bots[i]
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			_alive_bots.remove_at(i)

	# 1. Hồi sinh quái liên tục sau khi chết (MONSTER_RESPAWN_SEC = 6s)
	for i in range(_respawn_queue.size() - 1, -1, -1):
		var r: Dictionary = _respawn_queue[i]
		r["time"] = float(r.get("time", 0.0)) - delta
		if float(r["time"]) <= 0.0:
			_respawn_queue.remove_at(i)
			if int(r.get("floor", 0)) == current_floor and running and not done:
				_spawn_monster(int(r["tpl"]), int(r["lvl"]), r["pos"] as Vector2, int(r["hp"]), str(r["mname"]))
				_update_hud()

	# 2. Đối thủ Người Bí Ẩn từ tầng dưới leo lên tầng hiện tại
	if current_floor > 1 and _alive_bots.size() < 4:
		_bot_climb_timer -= delta
		if _bot_climb_timer <= 0.0:
			_bot_climb_timer = randf_range(22.0, 35.0)
			_spawn_bot_competitor(true)
			_say("⚡ [Thông Báo Tháp] 1 Người Bí Ẩn vừa thăng lên Tầng %d!" % current_floor)

	# 3. Đối thủ Người Bí Ẩn trên tầng hiện tại đủ điểm thăng lên tầng trên
	if current_floor < TOTAL_FLOORS and _alive_bots.size() >= 2:
		_bot_advance_timer -= delta
		if _bot_advance_timer <= 0.0:
			_bot_advance_timer = randf_range(30.0, 45.0)
			var promoted_bot: PkBot = _alive_bots[randi() % _alive_bots.size()]
			if is_instance_valid(promoted_bot):
				_alive_bots.erase(promoted_bot)
				promoted_bot.queue_free()
				_say("⚡ [Thông Báo Tháp] 1 Người Bí Ẩn đã đủ điểm thăng lên Tầng %d!" % (current_floor + 1))
				_update_hud()

	# Quét kiểm tra người chơi đứng trong phạm vi Cầm Long Trụ
	_check_pillar_capture(delta)

func _check_pillar_capture(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _pillar_node == null:
		return

	var dx: float = _player.position.x - _pillar_node.position.x
	var dy: float = (_player.position.y - _pillar_node.position.y) * 2.0
	var inside: bool = (dx * dx + dy * dy) <= (PILLAR_RANGE * PILLAR_RANGE)

	if inside != _is_capturing:
		_is_capturing = inside
		if _pillar_status_label != null:
			if _is_capturing:
				_pillar_status_label.text = "🟢 Đang chiếm trụ (+%dđ/3s)" % _current_pillar_pts()
				_pillar_status_label.modulate = Color(0.3, 1.0, 0.4)
			else:
				_pillar_status_label.text = "⚪ Chưa vào trụ"
				_pillar_status_label.modulate = Color(0.8, 0.8, 0.8)

	if _is_capturing:
		_pillar_timer += delta
		if _pillar_timer >= PILLAR_TICK_SEC:
			_pillar_timer = 0.0
			var pts := _current_pillar_pts()
			_add_score(pts, "Cầm Long Trụ")

func _add_score(pts: int, reason: String = "") -> void:
	if done:
		return
	score += pts
	floor_score += pts
	if reason != "":
		_say_floating("+%d Điểm (%s)" % [pts, reason])
	_update_hud()
	_check_floor_advance()

func _check_floor_advance() -> void:
	if done:
		return
	var target := target_floor_score(current_floor)
	if floor_score >= target:
		if current_floor < TOTAL_FLOORS:
			_say("🎉 CHÚC MỪNG! Đạt %d/%d Điểm Tầng, thăng lên TẦNG %d!" % [floor_score, target, current_floor + 1])
			_enter_floor(current_floor + 1)
		else:
			_finish(true, "Tuyệt đỉnh cao thủ! Đại hiệp đã chinh phục thành công Tầng 7 Linh Lung Tháp!")

func _current_pillar_pts() -> int:
	var fd := floor_data(current_floor)
	return int(fd.get("pillar_pts", 10 * current_floor))

func _say_floating(msg: String) -> void:
	if _player != null and _player.has_method("notify"):
		_player.notify(msg)

func _say(msg: String) -> void:
	if _player != null and _player.has_method("notify"):
		_player.notify(msg)

# ---------------------------------------------------------------- CƠ CHẾ LÊN / XUỐNG TẦNG

func _world_entity_parent() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var w = tree.root.get_node_or_null("World")
		if w != null and w.has_method("entity_parent"):
			var p = w.entity_parent()
			if p != null:
				return p
	var vw: GDScript = load("res://world/vltk_world.gd")
	if vw != null and vw.has_method("entity_parent"):
		var p = vw.entity_parent()
		if p != null:
			return p
	return get_parent() if get_parent() != null else self

func _enter_floor(fl: int) -> void:
	current_floor = clampi(fl, 1, TOTAL_FLOORS)
	max_floor_reached = maxi(max_floor_reached, current_floor)
	floor_score = 0
	kills_in_floor = 0

	# Dọn dẹp quái cũ
	for m in _alive:
		if is_instance_valid(m):
			m.queue_free()
	_alive.clear()

	# Dọn dẹp bot đối thủ cũ
	for b in _alive_bots:
		if is_instance_valid(b):
			b.queue_free()
	_alive_bots.clear()

	_respawn_queue.clear()
	_bot_climb_timer = randf_range(20.0, 30.0)
	_bot_advance_timer = randf_range(30.0, 45.0)

	var fd := floor_data(current_floor)
	var fname := str(fd.get("name", "Tầng %d" % current_floor))
	_say("⚡ TIẾN VÀO: %s!" % fname)

	var ppos: Array = data().get("pillar_pos", [51225, 102384])
	var center := Vector2(float(ppos[0]), float(ppos[1]) * 0.5)

	# 1. Sinh quái thủ vệ chuẩn phong cách Lâm Du Quan (Bôn Lôi #588 & Ngân Nha #589 xen kẽ)
	var count := int(fd.get("monster_count", 10))
	var lvl := int(fd.get("monster_level", 80 + current_floor * 2))
	var spawn_pts: Array = data().get("spawn_points", [])

	for i in count:
		var mpos := Vector2.ZERO
		if not spawn_pts.is_empty():
			var p: Array = spawn_pts[i % spawn_pts.size()]
			mpos = Vector2(float(p[0]), float(p[1]))
		else:
			var angle := (float(i) / float(count)) * TAU
			mpos = center + Vector2(cos(angle) * 230.0, sin(angle) * 140.0)

		# Quái Lâm Du Quan: xen kẽ Bôn Lôi (588) và Ngân Nha (589)
		var tpl := 588 if (i % 2 == 0) else 589
		var mname := "Bôn Lôi" if tpl == 588 else "Ngân Nha"
		# Máu chuẩn quái Lâm Du Quan (12600 gốc) giảm 1/2 riêng cho Linh Lung Tháp
		var hp := int((12600 + (current_floor - 1) * 1500) * 0.5)
		_spawn_monster(tpl, lvl, mpos, hp, mname)

	# 2. Sinh các đối thủ "Người Bí Ẩn" cùng khiêu chiến trên tầng (PK Sinh Tồn)
	var bot_count := 4 if current_floor <= 2 else (3 if current_floor <= 4 else (2 if current_floor <= 6 else 1))
	for bi in bot_count:
		_spawn_bot_competitor(false)

	_update_hud()

func _spawn_bot_competitor(at_entry: bool = false) -> void:
	var parent := _world_entity_parent()
	if parent == null or done or not running:
		return
	var lvl := int(floor_data(current_floor).get("monster_level", 80 + current_floor * 2))
	var bot_prof := PkBotProfile.create(lvl)
	bot_prof.display_name = "Người Bí Ẩn"

	var bot := PkBot.new()
	bot.setup(bot_prof)
	bot.max_health = 50000.0 + current_floor * 12500.0
	bot.health = bot.max_health

	if at_entry:
		var e_pos: Array = data().get("entry", [51200, 101888])
		bot.position = Vector2(float(e_pos[0]), float(e_pos[1]) * 0.5)
	else:
		var ppos: Array = data().get("pillar_pos", [51225, 102384])
		var center := Vector2(float(ppos[0]), float(ppos[1]) * 0.5)
		var b_angle := randf() * TAU
		bot.position = center + Vector2(cos(b_angle) * 180.0, sin(b_angle) * 100.0)

	bot.active = true
	bot.invulnerable = false
	bot.add_to_group("enemies")
	bot.pk_enemy = true
	bot.set_name_color(Color(1.0, 0.4, 0.4), "[Người Bí Ẩn]")
	bot.died.connect(_on_bot_died.bind(bot))
	parent.add_child(bot)
	_alive_bots.append(bot)
	_update_hud()

func _spawn_monster(tpl: int, lvl: int, pos: Vector2, hp: int, mname: String) -> void:
	var base := MonsterData.monster(tpl)
	var parent := _world_entity_parent()
	if base.is_empty() or parent == null:
		return
	var m_script: GDScript = load("res://systems/monster/vltk_monster.gd")
	if m_script == null or not m_script.can_instantiate():
		return
	var m = m_script.new()
	m.monster_id = tpl
	m.data = base.duplicate()
	m.data["name"] = mname
	m.data["series"] = randi() % 5
	m.level = lvl

	# Thiết lập cách đánh & AI chuẩn Lâm Du Quan:
	# - Tầm nhìn rộng (vision = 450), tầm hoạt động (active = 800)
	# - Tốc độ ra chiêu & di chuyển chuẩn VLTK (attack_speed 18, cast_speed 18, speed 6)
	# - AI Mode 1 với tỉ lệ chiêu tầm xa 75% (bắn chưởng sấm sét/ngũ hành), cận chiến 25% khi áp sát
	m.data["vision"] = 450
	m.data["active"] = 800
	m.data["attack_speed"] = 18
	m.data["cast_speed"] = 18
	m.data["walk_speed"] = 6
	m.data["run_speed"] = 6
	m.data["ai_mode"] = 1
	m.data["ai_params"] = [50, 38, 12, 37, 13, 30, 50, 0, 0]

	# Giảm máu và dame của quái xuống 1/2 (chỉ riêng màn chơi Linh Lung Tháp)
	m.hp_override = maxi(1, hp)
	m.moba_damage_multiplier = 0.5
	m.position = pos
	m.died.connect(_on_monster_died.bind(m))
	parent.add_child(m)
	_alive.append(m)

func _on_bot_died(bot: PkBot) -> void:
	if bot != null:
		_alive_bots.erase(bot)
	if done:
		return

	# Hạ gục đối thủ Người Bí Ẩn: Thưởng lớn +100 điểm tầng và điểm tổng
	kills_in_floor += 1
	_add_score(100, "Hạ Đối Thủ Bí Ẩn")
	if current_floor > 1:
		_say("⚔️ Đã hạ gục 1 Người Bí Ẩn! (+100 Điểm). Đối thủ bị đánh rớt xuống Tầng %d!" % (current_floor - 1))
	else:
		_say("⚔️ Đã hạ gục 1 Người Bí Ẩn! (+100 Điểm) tại Tầng 1!")

	# Rút ngắn thời gian đối thủ tiếp theo từ tầng dưới thăng lên
	_bot_climb_timer = randf_range(12.0, 20.0)

func _on_monster_died(m: VltkMonster = null) -> void:
	if m != null:
		_alive.erase(m)
		# Đưa quái vào hàng đợi hồi sinh liên tục sau 6 giây
		var hp := int((12600 + (current_floor - 1) * 1500) * 0.5)
		_respawn_queue.append({
			"time": MONSTER_RESPAWN_SEC,
			"tpl": m.monster_id,
			"lvl": m.level,
			"pos": m.position,
			"hp": hp,
			"mname": m.data.get("name", "Bôn Lôi"),
			"floor": current_floor
		})
	if done:
		return

	kills_in_floor += 1
	# Điểm thưởng diệt quái cộng thẳng vào điểm tầng
	var pts := 15 * current_floor
	_add_score(pts, "Diệt Quái")

func _on_player_died() -> void:
	if done:
		return

	if current_floor > 1:
		current_floor -= 1
		floor_score = 0
		_say("⚠️ BỊ HẠ GỤC! Đại hiệp bị đánh rớt xuống TẦNG %d Linh Lung Tháp!" % current_floor)
	else:
		floor_score = maxi(0, floor_score - 30)
		_say("⚠️ BỊ HẠ GỤC! Bị trừ 30 điểm tầng, hồi sinh tại Tầng 1!")

	# Hồi sinh và dịch chuyển tức thời về cửa tầng
	if _player != null and is_instance_valid(_player):
		if _player.has_method("revive"):
			_player.revive()
		var e_pos: Array = data().get("entry", [51200, 101888])
		var respawn_pos := Vector2(float(e_pos[0]), float(e_pos[1]) * 0.5)
		if _player.has_method("respawn_at"):
			_player.respawn_at(respawn_pos)
		else:
			_player.position = respawn_pos

	_enter_floor(current_floor)

# ---------------------------------------------------------------- KẾT THÚC VÀ TRAO THƯỞNG

func _finish(success: bool, reason_msg: String) -> void:
	done = true
	running = false

	# Dọn dẹp quái và bot
	for m in _alive:
		if is_instance_valid(m):
			m.queue_free()
	_alive.clear()

	for b in _alive_bots:
		if is_instance_valid(b):
			b.queue_free()
	_alive_bots.clear()

	# Khôi phục tên gốc và popup cái chết cho nhân vật
	if _player != null and is_instance_valid(_player):
		if "display_name" in _player and _orig_player_name != "":
			_player.display_name = _orig_player_name
		if "suppress_death_popup" in _player:
			_player.suppress_death_popup = false

	# Trao phần thưởng
	var profile: PlayerProfile = null
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		if gm != null and "local_profile" in gm:
			profile = gm.local_profile
	var exp_gained := score * 250
	var got_chest := false

	if profile != null:
		if profile.has_method("add_exp"):
			profile.add_exp(exp_gained)
		elif profile.has_method("gain_exp"):
			profile.gain_exp(exp_gained)
		# Nếu chinh phục tới tầng 5 trở lên hoặc điểm >= 500 thì nhận Rương Đoạt Khôi
		if current_floor >= 5 or score >= 500:
			var chest_it: ItemInstance = ItemGenerator.generate_misc(CHEST_ITEM_ID)
			if chest_it == null:
				chest_it = ItemInstance.new()
				chest_it.misc_id = CHEST_ITEM_ID
				chest_it.count = 1
			profile.inventory.append(chest_it)
			got_chest = true

		# Lưu kỷ lục
		var rec := _records()
		var k := _key(profile)
		var p: Dictionary = rec.get_or_add(k, {})
		p["best_floor"] = maxi(int(p.get("best_floor", 0)), max_floor_reached)
		p["best_score"] = maxi(int(p.get("best_score", 0)), score)
		_save_records(rec)

	_show_result_popup(success, reason_msg, exp_gained, got_chest)
	finished.emit(success, score, max_floor_reached)
	_leave_in = LEAVE_AFTER_SEC

func _show_result_popup(success: bool, reason: String, exp: int, got_chest: bool) -> void:
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(520, 320)
	popup.anchors_preset = Control.PRESET_CENTER
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	sbox.border_color = Color(0.9, 0.75, 0.3)
	sbox.set_border_width_all(2)
	sbox.set_corner_radius_all(10)
	sbox.content_margin_left = 24
	sbox.content_margin_right = 24
	sbox.content_margin_top = 20
	sbox.content_margin_bottom = 20
	popup.add_theme_stylebox_override("panel", sbox)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	popup.add_child(vb)

	var title := Label.new()
	title.text = "🏯 TỔNG KẾT CHIẾN TRƯỜNG LINH LUNG THÁP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = reason
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	vb.add_child(sub)

	var info := Label.new()
	var chest_text := " · 🎁 +1 %s" % CHEST_ITEM_NAME if got_chest else ""
	info.text = "Tầng cao nhất: %d/%d   ·   Tổng Điểm: %d\nKinh nghiệm nhận: +%d EXP%s" % [
		max_floor_reached, TOTAL_FLOORS, score, exp, chest_text
	]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	vb.add_child(info)

	var leave_lbl := Label.new()
	leave_lbl.text = "Tự động trở về sau 10 giây..."
	leave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave_lbl.add_theme_font_size_override("font_size", 13)
	leave_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vb.add_child(leave_lbl)

	var btn_leave := Button.new()
	btn_leave.text = "🚪 Trở Về Lâm An (200/199)"
	btn_leave.custom_minimum_size = Vector2(230, 36)
	btn_leave.pressed.connect(_return_player_to_city)
	vb.add_child(btn_leave)

	_hud.add_child(popup)

func _return_player_to_city() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		gm.field_map = {
			"id": 1001,
			"name": "Lâm An",
			"dir": "res://world/maps/map_1001",
			"level": 80,
			"arena_center": Vector2(51200, 50944)
		}
	get_tree().change_scene_to_file("res://main.tscn")

# ---------------------------------------------------------------- THỰC THỂ CẦM LONG TRỤ & HUD

func _spawn_pillar() -> void:
	var ppos: Array = data().get("pillar_pos", [51225, 102384])
	var pos := Vector2(float(ppos[0]), float(ppos[1]) * 0.5)

	_pillar_node = Node2D.new()
	_pillar_node.name = "CamLongTru"
	_pillar_node.position = pos
	_pillar_node.y_sort_enabled = true

	# 1. Vẽ vòng hào quang chiếm trụ dạng Elip Isometric 2:1 và BÓNG TIẾP ĐẤT (Ground Contact Shadow)
	var ring := Node2D.new()
	ring.name = "PillarFloorDecal"
	ring.z_index = -1  # Nằm sát mặt sàn bên dưới nhân vật và bệ trụ
	ring.z_as_relative = true
	var base_center := Vector2.ZERO  # Gốc tiếp đất (0, 0) trùng khớp 100% với tâm chân bệ đá
	ring.draw.connect(func() -> void:
		# --- A. LỚP BÓNG ĐỔ TIẾP ĐẤT (GROUND CONTACT SHADOW) ---
		# A1. Lớp bóng lan tỏa nhẹ (Ambient Occlusion)
		var pts_amb := PackedVector2Array()
		for i in 33:
			var a := TAU * float(i) / 32.0
			pts_amb.append(base_center + Vector2(cos(a) * 135.0, sin(a) * 67.5))
		ring.draw_colored_polygon(pts_amb, Color(0.0, 0.0, 0.0, 0.32))

		# A2. Lớp bóng đậm dưới bệ đá (Contact Shadow)
		var pts_base := PackedVector2Array()
		for i in 33:
			var a := TAU * float(i) / 32.0
			pts_base.append(base_center + Vector2(cos(a) * 95.0, sin(a) * 47.5))
		ring.draw_colored_polygon(pts_base, Color(0.0, 0.0, 0.0, 0.55))

		# A3. Khối bóng tiếp xúc ôm khít mặt đế hình thoi của bệ trụ (Rhombus Footprint: 170x85 px)
		var pts_core := PackedVector2Array([
			base_center + Vector2(0.0, -42.0),
			base_center + Vector2(-85.0, 0.0),
			base_center + Vector2(0.0, 42.0),
			base_center + Vector2(85.0, 0.0)
		])
		ring.draw_colored_polygon(pts_core, Color(0.0, 0.0, 0.0, 0.65))

		# --- B. VÒNG HÀO QUANG ISOMETRIC PHÒNG THỦ QUANH CHÂN TRỤ ---
		var pts_inner_ring := PackedVector2Array()
		for i in 41:
			var a := TAU * float(i) / 40.0
			pts_inner_ring.append(base_center + Vector2(cos(a) * 110.0, sin(a) * 55.0))
		ring.draw_polyline(pts_inner_ring, Color(1.0, 0.9, 0.3, 0.75), 2.5)

		var pts_inner_glow := PackedVector2Array()
		for i in 41:
			var a := TAU * float(i) / 40.0
			pts_inner_glow.append(base_center + Vector2(cos(a) * 92.0, sin(a) * 46.0))
		ring.draw_polyline(pts_inner_glow, Color(0.2, 0.8, 1.0, 0.45), 1.8)

		# --- C. VÙNG PHẠM VI CHIẾM CẦM LONG TRỤ (ISOMETRIC CAPTURE ZONE 2:1) ---
		var rx: float = PILLAR_RANGE
		var ry: float = PILLAR_RANGE * 0.5
		var pts_zone := PackedVector2Array()
		for i in 65:
			var a := TAU * float(i) / 64.0
			pts_zone.append(base_center + Vector2(cos(a) * rx, sin(a) * ry))

		# Nền hào quang mờ vùng chiếm
		ring.draw_colored_polygon(pts_zone, Color(1.0, 0.85, 0.2, 0.08))
		# Viền ngoài vàng kim chính
		ring.draw_polyline(pts_zone, Color(1.0, 0.88, 0.25, 0.9), 3.5)

		# Viền phụ phản quang bên trong
		var pts_zone_in := PackedVector2Array()
		for i in 65:
			var a := TAU * float(i) / 64.0
			pts_zone_in.append(base_center + Vector2(cos(a) * (rx - 6.0), sin(a) * (ry - 3.0)))
		ring.draw_polyline(pts_zone_in, Color(1.0, 0.95, 0.5, 0.35), 1.5)
	)
	_pillar_node.add_child(ring)

	# 2. Ảnh hình ảnh Long Trụ VLTK chuẩn nguyên bản (dùng MonsterSprite & MonsterData)
	# Căn chỉnh chân bệ đá trùng khít tuyệt đối với tâm gốc (0, 0) của vòng tròn hào quang
	var pillar_rendered := false
	var ms_script: GDScript = load("res://systems/monster/monster_sprite.gd")
	if ms_script != null and ms_script.can_instantiate():
		var ms: MonsterSprite = ms_script.new()
		ms.name = "PillarMonsterSprite"
		ms.position = Vector2(-1.5, 8.5)
		_pillar_node.add_child(ms)
		var res_id: String = str(data().get("pillar_res", "enemy190"))
		ms.set_resource(res_id)
		if ms.set_pose("stand1", 0, 0.0) or ms.set_pose("fight_stand", 0, 0.0) or ms.set_pose("stand", 0, 0.0):
			pillar_rendered = true

	# Fallback: Nếu MonsterSprite chưa render được thì nạp trực tiếp qua Image buffer
	if not pillar_rendered:
		var fallback_tex: Texture2D = null
		for candidate_path in [
			"res://assets/monster/enemy190_enemy190_st.png",
			"res://assets/monster/enemy191_enemy191_st.png"
		]:
			if FileAccess.file_exists(candidate_path):
				var img := Image.new()
				if img.load_png_from_buffer(FileAccess.get_file_as_bytes(candidate_path)) == OK:
					fallback_tex = ImageTexture.create_from_image(img)
					break
		if fallback_tex != null:
			var spr := Sprite2D.new()
			spr.name = "PillarSpriteFallback"
			spr.texture = fallback_tex
			spr.centered = false
			# Căn chỉnh tâm chân bệ đá trùng khớp gốc tiếp đất (0, 0)
			spr.position = Vector2(-84.5, -374.5)
			_pillar_node.add_child(spr)

	# 3. Tên Long Trụ phía trên đỉnh trụ
	var lbl := Label.new()
	lbl.text = "🏛️ CẦM LONG TRỤ"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-100, -360)
	lbl.custom_minimum_size = Vector2(200, 30)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 2
	_pillar_node.add_child(lbl)

	var parent := _world_entity_parent()
	if parent != null:
		parent.add_child(_pillar_node)
	else:
		add_child(_pillar_node)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "LinhLungThapHud"
	add_child(_hud)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -290.0  ## Dời sang trái 80px theo yêu cầu người chơi, tránh đè lên cụm nút SideMenu bên phải
	panel.offset_right = 130.0
	panel.offset_top = 54.0  ## Đặt an toàn dưới TopStatusBar (máu/mana kết thúc ở y~45), hoàn toàn không che thanh máu
	panel.offset_bottom = 54.0
	panel.custom_minimum_size = Vector2(420, 0)  ## Khung gọn gàng 420px, loại bỏ toàn bộ khoảng trống thừa
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.06, 0.08, 0.12, 0.8)
	sbox.border_color = Color(0.85, 0.7, 0.25, 0.8)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(6)
	sbox.content_margin_left = 10
	sbox.content_margin_right = 10
	sbox.content_margin_top = 3
	sbox.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", sbox)
	_hud.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 14)
	vb.add_child(top_row)

	_floor_label = Label.new()
	_floor_label.add_theme_font_size_override("font_size", 13)
	_floor_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	top_row.add_child(_floor_label)

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 13)
	_clock_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	top_row.add_child(_clock_label)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 13)
	_score_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	top_row.add_child(_score_label)

	var exit_btn := Button.new()
	exit_btn.text = "🚪 Rời"
	exit_btn.custom_minimum_size = Vector2(48, 20)
	exit_btn.add_theme_font_size_override("font_size", 11)
	exit_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_btn.pressed.connect(func() -> void:
		_finish(false, "Đại hiệp chủ động rời khỏi Linh Lung Tháp.")
	)
	top_row.add_child(exit_btn)

	var bot_row := HBoxContainer.new()
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_row.add_theme_constant_override("separation", 12)
	vb.add_child(bot_row)

	_kills_label = Label.new()
	_kills_label.add_theme_font_size_override("font_size", 12)
	_kills_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.75))
	bot_row.add_child(_kills_label)

	_pillar_status_label = Label.new()
	_pillar_status_label.text = "⚪ Chưa vào trụ"
	_pillar_status_label.add_theme_font_size_override("font_size", 12)
	_pillar_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bot_row.add_child(_pillar_status_label)

	_update_hud()

func _update_hud() -> void:
	if _floor_label != null:
		_floor_label.text = "🏯 TẦNG: %d / %d" % [current_floor, TOTAL_FLOORS]
	if _score_label != null:
		_score_label.text = "🏆 Tổng: %d" % score
	if _kills_label != null:
		var target := target_floor_score(current_floor)
		_kills_label.text = "⭐ Điểm Tầng: %d / %d  |  Quái: %d  |  Đối thủ: %d" % [
			floor_score, target, _alive.size(), _alive_bots.size()
		]
