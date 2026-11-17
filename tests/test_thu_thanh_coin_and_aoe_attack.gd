extends Node

## TEST SUITE KIỂM THỬ TOÀN DIỆN:
## 1. Quái rơi Xu vàng trên đất và người chơi nhặt Xu (+Xu vào HUD)
## 2. Nhân vật thi triển kỹ năng khi có quái trên hàng
## 3. Kỹ năng bay bám đuổi quái mục tiêu và nổ lan (AoE Splash) xung quanh

const ThuThanhChallengeScript := preload("res://systems/challenge/thu_thanh_challenge.gd")
const ThuThanhMonsterScript := preload("res://systems/challenge/thu_thanh_monster.gd")
const ThuThanhUnitScript := preload("res://systems/challenge/thu_thanh_unit.gd")
const ThuThanhProjectileScript := preload("res://systems/challenge/thu_thanh_projectile.gd")
const ThuThanhCoinScript := preload("res://systems/challenge/thu_thanh_coin.gd")

func _ready() -> void:
	print("=== BẮT ĐẦU TEST: XU RƠI, THI TRIỂN KỸ NĂNG VÀ AOE SPLASH THỦ THÀNH ===")

	var challenge := ThuThanhChallengeScript.new()
	challenge.name = "ThuThanhChallenge"
	add_child(challenge)

	await get_tree().process_frame
	await get_tree().process_frame

	# -------------------------------------------------------------
	# TEST 1: QUÁI CHẾT RƠI XU VÀ NGƯỜI CHƠI NHẶT XU
	# -------------------------------------------------------------
	print("--- TEST 1: RƠI XU VÀ THAO TÁC NHẶT XU ---")
	var initial_coins := challenge.current_coins
	print("Xu khởi đầu: %d" % initial_coins)

	# Sinh 1 quái vật ở ô (row 0, col 5)
	var mon: ThuThanhMonster = ThuThanhMonsterScript.new()
	mon.lane_row = 0
	mon.max_hp = 50.0
	mon.current_hp = 50.0
	mon.xu_drop_amount = 35
	challenge.add_child(mon)
	mon.position = Vector2(500.0, 150.0)

	await get_tree().process_frame

	# Quái nhận sát thương và tử vong
	mon.take_damage(60.0)
	await get_tree().process_frame

	# Kiểm tra đồng xu rơi ra chiến trường
	var coins = get_tree().get_nodes_in_group("thu_thanh_coins")
	assert(not coins.is_empty(), "Phải có đồng xu xuất hiện sau khi quái chết!")
	var dropped_coin: ThuThanhCoin = coins[0] as ThuThanhCoin
	assert(dropped_coin != null, "Đồng xu phải thuộc class ThuThanhCoin!")
	assert(dropped_coin.amount == 35, "Số Xu rơi phải là 35!")
	assert(abs(dropped_coin.position.x - 500.0) < 50.0, "Đồng xu phải ở gần vị trí quái chết (500px), không được bay đi xa!")
	print("✓ Đồng xu xuất hiện đúng vị trí quái tử trận: position = %s, amount = %d" % [dropped_coin.position, dropped_coin.amount])

	# Người chơi chạm / nhặt đồng xu
	dropped_coin.collect()
	await get_tree().process_frame

	assert(challenge.current_coins == initial_coins + 35, "Số Xu của người chơi phải được cộng thêm 35 Xu!")
	print("✓ Nhặt đồng xu thành công! Xu hiện tại: %d (Đã tăng +35)" % challenge.current_coins)

	# -------------------------------------------------------------
	# TEST 2: ĐẶT NHÂN VẬT & THI TRIỂN KỸ NĂNG THEO HÀNG
	# -------------------------------------------------------------
	print("\n--- TEST 2: NHÂN VẬT THI TRIỂN KỸ NĂNG KHI CÓ QUÁI TRÊN HÀNG ---")
	# Đặt hiệp khách Thiếu Lâm ở row 1, col 1
	var skill_tl := ThuThanhSkillData.get_skill("thieu_lam")
	var unit: ThuThanhUnit = ThuThanhUnitScript.new()
	unit.setup(skill_tl, 1, 1)
	challenge.add_child(unit)
	unit.position = Vector2(ThuThanhChallengeScript.ORIGIN_X + 1 * ThuThanhChallengeScript.CELL_W + ThuThanhChallengeScript.CELL_W * 0.5,
							ThuThanhChallengeScript.ORIGIN_Y + 1 * ThuThanhChallengeScript.CELL_H + ThuThanhChallengeScript.CELL_H * 0.5)

	await get_tree().process_frame

	# Chưa có quái trên hàng 1 -> không tấn công
	assert(not unit._has_enemies_in_lane(), "Chưa có quái trên hàng 1 thì không được kích hoạt tấn công!")
	print("✓ Hàng 1 chưa có quái: Nhân vật ở trạng thái sẵn sàng (chưa tấn công)")

	# Quái ở ngoài lằn ranh màu vàng (x > DEFENSE_BOUNDARY_X) -> hiệp khách không đánh quái
	var outside_enemy: ThuThanhMonster = ThuThanhMonsterScript.new()
	outside_enemy.lane_row = 1
	outside_enemy.max_hp = 300.0
	outside_enemy.current_hp = 300.0
	challenge.add_child(outside_enemy)
	outside_enemy.position = Vector2(ThuThanhChallengeScript.DEFENSE_BOUNDARY_X + 50.0, unit.position.y)
	await get_tree().process_frame

	assert(not unit._has_enemies_in_lane(), "Quái ở ngoài lằn ranh thì hiệp khách KHÔNG được tấn công!")
	assert(unit._get_target_enemy_in_lane() == null, "Mục tiêu phải là null khi quái chưa bước qua lằn ranh!")
	outside_enemy.take_damage(50.0)
	assert(outside_enemy.current_hp == 300.0, "Quái chưa bước qua lằn ranh không nhận sát thương!")
	print("✓ Quái ngoài lằn ranh vàng: Hiệp khách không tấn công, quái an toàn")
	outside_enemy.queue_free()
	await get_tree().process_frame

	# Sinh 2 quái trên hàng 1 (1 quái chính ở x = 600, 1 quái bên cạnh ở x = 640)
	var enemy1: ThuThanhMonster = ThuThanhMonsterScript.new()
	enemy1.lane_row = 1
	enemy1.max_hp = 300.0
	enemy1.current_hp = 300.0
	challenge.add_child(enemy1)
	enemy1.position = Vector2(600.0, unit.position.y)

	var enemy2: ThuThanhMonster = ThuThanhMonsterScript.new()
	enemy2.lane_row = 1
	enemy2.max_hp = 300.0
	enemy2.current_hp = 300.0
	challenge.add_child(enemy2)
	enemy2.position = Vector2(645.0, unit.position.y)

	await get_tree().process_frame

	assert(unit._has_enemies_in_lane(), "Đã có quái trên hàng 1: Nhân vật phải phát hiện được quái!")
	var target = unit._get_target_enemy_in_lane()
	assert(target == enemy1, "Mục tiêu phải là quái gần nhất (enemy1 ở x=600)")
	print("✓ Phát hiện quái mục tiêu chính xác trên hàng: enemy1 tại x = %.1f" % target.position.x)

	# -------------------------------------------------------------
	# TEST 3: ĐẠN BAY VÀ NỔ LAN (AOE SPLASH DAMAGE)
	# -------------------------------------------------------------
	print("\n--- TEST 3: CHIÊU THỨC BAY VÀ NỔ LAN (AOE SPLASH) ---")
	var hp_before1 := enemy1.current_hp
	var hp_before2 := enemy2.current_hp

	# Bắn đạn chiêu thức tới enemy1
	unit._spawn_projectile("buddha_palm", 800.0, enemy1, 75.0)

	var found_proj: ThuThanhProjectile = null
	for child in challenge.get_children():
		if child is ThuThanhProjectile:
			found_proj = child
			break

	assert(found_proj != null, "Đạn chiêu thức phải được sinh ra trong challenge!")
	assert(found_proj.position.x > 0 and found_proj.position.x < 1200.0, "Vị trí đạn phải hợp lệ trên bàn cờ!")
	print("✓ Đạn Phật Thủ đã xuất hiện tại position = %s, tốc độ = %.1f" % [found_proj.position, found_proj.speed])

	# Mô phỏng đạn bay tới gần quái mục tiêu
	found_proj.position = enemy1.position - Vector2(10, 0)
	found_proj._process(0.016)

	await get_tree().process_frame

	print("Enemy1 HP: %.1f -> %.1f (Mục tiêu chính nhận 100%% sát thương)" % [hp_before1, enemy1.current_hp])
	print("Enemy2 HP: %.1f -> %.1f (Quái xung quanh nhận sát thương lan AoE)" % [hp_before2, enemy2.current_hp])

	assert(enemy1.current_hp < hp_before1, "Quái mục tiêu chính phải bị trúng sát thương!")
	assert(enemy2.current_hp < hp_before2, "Quái xung quanh trong bán kính nổ phải bị nhận sát thương lan AoE!")
	print("✓ Nổ lan AoE hoạt động hoàn hảo: Cả 2 quái trên hàng đều chịu sát thương từ 1 chiêu thức!")

	# -------------------------------------------------------------
	# TEST 4: TÍNH NĂNG TẠM DỪNG (PAUSE) TRẬN ĐẤU
	# -------------------------------------------------------------
	print("\n--- TEST 4: TẠM DỪNG TRẬN ĐẤU (PAUSE / RESUME) ---")
	challenge.wave_state = "RUNNING"
	assert(not challenge.is_paused, "Ban đầu trận đấu không bị tạm dừng")
	assert(challenge._pause_btn != null, "Phải có nút tạm dừng trên HUD")
	assert(challenge._pause_btn.text == "⏸ Dừng", "Tên nút ban đầu là [⏸ Dừng]")

	# Bấm nút tạm dừng
	challenge._on_pause_toggle_pressed()
	assert(challenge.is_paused, "Trận đấu phải chuyển sang trạng thái tạm dừng!")
	assert(get_tree().paused, "Toàn bộ game tree phải bị tạm dừng!")
	assert(challenge._pause_btn.text == "▶ Tiếp Tục", "Nút đổi thành [▶ Tiếp Tục]")
	assert(challenge._pause_overlay.visible, "Lớp phủ tạm dừng phải hiển thị!")

	# Bấm tiếp tục
	challenge._on_pause_toggle_pressed()
	assert(not challenge.is_paused, "Trận đấu phải tiếp tục!")
	assert(not get_tree().paused, "Toàn bộ game tree được unpause!")
	assert(challenge._pause_btn.text == "⏸ Dừng", "Nút đổi lại thành [⏸ Dừng]")
	assert(not challenge._pause_overlay.visible, "Lớp phủ tạm dừng phải ẩn!")
	print("✓ Tính năng Tạm Dừng [⏸ Dừng] và Tiếp Tục [▶ Tiếp Tục] hoạt động chính xác 100%!")

	print("\n=== TẤT CẢ KIỂM THỬ ĐÃ THÀNH CÔNG 100%! ===")
	get_tree().quit(0)
