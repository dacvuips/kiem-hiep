extends RefCounted
class_name GameUi
## NGUỒN DUY NHẤT cho giao diện popup / cửa sổ của game: bảng màu, khung + viền, nút (thường / hover / bấm / đang chọn / tắt),
## nút đóng ✕, ô nhập, danh sách, hộp mục, biểu tượng. Muốn đổi giao diện TOÀN GAME thì chỉ sửa ở đây.
##
## Cách dùng: mọi Control trong popup đặt `theme_type_variation` = một trong các tên biến thể bên dưới (GameUi.BUTTON, GameUi.WINDOW...)
## hoặc dựng bằng hàm tạo sẵn (GameUi.button(), GameUi.close_button()...). Theme được gộp vào theme của project lúc khởi động
## (autoload GameUiBoot → GameUi.apply()) nên áp dụng được cả cho node nằm dưới CanvasLayer và trong file .tscn
## (chọn "Theme Type Variation" trong Inspector). Đừng add_theme_*_override màu/khung riêng trong popup — sẽ lệch khi đổi giao diện.

# ================================================================ Bảng màu
const BG := Color(0.055, 0.060, 0.058, 0.97)        ## nền khung
const BG_INNER := Color(0.035, 0.040, 0.040)          ## nền ô/khung con bên trong
const BORDER := Color(0.24, 0.24, 0.21)               ## viền mảnh
const BORDER_ACTIVE := Color(0.96, 0.78, 0.25)        ## viền khi hover / đang chọn / focus
const TITLE := Color(0.96, 0.78, 0.25)                ## vàng tiêu đề
const SUBTITLE := Color(0.62, 0.64, 0.62)
const TEXT := Color(0.86, 0.86, 0.80)
const MUTED := Color(0.52, 0.54, 0.52)
const LABEL_RED := Color(0.93, 0.40, 0.36)
const LABEL_BLUE := Color(0.56, 0.78, 0.95)
const LABEL_GREEN := Color(0.36, 0.85, 0.55)
const GOLD := Color(0.96, 0.82, 0.38)
const WARN := Color(0.98, 0.62, 0.30)
const SECTION_BG := Color(0.045, 0.100, 0.085)        ## hộp mục xanh lục đậm
const SECTION_ACCENT := Color(0.22, 0.65, 0.45)
const INFO_BG := Color(0.050, 0.075, 0.130)           ## hộp xanh dương đậm
const INFO_BORDER := Color(0.17, 0.25, 0.38)
const OK_BG := Color(0.07, 0.19, 0.12)
const OK_BORDER := Color(0.18, 0.48, 0.30)
const BAD_BG := Color(0.20, 0.07, 0.07)
const BAD_BORDER := Color(0.55, 0.20, 0.20)
const STONE := Color(0.76, 0.71, 0.62)                ## nút chính "đá" màu be
const STONE_DARK := Color(0.36, 0.31, 0.24)
const STONE_TEXT := Color(0.22, 0.17, 0.10)
const STONE_TEXT_HOVER := Color(0.12, 0.09, 0.04)
const BUTTON_BG := Color(0.10, 0.11, 0.10)            ## nút phụ nền tối chữ vàng
const BUTTON_BG_HOVER := Color(0.15, 0.16, 0.14)
const BUTTON_BG_PRESSED := Color(0.07, 0.08, 0.07)
const ACTIVE_BG := Color(0.20, 0.16, 0.05)            ## nút/thẻ ĐANG CHỌN
const ACTIVE_TEXT := Color(1.0, 0.90, 0.50)
const DISABLED_BG := Color(0.12, 0.14, 0.17)
const DISABLED_BORDER := Color(0.17, 0.19, 0.22)
const DISABLED_TEXT := Color(0.38, 0.40, 0.42)
const DIM := Color(0, 0, 0, 0.55)                     ## nền tối phủ màn hình sau popup dạng modal

# ================================================================ Kích thước
const RADIUS_WINDOW := 12
const RADIUS_BUTTON := 6
const RADIUS_PANEL := 6
const PAD_WINDOW := 16
const FONT_TITLE := 20
const FONT_SUBTITLE := 13
const FONT_TEXT := 14
const FONT_BUTTON := 14
const FONT_SMALL_BUTTON := 13
const CLOSE_SIZE := Vector2(32, 30)
const PRIMARY_HEIGHT := 40.0

