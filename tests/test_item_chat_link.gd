extends Node

const ItemChatHelper = preload("res://systems/items/item_chat_helper.gd")
const MapChatHelper = preload("res://systems/map_chat_helper.gd")

var _tests_passed := 0
var _tests_failed := 0

func _ready() -> void:
	print("--- BẮT ĐẦU TEST TÍNH NĂNG GẮN LINK VẬT PHẨM VÀO CHAT ---")
	test_encode_decode_equipment()
	test_encode_decode_gold_item()
	test_encode_decode_misc_item()
	test_format_chat_bbcode()
	test_clean_plain_text()
	test_item_detail_popup_button()
	await test_chat_panel_integration()
	test_map_chat_link_bbcode()
	await test_map_chat_panel_integration()
	await test_share_from_pk_badge()

	print("--- KẾT QUẢ TEST: %d PASS, %d FAIL ---" % [_tests_passed, _tests_failed])
	if _tests_failed == 0:
		print("TẤT CẢ TEST ĐỀU THÀNH CÔNG!")
	else:
		push_error("CÓ TEST THẤT BẠI!")
	get_tree().quit(0 if _tests_failed == 0 else 1)

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		print("  [FAIL] %s" % msg)

func test_encode_decode_equipment() -> void:
	print("[1] Test encode/decode trang bị xanh...")
	var it := ItemInstance.new()
	it.base_index = 0
	it.series = ElementTypes.ElementType.KIM
	it.durability = 85
	it.base_values = [["durability_v", 100], ["weapondamagemin_v", 30]]
	it.magic = [
		{"attrib": "attackrating_v", "value": [60, 0, 0], "name": "Độ chính xác", "prefix": true},
		{"attrib": "addphysicsdamage_v", "value": [15, 0, 0], "name": "Sát thương vật lý", "prefix": false}
	]

	var encoded := ItemChatHelper.encode_item(it)
	assert_true(not encoded.is_empty(), "Mã hoá chuỗi item không rỗng")

	var decoded := ItemChatHelper.decode_item(encoded)
	assert_true(decoded != null, "Giải mã thành công ItemInstance")
	assert_true(decoded.base_index == it.base_index, "Base index khớp")
	assert_true(decoded.series == it.series, "Ngũ hành khớp")
	assert_true(decoded.durability == it.durability, "Độ bền khớp")
	assert_true(decoded.magic.size() == 2, "Số dòng magic khớp")
	assert_true(decoded.magic[0].attrib == "attackrating_v", "Dòng magic 1 khớp")
	assert_true(decoded.magic[1].attrib == "addphysicsdamage_v", "Dòng magic 2 khớp")

func test_encode_decode_gold_item() -> void:
	print("[2] Test encode/decode trang bị hoàng kim...")
	var it := ItemGenerator.generate_gold(0)
	if it == null:
		it = ItemInstance.new()
		it.gold_index = 0
		it.series = ElementTypes.ElementType.KIM

	var token := ItemChatHelper.create_token(it)
	assert_true(token.begins_with("{item:") and token.ends_with("}"), "Token có format {item:...}")

	var payload := token.trim_prefix("{item:").trim_suffix("}")
	var decoded := ItemChatHelper.decode_item(payload)
	assert_true(decoded != null, "Giải mã thành công hoàng kim")
	assert_true(decoded.gold_index == it.gold_index, "Gold index khớp")
	assert_true(decoded.is_gold(), "Item vẫn là đồ hoàng kim sau khi decode")

func test_encode_decode_misc_item() -> void:
	print("[3] Test encode/decode vật phẩm tiêu hao / misc...")
	var it := ItemInstance.new()
	it.misc_id = "6_1_71"
	it.count = 10

	var encoded := ItemChatHelper.encode_item(it)
	var decoded := ItemChatHelper.decode_item(encoded)
	assert_true(decoded != null, "Giải mã thành công misc item")
	assert_true(decoded.misc_id == "6_1_71", "misc_id khớp")
	assert_true(decoded.count == 10, "Số lượng count khớp")

