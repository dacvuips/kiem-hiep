extends CanvasLayer
class_name FarmWindows
## Các cửa sổ giao diện Sơn Trang Nguyệt Ca:
## - Cửa hàng NPC (Chăn Nuôi, Trồng Trọt, Cá Nước Ngọt, Cá Biển)
## - Rương Nông Sản & Vật Tư Sơn Trang (Giao diện Grid Slot chuẩn VLTK)

const ICON_PREFIX := "res://assets/items/icons/"
const TOTAL_SLOTS := 60 # 12 cột x 5 hàng = 60 ô grid slot chuẩn rương Sơn Trang

static func open_shop(parent: Node) -> void:
	FarmNPCShop.open_shop(parent, "agriculture")

## Mở Bảng Giao Diện Lửa Trại Sơn Trang chuẩn Kiếm Hiệp VLTK
static func open_campfire(parent: Node, campfire_info: Dictionary = {}) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root: Node = parent.get_tree().root if (parent and parent.is_inside_tree()) else (tree.root if tree else null)
	
	# Đảm bảo hiển thị trên CanvasLayer độc lập (layer 120) để luôn căn giữa màn hình
	var modal_layer: CanvasLayer = null
	if root != null:
		modal_layer = root.get_node_or_null("FarmModalLayer") as CanvasLayer
		if modal_layer == null or not is_instance_valid(modal_layer):
			modal_layer = CanvasLayer.new()
			modal_layer.name = "FarmModalLayer"
			modal_layer.layer = 120
			root.add_child(modal_layer)
	
	var target_parent: Node = modal_layer if modal_layer != null else parent
	
	# Xóa cửa sổ cũ nếu đang mở
	if modal_layer != null:
		var old_modal = modal_layer.get_node_or_null("FarmCampfireWindow")
		if old_modal != null:
			old_modal.queue_free()
	if parent != null:
		var old_parent = parent.get_node_or_null("FarmCampfireWindow")
		if old_parent != null:
			old_parent.queue_free()

	var farm_mgr: FarmManager = null
	if root != null and root.has_node("FarmManager"):
		farm_mgr = root.get_node("FarmManager")
	elif parent != null:
		farm_mgr = parent.get_node_or_null("/root/FarmManager")

	var cf_name: String = str(campfire_info.get("name", "Đống Lửa Sơn Trang"))
	var cf_coord: String = str(campfire_info.get("coord_name", "192/187"))
	var cf_npc: String = str(campfire_info.get("npc_name", "Thần Nông Tiên Sinh"))
	var cf_pos: Vector2 = campfire_info.get("world_pos", Vector2(49280.0, 48000.0))

	# Khung bao bọc toàn màn hình (Modal Wrapper)
	var root_wrap := Control.new()
	root_wrap.name = "FarmCampfireWindow"
	root_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_wrap.mouse_filter = Control.MOUSE_FILTER_PASS

	# Lớp nền đen mờ bao phủ (Dark Backdrop) - Bấm ra ngoài để đóng
	var dark_overlay := ColorRect.new()
	dark_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dark_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			root_wrap.queue_free()
	)
	root_wrap.add_child(dark_overlay)

	# Khung Cửa Sổ Chính Cổ Phong Kiếm Hiệp VLTK
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(520, 560)
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -260
	win.offset_right = 260
	win.offset_top = -280
	win.offset_bottom = 280
	win.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.025, 0.075, 0.085, 0.98) # Màu nền huyền sẫm Kiếm Hiệp
	bg.border_color = Color(0.76, 0.63, 0.32, 0.95) # Viền vàng đồng hoàng gia VLTK
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.content_margin_left = 18
	bg.content_margin_top = 16
	bg.content_margin_right = 18
	bg.content_margin_bottom = 16
	bg.shadow_color = Color(0, 0, 0, 0.75)
	bg.shadow_size = 16
	win.add_theme_stylebox_override("panel", bg)
	root_wrap.add_child(win)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	win.add_child(vbox)

	# 1. Header: Tiêu đề + Vị trí Đống Lửa + Nút Đóng
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_BEGIN

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)

	var title_lbl := Label.new()
	title_lbl.text = "🔥 ĐỐNG LỬA SƠN TRANG"
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_box.add_child(title_lbl)

	var loc_lbl := Label.new()
	loc_lbl.text = "📍 %s [%s]  •  Khu vực: %s" % [cf_name, cf_coord, cf_npc]
	loc_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.88))
	loc_lbl.add_theme_font_size_override("font_size", 11)
	title_box.add_child(loc_lbl)

	header.add_child(title_box)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.35, 0.12, 0.12, 0.85)
	close_style.border_color = Color(0.85, 0.35, 0.35)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(root_wrap.queue_free)
	header.add_child(close_btn)
	vbox.add_child(header)

	# 2. Banner Trạng Thái Ngọn Lửa
	var banner := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.015, 0.045, 0.055, 0.95)
	b_style.border_color = Color(0.55, 0.45, 0.22, 0.8)
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(6)
	b_style.content_margin_left = 14
	b_style.content_margin_top = 10
	b_style.content_margin_right = 14
	b_style.content_margin_bottom = 10
	banner.add_theme_stylebox_override("panel", b_style)

	var bhbox := HBoxContainer.new()
	bhbox.add_theme_constant_override("separation", 14)
	banner.add_child(bhbox)

	var fire_ico := Label.new()
	fire_ico.text = "🔥"
	fire_ico.add_theme_font_size_override("font_size", 38)
	fire_ico.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bhbox.add_child(fire_ico)

	var bvbox := VBoxContainer.new()
	bvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bvbox.add_theme_constant_override("separation", 4)
	bhbox.add_child(bvbox)

	var flame_name_lbl := Label.new()
	flame_name_lbl.text = "Ngọn Lửa Sưởi Ấm Sơn Trang"
	flame_name_lbl.add_theme_font_size_override("font_size", 14)
	flame_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	bvbox.add_child(flame_name_lbl)

	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 12)
	bvbox.add_child(status_lbl)

	var time_lbl := Label.new()
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.82))
	bvbox.add_child(time_lbl)
	vbox.add_child(banner)

	# 3. Thanh Nhiên Liệu Lớn (Fuel Bar)
	var bar_box := VBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 4)
	vbox.add_child(bar_box)

	var bar_title_box := HBoxContainer.new()
	var bar_lbl := Label.new()
	bar_lbl.text = "Nhiên Liệu Lửa Trại (Độ Bền):"
	bar_lbl.add_theme_font_size_override("font_size", 12)
	bar_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	bar_title_box.add_child(bar_lbl)

	var bar_spacer := Control.new()
	bar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_title_box.add_child(bar_spacer)

	var fuel_pct_lbl := Label.new()
	fuel_pct_lbl.add_theme_font_size_override("font_size", 12)
	fuel_pct_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	bar_title_box.add_child(fuel_pct_lbl)
	bar_box.add_child(bar_title_box)

	var fuel_bar := ProgressBar.new()
	fuel_bar.custom_minimum_size = Vector2(0, 20)
	fuel_bar.min_value = 0.0
	fuel_bar.max_value = 100.0
	fuel_bar.show_percentage = false

	var f_bg := StyleBoxFlat.new()
	f_bg.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	f_bg.border_color = Color(0.35, 0.35, 0.35)
	f_bg.set_border_width_all(1)
	f_bg.set_corner_radius_all(4)
	fuel_bar.add_theme_stylebox_override("background", f_bg)

	var f_fill := StyleBoxFlat.new()
	f_fill.bg_color = Color(1.0, 0.62, 0.15)
	f_fill.set_corner_radius_all(4)
	fuel_bar.add_theme_stylebox_override("fill", f_fill)
	bar_box.add_child(fuel_bar)

	# 4. Bảng Phúc Lợi Khi Sưởi Ấm
	var benefit_box := PanelContainer.new()
	var ben_style := StyleBoxFlat.new()
	ben_style.bg_color = Color(0.015, 0.04, 0.05, 0.9)
	ben_style.border_color = Color(0.45, 0.42, 0.30, 0.7)
	ben_style.set_border_width_all(1)
	ben_style.set_corner_radius_all(6)
	ben_style.content_margin_left = 12
	ben_style.content_margin_top = 8
	ben_style.content_margin_right = 12
	ben_style.content_margin_bottom = 8
	benefit_box.add_theme_stylebox_override("panel", ben_style)

	var ben_vbox := VBoxContainer.new()
	ben_vbox.add_theme_constant_override("separation", 4)
	benefit_box.add_child(ben_vbox)

	var ben_title := Label.new()
	ben_title.text = "📜 PHÚC LỢI KHI SƯỞI ẤM BÊN ĐỐNG LỬA:"
	ben_title.add_theme_font_size_override("font_size", 12)
	ben_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	ben_vbox.add_child(ben_title)

	var benefits := [
		"🌟 Tu Vi Nhân Vật: +2000 EXP mỗi 1 giây (120.000 EXP/phút).",
		"🏰 Đẳng Cấp Sơn Trang: +20 EXP mỗi 1 giây.",
		"🌾 Ấm Áp Sơn Trang: Giữ ấm ruộng đồng, gia súc mau lớn, cá biển sinh sôi.",
		"📍 Phạm vi sưởi ấm: Mở rộng cực đại (750 bước quanh bất kỳ đống lửa nào)."
	]
	for b in benefits:
		var l := Label.new()
		l.text = b
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color(0.82, 0.85, 0.88))
		ben_vbox.add_child(l)
	vbox.add_child(benefit_box)

	# Hàm cập nhật số liệu nhiên liệu
	var update_fuel_display := func() -> void:
		var cur_fuel: float = farm_mgr.campfire_fuel if farm_mgr else 0.5
		var pct: int = int(round(cur_fuel * 100.0))
		var rem_sec: int = int(round(cur_fuel * 1200.0))
		var mins: int = rem_sec / 60
		var secs: int = rem_sec % 60
		
		fuel_bar.value = pct
		fuel_pct_lbl.text = "%d%%" % pct
		
		if cur_fuel > 0.5:
			status_lbl.text = "Trạng Thái: 🔥 LỬA CHÁY RỰC RỠ (CỰC MẠNH)"
			status_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
			f_fill.bg_color = Color(0.25, 0.85, 0.3)
		elif cur_fuel > 0.15:
			status_lbl.text = "Trạng Thái: ⚠️ LỬA ĐANG TÀN (CẦN THÊM CỦI)"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
			f_fill.bg_color = Color(1.0, 0.65, 0.15)
		elif cur_fuel > 0.0:
			status_lbl.text = "Trạng Thái: ⚠️ LỬA SẮP TẮT (GẦN HẾT NHIÊN LIỆU)"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
			f_fill.bg_color = Color(0.9, 0.35, 0.2)
		else:
			status_lbl.text = "Trạng Thái: ❌ LỬA ĐÃ TẮT (TRO TÀN BỐC KHÓI)"
			status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			f_fill.bg_color = Color(0.4, 0.4, 0.4)
		
		time_lbl.text = "Thời gian cháy duy trì: %d phút %02d giây (Tối đa 20 phút)" % [mins, secs]

	update_fuel_display.call()

	var show_popup_msg := func(text: String) -> void:
		var hud_node: Node = null
		if root != null:
			hud_node = root.find_child("FarmHUD", true, false)
			if hud_node == null:
				hud_node = root.find_child("FarmHud", true, false)
		if hud_node != null and hud_node.has_method("_show_popup_msg"):
			hud_node._show_popup_msg(text)

	# 5. Khu Vực Tiếp Củi / Thêm Nhiên Liệu
	var feed_section := VBoxContainer.new()
	feed_section.add_theme_constant_override("separation", 6)
	vbox.add_child(feed_section)

	var feed_lbl := Label.new()
	feed_lbl.text = "🪵 TIẾP THÊM NHIÊN LIỆU CHO ĐỐNG LỬA:"
	feed_lbl.add_theme_font_size_override("font_size", 12)
	feed_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	feed_section.add_child(feed_lbl)

	var add_fuel_row := func(btn_text: String, amount: float, desc: String) -> Button:
		var btn := Button.new()
		btn.text = btn_text
		btn.custom_minimum_size = Vector2(0, 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var b_box := StyleBoxFlat.new()
		b_box.bg_color = Color(0.08, 0.14, 0.15, 0.9)
		b_box.border_color = Color(0.68, 0.52, 0.25)
		b_box.set_border_width_all(1)
		b_box.set_corner_radius_all(6)
		b_box.content_margin_left = 12
		btn.add_theme_stylebox_override("normal", b_box)
		btn.tooltip_text = desc
		
		btn.pressed.connect(func():
			if farm_mgr != null:
				farm_mgr.feed_campfire(amount)
				update_fuel_display.call()
				show_popup_msg.call("🔥 Đã tiếp thêm nhiên liệu! Lửa cháy bập bùng.")
		)
		return btn

	feed_section.add_child(add_fuel_row.call("🪵 Thêm Củi Khô (+30% Nhiên Liệu)", 0.3, "Thêm cành củi khô, duy trì ngọn lửa thêm 6 phút"))
	feed_section.add_child(add_fuel_row.call("🌲 Bó Củi Lớn (+60% Nhiên Liệu)", 0.6, "Thêm bó củi to đượm lửa, duy trì ngọn lửa thêm 12 phút"))
	feed_section.add_child(add_fuel_row.call("🍶 Rượu Nếp Tiếp Lửa (Đầy 100% Nhiên Liệu)", 1.0, "Đổ rượu ấm nồng vào đống lửa, bùng cháy tối đa 20 phút"))

	# 6. Footer: Đi Đến Đống Lửa + Đóng
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	vbox.add_child(footer)

	var walk_btn := Button.new()
	walk_btn.text = "🏃 Đến Cạnh Đống Lửa Sưởi Ấm"
	walk_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	walk_btn.custom_minimum_size = Vector2(0, 38)
	walk_btn.focus_mode = Control.FOCUS_NONE
	walk_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var w_box := StyleBoxFlat.new()
	w_box.bg_color = Color(0.08, 0.22, 0.12, 0.95)
	w_box.border_color = Color(0.35, 0.75, 0.4)
	w_box.set_border_width_all(1)
	w_box.set_corner_radius_all(6)
	walk_btn.add_theme_stylebox_override("normal", w_box)
	walk_btn.pressed.connect(func():
		root_wrap.queue_free()
		var player = null
		if root != null:
			player = root.get_tree().get_first_node_in_group("player")
		elif parent != null and parent.is_inside_tree():
			player = parent.get_tree().get_first_node_in_group("player")
		
		if player != null and is_instance_valid(player):
			var target_pos := cf_pos
			if player.has_method("walk_to_feet"):
				player.walk_to_feet(target_pos + Vector2(0, 35))
			elif "destination" in player:
				player.destination = target_pos + Vector2(0, 35)
			show_popup_msg.call("🏃 Đang di chuyển đến %s..." % cf_name)
	)
	footer.add_child(walk_btn)

	var close_btn_bottom := Button.new()
	close_btn_bottom.text = "Đóng"
	close_btn_bottom.custom_minimum_size = Vector2(80, 38)
	close_btn_bottom.focus_mode = Control.FOCUS_NONE
	close_btn_bottom.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn_bottom.pressed.connect(root_wrap.queue_free)
	footer.add_child(close_btn_bottom)

	target_parent.add_child(root_wrap)

## Mở Rương Sơn Trang dạng Grid Slot ô vuông chuẩn VLTK (cho phép kéo thả di chuyển cửa sổ)
static func open_chest(parent: Node, default_tab: int = 0, initial_pos: Vector2 = Vector2.ZERO) -> void:
	# Đóng rương cũ nếu đang mở để tránh chồng lấn
	var old = parent.get_node_or_null("FarmChestGridWindow")
	if old:
		old.queue_free()

	# Đảm bảo ẩn QuickItemBar (4 ô thuốc nhanh) nếu có
	var hidden_bars: Array[Control] = []
	if parent and parent.get_tree():
		for bar in parent.get_tree().get_nodes_in_group("quick_item_bar"):
			if bar is Control and bar.visible:
				bar.visible = false
				hidden_bars.append(bar)

	var win := PanelContainer.new()
	win.name = "FarmChestGridWindow"
	win.custom_minimum_size = Vector2(744, 460)
	win.set_anchors_preset(Control.PRESET_TOP_LEFT)

	var vp_size = parent.get_viewport_rect().size if (parent and parent.is_inside_tree()) else Vector2(1280, 720)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1280, 720)

	if initial_pos != Vector2.ZERO:
		win.position = initial_pos
	else:
		win.position = Vector2((vp_size.x - 744.0) * 0.5, (vp_size.y - 460.0) * 0.5).round()

	if initial_pos == Vector2.ZERO:
		win.ready.connect(func():
			var vp = win.get_viewport_rect().size
			if vp.x > 0 and vp.y > 0 and win.size.x > 0:
				win.position = Vector2((vp.x - win.size.x) * 0.5, (vp.y - win.size.y) * 0.5).round()
		)

	win.tree_exited.connect(func():
		var in_farm = parent != null and (parent is FarmHud or parent.get_node_or_null("FarmHud") != null)
		if not in_farm and parent and parent.has_node("/root/GameManager"):
			var gm: Node = parent.get_node("/root/GameManager")
			if gm and gm.has_method("is_manor_mode") and gm.is_manor_mode():
				in_farm = true
		if not in_farm and parent and parent.get_tree():
			for bar in hidden_bars:
				if is_instance_valid(bar):
					bar.visible = true
	)

	# Cho phép kéo và di chuyển rương tự do trên màn hình
	var is_dragging := [false]
	var drag_start_mouse := [Vector2.ZERO]
	var drag_start_win_pos := [Vector2.ZERO]

	var handle_drag_input = func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging[0] = true
				drag_start_mouse[0] = event.global_position
				drag_start_win_pos[0] = win.position
				win.move_to_front()
			else:
				is_dragging[0] = false
		elif event is InputEventMouseMotion and is_dragging[0]:
			var delta = event.global_position - drag_start_mouse[0]
			var new_pos = drag_start_win_pos[0] + delta
			var screen = win.get_viewport_rect().size
			if screen.x > 0 and screen.y > 0:
				new_pos.x = clampf(new_pos.x, 0.0, maxf(0.0, screen.x - win.size.x))
				new_pos.y = clampf(new_pos.y, 0.0, maxf(0.0, screen.y - win.size.y))
			win.position = new_pos

	win.mouse_filter = Control.MOUSE_FILTER_STOP
	win.gui_input.connect(handle_drag_input)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.11, 0.98)
	bg.border_color = Color(0.85, 0.72, 0.28) # Viền vàng cổ điển
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.content_margin_left = 16
	bg.content_margin_top = 14
	bg.content_margin_right = 16
	bg.content_margin_bottom = 14
	bg.shadow_color = Color(0, 0, 0, 0.6)
	bg.shadow_size = 12
	win.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	win.add_child(vbox)

	# 1. Header: Tiêu đề + Vùng kéo di chuyển + Nút Đóng
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(handle_drag_input)

	var title_lbl := Label.new()
	title_lbl.text = "📦 RƯƠNG CHỨA ĐỒ SƠN TRANG"
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.35, 0.12, 0.12, 0.8)
	close_style.border_color = Color(0.8, 0.3, 0.3)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(win.queue_free)
	header.add_child(close_btn)
	vbox.add_child(header)

	# 2. Thanh Tabs phân loại (Tất Cả, Nông Sản, Hạt Giống, Vật Tư)
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	vbox.add_child(tab_bar)

	var current_tab := default_tab
	var tabs = [
		{"id": 0, "name": "📦 Tất Cả"},
		{"id": 1, "name": "🌾 Nông Sản & Thu Hoạch"},
		{"id": 2, "name": "🌱 Hạt Giống & Con Giống"},
		{"id": 3, "name": "🛠️ Vật Tư & Công Cụ"}
	]

	# 3. Khung Lưới Ô Grid Slot (12 Cột x 5 Hàng = 60 Ô Kín Toàn Bộ Khung)
	var grid_panel := PanelContainer.new()
	var grid_bg := StyleBoxFlat.new()
	grid_bg.bg_color = Color(0.05, 0.06, 0.07, 0.95)
	grid_bg.border_color = Color(0.25, 0.28, 0.32)
	grid_bg.set_border_width_all(1)
	grid_bg.set_corner_radius_all(6)
	grid_bg.content_margin_left = 10
	grid_bg.content_margin_top = 10
	grid_bg.content_margin_right = 10
	grid_bg.content_margin_bottom = 10
	grid_panel.add_theme_stylebox_override("panel", grid_bg)
	vbox.add_child(grid_panel)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	grid_scroll.custom_minimum_size = Vector2(0, 290)
	grid_panel.add_child(grid_scroll)

	var grid := GridContainer.new()
	grid.columns = 12
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid_scroll.add_child(grid)

	# 4. Footer: Sức chứa, Số dư tiền tệ & Nút Bán Nhanh
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	vbox.add_child(footer)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)

	var capacity_lbl := Label.new()
	capacity_lbl.add_theme_font_size_override("font_size", 12)
	capacity_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	info_vbox.add_child(capacity_lbl)

	var money_lbl := Label.new()
	money_lbl.add_theme_font_size_override("font_size", 12)
	money_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	info_vbox.add_child(money_lbl)
	footer.add_child(info_vbox)

	var quick_sell_btn := Button.new()
	quick_sell_btn.text = "⚡ Bán Hết Nông Sản"
	quick_sell_btn.custom_minimum_size = Vector2(160, 34)
	quick_sell_btn.focus_mode = Control.FOCUS_NONE
	var qs_style := StyleBoxFlat.new()
	qs_style.bg_color = Color(0.25, 0.35, 0.18, 0.9)
	qs_style.border_color = Color(0.5, 0.8, 0.4)
	qs_style.set_border_width_all(1)
	qs_style.set_corner_radius_all(4)
	quick_sell_btn.add_theme_stylebox_override("normal", qs_style)
	footer.add_child(quick_sell_btn)

	var farm_mgr: FarmManager = parent.get_node_or_null("/root/FarmManager")

	# Hàm cập nhật lại toàn bộ lưới Grid
	var refresh_grid = func():
		# Dọn sạch các ô cũ
		for c in grid.get_children():
			c.queue_free()

		# Thu thập danh sách vật phẩm từ 2 kho của farm_mgr
		var items_to_display: Array[Dictionary] = []
		if farm_mgr:
			# 1. Thành phẩm nông sản / chăn nuôi / cá
			if current_tab == 0 or current_tab == 1:
				for k in farm_mgr.farm_chest_produce.keys():
					var cnt: int = int(farm_mgr.farm_chest_produce[k])
					if cnt > 0:
						var meta = get_item_meta(k, false)
						meta["count"] = cnt
						meta["is_produce"] = true
						meta["item_id"] = k
						items_to_display.append(meta)

			# 2. Vật tư, hạt giống, con giống
			if current_tab == 0 or current_tab == 2 or current_tab == 3:
				for k in farm_mgr.farm_chest_supplies.keys():
					var cnt: int = int(farm_mgr.farm_chest_supplies[k])
					if cnt > 0:
						var meta = get_item_meta(k, true)
						var is_seed_or_animal = meta.get("is_seed", false) or meta.get("is_animal", false)
						if current_tab == 2 and not is_seed_or_animal:
							continue
						if current_tab == 3 and is_seed_or_animal:
							continue
						meta["count"] = cnt
						meta["is_produce"] = false
						meta["item_id"] = k
						items_to_display.append(meta)

		# Cập nhật số lượng sức chứa
		var total_occupied := items_to_display.size()
		capacity_lbl.text = "📦 Sức chứa: %d / %d ô rương" % [total_occupied, TOTAL_SLOTS]

		var st := Engine.get_main_loop() as SceneTree
		var gm = st.root.get_node_or_null("GameManager") if (st and st.root) else null
		var profile: PlayerProfile = gm.local_profile if (gm and "local_profile" in gm) else null
		var gold_val: int = profile.gold if profile else 0
		var xu_val: int = profile.xu if profile else 0
		money_lbl.text = "💰 Ngân lượng: %d Lượng  |  🪙 Xu: %d" % [gold_val, xu_val]

		# Tính tổng tiền nông sản có thể bán nhanh
		var total_sell_val := 0
		if farm_mgr:
			for k in farm_mgr.farm_chest_produce.keys():
				var c = int(farm_mgr.farm_chest_produce[k])
				var m = get_item_meta(k, false)
				total_sell_val += int(m.get("sell_price", 50)) * c
		quick_sell_btn.visible = (total_sell_val > 0)
		quick_sell_btn.text = "⚡ Bán Hết Nông Sản (+%d Lượng)" % total_sell_val

		# Sinh các ô Grid Slot (12 cột x 5 hàng = 60 ô)
		var num_slots = maxi(TOTAL_SLOTS, int(ceil(float(items_to_display.size()) / 12.0)) * 12)
		for slot_idx in range(num_slots):
			var slot_btn := Button.new()
			slot_btn.custom_minimum_size = Vector2(52, 52)
			slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_btn.focus_mode = Control.FOCUS_NONE

			var slot_box := StyleBoxFlat.new()
			slot_box.bg_color = Color(0.08, 0.09, 0.11, 0.95)
			slot_box.border_color = Color(0.24, 0.26, 0.30)
			slot_box.set_border_width_all(1)
			slot_box.set_corner_radius_all(4)
			slot_btn.add_theme_stylebox_override("normal", slot_box)

			var hover_box := StyleBoxFlat.new()
			hover_box.bg_color = Color(0.14, 0.16, 0.20, 0.95)
			hover_box.border_color = Color(1.0, 0.85, 0.3)
			hover_box.set_border_width_all(2)
			hover_box.set_corner_radius_all(4)
			slot_btn.add_theme_stylebox_override("hover", hover_box)

			# Nếu ô này có vật phẩm
			if slot_idx < items_to_display.size():
				var item = items_to_display[slot_idx]

				var icon_rect := TextureRect.new()
				icon_rect.custom_minimum_size = Vector2(40, 40)
				icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				icon_rect.offset_left = 6
				icon_rect.offset_top = 6
				icon_rect.offset_right = -6
				icon_rect.offset_bottom = -6
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_rect.texture = _load_texture_for_item(item)
				slot_btn.add_child(icon_rect)

				# Nhãn số lượng ở góc dưới bên phải ô
				var cnt_lbl := Label.new()
				cnt_lbl.text = str(item["count"])
				cnt_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				cnt_lbl.offset_left = -30
				cnt_lbl.offset_top = -18
				cnt_lbl.offset_right = -3
				cnt_lbl.offset_bottom = -2
				cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				cnt_lbl.add_theme_font_size_override("font_size", 11)
				cnt_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
				cnt_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
				cnt_lbl.add_theme_constant_override("outline_size", 3)
				cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_btn.add_child(cnt_lbl)

				slot_btn.tooltip_text = "%s (x%d)\n%s" % [item["name"], item["count"], item["desc"]]

				# Khi nhấp vào ô -> Mở popup hành động (bán, dùng, thả chuồng)
				slot_btn.pressed.connect(func():
					_show_item_action_popup(win, item, farm_mgr, parent, current_tab)
				)

			grid.add_child(slot_btn)

	# Khởi tạo các nút chuyển Tab (dàn đều full chiều ngang)
	for t in tabs:
		var tb := Button.new()
		tb.text = t["name"]
		tb.custom_minimum_size = Vector2(100, 32)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.focus_mode = Control.FOCUS_NONE
		var is_active: bool = (t["id"] == current_tab)
		var t_style := StyleBoxFlat.new()
		t_style.bg_color = Color(0.24, 0.22, 0.12, 0.95) if is_active else Color(0.12, 0.13, 0.15, 0.8)
		t_style.border_color = Color(0.9, 0.78, 0.3) if is_active else Color(0.3, 0.32, 0.35)
		t_style.set_border_width_all(1)
		t_style.set_corner_radius_all(4)
		tb.add_theme_stylebox_override("normal", t_style)

		tb.pressed.connect(func():
			var cur_pos = win.position
			win.queue_free()
			open_chest(parent, t["id"], cur_pos)
		)
		tab_bar.add_child(tb)

	# Nút Bán Nhanh Tất Cả Nông Sản
	quick_sell_btn.pressed.connect(func():
		if farm_mgr:
			var total_gain := 0
			for k in farm_mgr.farm_chest_produce.keys():
				var c = int(farm_mgr.farm_chest_produce[k])
				var m = get_item_meta(k, false)
				var unit_pr = int(m.get("sell_price", 50))
				total_gain += unit_pr * c
			farm_mgr.farm_chest_produce.clear()
			farm_mgr.earn_gold(total_gain)
			farm_mgr.save_farm_data()
			var cur_pos = win.position
			win.queue_free()
			open_chest(parent, current_tab, cur_pos)
	)

	# Vẽ lưới lần đầu
	refresh_grid.call()
	parent.add_child(win)