# ================================================================ Biểu tượng (chữ/emoji — đổi 1 chỗ là đổi cả game)
const ICON_CLOSE := "✕"
const ICON_GOLD := "🪙"
const ICON_LOCK := "🔒"
const ICON_CHEST := "🧰"
const ICON_BAG := "🎒"

# ================================================================ Tên biến thể theme (theme_type_variation)
const WINDOW := &"GameWindow"          ## PanelContainer: khung cửa sổ/popup
const TITLE_BAR := &"GameTitleBar"     ## PanelContainer: thanh tiêu đề (vùng kéo)
const PANEL := &"GameInnerPanel"       ## PanelContainer: khung con nền tối bên trong popup
const SECTION := &"GameSection"        ## PanelContainer: hộp mục xanh lục
const INFO := &"GameInfo"              ## PanelContainer: hộp xanh dương
const BANNER_OK := &"GameBannerOk"     ## PanelContainer: thanh báo tốt
const BANNER_BAD := &"GameBannerBad"   ## PanelContainer: thanh báo lỗi
const TITLE_LABEL := &"GameTitle"      ## Label: tiêu đề vàng
const SUBTITLE_LABEL := &"GameSubtitle"## Label: phụ đề xám
const BUTTON := &"GameButton"          ## Button: nút phụ (nền tối chữ vàng)
const PRIMARY := &"PrimaryButton"      ## Button: nút chính "đá" màu be
const TAB := &"TabButton"              ## Button (toggle_mode): thẻ/tab — đang chọn = pressed
const CLOSE := &"CloseButton"          ## Button: nút ✕ đóng popup
const INPUT := &"GameInput"            ## LineEdit
const LIST := &"GameList"              ## ItemList
const SEPARATOR := &"GameSeparator"    ## HSeparator