func test_format_chat_bbcode() -> void:
	print("[4] Test format BBCode tin nhắn chat...")
	var it := ItemInstance.new()
	it.base_index = 0
	var token := ItemChatHelper.create_token(it)
	var raw_msg := "Tôi có [món đồ xịn] bán này: " + token + " mua ngay!"

	var formatted := ItemChatHelper.format_chat_bbcode(raw_msg)
	assert_true(formatted.contains("[url=item:"), "BBCode chứa thẻ [url=item:...]")
	assert_true(formatted.contains("[/url]"), "BBCode chứa thẻ đóng [/url]")
	assert_true(formatted.contains("[lb]món đồ xịn[rb]") or formatted.contains("[lb]món đồ xịn"), "Ký tự [ của người chơi được escape an toàn")

func test_clean_plain_text() -> void:
	print("[5] Test lọc text thuần cho bong bóng chat...")
	var it := ItemInstance.new()
	it.base_index = 0
	var base_name := str(it.get_base().get("name", "Vật phẩm"))
	var token := ItemChatHelper.create_token(it)
	var raw_msg := "Bán " + token + " giá rẻ!"

	var clean := ItemChatHelper.clean_item_tags_for_plain_text(raw_msg)
	assert_true(clean == "Bán [%s] giá rẻ!" % base_name, "Bong bóng chat hiển thị tên món trong ngoặc vuông")
	assert_true(not clean.contains("{item:"), "Không còn token {item:...}")

func test_item_detail_popup_button() -> void:
	print("[6] Test nút Gắn vào chat trên ItemDetailPopup...")
	var it := ItemInstance.new()
	it.base_index = 0
	var popup := ItemDetailPopup.open(self, "Mô tả test", [], it)
	assert_true(popup != null, "Mở ItemDetailPopup thành công")

	var actions_node: VBoxContainer = popup.get_node("%Actions")
	var found_chat_btn := false
	for child in actions_node.get_children():
		if child is Button and child.visible and child.text == "Gắn vào chat":
			found_chat_btn = true
			break
	assert_true(found_chat_btn, "Có nút 'Gắn vào chat' trong bảng chi tiết vật phẩm")
	popup.queue_free()

func test_chat_panel_integration() -> void:
	print("[7] Test ChatPanel gắn link và click link mở popup...")
	var it := ItemInstance.new()
	it.base_index = 0
	var base_name := str(it.get_base().get("name", "Vật phẩm"))

	var panel := ChatPanel.open(self)
	assert_true(panel != null, "Mở ChatPanel thành công")
	await get_tree().process_frame

	# Gắn item vào chat
	panel.insert_item(it)
	var le: LineEdit = panel.get("_input")
	assert_true(le != null and le.text.contains("[%s]" % base_name), "Ô nhập chứa [%s]" % base_name)

	# Gõ thêm và gửi
	le.text = "Cần bán " + le.text + "ai mua pm"
	panel._send()

	var last_msg = ChatPanel.history.back()
	assert_true(last_msg != null, "Tin nhắn đã vào lịch sử chat")
	assert_true(str(last_msg.get("text", "")).contains("{item:"), "Tin nhắn gửi đi chứa token {item:...}")

	# Giả lập click vào link vật phẩm qua meta_clicked
	var token := ItemChatHelper.create_token(it)
	var payload := token.trim_prefix("{item:").trim_suffix("}")
	panel._on_meta_clicked("item:" + payload)

	# Tìm ItemDetailPopup vừa được mở ra
	await get_tree().process_frame
	var opened_popups := get_tree().root.find_children("*", "ItemDetailPopup", true, false)
	assert_true(opened_popups.size() > 0, "Bấm vào link chat mở được ItemDetailPopup xem thông tin vật phẩm")

	for p in opened_popups:
		p.queue_free()
	panel.queue_free()
	await get_tree().process_frame

