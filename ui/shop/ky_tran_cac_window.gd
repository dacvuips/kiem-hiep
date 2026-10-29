extends SocialWindow
class_name KyTranCacWindow

const KyTranCacShop = preload("res://systems/items/ky_tran_cac_shop.gd")

## KỲ TRÂN CÁC (Kỳ Trân Các / Cash Shop - Chuẩn giao diện VLTK 1):
## Tái hiện 100% giao diện Kỳ Trân Các kinh điển từ ảnh mẫu:
##   - Thanh tiêu đề: "Kỳ Trân Các" kèm nút đóng ✕
##   - 2 Tab chính: "Vật Phẩm" và "Tính Năng" (chọn tab có viền & chữ xanh ngọc/xanh lá sáng)
##   - Thanh điều khiển: Nút "Nạp" (mở Tiền Trang), nút "Trước", số trang (1/2, 2/2, 1/1), "Trang kế", "Giỏ Hàng"
##   - Khung lưới 15 ô (3 cột x 5 hàng):
##       + Mỗi ô hiển thị Icon vật phẩm, Tên, Giá gốc, Giá thực (tính bằng Xu) và nút "Mua"
##       + Các ô trống hiển thị khung tối chuẩn như bản gốc
##   - Hỗ trợ Mua ngay, Mua theo số lượng tuỳ chọn, Thêm vào Giỏ Hàng và Thanh toán Giỏ Hàng.

var _host: Node
var _profile: PlayerProfile
var _on_changed: Callable

var _active_tab: int = 0
var _current_page: int = 0

var _tab_vat_pham: Button
var _tab_tinh_nang: Button
var _btn_nap: Button
var _btn_prev: Button
var _btn_next: Button
var _btn_cart: Button
var _page_label: Label
var _xu_label: Label
var _grid_container: GridContainer
var _toast_label: Label

static func open(host: Node, on_changed: Callable = Callable(), profile: PlayerProfile = null) -> Control:
	var script: GDScript = load("res://ui/shop/ky_tran_cac_window.gd") as GDScript
	var win = script.new()
	win._host = host
	win._on_changed = on_changed
	win._profile = profile
	if win._profile == null and host != null and "_profile" in host:
		win._profile = host.get("_profile") as PlayerProfile
	if win._profile == null:
		var tree := host.get_tree() if host != null and host.is_inside_tree() else Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null and tree.root.has_node("GameManager"):
			win._profile = tree.root.get_node("GameManager").get("local_profile") as PlayerProfile
	win._refresh_ui()
	return SocialWindow.present(host, win, &"ky_tran_cac")

func _init() -> void:
	super._init("Kỳ Trân Các", "", 716.0)
	custom_minimum_size = Vector2(716, 545)
	_build_ui()
	_refresh_ui()
	GmManager.profile_modified.connect(func(p: PlayerProfile) -> void:
		if p == null or p == _profile or p == GameManager.local_profile:
			_refresh_ui()
	)

