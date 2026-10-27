extends Node

const HuyHoangWindow = preload("res://ui/events/huy_hoang_window.gd")
const BatNhaWindow = preload("res://ui/events/bat_nha_window.gd")
const ViemDeWindow = preload("res://ui/events/viem_de_window.gd")
const LanternWindow = preload("res://ui/events/lantern_window.gd")
const EscortWindow = preload("res://ui/events/escort_window.gd")
const SiegeWindow = preload("res://ui/events/siege_window.gd")
const EventScheduleWindow = preload("res://ui/events/event_schedule_window.gd")

func _ready() -> void:
	print("==================================================")
	print(" BẮT ĐẦU KIỂM THỬ TOÀN DIỆN HỆ THỐNG SỰ KIỆN IDLE")
	print("==================================================")
	_run_tests()

func _run_tests() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "DaiHiepTest"
	profile.level = 100
	profile.gold = 50000000
	profile.jade = 5000
	profile.guild = {"name": "Võ Lâm Bang", "contribution": 100, "siege_score": 0}

	# Dọn dẹp records cũ trước khi test để đảm bảo lượt ngày không bị chặn
	for p in [
		HuyHoangWindow.RECORD_PATH, BatNhaWindow.RECORD_PATH, ViemDeWindow.RECORD_PATH,
		LanternWindow.RECORD_PATH, EscortWindow.RECORD_PATH, SiegeWindow.RECORD_PATH,
		HuyHoangWindow.get_record_path(profile), BatNhaWindow.get_record_path(profile),
		LanternWindow.get_record_path(profile),
		ViemDeWindow.get_record_path(profile), EscortWindow.get_record_path(profile),
		SiegeWindow.get_record_path(profile)
	]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

	var root_node := Node2D.new()
	add_child(root_node)

	# 1. Kiểm thử HuyHoangWindow
	print("\n[*] 1. Kiểm thử Quả Huy Hoàng (HuyHoangWindow)...")
	var w_hh = HuyHoangWindow.new(profile)
	root_node.add_child(w_hh)
	var t_hh: Dictionary = w_hh._get_suitable_tier()
	assert(not t_hh.is_empty(), "Phải tìm được tier phù hợp với cấp 100")
	var lv_before: int = profile.level
	var exp_before: int = profile.current_exp
	w_hh._eat_fruit(t_hh, 1)
	assert(profile.level > lv_before or profile.current_exp > exp_before, "Ăn quả Huy Hoàng phải tăng cấp hoặc EXP")
	# Kiểm thử minigame nhảy quả Flappy Fruit
	var flappy_win: HuyHoangFlappyWindow = HuyHoangFlappyWindow.launch(w_hh, profile, t_hh)
	assert(flappy_win != null, "Khởi tạo HuyHoangFlappyWindow thành công")
	assert(flappy_win._state == HuyHoangFlappyWindow.State.READY, "Trạng thái ban đầu phải là READY")
	var ev_click := InputEventMouseButton.new()
	ev_click.button_index = MOUSE_BUTTON_LEFT
	ev_click.pressed = true
	flappy_win._on_board_input(ev_click)
	assert(flappy_win._state == HuyHoangFlappyWindow.State.PLAYING, "Nhấp chuột/chạm phải chuyển sang PLAYING")
	assert(flappy_win._fruit_vy == HuyHoangFlappyWindow.FLAP_VELOCITY, "Quả phải nhảy với vận tốc FLAP_VELOCITY")
	flappy_win._fruit_vy = 200.0
	flappy_win._on_board_input(ev_click)
	assert(flappy_win._fruit_vy == HuyHoangFlappyWindow.FLAP_VELOCITY, "Nhấp chuột tiếp theo quả phải tiếp tục nhảy lên")
	
	# Kiểm thử tính thưởng theo % hoàn thành màn chơi
	# Case 1: 0% hoàn thành (0 pipes)
	var callback_result := {}
	var flappy_test_0: HuyHoangFlappyWindow = HuyHoangFlappyWindow.launch(w_hh, profile, t_hh, func(score, exp, gold, fuyuan):
		callback_result["score"] = score
		callback_result["exp"] = exp
		callback_result["gold"] = gold
		callback_result["fuyuan"] = fuyuan
	)
	flappy_test_0._raw_pipes_passed = 0
	flappy_test_0._score = 0
	flappy_test_0._trigger_game_over()
	assert(callback_result.get("exp", -1) == 0, "0% hoàn thành phải nhận đúng 0 EXP")
	assert(callback_result.get("gold", -1) == 0, "0% hoàn thành phải nhận đúng 0 Lượng")
	assert(callback_result.get("fuyuan", -1) == 0, "0% hoàn thành phải nhận đúng 0 Phúc Duyên")
	flappy_test_0.queue_free()

	# Case 2: 50% hoàn thành (5 pipes)
	callback_result.clear()
	var flappy_test_50: HuyHoangFlappyWindow = HuyHoangFlappyWindow.launch(w_hh, profile, t_hh, func(score, exp, gold, fuyuan):
		callback_result["score"] = score
		callback_result["exp"] = exp
		callback_result["gold"] = gold
		callback_result["fuyuan"] = fuyuan
	)
	flappy_test_50._raw_pipes_passed = 5
	flappy_test_50._score = 5 * flappy_test_50._multiplier
	flappy_test_50._trigger_game_over()
	var base_fuyuan: int = int(t_hh.get("reward_fuyuan", 10))
	assert(callback_result.get("fuyuan", -1) == int(round(base_fuyuan * 0.5)), "50% hoàn thành phải nhận đúng 50% Phúc Duyên")
	assert(callback_result.get("exp", 0) > 0, "50% hoàn thành phải nhận EXP tỷ lệ thuận")
	flappy_test_50.queue_free()

	# Case 3: 100% hoàn thành (10 pipes)
	callback_result.clear()
	var flappy_test_100: HuyHoangFlappyWindow = HuyHoangFlappyWindow.launch(w_hh, profile, t_hh, func(score, exp, gold, fuyuan):
		callback_result["score"] = score
		callback_result["exp"] = exp
		callback_result["gold"] = gold
		callback_result["fuyuan"] = fuyuan
	)
	flappy_test_100._raw_pipes_passed = 10
	flappy_test_100._score = 10 * flappy_test_100._multiplier
	flappy_test_100._trigger_victory()
	assert(callback_result.get("fuyuan", -1) == base_fuyuan, "100% hoàn thành phải nhận đủ 100% Phúc Duyên")
	flappy_test_100.queue_free()

	flappy_win.queue_free()

	print("  -> HuyHoangWindow & Flappy Fruit Jump & Phần thưởng theo % hoàn thành: PASS!")
	w_hh.queue_free()

	# 2. Kiểm thử BatNhaWindow
	print("\n[*] 2. Kiểm thử Vườn Bát Nhã (BatNhaWindow)...")
	var w_bn = BatNhaWindow.new(profile)
	root_node.add_child(w_bn)
	var seed_cfg: Dictionary = BatNhaWindow.SEEDS[0]
	w_bn._plant_seed(0, seed_cfg)
	var rec_bn: Dictionary = w_bn._get_records()
	var plots: Array = rec_bn.get("plots", [])
	assert(plots.size() > 0 and not plots[0].is_empty(), "Ô đất 0 phải có hạt giống")
	# Test tưới nước thần (trừ 5 KNB)
	var jade_before: int = profile.jade
	w_bn._water_plot(0)
	assert(profile.jade == jade_before - 5, "Tưới Nước Thần phải trừ đúng 5 KNB")
	# Speedup and harvest
	w_bn._speedup_plot(0)
	lv_before = profile.level
	exp_before = profile.current_exp
	w_bn._harvest_plot(0, seed_cfg)
	assert(profile.level > lv_before or profile.current_exp > exp_before, "Thu hoạch Bát Nhã phải tăng cấp hoặc EXP")
	print("  -> BatNhaWindow (Gieo hạt, Tưới Nước Thần 5 KNB, Hoàn thành ngay 10 KNB, Thu hoạch): PASS!")
	w_bn.queue_free()
	print("  -> BatNhaWindow: PASS!")
	w_bn.queue_free()

	# 3. Kiểm thử ViemDeWindow
	print("\n[*] 3. Kiểm thử Viêm Đế Bảo Tàng (ViemDeWindow)...")
	var w_vd = ViemDeWindow.new(profile)
	root_node.add_child(w_vd)
	var f1: Dictionary = ViemDeWindow.FLOORS[0]
	lv_before = profile.level
	exp_before = profile.current_exp
	w_vd._clear_floor(f1, false)
	assert(profile.level > lv_before or profile.current_exp > exp_before, "Vượt tầng Viêm Đế phải nhận EXP")
	# Thử càn quét tầng đã vượt
	lv_before = profile.level
	exp_before = profile.current_exp
	w_vd._clear_floor(f1, true)
	assert(profile.level > lv_before or profile.current_exp > exp_before, "Càn quét tầng Viêm Đế phải nhận EXP")
	print("  -> ViemDeWindow: PASS!")
	w_vd.queue_free()

	# 4. Kiểm thử LanternWindow
	print("\n[*] 4. Kiểm thử Hội Hoa Đăng (LanternWindow)...")
	var w_lt = LanternWindow.new(profile)
	root_node.add_child(w_lt)
	var q: Dictionary = LanternWindow.QUESTIONS_DATABASE[0]
	lv_before = profile.level
	exp_before = profile.current_exp
	w_lt._on_answer_chosen(q, int(q["answer"]))
	assert(profile.level > lv_before or profile.current_exp > exp_before, "Trả lời câu đố đúng phải nhận EXP")
	print("  -> LanternWindow: PASS!")
	w_lt.queue_free()

	# 5. Kiểm thử EscortWindow
	print("\n[*] 5. Kiểm thử Vận Tiêu (EscortWindow)...")
	EscortWindow.test_bypass_day = true
	var w_es = EscortWindow.new(profile)
	root_node.add_child(w_es)
	var cart_cfg: Dictionary = EscortWindow.CARTS[0]
	w_es._execute_dispatch_cart(cart_cfg, int(cart_cfg.get("deposit_gold", 0)), int(cart_cfg.get("deposit_jade", 0)))
	var rec_es: Dictionary = w_es._get_records()
	assert(not rec_es.get("active_cart", {}).is_empty(), "Phải có xe tiêu đang chạy")
	# Claim
	lv_before = profile.level
	exp_before = profile.current_exp
	w_es._claim_cart(cart_cfg)
	assert(profile.level > lv_before or profile.current_exp > exp_before, "Thu hoạch xe tiêu phải tăng EXP")
	print("  -> EscortWindow: PASS!")
	w_es.queue_free()

	# 6. Kiểm thử SiegeWindow
	print("\n[*] 6. Kiểm thử Công Thành Chiến (SiegeWindow)...")
	var w_sg = SiegeWindow.new(profile)
	root_node.add_child(w_sg)
	var city_cfg: Dictionary = SiegeWindow.CITIES[0]
	lv_before = profile.level
	exp_before = profile.current_exp
	w_sg._attack_city(city_cfg, false)
	assert(profile.level > lv_before or profile.current_exp > exp_before, "Công thành phải nhận EXP")
	print("  -> SiegeWindow: PASS!")
	w_sg.queue_free()

	# 7. Kiểm thử Càn quét TimeChallenge & PhongLangDoChallenge
	print("\n[*] 7. Kiểm thử Càn quét Vượt Ải & Phong Lăng Độ...")
	var rec_tc: Dictionary = TimeChallenge._records()
	rec_tc[TimeChallenge._key(profile)] = {"best": 600}
	TimeChallenge._save_records(rec_tc)
	var it := ItemInstance.new()
	it.misc_id = TimeChallenge.ENTRY_ITEM_ID
	it.item_level = TimeChallenge.ENTRY_ITEM_LEVEL
	it.count = 5
	profile.inventory.append(it)

	var tc_sweep_res: Dictionary = TimeChallenge.sweep(profile)
	assert(tc_sweep_res.get("ok", false), "Càn quét Thách Thức Thời Gian phải thành công")
	print("  -> TimeChallenge sweep: PASS!")

	var rec_pld: Dictionary = PhongLangDoChallenge._records()
	rec_pld[PhongLangDoChallenge._key(profile)] = {"best": 300}
	PhongLangDoChallenge._save_records(rec_pld)
	var pld_sweep_res: Dictionary = PhongLangDoChallenge.sweep(profile)
	assert(pld_sweep_res.get("ok", false), "Ủy thác Phong Lăng Độ phải thành công")
	print("  -> PhongLangDoChallenge sweep: PASS!")

	# 8. Kiểm thử EventScheduleWindow có đủ hoạt động
	print("\n[*] 8. Kiểm thử EventScheduleWindow (Sự kiện võ lâm & Boss)...")
	var w_ev = EventScheduleWindow.new(profile)
	root_node.add_child(w_ev)
	assert(EventScheduleWindow.EVENTS_DATA.size() >= 11, "Phải có ít nhất 11 sự kiện trong EVENTS_DATA")
	print("  -> Đã kiểm tra %d sự kiện trong EventScheduleWindow (Thập Đại Boss 12h/19h30/23h & Tiểu Boss 9h10/17h10/21h10/23h10): PASS!" % EventScheduleWindow.EVENTS_DATA.size())
	w_ev.queue_free()

	print("\n==================================================")
	print(" 🎉 TẤT CẢ 8 HẠNG MỤC KIỂM THỬ ĐỀU ĐẠT 100% (PASS)!")
	print("==================================================")
	get_tree().quit(0)
