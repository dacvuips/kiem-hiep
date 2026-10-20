extends Node
class_name PhongLangDoChallenge
## ẢI THUYỀN PHONG LĂNG ĐỘ — Vượt sông Hoàng Hà diệt Thủy tặc & Boss Hoàng Kim Yên Hiểu Trái.
## Map: res://world/maps/map_336 (Phong Lăng Độ).
## Thủ tục bên ngoài: Cấp >= 50, có 1 Lệnh bài Phong Lăng Độ (4_489_1) hoặc nộp 2 vạn lượng (20.000 lượng) vé thuyền, 3 lượt / ngày.
## Khi đủ điều kiện: lên thuyền xuất bến ngay lập tức.
## Trên thuyền: 3 đợt thử thách Thủy Tặc (Thần Tý, Lãnh Thương, Thủy Tặc Đầu Lĩnh và Boss Yên Hiểu Trái),
## rơi Huyền Tinh, Thủy Tinh, Danh vọng, Phúc duyên và Trang bị Hoàng Kim môn phái.

signal finished(success: bool, seconds: int)

const MAP_ID := 337
const MAP_DIR := "res://world/maps/map_337"
const MAP_NAME := "Thuyền Phong Lăng Độ"
const ENTRY_ITEM_ID := "4_489_1"
const ENTRY_ITEM_NAME := "Lệnh bài Phong Lăng Độ"
const ENTRY_FEE := 20000              ## 2 vạn lượng nếu không có lệnh bài
const MIN_LEVEL := 50
const RUNS_PER_DAY := 3
const TIME_LIMIT_SEC := 600.0         ## 10 phút vượt sông
const PREPARE_SEC := 5.0              ## 5 giây nhổ neo
const LEAVE_AFTER_SEC := 10.0         ## xong / hết giờ: về Character Hub sau chừng này giây
const RECORD_PATH := "user://phong_lang_do.json"
const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"

## Quái Thủy Tặc
const MONSTER_THAN_TY := 707          ## Thần Tý (enemy028)
const MONSTER_LANH_THUONG := 708      ## Lãnh Thương (enemy036)
const MONSTER_DAU_LINH := 1692        ## Thủy Tặc Đại Đầu Lĩnh (enemy205)
const BOSS_YEN_HIEU_TRAI := 744       ## Yên Hiểu Trái (boss023 - Thúy Yên hệ Thủy)

var wave := 0                         ## 0 = chuẩn bị, 1 = đợt 1, 2 = đợt 2, 3 = Boss
var time_left := TIME_LIMIT_SEC
var running := false
var done := false
var _prepare := PREPARE_SEC
var _alive: Array[VltkMonster] = []
var _player: Node2D
var _hud: CanvasLayer
var _title: Label
var _info: Label
var _clock: Label
var _leave_in := -1.0

# ---------------------------------------------------------------- Kiểm tra thủ tục bên ngoài & vé thuyền

const BOAT_SPAWN := Vector2(51712.0, 51264.0)  ## Tọa độ trung tâm boong thuyền (VLTK gốc: NewWorld 337, 1616, 3204)

