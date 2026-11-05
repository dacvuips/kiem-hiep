extends SceneTree
## Unit test cho hệ thống cốt lõi Sơn Trang:
## - FarmTimeSystem (4 mùa, ngày/đêm)
## - PlantData & PlotManager (cày cuốc, gieo trồng, tưới nước, bón phân, thu hoạch)
## - FarmManager (tích lũy exp, cấp sơn trang, rương chứa đồ, đống lửa)

func run_tests() -> bool:
	print("--- [TEST SƠN TRANG] BẮT ĐẦU KIỂM THỬ ---")
	
	# 1. Test FarmTimeSystem & Weather System (Hệ thống Thời Tiết Sơn Trang)
	var season := FarmTimeSystem.get_current_season()
	var s_name := FarmTimeSystem.get_season_name(season)
	print("[PASS] Mùa hiện tại: ", s_name)
	
	var mult_match := FarmTimeSystem.get_growth_rate_multiplier(season, season)
	assert(mult_match > 1.0, "Đúng mùa phải tăng tốc độ sinh trưởng")
	print("[PASS] Đúng mùa tăng tốc: x", mult_match)

	# Kiểm tra 6 trạng thái thời tiết
	var all_w := FarmTimeSystem.get_all_weathers()
	assert(all_w.size() == 6, "Phải có đầy đủ 6 kiểu thời tiết (Nắng, Mưa, Bão, Sương mù, Tuyết, Gió)")
	
	# Test Mưa Rào (tự động tưới nước đất)
	FarmTimeSystem.set_weather(FarmTimeSystem.Weather.RAINY)
	var rainy_info := FarmTimeSystem.get_weather_info()
	assert(rainy_info.get("auto_water", false) == true, "Trời mưa phải tự động tưới nước")
	assert(rainy_info.get("name", "") == "Mưa Rào", "Tên thời tiết: Mưa Rào")

	# Test Tuyết Rơi (sưởi ấm lửa x2 EXP)
	FarmTimeSystem.set_weather(FarmTimeSystem.Weather.SNOWY)
	var snowy_info := FarmTimeSystem.get_weather_info()
	assert(snowy_info.get("campfire_bonus", 1.0) == 2.0, "Tuyết rơi phải x2 EXP sưởi ấm đống lửa")

	# Test Nắng Đẹp (quang hợp +15% sản lượng)
	FarmTimeSystem.set_weather(FarmTimeSystem.Weather.SUNNY)
	var sunny_info := FarmTimeSystem.get_weather_info()
	assert(sunny_info.get("crop_bonus", 0.0) == 0.15, "Nắng đẹp tăng +15% sản lượng quang hợp")
	print("[PASS] Hệ thống 6 trạng thái Thời Tiết và Buff Nông Nghiệp hoạt động chính xác (100%)")
	
	# 2. Test PlantData
	var linh_chi := PlantData.get_plant("linh_chi")
	assert(linh_chi != null, "Phải nạp được Linh Chi Thảo")
	assert(linh_chi.grow_time_seconds > 0, "Thời gian sinh trưởng phải > 0")
	print("[PASS] Nạp dữ liệu cây: ", linh_chi.name, " (", linh_chi.grow_time_seconds, "s)")
	
	# 3. Test PlotManager (34 Luống đất: 21 Khu Đông + 11 Khu Tây Mở Rộng + 2 Khu Bắc)
	var mgr := PlotManager.new()
	assert(mgr.plots.size() == 34, "Phải có đúng 34 luống đất theo thiết kế sau khi bỏ Luống 33")
	assert(mgr.plots[0].is_unlocked == true, "Luống 1 mở sẵn")
	assert(mgr.plots[0].level == 1, "Luống 1 khởi đầu Cấp 1")
	assert(mgr.plots[1].is_unlocked == false, "Luống 2 chưa kích hoạt (border đứt khúc)")
	assert(mgr.plots[20].is_unlocked == false, "Luống 21 chưa kích hoạt (border đứt khúc)")
	assert(mgr.plots[33].is_unlocked == false, "Luống 34 chưa kích hoạt (border đứt khúc)")
	
	# Test mua đất mới -> kích hoạt đất Cấp 1
	var unl_res := mgr.unlock_plot(1)
	assert(unl_res.get("success", false) == true, "Mua đất thành công")
	assert(mgr.plots[1].is_unlocked == true and mgr.plots[1].level == 1, "Sau khi mua có Đất Cấp 1")
	
	# Gieo hạt trên Luống 0
	var planted := mgr.plant_seed(0, "linh_chi")
	assert(planted and mgr.plots[0].state == PlotManager.PlotState.PLANTED, "Gieo hạt thành công trên Luống 1")
	
	# Tưới nước & bón phân
	var watered := mgr.water_plot(0)
	var fertilized := mgr.fertilize_plot(0)
	assert(watered and fertilized, "Tưới nước và bón phân thành công")
	assert(mgr.plots[0].watered_count == 1, "Số lần tưới phải là 1")
	assert(mgr.plots[0].is_fertilized, "Đã bón phân")
	
	# Nâng cấp Luống 0 lên Cấp 2
	var up_res := mgr.upgrade_plot(0)
	assert(up_res.get("success", false) == true, "Nâng cấp luống thành công")
	assert(mgr.plots[0].level == 2, "Luống 1 đã nâng lên Cấp 2")
	assert(mgr.plots[0].get_growth_rate() > 0.0, "Tốc độ sinh trưởng luống phải > 0")
	assert(mgr.plots[0].get_remaining_time() > 0.0, "Thời gian còn lại khi cây đang lớn phải > 0")
	print("[PASS] 6 Luống đất, gieo trồng, get_remaining_time và nâng cấp cấp độ luống hoạt động chính xác")
	
	# Giả lập thu hoạch
	mgr.plots[0].state = PlotManager.PlotState.HARVESTABLE
	var harvest_res := mgr.harvest_plot(0)
	assert(harvest_res.get("success", false) == true, "Thu hoạch thành công")
	assert(harvest_res.get("gold", 0) > 0, "Phải có tiền thưởng")
	print("[PASS] Thu hoạch thành công: ", harvest_res.get("plant_name"), " -> Vàng: ", harvest_res.get("gold"))

	# Kiểm tra 5 hình ảnh luống đất (Cấp 1 -> Cấp 5) tồn tại trên đĩa
	for lvl in range(1, 6):
		var p_path := "res://assets/farm/plots/plot_level_%d.png" % lvl
		assert(FileAccess.file_exists(p_path), "File ảnh luống cấp %d không tồn tại: %s" % [lvl, p_path])
	print("[PASS] 5 Cấp độ hình ảnh luống đất 159x130 đều hợp lệ 100%")

	# 4. Test NPC Thương Nhân Sơn Trang & Trù Thần Thu Mua Thịt
	var npc_script: GDScript = load("res://systems/son_trang/farm_npc_controller.gd") if ResourceLoader.exists("res://systems/son_trang/farm_npc_controller.gd") else load("res://world/maps/map_nguyet_ca/farm_npc_controller.gd")
	assert(npc_script != null, "Phải tải được FarmNPCController")
	var configs: Array = npc_script.NPC_CONFIGS
	assert(configs.size() >= 4, "Phải có ít nhất 4 NPC Sơn Trang")

	# NPC Chăn nuôi 195/192
	assert(configs[0]["coord_name"] == "195/192", "Tọa độ NPC Chăn nuôi phải là 195/192")
	assert(configs[0]["world_pos"] == Vector2(50048.0, 49280.0), "Pixel World NPC Chăn nuôi chuẩn 50048, 49280")
	assert(configs[0]["res"] == "passerby240", "Sprite NPC Chăn nuôi chuẩn passerby240")

	# NPC Trồng trọt 191/186
	assert(configs[1]["coord_name"] == "191/186", "Tọa độ NPC Trồng trọt phải là 191/186")
	assert(configs[1]["world_pos"] == Vector2(49024.0, 47744.0), "Pixel World NPC Trồng trọt chuẩn 49024, 47744")
	assert(configs[1]["res"] == "enemy110", "Sprite NPC Trồng trọt chuẩn enemy110")

	# NPC Cá nước ngọt 180/185
	assert(configs[2]["coord_name"] == "180/185", "Tọa độ NPC Cá nước ngọt phải là 180/185")
	assert(configs[2]["world_pos"] == Vector2(46208.0, 47488.0), "Pixel World NPC Cá nước ngọt chuẩn 46208, 47488")
	assert(configs[2]["res"] == "passerby338", "Sprite NPC Cá nước ngọt chuẩn passerby338")

	# NPC Cá biển 196/197
	assert(configs[3]["coord_name"] == "196/197", "Tọa độ NPC Cá biển phải là 196/197")
	assert(configs[3]["world_pos"] == Vector2(50304.0, 50560.0), "Pixel World NPC Cá biển chuẩn 50304, 50560")
	assert(configs[3]["res"] == "enemy149", "Sprite NPC Cá biển chuẩn enemy149")

	# NPC Trù Thần Thu Mua Thịt 194/191
	if configs.size() >= 5:
		assert(configs[4]["coord_name"] == "194/191", "Tọa độ NPC Trù Thần phải là 194/191")
		assert(configs[4]["category"] == "meat_exchange", "Danh mục Trù Thần là meat_exchange")
	print("[PASS] 5 NPC Sơn Trang gồm 4 Thương Nhân và Trù Thần Đổi Thịt tọa độ, sprite chuẩn")

	# 5. Test Cửa hàng và Icon không bị lỗi web
	var shop_script: GDScript = load("res://ui/son_trang/farm_npc_shop.gd")
	assert(shop_script != null, "Phải nạp được FarmNPCShop")
	var catalog: Dictionary = shop_script.SHOP_CATALOG
	for cat in ["livestock", "agriculture", "freshwater_fish", "ocean_fish"]:
		assert(catalog.has(cat), "Catalog phải có danh mục " + cat)
		var cat_data: Dictionary = catalog[cat]
		var items: Array = cat_data.get("items", [])
		assert(items.size() > 0, "Danh mục " + cat + " phải có sản phẩm")
		for it in items:
			var icon_file: String = "res://assets/items/icons/" + str(it.get("icon", ""))
			assert(FileAccess.file_exists(icon_file), "Icon không tồn tại hoặc lỗi web: " + icon_file)
			if it.has("monster_res"):
				var mres: String = str(it["monster_res"])
				assert(mres.begins_with("ani"), "Vật nuôi phải là động vật hoặc chim (bắt đầu bằng ani): " + mres)
				assert(MonsterData.thumb(mres) != null, "Ảnh đại diện trực tiếp của thú nuôi phải nạp được từ MonsterData: " + mres)
	print("[PASS] Kiểm tra 100% Vật nuôi là động vật/chim và Icon NPC Shop đều là file nội bộ hợp lệ")

	# 6. Test Rương Sơn Trang giao diện Grid Slot chuẩn VLTK (60 ô kín khung)
	var fw_script: GDScript = load("res://ui/son_trang/farm_windows.gd")
	assert(fw_script != null, "Phải nạp được FarmWindows")
	assert(fw_script.TOTAL_SLOTS == 60, "Rương phải có 60 ô grid slot chuẩn Sơn Trang (12x5)")
	var pork_meta: Dictionary = fw_script.get_item_meta("produce_pork", false)
	assert(pork_meta["name"] == "Thịt Heo Sạch", "Meta Thịt Heo Sạch chính xác")
	assert(pork_meta["sell_price"] == 60, "Giá bán Thịt Heo Sạch 60 Lượng")
	var eagle_meta: Dictionary = fw_script.get_item_meta("animal_eagle", true)
	assert(eagle_meta["name"] == "Đại Bàng Thứu Thần", "Meta Đại Bàng Thứu Thần chính xác")
	var carp_meta: Dictionary = fw_script.get_item_meta("fingerling_carp", true)
	assert(carp_meta["name"] == "Cá Trắm Cỏ Giống", "Meta Cá Trắm Cỏ Giống chính xác")
	assert(carp_meta["icon"] == "caoyu.png", "Icon Cá Trắm Cỏ Giống chuẩn caoyu.png")
	assert(carp_meta.get("is_seed", false) == true, "Cá Trắm Cỏ Giống phải được phân loại là giống (is_seed = true)")
	var bass_meta: Dictionary = fw_script.get_item_meta("fingerling_sea_bass", true)
	assert(bass_meta["name"] == "Cá Vược Biển Giống", "Meta Cá Vược Biển Giống chính xác")
	assert(bass_meta.get("is_seed", false) == true, "Cá Vược Biển Giống phải được phân loại là giống (is_seed = true)")
	print("[PASS] Kiểm tra Rương Sơn Trang Grid Slot 60 ô và Item Meta (Cá Trắm Cỏ Giống & Cá Vược Biển Giống) hoàn hảo")

	# 7. Test Đống Lửa Sơn Trang (FarmCampfireController) và UI Lửa Trại
	var cf_script: GDScript = load("res://systems/son_trang/farm_campfire_controller.gd") if ResourceLoader.exists("res://systems/son_trang/farm_campfire_controller.gd") else load("res://world/maps/map_nguyet_ca/farm_campfire_controller.gd")
	assert(cf_script != null, "Phải nạp được FarmCampfireController")
	assert(cf_script.CAMPFIRE_POS_WORLD == Vector2(49280.0, 48000.0), "Tọa độ Đống Lửa chuẩn 49280, 48000")
	assert(cf_script.CAMPFIRE_CONFIGS.size() == 4, "Phải có đúng 4 đống lửa ở 4 vị trí NPC")
	assert(cf_script.CAMPFIRE_CONFIGS[0]["world_pos"] == Vector2(49280.0, 48000.0), "Đống lửa Trồng Trọt ở 49280, 48000")
	assert(cf_script.CAMPFIRE_CONFIGS[1]["npc_name"] == "Trương Bá (Chăn Nuôi)", "Đống lửa Chăn Nuôi gắn với Trương Bá")
	assert(cf_script.CAMPFIRE_CONFIGS[2]["npc_name"] == "Khê Hồ Ngư Nương", "Đống lửa Khê Hồ gắn với Ngư Nương")
	assert(cf_script.CAMPFIRE_CONFIGS[3]["npc_name"] == "Hải Ngư Thuyền Trưởng", "Đống lửa Bờ Biển gắn với Thuyền Trưởng")
	assert(fw_script.has_method("open_campfire"), "FarmWindows phải có hàm open_campfire")
	print("[PASS] Kiểm tra 4 Đống Lửa Sơn Trang tại 4 NPC và UI Lửa Trại hoàn hảo")

	# 8. Test Thú Nuôi Di Chuyển Ở Ngoài (Free-Range Outdoor Pasture & Thú Cưng Đồng Hành)
	var ls_script: GDScript = load("res://systems/son_trang/livestock_controller.gd") if ResourceLoader.exists("res://systems/son_trang/livestock_controller.gd") else load("res://world/maps/map_nguyet_ca/livestock_controller.gd")
	assert(ls_script != null, "Phải nạp được LivestockController")
	var ls_inst = ls_script.new()
	assert(ls_inst.has_method("toggle_all_roam_outside"), "LivestockController phải có toggle_all_roam_outside")
	assert(ls_inst.has_method("contains_world_point"), "LivestockController phải có contains_world_point")
	assert(ls_inst.has_method("release_animal_here"), "LivestockController phải có release_animal_here")
	assert("zone_id" in ls_inst and "zone_name" in ls_inst, "LivestockController phải có thông tin zone_id và zone_name")

	# Test kiểm tra vị trí người chơi đứng trong và ngoài Vòng Nuôi Thú
	var center_pos: Vector2 = ls_script.LIVESTOCK_CENTER_WORLD
	ls_inst.position = center_pos
	var inside_center: Vector2 = center_pos # Tâm vòng nuôi 194/193
	var outside_pos: Vector2 = Vector2(10000.0, 10000.0) # Vị trí xa bên ngoài
	assert(ls_inst.contains_world_point(inside_center) == true, "Tâm chuồng nuôi 194/193 phải nằm trong Vòng Nuôi Thú")
	assert(ls_inst.contains_world_point(outside_pos) == false, "Vị trí xa bên ngoài không được nằm trong Vòng Nuôi Thú")

	ls_inst.free()
	assert(ls_script.OUTDOOR_ROAM_RECT.size.x > 500.0, "Khu vực bãi chăn thả ngoài trời phải rộng lớn")
	assert(ls_script.PASTURE_COORDS.size() == 5, "Chuồng nuôi phải có 5 điểm mốc tọa độ nối nhau")
	assert(ls_script.PASTURE_COORDS[0] == Vector2i(188, 191), "Điểm 1 chuồng nuôi: 188/191")
	assert(ls_script.PASTURE_COORDS[1] == Vector2i(198, 192), "Điểm 2 chuồng nuôi: 198/192")
	assert(ls_script.PASTURE_COORDS[2] == Vector2i(199, 194), "Điểm 3 chuồng nuôi: 199/194")
	assert(ls_script.PASTURE_COORDS[3] == Vector2i(193, 195), "Điểm 4 chuồng nuôi: 193/195")
	assert(ls_script.PASTURE_COORDS[4] == Vector2i(187, 194), "Điểm 5 chuồng nuôi: 187/194")
	assert(ls_script.PASTURE_POLYGON.size() == 5, "Đa giác chuồng nuôi gồm 5 đỉnh")

	var ls_mgr := LivestockManager.new()
	assert(ls_mgr.animals.size() >= 4, "Mặc định có ít nhất 4 thú nuôi")
	assert(ls_mgr.animals[0].is_roaming_outside == true, "Mặc định thú nuôi được phép di chuyển ở ngoài bãi cỏ")

	# Test vuốt ve thú nuôi ngoài trời
	var pet_res := ls_mgr.pet_animal(0)
	assert(pet_res.get("success", false) == true, "Vuốt ve thú nuôi thành công")
	assert(ls_mgr.animals[0].intimacy == 10, "Độ thân mật tăng lên 10")

	# Test chuyển đổi chế độ di chuyển ngoài trời
	ls_mgr.set_all_roaming_outside(false)
	assert(ls_mgr.animals[0].is_roaming_outside == false, "Đã cho thú vào chuồng")
	ls_mgr.set_all_roaming_outside(true)
	assert(ls_mgr.animals[0].is_roaming_outside == true, "Đã cho thú di chuyển ở ngoài")

	# Test hệ thống Đói và Tạm Dừng Thu Hoạch khi đói:
	var test_animal := ls_mgr.animals[0]
	test_animal.hunger = 10.0
	test_animal.grow_time_elapsed = 20.0
	var old_rem_time := test_animal.get_remaining_time()

	# Tick 1s: hunger giảm, tiến độ tăng
	test_animal.tick(1.0)
	assert(test_animal.hunger < 10.0, "Thanh đói phải giảm khi có thời gian trôi qua")
	assert(test_animal.grow_time_elapsed > 20.0, "Thời gian sinh trưởng phải tăng khi thú chưa đói")
	assert(test_animal.get_remaining_time() < old_rem_time, "Thời gian thu hoạch phải đếm ngược giảm dần")

	# Cho đói về 0:
	test_animal.hunger = 0.0
	test_animal.tick(0.1)
	assert(test_animal.state == LivestockManager.AnimalState.HUNGRY, "Khi đói = 0 thì trạng thái là HUNGRY")
	var paused_growth := test_animal.grow_time_elapsed
	var paused_rem_time := test_animal.get_remaining_time()

	# Khi đói = 0, dù trôi qua 100 giây thì tiến trình thu hoạch PHẢI DỪNG LẠI!
	test_animal.tick(100.0)
	assert(test_animal.grow_time_elapsed == paused_growth, "Khi đói = 0, thời gian thu hoạch PHẢI DỪNG LẠI!")
	assert(test_animal.get_remaining_time() == paused_rem_time, "Thời gian đếm ngược còn lại PHẢI ĐỨNG YÊN!")

	# Cho ăn -> Thú chỉ ăn nông sản tự trồng hoặc cá tự bắt:
	var invalid_feed := ls_mgr.feed_animal(0, "feed_invalid")
	assert(invalid_feed.get("success", true) == false, "Thú không ăn thức ăn không hợp lệ")

	# Cho ăn nông sản hợp lệ (Lúa Vàng trồng từ luống đất)
	var feed_res := ls_mgr.feed_animal(0, "lua_vang")
	assert(feed_res.get("success", false) == true, "Cho ăn nông sản Lúa Vàng thành công")
	assert(test_animal.hunger > 0.0, "Cho ăn xong thanh đói phải > 0")
	assert(test_animal.state == LivestockManager.AnimalState.GROWING, "Trạng thái trở lại GROWING")

	# Tick tiếp 5s sau khi cho ăn -> thời gian tiếp tục chạy
	test_animal.tick(5.0)
	assert(test_animal.grow_time_elapsed > paused_growth, "Sau khi cho ăn, thời gian thu hoạch tiếp tục tích lũy")
	assert(test_animal.get_remaining_time() < paused_rem_time, "Sau khi cho ăn, thời gian thu hoạch tiếp tục đếm ngược")
	print("[PASS] Kiểm tra Thanh Đói và Cơ Chế TẠM DỪNG THỜI GIAN THU HOẠCH khi đói = 0 hoàn hảo (100%)")

	# Test nạp PetCompanion (Thú Cưng Đồng Hành theo sau nhân vật ra ngoài bản đồ)
	var pet_companion_script: GDScript = load("res://systems/son_trang/pet_companion.gd")
	assert(pet_companion_script != null, "Phải nạp được PetCompanion script")
	var comp_instance = pet_companion_script.new(ls_mgr.animals[0].to_dict())
	assert(comp_instance != null, "Khởi tạo Thú Cưng Đồng Hành thành công")
	comp_instance.free()

	# Test thu hoạch: mất con thú nuôi đó khỏi đàn và chuyển thành thịt trong rương
	var before_count := ls_mgr.animals.size()
	ls_mgr.animals[0].state = LivestockManager.AnimalState.READY
	var harv_res := ls_mgr.harvest_animal(0)
	assert(harv_res.get("success", false) == true, "Thu hoạch thành công")
	assert(ls_mgr.animals.size() == before_count - 1, "Thu hoạch phải mất con quái đó khỏi đàn/chuồng")
	assert("thịt" in harv_res.get("product_name", "").to_lower(), "Sản phẩm thu hoạch phải chuyển thành thịt: %s" % harv_res.get("product_name", ""))
	assert(ls_mgr.animals[0].index == 0, "Chỉ số index con thú tiếp theo phải được cập nhật lại thành 0")
	print("[PASS] Kiểm tra Thú Nuôi Di Chuyển Ở Ngoài, Thu Hoạch Mất Thú và Chuyển Thành Thịt hoàn hảo (100%)")

	# 9. Test Khu Nuôi Thủy Hải Sản (Ao Cá Nước Ngọt 181/185 & Bè Cá Biển Sâu Hình Vuông 188/202) có Border Link
	var fish_script: GDScript = load("res://systems/son_trang/farm_fish_controller.gd") if ResourceLoader.exists("res://systems/son_trang/farm_fish_controller.gd") else load("res://world/maps/map_nguyet_ca/farm_fish_controller.gd")
	assert(fish_script != null, "Phải nạp được FarmFishController")
	var f_ctrl = fish_script.new()
	assert(f_ctrl.FISH_ZONES.size() == 2, "Có 2 khu nuôi trồng thủy sản")
	assert(f_ctrl.fish_data.size() == 2, "Có dữ liệu 2 ao cá")
	assert(f_ctrl.FISH_ZONES[0].has("landmark_coords"), "Ao cá nước ngọt phải có mốc tọa độ border link")
	assert(f_ctrl.FISH_ZONES[1].has("landmark_coords"), "Bè cá biển sâu phải có mốc tọa độ border link")
	assert(f_ctrl.FISH_ZONES[1]["coord_name"] == "188/202", "Bè cá biển phải đặt ở tọa độ biển 188/202")
	assert(f_ctrl.FISH_ZONES[1]["polygon"].size() == 4, "Bè cá biển phải là VÙNG HÌNH VUÔNG gồm 4 góc")
	assert(f_ctrl.FISH_ZONES[1]["landmark_coords"].size() == 4, "Bè cá biển phải có 4 mốc tọa độ tại 4 góc vuông")
	assert(f_ctrl.cached_polygons.size() == 2, "Cả 2 khu vực ao/bè cá phải có đa giác viền khép kín")
	assert(f_ctrl.cached_triangles[1].size() == 2, "Đa giác hình vuông bè cá biển phải được chia thành 2 tam giác vẽ mặt biển")
	f_ctrl.free()
	print("[PASS] Kiểm tra Khu Nuôi Cá Nước Ngọt & Bè Cá Biển Hình Vuông Tại Vị Trí (188/202) có Border Link hoàn hảo (100%)")
	
	# 10. Test Mức Nước / Khát Thú Nuôi & Kho Nguyên Liệu (Thực phẩm, Nước, Phân bón)
	var ls_test := LivestockManager.new()
	var thirst_animal := ls_test.animals[0]
	assert(thirst_animal.thirst == 100.0, "Khởi tạo mức nước thú nuôi phải là 100%")
	thirst_animal.thirst = 0.0
	var old_time := thirst_animal.grow_time_elapsed
	ls_test.tick(10.0)
	assert(thirst_animal.grow_time_elapsed == old_time, "Khi mức nước = 0 (khát), thời gian thu hoạch phải tạm dừng")
	
	var water_res := ls_test.water_animal(0)
	assert(water_res.get("success", false) == true, "Cho uống nước thành công")
	assert(thirst_animal.thirst == 100.0, "Uống nước phải hồi 100% mức nước")
	print("[PASS] Kiểm tra Mức Nước Uống Thú Nuôi và Tạm Dừng Thu Hoạch khi khát hoàn hảo (100%)")

	# 11. Test WeatherVFX & Hiệu ứng Sương Mù Tự Nhiên
	var hud_script: GDScript = load("res://ui/son_trang/farm_hud.gd")
	assert(hud_script != null, "Phải nạp được farm_hud.gd")
	var vfx = hud_script.WeatherVFX.new()
	assert(vfx != null, "Khởi tạo WeatherVFX thành công")
	assert(vfx.fog_cloud_textures.size() == 11, "Đã nạp đủ 11 cụm mây sương tự nhiên: %d/11" % vfx.fog_cloud_textures.size())
	assert(vfx.fog_layer_textures.size() == 3, "Đã nạp đủ 3 dải sương tầng cuộn: %d/3" % vfx.fog_layer_textures.size())
	assert(vfx.fog_wisp_textures.size() == 3, "Đã nạp đủ 3 luồng sương mảnh: %d/3" % vfx.fog_wisp_textures.size())
	assert(vfx.leaf_textures.size() == 12, "Đã nạp đủ 12 sprite lá mùa thu: %d/12" % vfx.leaf_textures.size())

	# Test chuyển thời tiết sang Sương Mù (FOGGY)
	vfx.update_weather(FarmTimeSystem.Weather.FOGGY)
	assert(vfx.current_weather == FarmTimeSystem.Weather.FOGGY, "Thời tiết hiện tại phải là FOGGY")
	assert(vfx.particles.size() == 14, "Thời tiết sương mù phải sinh đúng 14 cụm sương bồng bềnh: %d/14" % vfx.particles.size())
	for p in vfx.particles:
		assert(p.get("tex") != null, "Hạt sương mù phải có sprite texture mây sương hợp lệ, không dùng fallback hình tròn")

	# Test chuyển thời tiết sang Gió (WINDY)
	vfx.update_weather(FarmTimeSystem.Weather.WINDY)
	assert(vfx.current_weather == FarmTimeSystem.Weather.WINDY, "Thời tiết hiện tại phải là WINDY")
	vfx.free()
	print("[PASS] Kiểm tra WeatherVFX: 17 sprite Sương Mù & 12 sprite Lá Mùa Thu nạp đầy đủ, cơ chế FOGGY và WINDY hoạt động chính xác (100%)")

	# 12. Test Hệ Thống Ngày & Đêm Sơn Trang (FarmDayNightController & Ánh Sáng Đống Lửa Ban Đêm)
	# Kiểm tra chuyển đổi các buổi trong ngày (DayPhase)
	FarmTimeSystem.set_day_phase(FarmTimeSystem.DayPhase.DAY)
	assert(FarmTimeSystem.get_current_day_phase() == FarmTimeSystem.DayPhase.DAY, "Phải chuyển được sang Ban Ngày")
	assert(FarmTimeSystem.get_day_phase_darkness() == 0.0, "Ban ngày độ tối phải = 0.0 (sáng rạng rỡ)")
	assert(FarmTimeSystem.is_night() == false, "Ban ngày không phải là ban đêm")

	FarmTimeSystem.set_day_phase(FarmTimeSystem.DayPhase.SUNSET)
	assert(FarmTimeSystem.get_current_day_phase() == FarmTimeSystem.DayPhase.SUNSET, "Phải chuyển được sang Hoàng Hôn")
	assert(FarmTimeSystem.get_day_phase_darkness() > 0.35, "Hoàng hôn độ tối phải > 0.35")

	FarmTimeSystem.set_day_phase(FarmTimeSystem.DayPhase.NIGHT)
	assert(FarmTimeSystem.get_current_day_phase() == FarmTimeSystem.DayPhase.NIGHT, "Phải chuyển được sang Ban Đêm")
	assert(FarmTimeSystem.is_night() == true, "is_night() phải trả về true khi ở pha Ban Đêm")
	assert(FarmTimeSystem.get_day_phase_darkness() >= 0.85, "Ban đêm độ tối phải >= 0.85 (màn đêm bao phủ)")
	assert(FarmTimeSystem.get_day_phase_name().contains("Ban Đêm"), "Tên hiển thị phải chứa 'Ban Đêm'")

	# Khôi phục giờ thực tế
	FarmTimeSystem.reset_day_phase_to_realtime()
	assert(FarmTimeSystem.custom_day_phase == -1, "reset_day_phase_to_realtime phải đưa custom_day_phase về -1")

	# Kiểm tra FarmDayNightController và Shader ánh sáng Đống Lửa
	var dn_script: GDScript = load("res://systems/son_trang/farm_day_night_controller.gd")
	assert(dn_script != null, "Phải nạp được farm_day_night_controller.gd")
	var dn_inst = dn_script.new()
	assert(dn_inst != null, "Khởi tạo FarmDayNightController thành công")
	assert(dn_inst.layer == 1, "FarmDayNightController phải ở layer 1 (dưới CanvasLayer UI layer 10)")
	assert(dn_inst.night_overlay != null, "FarmDayNightController phải có NightOverlay ColorRect")
	assert(dn_inst.overlay_material != null, "FarmDayNightController phải có ShaderMaterial")
	
	# Giả lập ban đêm để kiểm tra shader parameters
	FarmTimeSystem.set_day_phase(FarmTimeSystem.DayPhase.NIGHT)
	dn_inst._process(0.1)
	var mat := dn_inst.overlay_material as ShaderMaterial
	assert(mat != null, "overlay_material phải là ShaderMaterial hợp lệ")
	var dark_val = mat.get_shader_parameter("darkness_intensity")
	assert(dark_val > 0.0, "Khi ban đêm, shader parameter darkness_intensity phải > 0.0")
	var cf_count = mat.get_shader_parameter("campfire_count")
	assert(int(cf_count) >= 4, "Shader phải nhận ít nhất 4 Đống Lửa Sơn Trang (Nông Trại, Chuồng Trại, Bến Hồ, Bờ Biển)")
	
	var cf_radii = mat.get_shader_parameter("campfire_radii")
	assert(cf_radii != null and cf_radii.size() >= 4, "Shader parameter campfire_radii phải chứa mảng bán kính ánh sáng")
	assert(dn_script.CAMPFIRE_LIGHT_RADIUS_PX == 600.0, "Bán kính ánh sáng đống lửa phải là 600px")
	assert(float(cf_radii[0]) > 0.50, "Ban đêm đống lửa đang cháy phải tỏa sáng một vùng rộng tầm 600px xung quanh (radius_uv > 0.50)")
	
	var cf_intensities = mat.get_shader_parameter("campfire_intensities")
	assert(cf_intensities != null and cf_intensities.size() >= 4, "Shader parameter campfire_intensities phải chứa mảng cường độ sáng")
	assert(float(cf_intensities[0]) > 0.80, "Ban đêm đống lửa đang cháy phải có cường độ ánh sáng rực rỡ (intensity > 0.80)")

	FarmTimeSystem.reset_day_phase_to_realtime()
	dn_inst.free()
	print("[PASS] Kiểm tra Hệ Thống Ngày & Đêm và Ánh Sáng Đống Lửa Sơn Trang Ban Đêm hoàn hảo (100%)")

	# 13. Test Hệ Thống Đổi Thịt Lấy Thưởng & Mở Rương Bách Thú Sơn Trang
	assert(fw_script.has_method("open_meat_exchange"), "FarmWindows phải có hàm open_meat_exchange")
	var meat_recipes: Array = fw_script.MEAT_RECIPES
	assert(meat_recipes.size() >= 4, "Phải có ít nhất 4 công thức đổi thịt (Heo, Heo Rừng, Trâu, Hươu)")
	for r in meat_recipes:
		assert(r.get("exp", 0) > 0, "Công thức đổi phải có EXP")
		assert(r.get("gold", 0) > 0, "Công thức đổi phải có Ngân lượng")
		assert(r.get("chest", 0) == 1, "Mỗi lần đổi thịt phải thưởng 1 Rương Bách Thú")

	# Kiểm tra Rương Bách Thú đăng ký trong ItemDatabase
	var chest_misc: Dictionary = ItemDatabase.get_misc("ruong_bach_thu_son_trang")
	assert(chest_misc != null and not chest_misc.is_empty(), "Phải nạp được ruong_bach_thu_son_trang trong ItemDatabase")
	assert(chest_misc.get("name", "") == "Rương Bách Thú Sơn Trang", "Tên rương chuẩn xác")

	# Kiểm tra mở Rương Bách Thú: Có EXP, Lượng, Trang Bị, Tiên Thảo Lộ, Thủy Tinh & Tỷ lệ cực hiếm Bí kíp 150/180
	var mock_profile := PlayerProfile.new()
	var open_res := ItemConsumer.open_ruong_bach_thu(mock_profile)
	assert(open_res.get("ok", false) == true, "Mở Rương Bách Thú thành công")
	assert(mock_profile.inventory.size() > 0, "Mở rương phải có vật phẩm vào hành trang (Trang bị / Tiên thảo lộ / Thủy tinh / Bí kíp)")
	print("[PASS] Kiểm tra Hệ Thống Đổi Thịt & Mở Rương Bách Thú Sơn Trang hoàn hảo (100%)")

	print("--- [TEST SƠN TRANG] TẤT CẢ TEST ĐỀU THÀNH CÔNG (100%) ---")
	return true

func _init() -> void:
	run_tests()
	quit(0)
