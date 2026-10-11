extends RefCounted
class_name SocialUi
## Bộ dựng giao diện CHUNG cho các chức năng xã hội (tổ đội, bang hội, rương, giao dịch, bày bán, khoá bảo vệ) — làm theo ảnh mẫu
## bảng chi tiết kỹ năng: nền gần đen bo góc + viền mảnh, tiêu đề vàng ở giữa, nhãn đỏ/xanh dương/xanh lá, hộp mục có viền trái màu,
## hộp xanh dương đậm, thanh xanh lá, nút "đá" màu be (nút tắt mờ xám). Mọi khung xã hội dùng hàm ở đây, đừng tự chọn màu riêng.

# ---- Bảng màu ----
const BG := Color(0.055, 0.060, 0.058, 0.97)
const BORDER := Color(0.24, 0.24, 0.21)
const TITLE := Color(0.96, 0.78, 0.25)          ## vàng tiêu đề
const SUBTITLE := Color(0.62, 0.64, 0.62)       ## phụ đề xám
const TEXT := Color(0.86, 0.86, 0.80)
const MUTED := Color(0.52, 0.54, 0.52)
const LABEL_RED := Color(0.93, 0.40, 0.36)
const LABEL_BLUE := Color(0.56, 0.78, 0.95)
const LABEL_GREEN := Color(0.36, 0.85, 0.55)
const GOLD := Color(0.96, 0.82, 0.38)
const WARN := Color(0.98, 0.62, 0.30)
const SECTION_BG := Color(0.045, 0.100, 0.085)  ## hộp mục xanh lục đậm
const SECTION_ACCENT := Color(0.22, 0.65, 0.45)
const INFO_BG := Color(0.050, 0.075, 0.130)     ## hộp xanh dương đậm
const INFO_BORDER := Color(0.17, 0.25, 0.38)
const OK_BG := Color(0.07, 0.19, 0.12)
const OK_BORDER := Color(0.18, 0.48, 0.30)
const BAD_BG := Color(0.20, 0.07, 0.07)
const BAD_BORDER := Color(0.55, 0.20, 0.20)
const STONE := Color(0.76, 0.71, 0.62)          ## nút đá màu be
const STONE_DARK := Color(0.36, 0.31, 0.24)
const STONE_TEXT := Color(0.22, 0.17, 0.10)
const DISABLED_BG := Color(0.12, 0.14, 0.17)
const DISABLED_TEXT := Color(0.38, 0.40, 0.42)