func _build_ui() -> void:
	body.add_theme_constant_override("separation", 6)

	# 1. Hàng chứa 2 Tab: "Vật Phẩm" | "Tính Năng"
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	body.add_child(tab_row)

	_tab_vat_pham = _create_tab_button(tr("Vật Phẩm"), 0)
	tab_row.add_child(_tab_vat_pham)

	_tab_tinh_nang = _create_tab_button(tr("Tính Năng"), 1)
	tab_row.add_child(_tab_tinh_nang)

	var tab_spacer := Control.new()
	tab_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(tab_spacer)

	# 2. Thanh điều khiển: Nút "Nạp" bên trái, hiển thị Xu + nút Trước / Trang / Trang kế / Giỏ hàng bên phải
	var control_bar := HBoxContainer.new()
	control_bar.add_theme_constant_override("separation", 8)
	body.add_child(control_bar)

	_btn_nap = _create_action_button(tr("Nạp"), Vector2(72, 28))
	_btn_nap.pressed.connect(_on_nap_pressed)
	control_bar.add_child(_btn_nap)

	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_bar.add_child(mid_spacer)

	_xu_label = Label.new()
	_xu_label.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
	_xu_label.add_theme_font_size_override("font_size", 13)
	_xu_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	control_bar.add_child(_xu_label)

	_btn_prev = _create_action_button(tr("Trước"), Vector2(62, 28))
	_btn_prev.pressed.connect(_on_prev_page)
	control_bar.add_child(_btn_prev)

	_page_label = Label.new()
	_page_label.text = "1/1"
	_page_label.custom_minimum_size = Vector2(48, 28)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	_page_label.add_theme_font_size_override("font_size", 13)
	control_bar.add_child(_page_label)

	_btn_next = _create_action_button(tr("Trang kế"), Vector2(72, 28))
	_btn_next.pressed.connect(_on_next_page)
	control_bar.add_child(_btn_next)

	_btn_cart = _create_action_button(tr("Giỏ Hàng"), Vector2(80, 28))
	_btn_cart.pressed.connect(_open_cart_dialog)
	control_bar.add_child(_btn_cart)

	# 3. Lưới 15 ô vật phẩm (3 cột x 5 hàng)
	var grid_panel := PanelContainer.new()
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color(0.06, 0.07, 0.065, 0.96)
	panel_box.border_width_left = 1
	panel_box.border_width_top = 1
	panel_box.border_width_right = 1
	panel_box.border_width_bottom = 1
	panel_box.border_color = Color(0.24, 0.25, 0.22, 0.9)
	panel_box.set_corner_radius_all(4)
	panel_box.content_margin_left = 6
	panel_box.content_margin_top = 6
	panel_box.content_margin_right = 6
	panel_box.content_margin_bottom = 6
	grid_panel.add_theme_stylebox_override("panel", panel_box)
	body.add_child(grid_panel)

	_grid_container = GridContainer.new()
	_grid_container.columns = 3
	_grid_container.add_theme_constant_override("h_separation", 6)
	_grid_container.add_theme_constant_override("v_separation", 6)
	_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_panel.add_child(_grid_container)

	# Thông báo toast phía đáy
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_color", GameUi.WARN)
	_toast_label.add_theme_font_size_override("font_size", 12)
	body.add_child(_toast_label)

func _create_tab_button(label_text: String, tab_idx: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(88, 28)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_switch_tab.bind(tab_idx))
	return btn

func _create_action_button(label_text: String, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.16, 0.17, 0.16, 0.95)
	normal_box.border_width_left = 1
	normal_box.border_width_top = 1
	normal_box.border_width_right = 1
	normal_box.border_width_bottom = 1
	normal_box.border_color = Color(0.48, 0.46, 0.40, 0.95)
	normal_box.set_corner_radius_all(3)
	normal_box.content_margin_left = 6
	normal_box.content_margin_right = 6

	var hover_box := StyleBoxFlat.new()
	hover_box.bg_color = Color(0.24, 0.25, 0.22, 0.98)
	hover_box.border_width_left = 1
	hover_box.border_width_top = 1
	hover_box.border_width_right = 1
	hover_box.border_width_bottom = 1
	hover_box.border_color = Color(0.85, 0.78, 0.52, 1.0)
	hover_box.set_corner_radius_all(3)
	hover_box.content_margin_left = 6
	hover_box.content_margin_right = 6

	btn.add_theme_stylebox_override("normal", normal_box)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", hover_box)
	btn.add_theme_stylebox_override("focus", normal_box)
	btn.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7))
	btn.add_theme_font_size_override("font_size", 13)
	return btn

func _update_tab_styles() -> void:
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.08, 0.15, 0.10, 0.95)
	active_style.border_width_left = 1
	active_style.border_width_top = 1
	active_style.border_width_right = 1
	active_style.border_width_bottom = 1
	active_style.border_color = Color(0.28, 0.88, 0.45, 1.0)
	active_style.set_corner_radius_all(3)
	active_style.content_margin_left = 8
	active_style.content_margin_right = 8

	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.12, 0.13, 0.12, 0.9)
	inactive_style.border_width_left = 1
	inactive_style.border_width_top = 1
	inactive_style.border_width_right = 1
	inactive_style.border_width_bottom = 1
	inactive_style.border_color = Color(0.35, 0.35, 0.32, 0.8)
	inactive_style.set_corner_radius_all(3)
	inactive_style.content_margin_left = 8
	inactive_style.content_margin_right = 8

	var tabs := [_tab_vat_pham, _tab_tinh_nang]
	for i in tabs.size():
		var t: Button = tabs[i]
		if i == _active_tab:
			t.add_theme_stylebox_override("normal", active_style)
			t.add_theme_stylebox_override("hover", active_style)
			t.add_theme_stylebox_override("pressed", active_style)
			t.add_theme_stylebox_override("focus", active_style)
			t.add_theme_color_override("font_color", Color(0.32, 0.95, 0.48))
		else:
			t.add_theme_stylebox_override("normal", inactive_style)
			t.add_theme_stylebox_override("hover", inactive_style)
			t.add_theme_stylebox_override("pressed", inactive_style)
			t.add_theme_stylebox_override("focus", inactive_style)
			t.add_theme_color_override("font_color", Color(0.70, 0.70, 0.68))

