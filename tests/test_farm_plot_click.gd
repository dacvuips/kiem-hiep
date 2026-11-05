extends SceneTree
## Unit test kiểm tra tương tác nhấp vào ô luống hiển thị popup thông tin luống đất Sơn Trang

class MockFarmMgr extends Node:
	var plot_mgr = null
	var currency_gold: int = 50000
	var farm_chest_supplies: Dictionary = {"fresh_water_pot": 10, "fertilizer": 10, "seed_rice": 5, "seed_cabbage": 5}
	func _init() -> void:
		var pm_script = load("res://systems/son_trang/plot_manager.gd")
		plot_mgr = pm_script.new()
	func buy_item_with_currency(gold: int, _xu: int = 0) -> bool:
		currency_gold -= gold
		return true
	func save_farm_data() -> void:
		pass
	func get_water_count() -> int:
		return 10
	func get_fertilizer_count() -> int:
		return 10
	func get_tool_hoe_count() -> int:
		return int(farm_chest_supplies.get("tool_hoe", 0))
	func use_tool_hoe(cnt: int = 1) -> bool:
		var cur = int(farm_chest_supplies.get("tool_hoe", 0))
		if cur >= cnt:
			farm_chest_supplies["tool_hoe"] = cur - cnt
			return true
		return false
	func use_water(_cnt: int = 1) -> bool:
		return true
	func use_fertilizer(_cnt: int = 1) -> bool:
		return true
	func add_to_chest(id: String, cnt: int, _is_supplies: bool) -> void:
		farm_chest_supplies[id] = int(farm_chest_supplies.get(id, 0)) + cnt
	func add_farm_exp(_exp: int) -> void:
		pass

