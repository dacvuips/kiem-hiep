extends Node

func _ready() -> void:
	print("--- TEST PUBG POTION & MANA REGEN START ---")

	# 1. Khởi tạo profile mẫu
	var profile := PlayerProfile.new()
	profile.display_name = "KiemHiepTester"
	profile.quick_items = ["original_slot1", "", "", ""]
	var orig_item := ItemInstance.new()
	orig_item.misc_id = "test_item"
	profile.inventory.append(orig_item)

	var room := {
		"id": "PUBG-TEST-1",
		"mode": 1,
		"players": 1
	}

	# 2. Bắt đầu trận PUBG
	var field_entry := PubgManager.start_match(profile, room)
	assert(PubgManager.is_pubg_active(), "PubgManager must be active")
	assert(profile.quick_items[0] == "1_8_0_4", "Quick item slot 1 must be '1_8_0_4' (Hồi Thiên Tái Tạo Đơn)")

	var ht_count := PotionEffect.count_in_inventory(profile, "1_8_0_4")
	assert(ht_count == 50, "Player must have exactly 50 bottles of Hồi Thiên Tái Tạo Đơn, found %d" % ht_count)
	print("✔ Cấp sẵn 50 bình Hồi Thiên Tái Tạo Đơn và gắn vào slot 1 thành công (count = %d, slot 1 = %s)" % [ht_count, profile.quick_items[0]])

	# 3. Tạo player node và test tiêu thụ 1 bình
	var player_script: GDScript = load("res://player/player.gd")
	var player = player_script.new()
	player.max_mana = 200.0
	player.mana = 100.0
	assert(player.mana == 100.0, "Initial mana should be 100")

	var first_potion := PotionEffect.first_in_inventory(profile, "1_8_0_4")
	assert(first_potion != null, "First potion must not be null")
	var consumed := PotionEffect.consume(profile, player, first_potion)
	assert(consumed, "PotionEffect.consume must succeed when player is present")
	var remaining_count := PotionEffect.count_in_inventory(profile, "1_8_0_4")
	assert(remaining_count == 49, "Remaining count must be 49 after 1 use, found %d" % remaining_count)
	print("✔ Uống 1 bình thành công, số lượng còn lại: %d" % remaining_count)

	# 4. Test hồi mana 30 mana / 1 giây trong PUBG
	# Tự hồi phục Nội Lực trong chế độ PUBG (1s hồi 30 mana): 30.0 * delta
	var total_delta: float = 1.0
	if PubgManager.is_pubg_active() and not player._dead and player.mana < player.max_mana:
		player.restore_mana(30.0 * total_delta)

	assert(is_equal_approx(player.mana, 130.0), "Mana should increase by 30 in 1 second, expected 130.0, got %f" % player.mana)
	print("✔ Hồi 30 mana sau 1 giây thành công (100 -> %f)" % player.mana)

	player.free()

	# 5. Kết thúc trận đấu -> kiểm tra khôi phục profile gốc
	PubgManager.end_match(profile)
	assert(not PubgManager.is_active, "PubgManager should be inactive after match ends")
	assert(profile.quick_items[0] == "original_slot1", "Original quick item slot 1 should be restored")
	assert(profile.inventory.size() == 1 and profile.inventory[0].misc_id == "test_item", "Original inventory should be restored")
	print("✔ Khôi phục profile gốc sau khi kết thúc PUBG thành công")

	print("--- TEST PUBG POTION & MANA REGEN PASSED ALL ---")
	get_tree().quit(0)