## Hiển thị popup modal thao tác vật phẩm khi người chơi nhấp vào ô grid slot
static func _show_item_action_popup(chest_win: Node, item: Dictionary, farm_mgr: FarmManager, parent: Node, cur_tab: int) -> void:
	# Đóng popup cũ nếu đang mở
	var old_popup = chest_win.get_node_or_null("ItemActionPopup")
	if old_popup:
		old_popup.queue_free()

	var popup := PanelContainer.new()
	popup.name = "ItemActionPopup"
	popup.custom_minimum_size = Vector2(360, 200)
	popup.anchor_left = 0.5
	popup.anchor_right = 0.5
	popup.anchor_top = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -180
	popup.offset_right = 180
	popup.offset_top = -100
	popup.offset_bottom = 100

	var p_box := StyleBoxFlat.new()
	p_box.bg_color = Color(0.10, 0.11, 0.14, 0.98)
	p_box.border_color = Color(0.9, 0.78, 0.3)
	p_box.set_border_width_all(2)
	p_box.set_corner_radius_all(8)
	p_box.content_margin_left = 14
	p_box.content_margin_top = 10
	p_box.content_margin_right = 14
	p_box.content_margin_bottom = 12
	p_box.shadow_color = Color(0, 0, 0, 0.8)
	p_box.shadow_size = 20
	popup.add_theme_stylebox_override("panel", p_box)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 8)
	popup.add_child(pvbox)

	# 1. Header: Tên + Nút đóng
	var phead := HBoxContainer.new()
	var pname := Label.new()
	pname.text = str(item.get("name", "Vật Phẩm"))
	pname.add_theme_font_size_override("font_size", 14)
	pname.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	phead.add_child(pname)

	var pcat := Label.new()
	pcat.text = " [%s]" % str(item.get("category", "Vật phẩm"))
	pcat.add_theme_font_size_override("font_size", 11)
	pcat.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	phead.add_child(pcat)

	var pspace := Control.new()
	pspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phead.add_child(pspace)

	var pclose := Button.new()
	pclose.text = "✕"
	pclose.custom_minimum_size = Vector2(26, 26)
	pclose.focus_mode = Control.FOCUS_NONE
	var pc_style := StyleBoxFlat.new()
	pc_style.bg_color = Color(0.35, 0.12, 0.12, 0.8)
	pc_style.border_color = Color(0.8, 0.3, 0.3)
	pc_style.set_border_width_all(1)
	pc_style.set_corner_radius_all(4)
	pclose.add_theme_stylebox_override("normal", pc_style)
	pclose.pressed.connect(popup.queue_free)
	phead.add_child(pclose)
	pvbox.add_child(phead)

	# 2. Body: Icon + Mô tả + Số lượng
	var pbody := HBoxContainer.new()
	pbody.add_theme_constant_override("separation", 10)
	pvbox.add_child(pbody)

	var icon_panel := PanelContainer.new()
	var ibox := StyleBoxFlat.new()
	ibox.bg_color = Color(0.06, 0.07, 0.08)
	ibox.border_color = Color(0.85, 0.72, 0.28)
	ibox.set_border_width_all(1)
	ibox.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", ibox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _load_texture_for_item(item)
	icon_panel.add_child(icon_rect)
	pbody.add_child(icon_panel)

	var pinfo := VBoxContainer.new()
	pinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinfo.add_theme_constant_override("separation", 2)
	pbody.add_child(pinfo)

	var pdesc := Label.new()
	pdesc.text = str(item.get("desc", ""))
	pdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pdesc.add_theme_font_size_override("font_size", 11)
	pdesc.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	pinfo.add_child(pdesc)

	var pqty := Label.new()
	pqty.text = "Số lượng trong rương: %d cái" % int(item.get("count", 1))
	pqty.add_theme_font_size_override("font_size", 11)
	pqty.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	pinfo.add_child(pqty)

	# 3. Row nút hành động
	var pact := HBoxContainer.new()
	pact.add_theme_constant_override("separation", 8)
	pact.alignment = BoxContainer.ALIGNMENT_END
	pvbox.add_child(pact)

	var item_id: String = str(item["item_id"])
	var is_produce: bool = bool(item.get("is_produce", false))
	var unit_price: int = int(item.get("sell_price", 50))
	var cnt: int = int(item.get("count", 1))

	if is_produce:
		var s1 := Button.new()
		s1.text = "Bán 1 (+%d Lượng)" % unit_price
		s1.focus_mode = Control.FOCUS_NONE
		_style_action_btn(s1, Color(0.22, 0.32, 0.16))
		s1.pressed.connect(func():
			if farm_mgr and farm_mgr.remove_from_chest(item_id, 1, false):
				farm_mgr.earn_gold(unit_price)
				var cur_pos = chest_win.position
				chest_win.queue_free()
				open_chest(parent, cur_tab, cur_pos)
		)
		pact.add_child(s1)

		var sa := Button.new()
		sa.text = "Bán Hết (+%d Lượng)" % [unit_price * cnt]
		sa.focus_mode = Control.FOCUS_NONE
		_style_action_btn(sa, Color(0.35, 0.28, 0.12))
		sa.pressed.connect(func():
			if farm_mgr and farm_mgr.remove_from_chest(item_id, cnt, false):
				farm_mgr.earn_gold(unit_price * cnt)
				var cur_pos = chest_win.position
				chest_win.queue_free()
				open_chest(parent, cur_tab, cur_pos)
		)
		pact.add_child(sa)
	elif item.get("is_animal", false):
		var tree := chest_win.get_tree()
		var ls_script: GDScript = load("res://systems/son_trang/livestock_controller.gd") if ResourceLoader.exists("res://systems/son_trang/livestock_controller.gd") else load("res://world/maps/map_nguyet_ca/livestock_controller.gd")
		var check: Dictionary = ls_script.check_player_in_zone(tree) if ls_script != null else {"inside": false}

		var zone_hint := Label.new()
		zone_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		zone_hint.add_theme_font_size_override("font_size", 11)
		if check.get("inside", false):
			zone_hint.text = "📍 %s: Sẵn sàng thả thú!" % check.get("zone_name", "Vòng Nuôi Thú")
			zone_hint.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			zone_hint.text = "⚠️ Phải đứng trong Vòng Nuôi Thú [194/193] mới có thể thả!"
			zone_hint.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
		pinfo.add_child(zone_hint)

		# Nút di chuyển nhanh đến vòng nuôi thú nếu đang ở xa
		if not check.get("inside", false):
			var walk_to_zone := Button.new()
			walk_to_zone.text = "🏃 Đến Vòng Nuôi Thú"
			walk_to_zone.focus_mode = Control.FOCUS_NONE
			_style_action_btn(walk_to_zone, Color(0.20, 0.35, 0.45))
			walk_to_zone.pressed.connect(func():
				var cur_tree := chest_win.get_tree()
				var player = cur_tree.get_first_node_in_group("player") if cur_tree else null
				if player != null and is_instance_valid(player):
					var target_pos := Vector2(49792.0, 49536.0)
					if player.has_method("walk_to_feet"):
						player.walk_to_feet(target_pos)
					elif "destination" in player:
						player.destination = target_pos
					if player.has_method("notify"):
						player.notify("🏃 Đang di chuyển vào Vòng Nuôi Thú Sơn Trang...")
				chest_win.queue_free()
			)
			pact.add_child(walk_to_zone)

		var adopt := Button.new()
		adopt.text = "🐾 Thả Nuôi"
		adopt.focus_mode = Control.FOCUS_NONE
		_style_action_btn(adopt, Color(0.18, 0.45, 0.28))
		adopt.pressed.connect(func():
			var cur_tree := chest_win.get_tree()
			var zone_check: Dictionary = ls_script.check_player_in_zone(cur_tree) if ls_script != null else {"inside": false}
			if not zone_check.get("inside", false):
				zone_hint.text = "❌ Thả thất bại! Bạn cần di chuyển vào bên trong Vòng Nuôi Thú mới có thể thả con vật này."
				zone_hint.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
				if cur_tree != null:
					var player = cur_tree.get_first_node_in_group("player")
					if player != null and is_instance_valid(player) and player.has_method("notify"):
						player.notify("⚠️ Bạn phải đứng trong Vòng Nuôi Thú mới có thể thả con vật!")
				return

			var target_zone = zone_check.get("zone")
			var ppos: Vector2 = zone_check.get("player_pos", Vector2.ZERO)
			var success: bool = false
			if target_zone != null and target_zone.has_method("release_animal_here"):
				success = target_zone.release_animal_here(item, ppos)
			elif farm_mgr and farm_mgr.livestock_mgr != null:
				success = farm_mgr.livestock_mgr.adopt_animal(item)

			if success:
				farm_mgr.remove_from_chest(item_id, 1, true)
				farm_mgr.save_farm_data()
				farm_mgr.farm_data_changed.emit()

				if cur_tree != null:
					var player = cur_tree.get_first_node_in_group("player")
					if player != null and is_instance_valid(player) and player.has_method("notify"):
						player.notify("🎉 Đã thả %s vào %s thành công!" % [str(item.get("name", "Vật nuôi")), zone_check.get("zone_name", "Vòng Nuôi Thú")])

				var cur_pos = chest_win.position
				chest_win.queue_free()
				open_chest(parent, cur_tab, cur_pos)
			else:
				zone_hint.text = "❌ Vòng nuôi đã đầy hoặc xảy ra lỗi!"
				zone_hint.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		)
		pact.add_child(adopt)
	elif item_id in ["fingerling_carp", "fingerling_sea_bass"]:
		var is_carp: bool = (item_id == "fingerling_carp")
		var target_loc := "Ao Cá Nước Ngọt (181/185)" if is_carp else "Bè Cá Biển Sâu (196/198)"
		var pond_pos := Vector2(46566.0, 47511.0) if is_carp else Vector2(50304.0, 50820.0)

		var cur_tree := chest_win.get_tree()
		var player = cur_tree.get_first_node_in_group("player") if cur_tree else null
		var p_pos: Vector2 = player.global_position if (player and is_instance_valid(player)) else Vector2.ZERO
		var dist: float = p_pos.distance_to(pond_pos) if p_pos != Vector2.ZERO else 9999.0
		# Với Bè Cá Biển: Cho phép đứng gần Bè Biển (196/198), Cầu Tàu Biển (50304, 50640), hoặc NPC Hải Ngư Thuyền Trưởng (196/197)
		var is_near: bool = false
		if is_carp:
			var kh_pos := Vector2(46208.0, 47488.0) # Khê Hồ Ngư Nương
			is_near = (dist < 400.0) or (p_pos.distance_to(kh_pos) < 400.0)
		else:
			var pier_pos := Vector2(50304.0, 50640.0)
			var npc_pos := Vector2(50304.0, 50560.0)
			var dist_pier: float = p_pos.distance_to(pier_pos) if p_pos != Vector2.ZERO else 9999.0
			var dist_npc: float = p_pos.distance_to(npc_pos) if p_pos != Vector2.ZERO else 9999.0
			is_near = (dist < 450.0) or (dist_pier < 450.0) or (dist_npc < 450.0)

		var fish_hint := Label.new()
		fish_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fish_hint.add_theme_font_size_override("font_size", 11)
		if is_near:
			fish_hint.text = "📍 Đang đứng cạnh %s: Sẵn sàng thả giống!" % target_loc
			fish_hint.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			fish_hint.text = "📍 Hãy mang tới %s để thả nuôi sinh sôi!" % target_loc
			fish_hint.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		pinfo.add_child(fish_hint)

		var release_btn := Button.new()
		release_btn.text = "🐟 Thả Nuôi"
		release_btn.focus_mode = Control.FOCUS_NONE
		_style_action_btn(release_btn, Color(0.18, 0.40, 0.55))
		release_btn.pressed.connect(func():
			if not is_near:
				fish_hint.text = "⚠️ Bạn cần đứng gần %s để thả cá giống!" % target_loc
				fish_hint.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
				if player and player.has_method("notify"):
					player.notify("⚠️ Bạn phải đứng gần %s mới có thể thả giống!" % target_loc)
				return

			if farm_mgr and farm_mgr.remove_from_chest(item_id, 1, true):
				var fish_ctrl = cur_tree.root.find_child("FarmFishController", true, false)
				if fish_ctrl != null and "fish_data" in fish_ctrl:
					var p_idx := 0 if is_carp else 1
					var p_data: Dictionary = fish_ctrl.fish_data[p_idx]
					p_data["started_at"] = int(Time.get_unix_time_from_system())
					p_data["fish_name"] = "Cá Trắm Cỏ" if is_carp else "Cá Vược Biển"
					p_data["oxy_count"] = 0
					p_data["mineral"] = false

				farm_mgr.save_farm_data()
				farm_mgr.farm_data_changed.emit()
				if player and player.has_method("notify"):
					player.notify("🎉 Đã thả %s vào %s thành công!" % [str(item.get("name", "Cá Giống")), target_loc])

				var cur_pos = chest_win.position
				chest_win.queue_free()
				open_chest(parent, cur_tab, cur_pos)
		)
		pact.add_child(release_btn)

		var close_act := Button.new()
		close_act.text = "Đóng"
		close_act.focus_mode = Control.FOCUS_NONE
		_style_action_btn(close_act, Color(0.2, 0.2, 0.25))
		close_act.pressed.connect(popup.queue_free)
		pact.add_child(close_act)
	else:
		var close_act := Button.new()
		close_act.text = "Đóng"
		close_act.focus_mode = Control.FOCUS_NONE
		_style_action_btn(close_act, Color(0.2, 0.2, 0.25))
		close_act.pressed.connect(popup.queue_free)
		pact.add_child(close_act)

	chest_win.add_child(popup)