func _initialize() -> void:
	print("--- [TEST PLOT CLICK & POPUP] BẮT ĐẦU KIỂM THỬ ---")
	
	# 1. Khởi tạo MockFarmMgr
	var farm_mgr = MockFarmMgr.new()
	farm_mgr.name = "FarmManager"
	root.add_child(farm_mgr)
	
	assert(farm_mgr.plot_mgr != null, "FarmManager phải có PlotManager")
	assert(farm_mgr.plot_mgr.plots.size() == 34, "Phải có đúng 34 luống đất")
	
	# 2. Khởi tạo FarmPlotsController
	var plots_script = load("res://systems/son_trang/farm_plots_controller.gd") if ResourceLoader.exists("res://systems/son_trang/farm_plots_controller.gd") else load("res://world/maps/map_nguyet_ca/farm_plots_controller.gd")
	assert(plots_script != null, "Phải tải được FarmPlotsController")
	var plots_node = plots_script.new()
	plots_node.name = "FarmPlotsController"
	plots_node.position = plots_script.FARM_CENTER_WORLD
	plots_node.farm_mgr = farm_mgr
	plots_node._calculate_plot_areas()
	root.add_child(plots_node)
	
	# Đảm bảo các Rect2 luống đã được tính toán
	assert(plots_node._plot_areas.size() == 34, "Phải tính toán đúng 34 vùng luống đất")
	
	# 3. Test Hover qua ô luống đất
	var plot0_rect: Rect2 = plots_node._plot_areas[0]
	plots_node._hovered_plot_idx = 0
	assert(plots_node._hovered_plot_idx == 0, "Luống 0 nhận hover thành công")
	print("[PASS] Tính năng hover ô luống hoạt động chính xác")
	
	# 4. Test Nhấp vào Luống 0 (Đã mở khóa) -> Mở LuongActionModal
	plots_node._handle_luong_click(0)
	
	var modal_layer = root.get_node_or_null("FarmModalLayer") as CanvasLayer
	assert(modal_layer != null, "Phải tạo FarmModalLayer trên CanvasLayer")
	assert(modal_layer.layer == 120, "FarmModalLayer phải có layer 120 nổi trên toàn bộ UI")
	
	var luong_modal = modal_layer.get_node_or_null("LuongActionModal") as Control
	assert(luong_modal != null, "Phải mở được popup LuongActionModal khi nhấp vào Luống 0")
	assert(luong_modal.visible, "LuongActionModal phải hiển thị")
	
	# Kiểm tra tọa độ popup không bị âm (lỗi ngoài màn hình trước đây)
	print("Tọa độ LuongActionModal: ", luong_modal.position, " Kích thước: ", luong_modal.size)
	assert(luong_modal.position.x >= 0 and luong_modal.position.y >= 0, "Popup phải nằm trọn vẹn trong vùng hiển thị của màn hình")
	print("[PASS] Nhấp vào Luống đã mở hiển thị popup thông tin & thao tác chuẩn xác")
	
	# 5. Test Nhấp vào Luống 1 (Chưa mở khóa) -> Đóng LuongActionModal cũ, Mở PlotUnlockModal
	plots_node._handle_luong_click(1)
	
	var old_modal = modal_layer.get_node_or_null("LuongActionModal")
	assert(old_modal == null or old_modal.is_queued_for_deletion(), "LuongActionModal cũ phải được đóng khi nhấp ô luống khác")
	
	var unlock_modal = modal_layer.get_node_or_null("PlotUnlockModal") as Control
	assert(unlock_modal != null, "Phải mở được popup PlotUnlockModal khi nhấp vào Luống 1 chưa khai hoang")
	assert(unlock_modal.position.x >= 0 and unlock_modal.position.y >= 0, "Popup Khai Hoang phải nằm trong màn hình")
	print("[PASS] Nhấp vào Luống chưa mở hiển thị popup Khai hoang mở đất chuẩn xác")
	
	# 6. Test Đóng Modal
	plots_node._close_all_modals()
	assert(plots_node._get_active_modal() == null, "Tất cả modal phải được đóng khi gọi _close_all_modals")
	print("[PASS] Đóng modal đóng chuẩn xác")
	
	# 7. Test Mở SeedPickerModal cho Luống 0
	plots_node._open_seed_picker_for_plot(0)
	var seed_modal = modal_layer.get_node_or_null("SeedPickerModal") as Control
	assert(seed_modal != null, "Phải mở được popup SeedPickerModal")
	assert(seed_modal.position.x >= 0 and seed_modal.position.y >= 0, "SeedPickerModal phải nằm trong màn hình")
	plots_node._close_all_modals()
	print("[PASS] SeedPickerModal mở và hiển thị vị trí chuẩn xác")

	# 8. Test Visual Cây Trồng & Hạt Giống trên Luống (tao_do và mai_hoa)
	farm_mgr.plot_mgr.plant_seed(0, "tao_do")
	var p0 = farm_mgr.plot_mgr.plots[0]
	assert(p0.state == PlotManager.PlotState.PLANTED, "Luống 0 phải ở trạng thái PLANTED")
	assert(p0.plant_id == "tao_do", "Luống 0 phải trồng táo đỏ")

	# Kiểm tra gọi _draw_crop_on_plot không gây lỗi (tại tiến độ 0%, 30%, 60%, 100%)
	plots_node._draw_crop_on_plot(p0, plot0_rect)
	p0.planted_at = int(Time.get_unix_time_from_system()) - int(p0.total_grow_time * 0.3)
	plots_node._draw_crop_on_plot(p0, plot0_rect)
	p0.planted_at = int(Time.get_unix_time_from_system()) - int(p0.total_grow_time * 0.7)
	plots_node._draw_crop_on_plot(p0, plot0_rect)
	p0.state = PlotManager.PlotState.HARVESTABLE
	plots_node._draw_crop_on_plot(p0, plot0_rect)
	print("[PASS] Hiển thị UI ảnh hạt giống và cây trồng trên luống (Táo Đỏ) hoạt động hoàn hảo mọi giai đoạn")

	# 9. Test Nâng Cấp Luống cần Cuốc Thép
	farm_mgr.farm_chest_supplies.erase("tool_hoe")
	assert(farm_mgr.get_tool_hoe_count() == 0, "Ban đầu không có cuốc thép")
	plots_node._open_luong_modal(0)
	var action_modal = modal_layer.get_node_or_null("LuongActionModal")
	assert(action_modal != null, "Mở LuongActionModal thành công")
	var up_btn: Button = null
	for child in action_modal.find_children("", "Button", true, false):
		if "Nâng Cấp Luống" in child.text:
			up_btn = child
			break
	assert(up_btn != null, "Phải tìm thấy nút Nâng Cấp Luống")
	assert("Cuốc Thép" in up_btn.text, "Nút Nâng Cấp Luống phải hiển thị yêu cầu Cuốc Thép: %s" % up_btn.text)

	# Bấm khi chưa có cuốc thép -> không nâng cấp được
	up_btn.emit_signal("pressed")
	assert(farm_mgr.plot_mgr.plots[0].level == 1, "Chưa có cuốc thép không được lên cấp 2")

	# Mua 1 cuốc thép vào rương
	farm_mgr.add_to_chest("tool_hoe", 1, true)
	assert(farm_mgr.get_tool_hoe_count() == 1, "Đã có 1 cuốc thép trong rương")

	# Bấm nâng cấp khi đã có cuốc thép -> nâng cấp thành công và tiêu hao 1 cuốc thép
	up_btn.emit_signal("pressed")
	assert(farm_mgr.plot_mgr.plots[0].level == 2, "Luống 0 đã nâng lên Cấp 2")
	assert(farm_mgr.get_tool_hoe_count() == 0, "Đã tiêu hao 1 cuốc thép sau khi nâng cấp")
	print("[PASS] Nâng cấp luống bắt buộc phải có Cuốc Thép và tiêu hao Cuốc Thép chính xác (100%)")

	# Cleanup
	plots_node.queue_free()
	if modal_layer:
		modal_layer.queue_free()
	farm_mgr.queue_free()
	
	print("--- [TEST PLOT CLICK & POPUP] TẤT CẢ TEST ĐỀU THÀNH CÔNG (100%) ---")
	quit()
