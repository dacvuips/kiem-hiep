extends Node2D
class_name NamePlate
## Bảng tên trên đầu quái / NPC (như VLTK gốc): ẢNH HỆ NGŨ HÀNH + tên, nằm ngay trên thanh máu.
## Ảnh hệ = ảnh gốc Spr/Ui3/Npc/series<hệ>.spr (GameSetting.ini [Series] Image, KNpc::PaintName) — xuất bởi
## tools/import_vltk_series_icons.py ra assets/ui/series/. Gốc node = giữa, ngay trên thanh máu (đặt bằng place_above()).
## Chỉ vẽ lại khi đổi tên/hệ -> rẻ cho mobile.

const FONT_SIZE := 13
const GAP := 4.0
const NAME_COLOR := Color(0.96, 0.95, 0.88)
const BOSS_NAME_COLOR := Color(0.45, 0.72, 1.0)   ## boss xanh: tên màu xanh dương
const GOLD_BOSS_NAME_COLOR := Color(1.0, 0.85, 0.15)   ## boss hoàng kim: tên màu vàng rực rỡ
const OUTLINE_SIZE := 3
## Thứ tự hệ = ElementTypes (Kim, Mộc, Thủy, Hỏa, Thổ) = số hệ của series%d.spr gốc.
const SERIES_ICONS: Array[Texture2D] = [
	preload("res://assets/ui/series/series_0.png"), preload("res://assets/ui/series/series_1.png"),
	preload("res://assets/ui/series/series_2.png"), preload("res://assets/ui/series/series_3.png"),
	preload("res://assets/ui/series/series_4.png"),
]

var _text := ""
var _icon: Texture2D
var _name_color := NAME_COLOR
var side_color: Color = Color.TRANSPARENT

func set_side_color(c: Color) -> void:
	side_color = c
	if side_color != Color.TRANSPARENT:
		_name_color = side_color
	queue_redraw()

func setup(display_name: String, element: ElementTypes.ElementType, boss: bool = false, is_gold: bool = false) -> void:
	_text = ("[Hoàng Kim] " + display_name) if is_gold else display_name
	if side_color != Color.TRANSPARENT:
		_name_color = side_color
	elif is_gold:
		_name_color = GOLD_BOSS_NAME_COLOR
	elif boss:
		_name_color = BOSS_NAME_COLOR
	else:
		_name_color = NAME_COLOR
	_icon = SERIES_ICONS[clampi(int(element), 0, SERIES_ICONS.size() - 1)]
	z_index = 5
	queue_redraw()

## Đặt ngay trên thanh máu `bar` (HealthBar: thanh cao từ y-13 đến y-7 quanh gốc của nó).
func place_above(bar: Node2D) -> void:
	position = bar.position + Vector2(0, -17.0)

func _draw() -> void:
	if _text == "":
		return
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var icon_size := _icon.get_size()
	var left := roundf(-(icon_size.x + GAP + text_size.x) * 0.5)
	## Ảnh hệ (gốc 18x18, vẽ đúng cỡ, toạ độ nguyên cho nét) căn giữa theo chiều cao chữ, đứng trước tên.
	draw_texture(_icon, Vector2(left, roundf(-text_size.y * 0.5 + 1.0 - icon_size.y * 0.5)))
	var pos := Vector2(left + icon_size.x + GAP, 0.0)
	draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, Color(0, 0, 0, 0.9))
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _name_color)
