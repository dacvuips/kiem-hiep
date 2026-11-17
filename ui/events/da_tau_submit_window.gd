extends SocialWindow
class_name DaTauSubmitWindow

const DaTauManager = preload("res://systems/quest/da_tau_manager.gd")
const ItemContainerScript = preload("res://systems/social/item_container.gd")

## Cửa sổ nộp vật phẩm / xem trang bị Dã Tẩu
## - Kích thước rương nộp: dài 10 ô × cao 6 ô (10 x 6 cells) chuẩn VLTK
## - Người chơi tự tay chọn món đặt vào rương rồi mới bấm xác nhận
## - Cảnh báo MÀU ĐỎ NỔI BẬT cho nhiệm vụ thu hồi đồ (Type 2) để tránh nộp nhầm món đồ quý có cùng thuộc tính
## - An toàn 100%: nếu đóng hoặc hủy, mọi món đồ trong rương tự động hoàn trả về hành trang

var _profile: PlayerProfile
var _quest: Dictionary
var _qtype: int = 2
var _on_submitted: Callable
var _chest_container: ItemContainer
var _chest_view: ItemRoomView
var _bag_view: ItemRoomView
var _bag: int = 0
var _bag_tabs: Array[Button] = []
var _cell: int = 36
var _msg_label: Label
var _confirm_btn: Button
var _submitted: bool = false