func _switch_tab(tab_idx: int) -> void:
	if _active_tab == tab_idx:
		return
	_active_tab = tab_idx
	_current_page = 0
	_refresh_ui()

func _on_prev_page() -> void:
	var total_pages := KyTranCacShop.get_page_count(_active_tab)
	if _current_page > 0:
		_current_page -= 1
		_refresh_ui()

func _on_next_page() -> void:
	var total_pages := KyTranCacShop.get_page_count(_active_tab)
	if _current_page < total_pages - 1:
		_current_page += 1
		_refresh_ui()

func _notify_changed() -> void:
	if _on_changed != null and _on_changed.is_valid():
		_on_changed.call()
	if _host != null and is_instance_valid(_host):
		if _host.has_method("_refresh_inventory_view"):
			_host.call("_refresh_inventory_view")
		if _host.has_method("refresh"):
			_host.call("refresh")
		if _host.has_method("_on_panel_profile_changed"):
			_host.call("_on_panel_profile_changed")
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		var inv: Node = tree.root.find_child("InventoryPopup", true, false)
		if inv and is_instance_valid(inv) and inv.has_method("_refresh"):
			inv.call("_refresh")
		var hub: Node = tree.root.find_child("CharacterHub", true, false)
		if hub and is_instance_valid(hub) and hub.has_method("_refresh_inventory_view"):
			hub.call("_refresh_inventory_view")

func _on_nap_pressed() -> void:
	TienTrangWindow.open(_host, func() -> void:
		_refresh_ui()
		_notify_changed()
	, _get_active_profile())

func _get_active_profile() -> PlayerProfile:
	if _profile != null:
		return _profile
	if _host != null and "_profile" in _host and _host.get("_profile") != null:
		return _host.get("_profile") as PlayerProfile
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager").get("local_profile") as PlayerProfile
	return null

func _refresh_ui() -> void:
	_update_tab_styles()
	var p := _get_active_profile()
	var xu_val: int = p.xu if p else 0
	_xu_label.text = "%s: %d %s" % [tr("Tiền Xu"), xu_val, tr("Xu")]

	var total_pages := KyTranCacShop.get_page_count(_active_tab)
	_current_page = clampi(_current_page, 0, maxi(0, total_pages - 1))
	_page_label.text = "%d/%d" % [_current_page + 1, total_pages]
	_btn_prev.disabled = (_current_page <= 0)
	_btn_next.disabled = (_current_page >= total_pages - 1)

	var cart_cnt := KyTranCacShop.get_cart_count()
	_btn_cart.text = ("%s (%d)" % [tr("Giỏ Hàng"), cart_cnt]) if cart_cnt > 0 else tr("Giỏ Hàng")
	_btn_prev.text = tr("Trước")
	_btn_next.text = tr("Trang kế")
	_btn_nap.text = tr("Nạp")
	_tab_vat_pham.text = tr("Vật Phẩm")
	_tab_tinh_nang.text = tr("Tính Năng")

	_build_grid_items()

func _build_grid_items() -> void:
	for c in _grid_container.get_children():
		c.queue_free()

	var items := KyTranCacShop.get_items_for_page(_active_tab, _current_page)
	for i in KyTranCacShop.SLOTS_PER_PAGE:
		if i < items.size():
			var item_card := _create_item_card(items[i])
			_grid_container.add_child(item_card)
		else:
			var empty_card := _create_empty_card()
			_grid_container.add_child(empty_card)

