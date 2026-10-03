extends Node2D
class_name StateVisuals
## Hình ảnh báo nhân vật (player/quái/người chơi khác) đang dính buff/bùa — tự tạo bởi
## StatusEffectController khi có trạng thái đầu tiên, dùng chung cho mọi nhân vật:
##   - Vòng sáng nhấp nháy dưới chân: đỏ tím nếu có ít nhất 1 bùa, vàng nếu chỉ có buff.
##   - Hàng icon skill trên đầu, mỗi icon có vòng đếm ngược thời gian còn lại (icon chưa có ảnh thì vẽ
##     ô màu + chữ cái đầu tên skill).
## VLTK gốc dùng sprite trạng thái riêng (Skills.txt StateSpecialId) — khi có sprite, thay phần vẽ tại đây.

const COLOR_DEBUFF := Color(0.85, 0.25, 0.95)
const COLOR_BUFF := Color(1.0, 0.82, 0.3)
const RING_RADIUS := Vector2(26, 10)  ## elip dưới chân (góc nhìn xéo)
const ICON_SIZE := 18.0
const ICON_GAP := 3.0
## Độ cao hàng icon trên tâm nhân vật — lấy theo thanh máu nếu nhân vật có node "HealthBar".
const DEFAULT_HEAD_OFFSET := -64.0

var controller: StatusEffectController
var _time: float = 0.0

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	_time += delta
	if controller == null or not is_instance_valid(controller):
		queue_free()
		return
	visible = not controller.get_state_display_list().is_empty()
	if visible:
		queue_redraw()

func _draw() -> void:
	var states := controller.get_state_display_list()
	if states.is_empty():
		return
	var has_debuff := false
	for st in states:
		if st["meta"].get("is_debuff", false):
			has_debuff = true
	_draw_ring(COLOR_DEBUFF if has_debuff else COLOR_BUFF)

	var head_y := _head_offset()
	var total_w := states.size() * ICON_SIZE + (states.size() - 1) * ICON_GAP
	var x := -total_w * 0.5
	for st in states:
		_draw_icon(Rect2(x, head_y - ICON_SIZE, ICON_SIZE, ICON_SIZE), st)
		x += ICON_SIZE + ICON_GAP

func _draw_ring(color: Color) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var scale_k := 1.0 + 0.08 * pulse
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(Vector2(cos(a) * RING_RADIUS.x, sin(a) * RING_RADIUS.y) * scale_k + Vector2(0, 6))
	var c := color
	c.a = 0.35 + 0.35 * pulse
	draw_polyline(points, c, 2.5, true)

func _draw_icon(rect: Rect2, st: Dictionary) -> void:
	var meta: Dictionary = st["meta"]
	var is_debuff: bool = meta.get("is_debuff", false)
	var border := COLOR_DEBUFF if is_debuff else COLOR_BUFF
	var icon: Texture2D = meta.get("icon")
	if icon:
		draw_texture_rect(icon, rect, false)
	else:
		draw_rect(rect, Color(border.r, border.g, border.b, 0.55))
		var name_text: String = meta.get("name", "?")
		var font := ThemeDB.fallback_font
		draw_string(font, rect.position + Vector2(4, 14), name_text.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_rect(rect, border, false, 1.5)
	## Vòng đếm ngược: cung còn lại = thời gian còn / tổng thời gian.
	var ratio := clampf(st["time"] / maxf(st["duration"], 0.001), 0.0, 1.0)
	draw_arc(rect.get_center(), ICON_SIZE * 0.5 + 2.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, border, 2.0, true)

func _head_offset() -> float:
	var owner_node := get_parent()
	var bar: Node = owner_node.get_node_or_null("HealthBar") if owner_node else null
	if bar is Node2D:
		return bar.position.y - 6.0
	if bar is Control:
		return bar.position.y - 6.0
	return DEFAULT_HEAD_OFFSET
