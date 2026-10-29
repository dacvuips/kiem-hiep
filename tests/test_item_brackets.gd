extends Node
## Kiểm thử hiển thị biên độ [min - max] (trắng) và [Max] (xanh đậm) cho thuộc tính trang bị

var _passes := 0
var _fails := 0

func check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("PASS: %s" % name)
	else:
		_fails += 1
		printerr("FAIL: %s" % name)

func _ready() -> void:
	print("\n--- BẮT ĐẦU TEST HIỂN THỊ [MIN - MAX] VÀ [MAX] THUỘC TÍNH TRANG BỊ ---")

	# 1. Kiểm tra ItemDatabase.get_magic_range
	var r_hp := ItemDatabase.get_magic_range("lifemax_v")
	check("lifemax_v range min=5, max=200", r_hp.x == 5 and r_hp.y == 200)

	var r_sta := ItemDatabase.get_magic_range("staminamax_v")
	check("staminamax_v range min=5, max=200", r_sta.x == 5 and r_sta.y == 200)

	# 2. Tạo món đồ xanh có dòng chưa max (125 / 200)
	var item1 := ItemInstance.new()
	item1.base_index = 0
	item1.magic = [{"attrib": "lifemax_v", "value": [125, 0, 0], "name": "Tăng Sinh lực", "prefix": true}]
	var bbcode1 := ItemText.build(item1, null, -1, -1, false)
	var plain1 := ItemText.plain(bbcode1)
	check("Dòng chưa max có [5 - 200]", plain1.contains("[5 - 200]"))
	check("Dòng chưa max có màu trắng ffffff", bbcode1.contains("[color=#ffffff][lb]5 - 200[rb][/color]"))

	# 3. Tạo món đồ xanh có dòng đạt MAX (200 / 200)
	var item2 := ItemInstance.new()
	item2.base_index = 0
	item2.magic = [{"attrib": "lifemax_v", "value": [200, 0, 0], "name": "Tăng Sinh lực", "prefix": true}]
	var bbcode2 := ItemText.build(item2, null, -1, -1, false)
	var plain2 := ItemText.plain(bbcode2)
	check("Dòng đạt max có [Max]", plain2.contains("[Max]"))
	check("Dòng đạt max KHÔNG còn [5 - 200]", not plain2.contains("[5 - 200]"))
	check("Dòng đạt max có màu Xanh đậm C_ATTR_MAX", bbcode2.contains("[color=#%s][lb]Max[rb][/color]" % ItemText.C_ATTR_MAX))

	# 4. Kiểm tra đồ hoàng kim hoàn mỹ cao cấp đạt MAX toàn game (Mộng Long Tăng Mão - sinh lực 200)
	var gold_item := ItemGenerator.generate_gold(0, 10)
	if gold_item:
		var bbcode_gold := ItemText.build(gold_item, null, -1, -1, false)
		var plain_gold := ItemText.plain(bbcode_gold)
		check("Đồ hoàng kim đạt max toàn game có [Max]", plain_gold.contains("[Max]"))

	# 5. Kiểm tra đồ Kim Phong tân thủ (cấp 60 - sinh lực 80, kháng 18 không bị coi là [Max] mà hiện biên độ [min - max])
	var kp_idx := ItemDatabase.gold_index_of_row(184)
	var kp_item := ItemGenerator.generate_gold(kp_idx, 10)
	if kp_item:
		var bbcode_kp := ItemText.build(kp_item, null, -1, -1, false)
		var plain_kp := ItemText.plain(bbcode_kp)
		check("Kim Phong sinh lực 80 KHÔNG có [Max]", not plain_kp.contains("Sinh lực tối đa: +80 điểm [Max]"))
		check("Kim Phong sinh lực 80 hiển thị biên độ [60 - 80]", plain_kp.contains("[60 - 80]"))
		check("Kim Phong kháng lôi 18 hiển thị biên độ [6 - 18]", plain_kp.contains("[6 - 18]"))

	# 6. Kiểm tra ItemDetailPopup: không autowrap để các dòng thuộc tính không xuống hàng
	var popup: ItemDetailPopup = ItemDetailPopup.open(self, bbcode1, [], item1)
	var body: RichTextLabel = popup.get_node("%Body")
	var scroll: ScrollContainer = popup.get_node("%BodyScroll")
	check("ItemDetailPopup body autowrap_mode là AUTOWRAP_OFF (0)", body.autowrap_mode == TextServer.AUTOWRAP_OFF)
	await get_tree().process_frame
	check("ItemDetailPopup scroll width >= 430", scroll.custom_minimum_size.x >= 430.0)
	popup.queue_free()

	print("--- HOÀN TẤT TEST: %d PASS, %d FAIL ---\n" % [_passes, _fails])