static func _style_action_btn(btn: Button, base_color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base_color
	sb.border_color = base_color.lightened(0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", sb)

	var hsb := StyleBoxFlat.new()
	hsb.bg_color = base_color.lightened(0.2)
	hsb.border_color = Color(1.0, 0.85, 0.3)
	hsb.set_border_width_all(1)
	hsb.set_corner_radius_all(4)
	hsb.content_margin_left = 10
	hsb.content_margin_right = 10
	hsb.content_margin_top = 5
	hsb.content_margin_bottom = 5
	btn.add_theme_stylebox_override("hover", hsb)

## Nạp Texture2D cho vật phẩm: Ưu tiên ảnh quái/thú VLTK đứng, sau đó nạp file Icon .png nội bộ
static func _load_texture_for_item(item: Dictionary) -> Texture2D:
	if item.has("monster_res"):
		var mres: String = str(item["monster_res"])
		var thumb_tex := MonsterData.thumb(mres)
		if thumb_tex != null:
			return thumb_tex
		var act := MonsterData.action(mres, "stand")
		var anim_key: String = str(act.get("anim", ""))
		if anim_key != "":
			var anim_info: Dictionary = MonsterData.anim(anim_key)
			var size_arr: Array = anim_info.get("size", [])
			var tex: Texture2D = MonsterData.texture(anim_key)
			if tex != null and size_arr.size() >= 2:
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(0, 0, float(size_arr[0]), float(size_arr[1]))
				return atlas

	var icon_name: String = str(item.get("icon", "zhurou.png"))
	if icon_name == "chuizi.png":
		icon_name = "chan.png"

	# 1. Thử nạp từ assets/farm/icons/ (luôn được đóng gói vào index.pck bản Web)
	var farm_icon_path: String = "res://assets/farm/icons/" + icon_name
	if ResourceLoader.exists(farm_icon_path):
		var tex = load(farm_icon_path)
		if tex is Texture2D:
			return tex
	var res_farm = load(farm_icon_path)
	if res_farm is Texture2D:
		return res_farm

	# 2. Thử nạp từ assets/items/icons/ (gói content.pck)
	var full_icon_path: String = ICON_PREFIX + icon_name
	if ResourceLoader.exists(full_icon_path):
		var tex = load(full_icon_path)
		if tex is Texture2D:
			return tex
	var res_items = load(full_icon_path)
	if res_items is Texture2D:
		return res_items

	# 3. Nếu là cây trồng, nạp ảnh trưởng thành từ assets/farm/crops/
	var i_id: String = str(item.get("item_id", ""))
	var plant := PlantData.get_plant(i_id)
	if plant != null:
		if plant.sprite_mature != "":
			var p_tex = load(plant.sprite_mature)
			if p_tex is Texture2D:
				return p_tex
		if plant.sprite_growing != "":
			var p_tex = load(plant.sprite_growing)
			if p_tex is Texture2D:
				return p_tex

	# 4. Fallback an toàn đảm bảo luôn có ảnh hiển thị trên Web
	var fallback_res = load("res://assets/farm/crops/seed.png")
	if fallback_res is Texture2D:
		return fallback_res

	return null

## Từ điển định nghĩa tên, icon, giá bán và phân loại cho mọi vật phẩm trong kho
static func get_item_meta(item_id: String, is_supply: bool) -> Dictionary:
	# 1. Kiểm tra cây trồng từ PlantData
	var p := PlantData.get_plant(item_id)
	if p != null:
		return {
			"name": p.name if not is_supply else ("Hạt Giống " + p.name),
			"icon": p.icon_path.get_file() if p.icon_path != "" else "seed_lucky.png",
			"category": "Nông Sản Thu Hoạch" if not is_supply else "Hạt Giống",
			"desc": "Cây trồng chất lượng cao thu hoạch từ mảnh đất sơn trang." if not is_supply else "Hạt giống gieo xuống luống đất cày xới.",
			"sell_price": p.sale_price_gold,
			"is_seed": is_supply
		}

	# 2. Định nghĩa chi tiết các sản phẩm & vật tư khác
	var dict = {
		# Nông sản / Thành phẩm thu hoạch
		"rice": {"name": "Lúa Vàng", "icon": "damidai.png", "category": "Nông Sản", "sell_price": 20, "desc": "Hạt lúa vàng óng xay xát thành gạo trắng."},
		"cabbage": {"name": "Bắp Cải Tươi", "icon": "bainianqixingcao.png", "category": "Rau Sạch", "sell_price": 25, "desc": "Bắp cải giòn ngọt vừa thu hoạch."},
		"tomato": {"name": "Cà Chua Mọng", "icon": "seed_normal.png", "category": "Hoa Quả", "sell_price": 35, "desc": "Quả cà chua chín đỏ mọng nước."},
		"potato": {"name": "Khoai Tây Củ", "icon": "hongshu.png", "category": "Nông Sản", "sell_price": 50, "desc": "Củ khoai tây bở thơm bùi."},
		"watermelon": {"name": "Dưa Hấu Ngọt", "icon": "seed_rose.png", "category": "Trái Cây", "sell_price": 80, "desc": "Trái dưa hấu giải nhiệt mùa hè."},
		"herb": {"name": "Thảo Dược Quý", "icon": "seed_gold.png", "category": "Dược Liệu", "sell_price": 150, "desc": "Dược liệu quý ngàn năm chuyên luyện đan."},
		
		# Sản phẩm chăn nuôi
		"produce_pork": {"name": "Thịt Heo Sạch", "icon": "zhurou.png", "category": "Thực Phẩm", "sell_price": 60, "desc": "Thịt heo trắng tươi sạch chất lượng cao."},
		"produce_buffalo_meat": {"name": "Thịt Trâu Tươi", "icon": "zhurou.png", "category": "Thực Phẩm", "sell_price": 90, "desc": "Thịt trâu tươi ngon giàu dinh dưỡng."},
		"produce_deer_meat": {"name": "Thịt Hươu Tươi", "icon": "zhurou.png", "category": "Thực Phẩm", "sell_price": 130, "desc": "Thịt hươu sao bổ dưỡng thượng hạng."},
		"produce_milk": {"name": "Sữa Trâu Thơm", "icon": "mailk.png", "category": "Dinh Dưỡng", "sell_price": 90, "desc": "Sữa trâu nguyên chất béo ngậy."},
		"produce_deer_horn": {"name": "Nhung Hươu Quý", "icon": "bainianqixingcao.png", "category": "Dược Liệu", "sell_price": 130, "desc": "Lộc nhung hươu sao bồi bổ nguyên khí."},
		"produce_wild_pork": {"name": "Thịt Heo Rừng", "icon": "zhurou.png", "category": "Đặc Sản", "sell_price": 75, "desc": "Thịt heo rừng săn chắc thơm ngon."},
		"prod_eagle": {"name": "Lông Vũ Đại Bàng", "icon": "bamboo.png", "category": "Nguyên Liệu", "sell_price": 160, "desc": "Lông vũ chim điêu đại bàng làm đuôi tên bắn."},
		"prod_vulture": {"name": "Lông Chim Ưng", "icon": "bamboo.png", "category": "Nguyên Liệu", "sell_price": 100, "desc": "Lông vũ chim ưng dẻo dai."},
		"prod_cat": {"name": "Lông Mèo Gấm", "icon": "yadan.png", "category": "Nguyên Liệu", "sell_price": 85, "desc": "Bộ lông mèo gấm mềm mịn."},
		"prod_monkey": {"name": "Trái Cây Rừng", "icon": "huasheng.png", "category": "Thực Phẩm", "sell_price": 70, "desc": "Trái cây rừng thơm ngọt do khỉ hái về."},
		"prod_hedgehog": {"name": "Gai Nhím Rừng", "icon": "songzhen.png", "category": "Ám Khí", "sell_price": 55, "desc": "Gai nhím sắc nhọn dùng chế tạo ám khí."},
		"prod_tiger": {"name": "Oai Lực Sơn Lâm", "icon": "baihuling.png", "category": "Bảo Vật", "sell_price": 350, "desc": "Tín vật uy nghiêm của chúa sơn lâm."},
		"prod_wolf": {"name": "Nanh Sói Dũng Sĩ", "icon": "canglangling.png", "category": "Bảo Vật", "sell_price": 140, "desc": "Nanh vuốt sói đỏ săn mồi dũng mãnh."},
		"prod_fox": {"name": "Lông Tuyết Hồ", "icon": "heidiaoxin.png", "category": "Bảo Vật", "sell_price": 200, "desc": "Lông tuyết hồ trắng muốt thượng hạng."},

		# Thủy sản & Đánh bắt cá
		"caoyu": {"name": "Cá Trắm Cỏ Hồ", "icon": "caoyu.png", "category": "Thủy Sản", "sell_price": 30, "desc": "Cá trắm cỏ tươi sống câu từ hồ Nguyệt Ca."},
		"bianyu": {"name": "Cá Vược Biển", "icon": "bianyu.png", "category": "Hải Sản", "sell_price": 70, "desc": "Cá vược biển tươi roi rói câu ven bến tàu."},
		"grilled_fresh_fish": {"name": "Cá Nướng Hồ", "icon": "kaoyu.png", "category": "Thức Ăn", "sell_price": 50, "desc": "Cá suối nướng than thơm lừng hồi phục thể lực."},
		"grilled_sea_fish": {"name": "Cá Biển Nướng", "icon": "gaojikaoyu.png", "category": "Thức Ăn", "sell_price": 90, "desc": "Cá biển nướng muối ớt cay nồng bổ dưỡng."},

		# Hạt giống
		"seed_rice": {"name": "Hạt Giống Lúa Nước", "icon": "seed_lucky.png", "category": "Hạt Giống", "desc": "Hạt giống lúa vàng gieo trồng 1 phút.", "is_seed": true},
		"seed_cabbage": {"name": "Hạt Giống Bắp Cải", "icon": "bainianqixingcao.png", "category": "Hạt Giống", "desc": "Hạt giống bắp cải xanh gieo trồng 1.5 phút.", "is_seed": true},
		"seed_tomato": {"name": "Hạt Giống Cà Chua", "icon": "seed_normal.png", "category": "Hạt Giống", "desc": "Hạt giống cà chua mọng gieo trồng 2 phút.", "is_seed": true},
		"seed_potato": {"name": "Hạt Giống Khoai Tây", "icon": "hongshu.png", "category": "Hạt Giống", "desc": "Hạt giống khoai tây củ gieo trồng 2.5 phút.", "is_seed": true},
		"seed_watermelon": {"name": "Hạt Giống Dưa Hấu", "icon": "seed_rose.png", "category": "Hạt Giống", "desc": "Hạt giống dưa hấu đỏ gieo trồng 3 phút.", "is_seed": true},
		"seed_herb": {"name": "Hạt Giống Thảo Dược", "icon": "seed_gold.png", "category": "Hạt Giống", "desc": "Hạt giống dược liệu quý gieo trồng 5 phút.", "is_seed": true},
		"fertilizer": {"name": "Phân Bón Vi Sinh", "icon": "feiliaodai.png", "category": "Vật Tư", "desc": "Rút ngắn 30% thời gian lớn của cây trồng."},

		# Thức ăn chăn nuôi
		"feed_grass": {"name": "Cỏ Tươi Đồng Quê", "icon": "bainianqixingcao.png", "category": "Thức Ăn Thú", "desc": "Cỏ tươi cho thú ăn (+40 Đói, +5 Thân Mật)."},
		"feed_grain": {"name": "Thóc Lúa Vàng Óng", "icon": "damidai.png", "category": "Thức Ăn Thú", "desc": "Thóc lúa bổ sung dinh dưỡng (+75 Đói, +10 Thân Mật)."},
		"feed_elephant_grass": {"name": "Cỏ Voi Tươi Ngọt", "icon": "bamboo.png", "category": "Thức Ăn Thú", "desc": "Cỏ voi mọng nước khoái khẩu của Trâu và Voi (+100 Đói, giảm 15% thời gian lớn)."},
		"feed_meat": {"name": "Thịt Tươi Săn Bắn", "icon": "zhurou.png", "category": "Thức Ăn Thú", "desc": "Thịt tươi sống cho dã thú Hổ, Sói, Báo (+100 Đói, giảm 25% thời gian lớn)."},
		"feed_compound": {"name": "Cám Hỗn Hợp Bổ Dưỡng", "icon": "huasheng.png", "category": "Thức Ăn Thú", "desc": "Cám tổng hợp giàu khoáng chất (+100 Đói, giảm 35% thời gian lớn, +10% vàng)."},
		"feed_divine_herb": {"name": "Linh Thảo Tiên Đơn", "icon": "heidiaoxin.png", "category": "Thức Ăn Thú", "desc": "Linh đan thần thú ngàn năm (+100 Đói, giảm 55% thời gian lớn, +30% vàng)."},
		"feed_royal_feast": {"name": "Vương Giả Thần Lương", "icon": "baiyu.png", "category": "Thức Ăn Thú", "desc": "Đại lương vương giả (+100 Đói, lớn ngay lập tức 100%, +50% vàng)."},

		# Động vật & Loài chim giống
		"animal_elephant_hoang_ha": {"name": "Voi Hoàng Hà Cổ Tượng", "monster_res": "ani024", "icon": "baihuling.png", "category": "Thần Thú Cự Đại", "desc": "Cổ tượng Hoàng Hà uy dũng sa trường, giá mắc nhất x10 lần.", "is_animal": true},
		"animal_elephant_giant": {"name": "Bạch Tượng Thần Thú", "monster_res": "ani021", "icon": "baihuling.png", "category": "Thần Thú Cự Đại", "desc": "Đại tượng khổng lồ ngàn năm sức mạnh bạt sơn cái thế.", "is_animal": true},
		"animal_bear_brown": {"name": "Bạo Hùng Gấu Nâu", "monster_res": "ani025", "icon": "zhurou.png", "category": "Mãnh Thú Sơn Lâm", "desc": "Bạo hùng dũng mãnh, cho Mật Gấu Rừng đại bổ.", "is_animal": true},
		"animal_bear_black": {"name": "Hắc Hùng Gấu Đen", "monster_res": "ani026", "icon": "zhurou.png", "category": "Mãnh Thú Sơn Lâm", "desc": "Gấu đen phương bắc, Da Gấu Đen chống rét.", "is_animal": true},
		"animal_bear_raccoon": {"name": "Hoán Hùng Linh Thú", "monster_res": "ani051", "icon": "huasheng.png", "category": "Linh Thú", "desc": "Gấu mèo hoạt bát tinh khôn trông kho bãi.", "is_animal": true},
		"animal_tiger": {"name": "Bạch Hổ Chúa Sơn Lâm", "monster_res": "ani001", "icon": "baihuling.png", "category": "Linh Thú", "desc": "Hổ trắng hộ vệ sơn môn.", "is_animal": true},
		"animal_tiger_blood": {"name": "Sát Huyết Mãnh Hổ", "monster_res": "ani002", "icon": "baihuling.png", "category": "Linh Thú", "desc": "Hổ vằn Hoa Nam thiện chiến hung hãn.", "is_animal": true},
		"animal_tiger_snow": {"name": "Bạch Hổ Tuyết Sơn", "monster_res": "ani003", "icon": "baihuling.png", "category": "Linh Thú", "desc": "Bạch hổ đỉnh Tuyết Sơn tỏa hàn khí băng giá.", "is_animal": true},
		"animal_leopard_gold": {"name": "Kim Tiền Báo Hoa Mai", "monster_res": "ani005", "icon": "baihuling.png", "category": "Linh Thú", "desc": "Báo gấm hoa mai tốc độ như tia chớp.", "is_animal": true},
		"animal_leopard_snow": {"name": "Tuyết Báo Vương", "monster_res": "ani006", "icon": "baihuling.png", "category": "Linh Thú", "desc": "Chúa tể báo tuyết bắc cực băng giá.", "is_animal": true},
		"animal_wolf": {"name": "Hồng Lang Sói Đỏ", "monster_res": "ani010", "icon": "canglangling.png", "category": "Dã Thú", "desc": "Sói săn mồi trung thành tuyệt đối.", "is_animal": true},
		"animal_wolf_gray": {"name": "Hôi Lang Sói Xám", "monster_res": "ani009", "icon": "canglangling.png", "category": "Dã Thú", "desc": "Sói xám đồng hoang tinh quái bền bỉ.", "is_animal": true},
		"animal_wolf_green": {"name": "Thanh Lang Ác Thú", "monster_res": "ani011", "icon": "canglangling.png", "category": "Dã Thú", "desc": "Sói xanh mắt sáng rực trong bóng đêm.", "is_animal": true},
		"animal_wolf_snow": {"name": "Bạch Lang Tuyết Vực", "monster_res": "ani012", "icon": "canglangling.png", "category": "Dã Thú", "desc": "Sói trắng bắc cực chịu giá rét phi thường.", "is_animal": true},
		"animal_fox": {"name": "Bạch Cáo Tuyết Hồ", "monster_res": "ani013", "icon": "heidiaoxin.png", "category": "Linh Thú", "desc": "Cáo tuyết thông minh lấy lông thú.", "is_animal": true},
		"animal_fox_fire": {"name": "Cửu Vĩ Hỏa Hồ", "monster_res": "ani015", "icon": "heidiaoxin.png", "category": "Linh Thú", "desc": "Hồ ly lửa đỏ mang linh khí may mắn.", "is_animal": true},
		"animal_pig": {"name": "Heo Trắng Giống", "monster_res": "ani063", "icon": "zhurou.png", "category": "Con Giống", "desc": "Con giống heo trắng thả chuồng.", "is_animal": true},
		"animal_boar": {"name": "Heo Rừng Dũng Mãnh", "monster_res": "ani018", "icon": "zhurou.png", "category": "Con Giống", "desc": "Heo rừng lấy thịt chắc nạc.", "is_animal": true},
		"animal_buffalo": {"name": "Trâu Cày Kéo", "monster_res": "ani029", "icon": "mailk.png", "category": "Con Giống", "desc": "Trâu giống cày kéo lấy sữa.", "is_animal": true},
		"animal_deer": {"name": "Hươu Sao Đồng Cỏ", "monster_res": "ani061", "icon": "bainianqixingcao.png", "category": "Con Giống", "desc": "Hươu sao lấy nhung quý.", "is_animal": true},
		"animal_deer_fragrant": {"name": "Bách Hương Thần Lộc", "monster_res": "ani069", "icon": "bainianqixingcao.png", "category": "Linh Thú", "desc": "Hươu xạ hương thơm ngàn dặm luyện đan.", "is_animal": true},
		"animal_cat": {"name": "Linh Miêu Gấm", "monster_res": "ani052", "icon": "yadan.png", "category": "Thú Nuôi", "desc": "Mèo cảnh bắt chuột giữ kho.", "is_animal": true},
		"animal_cat_gold": {"name": "Kim Miêu Hoàng Gia", "monster_res": "ani049", "icon": "yadan.png", "category": "Thú Nuôi", "desc": "Mèo lông vàng hoàng tộc bắt chuột giữ kho.", "is_animal": true},
		"animal_cat_gem": {"name": "Xá Lị Linh Miêu", "monster_res": "ani050", "icon": "yadan.png", "category": "Thú Nuôi", "desc": "Mèo mắt ngọc trừ tà trấn trạch.", "is_animal": true},
		"animal_hedgehog": {"name": "Nhím Gai Rừng", "monster_res": "ani019", "icon": "songzhen.png", "category": "Thú Nuôi", "desc": "Nhím cảnh lấy gai nhím.", "is_animal": true},
		"animal_monkey": {"name": "Khỉ Xám Rừng Trúc", "monster_res": "ani054", "icon": "huasheng.png", "category": "Thú Nuôi", "desc": "Khỉ khôn hái trái cây.", "is_animal": true},
		"animal_monkey_tibetan": {"name": "Tàng Vực Tuyết Hầu", "monster_res": "ani053", "icon": "huasheng.png", "category": "Thú Nuôi", "desc": "Khỉ tuyết hái dược thảo vách núi.", "is_animal": true},
		"animal_monkey_black": {"name": "Hắc Diệp Thần Hầu", "monster_res": "ani055", "icon": "huasheng.png", "category": "Thú Nuôi", "desc": "Vượn đen rừng sâu canh gác trang trại.", "is_animal": true},
		"animal_monkey_golden": {"name": "Kim Tơ Hoàng Hầu", "monster_res": "ani056", "icon": "huasheng.png", "category": "Thú Nuôi", "desc": "Khỉ vàng lông tơ quý tộc thông minh.", "is_animal": true},
		"animal_jackal": {"name": "Sài Lang Hoang Dã", "monster_res": "ani058", "icon": "canglangling.png", "category": "Dã Thú", "desc": "Chó rừng sài lang dẻo dai trung dũng.", "is_animal": true},
		"animal_eagle": {"name": "Đại Bàng Thứu Thần", "monster_res": "ani042", "icon": "bamboo.png", "category": "Chim Giống", "desc": "Chim đại bàng nuôi thả sơn trang.", "is_animal": true},
		"animal_eagle_gold": {"name": "Kim Điêu Thiên Ưng", "monster_res": "ani041", "icon": "bamboo.png", "category": "Chim Giống", "desc": "Đại điêu vàng sải cánh ngút trời.", "is_animal": true},
		"animal_vulture": {"name": "Chim Kền Kền Núi", "monster_res": "ani043", "icon": "bamboo.png", "category": "Chim Giống", "desc": "Chim ưng săn mồi dũng mãnh.", "is_animal": true},
		"animal_bat_lord": {"name": "Hắc Dạ Dơi Chúa", "monster_res": "ani045", "icon": "bamboo.png", "category": "Chim Giống", "desc": "Dơi chúa bóng đêm canh gác ban đêm.", "is_animal": true},
		"animal_bat_red": {"name": "Huyết Dạ Dơi Đỏ", "monster_res": "ani046", "icon": "bamboo.png", "category": "Chim Giống", "desc": "Dơi đỏ mắt ngọc ruby huyền bí.", "is_animal": true},
		"animal_bat_cave": {"name": "Thâm Lâm Dơi Dong", "monster_res": "ani047", "icon": "bamboo.png", "category": "Chim Giống", "desc": "Dơi dong bắt sâu bọ bảo vệ mùa màng.", "is_animal": true},
		"animal_bat_blood": {"name": "Huyết Dơi Hút Máu", "monster_res": "ani048", "icon": "bamboo.png", "category": "Chim Giống", "desc": "Dơi nhung nhanh nhẹn phát hiện kẻ lạ.", "is_animal": true},
		"animal_crocodile": {"name": "Cá Sấu Cự Ngạc", "monster_res": "ani033", "icon": "caoyu.png", "category": "Dị Thú", "desc": "Cá sấu vảy sắt đầm lầy trấn giữ ao.", "is_animal": true},
		"animal_lizard": {"name": "Hỏa Diễm Thằn Lằn Đỏ", "monster_res": "ani036", "icon": "huasheng.png", "category": "Dị Thú", "desc": "Thằn lằn đỏ sưởi ấm chuồng trại mùa đông.", "is_animal": true},
		"animal_snake_cobra": {"name": "Nhãn Kính Mãng Xà", "monster_res": "ani037", "icon": "yuer.png", "category": "Dị Thú", "desc": "Hổ mang chúa cho nọc độc quý.", "is_animal": true},
		"animal_snake_green": {"name": "Bích Luyện Thanh Xà", "monster_res": "ani038", "icon": "yuer.png", "category": "Dị Thú", "desc": "Rắn xanh bờ tre đuổi chuột giữ thóc.", "is_animal": true},
		"animal_snake_golden": {"name": "Kim Hoàn Mãng Xà", "monster_res": "ani039", "icon": "yuer.png", "category": "Dị Thú", "desc": "Trăn gấm khoang vàng thịnh vượng.", "is_animal": true},
		"animal_snake_fire": {"name": "Xích Luyện Hỏa Xà", "monster_res": "ani040", "icon": "yuer.png", "category": "Dị Thú", "desc": "Rắn đỏ lửa tỏa hơi ấm mùa đông.", "is_animal": true},
		"animal_toad_gold": {"name": "Kim Thiềm Thần Cóc", "monster_res": "ani060", "icon": "yadan.png", "category": "Linh Thú", "desc": "Cóc vàng ngậm tiền chiêu tài tiến bảo.", "is_animal": true},
		"animal_yeti_snow": {"name": "Bắc Vực Tuyết Quái", "monster_res": "ani059", "icon": "baihuling.png", "category": "Dị Thú", "desc": "Dị thú khổng lồ lông trắng vùng cực bắc.", "is_animal": true},
		"animal_scorpion": {"name": "Thiết Giáp Bọ Cạp", "monster_res": "ani065", "icon": "songzhen.png", "category": "Dị Thú", "desc": "Bọ cạp thiết giáp nọc độc hộ thể.", "is_animal": true},
		"animal_spider": {"name": "Ngũ Thái Thần Thù", "monster_res": "ani066", "icon": "yadan.png", "category": "Dị Thú", "desc": "Nhện năm màu dệt tơ ngũ sắc bền chắc.", "is_animal": true},
		"animal_centipede": {"name": "Thiên Tố Cự Ngô Công", "monster_res": "ani067", "icon": "songzhen.png", "category": "Dị Thú", "desc": "Rết khổng lồ nhiều chân hỗ trợ luyện đan.", "is_animal": true},

		# Cá giống & Thủy sản
		"fingerling_carp": {"name": "Cá Trắm Cỏ Giống", "icon": "caoyu.png", "category": "Con Giống Thủy Sản", "sell_price": 20, "desc": "Cá con khoẻ mạnh thả vào ao hồ sơn trang nuôi dưỡng sinh sôi.", "is_seed": true},
		"fingerling_sea_bass": {"name": "Cá Vược Biển Giống", "icon": "bianyu.png", "category": "Con Giống Thủy Sản", "sell_price": 35, "desc": "Cá biển giống thả lồng bè ven bờ biển Nam Hải nuôi lớn lấy thịt thơm ngon.", "is_seed": true},
		"fish_fresh": {"name": "Cá Trắm Cỏ Hồ", "icon": "caoyu.png", "category": "Thủy Sản", "sell_price": 30, "desc": "Cá trắm cỏ tươi sống thu hoạch từ hồ Nguyệt Ca."},
		"fish_ocean": {"name": "Cá Vược Biển Sâu", "icon": "bianyu.png", "category": "Hải Sản", "sell_price": 70, "desc": "Cá vược biển tươi roi rói thu hoạch từ bè bến tàu."},

		# Công cụ & Dụng cụ nông ngư nghiệp
		"tool_hoe": {"name": "Cuốc Thép Khai Hoang", "icon": "chan.png", "category": "Công Cụ", "sell_price": 50, "desc": "Cuốc thép sắc bén dùng khai hoang mở rộng luống đất trồng."},
		"tool_watercan": {"name": "Bình Tưới Đồng", "icon": "shuitong.png", "category": "Dụng Cụ", "sell_price": 40, "desc": "Bình tưới đồng tưới mát cho cây trồng rút ngắn thời gian sinh trưởng."},
		"tool_rod_bamboo": {"name": "Cần Câu Trúc Hồ Đầm", "icon": "diaogan.png", "category": "Công Cụ", "desc": "Cần câu trúc câu cá suối, đầm sen."},
		"tool_rod_ocean": {"name": "Cần Câu Biển Cường Lực", "icon": "diaogan.png", "category": "Công Cụ", "desc": "Cần câu biển carbon câu cá lớn ngoài khơi."},
		"bait_worm": {"name": "Mồi Trùng Đất Đầm Sen", "icon": "yuer.png", "category": "Mồi Câu", "desc": "Giun đất tươi câu cá nước ngọt."},
		"bait_shrimp": {"name": "Mồi Tôm Biển Tươi Rói", "icon": "xia.png", "category": "Mồi Câu", "desc": "Tôm biển tươi roi rói câu cá biển."},
		"fish_pot": {"name": "Hũ Dưỡng Thủy Sản", "icon": "yuguan.png", "category": "Dụng Cụ", "desc": "Bình giữ cá luôn tươi sống."},
		"fresh_water_pot": {"name": "Thùng Nước Suối Khoáng", "icon": "shuitong.png", "category": "Vật Tư", "desc": "Nước suối khoáng tự nhiên."},
		"sea_salt_barrel": {"name": "Thùng Muối Biển Hạt To", "icon": "shuitong.png", "category": "Vật Tư", "desc": "Muối hạt ướp hải sản."},
		"jade_fish_token": {"name": "Bạch Ngọc Hoa Tiêu", "icon": "baiyu.png", "category": "Bảo Vật", "desc": "La bàn định vị ngư trường biển."},
		"ruong_bach_thu_son_trang": {"name": "Rương Bách Thú Sơn Trang", "icon": "item_goldenbox", "category": "Bảo Rương", "sell_price": 500, "desc": "Bảo rương quý giá nhận khi đổi thịt thú nuôi cho Trù Thần. Mở ra nhận Trang Bị Quý, Tiên Thảo Lộ, Thủy Tinh, và tỷ lệ CỰC HIẾM rớt Tuyệt Kỹ 150, Bí Kíp 180!"}
	}

	if dict.has(item_id):
		return dict[item_id]

	# 3. Tra cứu tự động từ NPC Shop Catalog nếu chưa có trong từ điển thủ công
	var shop_script = load("res://ui/son_trang/farm_npc_shop.gd")
	if shop_script != null and "SHOP_CATALOG" in shop_script:
		var catalog: Dictionary = shop_script.SHOP_CATALOG
		for cat_key in catalog:
			var cat_data: Dictionary = catalog[cat_key]
			var items: Array = cat_data.get("items", [])
			for it in items:
				var it_id: String = str(it.get("id", ""))
				var it_supply: String = str(it.get("supply_key", ""))
				if it_id == item_id or it_supply == item_id:
					var is_seed_val: bool = is_supply and (item_id.begins_with("seed_") or item_id.begins_with("fingerling_") or "giống" in str(it.get("name", "")).to_lower())
					var is_animal_val: bool = is_supply and (it.has("monster_res") or it.has("animal_id") or item_id.begins_with("animal_"))
					var res_dict: Dictionary = it.duplicate(true)
					res_dict["name"] = str(it.get("name", item_id.capitalize()))
					res_dict["icon"] = str(it.get("icon", "damidai.png"))
					res_dict["category"] = str(it.get("category_tag", "Con Giống" if (is_seed_val or is_animal_val) else ("Vật Tư" if is_supply else "Nông Sản")))
					res_dict["desc"] = str(it.get("desc", "Vật phẩm lưu trữ trong rương Sơn Trang."))
					res_dict["sell_price"] = int(it.get("price_gold", 50))
					res_dict["is_seed"] = is_seed_val
					res_dict["is_animal"] = is_animal_val
					return res_dict

	return {
		"name": item_id.capitalize(),
		"icon": "damidai.png" if is_supply else "zhurou.png",
		"category": "Vật Tư" if is_supply else "Nông Sản",
		"desc": "Vật phẩm lưu trữ trong rương Sơn Trang.",
		"sell_price": 50
	}

# ==============================================================================
# NPC TRÙ THẦN SƠN TRANG - GIAO DIỆN ĐỔI THỊT THÚ LẤY EXP, TIỀN VÀ RƯƠNG BÁCH THÚ
# ==============================================================================

const MEAT_RECIPES := [
	{
		"id": "produce_pork",
		"name": "Thịt Heo Sạch",
		"icon": "zhurou.png",
		"source_desc": "Thu hoạch từ Heo Trắng (Khu Vật Nuôi)",
		"exp": 150000,
		"gold": 30000,
		"farm_exp": 30,
		"chest": 1
	},
	{
		"id": "produce_wild_pork",
		"name": "Thịt Heo Rừng",
		"icon": "zhurou.png",
		"source_desc": "Thu hoạch từ Heo Rừng (Khu Vật Nuôi)",
		"exp": 200000,
		"gold": 45000,
		"farm_exp": 40,
		"chest": 1
	},
	{
		"id": "produce_buffalo_meat",
		"name": "Thịt Trâu Tươi",
		"icon": "zhurou.png",
		"source_desc": "Thu hoạch từ Trâu Cày (Khu Vật Nuôi)",
		"exp": 250000,
		"gold": 60000,
		"farm_exp": 50,
		"chest": 1
	},
	{
		"id": "produce_deer_meat",
		"name": "Thịt Hươu Tươi",
		"icon": "zhurou.png",
		"source_desc": "Thu hoạch từ Hươu Sao (Khu Vật Nuôi)",
		"exp": 350000,
		"gold": 90000,
		"farm_exp": 70,
		"chest": 1
	}
]

## Mở bảng Giao Diện NPC Trù Thần: Đổi các miếng thịt thu hoạch từ chăn nuôi lấy EXP, Tiền và Rương Bách Thú
static func open_meat_exchange(parent: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root: Node = parent.get_tree().root if (parent and parent.is_inside_tree()) else (tree.root if tree else null)

	var modal_layer: CanvasLayer = null
	if root != null:
		modal_layer = root.get_node_or_null("FarmModalLayer") as CanvasLayer
		if modal_layer == null or not is_instance_valid(modal_layer):
			modal_layer = CanvasLayer.new()
			modal_layer.name = "FarmModalLayer"
			modal_layer.layer = 120
			root.add_child(modal_layer)

	var target_parent: Node = modal_layer if modal_layer != null else parent

	# Đóng cửa sổ cũ nếu đang mở
	var old = target_parent.get_node_or_null("FarmMeatExchangeWindow")
	if old != null:
		old.queue_free()

	var farm_mgr: FarmManager = null
	if root != null and root.has_node("FarmManager"):
		farm_mgr = root.get_node("FarmManager")
	elif parent != null:
		farm_mgr = parent.get_node_or_null("/root/FarmManager")

	var gm = root.get_node_or_null("GameManager") if (root and root.has_node("GameManager")) else null
	var profile: PlayerProfile = gm.local_profile if (gm and "local_profile" in gm) else null

	# Khung bao bọc
	var root_wrap := Control.new()
	root_wrap.name = "FarmMeatExchangeWindow"
	root_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_wrap.mouse_filter = Control.MOUSE_FILTER_PASS

	# Lớp nền đen mờ
	var dark_overlay := ColorRect.new()
	dark_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dark_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			root_wrap.queue_free()
	)
	root_wrap.add_child(dark_overlay)

	# Khung chính
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(620, 600)
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -310
	win.offset_right = 310
	win.offset_top = -300
	win.offset_bottom = 300
	win.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.07, 0.09, 0.98)
	bg.border_color = Color(0.85, 0.68, 0.32, 0.95)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.content_margin_left = 18
	bg.content_margin_top = 16
	bg.content_margin_right = 18
	bg.content_margin_bottom = 16
	bg.shadow_color = Color(0, 0, 0, 0.8)
	bg.shadow_size = 18
	win.add_theme_stylebox_override("panel", bg)
	root_wrap.add_child(win)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	win.add_child(vbox)

	# 1. Header
	var header := HBoxContainer.new()
	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)

	var title_lbl := Label.new()
	title_lbl.text = "🍖 TRÙ THẦN SƠN TRANG - ĐỔI THỊT LẤY BẢO RƯƠNG"
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "📍 Tọa độ 194/191 • Thu mua thịt tươi chăn nuôi: Mỗi miếng đổi lấy Lượng lớn EXP, Tiền & 1 Rương Bách Thú!"
	subtitle_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	subtitle_lbl.add_theme_font_size_override("font_size", 11)
	title_vbox.add_child(subtitle_lbl)
	header.add_child(title_vbox)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(root_wrap.queue_free)
	header.add_child(close_btn)
	vbox.add_child(header)

	# 2. Hộp thông tin bảo rương
	var chest_banner := PanelContainer.new()
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.12, 0.18, 0.24, 0.9)
	c_sb.border_color = Color(0.4, 0.75, 1.0, 0.8)
	c_sb.set_border_width_all(1)
	c_sb.set_corner_radius_all(6)
	c_sb.content_margin_left = 12
	c_sb.content_margin_top = 8
	c_sb.content_margin_right = 12
	c_sb.content_margin_bottom = 8
	chest_banner.add_theme_stylebox_override("panel", c_sb)

	var c_hbox := HBoxContainer.new()
	c_hbox.add_theme_constant_override("separation", 10)
	chest_banner.add_child(c_hbox)

	var c_icon := TextureRect.new()
	c_icon.custom_minimum_size = Vector2(40, 40)
	c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_icon.texture = load("res://assets/items/icons/item_goldenbox.png") if ResourceLoader.exists("res://assets/items/icons/item_goldenbox.png") else null
	c_hbox.add_child(c_icon)

	var c_lbl := Label.new()
	c_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_lbl.text = "🎁 [Rương Bách Thú Sơn Trang]: Mở ra chắc chắn có Đồ Trang Bị (Hoàng Kim/Xanh 4-6 dòng), Tiên Thảo Lộ, Thủy Tinh và tỷ lệ CỰC HIẾM rớt Đại Tuyệt Kỹ 180 (15 Môn Phái) & Bí Kíp 150!"
	c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_lbl.add_theme_font_size_override("font_size", 11)
	c_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	c_hbox.add_child(c_lbl)
	vbox.add_child(chest_banner)

	# 3. Danh sách cuộn các loại thịt đổi lấy thưởng
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(list_vbox)

	# Callback dựng lại danh sách khi người chơi đổi thịt
	var refresh_list: Callable
	refresh_list = func():
		for ch in list_vbox.get_children():
			ch.queue_free()

		var total_available_meat := 0

		for recipe in MEAT_RECIPES:
			var meat_id: String = recipe["id"]
			var cur_cnt: int = int(farm_mgr.farm_chest_produce.get(meat_id, 0)) if farm_mgr else 0
			total_available_meat += cur_cnt

			var row := PanelContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var r_sb := StyleBoxFlat.new()
			r_sb.bg_color = Color(0.08, 0.12, 0.15, 0.95)
			r_sb.border_color = Color(0.65, 0.52, 0.25, 0.8) if cur_cnt > 0 else Color(0.25, 0.3, 0.35, 0.5)
			r_sb.set_border_width_all(1)
			r_sb.set_corner_radius_all(6)
			r_sb.content_margin_left = 10
			r_sb.content_margin_top = 8
			r_sb.content_margin_right = 10
			r_sb.content_margin_bottom = 8
			row.add_theme_stylebox_override("panel", r_sb)

			var rhbox := HBoxContainer.new()
			rhbox.add_theme_constant_override("separation", 10)
			row.add_child(rhbox)

			# Icon thịt
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(44, 44)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_p := "res://assets/items/icons/" + str(recipe["icon"])
			if ResourceLoader.exists(icon_p):
				icon_rect.texture = load(icon_p)
			rhbox.add_child(icon_rect)

			# Thông tin công thức đổi
			var ivbox := VBoxContainer.new()
			ivbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ivbox.add_theme_constant_override("separation", 2)

			var name_row := HBoxContainer.new()
			name_row.add_theme_constant_override("separation", 8)
			var n_lbl := Label.new()
			n_lbl.text = "🥩 %s" % recipe["name"]
			n_lbl.add_theme_font_size_override("font_size", 13)
			n_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45) if cur_cnt > 0 else Color(0.7, 0.7, 0.7))
			name_row.add_child(n_lbl)

			var stock_lbl := Label.new()
			stock_lbl.text = "• Hiện có trong kho: %d miếng" % cur_cnt
			stock_lbl.add_theme_font_size_override("font_size", 11)
			stock_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.45) if cur_cnt > 0 else Color(0.85, 0.45, 0.45))
			name_row.add_child(stock_lbl)
			ivbox.add_child(name_row)

			var rwd_lbl := Label.new()
			rwd_lbl.text = "🎁 Mỗi miếng đổi: +%s EXP  •  +%s Lượng  •  +1 Rương Bách Thú  •  +%d EXP Nông Trại" % [
				_fmt(recipe["exp"]), _fmt(recipe["gold"]), recipe["farm_exp"]
			]
			rwd_lbl.add_theme_font_size_override("font_size", 11)
			rwd_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
			ivbox.add_child(rwd_lbl)

			var src_lbl := Label.new()
			src_lbl.text = str(recipe["source_desc"])
			src_lbl.add_theme_font_size_override("font_size", 10)
			src_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
			ivbox.add_child(src_lbl)

			rhbox.add_child(ivbox)

			# Cụm nút bấm Đổi
			var btn_box := VBoxContainer.new()
			btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_box.add_theme_constant_override("separation", 4)

			var exchange_action := func(count: int):
				if farm_mgr == null or profile == null:
					return
				var available: int = int(farm_mgr.farm_chest_produce.get(meat_id, 0))
				if available < count or count <= 0:
					return
				# Trừ thịt
				farm_mgr.remove_from_chest(meat_id, count, false)
				# Tặng EXP, Tiền, EXP Nông Trại
				var total_exp: int = int(recipe["exp"]) * count
				var total_gold: int = int(recipe["gold"]) * count
				var total_f_exp: int = int(recipe["farm_exp"]) * count
				profile.add_exp(total_exp)
				profile.gold = mini(PlayerProfile.MAX_GOLD, profile.gold + total_gold)
				farm_mgr.add_farm_exp(total_f_exp)

				# Tặng Rương Bách Thú Sơn Trang
				var chest_item := ItemGenerator.generate_misc("ruong_bach_thu_son_trang", 0, 0, count)
				if chest_item != null:
					profile.add_item(chest_item)

				farm_mgr.save_farm_data()

				# Hiển thị thông báo kết quả
				_show_exchange_success_popup(win, "🎉 Đổi Thành Công x%d %s!" % [count, recipe["name"]], [
					"+ %s EXP Nhân Vật" % _fmt(total_exp),
					"+ %s Ngân Lượng" % _fmt(total_gold),
					"+ %dx [Rương Bách Thú Sơn Trang] (Đã vào túi đồ)" % count,
					"+ %d EXP Nông Trại Sơn Trang" % total_f_exp
				])
				refresh_list.call()

			if cur_cnt >= 1:
				var exchange_one_btn := Button.new()
				exchange_one_btn.text = "Đổi 1 Miếng"
				exchange_one_btn.custom_minimum_size = Vector2(105, 28)
				exchange_one_btn.focus_mode = Control.FOCUS_NONE
				_apply_exchange_button_style(exchange_one_btn, Color(0.16, 0.40, 0.22, 0.95), Color(0.4, 0.85, 0.45))
				exchange_one_btn.pressed.connect(func(): exchange_action.call(1))
				btn_box.add_child(exchange_one_btn)

				if cur_cnt > 1:
					var exchange_all_btn := Button.new()
					exchange_all_btn.text = "Đổi Hết (x%d)" % cur_cnt
					exchange_all_btn.custom_minimum_size = Vector2(105, 28)
					exchange_all_btn.focus_mode = Control.FOCUS_NONE
					_apply_exchange_button_style(exchange_all_btn, Color(0.48, 0.32, 0.12, 0.95), Color(0.95, 0.75, 0.3))
					exchange_all_btn.pressed.connect(func(): exchange_action.call(cur_cnt))
					btn_box.add_child(exchange_all_btn)
			else:
				var empty_btn := Button.new()
				empty_btn.text = "Chưa Có Thịt"
				empty_btn.custom_minimum_size = Vector2(105, 30)
				empty_btn.disabled = true
				_apply_exchange_button_style(empty_btn, Color(0.18, 0.20, 0.22, 0.6), Color(0.4, 0.45, 0.5, 0.6))
				btn_box.add_child(empty_btn)

			rhbox.add_child(btn_box)
			list_vbox.add_child(row)

	refresh_list.call()

	# 4. Footer
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)

	# Nút Mở Rương Nhanh nếu người chơi đang có rương bách thú trong hành trang
	var open_chest_btn := Button.new()
	open_chest_btn.text = "🎁 Mở Rương Bách Thú Ngay"
	open_chest_btn.custom_minimum_size = Vector2(190, 34)
	open_chest_btn.focus_mode = Control.FOCUS_NONE
	_apply_exchange_button_style(open_chest_btn, Color(0.18, 0.32, 0.52, 0.95), Color(0.4, 0.8, 1.0))
	open_chest_btn.pressed.connect(func():
		if profile == null:
			return
		# Tìm rương bách thú trong hành trang
		var chest_idx := -1
		for i in range(profile.inventory.size()):
			var it = profile.inventory[i]
			if it is ItemInstance and it.misc_id == "ruong_bach_thu_son_trang":
				chest_idx = i
				break
		if chest_idx >= 0:
			var res = ItemConsumer.use_item(profile, profile.inventory[chest_idx])
			var msg: String = str(res.get("message", "Đã mở rương!"))
			_show_exchange_success_popup(win, "🎁 KẾT QUẢ MỞ RƯƠNG", [msg])
		else:
			_show_exchange_success_popup(win, "⚠️ Chưa Có Rương Bách Thú", [
				"Bạn hiện chưa có [Rương Bách Thú Sơn Trang] trong hành trang!",
				"Hãy đổi các miếng thịt chăn nuôi ở trên để nhận rương nhé."
			])
	)
	footer.add_child(open_chest_btn)

	var close_bottom_btn := Button.new()
	close_bottom_btn.text = "Đóng"
	close_bottom_btn.custom_minimum_size = Vector2(90, 34)
	_apply_exchange_button_style(close_bottom_btn, Color(0.2, 0.22, 0.25, 0.9), Color(0.6, 0.65, 0.7))
	close_bottom_btn.pressed.connect(root_wrap.queue_free)
	footer.add_child(close_bottom_btn)

	vbox.add_child(footer)
	target_parent.add_child(root_wrap)

