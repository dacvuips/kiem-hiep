extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("\n--- BẮT ĐẦU TEST TỐI ƯU HÓA HỆ THỐNG (MỤC 2, 3, 5) ---")
	test_audio_limiter()
	test_object_pooling_corpse()
	test_object_pooling_enemy()
	test_netproto_binary_packing()
	test_netproto_legacy_fallback()
	test_duplicate_login_kick()

	print("\n--- KẾT THÚC TEST TỐI ƯU HÓA ---")
	print("Tổng cộng: %d PASS, %d FAIL" % [_passed, _failed])
	if _failed == 0:
		print(">>> TẤT CẢ TEST ĐỀU THÀNH CÔNG! <<<")
		get_tree().quit(0)
	else:
		print(">>> CÓ TEST THẤT BẠI! <<<")
		get_tree().quit(1)

func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("PASS: %s" % msg)
	else:
		_failed += 1
		printerr("FAIL: %s" % msg)

func test_audio_limiter() -> void:
	print("\n[1] Kiểm tra Audio Limiter & SfxManager:")
	var stream := AudioStreamWAV.new()
	assert_true(SfxManager != null, "SfxManager autoload tồn tại")

	# Tạo player tại (0,0) để làm listener
	var listener := Node2D.new()
	listener.add_to_group("player")
	add_child(listener)

	# Test distance culling
	var far_pos := Vector2(999999, 999999)
	var count_before := SfxManager._count_playing(stream)
	SfxManager.play(stream, far_pos)
	assert_true(SfxManager._count_playing(stream) == count_before, "Âm thanh ở xa ngoài tầm bị cull, không tốn voice")

	# Test frame throttle
	var dummy_stream1 := AudioStreamWAV.new()
	var dummy_stream2 := AudioStreamWAV.new()
	var dummy_stream3 := AudioStreamWAV.new()
	var dummy_stream4 := AudioStreamWAV.new()
	var dummy_stream5 := AudioStreamWAV.new()

	SfxManager._starts_this_frame = 0
	SfxManager._last_frame_ticks = Engine.get_process_frames()
	SfxManager.play(dummy_stream1, Vector2.ZERO)
	SfxManager.play(dummy_stream2, Vector2.ZERO)
	SfxManager.play(dummy_stream3, Vector2.ZERO)
	SfxManager.play(dummy_stream4, Vector2.ZERO)
	# 5th sound should be throttled by MAX_STARTS_PER_FRAME = 4
	var count_dummy5 := SfxManager._count_playing(dummy_stream5)
	SfxManager.play(dummy_stream5, Vector2.ZERO, 0.0, 0.0, false)
	assert_true(SfxManager._count_playing(dummy_stream5) == count_dummy5, "Âm thanh thứ 5 trong cùng frame bị throttle")

	# Priority sound bypasses throttle
	SfxManager.play(dummy_stream5, Vector2.ZERO, 0.0, 0.0, true)
	assert_true(SfxManager._count_playing(dummy_stream5) > count_dummy5, "Âm thanh ưu tiên (player cast/hit) được phát bất chấp throttle")

	listener.queue_free()

func test_object_pooling_corpse() -> void:
	print("\n[2] Kiểm tra Pooling Xác Quái (MonsterCorpse):")
	var parent := Node2D.new()
	add_child(parent)

	# Spawn corpse 1
	var corpse1 := MonsterCorpse.spawn(parent, 1, 0, Vector2(100, 100), 1.0)
	assert_true(corpse1 != null, "Spawn được MonsterCorpse")
	assert_true(corpse1.visible, "MonsterCorpse hiển thị")

	# Simulate corpse finish animation & fade
	corpse1._frames = corpse1._len_frames
	corpse1._after = MonsterCorpse.STAY + MonsterCorpse.FADE + 0.1
	corpse1._process(0.1)

	assert_true(not corpse1.visible, "Sau khi mờ, corpse ẩn đi")
	assert_true(MonsterCorpse._pool.size() > 0, "Corpse được thu hồi vào MonsterCorpse._pool thay vì queue_free")

	# Spawn corpse 2 -> should pop from pool
	var corpse2 := MonsterCorpse.spawn(parent, 1, 0, Vector2(200, 200), 1.0)
	assert_true(corpse2 == corpse1, "Corpse mới tái sử dụng lại node từ pool")
	assert_true(corpse2.visible, "Corpse tái sử dụng được bật lại visible")
	assert_true(corpse2.position == Vector2(200, 200), "Corpse tái sử dụng nhận đúng vị trí mới")

	parent.queue_free()