static func box(bg: Color, border: Color, radius := 6, border_w := 1, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

static func window_style() -> StyleBoxFlat:
	return box(BG, BORDER, 12, 1, 16)

static func label(text: String, color: Color = TEXT, size := 14, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

static func title(text: String) -> Label:
	return label(text, TITLE, 20, HORIZONTAL_ALIGNMENT_CENTER)

static func subtitle(text: String) -> Label:
	var l := label(text, SUBTITLE, 13, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

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
	var d := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(0.30, 0.30, 0.26)
	line.thickness = 1
	d.add_theme_stylebox_override("separator", line)
	return d

## Hộp mục (nền xanh lục đậm + viền TRÁI màu). Trả về [PanelContainer, VBoxContainer nội dung].
static func section(header: String = "", accent: Color = SECTION_ACCENT, bg: Color = SECTION_BG) -> Array:
	var panel := PanelContainer.new()
	## Không viền: bỏ đường viền màu bên trái khung (theo yêu cầu) — `accent` giữ lại chỉ để tương thích chỗ gọi.
	panel.add_theme_stylebox_override("panel", box(bg, bg, 4, 0, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	if header != "":
		v.add_child(label(header, LABEL_GREEN, 14))
	return [panel, v]

## Hộp xanh dương đậm ("Được hỗ trợ từ…"). Trả về [PanelContainer, VBoxContainer].
static func info_box(header: String = "") -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(INFO_BG, INFO_BORDER, 8, 1, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	if header != "":
		v.add_child(label(header, LABEL_BLUE, 14))
	return [panel, v]

## Thanh thông báo (xanh lá = tốt, đỏ = lỗi) kiểu "Đã đạt cảnh giới tối cao".
static func banner(text: String, good := true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(OK_BG if good else BAD_BG, OK_BORDER if good else BAD_BORDER, 8, 1, 10))
	panel.add_child(label(text, LABEL_GREEN if good else LABEL_RED, 14, HORIZONTAL_ALIGNMENT_CENTER))
	return panel

static func set_banner(panel: PanelContainer, text: String, good: bool) -> void:
	panel.add_theme_stylebox_override("panel", box(OK_BG if good else BAD_BG, OK_BORDER if good else BAD_BORDER, 8, 1, 10))
	var l := panel.get_child(0) as Label
	l.text = text
	l.add_theme_color_override("font_color", LABEL_GREEN if good else LABEL_RED)

## Nút "đá" màu be (chính) — nút tắt mờ xám, giống hàng nút dưới đáy ảnh mẫu.
static func stone_button(text: String, min_size := Vector2(0, 40)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_color_override("font_color", STONE_TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.12, 0.09, 0.04))
	b.add_theme_color_override("font_pressed_color", Color(0.12, 0.09, 0.04))
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", box(STONE, STONE_DARK, 8, 2, 8))
	b.add_theme_stylebox_override("hover", box(STONE.lightened(0.12), STONE_DARK, 8, 2, 8))
	b.add_theme_stylebox_override("pressed", box(STONE.darkened(0.12), STONE_DARK, 8, 2, 8))
	b.add_theme_stylebox_override("disabled", box(DISABLED_BG, Color(0.18, 0.20, 0.23), 8, 1, 8))
	return b

## Nút phụ gọn (nền tối, chữ vàng) cho thao tác nhỏ trong danh sách.
static func small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", TITLE)
	b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.55))
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_stylebox_override("normal", box(Color(0.10, 0.11, 0.10), BORDER, 5, 1, 6))
	b.add_theme_stylebox_override("hover", box(Color(0.15, 0.16, 0.14), TITLE, 5, 1, 6))
	b.add_theme_stylebox_override("pressed", box(Color(0.07, 0.08, 0.07), TITLE, 5, 1, 6))
	b.add_theme_stylebox_override("disabled", box(DISABLED_BG, Color(0.16, 0.18, 0.20), 5, 1, 6))
	return b

## Ô nhập chữ nền tối viền mảnh.
static func line_edit(placeholder := "", secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", MUTED)
	e.add_theme_stylebox_override("normal", box(Color(0.03, 0.035, 0.035), BORDER, 5, 1, 7))
	e.add_theme_stylebox_override("focus", box(Color(0.03, 0.035, 0.035), TITLE, 5, 1, 7))
	return e

## Hàng thanh dưới đáy kiểu "Sát thương: 8424 …… DPS: 15.0k". Trả về [PanelContainer, HBoxContainer].
static func footer_bar() -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(Color(0.04, 0.045, 0.045), Color(0.14, 0.15, 0.14), 6, 1, 8))
	var h := HBoxContainer.new()
	panel.add_child(h)
	return [panel, h]

## Danh sách chọn 1 dòng (nhóm của mình / người chơi...) nền tối, dòng chọn viền vàng — kiểu hai khung danh sách của màn "Lập nhóm" gốc.
static func item_list(min_size := Vector2(200, 220)) -> ItemList:
	var l := ItemList.new()
	l.custom_minimum_size = min_size
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.add_theme_stylebox_override("panel", box(Color(0.025, 0.03, 0.03), BORDER, 4, 1, 4))
	l.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	l.add_theme_stylebox_override("selected", box(Color(0.16, 0.14, 0.05), TITLE, 3, 1, 2))
	l.add_theme_stylebox_override("selected_focus", box(Color(0.16, 0.14, 0.05), TITLE, 3, 1, 2))
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_selected_color", GOLD)
	l.add_theme_font_size_override("font_size", 13)
	return l

## Ô vuông báo trạng thái (xanh = đang bật, đỏ = tắt) như ô vuông nhỏ cạnh nút "Lập nhóm"/"Đồng ý"/"Xác nhận" ở màn gốc.
static func indicator(on := false, size := 14.0) -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(size, size)
	r.color = Color(0.25, 0.85, 0.35) if on else Color(0.75, 0.15, 0.12)
	return r

static func set_indicator(r: ColorRect, on: bool) -> void:
	r.color = Color(0.25, 0.85, 0.35) if on else Color(0.75, 0.15, 0.12)