## Tạo 1 thẻ chứa thông tin vật phẩm: Icon bên trái, Tên + Giá gốc + Giá thực + Nút Mua bên phải
func _create_item_card(it_data: Dictionary) -> PanelContainer:
	var item_id: String = str(it_data.get("id", ""))
	var item_name: String = str(it_data.get("name", ""))
	var price_orig: int = int(it_data.get("price_original", 0))
	var price_real: int = int(it_data.get("price", 0))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(226, 76)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.13, 0.12, 0.95)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.32, 0.31, 0.28, 0.9)
	card_style.set_corner_radius_all(3)
	card_style.content_margin_left = 6
	card_style.content_margin_top = 4
	card_style.content_margin_right = 6
	card_style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	# Khung Icon
	var icon_slot := PanelContainer.new()
	icon_slot.custom_minimum_size = Vector2(48, 48)
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_box := StyleBoxFlat.new()
	icon_box.bg_color = Color(0.04, 0.05, 0.04, 0.98)
	icon_box.border_width_left = 1
	icon_box.border_width_top = 1
	icon_box.border_width_right = 1
	icon_box.border_width_bottom = 1
	icon_box.border_color = Color(0.42, 0.38, 0.28, 0.8)
	icon_box.set_corner_radius_all(2)
	icon_slot.add_theme_stylebox_override("panel", icon_box)

	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var item_record := ItemDatabase.get_misc(item_id)
	tex_rect.texture = ItemDatabase.get_icon(item_record)
	icon_slot.add_child(tex_rect)
	hbox.add_child(icon_slot)

	# Tooltip mô tả vật phẩm
	var intro_text: String = str(item_record.get("intro", ""))
	if intro_text != "":
		card.tooltip_text = "%s\n%s" % [item_name, ItemText.plain(ItemText.clean_vltk_tags(intro_text))]

	# Cột thông tin chi tiết
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# Tên vật phẩm
	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(name_lbl)

	# Giá gốc
	var price_orig_row := HBoxContainer.new()
	price_orig_row.add_theme_constant_override("separation", 4)
	var lbl_po := Label.new()
	lbl_po.text = tr("Giá gốc:")
	lbl_po.add_theme_font_size_override("font_size", 11)
	lbl_po.add_theme_color_override("font_color", Color(0.65, 0.65, 0.62))
	price_orig_row.add_child(lbl_po)

	var val_po := Label.new()
	val_po.text = "%d %s" % [price_orig, tr("Xu")]
	val_po.add_theme_font_size_override("font_size", 11)
	val_po.add_theme_color_override("font_color", Color(0.45, 0.82, 0.95))
	price_orig_row.add_child(val_po)
	vbox.add_child(price_orig_row)

	# Giá thực + Nút Mua
	var price_real_row := HBoxContainer.new()
	price_real_row.add_theme_constant_override("separation", 4)
	var lbl_pr := Label.new()
	lbl_pr.text = tr("Giá thực:")
	lbl_pr.add_theme_font_size_override("font_size", 11)
	lbl_pr.add_theme_color_override("font_color", Color(0.65, 0.65, 0.62))
	price_real_row.add_child(lbl_pr)

	var val_pr := Label.new()
	val_pr.text = "%d %s" % [price_real, tr("Xu")]
	val_pr.add_theme_font_size_override("font_size", 11)
	val_pr.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	price_real_row.add_child(val_pr)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_real_row.add_child(spacer)

	var buy_btn := _create_action_button(tr("Mua"), Vector2(48, 22))
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.pressed.connect(_open_buy_dialog.bind(it_data))
	price_real_row.add_child(buy_btn)

	vbox.add_child(price_real_row)

	return card

## Tạo 1 thẻ ô trống (như trong ảnh mẫu khi hết vật phẩm)
func _create_empty_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(226, 76)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.09, 0.10, 0.09, 0.9)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.22, 0.22, 0.20, 0.7)
	card_style.set_corner_radius_all(3)
	card_style.content_margin_left = 6
	card_style.content_margin_top = 4
	card_style.content_margin_right = 6
	card_style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var empty_slot := PanelContainer.new()
	empty_slot.custom_minimum_size = Vector2(48, 48)
	empty_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.04, 0.04, 0.04, 0.8)
	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.border_color = Color(0.18, 0.18, 0.18, 0.6)
	slot_style.set_corner_radius_all(2)
	empty_slot.add_theme_stylebox_override("panel", slot_style)
	hbox.add_child(empty_slot)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vbox)

	var placeholder := Label.new()
	placeholder.text = ""
	vbox.add_child(placeholder)

	var btn_ghost := _create_action_button(tr("Mua"), Vector2(48, 22))
	btn_ghost.disabled = true
	btn_ghost.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_ghost.modulate = Color(0.5, 0.5, 0.5, 0.3)
	vbox.add_child(btn_ghost)

	return card

