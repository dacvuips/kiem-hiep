extends SceneTree

func _init() -> void:
	print("--- [TEST LIVESTOCK UI & BUTTONS] BẮT ĐẦU KIỂM THỬ ---")
	test_overhead_hud()
	test_prominent_buttons()
	test_batch_feed_and_water()
	test_animal_modal_batch_buttons()
	print("--- [TEST LIVESTOCK UI & BUTTONS] HOÀN TẤT KIỂM THỬ THÀNH CÔNG (100%) ---")
	quit()

func test_overhead_hud() -> void:
	var livestock_script = load("res://systems/son_trang/livestock_controller.gd") if ResourceLoader.exists("res://systems/son_trang/livestock_controller.gd") else load("res://world/maps/map_nguyet_ca/livestock_controller.gd")
	var lc = livestock_script.new()
	root.add_child(lc)

	var animal_info = LivestockManager.AnimalInfo.new()
	animal_info.animal_id = "voi_hoang_ha"
	animal_info.name = "Voi Hoàng Hà Cổ Tượng"
	animal_info.hunger = 0.0 # Bị đói
	animal_info.thirst = 0.0 # Bị khát
	animal_info.state = LivestockManager.AnimalState.GROWING

	var wanderer = livestock_script.AnimalWanderer.new(animal_info, Rect2(0, 0, 100, 100))
	var hud = livestock_script.AnimalOverheadHUD.new(wanderer)
	root.add_child(hud)

	# Verify overhead hud exists
	assert(hud != null, "HUD phải được tạo thành công")
	print("[PASS] AnimalOverheadHUD khởi tạo thành công khi thú đói 0%")
	hud.queue_free()
	lc.queue_free()

func test_prominent_buttons() -> void:
	var livestock_script = load("res://systems/son_trang/livestock_controller.gd") if ResourceLoader.exists("res://systems/son_trang/livestock_controller.gd") else load("res://world/maps/map_nguyet_ca/livestock_controller.gd")
	var lc = livestock_script.new()
	root.add_child(lc)

	var btn := Button.new()
	lc._apply_prominent_button_style(btn, Color(0.16, 0.46, 0.2, 0.96), Color(0.55, 0.95, 0.45), Color(0.95, 1.0, 0.92))

	var normal = btn.get_theme_stylebox("normal")
	assert(normal is StyleBoxFlat, "StyleBoxFlat phải được gán cho normal")
	var sbf: StyleBoxFlat = normal
	assert(sbf.border_width_left >= 1, "Border width phải >= 1px để làm nổi nút")
	assert(btn.get_theme_stylebox("hover") is StyleBoxFlat, "Phải có hover stylebox")
	assert(btn.get_theme_stylebox("pressed") is StyleBoxFlat, "Phải có pressed stylebox")
	assert(btn.get_theme_stylebox("disabled") is StyleBoxFlat, "Phải có disabled stylebox")
	print("[PASS] Nút bấm được định dạng StyleBoxFlat nổi bật với viền và màu sắc tương phản cao")
	btn.queue_free()
	lc.queue_free()

func test_batch_feed_and_water() -> void:
	var mgr := LivestockManager.new()
	assert(mgr.animals.size() >= 4, "Mặc định có ít nhất 4 con thú")

	# Làm đói và khát toàn bộ đàn thú
	for a in mgr.animals:
		a.hunger = 0.0
		a.thirst = 0.0
		a.state = LivestockManager.AnimalState.GROWING

	# 1. Test Cho uống nước hàng loạt
	var water_res := mgr.water_all_animals()
	assert(water_res.get("success", false) == true, "Cho uống nước hàng loạt phải thành công")
	assert(water_res.get("watered_count", 0) == mgr.animals.size(), "Toàn bộ thú phải được uống nước")
	for a in mgr.animals:
		assert(a.thirst == 100.0, "Mức nước phải đạt 100%")

	# Thử cho uống lần nữa khi đã no nước -> báo không cần uống
	var water_again := mgr.water_all_animals()
	assert(water_again.get("success", false) == false, "Khi đã no nước không thể cho uống tiếp")

	# 2. Test Cho ăn hàng loạt
	var feed_res := mgr.feed_all_animals("lua_vang")
	assert(feed_res.get("success", false) == true, "Cho ăn hàng loạt phải thành công")
	assert(feed_res.get("fed_count", 0) == mgr.animals.size(), "Toàn bộ thú đói phải được cho ăn")
	for a in mgr.animals:
		assert(a.hunger > 0.0, "Thanh đói phải được hồi phục")

	print("[PASS] LivestockManager feed_all_animals & water_all_animals hoạt động chính xác 100%")

func test_animal_modal_batch_buttons() -> void:
	var livestock_script = load("res://systems/son_trang/livestock_controller.gd") if ResourceLoader.exists("res://systems/son_trang/livestock_controller.gd") else load("res://world/maps/map_nguyet_ca/livestock_controller.gd")
	var lc = livestock_script.new()
	root.add_child(lc)

	var mgr := LivestockManager.new()
	# Tạo mock FarmManager đơn giản
	var dummy_farm := Node.new()
	dummy_farm.name = "FarmManager"
	dummy_farm.set("livestock_mgr", mgr)
	var script_src := """
extends Node
signal farm_data_changed()
var livestock_mgr = null
var currency_gold: int = 50000
var active_companion: Dictionary = {}
func get_feed_count() -> int: return 10
func get_water_count() -> int: return 15
func use_any_feed(consume: bool = false) -> String: return "lua_vang"
func use_water(count: int = 1) -> bool: return true
func get_player_gold() -> int: return 50000
func save_farm_data() -> void: pass
"""
	var custom_script := GDScript.new()
	custom_script.source_code = script_src
	custom_script.reload()
	dummy_farm.set_script(custom_script)
	dummy_farm.livestock_mgr = mgr
	root.add_child(dummy_farm)

	lc.farm_mgr = dummy_farm
	lc._open_animal_action_modal(0)

	var modal = root.find_child("AnimalActionModal", true, false)
	assert(modal != null, "Modal AnimalActionModal phải được tạo")

	# Tìm các nút Cho Ăn, Cho Ăn Hàng Loạt, Cho Uống Nước, Cho Uống Hàng Loạt
	var found_feed := false
	var found_batch_feed := false
	var found_water := false
	var found_batch_water := false

	var queue: Array[Node] = [modal]
	while not queue.is_empty():
		var node = queue.pop_front()
		if node is Button:
			var btn := node as Button
			if btn.text == "🌾 Cho Ăn":
				found_feed = true
			elif btn.text == "🌾 Cho Ăn Hàng Loạt":
				found_batch_feed = true
			elif btn.text == "💧 Cho Uống Nước":
				found_water = true
			elif btn.text == "💧 Cho Uống Hàng Loạt":
				found_batch_water = true
		for ch in node.get_children():
			queue.append(ch)

	assert(found_feed, "Phải có nút '🌾 Cho Ăn'")
	assert(found_batch_feed, "Phải có nút '🌾 Cho Ăn Hàng Loạt'")
	assert(found_water, "Phải có nút '💧 Cho Uống Nước'")
	assert(found_batch_water, "Phải có nút '💧 Cho Uống Hàng Loạt'")

	print("[PASS] Bảng Tương Tác Thú Nuôi đã hiển thị đầy đủ [Cho Ăn], [Cho Ăn Hàng Loạt], [Cho Uống Nước], [Cho Uống Hàng Loạt]")

	modal.queue_free()
	dummy_farm.queue_free()
	lc.queue_free()

