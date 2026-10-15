extends Node
class_name TimeChallenge
## THÁCH THỨC THỜI GIAN (Vượt Ải của NPC Nhiếp Thí Trần) — theo script gốc VLTK 15 phái (server-vm):
##   script/global/npcchucnang/nhieptran.lua (điều kiện vào), script/header/vuotai.lua (bảng ải / boss / toạ độ, release_npcvuotai),
##   script/feature/vuotai/die_normal.lua + die_boss.lua (hết quái -> ải sau, boss cuối chết -> xong, thưởng), dữ liệu đã chuyển sang
##   data/challenge/time_challenge.json.
## Luật giữ như gốc: cấp >= 80, phí 15 vạn lượng, 2 lượt / ngày, 30 phút; 27 ải quái (mỗi ải N con ở toạ độ cố định, máu
## 50000 + ải*500), 12 ải có thêm boss (máu 500000 + thứ tự*5000, boss tên trống = mang tên người chơi), ải 28 = đại boss
## Độc Cô Quỷ Kiếm (1 500 000 máu). Hết quái của ải mới ra ải sau.
## Chơi MỘT MÌNH: bỏ điều kiện tổ đội >= 4 người; máu quái nhân `solo_hp_scale` (gốc tính cho đội 4-8 người).
## Vào ải trừ 1 Sát thủ giản cấp 90 trong hành trang (challengeoftime/npc/dragonboat_main_*.lua: ConsumeEquiproomItem(1,6,1,400,90)).
## Chưa có (giai đoạn sau): Bảo Rương Vượt Ải (thưởng), chế độ chờ tổ đội online.

signal finished(success: bool, seconds: int)

const DATA_PATH := "res://data/challenge/time_challenge.json"
const RECORD_PATH := "user://time_challenge.json"
const MAP_DIR := "res://world/maps/map_480"
const PREPARE_SEC := 10.0          ## gốc: 5 phút chờ tổ đội tập trung; chơi một mình chỉ đếm 10 giây
const LEAVE_AFTER_SEC := 8.0       ## xong / hết giờ: về Character Hub sau chừng này giây
const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const ENTRY_ITEM_ID := "6_1_400"   ## Sát thủ giản
const ENTRY_ITEM_LEVEL := 90
const ENTRY_ITEM_NAME := "Sát thủ giản (cấp 90)"

static var _data: Dictionary = {}

var wave := 0                      ## ải đang đánh (1..28), 0 = đang chuẩn bị
var time_left := 0.0
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

# ---------------------------------------------------------------- dữ liệu, điều kiện vào, lượt mỗi ngày

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data

static func rules() -> Dictionary:
	return data().get("rules", {})

## Mục "map" đưa cho Character Hub (GameManager.field_map) để vào đấu trường.
static func map_entry() -> Dictionary:
	return {"id": int(data().get("map", 480)), "name": "Thách Thức Thời Gian", "dir": MAP_DIR, "level": 100, "challenge": true}

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

## Thời gian hoàn thành nhanh nhất (giây), 0 = chưa từng xong.
static func best_time(profile: PlayerProfile) -> int:
	return int(_records().get(_key(profile), {}).get("best", 0))

## "" = đủ điều kiện, ngược lại là lý do (như các câu Talk của Nhiếp Thí Trần).
static func check_entry(profile: PlayerProfile) -> String:
	var r := rules()
	if profile == null:
		return "Chưa có nhân vật."
	if profile.level < int(r.get("min_level", 80)):
		return "Cần đạt cấp %d mới được tham gia khiêu chiến." % int(r.get("min_level", 80))
	if profile.gold < int(r.get("cost", 150000)):
		return "Cần %s lượng để tham gia khiêu chiến." % _money(int(r.get("cost", 150000)))
	if entry_item_count(profile) < 1:
		return "Cần 1 %s trong hành trang để tham gia khiêu chiến." % ENTRY_ITEM_NAME
	if runs_today(profile) >= int(r.get("runs_per_day", 2)):
		return "Hôm nay đại hiệp đã hết %d lượt tham gia Vượt ải rồi!" % int(r.get("runs_per_day", 2))
	return ""