# ================= HỘP MUA VẬT PHẨM (BUY DIALOG) =================
func _open_buy_dialog(it_data: Dictionary) -> void:
	var item_id: String = str(it_data.get("id", ""))
	var item_name: String = str(it_data.get("name", ""))
	var price_real: int = int(it_data.get("price", 0))

	var item_rec := ItemDatabase.get_misc(item_id)
	var win := SocialWindow.new("%s: %s" % [tr("Mua"), item_name], "", 380.0)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(50, 50)
	var ibs := StyleBoxFlat.new()
	ibs.bg_color = Color(0.05, 0.05, 0.05)
	ibs.set_border_width_all(1)
	ibs.border_color = Color(0.4, 0.38, 0.3)
	ibs.set_corner_radius_all(3)
	icon_box.add_theme_stylebox_override("panel", ibs)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ItemDatabase.get_icon(item_rec)
	icon_box.add_child(icon)
	head.add_child(icon_box)

	var intro := Label.new()
	intro.text = ItemText.plain(ItemText.clean_vltk_tags(str(item_rec.get("intro", ""))))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	head.add_child(intro)
	win.body.add_child(head)

	var p := _get_active_profile()
	var cur_xu: int = p.xu if p else 0

	var info_h := HBoxContainer.new()
	var price_lbl := Label.new()
	price_lbl.text = "%s: %d %s" % [tr("Đơn giá"), price_real, tr("Xu")]
	price_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
	price_lbl.add_theme_font_size_override("font_size", 13)
	price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_h.add_child(price_lbl)

	var have_lbl := Label.new()
	have_lbl.text = "%s: %d %s" % [tr("Hiện có"), cur_xu, tr("Xu")]
	have_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	have_lbl.add_theme_font_size_override("font_size", 13)
	info_h.add_child(have_lbl)
	win.body.add_child(info_h)

	# Điều khiển số lượng mua
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)

	var count_title := Label.new()
	count_title.text = tr("Số lượng:")
	count_title.add_theme_font_size_override("font_size", 13)
	row.add_child(count_title)

	var btn_minus := SocialUi.small_button("−")
	btn_minus.custom_minimum_size = Vector2(32, 28)
	row.add_child(btn_minus)

	var qty_input := SocialUi.line_edit("1")
	qty_input.text = "1"
	qty_input.custom_minimum_size = Vector2(60, 28)
	qty_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_input.max_length = 3
	row.add_child(qty_input)

	var btn_plus := SocialUi.small_button("+")
	btn_plus.custom_minimum_size = Vector2(32, 28)
	row.add_child(btn_plus)

	win.body.add_child(row)

	# Các nút tăng nhanh: +1, +5, +10, Tối đa
	var quick_row := HBoxContainer.new()
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.add_theme_constant_override("separation", 6)
	for q in [1, 5, 10]:
		var q_btn := SocialUi.small_button("+%d" % q)
		q_btn.pressed.connect(func() -> void:
			var cur := int(qty_input.text) if qty_input.text.is_valid_int() else 1
			qty_input.text = str(clampi(cur + q, 1, 99))
			qty_input.text_changed.emit(qty_input.text)
		)
		quick_row.add_child(q_btn)

	var max_btn := SocialUi.small_button(tr("Tối đa"))
	max_btn.pressed.connect(func() -> void:
		var max_affordable := cur_xu / maxi(1, price_real)
		qty_input.text = str(clampi(max_affordable, 1, 99))
		qty_input.text_changed.emit(qty_input.text)
	)
	quick_row.add_child(max_btn)
	win.body.add_child(quick_row)

	var total_lbl := Label.new()
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.add_theme_font_size_override("font_size", 15)
	total_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	win.body.add_child(total_lbl)

	var err_label := Label.new()
	err_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err_label.add_theme_color_override("font_color", GameUi.WARN)
	err_label.add_theme_font_size_override("font_size", 12)
	win.body.add_child(err_label)

	var update_total := func() -> void:
		var t := qty_input.text.strip_edges()
		var n: int = clampi(int(t) if t.is_valid_int() else 1, 1, 99)
		var tot: int = n * price_real
		total_lbl.text = "%s: %d %s" % [tr("Tổng thanh toán"), tot, tr("Xu")]
		if tot > cur_xu:
			err_label.text = "%s (%s %d %s). %s" % [tr("Không đủ Tiền Xu"), tr("thiếu"), tot - cur_xu, tr("Xu"), tr("Nhấn 'Nạp' để nạp thêm.")]
		else:
			err_label.text = ""

	qty_input.text_changed.connect(func(_t: String) -> void: update_total.call())
	btn_minus.pressed.connect(func() -> void:
		var t := qty_input.text.strip_edges()
		var cur_n: int = clampi(int(t) if t.is_valid_int() else 1, 1, 99)
		qty_input.text = str(maxi(1, cur_n - 1))
		update_total.call()
	)
	btn_plus.pressed.connect(func() -> void:
		var t := qty_input.text.strip_edges()
		var cur_n: int = clampi(int(t) if t.is_valid_int() else 1, 1, 99)
		qty_input.text = str(mini(99, cur_n + 1))
		update_total.call()
	)
	update_total.call()

	# Hàng nút thao tác: "Mua ngay" | "Thêm vào giỏ" | "Huỷ"
	var btn_row := win.add_button_row()

	var buy_btn := SocialUi.stone_button(tr("Mua ngay"))
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.pressed.connect(func() -> void:
		var t := qty_input.text.strip_edges()
		var n: int = clampi(int(t) if t.is_valid_int() else 1, 1, 99)
		var res: Dictionary = KyTranCacShop.buy_item(_get_active_profile(), item_id, n, price_real, item_name)
		if res.get("ok", false):
			var p_act := _get_active_profile()
			var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
			if p_act and tree and tree.root.has_node("SaveManager"):
				tree.root.get_node("SaveManager").call("save_profile", p_act)
			win.close_requested.emit()
			_toast(str(res.get("message", "Mua thành công!")))
			_refresh_ui()
			_notify_changed()
		else:
			err_label.text = str(res.get("message", "Mua thất bại."))
	)
	btn_row.add_child(buy_btn)

	var cart_btn := SocialUi.stone_button(tr("Thêm vào giỏ"))
	cart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_btn.pressed.connect(func() -> void:
		var t := qty_input.text.strip_edges()
		var n: int = clampi(int(t) if t.is_valid_int() else 1, 1, 99)
		KyTranCacShop.add_to_cart(item_id, item_name, price_real, n)
		win.close_requested.emit()
		_toast("Đã thêm %d x %s vào Giỏ Hàng." % [n, item_name])
		_refresh_ui()
	)
	btn_row.add_child(cart_btn)

	var cancel_btn := SocialUi.stone_button(tr("Huỷ"))
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func() -> void: win.close_requested.emit())
	btn_row.add_child(cancel_btn)

	SocialWindow.present(self, win, &"ky_tran_cac_buy")

