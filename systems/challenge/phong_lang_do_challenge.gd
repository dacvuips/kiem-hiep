extends Node
class_name PhongLangDoChallenge
## ẢI THUYỀN PHONG LĂNG ĐỘ — Vượt sông Hoàng Hà diệt Thủy tặc & Boss Hoàng Kim Yên Hiểu Trái.
## Chuẩn theo mã nguồn gốc VLTK (script/feature/phonglangdo & timertask/task01-03.lua):
## 1. Hành trình vượt sông kéo dài theo thời gian thực (5 phút / 300 giây).
## 2. 44 vị trí quái Thủy Tặc rải khắp boong thuyền lấy nguyên bản từ mảng NPC_PHONGLANG của source gốc.
## 3. Thủy tặc liên tục áp mạn thuyền chi viện (respawn) để người chơi thỏa sức gom quái luyện cấp & farm exp.
## 4. Các mốc thời gian đặc biệt:
##    - Giữa sông: Thủy Tặc Đầu Lĩnh xuất hiện tại 2 mũi/đuôi thuyền (mảng BOSS_PHONGLANG gốc).
##    - Áp bờ Bắc: Thủy Tặc Đại Đầu Lĩnh và Boss Hoàng Kim Yên Hiểu Trái áp mạn quyết chiến.
## 5. Hết thời gian hành trình mà nhân vật vẫn sống sót: Thuyền chính thức CẬP BẾN BỜ BẮC AN TOÀN!
## 6. Quy tắc lên thuyền: Khi 1 thuyền đã nhổ neo xuất bến, cửa bến đóng lại, không ai được lên thuyền nữa.

signal finished(success: bool, seconds: int)

const MAP_ID := 337
const MAP_DIR := "res://world/maps/map_337"
const MAP_NAME := "Thuyền Phong Lăng Độ"
const ENTRY_ITEM_ID := "4_489_1"
const ENTRY_ITEM_NAME := "Lệnh bài Phong Lăng Độ"
const ENTRY_FEE := 20000              ## 2 vạn lượng nếu không có lệnh bài
const MIN_LEVEL := 50
const RUNS_PER_DAY := 3
const TIME_LIMIT_SEC := 300.0         ## 5 phút vượt sông Hoàng Hà
const CountdownOverlay = preload("res://ui/common/countdown_overlay.gd")
const PREPARE_SEC := 3.0              ## 3 giây đếm ngược nhổ neo (1, 2, 3, GO)
const LEAVE_AFTER_SEC := 10.0         ## Xong / hết giờ: về Character Hub sau 10 giây
const RECORD_PATH := "user://phong_lang_do.json"
const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"

## Quái Thủy Tặc (Khớp Data VLTK)
const MONSTER_THAN_TY := 707          ## Thần Tý (enemy028)
const MONSTER_LANH_THUONG := 708      ## Lãnh Thương (enemy036)
const MONSTER_DAU_LINH := 1692        ## Thủy Tặc Đại Đầu Lĩnh (enemy205)
const BOSS_YEN_HIEU_TRAI := 744       ## Yên Hiểu Trái (boss023 - Thúy Yên hệ Thủy)

## Tọa độ trung tâm xuất phát của nhân vật trên thuyền
const BOAT_SPAWN := Vector2(51712.0, 51264.0)  ## VLTK gốc: NewWorld 337, 1616, 3204

