extends RefCounted
class_name SocialUi
## Bộ dựng giao diện cho các khung xã hội (tổ đội, bang hội, rương, giao dịch, bày bán, khoá bảo vệ). Mọi màu / khung / nút lấy từ
## GameUi (nguồn giao diện chung của cả game) — file này chỉ giữ tên hàm cũ + vài khối ghép riêng của khung xã hội.
## Muốn đổi giao diện: sửa GameUi, đừng thêm màu riêng ở đây.

# ---- Bảng màu (bí danh của GameUi để code cũ chạy nguyên) ----
const BG := GameUi.BG
const BORDER := GameUi.BORDER
const TITLE := GameUi.TITLE
const SUBTITLE := GameUi.SUBTITLE
const TEXT := GameUi.TEXT
const MUTED := GameUi.MUTED
const LABEL_RED := GameUi.LABEL_RED
const LABEL_BLUE := GameUi.LABEL_BLUE
const LABEL_GREEN := GameUi.LABEL_GREEN
const GOLD := GameUi.GOLD
const WARN := GameUi.WARN
const SECTION_BG := GameUi.SECTION_BG
const SECTION_ACCENT := GameUi.SECTION_ACCENT
const INFO_BG := GameUi.INFO_BG
const INFO_BORDER := GameUi.INFO_BORDER
const OK_BG := GameUi.OK_BG
const OK_BORDER := GameUi.OK_BORDER
const BAD_BG := GameUi.BAD_BG
const BAD_BORDER := GameUi.BAD_BORDER
const STONE := GameUi.STONE
const STONE_DARK := GameUi.STONE_DARK
const STONE_TEXT := GameUi.STONE_TEXT
const DISABLED_BG := GameUi.DISABLED_BG
const DISABLED_TEXT := GameUi.DISABLED_TEXT

static func box(bg: Color, border: Color, radius := 6, border_w := 1, margin := 10) -> StyleBoxFlat:
	return GameUi.box(bg, border, radius, border_w, margin)

static func window_style() -> StyleBoxFlat:
	return GameUi.window_style()

static func label(text: String, color: Color = TEXT, size := 14, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return GameUi.label(text, color, size, align)

static func title(text: String) -> Label:
	return GameUi.title(text)

static func subtitle(text: String) -> Label:
	return GameUi.subtitle(text)

## Dòng "Nhãn: giá trị" — nhãn tô màu (đỏ/xanh dương/xanh lá), giá trị màu chữ thường. Nhãn giá trị là con thứ 2 của HBox.
static func kv(key: String, value: String, key_color: Color = LABEL_BLUE, value_color: Color = TEXT, size := 14) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(label(key, key_color, size))
	var v := label(value, value_color, size)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	return row

static func set_kv(row: HBoxContainer, value: String, color: Color = TEXT) -> void:
	var v := row.get_child(1) as Label
	v.text = value
	v.add_theme_color_override("font_color", color)

## Đường kẻ mảnh dưới phần đầu.
static func divider() -> HSeparator:
	return GameUi.divider()

## Hộp mục (nền xanh lục đậm). Trả về [PanelContainer, VBoxContainer nội dung]. `accent`/`bg` khác mặc định = hộp màu riêng (thẻ phe...).
static func section(header: String = "", _accent: Color = SECTION_ACCENT, bg: Color = SECTION_BG) -> Array:
	var panel := GameUi.panel(GameUi.SECTION)
	if bg != SECTION_BG:
		panel.add_theme_stylebox_override("panel", box(bg, bg, 4, 0, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	if header != "":
		v.add_child(label(header, LABEL_GREEN, 14))
	return [panel, v]

## Hộp xanh dương đậm ("Được hỗ trợ từ…"). Trả về [PanelContainer, VBoxContainer].
static func info_box(header: String = "") -> Array:
	var panel := GameUi.panel(GameUi.INFO)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	if header != "":
		v.add_child(label(header, LABEL_BLUE, 14))
	return [panel, v]

## Thanh thông báo (xanh lá = tốt, đỏ = lỗi).
static func banner(text: String, good := true) -> PanelContainer:
	var panel := GameUi.panel(GameUi.BANNER_OK if good else GameUi.BANNER_BAD)
	panel.add_child(label(text, LABEL_GREEN if good else LABEL_RED, 14, HORIZONTAL_ALIGNMENT_CENTER))
	return panel

static func set_banner(panel: PanelContainer, text: String, good: bool) -> void:
	panel.theme_type_variation = GameUi.BANNER_OK if good else GameUi.BANNER_BAD
	var l := panel.get_child(0) as Label
	l.text = text
	l.add_theme_color_override("font_color", LABEL_GREEN if good else LABEL_RED)

## Nút chính "đá" màu be.
static func stone_button(text: String, min_size := Vector2(0, 40)) -> Button:
	var b := GameUi.button(text, GameUi.PRIMARY)
	b.custom_minimum_size = min_size
	return b

## Nút phụ gọn (nền tối, chữ vàng).
static func small_button(text: String) -> Button:
	return GameUi.button(text, GameUi.BUTTON)

static func line_edit(placeholder := "", secret := false) -> LineEdit:
	return GameUi.line_edit(placeholder, secret)

## Hàng thanh dưới đáy kiểu "Sát thương: 8424 …… DPS: 15.0k". Trả về [PanelContainer, HBoxContainer].
static func footer_bar() -> Array:
	var panel := GameUi.panel(GameUi.PANEL)
	var h := HBoxContainer.new()
	panel.add_child(h)
	return [panel, h]

## Danh sách chọn 1 dòng nền tối, dòng chọn viền vàng.
static func item_list(min_size := Vector2(200, 220)) -> ItemList:
	GameUi.apply()
	var l := ItemList.new()
	l.custom_minimum_size = min_size
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.theme_type_variation = GameUi.LIST
	return l

## Ô vuông báo trạng thái (xanh = đang bật, đỏ = tắt).
static func indicator(on := false, size := 14.0) -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(size, size)
	r.color = Color(0.25, 0.85, 0.35) if on else Color(0.75, 0.15, 0.12)
	return r

static func set_indicator(r: ColorRect, on: bool) -> void:
	r.color = Color(0.25, 0.85, 0.35) if on else Color(0.75, 0.15, 0.12)