static func _apply_exchange_button_style(btn: Button, bg_col: Color, border_col: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = border_col
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg_col.lightened(0.15)
	hover.border_color = border_col.lightened(0.2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	btn.add_theme_font_size_override("font_size", 11)

static func _show_exchange_success_popup(parent: Node, title: String, lines: Array) -> void:
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(380, 200)
	popup.anchor_left = 0.5
	popup.anchor_right = 0.5
	popup.anchor_top = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -190
	popup.offset_right = 190
	popup.offset_top = -100
	popup.offset_bottom = 100
	popup.z_index = 50

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.08, 0.12, 0.98)
	bg.border_color = Color(1.0, 0.85, 0.35)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 14
	bg.content_margin_top = 12
	bg.content_margin_right = 14
	bg.content_margin_bottom = 12
	popup.add_theme_stylebox_override("panel", bg)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	popup.add_child(vb)

	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vb.add_child(t_lbl)

	for l in lines:
		var lbl := Label.new()
		lbl.text = str(l)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		vb.add_child(lbl)

	var ok_btn := Button.new()
	ok_btn.text = "Xác Nhận"
	ok_btn.custom_minimum_size = Vector2(90, 28)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_exchange_button_style(ok_btn, Color(0.18, 0.38, 0.24), Color(0.4, 0.85, 0.45))
	ok_btn.pressed.connect(popup.queue_free)
	vb.add_child(ok_btn)

	parent.add_child(popup)

static func _fmt(n: int) -> String:
	var s := str(n)
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0 and s[i - 1] != "-":
			res = "." + res
	return res