# ================= HỘP GIỎ HÀNG (CART DIALOG) =================
func _open_cart_dialog() -> void:
	var win := SocialWindow.new(tr("Giỏ Hàng Kỳ Trân Các"), "", 460.0)

	var cart := KyTranCacShop.get_cart()
	if cart.is_empty():
		win.body.add_child(SocialUi.label(tr("Giỏ hàng của bạn đang trống."), SocialUi.MUTED, 14, HORIZONTAL_ALIGNMENT_CENTER))
		var close_btn := SocialUi.stone_button(tr("Đóng"))
		close_btn.pressed.connect(func() -> void: win.close_requested.emit())
		win.body.add_child(close_btn)
		SocialWindow.present(self, win, &"ky_tran_cac_cart")
		return

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.body.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(list_box)

	var p := _get_active_profile()
	var cur_xu: int = p.xu if p else 0

	var total_lbl := Label.new()
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.add_theme_font_size_override("font_size", 15)
	total_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	win.body.add_child(total_lbl)

	_populate_cart_items(win, list_box, total_lbl, cur_xu)

	var err_lbl := Label.new()
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err_lbl.add_theme_color_override("font_color", GameUi.WARN)
	err_lbl.add_theme_font_size_override("font_size", 12)
	win.body.add_child(err_lbl)

	var btn_row := win.add_button_row()

	var checkout_btn := SocialUi.stone_button(tr("Thanh toán tất cả"))
	checkout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkout_btn.pressed.connect(func() -> void:
		var res: Dictionary = KyTranCacShop.buy_cart(_get_active_profile())
		if res.get("ok", false):
			var p_act := _get_active_profile()
			var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
			if p_act and tree and tree.root.has_node("SaveManager"):
				tree.root.get_node("SaveManager").call("save_profile", p_act)
			win.close_requested.emit()
			_toast(str(res.get("message", "Thanh toán giỏ hàng thành công!")))
			_refresh_ui()
			_notify_changed()
		else:
			err_lbl.text = str(res.get("message", "Thanh toán thất bại."))
	)
	btn_row.add_child(checkout_btn)

	var clear_btn := SocialUi.stone_button(tr("Xóa giỏ"))
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(func() -> void:
		KyTranCacShop.clear_cart()
		win.close_requested.emit()
		_refresh_ui()
		_toast("Đã xoá sạch giỏ hàng.")
	)
	btn_row.add_child(clear_btn)

	var close_btn := SocialUi.stone_button(tr("Đóng"))
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void: win.close_requested.emit())
	btn_row.add_child(close_btn)

	SocialWindow.present(self, win, &"ky_tran_cac_cart")
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void: win.close_requested.emit())
	btn_row.add_child(close_btn)

	SocialWindow.present(self, win, &"ky_tran_cac_cart")