## Mục map đưa cho GameManager.field_map để vào map Phong Lăng Độ
static func map_entry() -> Dictionary:
	return {
		"id": MAP_ID,
		"name": MAP_NAME,
		"dir": MAP_DIR,
		"level": 95,
		"phong_lang_do": true,
		"arena_center": BOAT_SPAWN
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

static func best_time(profile: PlayerProfile) -> int:
	return int(_records().get(_key(profile), {}).get("best", 0))

static func has_entry_item(profile: PlayerProfile) -> bool:
	return entry_item_count(profile) > 0

static func entry_item_count(profile: PlayerProfile) -> int:
	if profile == null:
		return 0
	var n := 0
	for it in profile.inventory:
		if it != null and (it.misc_id == ENTRY_ITEM_ID or it.get_base().get("name", "") == ENTRY_ITEM_NAME):
			n += maxi(it.count, 1)
	return n

## Kiểm tra thủ tục bên ngoài: "" = đủ điều kiện, ngược lại là lý do
static func check_entry(profile: PlayerProfile) -> String:
	if profile == null:
		return "Chưa có nhân vật."
	if profile.level < MIN_LEVEL:
		return "Cần đạt cấp %d trở lên mới được lên thuyền Phong Lăng Độ." % MIN_LEVEL
	if runs_today(profile) >= RUNS_PER_DAY:
		return "Hôm nay đại hiệp đã hết %d lượt lên thuyền Phong Lăng Độ rồi!" % RUNS_PER_DAY
	if not has_entry_item(profile) and profile.gold < ENTRY_FEE:
		return "Cần 1 %s hoặc %s lượng để làm thủ tục lên thuyền." % [ENTRY_ITEM_NAME, _money(ENTRY_FEE)]
	return ""

## Làm thủ tục lên thuyền: trừ 1 Lệnh bài (nếu có) hoặc 20.000 lượng, tính 1 lượt hôm nay
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

	var rec := _records()
	var mine: Dictionary = rec.get(_key(profile), {})
	var runs: Dictionary = mine.get("runs", {})
	runs = {_today(): int(runs.get(_today(), 0)) + 1}
	mine["runs"] = runs
	rec[_key(profile)] = mine
	_save_records(rec)

	SaveManager.save_profile(profile)
	SaveManager.flush_online()
	return true

static func _money(v: int) -> String:
	@warning_ignore("integer_division")
	return "%d vạn" % (v / 10000) if v >= 10000 and v % 10000 == 0 else str(v)

static func format_time(sec: int) -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d" % [sec / 60, sec % 60]

# ---------------------------------------------------------------- Vòng chơi trên thuyền

func _ready() -> void:
	time_left = TIME_LIMIT_SEC
	_build_hud()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		_player.global_position = BOAT_SPAWN
	_say("Thuyền Phong Lăng Độ chuẩn bị nhổ neo! Còn %d giây chuẩn bị xuất bến." % int(PREPARE_SEC))

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _leave_in >= 0.0:
		_leave_in -= delta
		_clock.text = "Rời thuyền sau %d giây" % ceili(maxf(_leave_in, 0.0))
		if _leave_in <= 0.0:
			_leave_in = -1.0
			_go_home()
		return
	if done:
		return
	if not running:
		_prepare -= delta
		_clock.text = "Xuất bến sau %d" % ceili(maxf(_prepare, 0.0))
		if _prepare <= 0.0:
			running = true
			_release_wave(1)
		return

	time_left -= delta
	_clock.text = format_time(maxi(0, ceili(time_left)))
	if time_left <= 0.0:
		_finish(false)

func _release_wave(w: int) -> void:
	wave = w
	_alive.clear()
	var center := _player.global_position if _player else Vector2(51968, 51200)

	match wave:
		1:
			_say("Đợt 1: Thủy Tặc Thần Tý & Lãnh Thương tràn lên mạn thuyền!")
			for i in 10:
				var tpl := MONSTER_THAN_TY if i % 2 == 0 else MONSTER_LANH_THUONG
				var offset := Vector2(randf_range(-320, 320), randf_range(-220, 220))
				if offset.length() < 120.0:
					offset = offset.normalized() * 160.0
				_spawn(tpl, 95, -1, center + offset, 60000, "")
		2:
			_say("Đợt 2: Thủy Tặc Đầu Lĩnh dẫn toán cướp bao vây thuyền!")
			for i in 8:
				var tpl := MONSTER_THAN_TY if i % 2 == 0 else MONSTER_LANH_THUONG
				var offset := Vector2(randf_range(-340, 340), randf_range(-240, 240))
				_spawn(tpl, 98, -1, center + offset, 80000, "Thủy Tặc Tinh Anh")
			# 2 Thủy Tặc Đầu Lĩnh
			_spawn(MONSTER_DAU_LINH, 100, 2, center + Vector2(-220, -120), 250000, "Thủy Tặc Đầu Lĩnh")
			_spawn(MONSTER_DAU_LINH, 100, 3, center + Vector2(220, 120), 250000, "Thủy Tặc Đầu Lĩnh")
		3:
			_say("Đợt 3: Thủy Tặc Đại Đầu Lĩnh cùng Boss Hoàng Kim Yên Hiểu Trái xuất hiện!")
			# Đại Đầu Lĩnh
			_spawn(MONSTER_DAU_LINH, 100, 4, center + Vector2(-260, 0), 400000, "Thủy Tặc Đại Đầu Lĩnh")
			# Boss Hoàng Kim Yên Hiểu Trái
			_spawn_gold_boss(center + Vector2(240, -60))

	_update_info()
	if _alive.is_empty():
		_on_wave_cleared()

func _spawn(tpl: int, lvl: int, series: int, pos: Vector2, hp: int, name_override: String) -> void:
	var base := MonsterData.monster(tpl)
	var parent := VltkWorld.entity_parent()
	if base.is_empty() or parent == null:
		return
	var m := VltkMonster.new()
	m.monster_id = tpl
	m.data = base.duplicate()
	m.data["series"] = series if series >= 0 and series <= 4 else randi() % 5
	m.data["vision"] = 2400
	m.data["active"] = 4000
	if name_override != "":
		m.data["name"] = name_override
	m.level = lvl
	m.hp_override = maxi(1, hp)
	m.position = pos
	m.ai_enabled = true
	m.died.connect(_on_monster_died)
	parent.add_child(m)
	_alive.append(m)

func _spawn_gold_boss(pos: Vector2) -> void:
	var base := MonsterData.monster(BOSS_YEN_HIEU_TRAI)
	var parent := VltkWorld.entity_parent()
	if base.is_empty() or parent == null:
		return
	var m := VltkMonster.new()
	m.monster_id = BOSS_YEN_HIEU_TRAI
	m.data = base.duplicate()
	m.data["name"] = "Yên Hiểu Trái"
	m.data["res"] = "boss023"
	m.data["series"] = 2   ## Hệ Thủy
	m.data["vision"] = 2400
	m.data["active"] = 4000
	m.level = 95
	m.hp_override = 1200000
	m.gold_boss = true
	m.position = pos
	m.ai_enabled = true
	m.died.connect(_on_monster_died)
	parent.add_child(m)
	_alive.append(m)

func _on_monster_died(m: VltkMonster) -> void:
	_alive.erase(m)
	if done:
		return
	_update_info()
	if _alive.is_empty():
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	if wave >= 3:
		_finish(true)
	else:
		_say("Đã dẹp sạch đợt %d! Chuẩn bị đợt tiếp theo..." % wave)
		await get_tree().create_timer(3.0).timeout
		if not done:
			_release_wave(wave + 1)

func _finish(success: bool) -> void:
	if done:
		return
	done = true
	running = false
	var used := int(TIME_LIMIT_SEC - maxf(time_left, 0.0))
	var profile := GameManager.local_profile

	if success:
		_reward(profile)
		var rec := _records()
		var mine: Dictionary = rec.get(_key(profile), {})
		var best := int(mine.get("best", 0))
		if best == 0 or used < best:
			mine["best"] = used
		rec[_key(profile)] = mine
		_save_records(rec)
		_say("Thuyền Phong Lăng Độ đã cập bờ Bắc an toàn! Thời gian: %d phút %d giây." % [int(used / 60.0), used % 60])
		_title.text = "Vượt Sông Cập Bến Thành Công!"
		_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		for m in _alive:
			if is_instance_valid(m):
				m.queue_free()
		_alive.clear()
		_say("Hết giờ vượt sông! Nhiệm vụ Phong Lăng Độ thất bại.")
		_title.text = "Hết giờ — Vượt sông thất bại!"
		_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	finished.emit(success, used)
	_leave_in = LEAVE_AFTER_SEC

func _reward(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var exp_gain := 350000
	var before := profile.level
	profile.add_exp(exp_gain)
	profile.prestige += 100
	profile.fuyuan += 100
	SaveManager.save_profile(profile)
	SaveManager.flush_online()
	if _player and profile.level > before and _player.has_method("refresh_combat_stats"):
		_player.refresh_combat_stats()
	_say("Thưởng vượt thuyền: +%d EXP, +100 Danh vọng, +100 Phúc duyên!" % exp_gain)

func _go_home() -> void:
	GameManager.field_map = {}
	get_tree().change_scene_to_file(HUB_SCENE)

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

	_title = _hud_label("Phong Lăng Độ — Thuyền Vượt Sông", 18, GameUi.GOLD)
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
	if _info:
		var wave_name := "Chuẩn bị"
		match wave:
			1: wave_name = "Đợt 1: Thần Tý & Lãnh Thương"
			2: wave_name = "Đợt 2: Thủy Tặc Đầu Lĩnh"
			3: wave_name = "Đợt 3: Boss Yên Hiểu Trái"
		_info.text = "%s  ·  Còn %d tên thủy tặc" % [wave_name, _alive.size()]

func _say(text: String) -> void:
	if _player and _player.has_method("notify"):
		_player.notify(text)
	else:
		print("[Phong Lăng Độ] ", text)