## 44 Tọa độ Thủy Tặc trên boong thuyền (Trích xuất 100% từ NPC_PHONGLANG trong script/header/phonglangdo.lua)
const PIRATE_COORDS: Array[Vector2] = [
	Vector2(50310.0, 51163.0),
	Vector2(50676.0, 51323.0),
	Vector2(50648.0, 51198.0),
	Vector2(50494.0, 51123.0),
	Vector2(50747.0, 51089.0),
	Vector2(50749.0, 50912.0),
	Vector2(50920.0, 51016.0),
	Vector2(51105.0, 50934.0),
	Vector2(51248.0, 50865.0),
	Vector2(51332.0, 50991.0),
	Vector2(51436.0, 50838.0),
	Vector2(51247.0, 50686.0),
	Vector2(51646.0, 50812.0),
	Vector2(52084.0, 50991.0),
	Vector2(52103.0, 51172.0),
	Vector2(51979.0, 51100.0),
	Vector2(51598.0, 51067.0),
	Vector2(52020.0, 51267.0),
	Vector2(51402.0, 51173.0),
	Vector2(51773.0, 51384.0),
	Vector2(51609.0, 51499.0),
	Vector2(51152.0, 51283.0),
	Vector2(51426.0, 51488.0),
	Vector2(51322.0, 51592.0),
	Vector2(51071.0, 51472.0),
	Vector2(52588.0, 51209.0),
	Vector2(52718.0, 51312.0),
	Vector2(52504.0, 51298.0),
	Vector2(52366.0, 51357.0),
	Vector2(52426.0, 51504.0),
	Vector2(51995.0, 51493.0),
	Vector2(52150.0, 51660.0),
	Vector2(51718.0, 51520.0),
	Vector2(51976.0, 51768.0),
	Vector2(51592.0, 51807.0),
	Vector2(52001.0, 51982.0),
	Vector2(52314.0, 51723.0),
	Vector2(52402.0, 51587.0),
	Vector2(52580.0, 51498.0),
	Vector2(52769.0, 51591.0),
	Vector2(52866.0, 51445.0),
	Vector2(53021.0, 51537.0),
	Vector2(52197.0, 52040.0),
	Vector2(52384.0, 51947.0)
]

## Tọa độ Thủy Tặc Đầu Lĩnh giữa sông (BOSS_PHONGLANG trong script/header/phonglangdo.lua)
const MID_BOSS_COORDS: Array[Vector2] = [
	Vector2(51619.0, 51031.0),
	Vector2(52565.0, 51462.0)
]

## Trạng thái thuyền đang xuất bến (khóa cửa bến không cho ai lên nữa)
static var is_boat_sailing := false

## Mốc thời gian của hành trình
const MID_RIVER_TIME := 180.0         ## Còn 180s: Ra đến giữa sông, Thủy Tặc Đầu Lĩnh xuất hiện
const NEAR_SHORE_TIME := 90.0         ## Còn 90s: Cận bờ Bắc, Đại Đầu Lĩnh & Yên Hiểu Trái áp mạn
const RESPAWN_INTERVAL := 4.0        ## Mỗi 4 giây kiểm tra chi viện thêm thủy tặc nếu thiếu
const TARGET_PIRATE_COUNT := 32       ## Luôn duy trì khoảng 32 thủy tặc trên sàn tàu để farm

var time_left := TIME_LIMIT_SEC
var running := false
var done := false
var _prepare := PREPARE_SEC
var _respawn_timer := 0.0

var _spawned_mid_bosses := false
var _spawned_final_bosses := false

var _alive_pirates: Array[VltkMonster] = []
var _alive_bosses: Array[VltkMonster] = []

var pirates_slain := 0
var mid_bosses_slain := 0
var gold_boss_slain := 0

var _player: Node2D
var _hud: CanvasLayer
var _title: Label
var _info: Label
var _clock: Label
var _stat_lbl: Label
var _leave_in := -1.0

# ---------------------------------------------------------------- Kiểm tra thủ tục bên ngoài & vé thuyền

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
	if is_boat_sailing:
		return "Thuyền Phong Lăng Độ đã nhổ neo xuất bến ra giữa sông! Không thể lên thuyền lúc này, xin đợi chuyến sau."
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var api = tree.root.get_node_or_null("AccountApi")
		if api != null and api.has_method("is_gm") and api.is_gm():
			return ""
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

