extends Node2D
class_name GroundDrop
## Vật rớt nằm trên đất (tiền hoặc 1 món đồ). Phải NHẤP vào mới nhặt (đi ngang qua không nhặt): tiền cộng vào PlayerProfile.gold, đồ vào
## Hành trang (đầy túi thì để lại). Biến mất sau LIFETIME giây. Gốc node = chỗ rơi (chân). Tên màu theo phẩm chất (xanh = đồ có dòng magic).

const REACH := 44.0                 ## đứng cách vật rớt chừng này (pixel) thì mới nhặt được
const CLICK_RADIUS := 30.0
const LIFETIME := 90.0
const BLINK_TIME := 12.0
const SCROLL_SHEET_PATH := "res://assets/items/ground/item_shenmituzhi.png"
const SCROLL_FRAMES := 7
const SCROLL_FPS := 1000.0 / 230.0  ## interval=230ms từ item_shenmituzhi.spr gốc
const MONEY_FRAMES := 7
const MONEY_FPS := 1000.0 / 135.0   ## interval=135ms từ obj_money_01..05.spr gốc
const MONEY_FALL_META := {
	1: [13, 1000.0 / 73.0],
	2: [13, 1000.0 / 73.0],
	3: [15, 1000.0 / 63.0],
	4: [15, 1000.0 / 63.0],
	5: [15, 1000.0 / 63.0],
}
const GROUND_SPRITES_PATH := "res://data/items/ground_sprites.json"

static var _scroll_sheet: Texture2D = null
static var _scroll_sheet_tried := false
static var _money_sheets: Dictionary = {}
static var _money_fall_sheets: Dictionary = {}
static var _ground_db: Dictionary = {}
static var _ground_db_tried := false
static var _ground_tex_cache: Dictionary = {}

static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

static func _get_scroll_sheet() -> Texture2D:
	if not _scroll_sheet_tried:
		_scroll_sheet_tried = true
		_scroll_sheet = _load_tex(SCROLL_SHEET_PATH)
	return _scroll_sheet

## Phân cấp 5 mức đống tiền theo MoneyObj.txt gốc (200 / 1000 / 5000 / 10000 / >10000).
static func money_tier_for_amount(value: int) -> int:
	if value <= 200:
		return 1
	if value <= 1000:
		return 2
	if value <= 5000:
		return 3
	if value <= 10000:
		return 4
	return 5

static func _get_money_sheet(tier: int, falling: bool = false) -> Texture2D:
	var t := clampi(tier, 1, 5)
	var cache := _money_fall_sheets if falling else _money_sheets
	if not cache.has(t):
		var suffix := "_fall" if falling else ""
		cache[t] = _load_tex("res://assets/items/ground/obj_money_%02d%s.png" % [t, suffix])
	return cache[t]