static func open(host: Node, profile: PlayerProfile, quest: Dictionary, on_submitted: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/events/da_tau_submit_window.gd")
	var win: SocialWindow = script.new(profile, quest, on_submitted)
	var presented: SocialWindow = SocialWindow.present(host, win, &"da_tau_submit")
	# Đảm bảo hiển thị trên cùng
	if presented.get_parent() is CanvasLayer:
		(presented.get_parent() as CanvasLayer).layer = DraggableWindow.WINDOW_LAYER + 5
	return win

func _init(profile: PlayerProfile = null, quest: Dictionary = {}, on_submitted: Callable = Callable()) -> void:
	_profile = profile
	_quest = quest
	_qtype = int(_quest.get("type", 2))
	_on_submitted = on_submitted

	var title_str := "Dã Tẩu — Nộp Vật Phẩm" if _qtype == 2 else "Dã Tẩu — Cho Xem Trang Bị"
	var sub_str := "Rương nộp đồ dài 10 ô × cao 6 ô"
	super._init(title_str, sub_str, 840.0)

	# Tạo container rương nộp: DÀI 10 Ô × CAO 6 Ô
	_chest_container = ItemContainer.new(10, 6, 1)

	# Kết nối sự kiện đóng cửa sổ -> hoàn trả đồ an toàn nếu chưa xác nhận
	close_requested.connect(func() -> void:
		if not _submitted:
			_return_all_chest_items_to_bag()
			if _profile != null:
				SaveManager.save_profile(_profile, true)
	)

	_build_ui()

func _build_ui() -> void:
	# 1. BANNER CẢNH BÁO
	_build_warning_banner()

	# 2. KHU VỰC CHÍNH: 2 CỘT (Cột trái: Rương nộp 10x6, Cột phải: Hành trang)
	var main_cols := HBoxContainer.new()
	main_cols.add_theme_constant_override("separation", 14)
	main_cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(main_cols)

	# --- CỘT TRÁI: RƯƠNG NỘP ĐỒ (10 x 6 Ô) ---
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_cols.add_child(left_col)

	var chest_section_title := "📦 RƯƠNG NỘP CHO DÃ TẨU (10 × 6 Ô)" if _qtype == 2 else "🔍 RƯƠNG CHO DÃ TẨU XEM (10 × 6 Ô)"
	var chest_box := SocialUi.section(chest_section_title)
	left_col.add_child(chest_box[0])

	var req_lbl := SocialUi.label("Yêu cầu: %s" % str(_quest.get("desc", "")), SocialUi.TITLE, 13)
	req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req_lbl.add_theme_color_override("font_color", WuxiaStyle.COLOR_TEXT_GOLD)
	chest_box[1].add_child(req_lbl)

	# Khung hiển thị rương 10x6
	var chest_panel := PanelContainer.new()
	var chest_style := StyleBoxFlat.new()
	chest_style.bg_color = Color(0.04, 0.04, 0.03, 0.95)
	chest_style.border_color = Color(0.8, 0.65, 0.3, 0.8)
	chest_style.set_border_width_all(2)
	chest_style.set_content_margin_all(4)
	chest_panel.add_theme_stylebox_override("panel", chest_style)
	chest_box[1].add_child(chest_panel)

	_chest_view = ItemRoomView.new()
	_chest_view.cell = _cell
	_chest_view.setup(_chest_container, _profile)
	_chest_view.transfer_handler = _transfer_handler
	_chest_view.item_pressed.connect(_on_chest_item_pressed)
	chest_panel.add_child(_chest_view)

	var hint_lbl := SocialUi.label("💡 Bấm hoặc kéo thả vật phẩm để chuyển giữa Rương và Hành trang.", SocialUi.MUTED, 11)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chest_box[1].add_child(hint_lbl)

	# --- CỘT PHẢI: HÀNH TRANG CỦA BẠN ---
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_cols.add_child(right_col)

	var bag_box := SocialUi.section("🎒 HÀNH TRANG CỦA BẠN")
	right_col.add_child(bag_box[0])

	# Tabs chuyển túi hành trang
	var bag_tabs_bar := HBoxContainer.new()
	bag_tabs_bar.add_theme_constant_override("separation", 6)
	bag_tabs_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_box[1].add_child(bag_tabs_bar)

	var num_bags: int = mini(3, PlayerProfile.OPEN_BAGS)
	for i in num_bags:
		var b := GameUi.button("Túi %d" % (i + 1), GameUi.TAB)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 30)
		b.pressed.connect(func() -> void:
			_bag = i
			_select_bag_tab(i)
		)
		bag_tabs_bar.add_child(b)
		_bag_tabs.append(b)
	_select_bag_tab(0)

	# Khung cuộn túi hành trang
	var bag_scroll := ScrollContainer.new()
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	bag_scroll.custom_minimum_size = Vector2(_profile.ROOM_WIDTH * _cell + 10, 6 * _cell + 10)
	bag_box[1].add_child(bag_scroll)

	_bag_view = ItemRoomView.new()
	_bag_view.cell = _cell
	_bag_view.setup(_profile)
	_bag_view.transfer_handler = _transfer_handler
	_bag_view.item_pressed.connect(_on_bag_item_pressed)
	bag_scroll.add_child(_bag_view)

	# 3. DÒNG THÔNG BÁO TRẠNG THÁI / KẾT QUẢ KIỂM TRA
	_msg_label = SocialUi.label("", SocialUi.WARN, 13, HORIZONTAL_ALIGNMENT_CENTER)
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_msg_label)

	# 4. HÀNG NÚT THAO TÁC
	var btn_row := add_button_row()

	var confirm_title := "✅ XÁC NHẬN NỘP VẬT PHẨM" if _qtype == 2 else "✅ XÁC NHẬN CHO DÃ TẨU XEM"
	_confirm_btn = SocialUi.stone_button(confirm_title)
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.custom_minimum_size = Vector2(220, 40)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(_confirm_btn)

	var retrieve_btn := SocialUi.stone_button("↩️ Thu Hồi Về Túi")
	retrieve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retrieve_btn.custom_minimum_size = Vector2(160, 40)
	retrieve_btn.pressed.connect(func() -> void:
		_return_all_chest_items_to_bag()
		_refresh_views()
		_set_msg("Đã thu hồi tất cả vật phẩm từ rương về lại hành trang.", false)
	)
	btn_row.add_child(retrieve_btn)

	var cancel_btn := SocialUi.stone_button("✕ Đóng / Hủy")
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(140, 40)
	cancel_btn.pressed.connect(func() -> void:
		close_requested.emit()
	)
	btn_row.add_child(cancel_btn)

	_refresh_views()