func _populate_cart_items(win: SocialWindow, list_box: VBoxContainer, total_lbl: Label, cur_xu: int) -> void:
	for c in list_box.get_children():
		c.queue_free()

	var cur_cart := KyTranCacShop.get_cart()
	if cur_cart.is_empty():
		win.close_requested.emit()
		_refresh_ui()
		return

	for it in cur_cart:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var name_l := Label.new()
		name_l.text = str(it.get("name", ""))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_font_size_override("font_size", 13)
		row.add_child(name_l)

		var p_l := Label.new()
		p_l.text = "%d Xu" % int(it.get("price", 0))
		p_l.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
		p_l.add_theme_font_size_override("font_size", 12)
		row.add_child(p_l)

		var minus := SocialUi.small_button("−")
		var it_id: String = str(it.get("id", ""))
		var it_cnt: int = int(it.get("count", 1))
		minus.pressed.connect(func() -> void:
			KyTranCacShop.update_cart_item_count(it_id, it_cnt - 1)
			_populate_cart_items(win, list_box, total_lbl, cur_xu)
			_refresh_ui()
		)
		row.add_child(minus)

		var cnt_l := Label.new()
		cnt_l.text = "%d" % it_cnt
		cnt_l.custom_minimum_size = Vector2(28, 0)
		cnt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cnt_l)

		var plus := SocialUi.small_button("+")
		plus.pressed.connect(func() -> void:
			KyTranCacShop.update_cart_item_count(it_id, it_cnt + 1)
			_populate_cart_items(win, list_box, total_lbl, cur_xu)
			_refresh_ui()
		)
		row.add_child(plus)

		var del_btn := SocialUi.small_button("✕")
		del_btn.pressed.connect(func() -> void:
			KyTranCacShop.remove_from_cart(it_id)
			_populate_cart_items(win, list_box, total_lbl, cur_xu)
			_refresh_ui()
		)
		row.add_child(del_btn)

		list_box.add_child(row)

	total_lbl.text = "Tổng giỏ hàng: %d Xu  |  Hiện có: %d Xu" % [KyTranCacShop.get_cart_total(), cur_xu]

func _toast(msg: String) -> void:
	if is_instance_valid(_toast_label):
		_toast_label.text = msg
	if is_instance_valid(_host) and _host.has_method("_show_toast"):
		_host.call("_show_toast", msg)
