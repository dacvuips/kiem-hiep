extends Control
class_name StateIconBar
## Hàng biểu tượng buff/bùa/hào quang của NGƯỜI CHƠI, đặt ngay dưới thanh máu/nội lực góc trên trái (PlayerStatusHud).
## Tự ẩn khi không có gì. Hiển thị thời gian đếm ngược kết thúc cho bùa và buff có thời hạn.

const ICON_SIZE := 26.0
const GAP := 4.0
const COLOR_TEXT_DEBUFF := Color(1.0, 0.45, 0.45)
const COLOR_TEXT_BUFF := Color(1.0, 0.88, 0.3)

var _player: Node
var _controller: StatusEffectController

func setup(player: Node) -> void:
	_player = player
	_controller = player.get_node_or_null("StatusEffectController")
	custom_minimum_size = Vector2(0, ICON_SIZE + 16.0)
	visible = false

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var has_any := not _entries().is_empty()
	if visible != has_any:
		visible = has_any
	if has_any:
		queue_redraw()

## [{icon, name, debuff, ratio, time}] — ratio < 0 = không có đếm ngược (hào quang).
func _entries() -> Array:
	var out := []
	var profile := GameManager.local_profile
	if profile != null and profile.active_aura_id != "":
		var sect := SectRegistry.get_by_id(profile.sect_id)
		if sect:
			for skill in sect.skills:
				if skill.id == profile.active_aura_id:
					out.append({"icon": skill.icon, "name": skill.skill_name, "debuff": false, "ratio": -1.0, "time": -1.0})
					break
	if _controller != null and is_instance_valid(_controller):
		for st in _controller.get_state_display_list():
			var meta: Dictionary = st["meta"]
			var time_left: float = float(st.get("time", 0.0))
			var duration: float = float(st.get("duration", 0.0))
			out.append({
				"icon": meta.get("icon"),
				"name": str(meta.get("name", "?")),
				"debuff": bool(meta.get("is_debuff", false)),
				"ratio": clampf(time_left / maxf(duration, 0.001), 0.0, 1.0),
				"time": time_left,
			})
	return out

func _draw() -> void:
	var x := 1.0
	for e in _entries():
		var rect := Rect2(x, 1.0, ICON_SIZE, ICON_SIZE)
		var is_aura: bool = e["ratio"] < 0.0
		var icon: Texture2D = e["icon"]
		if icon:
			draw_texture_rect(icon, rect, false)
		else:
			draw_rect(rect, Color(0.18, 0.16, 0.14, 0.85))
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(7, 18), str(e["name"]).substr(0, 1).to_upper(),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

		# Thời gian kết thúc cho bùa / buff có thời hạn
		var time_left: float = float(e.get("time", -1.0))
		if not is_aura and time_left > 0.0:
			var time_text := _format_time(time_left)
			if time_text != "":
				var font: Font = ThemeDB.fallback_font
				var font_size := 11
				var text_pos := Vector2(rect.position.x - 2.0, rect.position.y + ICON_SIZE + 11.0)
				var text_w := ICON_SIZE + 4.0
				var text_color: Color = COLOR_TEXT_DEBUFF if e.get("debuff", false) else COLOR_TEXT_BUFF
				draw_string_outline(font, text_pos, time_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size, 3, Color.BLACK)
				draw_string(font, text_pos, time_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size, text_color)

		x += ICON_SIZE + GAP

static func _format_time(time_left: float) -> String:
	if time_left <= 0.0:
		return ""
	if time_left >= 3600.0:
		return "%dh" % ceili(time_left / 3600.0)
	if time_left >= 60.0:
		var m := int(time_left) / 60
		var s := int(time_left) % 60
		return "%d:%02d" % [m, s]
	return "%ds" % ceili(time_left)