static func _is_entry_item(it: ItemInstance) -> bool:
	return it != null and it.misc_id == ENTRY_ITEM_ID and it.item_level == ENTRY_ITEM_LEVEL

## Số Sát thủ giản cấp 90 trong hành trang (CalcEquiproomItemCount gốc).
static func entry_item_count(profile: PlayerProfile) -> int:
	var n := 0
	for it in profile.inventory:
		if _is_entry_item(it):
			n += maxi(it.count, 1)
	return n

## Trả phí (tiền + 1 Sát thủ giản) + tính 1 lượt (gọi ngay trước khi vào map). false = không đủ điều kiện, chưa trừ gì.
static func pay_entry(profile: PlayerProfile) -> bool:
	if check_entry(profile) != "":
		return false
	for i in profile.inventory.size():
		var it := profile.inventory[i]
		if _is_entry_item(it):
			if it.count > 1:
				it.count -= 1
			else:
				profile.inventory.remove_at(i)
			break
	profile.gold -= int(rules().get("cost", 150000))
	var rec := _records()
	var mine: Dictionary = rec.get(_key(profile), {})
	var runs: Dictionary = mine.get("runs", {})
	runs = {_today(): int(runs.get(_today(), 0)) + 1}      ## chỉ giữ ngày hôm nay
	mine["runs"] = runs
	rec[_key(profile)] = mine
	_save_records(rec)
	SaveManager.save_profile(profile)
	return true

static func _money(v: int) -> String:
	@warning_ignore("integer_division")
	return "%d vạn" % (v / 10000) if v % 10000 == 0 else str(v)

static func format_time(sec: int) -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d" % [sec / 60, sec % 60]

# ---------------------------------------------------------------- vòng chơi

func _ready() -> void:
	time_left = float(rules().get("time_limit_sec", 1800))
	_build_hud()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_place_player_at_entry.call_deferred()
	_say("Còn %d giây sẽ chính thức tính thời gian nhiệm vụ." % int(PREPARE_SEC))

func _place_player_at_entry() -> void:
	var entry: Array = data().get("entry", [49920, 102912])
	if _player:
		_player.global_position = Vector2(float(entry[0]), float(entry[1]) * 0.5)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _leave_in >= 0.0:
		_leave_in -= delta
		_clock.text = "Rời khỏi sau %d giây" % ceili(maxf(_leave_in, 0.0))
		if _leave_in <= 0.0:
			_leave_in = -1.0
			_go_home()
		return
	if done:
		return
	if not running:
		_prepare -= delta
		_clock.text = "Chuẩn bị %d" % ceili(maxf(_prepare, 0.0))
		if _prepare <= 0.0:
			running = true
			_release(1)
		return
	time_left -= delta
	_clock.text = format_time(maxi(0, ceili(time_left)))
	if time_left <= 0.0:
		_finish(false)

## release_npcvuotai(nLevel): ải 1..27 = quái thường ở bộ toạ độ của ải (+ boss nếu có), ải 28 = đại boss.
func _release(level: int) -> void:
	wave = level
	_alive.clear()
	var d := data()
	var hp: Dictionary = d.get("hp", {})
	var scale := float(rules().get("solo_hp_scale", 0.25))
	var lv := 100
	if level >= int(d.get("final_boss", {}).get("wave", 28)):
		var fb: Dictionary = d["final_boss"]
		_spawn(int(fb["tpl"]), int(fb.get("level", lv)), -1, _boss_pos(), int(float(hp.get("final_boss", 1500000)) * scale), str(fb["name"]))
		_say("Quái nhân giữ ải cuối cùng đã xuất hiện!")
	else:
		var w: Dictionary = d["waves"][level - 1]
		var points: Array = d["positions"].get(str(int(w["pos"])), [])
		var whp := int(float(int(hp.get("normal_base", 50000)) + level * int(hp.get("normal_per_wave", 500))) * scale)
		for p in points:
			_spawn(int(w["tpl"]), lv, int(w["series"]), Vector2(float(p[0]), float(p[1])), whp, "")
		var bi := int(w.get("boss", 0))
		if bi > 0:
			var b: Dictionary = d["bosses"][bi - 1]
			var bname := str(b.get("name", "")).strip_edges()
			if bname == "":               ## boss tên trống: mang tên người chơi trong ải (gốc: thành viên đầu tiên đang online)
				bname = GameManager.local_profile.display_name if GameManager.local_profile else "Quái nhân"
			var bhp := int(float(int(hp.get("boss_base", 500000)) + bi * int(hp.get("boss_per_index", 5000))) * scale)
			_spawn(int(b["tpl"]), lv, int(b["series"]), _boss_pos(), bhp, bname)
	_say("Vào ải thứ %d. Xuất hiện %d con quái." % [level, _alive.size()])
	_update_info()
	if _alive.is_empty():                 ## thiếu dữ liệu quái: đừng kẹt ở ải này
		_on_wave_cleared()

