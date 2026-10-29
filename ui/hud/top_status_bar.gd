extends Control
class_name TopStatusBar
## THANH TRẠNG THÁI VLTK ở giữa phía trên màn hình — dùng ĐÚNG ảnh gốc (UiHeaderControlBar.ini, ảnh trích bằng
## tools/import_vltk_topbar.py): panel nền "新血条面板" (đã có chữ Cấp/Hạng, biểu tượng, các ô thanh) + ảnh phần đầy của
## Thể lực (xanh lục) · Sinh lực (đỏ) · Nội lực (xanh dương) · Kinh nghiệm (xám). Số liệu nằm DƯỚI panel như bản gốc.
## Sinh lực theo signal player.health_changed; các số còn lại đọc mỗi frame và chỉ cập nhật khi đổi (rẻ).
## Game chưa tiêu hao thể lực/nội lực nên 2 thanh đó luôn đầy theo giá trị tối đa của chỉ số.

## Khung kim loại frame.png (491x24, các ô rỗng trong suốt): ô trái = Cấp, 4 ô dài = Thể lực/Sinh lực/Nội lực/Kinh nghiệm, ô phải = Hạng.
## Phần đầy (ảnh gốc VLTK trích bằng tools/import_vltk_topbar.py) vẽ SAU khung ở dưới nên lộ ra qua các ô; SCALE phóng/thu cho vừa màn.
const SCALE := 1.2
const PANEL_SIZE := Vector2(491, 24)
const BAR_RECTS := {
	"stamina": Rect2(79, 8, 82, 7), "life": Rect2(172, 8, 79, 7),
	"mana": Rect2(261, 8, 79, 7), "exp": Rect2(350, 8, 78, 7),
}
const LEVEL_RECT := Rect2(28, 6, 42, 11)
const RANK_RECT := Rect2(437, 6, 39, 11)
const TEXT_Y := 18.0        ## số liệu sát ngay dưới thanh (hơi chồng lên mép dưới khung)
const COLOR_TEXT_GREEN := Color(55.0 / 255.0, 231.0 / 255.0, 63.0 / 255.0)
const TEX_DIR := "res://assets/ui/topbar/"

## Phần đầy của thanh: ảnh gốc (106x11) cắt theo tỉ lệ từ trái sang.
class BarCell extends Control:
	var texture: Texture2D
	var ratio := 1.0

	func _draw() -> void:
		if texture == null:
			return
		var full := texture.get_size()
		var w := full.x * clampf(ratio, 0.0, 1.0)
		if w >= 1.0:
			draw_texture_rect_region(texture, Rect2(Vector2.ZERO, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), Rect2(Vector2.ZERO, Vector2(w, full.y)))

var _player: Node
var _level_label: Label
var _rank_label: Label
var _bars: Dictionary = {}     ## tên -> {bar: BarCell, text: Label}
var _last_text: Dictionary = {}
var _disguise_tag: PanelContainer
var _disguise_tag_label: Label

func setup(player: Node) -> void:
	_player = player
	player.health_changed.connect(func(_h: float, _m: float) -> void: _refresh())
	_refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	var size_px := PANEL_SIZE * SCALE
	offset_left = -size_px.x * 0.5
	offset_right = size_px.x * 0.5
	offset_top = 2.0
	offset_bottom = 2.0 + size_px.y + 14.0

	## Lớp dưới: nền tối từng ô + phần đầy; lớp trên: khung (lỗ trong suốt).
	for key in ["stamina", "life", "mana", "exp"]:
		_bars[key] = _make_bar(key)
	var frame := TextureRect.new()
	frame.texture = load(TEX_DIR + "frame.png")
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = size_px
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_level_label = _make_label(LEVEL_RECT, COLOR_TEXT_GREEN)
	_rank_label = _make_label(RANK_RECT, COLOR_TEXT_GREEN)
	_rank_label.text = "?"
	for key in _bars:
		var rect: Rect2 = BAR_RECTS[key]
		_bars[key]["text"] = _make_label(Rect2(rect.position.x, TEXT_Y, rect.size.x, 12), Color.WHITE)

	_disguise_tag = PanelContainer.new()
	_disguise_tag.name = "DisguiseTag"
	_disguise_tag.mouse_filter = Control.MOUSE_FILTER_PASS
	_disguise_tag.position = Vector2(size_px.x + 4.0, 2.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.85, 0.72, 0.25, 0.9)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	_disguise_tag.add_theme_stylebox_override("panel", sb)

	_disguise_tag_label = Label.new()
	_disguise_tag_label.add_theme_font_override("font", _bold_font())
	_disguise_tag_label.add_theme_font_size_override("font_size", 12)
	_disguise_tag_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	_disguise_tag_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_disguise_tag_label.add_theme_constant_override("outline_size", 3)
	_disguise_tag_label.text = "🎭"
	_disguise_tag.add_child(_disguise_tag_label)
	_disguise_tag.visible = false
	add_child(_disguise_tag)

	HudLayout.add_listener(apply_hud_layout)
	apply_hud_layout()