## Tạo Banner cảnh báo nổi bật (Màu Đỏ cho Type 2, Màu Xanh/Vàng cho Type 3)
func _build_warning_banner() -> void:
	var banner := PanelContainer.new()
	var b_style := StyleBoxFlat.new()

	if _qtype == 2:
		# CẢNH BÁO MÀU ĐỎ NỔI BẬT: Dã Tẩu sẽ thu hồi (mất món đồ vĩnh viễn)
		b_style.bg_color = Color(0.38, 0.05, 0.05, 0.95)
		b_style.border_color = Color(1.0, 0.25, 0.25, 1.0)
		b_style.set_border_width_all(2)
		b_style.set_content_margin_all(10)
		banner.add_theme_stylebox_override("panel", b_style)
		body.add_child(banner)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		banner.add_child(vb)

		var t := SocialUi.label("⚠️ CẢNH BÁO QUAN TRỌNG: DÃ TẨU SẼ THU HỒI MÓN ĐỒ NÀY (BỊ MẤT ĐỒ)!", SocialUi.TITLE, 14, HORIZONTAL_ALIGNMENT_CENTER)
		t.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		vb.add_child(t)

		var d := SocialUi.label("Món đồ bạn nộp sẽ BỊ XÓA VĨNH VIỄN khỏi nhân vật sau khi xác nhận. Hãy tự tay chọn và kiểm tra kỹ món đồ bỏ vào rương để tránh nộp nhầm trang bị có chỉ số cao mà bạn muốn giữ lại!", SocialUi.TEXT, 12, HORIZONTAL_ALIGNMENT_CENTER)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8))
		vb.add_child(d)
	else:
		# LƯU Ý MÀU XANH / VÀNG CHO TYPE 3 (Chỉ xem chỉ số, không mất đồ)
		b_style.bg_color = Color(0.04, 0.22, 0.12, 0.95)
		b_style.border_color = Color(0.2, 0.85, 0.45, 1.0)
		b_style.set_border_width_all(2)
		b_style.set_content_margin_all(10)
		banner.add_theme_stylebox_override("panel", b_style)
		body.add_child(banner)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		banner.add_child(vb)

		var t := SocialUi.label("ℹ️ LƯU Ý: DÃ TẨU CHỈ XEM CHỈ SỐ, KHÔNG THU HỒI ĐỒ", SocialUi.TITLE, 14, HORIZONTAL_ALIGNMENT_CENTER)
		t.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		vb.add_child(t)

		var d := SocialUi.label("Nhiệm vụ này Dã Tẩu chỉ xem chỉ số trang bị. Sau khi bấm xác nhận cho xem, trang bị vẫn nằm an toàn trong hành trang của bạn!", SocialUi.TEXT, 12, HORIZONTAL_ALIGNMENT_CENTER)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
		vb.add_child(d)

func _select_bag_tab(idx: int) -> void:
	for i in _bag_tabs.size():
		GameUi.set_active(_bag_tabs[i], i == idx)
	if _bag_view != null:
		_bag_view.bag = idx
		_bag_view.rebuild()

func _refresh_views() -> void:
	if _chest_view != null:
		_chest_view.rebuild()
	if _bag_view != null:
		_bag_view.rebuild()
	_check_items_preview()

func _set_msg(text: String, is_error: bool = false) -> void:
	if _msg_label == null:
		return
	_msg_label.text = text
	var col := Color(1.0, 0.35, 0.35) if is_error else Color(0.4, 0.95, 0.6)
	_msg_label.add_theme_color_override("font_color", col)