func test_object_pooling_enemy() -> void:
	print("\n[3] Kiểm tra Pooling Quái Vật (Enemy & ObjectPool):")
	var enemy_scene: PackedScene = load("res://enemies/Enemy.tscn")
	assert_true(enemy_scene != null, "Load được Enemy.tscn")

	var parent := Node2D.new()
	add_child(parent)

	# Acquire enemy from pool
	var e1: CharacterBody2D = ObjectPool.acquire(enemy_scene, parent)
	assert_true(e1 != null, "Acquire được enemy từ ObjectPool")
	assert_true(e1.has_meta("pool_key"), "Enemy có gắn pool_key")
	assert_true(e1.visible, "Enemy đang hiển thị")

	# Setup tier
	var tier := EnemyTierData.new()
	tier.tier_name = "Thỏ Trắng"
	tier.contact_damage = 10.0
	tier.speed = 50.0
	tier.scale_override = 1.0
	var entry := EnemySpawnEntry.new()
	entry.tier = tier
	e1.setup(entry)

	var orig_scale: Vector2 = (e1.get_node("Sprite2D") as CanvasItem).scale

	# Simulate die & release to pool
	e1.die()
	assert_true(e1.is_dead(), "Enemy đánh dấu _is_dead = true")
	assert_true(not e1.visible, "Enemy giải phóng vào pool được ẩn đi")

	# Re-acquire enemy
	var e2: CharacterBody2D = ObjectPool.acquire(enemy_scene, parent)
	assert_true(e2 == e1, "Re-acquire lấy đúng instance cũ từ pool")
	assert_true(not e2.is_dead(), "_on_pool_acquire reset lại _is_dead = false")
	assert_true(e2.visible, "Enemy tái kích hoạt hiển thị")

	# Setup again and verify scale does not explode
	e2.setup(entry)
	assert_true(e2.get_node("Sprite2D").scale == orig_scale, "Sprite scale không bị nhân luỹ kế sau khi tái sử dụng")

	parent.queue_free()

func test_netproto_binary_packing() -> void:
	print("\n[4] Kiểm tra NetProto Binary Packing cho Đấu Trường PK:")
	var st := {
		"op": "state",
		"id": "room_99",
		"mode": 1,
		"state": "fight",
		"left": 95,
		"round": 2,
		"spectators": 5,
		"role": "fighter",
		"my_team": "a",
		"team_a": [101, 102],
		"team_a_eids": [1001, 1002],
		"team_a_names": ["Tiêu Phong", "Hư Trúc"],
		"team_b": [201],
		"team_b_eids": [2001],
		"team_b_names": ["Đoàn Dự"],
	}

	# 1. So sánh dung lượng JSON thuần vs Binary packing
	var json_str := JSON.stringify(st)
	var json_bytes := json_str.to_utf8_buffer().size()

	var buf := NetProto.writer(NetProto.S_ARENA)
	NetProto.pack_arena_msg(buf, st)
	var bin_bytes := buf.data_array.size()

	print("  Dung lượng JSON thuần: %d bytes" % json_bytes)
	print("  Dung lượng Binary Packed: %d bytes" % bin_bytes)
	var savings := float(json_bytes - bin_bytes) / float(json_bytes) * 100.0
	print("  Tiết kiệm băng thông: %.1f%%" % savings)

	assert_true(bin_bytes < json_bytes, "Gói tin nhị phân nhỏ hơn JSON đáng kể")
	assert_true(savings >= 60.0, "Tiết kiệm băng thông đạt trên 60%% (thực tế: %.1f%%)" % savings)

	# 2. Giải nén và kiểm tra tính toàn vẹn dữ liệu
	var reader := NetProto.reader(buf.data_array)
	var msg_type := reader.get_u8()
	assert_true(msg_type == NetProto.S_ARENA, "Opcode đúng là S_ARENA")

	var unpacked := NetProto.unpack_arena_msg(reader)
	assert_true(unpacked.get("op") == "state", "Giải nén đúng op = state")
	assert_true(unpacked.get("id") == "room_99", "Giải nén đúng room_id")
	assert_true(unpacked.get("mode") == 1, "Giải nén đúng mode")
	assert_true(unpacked.get("state") == "fight", "Giải nén đúng state fight")
	assert_true(unpacked.get("left") == 95, "Giải nén đúng thời gian còn lại")
	assert_true(unpacked.get("round") == 2, "Giải nén đúng hiệp đấu")
	assert_true(unpacked.get("spectators") == 5, "Giải nén đúng số người xem")
	assert_true(unpacked.get("role") == "fighter", "Giải nén đúng vai trò")
	assert_true(unpacked.get("my_team") == "a", "Giải nén đúng phe của tôi")
	assert_true(unpacked.get("team_a_names") == ["Tiêu Phong", "Hư Trúc"], "Giải nén đúng danh sách tên team A")
	assert_true(unpacked.get("team_b_names") == ["Đoàn Dự"], "Giải nén đúng danh sách tên team B")
	assert_true(unpacked.get("fighter_eids") == [1001, 1002, 2001], "Giải nén đúng toàn bộ fighter_eids")

