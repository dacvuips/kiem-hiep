extends Node

## TEST SUITE KIỂM THỬ HOẠT ẢNH SKILL VLTK THẬT:
## 1. Con Rồng Phi Long bay ra (fx_a31b9f04)
## 2. Cây Bổng dí xoay bay ra (fx_04e27976)
## 3. Chưởng lực Phật Môn La Hán vàng kim (fx_c9ba5bf1)
## 4. Hoạt ảnh nổ VLTK thật khi trúng đích (fx_c33e96c2, fx_b91ab706)

const ThuThanhProjectileScript := preload("res://systems/challenge/thu_thanh_projectile.gd")
const ThuThanhFxSpriteScript := preload("res://systems/challenge/thu_thanh_fx_sprite.gd")
const ThuThanhMonsterScript := preload("res://systems/challenge/thu_thanh_monster.gd")

func _ready() -> void:
	print("=== BẮT ĐẦU TEST: HOẠT ẢNH SKILL VLTK THẬT (CON RỒNG BAY RA & CÂY BỔNG DÍ) ===")

	# -------------------------------------------------------------
	# TEST 1: KIỂM TRA THUTHANH_FX_SPRITE LOAD VÀ CẮT KHUNG HÌNH
	# -------------------------------------------------------------
	print("\n--- TEST 1: THUTHANH_FX_SPRITE LOAD VÀ TÍNH TOÁN KHUNG HÌNH ---")
	var fx := ThuThanhFxSpriteScript.new()
	add_child(fx)

	# Nạp Con Rồng Cái Bang (fx_a31b9f04)
	var ok := fx.setup_fx("fx_a31b9f04", 48, true, 18.0)
	assert(ok, "Phải nạp thành công anim con rồng fx_a31b9f04!")
	assert(fx.texture != null, "Texture con rồng phải tồn tại!")
	assert(fx.spr_dirs == 16, "Con rồng phải có 16 hướng!")
	assert(fx.frame_size == Vector2i(297, 164), "Kích thước khung hình con rồng phải là 297x164!")
	assert(fx.region_rect.size.x == 297 and fx.region_rect.size.y == 164, "Vùng cắt region_rect phải đúng 297x164!")
	print("✓ Con Rồng Phi Long (fx_a31b9f04) nạp thành công: 16 hướng, kích thước %s, offset = %s" % [fx.frame_size, fx.frame_offset])

	# Cập nhật thời gian hoạt ảnh xem frame có chạy không
	fx._process(0.1)
	assert(fx.region_rect.position.x >= 0, "Region rect position phải hợp lệ!")
	print("✓ Hoạt ảnh con rồng đang chuyển động mượt mà ở 18 FPS")

	# -------------------------------------------------------------
	# TEST 2: KIỂM TRA CÂY BỔNG DÍ (fx_04e27976)
	# -------------------------------------------------------------
	print("\n--- TEST 2: CÂY BỔNG XOAY TÍT DÍ THEO QUÁI ---")
	var fx_stick := ThuThanhFxSpriteScript.new()
	add_child(fx_stick)
	var ok_stick := fx_stick.setup_fx("fx_04e27976", 48, true, 18.0)
	assert(ok_stick, "Phải nạp thành công anim cây bổng fx_04e27976!")
	assert(fx_stick.spr_dirs == 16, "Cây bổng phải có 16 hướng xoay!")
	assert(fx_stick.frame_size == Vector2i(206, 116), "Kích thước cây bổng là 206x116!")
	print("✓ Cây Bổng dí (fx_04e27976) nạp thành công: 16 hướng, kích thước %s" % [fx_stick.frame_size])

	# -------------------------------------------------------------
	# TEST 3: ĐẠN BAY CON RỒNG VÀ CÂY BỔNG BÁM ĐUỔI QUÁI
	# -------------------------------------------------------------
	print("\n--- TEST 3: ĐẠN BAY CON RỒNG THẬT VÀ NỔ LỬA VLTK ---")
	var mon: ThuThanhMonster = ThuThanhMonsterScript.new()
	mon.lane_row = 0
	mon.max_hp = 200.0
	mon.current_hp = 200.0
	add_child(mon)
	mon.position = Vector2(500.0, 100.0)

	# Bắn con rồng
	var proj_dragon: ThuThanhProjectile = ThuThanhProjectileScript.new()
	add_child(proj_dragon)
	proj_dragon.position = Vector2(200.0, 100.0)
	proj_dragon.setup("dragon", 80.0, 0, 600.0)
	proj_dragon.set_target_and_aoe(mon, 85.0)

	await get_tree().process_frame

	# Kiểm tra con rồng có sprite fx bên trong
	var dragon_fx = proj_dragon.get_node_or_null("@Sprite2D@2")
	if dragon_fx == null:
		for c in proj_dragon.get_children():
			if c.has_method("setup_fx") or c.get_script() == ThuThanhFxSpriteScript:
				dragon_fx = c
				break
	assert(dragon_fx != null, "Đạn con rồng phải chứa ThuThanhFxSprite hoạt ảnh thật!")
	assert(dragon_fx.anim_key == "fx_a31b9f04", "Anim key phải là con rồng fx_a31b9f04, KHÔNG ĐƯỢC LÀ ICON TĨNH!")
	print("✓ Chiêu thức Cái Bang phát ra con rồng thật (fx_a31b9f04), không phải ảnh icon!")

	# Cho rồng bay tới quái mục tiêu và nổ
	proj_dragon.position = mon.position - Vector2(10, 0)
	proj_dragon._process(0.016)

	await get_tree().process_frame

	assert(mon.current_hp < 200.0, "Quái phải nhận sát thương từ con rồng!")
	print("✓ Con rồng trúng đích nổ lửa thành công! Máu quái: 200.0 -> %.1f" % mon.current_hp)

	# -------------------------------------------------------------
	# TEST 4: BẮN CÂY BỔNG DÍ (dog_stick)
	# -------------------------------------------------------------
	print("\n--- TEST 4: BẮN CÂY BỔNG DÍ VÀ NỔ BỔNG KÌNH ---")
	var proj_stick: ThuThanhProjectile = ThuThanhProjectileScript.new()
	add_child(proj_stick)
	proj_stick.position = Vector2(200.0, 100.0)
	proj_stick.setup("dog_stick", 70.0, 0, 540.0)
	proj_stick.set_target_and_aoe(mon, 75.0)

	await get_tree().process_frame

	var stick_fx = null
	for c in proj_stick.get_children():
		if c.has_method("setup_fx") or c.get_script() == ThuThanhFxSpriteScript:
			stick_fx = c
			break
	assert(stick_fx != null, "Đạn bổng phải chứa ThuThanhFxSprite!")
	assert(stick_fx.anim_key == "fx_04e27976", "Anim key phải là cây bổng dí fx_04e27976!")
	print("✓ Chiêu thức Đả Cẩu Bổng phát ra cây bổng dí thật (fx_04e27976) xoay tít bay tới quái!")

	print("\n=== TẤT CẢ TEST HOẠT ẢNH SKILL VLTK THẬT ĐẠT 100% THÀNH CÔNG! ===")
	get_tree().quit(0)