## Tự động kiểm tra trước các món đang đặt trong rương nộp và đưa ra gợi ý tức thì
func _check_items_preview() -> void:
	if _chest_container.inventory.is_empty():
		_set_msg("Rương nộp đang trống. Hãy bấm hoặc kéo món đồ bạn muốn nộp vào rương.", false)
		return

	if _qtype == 2:
		var has_valid := false
		var valid_name := ""
		for it in _chest_container.inventory:
			if DaTauManager.is_item_matching_type2(it, _quest):
				has_valid = true
				valid_name = it.get_display_name()
				break
		if has_valid:
			_set_msg("✅ Tìm thấy món [%s] hợp lệ! Bấm Xác Nhận để nộp (món đồ sẽ bị thu hồi)." % valid_name, false)
		else:
			_set_msg("⚠️ Các món trong rương hiện tại KHÔNG thỏa mãn yêu cầu: %s" % str(_quest.get("desc", "")), true)
	elif _qtype == 3:
		var has_valid := false
		var valid_name := ""
		var valid_val := 0
		for it in _chest_container.inventory:
			var res := DaTauManager.is_item_matching_type3(it, _quest)
			if res.get("match", false):
				has_valid = true
				valid_name = it.get_display_name()
				valid_val = int(res.get("cur_value", 0))
				break
		if has_valid:
			_set_msg("✅ Món [%s] đạt yêu cầu (chỉ số: %d)! Bấm Xác Nhận để Dã Tẩu xem (không mất đồ)." % [valid_name, valid_val], false)
		else:
			_set_msg("⚠️ Các trang bị trong rương chưa có thuộc tính hoặc chỉ số đạt yêu cầu!", true)

## Xử lý kéo thả giữa Hành trang và Rương nộp 10x6
func _transfer_handler(item: ItemInstance, from: Object, to: Object, x: int, y: int, bag: int) -> bool:
	if from == _profile and to == _chest_container:
		if SecurityLock.is_item_locked(item) or item.trade_price > 0:
			_set_msg("⚠️ Món đồ đang bị khoá hoặc đang bày bán, không thể đưa vào rương!", true)
			return false
		if not _profile.inventory.has(item) or not _chest_container.can_place(item, x, y, bag):
			_set_msg("⚠️ Vị trí trong rương không đủ chỗ trống!", true)
			return false
		_profile.inventory.erase(item)
		_chest_container.place_item(item, x, y, bag)
		_refresh_views()
		return true
	elif from == _chest_container and to == _profile:
		if not _chest_container.owns(item) or not _profile.can_place(item, x, y, bag, _profile.get_room_height(bag)):
			_set_msg("⚠️ Vị trí trong hành trang không đủ chỗ trống!", true)
			return false
		_chest_container.remove_item(item)
		item.room_x = x
		item.room_y = y
		item.room_bag = bag
		_profile.inventory.append(item)
		_refresh_views()
		return true
	return false

## Bấm vào món trong hành trang -> đưa vào rương nộp
func _on_bag_item_pressed(item: ItemInstance) -> void:
	if SecurityLock.is_item_locked(item) or item.trade_price > 0:
		_set_msg("⚠️ Món đồ đang bị khoá hoặc đang bày bán, không thể đưa vào rương!", true)
		return
	var spot := _chest_container.find_free_spot_any(item.get_size())
	if spot.z < 0:
		_set_msg("⚠️ Rương nộp đã đầy! Không còn ô trống để chứa món đồ.", true)
		return
	_profile.inventory.erase(item)
	_chest_container.place_item(item, spot.x, spot.y, spot.z)
	_refresh_views()

## Bấm vào món trong rương nộp -> chuyển lại về hành trang
func _on_chest_item_pressed(item: ItemInstance) -> void:
	var spot := _profile.find_free_spot_any(item.get_size())
	if spot.z < 0:
		_set_msg("⚠️ Hành trang không đủ chỗ trống để nhận lại món đồ!", true)
		return
	_chest_container.remove_item(item)
	item.room_x = spot.x
	item.room_y = spot.y
	item.room_bag = spot.z
	_profile.inventory.append(item)
	_refresh_views()

