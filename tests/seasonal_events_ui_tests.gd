extends Control
## UI sự kiện năm: tab "Sự kiện Năm" của EventScheduleWindow (11 thẻ), cửa sổ Hướng dẫn, EventCraftWindow (đặt nguyên liệu,
## xem trước, Bắt đầu ép offline, phần dư giữ lại hành trang).
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/seasonal_events_ui_tests.tscn
## Chụp ảnh (chạy có cửa sổ): SHOT_DIR=<thư mục> godot --path . res://tests/seasonal_events_ui_tests.tscn
var _fail := 0

func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c:
		_fail += 1

func _give(p: PlayerProfile, mid: String, n: int) -> ItemInstance:
	var it := ItemGenerator.generate_misc(mid)
	it.count = n
	it.ensure_uid()
	p.add_item_stacked(it)
	for x in p.inventory:
		if x.misc_id == mid:
			return x
	return null

func _count(p: PlayerProfile, mid: String) -> int:
	var n := 0
	for it in p.inventory:
		if it.misc_id == mid:
			n += it.count
	return n

func _shot(name: String) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := PlayerProfile.new()
	p.level = 150
	p.gold = 500_000
	GameManager.local_profile = p

	## ---- tab Sự kiện Năm
	var win := EventScheduleWindow.new(p)
	add_child(win)
	await get_tree().process_frame
	win._select_main(1)
	await get_tree().process_frame
	check("tab Sự kiện Năm có 11 thẻ", win._list_container.get_child_count() == 11)
	check("ẩn bộ lọc của tab Ngày", not win._sub_tabs_box.visible)
	var crafts := win._list_container.find_children("*", "Button", true, false).filter(func(x): return (x as Button).text == "Chế tạo")
	check("chỉ sự kiện đang diễn ra có nút Chế tạo", crafts.size() == SeasonalEvents.active_ids().size())
	var boxes := 0
	for l in win._list_container.find_children("*", "Label", true, false):
		if (l as Label).text.contains("Vật phẩm rớt từ quái:"):
			boxes += 1
	check("mỗi thẻ có dòng Vật phẩm (hộp rơi)", boxes == 11)
	await _shot("1_year_tab")
	win._select_main(0)
	await get_tree().process_frame
	check("tab Sự kiện Ngày vẫn còn danh sách cũ", win._list_container.get_child_count() >= 10)
	win.queue_free()

	## ---- GM: tab Sự Kiện Năm
	var gm := GmControlWindow.new()
	add_child(gm)
	await get_tree().process_frame
	gm._current_tab = GmControlWindow.Tab.EVENTS
	gm._render_tab()
	await get_tree().process_frame
	check("GM tab Sự Kiện Năm: 11 dòng + đầu mục", gm._content_area.get_child_count() == 12)
	await _shot("5_gm_events")
	gm.queue_free()

	## ---- Hướng dẫn
	var teacher := SeasonalEvents.get_event("nha_giao")
	var guide := SeasonalEventUi.open_guide(self, SeasonalEvents.get_event(OS.get_environment("SHOT_GUIDE") if OS.get_environment("SHOT_GUIDE") != "" else "giang_sinh"))
	await get_tree().process_frame
	check("mở cửa sổ Hướng dẫn", guide != null and guide.is_inside_tree())
	await _shot("2_guide")
	if OS.get_environment("SHOT_SCROLL") != "":   ## chụp thêm phần dưới: SHOT_SCROLL=<px>
		var sc := guide.find_children("*", "ScrollContainer", true, false)
		if not sc.is_empty():
			await get_tree().process_frame
			(sc[0] as ScrollContainer).scroll_vertical = int(OS.get_environment("SHOT_SCROLL"))
			await _shot("2_guide_scroll")
	guide.queue_free()

	## ---- Chế tạo: 20/11 (đang diễn ra 26/11) — 11 Giấy Trắng + 2 Cây Bút + 3 Lọ Mực -> 2 Cuốn Sách, dư 1 giấy + 1 mực
	var paper := _give(p, "6_1_3039", 11)
	var pen := _give(p, "6_1_3040", 2)
	var ink := _give(p, "6_1_3041", 3)
	var stray := _give(p, "6_1_3074", 1)   ## áo giáng sinh — không phải nguyên liệu 20/11
	var craft := EventCraftWindow.new(teacher, p)
	add_child(craft)
	await get_tree().process_frame
	craft._place(paper, 11)
	craft._place(pen, 2)
	craft._place(ink, 3)
	craft._ask_place(stray)
	check("đặt đồ lạ bị từ chối", not craft._placed.has(stray.uid))
	check("ô chế tạo có 3 chồng", craft._slots.inventory.size() == 3)
	check("hành trang ẩn phần đã đặt", int(craft._bag_view.slotted_counts.get(paper.uid, 0)) == 11)
	var active := SeasonalEvents.is_active(teacher)
	if active:
		check("xem trước: ép 2 lần", craft._preview.text.contains("Ép 2 lần"))
		check("nút Bắt đầu bật", not craft._start_btn.disabled)
		await _shot("3_craft")
		craft._on_start()
		await get_tree().process_frame
		check("ép xong: 2 Cuốn Sách", _count(p, "6_1_3042") == 2)
		check("dư 1 Giấy Trắng, 1 Lọ Mực, 0 Cây Bút", _count(p, "6_1_3039") == 1 and _count(p, "6_1_3041") == 1 and _count(p, "6_1_3040") == 0)
		check("ô chế tạo trống sau khi ép", craft._placed.is_empty())
	else:
		check("ngoài đợt: nút Bắt đầu tắt", craft._start_btn.disabled)
	craft._auto_fill()
	check("Tự đặt nguyên liệu lấy phần còn lại", craft._placed.size() >= 1)
	await _shot("4_craft_after")
	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)
