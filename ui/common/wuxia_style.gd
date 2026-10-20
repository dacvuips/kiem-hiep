extends RefCounted
class_name WuxiaStyle
## Hệ thống Style CSS (StyleBoxFlat) phong cách Kiếm Hiệp cổ phong.
## Dùng chung cho toàn bộ các khung hộp thoại, bảng thuộc tính, ô trang bị, nút bấm, menu...

const COLOR_BG_PANEL := Color(0.015, 0.08, 0.09, 0.94)
const COLOR_BG_HEADER := Color(0.04, 0.15, 0.16, 0.95)
const COLOR_BG_INNER := Color(0.01, 0.05, 0.06, 0.9)
const COLOR_BG_SLOT := Color(0.02, 0.07, 0.08, 0.85)

const COLOR_BORDER_GOLD := Color(0.76, 0.63, 0.32, 0.9)
const COLOR_BORDER_GOLD_BRIGHT := Color(0.98, 0.86, 0.52, 1.0)
const COLOR_BORDER_SLOT := Color(0.68, 0.55, 0.30, 0.8)
const COLOR_BORDER_SUBTLE := Color(0.24, 0.44, 0.45, 0.7)

const COLOR_TEXT_GOLD := Color(0.92, 0.86, 0.62)
const COLOR_TEXT_LABEL := Color(0.87, 0.85, 0.82)
const COLOR_TEXT_VALUE := Color(0.98, 0.88, 0.55)
const COLOR_TEXT_RED := Color(0.95, 0.25, 0.2)

## Tạo StyleBoxFlat khung nhóm (Group Panel Box)
static func create_panel_box(border_color := COLOR_BORDER_GOLD, border_width := 2, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG_PANEL
	s.set_border_width_all(border_width)
	s.border_color = border_color
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	return s

## Tạo StyleBoxFlat thanh tiêu đề khung nhóm (Header Bar)
static func create_header_bar(radius := 7) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG_HEADER
	s.border_width_bottom = 1
	s.border_color = Color(0.45, 0.38, 0.18, 0.6)
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	return s

## Tạo StyleBoxFlat ô trang bị / vật phẩm (Equipment Slot)
static func create_slot_box(hover := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.14, 0.16, 0.9) if hover else COLOR_BG_SLOT
	s.set_border_width_all(1)
	s.border_color = COLOR_BORDER_GOLD_BRIGHT if hover else COLOR_BORDER_SLOT
	s.set_corner_radius_all(6)
	s.content_margin_left = 4
	s.content_margin_top = 4
	s.content_margin_right = 4
	s.content_margin_bottom = 4
	if hover:
		s.shadow_color = Color(0.98, 0.86, 0.52, 0.4)
		s.shadow_size = 4
	return s

## Tạo StyleBoxFlat thẻ bên trong (Inner Card, vd ô thú cưỡi)
static func create_inner_card(radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG_INNER
	s.set_border_width_all(1)
	s.border_color = COLOR_BORDER_GOLD
	s.set_corner_radius_all(radius)
	s.content_margin_left = 4
	s.content_margin_top = 4
	s.content_margin_right = 4
	s.content_margin_bottom = 4
	return s

## Tạo StyleBoxFlat nút Nav Menu
static func create_nav_button(active := false, hover := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = Color(0.85, 0.52, 0.08, 0.96)
		s.set_border_width_all(2)
		s.border_color = Color(1.0, 0.90, 0.60, 1.0)
		s.set_corner_radius_all(12)
		s.shadow_color = Color(0.85, 0.50, 0.05, 0.6)
		s.shadow_size = 10
	elif hover:
		s.bg_color = Color(0.07, 0.22, 0.24, 0.95)
		s.set_border_width_all(1)
		s.border_color = Color(0.90, 0.78, 0.45, 0.95)
		s.set_corner_radius_all(12)
	else:
		s.bg_color = Color(0.04, 0.15, 0.16, 0.92)
		s.set_border_width_all(1)
		s.border_color = COLOR_BORDER_SUBTLE
		s.set_corner_radius_all(12)
	return s
