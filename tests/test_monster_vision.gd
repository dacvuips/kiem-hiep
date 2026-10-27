extends Node

func _ready() -> void:
	print("\n--- BẮT ĐẦU TEST PHẠM VI NHÌN THẤY CỦA QUÁI & BOSS THEO CHUẨN VLTK GỐC ---\n")

	# 1. Kiểm tra dữ liệu gốc NpcS.txt / monsters.json
	print("[1] Kiểm tra chỉ số VisionRadius & ActiveRadius trong MonsterData...")
	var tiger := MonsterData.monster(0) # Đông Bắc Hổ
	assert(tiger.get("vision") == 400, "Đông Bắc Hổ phải có vision chuẩn 400")
	assert(tiger.get("active") == 700, "Đông Bắc Hổ phải có active chuẩn 700")
	print("PASS: Quái thường (Đông Bắc Hổ) có Vision=400, Active=700")

	var boss_dao := MonsterData.monster(456) # Boss Đạo Nhất Chân Nhân
	assert(boss_dao.get("vision") == 800, "Boss Đạo Nhất Chân Nhân phải có vision chuẩn 800")
	assert(boss_dao.get("active") == 1000, "Boss Đạo Nhất Chân Nhân phải có active chuẩn 1000")
	print("PASS: Boss Hoàng Kim (Đạo Nhất Chân Nhân) có Vision=800, Active=1000")

	var boss_yen := MonsterData.monster(744) # Boss Yên Hiểu Trái
	assert(boss_yen.get("vision") == 1800, "Boss Yên Hiểu Trái phải có vision chuẩn 1800")
	assert(boss_yen.get("active") == 2000, "Boss Yên Hiểu Trái phải có active chuẩn 2000")
	print("PASS: Boss Cao Cấp (Yên Hiểu Trái) có Vision=1800, Active=2000")

	var tree_npc := MonsterData.monster(603) # Cây thông 1
	assert(int(tree_npc.get("vision", 0)) == 0, "NPC tĩnh/cây cối phải có Vision=0")
	assert(int(tree_npc.get("active", 0)) == 0, "NPC tĩnh/cây cối phải có Active=0")
	print("PASS: NPC tĩnh / Cây cối có Vision=0, Active=0 (không nhìn, không đuổi)")

	# 2. Kiểm tra ServerMonster không bị nhân khống tầm nhìn
	print("\n[2] Kiểm tra ServerMonster đọc chuẩn tầm nhìn gốc...")
	var sm_entry := {"t": 0, "lv": 20, "px": 100.0, "py": 100.0, "respawn": 40}
	var sm := ServerMonster.from_entry(sm_entry, 1)
	assert(sm != null, "Khởi tạo ServerMonster thành công")
	assert(sm._vision == 400.0, "ServerMonster vision phải đúng 400.0, không được nhân khống (trước đây bị max(400*1.6, 750)=750)")
	assert(sm._active == 700.0, "ServerMonster active phải đúng 700.0, không được nhân khống (trước đây bị max(700*2, 1500)=1500)")
	print("PASS: ServerMonster giữ nguyên Vision=400.0, Active=700.0 chuẩn C++ gốc")

	# 3. Kiểm tra VltkMonster (Client / Offline) khóa mục tiêu theo đúng tầm nhìn
	print("\n[3] Kiểm tra VltkMonster nhận diện mục tiêu đúng khoảng cách...")
	var vm := VltkMonster.new()
	vm.monster_id = 0
	vm.data = tiger.duplicate()
	vm.level = 20
	vm.ai_enabled = true
	vm.position = Vector2(500, 500)
	add_child(vm)

	var dummy := Node2D.new()
	dummy.name = "DummyPlayer"
	dummy.add_to_group("player")
	add_child(dummy)

	# Đặt người chơi cách quái 300 logic px (nằm trong tầm nhìn 400)
	# Logic distance: sqrt(dx^2 + (2*dy)^2)
	# Với dx=250, dy=0 -> logic dist = 250 <= 400
	dummy.position = Vector2(750, 500) # world dist = 250, logic dist = 250
	vm.target = dummy
	assert(vm.is_engaging(dummy), "Trong cự ly 250 logic px <= 400: Quái phải phát hiện và giao chiến")
	print("PASS: Trong tầm nhìn (250 logic px <= 400): Quái phát hiện mục tiêu")

	# Đặt người chơi cách quái 500 logic px (ngoài tầm nhìn 400)
	dummy.position = Vector2(1000, 500) # world dist = 500, logic dist = 500 > 400
	assert(not vm.is_engaging(dummy), "Ngoài cự ly 500 logic px > 400: Quái KHÔNG được coi là đang giao chiến")
	print("PASS: Ngoài tầm nhìn (500 logic px > 400): Quái không giao chiến")

	# 4. Kiểm tra NPC tĩnh không bao giờ giao chiến
	print("\n[4] Kiểm tra NPC tĩnh / Cây cối (Vision=0, AIMode=0)...")
	var vm_tree := VltkMonster.new()
	vm_tree.monster_id = 603
	vm_tree.data = tree_npc.duplicate()
	vm_tree.position = Vector2(500, 500)
	add_child(vm_tree)
	dummy.position = Vector2(510, 500) # ngay sát cạnh 10px
	vm_tree.target = dummy
	assert(not vm_tree.is_engaging(dummy), "NPC tĩnh có vision=0 không bao giờ giao chiến với người chơi")
	print("PASS: NPC tĩnh không giao chiến kể cả khi đứng sát cạnh")

	# 5. Kiểm tra số frame động tác di chuyển của quái Đoạt Mệnh Liêm (tránh bug chạy liên hồi)
	print("\n[5] Kiểm tra số frame động tác quái Đoạt Mệnh Liêm (ID 838)...")
	var doat_menh := MonsterData.monster(838)
	var walk_frames := MonsterData.action_frames(doat_menh, "walk")
	assert(walk_frames == 15, "Đoạt Mệnh Liêm phải có 15 frame di chuyển (120 frame / 8 hướng), không được bằng 1: got %d" % walk_frames)
	var die_frames := MonsterData.action_frames(doat_menh, "die")
	assert(die_frames == 22, "Đoạt Mệnh Liêm phải có 22 frame chết (176 frame / 8 hướng): got %d" % die_frames)
	print("PASS: Đoạt Mệnh Liêm có chuẩn 15 frame walk và 22 frame die (không bị giật liên hồi do frame=1)")

	# 6. Dọn dẹp
	dummy.remove_from_group("player")
	dummy.queue_free()
	vm.queue_free()
	vm_tree.queue_free()

	print("\n--- KẾT THÚC TEST: TẤT CẢ CÁC BƯỚC KIỂM TRA ĐỀU THÀNH CÔNG (PASS 100%) ---")
	get_tree().quit(0)
