extends Node

func _ready() -> void:
	print("\n--- BẮT ĐẦU TEST: QUÁI ƯU TIÊN ĐÁNH BOSS HỖ TRỢ / BOSS ĐỒNG MINH KHI NHÌN THẤY ---\n")

	# 1. Test quái thủ trụ (is_honor_defense_creep): ban đầu nhắm Trụ, khi thấy Boss hỗ trợ phải ưu tiên Boss
	print("[1] Test quái thủ trụ ưu tiên nhắm Boss Hỗ Trợ khi xuất hiện trong tầm nhìn...")
	var pillar := HonorPillar.new()
	pillar.position = Vector2(1000, 1000)
	add_child(pillar)

	var ally_tanker := AllyDefenseBoss.new()
	ally_tanker.setup("tanker", "Thiên Vương Thiết Kỵ", 100, 500000.0, pillar)
	ally_tanker.position = Vector2(800, 1000) # Cách trụ 200px
	add_child(ally_tanker)

	var creep := VltkMonster.new()
	creep.monster_id = 11
	creep.data = MonsterData.monster(11).duplicate()
	creep.level = 50
	creep.ai_enabled = true
	creep.position = Vector2(600, 1000) # Cách ally_tanker 200px (trong tầm nhìn), cách pillar 400px
	creep.is_honor_defense_creep = true
	creep.target = pillar # Ban đầu xuất hiện nhắm Trụ
	add_child(creep)

	# Giả lập 1 nhịp physics process
	creep._physics_process(0.016)

	assert(creep.target == ally_tanker, "Quái thủ trụ phải chuyển mục tiêu sang Boss hỗ trợ (Thiên Vương Thiết Kỵ) thay vì đánh Trụ! Got: %s" % creep.target)
	print("PASS: [1] Quái thủ trụ đã ưu tiên nhắm Boss hỗ trợ thay vì đánh Trụ.")

	# 2. Test ưu tiên Boss hỗ trợ gần nhất khi có nhiều Boss
	print("\n[2] Test ưu tiên Boss hỗ trợ gần nhất khi có nhiều Boss đồng minh...")
	var ally_healer := AllyDefenseBoss.new()
	ally_healer.setup("healer", "Nga Mi Thánh Nữ", 100, 400000.0, pillar)
	ally_healer.position = Vector2(700, 1000) # Cách creep 100px (gần hơn tanker 200px)
	add_child(ally_healer)

	creep._foe_search_timer = 0.0 # Ép quét lại
	creep._physics_process(0.016)

	assert(creep.target == ally_healer, "Quái phải ưu tiên Boss hỗ trợ gần hơn (Nga Mi cách 100px < Thiên Vương cách 200px)! Got: %s" % creep.target)
	print("PASS: [2] Quái đã nhắm Boss hỗ trợ gần nhất.")

	# 3. Test khi Boss hỗ trợ bị tiêu diệt: Quái chuyển mục tiêu sang Boss còn sống hoặc quay về Trụ
	print("\n[3] Test khi Boss hỗ trợ chết: Quái chuyển mục tiêu sang Boss còn lại hoặc Trụ...")
	ally_healer._is_dead = true
	creep._physics_process(0.016)

	assert(creep.target == ally_tanker, "Khi Nga Mi chết, quái phải chuyển sang Thiên Vương Thiết Kỵ còn sống! Got: %s" % creep.target)
	print("PASS: [3.1] Quái chuyển sang Boss hỗ trợ còn sống tiếp theo.")

	ally_tanker._is_dead = true
	creep._physics_process(0.016)

	assert(creep.target == pillar, "Khi toàn bộ Boss hỗ trợ đều chết, quái phải quay về đánh Trụ! Got: %s" % creep.target)
	print("PASS: [3.2] Khi hết Boss hỗ trợ, quái quay lại đánh Trụ.")

	# 4. Test Boss hỗ trợ tấn công quái: Quái phản đòn nhắm Boss đó
	print("\n[4] Test khi Boss hỗ trợ tấn công: Quái phản đòn nhắm lại Boss...")
	var ally_sword := AllyDefenseBoss.new()
	ally_sword.setup("sword", "Võ Đang Kiếm Thánh", 100, 450000.0, pillar)
	ally_sword.position = Vector2(850, 1000)
	add_child(ally_sword)

	creep.target = pillar # Quái đang nhắm trụ
	ally_sword._perform_attack(creep) # Boss Võ Đang xuất chiêu đánh quái

	assert(creep.target == ally_sword, "Quái bị Boss Võ Đang đánh phải lập tức nhắm Boss Võ Đang! Got: %s" % creep.target)
	print("PASS: [4] Quái bị Boss hỗ trợ tấn công lập tức phản đòn nhắm lại Boss.")

	# 5. Test quái bản đồ thường: ưu tiên Boss hỗ trợ trước người chơi
	print("\n[5] Test quái thường ưu tiên Boss hỗ trợ trước người chơi...")
	var player_dummy := Node2D.new()
	player_dummy.name = "TestPlayer"
	player_dummy.add_to_group("player")
	player_dummy.position = Vector2(100, 100)
	add_child(player_dummy)

	var normal_creep := VltkMonster.new()
	normal_creep.monster_id = 0
	normal_creep.data = MonsterData.monster(0).duplicate()
	normal_creep.level = 20
	normal_creep.ai_enabled = true
	normal_creep.position = Vector2(250, 100)
	add_child(normal_creep)

	var ally_beast := AllyDefenseBoss.new()
	ally_beast.setup("beast", "Thiên Sơn Thần Thú", 100, 600000.0, null)
	ally_beast.position = Vector2(200, 100) # Cách normal_creep 50px
	add_child(ally_beast)

	normal_creep.target = player_dummy # Ban đầu nhắm người chơi
	normal_creep._foe_search_timer = 0.0
	normal_creep._physics_process(0.016)

	assert(normal_creep.target == ally_beast, "Quái thường phải ưu tiên nhắm Boss hỗ trợ thay vì người chơi! Got: %s" % normal_creep.target)
	print("PASS: [5] Quái thường ưu tiên nhắm Boss hỗ trợ thay vì người chơi.")

	# 6. Test cơ chế giảm 50% sát thương của Boss Tanker (Thiên Vương Thiết Kỵ)
	print("\n[6] Test cơ chế Kim Chung Tráo giảm 50% sát thương nhận vào của Boss Tanker...")
	var test_tanker := AllyDefenseBoss.new()
	test_tanker.setup("tanker", "Thiên Vương Thiết Kỵ", 100, 1000000.0, null)
	add_child(test_tanker)
	var hp_before := test_tanker.health
	test_tanker.take_damage(10000.0)
	var dmg_taken := hp_before - test_tanker.health
	assert(dmg_taken == 5000.0, "Tanker nhận 10000 sát thương phải giảm 50% còn 5000: got " + str(dmg_taken))
	print("PASS: [6] Boss Tanker giảm chính xác 50% sát thương nhận vào (10000 -> 5000).")

	# Dọn dẹp
	pillar.queue_free()
	ally_tanker.queue_free()
	ally_healer.queue_free()
	ally_sword.queue_free()
	ally_beast.queue_free()
	test_tanker.queue_free()
	creep.queue_free()
	normal_creep.queue_free()
	player_dummy.queue_free()

	print("\n--- KẾT THÚC TEST: TẤT CẢ 6/6 TEST CASES ĐỀU PASS 100% ---")
	get_tree().quit(0)