func _boss_pos() -> Vector2:
	var b: Array = data().get("boss_pos", [50201, 102968])
	return Vector2(float(b[0]), float(b[1]))

## Toạ độ ải trong script là toạ độ logic (y gấp đôi) -> pixel map: (x, y/2).
func _spawn(tpl: int, lvl: int, series: int, logic_pos: Vector2, hp: int, name_override: String) -> void:
	var base := MonsterData.monster(tpl)
	var parent := VltkWorld.entity_parent()
	if base.is_empty() or parent == null:
		push_warning("TimeChallenge: thiếu quái %d" % tpl)
		return
	var m := VltkMonster.new()
	m.monster_id = tpl
	m.data = base.duplicate()
	m.data["series"] = series if series >= 0 and series <= 4 else randi() % 5     ## RANDOMC(0,1,2,3,4)
	m.data["vision"] = 2400            ## đấu trường nhỏ: quái thấy người chơi ngay
	m.data["active"] = 4000
	if name_override != "":
		m.data["name"] = name_override
	m.level = lvl
	m.hp_override = maxi(1, hp)
	m.position = Vector2(logic_pos.x, logic_pos.y * 0.5)
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
	if wave >= int(data().get("final_boss", {}).get("wave", 28)):
		_finish(true)
	else:
		_release(wave + 1)

func _finish(success: bool) -> void:
	if done:
		return
	done = true
	running = false
	var used := int(float(rules().get("time_limit_sec", 1800)) - maxf(time_left, 0.0))
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
		_say("Đã hoàn thành nhiệm vụ đúng thời gian: %d phút %d giây" % [int(used / 60.0), used % 60])
		_title.text = "Vượt ải thành công!"
	else:
		for m in _alive:
			if is_instance_valid(m):
				m.queue_free()
		_alive.clear()
		_say("Hết thời gian khiêu chiến. Nhiệm vụ thất bại.")
		_title.text = "Hết giờ — thất bại (ải %d/28)" % wave
	finished.emit(success, used)
	_leave_in = LEAVE_AFTER_SEC

## Thưởng boss cuối (die_boss.lua): gốc 10 000 000 kinh nghiệm cho cả đội (người kết liễu 100%, người khác 80%) + Bảo Rương
## Vượt Ải + Tiên Thảo Lộ. Bảng kinh nghiệm của game khác VLTK -> quy theo `reward_exp_levels` cấp hiện tại.
## Vật phẩm thưởng: chờ hệ vật phẩm dùng được (giai đoạn sau).
func _reward(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var levels := float(rules().get("reward_exp_levels", 0.5))
	var exp_gain := int(float(profile.get_exp_to_next_level()) * levels)
	var before := profile.level
	profile.add_exp(exp_gain)
	SaveManager.save_profile(profile)
	if _player and profile.level > before and _player.has_method("refresh_combat_stats"):
		_player.refresh_combat_stats()
	_say("Nhận %d kinh nghiệm thưởng vượt ải." % exp_gain)

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
	box.position = Vector2(-160, 8)
	box.custom_minimum_size = Vector2(320, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	_title = _hud_label("Thách Thức Thời Gian", 18, GameUi.GOLD)
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
		_info.text = "Ải %d / 28   ·   Còn %d quái" % [wave, _alive.size()]

func _say(text: String) -> void:
	if _player and _player.has_method("notify"):
		_player.notify(text)
	else:
		print("[Vượt ải] ", text)