## Hoàn trả tất cả vật phẩm còn trong rương nộp về lại hành trang (an toàn 100%)
func _return_all_chest_items_to_bag() -> void:
	if _chest_container == null or _profile == null:
		return
	var items_to_return := _chest_container.inventory.duplicate()
	for it in items_to_return:
		_chest_container.remove_item(it)
		if not _profile.inventory.has(it):
			var spot := _profile.find_free_spot_any(it.get_size())
			if spot.z >= 0:
				it.room_x = spot.x
				it.room_y = spot.y
				it.room_bag = spot.z
			_profile.inventory.append(it)
	_chest_container.clear()

## Người chơi bấm nút Xác Nhận Nộp / Xác Nhận Cho Xem
func _on_confirm_pressed() -> void:
	if _chest_container.inventory.is_empty():
		_set_msg("⚠️ Rương nộp đang trống! Vui lòng bỏ món đồ bạn muốn nộp vào rương.", true)
		return

	if _qtype == 2:
		# TYPE 2: Tìm món đồ hợp lệ trong rương nộp để THU HỒI
		var matched_item: ItemInstance = null
		for it in _chest_container.inventory:
			if DaTauManager.is_item_matching_type2(it, _quest):
				matched_item = it
				break

		if matched_item == null:
			_set_msg("⚠️ Không có món đồ nào trong rương thỏa mãn yêu cầu của Dã Tẩu!\nYêu cầu: %s" % str(_quest.get("desc", "")), true)
			return

		var item_display_name := matched_item.get_display_name()

		# Thu hồi món đồ hợp lệ đã chọn
		if matched_item.is_misc() and matched_item.count > 1:
			matched_item.count -= 1
			# Trả phần còn lại về túi
			_chest_container.remove_item(matched_item)
			_profile.add_item(matched_item)
		else:
			# Xóa vĩnh viễn món đồ được chọn
			_chest_container.remove_item(matched_item)

		# Hoàn trả toàn bộ các món khác (nếu có) còn lại trong rương về túi
		_return_all_chest_items_to_bag()

		# Đánh dấu nhiệm vụ đã nộp đủ
		_quest["done_num"] = int(_quest.get("need_num", 1))
		var state := DaTauManager._get_state(_profile)
		DaTauManager.save_records(state, _profile)
		SaveManager.save_profile(_profile, true)

		_submitted = true
		var success_msg := "✅ Đã nộp thành công [%s] cho Dã Tẩu! Hãy nhận phần thưởng." % item_display_name
		if _on_submitted.is_valid():
			_on_submitted.call(success_msg)
		close_requested.emit()

	elif _qtype == 3:
		# TYPE 3: Tìm trang bị có thuộc tính đạt yêu cầu để CHO DÃ TẨU XEM (KHÔNG THU HỒI)
		var matched_item: ItemInstance = null
		var match_info: Dictionary = {}
		for it in _chest_container.inventory:
			var res := DaTauManager.is_item_matching_type3(it, _quest)
			if res.get("match", false):
				matched_item = it
				match_info = res
				break

		if matched_item == null:
			_set_msg("⚠️ Trong rương không có trang bị nào đạt chỉ số thuộc tính yêu cầu!\n(Yêu cầu: %s)" % str(_quest.get("desc", "")), true)
			return

		var item_display_name := matched_item.get_display_name()
		var cur_val: int = int(match_info.get("cur_value", 0))

		# Hoàn trả 100% món đồ trong rương về lại hành trang (không mất bất kỳ món nào)
		_return_all_chest_items_to_bag()

		# Đánh dấu nhiệm vụ đã xem xong
		_quest["done_num"] = int(_quest.get("need_num", 1))
		var state := DaTauManager._get_state(_profile)
		DaTauManager.save_records(state, _profile)
		SaveManager.save_profile(_profile, true)

		_submitted = true
		var success_msg := "✅ Dã Tẩu đã xem xong [%s] (chỉ số: %d), thuộc tính hoàn toàn đạt yêu cầu!" % [item_display_name, cur_val]
		if _on_submitted.is_valid():
			_on_submitted.call(success_msg)
		close_requested.emit()
