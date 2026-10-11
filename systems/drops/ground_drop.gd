extends Node2D
class_name GroundDrop
## Vật rớt nằm trên đất (tiền hoặc 1 món đồ). Phải NHẤP vào mới nhặt (đi ngang qua không nhặt): tiền cộng vào PlayerProfile.gold, đồ vào
## Hành trang (đầy túi thì để lại). Biến mất sau LIFETIME giây. Gốc node = chỗ rơi (chân). Tên màu theo phẩm chất (xanh = đồ có dòng magic).

const REACH := 44.0                 ## đứng cách vật rớt chừng này (pixel) thì mới nhặt được
const CLICK_RADIUS := 30.0
const LIFETIME := 90.0
const BLINK_TIME := 12.0

var amount: int = 0                 ## > 0 = tiền
var item: ItemInstance = null
var _time := 0.0
var _want_pickup := false        ## đã bấm vào, đang đi tới để nhặt
var _hover := false
var _label := ""
var _color := Color.WHITE
var _icon: Texture2D

func setup_money(value: int) -> void:
	amount = value
	_label = "%d lượng" % value
	_color = Color(1.0, 0.86, 0.25)
	z_index = 4

func setup_item(it: ItemInstance) -> void:
	item = it
	_label = it.get_display_name()
	_color = it.get_quality_color()
	_icon = it.get_icon(true)
	z_index = 4

func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and _want_pickup:
		if _player_feet(player).distance_to(global_position) <= REACH:
			_want_pickup = false
			_pick_up(player)
			return
		if player.has_method("is_moving_to_target") and not player.is_moving_to_target():
			_want_pickup = false      ## người chơi đã đổi ý / bị chặn đường
	_hover = get_global_mouse_position().distance_to(global_position + Vector2(0, -12)) <= CLICK_RADIUS
	queue_redraw()

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

func _pick_up(player: Node) -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	if net_id != 0:
		NetClient.send_pickup(net_id)
		return
	## Tổ đội: chế độ nhặt đồ (đội trưởng nhặt / luân phiên) quyết định mình có được nhặt lúc này không.
	var team := SocialHub.of(profile).team
	if not team.can_local_pick():
		_notice(player, "Theo luật nhặt đồ của tổ đội, chưa tới lượt bạn nhặt.")
		return
	if amount > 0:
		profile.gold += amount
		_notice(player, "Nhặt được %d lượng" % amount)
	elif item != null:
		if not profile.add_item(item):
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

func _draw() -> void:
	if _time > LIFETIME - BLINK_TIME and int(_time * 4.0) % 2 == 0:
		return
	var lift := 0.0   ## nằm yên trên đất, không bay lơ lửng
	if _hover:
		draw_arc(Vector2(0, -12 + lift), 17.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.5)
	draw_circle(Vector2(0, 0), 7.0, Color(0, 0, 0, 0.3))
	if amount > 0:
		draw_circle(Vector2(0, -10 + lift), 7.0, Color(0.35, 0.22, 0.02))
		draw_circle(Vector2(0, -10 + lift), 5.5, _color)
		draw_circle(Vector2(-1.5, -12 + lift), 1.8, Color(1, 1, 0.8, 0.85))
	elif _icon != null:
		var s := minf(32.0 / _icon.get_width(), 32.0 / _icon.get_height())
		draw_texture_rect(_icon, Rect2(Vector2(-_icon.get_width() * s * 0.5, -_icon.get_height() * s - 4 + lift), _icon.get_size() * s), false)
	else:
		draw_rect(Rect2(-8, -22 + lift, 16, 16), _color)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string_outline(font, Vector2(-w * 0.5, -40 + lift), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(-w * 0.5, -40 + lift), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _color)

## Rải các vật rớt quanh `at` (toạ độ chân quái) vào `parent`.
static func spawn_drops(parent: Node, at: Vector2, drops: Array) -> void:
	for i in drops.size():
		var d: Dictionary = drops[i]
		var g := GroundDrop.new()
		if str(d["type"]) == "money":
			g.setup_money(int(d["amount"]))
		else:
			g.setup_item(d["item"])
		g.position = at + Vector2(randf_range(-22, 22), randf_range(-8, 8)) * (1 if drops.size() > 1 else 0.4)
		parent.add_child(g)