## Ủy thác vượt sông / Càn quét nhanh (dành cho chế độ Idle sau khi đã cập bến thành công ít nhất 1 lần):
static func sweep(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {"ok": false, "reason": "Chưa có nhân vật."}
	if best_time(profile) <= 0:
		return {"ok": false, "reason": "Cần hoàn thành vượt sông Phong Lăng Độ ít nhất 1 lần mới có thể Ủy thác."}
	var reason := check_entry(profile)
	if reason != "":
		return {"ok": false, "reason": reason}
	if not pay_entry(profile):
		return {"ok": false, "reason": "Thanh toán lệ phí lên thuyền thất bại."}

	var exp_gain := 450000
	profile.add_exp(exp_gain)
	profile.prestige += 120
	profile.fuyuan += 120
	profile.gold += 50000
	SaveManager.save_profile(profile)
	SaveManager.flush_online()
	return {"ok": true, "exp": exp_gain, "prestige": 120, "fuyuan": 120, "gold": 50000}

static func _money(v: int) -> String:
	@warning_ignore("integer_division")
	return "%d vạn" % (v / 10000) if v >= 10000 and v % 10000 == 0 else str(v)

static func format_time(sec: int) -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d" % [sec / 60, sec % 60]

static func _format_number(n: int) -> String:
	var s := str(n)
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res

# ---------------------------------------------------------------- Vòng chơi trên thuyền

func _ready() -> void:
	is_boat_sailing = true
	time_left = TIME_LIMIT_SEC
	_build_hud()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		_player.global_position = BOAT_SPAWN

	_say("Quý hiệp khách đã lên thuyền! Chuẩn bị xuất bến!")
	CountdownOverlay.start(self, func() -> void:
		if not running:
			running = true
			_say("Thuyền Phong Lăng Độ đã nhổ neo xuất bến! Cửa bến đã đóng, xin quý hiệp khách ổn định chỗ ngồi chiến đấu!")
	)
	_spawn_all_initial_pirates()

func _exit_tree() -> void:
	is_boat_sailing = false

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

	# Đếm ngược nhổ neo xuất bến
	if not running:
		_prepare -= delta
		_clock.text = ""
		if _prepare <= 0.0:
			running = true
			_say("Thuyền Phong Lăng Độ đã nhổ neo xuất bến! Cửa bến đã đóng, xin quý hiệp khách ổn định chỗ ngồi chiến đấu!")
		return

	# Kiểm tra người chơi tử trận
	var cur_hp := float(PlayerStats.health) if "health" in PlayerStats else 100.0
	var is_dead: bool = (PlayerStats.is_dead if "is_dead" in PlayerStats else false) or cur_hp <= 0.0
	if is_dead:
		_finish(false)
		return

	# Đếm ngược thời gian hành trình vượt sông
	time_left -= delta
	_clock.text = "Cập bến sau: %s" % format_time(maxi(0, ceili(time_left)))

	# Mốc giữa sông: 2 Thủy Tặc Đầu Lĩnh xuất hiện
	if not _spawned_mid_bosses and time_left <= MID_RIVER_TIME:
		_spawned_mid_bosses = true
		_spawn_mid_bosses()

	# Mốc cận bờ Bắc: Thủy Tặc Đại Đầu Lĩnh + Boss Yên Hiểu Trái áp mạn
	if not _spawned_final_bosses and time_left <= NEAR_SHORE_TIME:
		_spawned_final_bosses = true
		_spawn_final_bosses()

	# Cơ chế chi viện Thủy Tặc (farm liên tục trong suốt hành trình)
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_respawn_timer = RESPAWN_INTERVAL
		_reinforce_pirates()

	_update_info()

	# HẾT THỜI GIAN VƯỢT SÔNG = CẬP BẾN BỜ BẮC AN TOÀN!
	if time_left <= 0.0:
		_finish(true)

# ---------------------------------------------------------------- Sinh quái & Tiếp viện

## Xuất hiện 44 con Thủy Tặc đầu tiên rải khắp boong tàu theo tọa độ gốc
func _spawn_all_initial_pirates() -> void:
	for i in PIRATE_COORDS.size():
		var pos: Vector2 = PIRATE_COORDS[i]
		var tpl := MONSTER_THAN_TY if i % 2 == 0 else MONSTER_LANH_THUONG
		_spawn_pirate(tpl, 95, i % 5, pos, 50000, "")

## Tiếp viện bổ sung thủy tặc khi số lượng trên thuyền giảm
func _reinforce_pirates() -> void:
	# Dọn dẹp quái đã giải phóng
	_clean_alive_lists()
	if _alive_pirates.size() >= TARGET_PIRATE_COUNT:
		return

	var needed := TARGET_PIRATE_COUNT - _alive_pirates.size()
	var spawn_batch := mini(needed, 6)
	var available_coords: Array[Vector2] = []

	for pos in PIRATE_COORDS:
		var occupied := false
		for m in _alive_pirates:
			if is_instance_valid(m) and m.position.distance_to(pos) < 90.0:
				occupied = true
				break
		if not occupied:
			available_coords.append(pos)

	available_coords.shuffle()
	for i in mini(spawn_batch, available_coords.size()):
		var tpl := MONSTER_THAN_TY if randi() % 2 == 0 else MONSTER_LANH_THUONG
		_spawn_pirate(tpl, 95, randi() % 5, available_coords[i], 50000, "")

func _spawn_mid_bosses() -> void:
	_say("Sương mù nổi lên giữa sông! Hai tên Thủy Tặc Đầu Lĩnh đã áp sát mũi và đuôi thuyền!")
	for i in MID_BOSS_COORDS.size():
		var pos: Vector2 = MID_BOSS_COORDS[i]
		_spawn_boss(MONSTER_DAU_LINH, 100, (i + 2) % 5, pos, 280000, "Thủy Tặc Đầu Lĩnh", false)

func _spawn_final_bosses() -> void:
	_say("Thuyền đang áp sát bờ Bắc! Thủy Tặc Đại Đầu Lĩnh và Boss Hoàng Kim Yên Hiểu Trái áp mạn thuyền quyết chiến!")
	# Đại Đầu Lĩnh
	_spawn_boss(MONSTER_DAU_LINH, 105, 4, BOAT_SPAWN + Vector2(-260, 0), 450000, "Thủy Tặc Đại Đầu Lĩnh", false)
	# Boss Hoàng Kim Yên Hiểu Trái
	_spawn_boss(BOSS_YEN_HIEU_TRAI, 105, 2, BOAT_SPAWN + Vector2(240, -50), 1200000, "Yên Hiểu Trái", true)

func _spawn_pirate(tpl: int, lvl: int, series: int, pos: Vector2, hp: int, name_override: String) -> void:
	var base := MonsterData.monster(tpl)
	var parent := VltkWorld.entity_parent()
	if base.is_empty() or parent == null:
		return
	var m := VltkMonster.new()
	m.monster_id = tpl
	m.data = base.duplicate()
	m.data["series"] = series if series >= 0 and series <= 4 else randi() % 5
	if name_override != "":
		m.data["name"] = name_override
	m.level = lvl
	m.hp_override = maxi(1, hp)
	m.position = pos
	m.ai_enabled = true
	m.died.connect(func(_victim: VltkMonster) -> void:
		pirates_slain += 1
		_alive_pirates.erase(_victim)
	)
	parent.add_child(m)
	_alive_pirates.append(m)

func _spawn_boss(tpl: int, lvl: int, series: int, pos: Vector2, hp: int, boss_name: String, is_gold: bool) -> void:
	var base := MonsterData.monster(tpl)
	var parent := VltkWorld.entity_parent()
	if base.is_empty() or parent == null:
		return
	var m := VltkMonster.new()
	m.monster_id = tpl
	m.data = base.duplicate()
	m.data["name"] = boss_name
	m.data["series"] = series
	if is_gold:
		m.data["res"] = "boss023"
		m.gold_boss = true
	m.level = lvl
	m.hp_override = maxi(1, hp)
	m.position = pos
	m.ai_enabled = true
	m.died.connect(func(_victim: VltkMonster) -> void:
		if is_gold:
			gold_boss_slain += 1
			_say("Hảo hán đã hạ gục Boss Hoàng Kim Yên Hiểu Trái!")
		else:
			mid_bosses_slain += 1
			_say("Đã tiêu diệt Thủy Tặc Đầu Lĩnh!")
		_alive_bosses.erase(_victim)
	)
	parent.add_child(m)
	_alive_bosses.append(m)

func _clean_alive_lists() -> void:
	var clean_p: Array[VltkMonster] = []
	for m in _alive_pirates:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			clean_p.append(m)
	_alive_pirates = clean_p

	var clean_b: Array[VltkMonster] = []
	for b in _alive_bosses:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			clean_b.append(b)
	_alive_bosses = clean_b

# ---------------------------------------------------------------- Kết thúc & Thưởng

func _finish(success: bool) -> void:
	if done:
		return
	done = true
	running = false
	is_boat_sailing = false
	var used := int(TIME_LIMIT_SEC - maxf(time_left, 0.0))
	var profile := GameManager.local_profile

	if success:
		_reward(profile)
		var rec := _records()
		var mine: Dictionary = rec.get(_key(profile), {})
		var best := int(mine.get("best", 0))
		if best == 0 or used > best:
			mine["best"] = used
		rec[_key(profile)] = mine
		_save_records(rec)

		_say("Thuyền Phong Lăng Độ đã vượt sông Hoàng Hà cập bờ Bắc an toàn!")
		_title.text = "Cập Bến Bờ Bắc An Toàn!"
		_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_clock.text = "Hoàn Thành Hành Trình Vượt Sông"
		_info.text = "Chiến tích: Diệt %d Thủy tặc · %d Đầu Lĩnh · %s Boss Hoàng Kim" % [
			pirates_slain,
			mid_bosses_slain,
			"1" if gold_boss_slain > 0 else "0"
		]
	else:
		_clear_all_monsters()
		_say("Người chơi đã trọng thương hoặc bỏ cuộc! Hành trình vượt sông thất bại.")
		_title.text = "Vượt Sông Thất Bại!"
		_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_clock.text = "Thất Bại"
		_info.text = "Thuyền bị thủy tặc áp đảo!"

	finished.emit(success, used)
	_leave_in = LEAVE_AFTER_SEC

func _reward(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var base_exp := 400000
	var kill_bonus_exp := mini(pirates_slain * 3000 + mid_bosses_slain * 30000 + gold_boss_slain * 100000, 600000)
	var exp_gain := base_exp + kill_bonus_exp
	var gold_gain := 50000 + (pirates_slain * 500)

	var before := profile.level
	profile.add_exp(exp_gain)
	profile.prestige += 120
	profile.fuyuan += 120
	profile.gold += gold_gain
	SaveManager.save_profile(profile)
	SaveManager.flush_online()

	if _player and profile.level > before and _player.has_method("refresh_combat_stats"):
		_player.refresh_combat_stats()

	_say("Thưởng cập bến: +%s EXP, +120 Danh vọng, +120 Phúc duyên, +%s lượng!" % [
		_format_number(exp_gain),
		_format_number(gold_gain)
	])

func _clear_all_monsters() -> void:
	for m in _alive_pirates:
		if is_instance_valid(m):
			m.queue_free()
	_alive_pirates.clear()

	for b in _alive_bosses:
		if is_instance_valid(b):
			b.queue_free()
	_alive_bosses.clear()

func _go_home() -> void:
	is_boat_sailing = false
	GameManager.field_map = {}
	get_tree().change_scene_to_file(HUB_SCENE)

# ---------------------------------------------------------------- Giao diện HUD

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

	_title = _hud_label("Phong Lăng Độ — Thuyền Vượt Sông Hoàng Hà", 17, GameUi.GOLD)
	_clock = _hud_label("", 24, Color(1, 1, 1))
	_info = _hud_label("", 13, GameUi.TEXT)
	_stat_lbl = _hud_label("", 12, Color(0.7, 0.9, 1.0))

	for l in [_title, _clock, _info, _stat_lbl]:
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
	if not _info or not _stat_lbl:
		return
	var stage_name := "Chuẩn bị nhổ neo"
	if running:
		if time_left > MID_RIVER_TIME:
			stage_name = "Đoạn 1: Rời Bến · Trừ Diệt Thủy Tặc"
		elif time_left > NEAR_SHORE_TIME:
			stage_name = "Đoạn 2: Giữa Sông · Thủy Tặc Đầu Lĩnh Xuất Hiện"
		else:
			stage_name = "Đoạn 3: Cận Bờ Bắc · Boss Hoàng Kim Yên Hiểu Trái"

	_clean_alive_lists()
	var total_alive := _alive_pirates.size() + _alive_bosses.size()
	_info.text = "%s  (Trên thuyền: %d quái)" % [stage_name, total_alive]
	_stat_lbl.text = "Chiến tích đã diệt: %d Thủy tặc  |  %d Đầu Lĩnh  |  %s Boss Hoàng Kim" % [
		pirates_slain,
		mid_bosses_slain,
		"1" if gold_boss_slain > 0 else "0"
	]

func _say(text: String) -> void:
	if _player and _player.has_method("notify"):
		_player.notify(text)
	else:
		print("[Phong Lăng Độ] ", text)
