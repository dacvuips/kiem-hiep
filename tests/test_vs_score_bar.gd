extends Node

const VsScoreBar := preload("res://ui/common/vs_score_bar.gd")

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS: ", name)
	else:
		_fail += 1
		print("FAIL: ", name, " | ", detail)

func _ready() -> void:
	print("--- BẮT ĐẦU TEST BANNER TỶ SỐ VS TRẬN ĐẤU (TỐNG KIM LOL, TỐNG KIM, PK) ---")
	test_vs_score_bar_component()
	test_tong_kim_lol_integration()
	test_battle_client_integration()
	test_pk_match_integration()
	print("RESULT: ", _pass, "/", _pass + _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func test_vs_score_bar_component() -> void:
	print("[1] Test VsScoreBar Component...")
	var vs := VsScoreBar.new()
	add_child(vs)

	check("VsScoreBar tồn tại", vs != null)
	check("Texture background đã được nạp", vs._bg_tex != null and vs._bg_tex.texture != null)
	check("Nhãn phe trái mặc định 'Tống'", vs._left_name_lbl.text == "Tống")
	check("Nhãn phe phải mặc định 'Kim'", vs._right_name_lbl.text == "Kim")

	# Test set_sides
	vs.set_sides("Đại Tống", 774, 1557, "Đại Kim")
	check("Tên phe trái cập nhật", vs._left_name_lbl.text == "Đại Tống")
	check("Điểm phe trái cập nhật", vs._left_score_lbl.text == "774")
	check("Điểm phe phải cập nhật", vs._right_score_lbl.text == "1557")
	check("Tên phe phải cập nhật", vs._right_name_lbl.text == "Đại Kim")

	# Test set_timer
	vs.set_timer("35:20")
	check("Đồng hồ cập nhật", vs._timer_lbl.text == "35:20" and vs._timer_lbl.visible)

	# Test title / subtitle
	vs.set_title("CHIẾN TRƯỜNG TỐNG KIM")
	check("Tiêu đề cập nhật", vs._title_lbl.text == "CHIẾN TRƯỜNG TỐNG KIM" and vs._title_lbl.visible)

	vs.set_subtitle("Đang khai chiến · Hiệp 1")
	check("Phụ đề cập nhật", vs._subtitle_lbl.text == "Đang khai chiến · Hiệp 1" and vs._subtitle_lbl.visible)

	vs.queue_free()

func test_tong_kim_lol_integration() -> void:
	print("[2] Test Tống Kim LOL Client...")
	var lol := TongKimLolClient.new()
	add_child(lol)

	check("TongKimLolClient có _vs_bar", lol._vs_bar != null)
	check("Khởi đầu phe trái là Tống", lol._vs_bar._left_name_lbl.text == "Tống")
	check("Khởi đầu phe phải là Kim", lol._vs_bar._right_name_lbl.text == "Kim")

	# Update scores
	lol.update_scores(12, 5, 8, 12)
	check("Cập nhật tỷ số hạ gục phe Tống", lol._vs_bar._left_score_lbl.text == "12")
	check("Cập nhật tỷ số hạ gục phe Kim", lol._vs_bar._right_score_lbl.text == "8")

	# Test timer
	lol.time_left = 1800.0
	lol._process(1.0)
	check("Đồng hồ đếm ngược hiển thị trên VS Bar", lol._vs_bar._timer_lbl.text == "29:59")

	lol.queue_free()

func test_battle_client_integration() -> void:
	print("[3] Test Chiến Trường Tống Kim (BattleClient)...")
	var bc := BattleClient.create("song", 1)
	add_child(bc)

	check("BattleClient có _vs_bar", bc._vs_bar != null)

	# Simulate state message from BattleServer
	var state_msg := {
		"phase": "fight",
		"left": 1245,
		"song": 30,
		"song_points": 5800,
		"jin": 28,
		"jin_points": 4950,
		"me": {"points": 350, "kills": 3, "deaths": 1}
	}
	bc._on_state(state_msg)

	check("Điểm Tống hiển thị đúng", bc._vs_bar._left_score_lbl.text == "5800")
	check("Điểm Kim hiển thị đúng", bc._vs_bar._right_score_lbl.text == "4950")
	check("Thời gian hiển thị đúng", bc._vs_bar._timer_lbl.text == "20:45")

	bc.queue_free()

func test_pk_match_integration() -> void:
	print("[4] Test PK Match HUD...")
	var pk := PkMatch.new()
	GameManager.field_map = {"pk": {"mode": PkRules.Mode.THACH_DAU, "team_size": 1}}
	add_child(pk)

	check("PkMatch có _vs_bar", pk._vs_bar != null)
	check("Banner tiêu đề chế độ PK hiển thị", pk._vs_bar._title_lbl.visible)

	pk.queue_free()
