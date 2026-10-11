extends Control
class_name StateIconBar
## Hàng biểu tượng buff/bùa/hào quang của NGƯỜI CHƠI, đặt ngay dưới thanh máu/nội lực góc trên trái (PlayerStatusHud). Mỗi
## biểu tượng có vòng đếm ngược thời gian còn lại (hào quang đang bật không có đếm ngược, viền vàng). Tự ẩn khi không có gì.
## Trước đây hàng này nằm trên đầu nhân vật (StateVisuals) — giờ chỉ quái/người chơi khác còn hiện trên đầu.

const ICON_SIZE := 26.0
const GAP := 4.0
const COLOR_BUFF := Color(1.0, 0.82, 0.3)
const COLOR_DEBUFF := Color(0.85, 0.25, 0.95)
const COLOR_AURA := Color(0.45, 0.9, 1.0)

var _player: Node
var _controller: StatusEffectController

func setup(player: Node) -> void:
	_player = player
	_controller = player.get_node_or_null("StatusEffectController")
	custom_minimum_size = Vector2(0, ICON_SIZE + 2.0)
	visible = false

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var has_any := not _entries().is_empty()
	if visible != has_any:
		visible = has_any
	if has_any:
		queue_redraw()

## [{icon, name, debuff, ratio}] — ratio < 0 = không có đếm ngược (hào quang).
func _entries() -> Array:
	var out := []
	var profile := GameManager.local_profile
	if profile != null and profile.active_aura_id != "":
		var sect := SectRegistry.get_by_id(profile.sect_id)
		if sect:
			for skill in sect.skills:
				if skill.id == profile.active_aura_id:
					out.append({"icon": skill.icon, "name": skill.skill_name, "debuff": false, "ratio": -1.0})
					break
	if _controller != null and is_instance_valid(_controller):
		for st in _controller.get_state_display_list():
			var meta: Dictionary = st["meta"]
			out.append({"icon": meta.get("icon"), "name": str(meta.get("name", "?")), "debuff": bool(meta.get("is_debuff", false)),
					"ratio": clampf(st["time"] / maxf(st["duration"], 0.001), 0.0, 1.0)})
	return out

func _draw() -> void:
	var x := 1.0
	for e in _entries():
		var rect := Rect2(x, 1.0, ICON_SIZE, ICON_SIZE)
		var is_aura: bool = e["ratio"] < 0.0
		var border: Color = COLOR_AURA if is_aura else (COLOR_DEBUFF if e["debuff"] else COLOR_BUFF)
		var icon: Texture2D = e["icon"]
		if icon:
			draw_texture_rect(icon, rect, false)
		else:
			draw_rect(rect, Color(border.r, border.g, border.b, 0.55))
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(7, 18), str(e["name"]).substr(0, 1).to_upper(),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_rect(rect, border, false, 1.5)
		if not is_aura:
			draw_arc(rect.get_center(), ICON_SIZE * 0.5 + 2.0, -PI * 0.5, -PI * 0.5 + TAU * float(e["ratio"]), 24, border, 2.0, true)
		x += ICON_SIZE + GAP