static func _ensure_ground_db() -> void:
	if _ground_db_tried:
		return
	_ground_db_tried = true
	var f := FileAccess.open(GROUND_SPRITES_PATH, FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_ground_db = parsed

static func get_item_ground_info(it: ItemInstance) -> Dictionary:
	if it == null:
		return {}
	_ensure_ground_db()
	if _ground_db.is_empty():
		return {}
	var oid := 0
	if it.misc_id != "":
		var by_misc: Dictionary = _ground_db.get("by_misc", {})
		oid = int(by_misc.get(it.misc_id, 0))
	else:
		var rec: Dictionary = it.get_base()
		var img_key := str(rec.get("image", "")).to_lower()
		var by_image: Dictionary = _ground_db.get("by_image", {})
		if img_key != "" and by_image.has(img_key):
			oid = int(by_image[img_key])
		else:
			var det := int(rec.get("detail", -1))
			var par := int(rec.get("particular", -1))
			var dp_key := "%d_%d" % [det, par]
			var by_dp: Dictionary = _ground_db.get("by_dp", {})
			if by_dp.has(dp_key):
				oid = int(by_dp[dp_key])
			else:
				var by_detail: Dictionary = _ground_db.get("by_detail", {})
				oid = int(by_detail.get(str(det), 0))
	if oid <= 0:
		return {}
	var objs: Dictionary = _ground_db.get("objs", {})
	return objs.get(str(oid), {})

static func _get_ground_sheet(stem: String) -> Texture2D:
	if stem == "":
		return null
	if not _ground_tex_cache.has(stem):
		_ground_tex_cache[stem] = _load_tex("res://assets/items/ground/%s.png" % stem)
	return _ground_tex_cache[stem]

var amount: int = 0                 ## > 0 = tiền
var item: ItemInstance = null
var _time := 0.0
var _want_pickup := false        ## đã bấm vào, đang đi tới để nhặt
var _hover := false
var _full_bag_cooldown: float = 0.0
var _label := ""
var _color := Color.WHITE
var _icon: Texture2D
var _ground_info: Dictionary = {}
## Đồ do người chơi tự VỨT từ hành trang: không tự nhặt lại khi đứng gần / đi ngang qua và auto không nhặt (nếu không vứt xong
## sẽ bị nhặt lại ngay vì rơi dưới chân). Muốn lấy lại thì NHẤP vào.
var discarded := false
## uid các món vừa vứt khi online — server gửi vật rớt về sau, gặp uid này thì đánh dấu discarded.
static var _discarded_uids: Dictionary = {}

static func mark_discarded(uid: String) -> void:
	if uid == "":
		return
	_discarded_uids[uid] = true
	if _discarded_uids.size() > 64:
		_discarded_uids.erase(_discarded_uids.keys()[0])

## Nhóm để AutoController quét vật rớt quanh người (không phải lục cả cây node).
const GROUP := &"ground_drops"

func _enter_tree() -> void:
	add_to_group(GROUP)

func setup_money(value: int) -> void:
	amount = value
	_label = "%d lượng" % value
	_color = Color(1.0, 0.86, 0.25)
	z_index = 4

func setup_item(it: ItemInstance) -> void:
	item = it
	_label = it.get_display_name()
	_color = it.get_quality_color()
	_ground_info = get_item_ground_info(it)
	_icon = it.get_icon(true)
	z_index = 4
	if _discarded_uids.has(it.uid):
		_discarded_uids.erase(it.uid)
		discarded = true

func _process(delta: float) -> void:
	_time += delta
	if _full_bag_cooldown > 0.0:
		_full_bag_cooldown -= delta
	if _net_pick_wait > 0.0:
		_net_pick_wait -= delta
	if _time >= LIFETIME:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var dist := _player_feet(player).distance_to(global_position)
		# Đi ngang qua là có thể nhặt tiền và đồ vào hành trang tự động
		var pickup_reach := REACH + 25.0
		if GameManager.game_mode == GameManager.GameMode.STAGE or GameManager.field_map.get("survivor_mode", false):
			pickup_reach = maxf(pickup_reach, float(PlayerStats.pickup_radius))
		if dist <= pickup_reach and _full_bag_cooldown <= 0.0 and not discarded:
			_pick_up(player)
			return
		if _want_pickup:
			if dist <= REACH:
				_want_pickup = false
				_pick_up(player)
				return
			if player.has_method("is_moving_to_target") and not player.is_moving_to_target():
				_want_pickup = false
	_hover = get_global_mouse_position().distance_to(global_position + Vector2(0, -12)) <= CLICK_RADIUS
	queue_redraw()

## Auto nhặt đồ: đứng đủ gần thì nhặt ngay (true = đã gửi lệnh nhặt), xa thì để người gọi tự chạy tới.
func try_auto_pick(player: Node2D) -> bool:
	if _player_feet(player).distance_to(global_position) > REACH:
		return false
	_pick_up(player)
	return true

func _player_feet(player: Node2D) -> Vector2:
	return player.global_position + Vector2(0, 30)

## NHẤP vào vật rớt mới nhặt (đi ngang qua không tự nhặt). Ở xa thì nhân vật tự chạy tới rồi nhặt.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	## Toạ độ thế giới của chỗ bấm lấy thẳng từ sự kiện (không phụ thuộc vị trí con trỏ lưu sẵn trong viewport).
	var click_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
	if click_world.distance_to(global_position + Vector2(0, -12)) > CLICK_RADIUS:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	get_viewport().set_input_as_handled()
	if _player_feet(player).distance_to(global_position) <= REACH:
		_pick_up(player)
	else:
		_want_pickup = true
		if player.has_method("walk_to_feet"):
			player.walk_to_feet(global_position)

## Online: đồ rơi do game server tạo (net_id != 0) — nhặt = xin server; server đồng ý (S_PICKED) thì NetWorldSync mới cộng.
var net_id: int = 0
## Online: đi ngang qua đồ chưa được nhặt (của người ngoài đội / chưa tới lượt) thì mỗi khung hình đều xin nhặt -> server báo lỗi
## liên tục. Giãn cách lần xin kế tiếp NET_PICK_RETRY giây.
const NET_PICK_RETRY := 1.0
var _net_pick_wait := 0.0

func _pick_up(player: Node) -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	if net_id != 0:
		if _net_pick_wait > 0.0:
			return
		_net_pick_wait = NET_PICK_RETRY
		NetClient.send_pickup(net_id)
		return
	## Tổ đội: chế độ nhặt đồ (đội trưởng nhặt / luân phiên) quyết định mình có được nhặt lúc này không.
	var team := SocialHub.of(profile).team
	if not team.can_local_pick():
		_notice(player, "Theo luật nhặt đồ của tổ đội, chưa tới lượt bạn nhặt.")
		return
	if amount > 0:
		if GameManager.field_map.get("tong_kim_lol", false) == true:
			var s := TongKimLolState.instance()
			if s:
				s.add_gold(amount)
				_notice(player, "Nhặt được %d Vàng Tống Kim" % amount)
		else:
			profile.gold += amount
			_notice(player, "Nhặt được %d lượng" % amount)
	elif item != null:
		if item.misc_id in ["6_1_206", "6_1_213"]:
			var cur_map_id: int = int(GameManager.field_map.get("id", -1)) if GameManager else -1
			var res := DaTauManager.try_collect_picked_scroll(profile, item.misc_id, cur_map_id)
			if res.get("counted", false):
				_notice(player, "Nhặt được %s (%d/%d) — Dã Tẩu đã ghi nhận" % [res.get("name", "Địa đồ chí"), res.get("done", 1), res.get("need", 1)])
			elif res.get("bag_full", false):
				_notice(player, "Hành trang đã đầy, không thể nhặt %s!" % res.get("name", "Địa đồ chí"))
				_time = maxf(_time, LIFETIME - 5.0)
				return
			else:
				_notice(player, "Nhặt được %s → +1 mảnh Sơn Hà Xã Tắc (Hiện có: %d)" % [res.get("name", item.get_display_name()), int(res.get("shxt_total", 1))])
			team.advance_turn()
			SaveManager.save_profile(profile)
			queue_free()
			return
		if not profile.add_item_stacked(item):
			_full_bag_cooldown = 2.0
			_notice(player, "Hành trang đã đầy")
			_time = maxf(_time, LIFETIME - 5.0)   ## để lại trên đất thêm chút nữa
			return
		_notice(player, "Nhặt được %s" % item.get_display_name())
	team.advance_turn()
	SaveManager.save_profile(profile)
	queue_free()

func _notice(player: Node, text: String) -> void:
	if player.has_method("_notice"):
		player._notice(text)

const GROUND_DRAW_SCALE := 0.85

func _draw_sheet_frame(sheet: Texture2D, frames: int, frame: int, lift: float, max_dim: float = 0.0) -> void:
	var fw := sheet.get_width() / float(maxi(frames, 1))
	var fh := float(sheet.get_height())
	var s := GROUND_DRAW_SCALE
	if max_dim > 0.0:
		s = minf(s, minf(max_dim / maxf(fw, 1.0), max_dim / maxf(fh, 1.0)))
	var dst_size := Vector2(fw * s, fh * s)
	draw_texture_rect_region(
		sheet,
		Rect2(Vector2(-dst_size.x * 0.5, -dst_size.y + 3.0 + lift), dst_size),
		Rect2(Vector2(frame * fw, 0.0), Vector2(fw, fh))
	)

func _draw() -> void:
	if _time > LIFETIME - BLINK_TIME and int(_time * 4.0) % 2 == 0:
		return
	var lift := 0.0   ## nằm yên trên đất, không bay lơ lửng
	if _hover:
		draw_arc(Vector2(0, -10 + lift), 14.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.5)
	draw_circle(Vector2(0, 0), 5.0, Color(0, 0, 0, 0.25))
	if amount > 0:
		var tier := money_tier_for_amount(amount)
		var fall_info: Array = MONEY_FALL_META.get(tier, [13, 1000.0 / 73.0])
		var fall_frames: int = fall_info[0]
		var fall_fps: float = fall_info[1]
		var fall_sheet: Texture2D = _get_money_sheet(tier, true) if _time * fall_fps < float(fall_frames) else null
		var idle_sheet: Texture2D = _get_money_sheet(tier, false)
		var sheet := fall_sheet if fall_sheet != null else idle_sheet
		if sheet != null:
			var frames := fall_frames if fall_sheet != null else MONEY_FRAMES
			var frame := clampi(int(_time * fall_fps), 0, frames - 1) if fall_sheet != null else (int(_time * MONEY_FPS) % frames)
			_draw_sheet_frame(sheet, frames, frame, lift)
		else:
			draw_circle(Vector2(0, -8 + lift), 6.0, Color(0.35, 0.22, 0.02))
			draw_circle(Vector2(0, -8 + lift), 4.5, _color)
			draw_circle(Vector2(-1.2, -9.5 + lift), 1.5, Color(1, 1, 0.8, 0.85))
	elif item != null and item.misc_id in ["6_1_206", "6_1_213", "6_1_196"] and _get_scroll_sheet() != null:
		_draw_sheet_frame(_get_scroll_sheet(), SCROLL_FRAMES, int(_time * SCROLL_FPS) % SCROLL_FRAMES, lift, 36.0)
	elif item != null and not _ground_info.is_empty():
		var fall_frames := int(_ground_info.get("fall_frames", 0))
		var fall_fps := float(_ground_info.get("fall_fps", 15.0))
		var fall_stem := str(_ground_info.get("fall", ""))
		var use_fall := fall_stem != "" and fall_frames > 0 and _time * fall_fps < float(fall_frames)
		var sheet := _get_ground_sheet(fall_stem) if use_fall else _get_ground_sheet(str(_ground_info.get("idle", "")))
		if sheet != null:
			var frames := fall_frames if use_fall else maxi(int(_ground_info.get("frames", 1)), 1)
			var fps := fall_fps if use_fall else float(_ground_info.get("fps", 8.0))
			var frame := clampi(int(_time * fps), 0, frames - 1) if use_fall else (int(_time * fps) % frames)
			_draw_sheet_frame(sheet, frames, frame, lift, 44.0 if not use_fall else 0.0)
		elif _icon != null:
			var s := minf(24.0 / _icon.get_width(), 24.0 / _icon.get_height())
			draw_texture_rect(_icon, Rect2(Vector2(-_icon.get_width() * s * 0.5, -_icon.get_height() * s - 3 + lift), _icon.get_size() * s), false)
		else:
			draw_rect(Rect2(-7, -18 + lift, 14, 14), _color)
	elif _icon != null:
		var s := minf(24.0 / _icon.get_width(), 24.0 / _icon.get_height())
		draw_texture_rect(_icon, Rect2(Vector2(-_icon.get_width() * s * 0.5, -_icon.get_height() * s - 3 + lift), _icon.get_size() * s), false)
	else:
		draw_rect(Rect2(-7, -18 + lift, 14, 14), _color)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(font, Vector2(-w * 0.5, -28 + lift), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(-w * 0.5, -28 + lift), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _color)

## Rải các vật rớt quanh `at` (toạ độ chân quái) vào `parent`.
static func spawn_drops(parent: Node, at: Vector2, drops: Array) -> void:
	for i in drops.size():
		var d: Dictionary = drops[i]
		var g := GroundDrop.new()
		var drop_type: String = str(d.get("type", ""))
		if drop_type == "money" or d.has("money") or (d.has("amount") and not d.has("item")):
			var amt: int = int(d.get("amount", d.get("money", 0)))
			if GameModeManager.is_offline() or GameManager.field_map.get("survivor_mode", false):
				amt *= 10
			g.setup_money(amt)
		elif drop_type == "item" or d.has("item"):
			var it = d.get("item", null)
			if it is ItemInstance:
				g.setup_item(it)
				if bool(d.get("discarded", false)):
					g.discarded = true
			else:
				continue
		else:
			continue
		g.position = at + Vector2(randf_range(-22, 22), randf_range(-8, 8)) * (1 if drops.size() > 1 else 0.4)
		parent.add_child(g)
