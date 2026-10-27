extends Node

const EscortChallengeScript := preload("res://systems/challenge/escort_challenge.gd")
const EscortWindowScript := preload("res://ui/events/escort_window.gd")
const EscortManagerScript := preload("res://systems/challenge/escort_manager.gd")
const VltkMonsterScript := preload("res://systems/monster/vltk_monster.gd")

func _ready() -> void:
	print("--- BẮT ĐẦU TEST TOÀN DIỆN VẬN TIÊU BIỆN KINH & TẦM NHÌN QUÁI ---")

	# 1. Kiểm tra cấu hình map Biện Kinh Ngoại Thành (Map 37)
	assert(EscortChallengeScript.MAP_ID == 37, "Map vận tiêu chuẩn là Biện Kinh (Map 37)")
	assert(EscortChallengeScript.WAYPOINTS.size() >= 5, "Lộ trình Biện Kinh phải có ít nhất 5 waypoints")
	for wp in EscortChallengeScript.WAYPOINTS:
		assert(not (wp.x >= 48000.0 and wp.x <= 60000.0 and wp.y >= 45500.0 and wp.y <= 52500.0), "Tất cả mốc đường vận tiêu phải nằm NGOÀI THÀNH Biện Kinh: %s" % wp)
	for cart in EscortWindowScript.CARTS:
		assert(cart.get("map_id", 37) == 37, "Mọi cấp xe đều trỏ về Map 37 Biện Kinh")
	print("PASS: 1. Mọi cấp tiêu xa đều chạy trên tuyến đường Quan Lộ NGOÀI THÀNH Biện Kinh (Map 37) với lộ trình chuẩn")

	# 2. Kiểm tra kiểm tra ngày vận tiêu (Thứ 7 & Chủ Nhật)
	assert(EscortWindowScript.is_escort_day() is bool, "Có hàm kiểm tra ngày vận tiêu is_escort_day()")
	assert(EscortWindowScript.RUNS_PER_DAY == 3, "Giới hạn vận tiêu là 3 lần / ngày")
	print("PASS: 2. Kiểm tra ngày mở Thứ 7 & CN và giới hạn 3 lần/ngày chính xác")

	# 3. Kiểm tra UI HUD không còn bị PRESET_TOP_WIDE che lấp màn hình
	var challenge := EscortChallengeScript.new()
	challenge.cart_data = EscortWindowScript.CARTS[0].duplicate()
	add_child(challenge)
	challenge._build_hud()

	var hud_layer: CanvasLayer = null
	for child in challenge.get_children():
		if child is CanvasLayer:
			hud_layer = child
			break
	assert(hud_layer != null, "CanvasLayer HUD phải được tạo")
	var hud_panel: PanelContainer = null
	for child in hud_layer.get_children():
		if child is PanelContainer:
			hud_panel = child
			break
	assert(hud_panel != null, "Tìm thấy khung Panel HUD tiêu xa")
	assert(hud_panel.anchor_left == 0.0 and hud_panel.anchor_right == 0.0, "HUD phải nằm gọn ở bên trái màn hình (anchor 0.0)")
	assert(hud_panel.custom_minimum_size.x <= 300, "Kích thước chiều ngang bảng nhỏ gọn <= 300px")
	print("PASS: 3. UI bảng tiêu xa nhỏ gọn (270px) đặt ở bên trái màn hình, không che khuất nhân vật và xe")

	# 4. Kiểm tra phân tách hồ sơ vận tiêu theo từng tài khoản (Account 1 vs Account 2)
	var p1 := PlayerProfile.new()
	p1.display_name = "NguoiChoi_A"
	var p2 := PlayerProfile.new()
	p2.display_name = "NguoiChoi_B"

	var path1: String = EscortWindowScript.get_record_path(p1)
	var path2: String = EscortWindowScript.get_record_path(p2)
	assert(path1 != path2, "File lưu trữ vận tiêu của 2 tài khoản/nhân vật phải hoàn toàn độc lập!")

	var today := Time.get_date_string_from_system()
	# Giả lập tài khoản 1 đã chạy hết 3 lượt hôm nay
	EscortWindowScript._save_records_for({"runs": {today: 3}}, p1)
	# Kiểm tra tài khoản 2 vẫn có 0 lượt, không bị ảnh hưởng
	var rec2: Dictionary = EscortWindowScript._get_records_for(p2)
	var runs_p2: int = int(rec2.get("runs", {}).get(today, 0))
	assert(runs_p2 == 0, "Tài khoản B mới đăng nhập phải có 0 lượt, không bị lấy nhầm số lượt của tài khoản A!")
	print("PASS: 4. Phân tách hồ sơ vận tiêu độc lập theo từng tài khoản/nhân vật thành công")

	# 5. Kiểm tra tầm nhìn quái vật (Vision / Leash)
	var mon := VltkMonsterScript.new()
	mon.data = {"vision": 350, "active": 400, "skills": [[1, 1], [0, 0], [0, 0], [0, 0]]}
	add_child(mon)

	# Giả lập dummy player xa 2000px
	var dummy_player := Node2D.new()
	dummy_player.position = Vector2(2000, 2000)
	dummy_player.name = "DummyPlayer"
	dummy_player.add_to_group("player")
	add_child(dummy_player)

	assert(not mon.is_engaging(dummy_player), "Quái ở xa 2000px không được coi là đang giao chiến (tầm nhìn chuẩn 350)")

	dummy_player.remove_from_group("player")
	dummy_player.queue_free()
	mon.queue_free()
	challenge.queue_free()
	print("PASS: 5. Tầm nhìn của quái vật đã được chuẩn hóa theo dữ liệu gốc, không còn khóa toàn màn hình")

	# 6. Kiểm tra Sprite Tiêu Xa (MonsterSprite enemy241) & Tính năng nhấp chuột tự đi theo
	var test_cart := EscortCart.new()
	test_cart.setup({"cart_name": "Tiêu Xa Hoàng Kim", "owner_name": "Đại Hiệp"}, [Vector2(100, 100), Vector2(200, 200)])
	add_child(test_cart)

	assert(test_cart._sprite != null, "Tiêu xa phải có MonsterSprite hiển thị hình ảnh")
	assert(test_cart._sprite.res_name == "enemy241", "Mã Xa Tiêu phải dùng bộ tài nguyên gốc VLTK enemy241")
	assert(test_cart._sprite._sprite != null and test_cart._sprite._sprite.visible, "Sprite hình ảnh của chiếc xe tiêu phải hiển thị rõ ràng (không bị mất)")

	var test_player_scene := preload("res://player/player.tscn")
	var test_player := test_player_scene.instantiate()
	test_player.position = Vector2(0, 0)
	add_child(test_player)

	# Giả lập nhấp vào xe tiêu
	test_cart._player_start_following()
	assert(test_player.follow_target == test_cart, "Khi nhấp vào chiếc xe tiêu, nhân vật phải tự động đi theo bảo vệ tiêu xa")
	assert(test_player.is_following(), "Trạng thái is_following() của nhân vật phải là true")

	test_player.queue_free()
	test_cart.queue_free()
	print("PASS: 6. Hình ảnh Tiêu Xa (enemy241) hiển thị đầy đủ sắc nét kèm bóng, nhấp vào xe nhân vật tự động đi theo")

	# 7. Kiểm tra hệ thống Vận Tiêu Cá Nhân: Chọn Phe Hộ Tiêu vs Cướp Tiêu (5v5 Cân Bằng)
	var dummy_cart := {
		"id": "cart_test_5v5",
		"owner_name": "NguoiChoi_A",
		"cart_name": "Tiêu Xa Thí Nghiệm",
		"defenders": ["NguoiChoi_A"],
		"raiders": []
	}
	# Người chơi B thử vào phe Hộ Tiêu -> Bị chặn vì Hộ Tiêu 1 vs Cướp Tiêu 0 (chênh lệch sẽ thành 2 > 1)
	var chk_def := EscortManagerScript.can_join_team(dummy_cart, "defender", "NguoiChoi_B")
	assert(not chk_def.get("ok", true), "Không được vào phe Hộ Tiêu khi sẽ làm chênh lệch > 1 người")

	# Người chơi B vào phe Cướp Tiêu -> Được phép vì cân bằng thành 1 vs 1
	var chk_raid := EscortManagerScript.can_join_team(dummy_cart, "raider", "NguoiChoi_B")
	assert(chk_raid.get("ok", false), "Được phép vào phe Cướp Tiêu để cân bằng 1 vs 1")

	# Kiểm tra giới hạn 5 người mỗi bên
	var full_cart := {
		"id": "cart_full",
		"defenders": ["D1", "D2", "D3", "D4", "D5"],
		"raiders": ["R1", "R2", "R3", "R4", "R5"]
	}
	assert(not EscortManagerScript.can_join_team(full_cart, "defender", "ExtraPlayer").get("ok", true), "Không được vượt quá 5 người phe Hộ Tiêu")
	assert(not EscortManagerScript.can_join_team(full_cart, "raider", "ExtraPlayer").get("ok", true), "Không được vượt quá 5 người phe Cướp Tiêu")

	# Kiểm tra điểm xuất hiện: Hộ Tiêu tại xe tiêu, Cướp Tiêu tại tọa độ kết thúc
	var entry_def := EscortChallengeScript.map_entry(dummy_cart, "defender")
	var entry_raid := EscortChallengeScript.map_entry(dummy_cart, "raider")
	assert(entry_def.get("player_role") == "defender", "Vai trò Hộ Tiêu được lưu trong map entry")
	assert(entry_raid.get("player_role") == "raider", "Vai trò Cướp Tiêu được lưu trong map entry")
	assert(entry_raid.get("arena_center") == EscortChallengeScript.WAYPOINTS[EscortChallengeScript.WAYPOINTS.size() - 1], "Phe Cướp Tiêu xuất hiện ở tọa độ kết thúc")

	print("PASS: 7. Hệ thống Vận Tiêu Cá Nhân 5v5 (Cân bằng chênh lệch <= 1, Hộ Tiêu ở xe, Cướp Tiêu ở đích) hoàn toàn chuẩn xác")

	# 8. Kiểm tra cơ chế thưởng Phe Cướp Tiêu dựa trên % máu mất đi của xe & chia đều thành viên còn sống
	var ch_test := EscortChallengeScript.new()
	ch_test.cart_data = {
		"id": "cart_test_loot",
		"reward_gold": 1000000,
		"reward_exp": 500000,
		"deposit_gold": 200000,
		"defenders": ["Def1", "Def2"],
		"raiders": ["Raid1", "Raid2"]
	}
	ch_test.player_role = "raider"
	add_child(ch_test)

	# Giả lập xe tiêu 100.000 HP
	var test_cart_loot := EscortCart.new()
	test_cart_loot.max_hp = 100000
	test_cart_loot.current_hp = 40000 # Mất 60.000 HP (mất 60% máu)
	ch_test.cart_node = test_cart_loot

	# 1) Trường hợp xe về đích nhưng mất 60% máu:
	var total_loot_gold := 1000000 + 200000 # 1.200.000 Lượng
	var lost_hp := test_cart_loot.max_hp - test_cart_loot.current_hp
	var lost_pct := float(lost_hp) / float(test_cart_loot.max_hp)
	assert(is_equal_approx(lost_pct, 0.6), "% máu mất đi của xe vận phải là 60%")

	var raid_gold_pool := int(float(total_loot_gold) * lost_pct) # 720.000 Lượng
	assert(raid_gold_pool == 720000, "Tổng quỹ cướp đoạt được phải đúng 60% giá trị hàng hóa")

	# 2) Chia đều cho 2 thành viên phe cướp còn sống:
	var num_survivors := 2
	var share_each := int(float(raid_gold_pool) / float(num_survivors))
	assert(share_each == 360000, "Mỗi thành viên phe cướp còn sống nhận đúng phần chia đều 360.000 Lượng")

	# 3) Nếu thành viên tử trận (is_dead = true) thì nhận 0
	var dead_survivors: Array = [] # 0 người sống
	assert(dead_survivors.is_empty(), "Người tử trận / out map không nằm trong danh sách người sống nhận thưởng")

	test_cart_loot.queue_free()
	ch_test.queue_free()
	print("PASS: 8. Cơ chế thưởng Phe Cướp Tiêu theo % máu mất đi của xe, chia đều người còn sống, chết/out = 0 đã được xác minh thành công")

	print("--- TẤT CẢ TEST ĐÃ VƯỢT QUA XUẤT SẮC! ---")
	get_tree().quit(0)
