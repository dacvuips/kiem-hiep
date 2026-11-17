extends Node2D
class_name GuildTag
const GuildEmblem = preload("res://systems/social/guild_emblem.gd")
## Dòng tên Bang Hội + Biểu tượng bang trên đầu nhân vật (dùng chung cho Player và RemotePlayer).
## Vẽ trực tiếp bằng _draw() ở z_index = 12 để luôn nổi trên nhân vật và hiệu ứng buff/hào quang.
## Đặt ngay trên nhãn tên nhân vật qua place_above(name_top_y).

const FONT_SIZE := 12
const ICON_DRAW_SIZE := Vector2(15.0, 15.0)
const GAP := 3.0
const ROW_HEIGHT := 18.0
const OUTLINE_SIZE := 4
const GUILD_COLOR := Color(0.46, 1.0, 0.46)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.94)

var _guild_name := ""
var _emblem_id := 0
var _text := ""
var _icon: Texture2D = null
var _suppressed := false

func _init() -> void:
	z_index = 12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false

func has_guild() -> bool:
	return _text != ""

func set_guild(guild_name: String, emblem_id: int = 0) -> void:
	var clean := guild_name.strip_edges()
	var resolved := emblem_id if emblem_id > 0 else (GuildEmblem.resolve_id({"name": clean}) if clean != "" else 0)
	if clean == _guild_name and resolved == _emblem_id:
		return
	_guild_name = clean
	_emblem_id = resolved
	_text = "[%s]" % clean if clean != "" else ""
	_icon = GuildEmblem.get_texture(resolved) if clean != "" and resolved > 0 else null
	visible = has_guild() and not _suppressed
	queue_redraw()

func set_suppressed(hidden: bool) -> void:
	_suppressed = hidden
	visible = has_guild() and not _suppressed

func place_above(name_top_y: float) -> void:
	position = Vector2(0.0, name_top_y - 3.0)

func top_y() -> float:
	return position.y - ROW_HEIGHT if has_guild() else position.y

func _draw() -> void:
	if _text == "":
		return
	var font := GameUi.game_font_bold() if GameUi else ThemeDB.fallback_font
	if font == null:
		font = ThemeDB.fallback_font
	var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var icon_w := ICON_DRAW_SIZE.x + GAP if _icon != null else 0.0
	var total_w := icon_w + text_size.x
	var left := roundf(-total_w * 0.5)
	var baseline_y := -3.0
	if _icon != null:
		var icon_y := roundf(baseline_y - font.get_ascent(FONT_SIZE) * 0.5 - ICON_DRAW_SIZE.y * 0.5)
		draw_texture_rect(_icon, Rect2(Vector2(left, icon_y), ICON_DRAW_SIZE), false)
	var text_pos := Vector2(left + icon_w, baseline_y)
	draw_string_outline(font, text_pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, OUTLINE_COLOR)
	draw_string(font, text_pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GUILD_COLOR)
