extends SocialWindow
class_name KeyGuideWindow

## Bảng Hướng Dẫn Phím Tắt VLTK 1 PC (Kiếm Hiệp Tình Duyên)
## Chuẩn thao tác bàn phím game PC kinh điển.

static func open(host: Node) -> KeyGuideWindow:
	return SocialWindow.present(host, KeyGuideWindow.new(), &"key_guide") as KeyGuideWindow

func _init() -> void:
	super._init("Hướng Dẫn Phím Tắt (Võ Lâm PC)", "Chuẩn thao tác phím PC kinh điển", 560.0)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(530, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	# Nhóm 1: Phím chức năng F1 - F12
	_build_category(content, "★ HỆ THỐNG PHÍM CHỨC NĂNG (F1 - F12)", [
		["F1", "Trợ giúp / Bảng hướng dẫn phím tắt"],
		["F2", "Cài đặt hệ thống (Âm thanh, hình ảnh, thoát)"],
		["F3 / C", "Bảng thuộc tính nhân vật & Trang bị"],
		["F4 / B / I", "Bảng hành trang / Rương đồ / Túi vật phẩm"],
		["F5 / K / G", "Bảng kỹ năng võ công (Skill Book)"],
		["F6", "Bảng Bang Hội (Guild)"],
		["F7 / T / O", "Bật / Tắt chế độ Giao dịch (Trade)"],
		["F8", "Danh sách Hảo hữu (Friends)"],
		["F9", "Chuyển chế độ PK (Luyện Công / Phe / Đồ Sát / Bang)"],
		["F11", "Kỳ Trân Các (Cửa hàng thương thành)"],
		["F12", "Cài đặt hệ thống / Bảng điều hành GM"],
	])

	# Nhóm 2: Thao tác cửa sổ & Chuột
	_build_category(content, "★ THAO TÁC CỬA SỔ & CHUỘT", [
		["Chuột phải (Vật phẩm)", "Dùng thuốc/vật phẩm ngay; Mặc trang bị ngay"],
		["Chuột phải (Khi mở Rương)", "Cất đồ vào rương ngay; Lấy đồ từ rương ra túi ngay"],
		["Chuột phải (Ô trang bị)", "Tháo trang bị trên người về túi đồ ngay"],
		["Tab", "Bật / Tắt Bản đồ toàn cảnh (MiniMap)"],
		["P", "Bật / Tắt giao diện Tổ đội (Party)"],
		["T / O", "Bật / Tắt chế độ Giao dịch nhanh"],
		["Esc", "Đóng cửa sổ đang mở / Mở Cài đặt hệ thống"],
		["Ctrl", "Bật / Tắt chế độ Tự động đánh (Auto)"],
		["Ctrl + F5 / F6", "Lưu nhanh / Tải nhanh tiến trình (Debug)"],
	])

	# Nhóm 3: Di chuyển & Chiến đấu
	_build_category(content, "★ DI CHUYỂN & CHIẾN ĐẤU", [
		["W, A, S, D", "Di chuyển nhân vật (hoặc các phím mũi tên)"],
		["M", "Lên / Xuống ngựa (Mã)"],
		["V", "Ngồi thiền / Đứng dậy (Tọa thiền hồi HP/MP)"],
		["Space", "Khinh công / Nhảy qua chướng ngại vật"],
		["Chuột trái / J / X", "Tấn công thường / Tương tác mục tiêu"],
		["Chuột phải / L", "Thi triển kỹ năng chính đã gán"],
		["1, 2, 3, 4", "Dùng thuốc ở 4 ô thuốc nhanh (không chạy khi đang gõ chat)"],
		["5, 6, 7, 8", "Thi triển 4 ô kỹ năng phụ đầu tiên của trang đang chọn"],
	])

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_close := SocialUi.stone_button("Đã hiểu (Esc / F1)", Vector2(160, 36))
	btn_close.pressed.connect(func() -> void: close_requested.emit())
	footer.add_child(btn_close)
	body.add_child(footer)

func _build_category(parent: VBoxContainer, cat_title: String, rows: Array) -> void:
	var sec_box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.11, 0.75)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.35, 0.32, 0.22, 0.8)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sec_box.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	sec_box.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = cat_title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vb.add_child(title_lbl)

	vb.add_child(SocialUi.divider())

	for item in rows:
		var row := HBoxContainer.new()
		var key_lbl := Label.new()
		key_lbl.text = item[0]
		key_lbl.custom_minimum_size.x = 130
		key_lbl.add_theme_font_size_override("font_size", 13)
		key_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		row.add_child(key_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = item[1]
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(desc_lbl)
		vb.add_child(row)

	parent.add_child(sec_box)