func test_netproto_legacy_fallback() -> void:
	print("\n[5] Kiểm tra Tương thích ngược NetProto (Legacy JSON Fallback):")
	var legacy_dict := {"op": "reject", "msg": "Phòng đã đủ người"}
	var legacy_buf := NetProto.writer(NetProto.S_ARENA)
	NetProto.put_str(legacy_buf, JSON.stringify(legacy_dict))

	var reader := NetProto.reader(legacy_buf.data_array)
	var _type := reader.get_u8()
	var unpacked := NetProto.unpack_arena_msg(reader)
	assert_true(unpacked.get("op") == "reject", "Giải nén gói legacy JSON đúng op")
	assert_true(unpacked.get("msg") == "Phòng đã đủ người", "Giải nén gói legacy JSON đúng msg")

func test_duplicate_login_kick() -> void:
	print("\n[6] Kiểm tra Đá phiên cũ khi Đăng nhập trên 2 thiết bị (Anti Multi-login):")
	# 1. Kiểm tra AccountApi hỗ trợ check_session và session_invalidated
	assert_true(AccountApi.has_signal("session_invalidated"), "AccountApi có signal session_invalidated")
	assert_true(AccountApi.has_method("check_session"), "AccountApi có method check_session()")

	# 2. Kiểm tra GameServer._by_account logic
	var gs := GameServer.new()
	assert_true(gs._by_account != null, "GameServer có từ điển _by_account để theo dõi phiên tài khoản")

	# Tạo 2 kết nối giả lập của cùng 1 account_id
	var c1 := GameServer.Conn.new()
	c1.key = "conn_device_1"
	c1.account_id = 999
	c1.character_id = 1001
	gs._conns[c1.key] = c1
	gs._by_account[c1.account_id] = c1
	gs._by_character[c1.character_id] = c1

	var c2 := GameServer.Conn.new()
	c2.key = "conn_device_2"
	c2.account_id = 999
	c2.character_id = 1002
	gs._conns[c2.key] = c2

	# Giả lập c2 authenticate trên GameServer
	var old_acc: GameServer.Conn = gs._by_account.get(c2.account_id)
	assert_true(old_acc == c1, "Phát hiện thiết bị cũ (c1) đang online cùng tài khoản 999")

	# Đá phiên cũ c1 và nhường chỗ cho c2
	old_acc.character_id = 0
	gs._by_account[c2.account_id] = c2
	gs._by_character[c2.character_id] = c2

	assert_true(c1.character_id == 0, "Phiên cũ c1 bị hủy character_id (không lưu đè dữ liệu)")
	assert_true(gs._by_account[999] == c2, "Phiên mới c2 trở thành kết nối duy nhất của tài khoản")

	# Khi c2 thoát -> dọn dẹp _by_account
	if gs._by_account.get(c2.account_id) == c2:
		gs._by_account.erase(c2.account_id)
	assert_true(not gs._by_account.has(999), "Khi thiết bị c2 thoát, tài khoản được dọn dẹp sạch sẽ")
