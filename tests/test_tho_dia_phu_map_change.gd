extends Node

func _ready() -> void:
	print("\n--- TEST BẮT ĐẦU: THỔ ĐỊA PHÙ KHI CHUYỂN MAP / ẢI LUYỆN ---")
	
	# 1. Tạo profile và nạp vào GameManager.local_profile
	var p := PlayerProfile.new()
	p.display_name = "DaiHiepTest"
	p.level = 50
	p.gold = 100000
	GameManager.local_profile = p
	
	# 2. Mua Thổ Địa Phù trong Hiệu Thuốc (5_0_0)
	var buy_res := PotionShop.buy(p, "5_0_0", 5)
	print("[1] Mua 5 Thổ Địa Phù tại Hiệu Thuốc: ", buy_res)
	assert(buy_res["ok"] == true, "Mua Thổ Địa Phù phải thành công")
	
	var count_tdp := PotionEffect.count_in_inventory(p, "5_0_0")
	print("[2] Số lượng Thổ Địa Phù trong túi sau khi mua: ", count_tdp)
	assert(count_tdp == 5, "Trong túi phải có 5 Thổ Địa Phù")
	
	# 3. Test serialization (to_dict / from_dict)
	var dict_data := p.to_dict()
	var loaded_p := PlayerProfile.from_dict(dict_data)
	var count_after_load := PotionEffect.count_in_inventory(loaded_p, "5_0_0")
	print("[3] Số lượng Thổ Địa Phù sau khi serialize to_dict / from_dict: ", count_after_load)
	assert(count_after_load == 5, "Serialization không được làm mất Thổ Địa Phù")
	
	# 4. Test SaveManager save & load
	SaveManager.save_profile(p)
	var reloaded_p := SaveManager.load_profile()
	var count_after_file := PotionEffect.count_in_inventory(reloaded_p, "5_0_0")
	print("[4] Số lượng Thổ Địa Phù sau khi SaveManager.save_profile & load_profile: ", count_after_file)
	assert(count_after_file == 5, "Lưu file không được làm mất Thổ Địa Phù")

	# 5. Test copy_from
	var fresh_p := PlayerProfile.new()
	fresh_p.copy_from(reloaded_p)
	var count_after_copy := PotionEffect.count_in_inventory(fresh_p, "5_0_0")
	print("[5] Số lượng Thổ Địa Phù sau khi copy_from: ", count_after_copy)
	assert(count_after_copy == 5, "copy_from không được làm mất Thổ Địa Phù")
	
	# 6. Test ProfileGuard.merge (ONLINE MODE)
	# Giả sử client mua ở Hub hoặc trong map, server_data chưa có hoặc đã có
	var server_dict := p.to_dict()
	# Xoá Thổ địa phù khỏi server_dict để giả lập trường hợp server_data không có uid này (nếu mua ở client)
	var s_inv: Array = []
	for it in server_dict["inventory"]:
		if str(it.get("mid", "")) != "5_0_0":
			s_inv.append(it)
	server_dict["inventory"] = s_inv
	
	var merged := ProfileGuard.merge(server_dict, p.to_dict(), 0, false)
	var merged_p := PlayerProfile.from_dict(merged)
	var count_after_merge := PotionEffect.count_in_inventory(merged_p, "5_0_0")
	print("[6] Khi server_data chưa biết Thổ Địa Phù, ProfileGuard.merge trả về số lượng: ", count_after_merge)
	assert(count_after_merge == 5, "ProfileGuard.merge phải giữ lại Thổ Địa Phù hợp lệ từ PotionShop")

	# 7. Test ItemConsumer.is_town_portal
	var it_tdp := ItemGenerator.generate_misc("5_0_0")
	assert(ItemConsumer.is_town_portal(it_tdp), "ItemConsumer phải nhận diện 5_0_0 là town portal")
	
	# 8. Test sử dụng Thổ Địa Phù trong Stage Mode
	GameManager.game_mode = GameManager.GameMode.STAGE
	var count_before_use := PotionEffect.count_in_inventory(p, "5_0_0")
	# Tạo dummy player node trong tree
	var dummy_player := Node2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group("player")
	add_child(dummy_player)
	
	# Giả lập dùng 1 Thổ Địa Phù
	var use_res := ItemConsumer.use_item(p, p.inventory[0], dummy_player, self)
	print("[8] Kết quả dùng Thổ Địa Phù trong Stage: ", use_res)
	assert(use_res["ok"] == true, "Dùng Thổ Địa Phù phải thành công")
	assert(use_res["exit_to_hub"] == true, "Dùng Thổ Địa Phù phải kích hoạt thoát về hub")
	
	var count_after_use := PotionEffect.count_in_inventory(p, "5_0_0")
	print("[9] Số lượng Thổ Địa Phù còn lại sau khi dùng 1 cái: ", count_after_use)
	assert(count_after_use == count_before_use - 1, "Thổ Địa Phù phải bị trừ đúng 1 cái và không bị rollback mất sạch")

	print("--- KẾT THÚC TEST THÀNH CÔNG ---")
	get_tree().quit(0)
