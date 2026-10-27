extends Node

func _ready() -> void:
	print("=== KIỂM THỬ NÚT VƯỢT TIẾP ẢI TIẾP THEO HAY VỀ THÀNH (THẬP NHỊ ĐẠI VƯỢT ẢI) ===")
	
	var all_stages := GameManager.get_all_stages()
	assert(all_stages.size() == 12, "Phải nạp đủ 12 ải")

	# 1. Test tại Ải 1 -> Phải có nút Vượt Tiếp Ải 2 và nút Về Thành
	print("\n[*] 1. Kiểm tra tại Ải 1 (stage_01):")
	GameManager.current_stage = all_stages[0]
	var popup_1 := StageVictoryPopup.new()
	popup_1._rewards = {
		"tier": 1,
		"stage_name": all_stages[0].stage_name,
		"gold": 1000,
		"exp": 50000,
	}
	add_child(popup_1)

	var next_st_1: StageData = popup_1._get_next_stage()
	assert(next_st_1 != null, "Ải 1 phải có ải tiếp theo")
	assert(next_st_1 == all_stages[1], "Ải tiếp theo của Ải 1 phải là Ải 2")
	print("  -> Đã xác định đúng Ải tiếp theo: %s" % next_st_1.stage_name)

	# Tìm các nút trong popup 1
	var buttons_1: Array[Button] = []
	_find_buttons(popup_1, buttons_1)
	var btn_texts_1: Array[String] = []
	for b in buttons_1:
		btn_texts_1.append(b.text)
	print("  -> Danh sách nút hiển thị: %s" % str(btn_texts_1))

	assert("Về Thành" in btn_texts_1, "Phải có nút 'Về Thành'")
	assert("Vượt Tiếp Ải 2" in btn_texts_1, "Phải có nút 'Vượt Tiếp Ải 2'")
	assert("Ở lại bản đồ" in btn_texts_1, "Phải có nút 'Ở lại bản đồ'")

	# Tìm label hỏi ý kiến
	var labels_1: Array[Label] = []
	_find_labels(popup_1, labels_1)
	var found_prompt_1 := false
	for l in labels_1:
		if "vượt tiếp ải tiếp theo hay về thành" in l.text:
			found_prompt_1 = true
			print("  -> Tìm thấy câu hỏi: '%s'" % l.text)
			break
	assert(found_prompt_1, "Phải có câu hỏi hỏi người chơi vượt tiếp ải tiếp theo hay về thành")
	print("  => Kiểm tra Ải 1: PASS!")
	popup_1.queue_free()

	# 2. Test tại Ải 12 (Ải cuối cùng) -> Không còn ải tiếp theo, chỉ có Về Thành
	print("\n[*] 2. Kiểm tra tại Ải 12 (stage_12 - ải cuối):")
	GameManager.current_stage = all_stages[11]
	var popup_12 := StageVictoryPopup.new()
	popup_12._rewards = {
		"tier": 12,
		"stage_name": all_stages[11].stage_name,
		"gold": 50000,
		"exp": 10000000,
	}
	add_child(popup_12)

	var next_st_12: StageData = popup_12._get_next_stage()
	assert(next_st_12 == null, "Ải 12 không được có ải tiếp theo")
	print("  -> Xác nhận Ải 12 không còn ải tiếp theo (phá đảo).")

	var buttons_12: Array[Button] = []
	_find_buttons(popup_12, buttons_12)
	var btn_texts_12: Array[String] = []
	for b in buttons_12:
		btn_texts_12.append(b.text)
	print("  -> Danh sách nút hiển thị: %s" % str(btn_texts_12))

	assert("Về Thành" in btn_texts_12, "Phải có nút 'Về Thành'")
	var has_next_btn := false
	for txt in btn_texts_12:
		if "Vượt Tiếp" in txt:
			has_next_btn = true
	assert(not has_next_btn, "Tại Ải 12 không được hiển thị nút 'Vượt Tiếp'")
	print("  => Kiểm tra Ải 12: PASS!")
	popup_12.queue_free()

	print("\n=======================================================")
	print("TẤT CẢ KIỂM THỬ VƯỢT TIẾP ẢI TIẾP THEO HAY VỀ THÀNH: PASS 100%!")
	print("=======================================================")
	get_tree().paused = false
	get_tree().quit(0)

func _find_buttons(node: Node, result: Array[Button]) -> void:
	if node is Button:
		result.append(node)
	for child in node.get_children():
		_find_buttons(child, result)

func _find_labels(node: Node, result: Array[Label]) -> void:
	if node is Label:
		result.append(node)
	for child in node.get_children():
		_find_labels(child, result)