func _exit_tree() -> void:
	HudLayout.remove_listener(apply_hud_layout)

func apply_hud_layout() -> void:
	var elem: Dictionary = HudLayout.get_element("top_bar")
	var sc: float = float(elem.get("scale", 1.0))
	var ox: float = float(elem.get("offset_x", 0.0))
	var oy: float = float(elem.get("offset_y", 0.0))
	var base_w := PANEL_SIZE.x * SCALE
	var base_h := PANEL_SIZE.y * SCALE + 14.0
	pivot_offset = Vector2(base_w * 0.5, 0.0)
	scale = Vector2.ONE * sc
	offset_left = -base_w * 0.5 + ox
	offset_right = base_w * 0.5 + ox
	offset_top = 2.0 + oy
	offset_bottom = 2.0 + base_h + oy

func _make_label(rect: Rect2, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_text(label, color)
	add_child(label)
	## Chữ cao hơn ô (dòng chữ tối thiểu ~23px) -> đặt ô chữ đúng chiều cao chữ và căn TÂM trùng tâm ô, tránh bị lệch xuống.
	var line := label.get_minimum_size().y
	label.size = Vector2(rect.size.x * SCALE, line)
	label.position = Vector2(rect.position.x * SCALE, (rect.position.y + rect.size.y * 0.5) * SCALE - line * 0.5)
	return label

## Nền tối + ảnh phần đầy đặt đúng vào ô của khung (chưa có chữ — chữ thêm sau khung).
func _make_bar(key: String) -> Dictionary:
	var rect: Rect2 = BAR_RECTS[key]
	var back := ColorRect.new()
	back.color = Color(0.03, 0.03, 0.04, 0.95)
	back.position = rect.position * SCALE
	back.size = rect.size * SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var bar := BarCell.new()
	bar.texture = load(TEX_DIR + key + ".png")
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bar.position = back.position
	bar.size = back.size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return {"bar": bar}

static func _bold_font() -> Font:
	return GameUi.game_font_bold()   ## chữ đậm trong game: font chung GameUi

func _style_text(label: Label, color: Color) -> void:
	label.add_theme_font_override("font", _bold_font())
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var profile := GameManager.local_profile
	var stats: CombatantStats = _player.combat_stats
	var max_stamina: int = stats.max_stamina if stats else 0
	var max_mana: int = stats.max_mana if stats else 0
	_set_number(_level_label, str(profile.level if profile else 1))
	_set_number(_rank_label, profile.world_rank if profile and profile.world_rank != "" else "?")
	_set_bar("stamina", max_stamina, max_stamina)
	_set_bar("life", _player.health, _player.max_health)
	var cur_mana: float = _player.mana if "mana" in _player else float(max_mana)
	var effective_max_mana: float = _player.max_mana if ("max_mana" in _player and _player.max_mana > 0.0) else float(max_mana)
	_set_bar("mana", cur_mana, effective_max_mana)
	var exp_ratio := 0.0
	if profile != null and profile.get_exp_to_next_level() > 0:
		exp_ratio = clampf(float(profile.current_exp) / float(profile.get_exp_to_next_level()), 0.0, 1.0)
	_set_bar("exp", exp_ratio * 100.0, 100.0, "%s%%" % ("%.2f" % (exp_ratio * 100.0)).replace(".", ","))

	if _disguise_tag and profile:
		var mask_item: ItemInstance = profile.equipment.get(Equipment.Part.MASK)
		if mask_item and profile.show_mask:
			_disguise_tag.visible = true
			var d_title: String = mask_item.get_display_name()
			_disguise_tag_label.text = "🎭"
			_disguise_tag.tooltip_text = "Mặt Nạ: %s\n(Đang dịch dung ngoại hình)" % d_title
		else:
			_disguise_tag.visible = false

func _set_number(label: Label, value: String) -> void:
	if label.text != value:
		label.text = value

## `text_override` "" = hiện "giá trị/tối đa" kiểu 2674/2674.
func _set_bar(key: String, value: float, max_value: float, text_override: String = "") -> void:
	var entry: Dictionary = _bars[key]
	var bar: BarCell = entry["bar"]
	var text := text_override if text_override != "" else "%d/%d" % [ceili(maxf(value, 0.0)), int(max_value)]
	if _last_text.get(key, "") != text:
		_last_text[key] = text
		(entry["text"] as Label).text = text
		bar.ratio = clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
		bar.queue_redraw()