func test_map_chat_link_bbcode() -> void:
	print("[8] Test format BBCode cho Map link [Map:44737382]...")
	var raw_text := "Ai rảnh vào train chung nè [Map:44737382] nhanh lên!"
	var formatted := MapChatHelper.format_chat_map_bbcode(raw_text)

	assert_true(formatted.contains("[url=map:44737382]"), "BBCode chứa [url=map:44737382]")
	assert_true(formatted.contains("[color=#00E5FF]"), "BBCode chứa màu xanh link map #00E5FF")
	assert_true(formatted.contains("[u]"), "BBCode có underline [u]")
	assert_true(formatted.contains("[Map:44737382]"), "BBCode giữ chữ [Map:44737382]")
	assert_true(formatted.contains("[/url]"), "BBCode có thẻ đóng [/url]")

func test_map_chat_panel_integration() -> void:
	print("[9] Test ChatPanel click link map mở popup xác nhận...")
	var panel := ChatPanel.open(self)
	assert_true(panel != null, "Mở ChatPanel thành công")
	await get_tree().process_frame

	# Gắn link map vào chat
	panel.insert_text("[Map:44737382]")
	var le: LineEdit = panel.get("_input")
	assert_true(le != null and le.text.contains("[Map:44737382]"), "Ô nhập chứa [Map:44737382]")

	# Giả lập click vào link [Map:44737382]
	panel._on_meta_clicked("map:44737382")
	await get_tree().process_frame

	# Tìm ConfirmationDialog xác nhận dịch chuyển vừa được mở
	var dialogs := get_tree().root.find_children("*", "ConfirmationDialog", true, false)
	assert_true(dialogs.size() > 0, "Mở được popup xác nhận dịch chuyển")
	var found_correct_dialog := false
	for d in dialogs:
		if d is ConfirmationDialog and d.dialog_text.contains("44737382"):
			found_correct_dialog = true
			d.queue_free()
			break
	assert_true(found_correct_dialog, "Nội dung popup có chứa ID phòng 44737382")

	panel.queue_free()
	await get_tree().process_frame

func test_share_from_pk_badge() -> void:
	print("[10] Test chia sẻ ID phòng thực tế từ PkRoomBadge vào ChatPanel...")
	var badge := PkRoomBadge.attach(self, "998877", PkRules.Mode.DAI_HOI)
	assert_true(badge != null, "Tạo PkRoomBadge thành công")
	assert_true(MapChatHelper.get_current_room_or_map_id() == "998877", "Lấy đúng ID phòng từ badge là 998877")

	# Bấm nút share từ badge
	badge._on_share()
	await get_tree().process_frame

	var panel := ChatPanel._open_panel
	assert_true(panel != null and is_instance_valid(panel), "ChatPanel tự động mở sau khi bấm chia sẻ từ badge")

	var le: LineEdit = panel.get("_input")
	assert_true(le != null and le.text.contains("[Map:998877]"), "Ô nhập chat tự động được điền [Map:998877]")

	# Gửi tin nhắn và kiểm tra kết quả render
	le.text = "Vào đấu trường PK cùng mình nhé " + le.text
	panel._send()

	var last_msg = ChatPanel.history.back()
	assert_true(last_msg != null and str(last_msg.get("text", "")).contains("[Map:998877]"), "Tin nhắn gửi vào lịch sử có chứa [Map:998877]")

	panel._render()
	var log_node: RichTextLabel = panel.get("_log")
	assert_true(log_node != null and log_node.text.contains("[url=map:998877]"), "Khung chat render ra thẻ liên kết [url=map:998877]")
	assert_true(log_node.text.contains("#00E5FF"), "Liên kết map có mã màu xanh #00E5FF")

	badge.queue_free()
	panel.queue_free()
	await get_tree().process_frame