# ================================================================ Khối dựng StyleBox
static func box(bg: Color, border: Color, radius := RADIUS_PANEL, border_w := 1, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

static func window_style() -> StyleBoxFlat:
	return WuxiaStyle.create_panel_box()

# ================================================================ Theme
static var _theme: Theme

## Theme chứa toàn bộ biến thể ở trên (dựng 1 lần).
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme

## Gộp theme vào theme của project → mọi Control (kể cả dưới CanvasLayer) nhận được các biến thể. Gọi bao nhiêu lần cũng được.
static var _applied := false
static func apply() -> void:
	if _applied:
		return
	_applied = true
	var target := ThemeDB.get_project_theme()
	if target == null:
		target = ThemeDB.get_default_theme()
	target.merge_with(get_theme())

# ================================================================ Font
## Font TRONG GAME (từ màn Hub trở đi + mọi popup): IBM Plex Mono như Võ Lâm Idle — 3 file woff2 tách theo bảng chữ của bản gốc đã
## gộp thành 1 TTF (tools/merge_plex_mono_font.py) để dấu tiếng Việt không lệch; font cũ của project làm fallback cho emoji/ký hiệu.
## Màn đăng nhập / đăng ký / chọn server / chọn-tạo nhân vật (PREGAME_SCENES) giữ font cũ — GameUiBoot đổi qua lại khi chuyển màn.
const GAME_FONT_PATH := "res://assets/fonts/ibm_plex_mono/IBMPlexMono-Regular-vi.ttf"
const SYMBOL_FONT_PATH := "res://assets/fonts/symbol_fallback.ttf"
const PREGAME_SCENES := [
	"res://ui/login/Login.tscn",
	"res://ui/account/Register.tscn",
	"res://ui/account/ForgotPassword.tscn",
	"res://ui/server_select/ServerSelect.tscn",
	"res://ui/character_roster/CharacterRoster.tscn",
	"res://ui/character_create/CharacterCreate.tscn",
	"res://ui/character_select/CharacterSelect.tscn",
]
## Độ đậm giả cho chữ "bold" (Plex Mono chỉ có bản 400).
const BOLD_EMBOLDEN := 0.7

static var _game_font: FontVariation
static var _game_font_bold: FontVariation
static var _pregame_fonts := {}   ## font gốc của theme project, khôi phục khi quay lại màn đăng nhập

static func game_font() -> Font:
	if _game_font == null:
		_game_font = FontVariation.new()
		_game_font.base_font = load(GAME_FONT_PATH)
		var chain: Array[Font] = []
		var project := ThemeDB.get_project_theme()
		var old: Font = _pregame_fonts.get("default", project.default_font if project != null else null)
		if old != null:
			chain.append(old)
		if ResourceLoader.exists(SYMBOL_FONT_PATH):
			var sym_font: Font = load(SYMBOL_FONT_PATH)
			if sym_font != null:
				chain.append(sym_font)
				var base_f: Font = load(GAME_FONT_PATH)
				if base_f != null and not base_f.fallbacks.has(sym_font):
					base_f.fallbacks.append(sym_font)
		_game_font.fallbacks = chain
	return _game_font

static func game_font_bold() -> Font:
	if _game_font_bold == null:
		_game_font_bold = FontVariation.new()
		_game_font_bold.base_font = game_font()
		_game_font_bold.variation_embolden = BOLD_EMBOLDEN
	return _game_font_bold

## Nhãn nằm trong ô CỐ ĐỊNH (ô vẽ sẵn trên ảnh khung): tự thu cỡ chữ từ `font_size` xuống tối đa `min_size` cho vừa bề ngang ô —
## đổi font rộng hơn (vd. font trong game) không bị cắt chữ. `pad` = phần bề ngang ô bị hình vẽ đè (icon...) cần chừa ra.
## Tính lại mỗi khi nhãn vẽ lại (đổi chữ / đổi cỡ ô).
static func fit_label(label: Label, font_size: int, min_size := 9, pad := 0.0) -> void:
	label.set_meta(&"fit_size", font_size)
	label.set_meta(&"fit_pad", pad)
	label.set_meta(&"fit_min", min_size)
	label.add_theme_font_size_override("font_size", font_size)
	if not label.has_meta(&"fit_hooked"):
		label.set_meta(&"fit_hooked", true)
		label.draw.connect(func() -> void: _refit.call_deferred(label))

static func _refit(label: Label) -> void:
	if not is_instance_valid(label) or label.size.x <= 0.0:
		return
	var font := label.get_theme_font(&"font")
	var outline := label.get_theme_constant(&"outline_size")
	var fit := int(label.get_meta(&"fit_size"))
	var lo := int(label.get_meta(&"fit_min"))
	var room := label.size.x - float(label.get_meta(&"fit_pad", 0.0))
	while fit > lo and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x + outline > room:
		fit -= 1
	if label.get_theme_font_size(&"font_size") != fit:
		label.add_theme_font_size_override("font_size", fit)

static func is_pregame_scene(scene: Node) -> bool:
	return scene != null and scene.scene_file_path in PREGAME_SCENES

## Bật/tắt font trong game cho theme project (mọi Control đang hiện đổi theo ngay).
static func use_game_font(on: bool) -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	if _pregame_fonts.is_empty():
		_pregame_fonts = {
			"default": theme.default_font,
			"LineEdit": theme.get_font(&"font", &"LineEdit") if theme.get_font_list("LineEdit").has("font") else null,
			"TextEdit": theme.get_font(&"font", &"TextEdit") if theme.get_font_list("TextEdit").has("font") else null,
		}
	var font: Font = game_font() if on else _pregame_fonts["default"]
	if theme.default_font == font:
		return
	theme.default_font = font
	for type in [&"LineEdit", &"TextEdit"]:
		var f: Font = game_font() if on else _pregame_fonts[String(type)]
		if f != null:
			theme.set_font(&"font", type, f)

static func _build_theme() -> Theme:
	var t := Theme.new()
	## Khung
	_panel(t, WINDOW, window_style())
	_panel(t, TITLE_BAR, WuxiaStyle.create_header_bar())
	_panel(t, PANEL, box(BG_INNER, BORDER, RADIUS_PANEL, 1, 12))
	_panel(t, SECTION, box(SECTION_BG, SECTION_BG, 4, 0, 10))
	_panel(t, INFO, box(INFO_BG, INFO_BORDER, 8, 1, 12))
	_panel(t, BANNER_OK, box(OK_BG, OK_BORDER, 8, 1, 10))
	_panel(t, BANNER_BAD, box(BAD_BG, BAD_BORDER, 8, 1, 10))
	## Chữ
	_label(t, TITLE_LABEL, TITLE, FONT_TITLE)
	_label(t, SUBTITLE_LABEL, SUBTITLE, FONT_SUBTITLE)
	## Nút phụ
	_button(t, BUTTON, FONT_SMALL_BUTTON,
		box(BUTTON_BG, BORDER, RADIUS_BUTTON, 1, 6),
		box(BUTTON_BG_HOVER, BORDER_ACTIVE, RADIUS_BUTTON, 1, 6),
		box(ACTIVE_BG, BORDER_ACTIVE, RADIUS_BUTTON, 1, 6),
		box(DISABLED_BG, DISABLED_BORDER, RADIUS_BUTTON, 1, 6),
		TITLE, ACTIVE_TEXT, ACTIVE_TEXT)
	## Thẻ/tab: giống nút phụ, chữ thường màu xám khi chưa chọn, đang chọn = vàng sáng + nền vàng đậm
	_button(t, TAB, FONT_SMALL_BUTTON,
		box(BUTTON_BG, BORDER, RADIUS_BUTTON, 1, 8),
		box(BUTTON_BG_HOVER, BORDER_ACTIVE, RADIUS_BUTTON, 1, 8),
		box(ACTIVE_BG, BORDER_ACTIVE, RADIUS_BUTTON, 2, 8),
		box(DISABLED_BG, DISABLED_BORDER, RADIUS_BUTTON, 1, 8),
		TEXT, GOLD, ACTIVE_TEXT)
	## Nút chính "đá"
	_button(t, PRIMARY, FONT_BUTTON,
		box(STONE, STONE_DARK, 8, 2, 8),
		box(STONE.lightened(0.12), STONE_DARK, 8, 2, 8),
		box(STONE.darkened(0.12), STONE_DARK, 8, 2, 8),
		box(DISABLED_BG, DISABLED_BORDER, 8, 1, 8),
		STONE_TEXT, STONE_TEXT_HOVER, STONE_TEXT_HOVER)
	## Nút đóng ✕: trong suốt, hover đỏ
	var none := StyleBoxEmpty.new()
	_button(t, CLOSE, 18, none, box(Color(0.55, 0.20, 0.20, 0.25), Color(0, 0, 0, 0), RADIUS_BUTTON, 0, 2), box(Color(0.55, 0.20, 0.20, 0.45), Color(0, 0, 0, 0), RADIUS_BUTTON, 0, 2), none,
		SUBTITLE, LABEL_RED, LABEL_RED)
	## Ô nhập
	t.set_type_variation(INPUT, &"LineEdit")
	t.set_stylebox(&"normal", INPUT, box(Color(0.03, 0.035, 0.035), BORDER, 5, 1, 7))
	t.set_stylebox(&"focus", INPUT, box(Color(0.03, 0.035, 0.035), BORDER_ACTIVE, 5, 1, 7))
	t.set_stylebox(&"read_only", INPUT, box(DISABLED_BG, DISABLED_BORDER, 5, 1, 7))
	t.set_color(&"font_color", INPUT, TEXT)
	t.set_color(&"font_placeholder_color", INPUT, MUTED)
	t.set_color(&"caret_color", INPUT, TITLE)
	## Danh sách
	t.set_type_variation(LIST, &"ItemList")
	t.set_stylebox(&"panel", LIST, box(Color(0.025, 0.03, 0.03), BORDER, 4, 1, 4))
	t.set_stylebox(&"focus", LIST, StyleBoxEmpty.new())
	t.set_stylebox(&"hovered", LIST, box(BUTTON_BG_HOVER, Color(0, 0, 0, 0), 3, 0, 2))
	t.set_stylebox(&"selected", LIST, box(Color(0.16, 0.14, 0.05), BORDER_ACTIVE, 3, 1, 2))
	t.set_stylebox(&"selected_focus", LIST, box(Color(0.16, 0.14, 0.05), BORDER_ACTIVE, 3, 1, 2))
	t.set_color(&"font_color", LIST, TEXT)
	t.set_color(&"font_hovered_color", LIST, ACTIVE_TEXT)
	t.set_color(&"font_selected_color", LIST, GOLD)
	t.set_font_size(&"font_size", LIST, 13)
	## Đường kẻ
	t.set_type_variation(SEPARATOR, &"HSeparator")
	var line := StyleBoxLine.new()
	line.color = Color(0.30, 0.30, 0.26)
	line.thickness = 1
	t.set_stylebox(&"separator", SEPARATOR, line)
	return t

static func _panel(t: Theme, name: StringName, style: StyleBox) -> void:
	t.set_type_variation(name, &"PanelContainer")
	t.set_stylebox(&"panel", name, style)

static func _label(t: Theme, name: StringName, color: Color, size: int) -> void:
	t.set_type_variation(name, &"Label")
	t.set_color(&"font_color", name, color)
	t.set_font_size(&"font_size", name, size)

static func _button(t: Theme, name: StringName, font_size: int, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox,
		text: Color, text_hover: Color, text_pressed: Color) -> void:
	t.set_type_variation(name, &"Button")
	t.set_stylebox(&"normal", name, normal)
	t.set_stylebox(&"hover", name, hover)
	t.set_stylebox(&"pressed", name, pressed)
	t.set_stylebox(&"hover_pressed", name, pressed)
	t.set_stylebox(&"disabled", name, disabled)
	t.set_stylebox(&"focus", name, StyleBoxEmpty.new())
	t.set_color(&"font_color", name, text)
	t.set_color(&"font_hover_color", name, text_hover)
	t.set_color(&"font_pressed_color", name, text_pressed)
	t.set_color(&"font_hover_pressed_color", name, text_pressed)
	t.set_color(&"font_focus_color", name, text)
	t.set_color(&"font_disabled_color", name, DISABLED_TEXT)
	t.set_color(&"icon_normal_color", name, Color.WHITE)
	t.set_color(&"icon_disabled_color", name, Color(1, 1, 1, 0.4))
	t.set_font_size(&"font_size", name, font_size)

# ================================================================ Hàm dựng control chuẩn
## Nút theo biến thể: GameUi.BUTTON (phụ), GameUi.PRIMARY (chính), GameUi.TAB (thẻ — toggle, đang chọn = pressed).
static func button(text: String, kind: StringName = BUTTON) -> Button:
	apply()
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = kind
	if kind == PRIMARY:
		b.custom_minimum_size.y = PRIMARY_HEIGHT
	elif kind == TAB:
		b.toggle_mode = true
	return b

## Đặt trạng thái "đang chọn" cho thẻ/nút TAB (không phát tín hiệu).
static func set_active(b: Button, active: bool) -> void:
	b.toggle_mode = true
	b.set_pressed_no_signal(active)

## Nút ✕ đóng popup.
static func close_button() -> Button:
	apply()
	var b := Button.new()
	b.text = ICON_CLOSE
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = CLOSE
	b.custom_minimum_size = CLOSE_SIZE
	b.tooltip_text = "Đóng"
	return b

## Áp biến thể cho control có sẵn (vd. node trong .tscn chưa đặt Theme Type Variation).
static func style(c: Control, kind: StringName) -> Control:
	apply()
	c.theme_type_variation = kind
	return c

## Áp nút chuẩn cho mọi Button bên dưới `root` chưa có biến thể nào (dùng khi bọc popup .tscn cũ): nút có chữ ✕/X → CLOSE,
## nút toggle → TAB, còn lại → BUTTON. Bỏ qua nút flat / nút có stylebox riêng (ô vật phẩm, nút ảnh).
static func style_buttons(root: Node) -> void:
	apply()
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.theme_type_variation != &"" or b.flat or b.has_theme_stylebox_override(&"normal"):
			continue
		var txt := b.text.strip_edges()
		if txt == "X" or txt == "x" or txt == ICON_CLOSE or txt == "×":
			b.text = ICON_CLOSE
			b.theme_type_variation = CLOSE
		elif b.toggle_mode:
			b.theme_type_variation = TAB
		else:
			b.theme_type_variation = BUTTON

static func label(text: String, color: Color = TEXT, size := FONT_TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

static func title(text: String) -> Label:
	apply()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.theme_type_variation = TITLE_LABEL
	return l

static func subtitle(text: String) -> Label:
	apply()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.theme_type_variation = SUBTITLE_LABEL
	return l

static func panel(kind: StringName = PANEL) -> PanelContainer:
	apply()
	var p := PanelContainer.new()
	p.theme_type_variation = kind
	return p

static func divider() -> HSeparator:
	apply()
	var d := HSeparator.new()
	d.theme_type_variation = SEPARATOR
	return d

static func line_edit(placeholder := "", secret := false) -> LineEdit:
	apply()
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.theme_type_variation = INPUT
	return e

## Nền tối phủ toàn màn hình phía sau popup modal.
static func dim_rect() -> ColorRect:
	var r := ColorRect.new()
	r.color = DIM
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r
