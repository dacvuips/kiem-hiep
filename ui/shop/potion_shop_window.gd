extends SocialWindow
class_name PotionShopWindow
## HIỆU THUỐC (nút trong Hành trang): lưới ô như hành trang, phân theo Tab:
##   - Tab "Dược Điếm": chuẩn các loại thuốc hồi phục VLTK 1 chính thống.
##   - Tab "Quân Nhu Tống Kim": vật phẩm chiến trường Tống Kim (Chiến Cổ, Lệnh Bài, Càn Khôn Tạo Hóa Đan, các loại Hoàn...).
## Bấm 1 ô -> hộp mua: nhập số lượng (− / + hoặc gõ), hiện đơn giá + tổng tiền, nút Mua.
##   - Đang ở trên map (online): gửi C_SHOP_BUY, game server mua trên hồ sơ của server rồi gửi bản nhân vật mới (S_PROFILE).
##   - Ngoài map (Hub) / offline: mua trên hồ sơ trong máy (PotionShop.buy) rồi lưu.

const COLUMNS := 8
const CELL := 52.0

## Tên viết tắt hiển thị trên ô cho các loại hoàn Tống Kim (dùng chung icon obj-potion15):
const SHORT_NAMES := {
	"6_177": "N.Phổ",
	"6_178": "N.Độc",
	"6_179": "N.Băng",
	"6_180": "Nội Phổ",
	"6_181": "Nội Độc",
	"6_182": "Nội Băng",
	"6_183": "Nội Hỏa",
	"6_184": "Nội Lôi",
	"6_185": "Tr.Mệnh",
	"6_186": "Gia Tốc",
	"6_187": "C.Thiểm",
	"6_188": "C.Trung",
	"6_189": "Phi Tốc",
}

var _host: Node
var _profile: PlayerProfile
var _gold_label: Label
var _message: Label
var _on_changed: Callable
var _grid: GridContainer
var _tab_buttons: Array[Button] = []
var _current_tab: int = 0

static func open(host: Node, on_changed: Callable = Callable(), profile: PlayerProfile = null) -> PotionShopWindow:
	var win := PotionShopWindow.new()
	win._host = host
	win._on_changed = on_changed
	win._profile = profile
	if win._profile == null and host != null and "_profile" in host:
		win._profile = host.get("_profile") as PlayerProfile
	return SocialWindow.present(host, win, &"potion_shop") as PotionShopWindow

func _init() -> void:
	super._init("Hiệu Thuốc", "Bấm vào thuốc để mua", COLUMNS * (CELL + 4) + 40)
	
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	body.add_child(tab_row)
	
	var tab_names := ["Dược Điếm", "Quân Nhu Tống Kim"]
	for i in tab_names.size():
		var btn := GameUi.button(tab_names[i], GameUi.TAB)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 32
		btn.pressed.connect(_select_tab.bind(i))
		tab_row.add_child(btn)
		_tab_buttons.append(btn)
	
	_gold_label = SocialUi.label("", SocialUi.GOLD, 14)
	body.add_child(_gold_label)
	_message = SocialUi.label("", SocialUi.WARN, 13)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLUMNS * (CELL + 4) + 12, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)
	
	var frame := GameUi.panel(GameUi.PANEL)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(frame)
	TouchScrollHelperScript.attach(scroll, frame)
	
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	frame.add_child(_grid)
	
	_select_tab(0)
	NetClient.server_notice.connect(_on_notice)

func _select_tab(idx: int) -> void:
	_current_tab = idx
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == idx)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	
	if idx == 0:
		var last := -1
		for mid in PotionShop.items():
			var cat := PotionShop.category_of(mid)
			if last != -1 and cat != last:
				while _grid.get_child_count() % COLUMNS != 0:
					var gap := Control.new()
					gap.custom_minimum_size = Vector2(CELL, CELL)
					_grid.add_child(gap)
			last = cat
			_grid.add_child(_cell(mid))
	else:
		for mid in PotionShop.songjin_items():
			_grid.add_child(_cell(mid))

## 1 ô lưới: ảnh thuốc trên nền ô kiểu hành trang.
func _cell(mid: String) -> Control:
	var rec := ItemDatabase.get_misc(mid)
	var b := Button.new()
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_NONE
	var cat_name: String = str(PotionShop.CATEGORY_NAMES[clampi(PotionShop.category_of(mid), 0, PotionShop.CATEGORY_NAMES.size() - 1)])
	b.tooltip_text = "[%s] %s — %s%s" % [cat_name, str(rec.get("name", mid)), PotionShop.cost_text(mid),
		" (chỉ dùng trong Tống Kim)" if bool(rec.get("songjin_only", false)) else ""]
	b.add_theme_stylebox_override("normal", GameUi.box(GameUi.BG_INNER, GameUi.BORDER, 4, 1, 2))
	b.add_theme_stylebox_override("hover", GameUi.box(GameUi.BG_INNER, GameUi.BORDER_ACTIVE, 4, 1, 2))
	b.add_theme_stylebox_override("pressed", GameUi.box(GameUi.ACTIVE_BG, GameUi.BORDER_ACTIVE, 4, 1, 2))
	var icon := TextureRect.new()
	icon.texture = ItemDatabase.get_icon(rec)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(4, 4)
	icon.size = Vector2(CELL - 8, CELL - 8)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	
	if SHORT_NAMES.has(mid):
		var lbl := Label.new()
		lbl.text = SHORT_NAMES[mid]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(1, CELL - 16)
		lbl.size = Vector2(CELL - 2, 14)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", SocialUi.GOLD)
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0, 0, 0, 0.75)
		s.corner_radius_top_left = 2
		s.corner_radius_top_right = 2
		s.corner_radius_bottom_left = 2
		s.corner_radius_bottom_right = 2
		lbl.add_theme_stylebox_override("normal", s)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lbl)
	
	b.pressed.connect(_open_buy.bind(mid))
	return b

## Hộp mua 1 loại thuốc: số lượng + tổng tiền.
func _open_buy(mid: String) -> void:
	var rec := ItemDatabase.get_misc(mid)
	var win := SocialWindow.new(str(rec.get("name", mid)), "", 360.0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ItemDatabase.get_icon(rec)
	head.add_child(icon)
	var intro := SocialUi.label(ItemText.plain(ItemText.clean_vltk_tags(str(rec.get("intro", "")))), SocialUi.TEXT, 13)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(intro)
	win.body.add_child(head)
	win.body.add_child(SocialUi.label("Đơn giá: %s" % PotionShop.cost_text(mid), SocialUi.MUTED, 13))
	if bool(rec.get("songjin_only", false)):
		win.body.add_child(SocialUi.label("Chỉ dùng được trong Chiến trường Tống Kim.", SocialUi.WARN, 12))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(SocialUi.label("Số lượng:", SocialUi.TEXT, 14))
	var minus := SocialUi.small_button("−")
	minus.custom_minimum_size = Vector2(32, 30)
	row.add_child(minus)
	var qty := SocialUi.line_edit("1")
	qty.text = "1"
	qty.custom_minimum_size = Vector2(70, 30)
	qty.alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty.max_length = 2
	row.add_child(qty)
	var plus := SocialUi.small_button("+")
	plus.custom_minimum_size = Vector2(32, 30)
	row.add_child(plus)
	win.body.add_child(row)
	var total := SocialUi.label("", SocialUi.GOLD, 15, HORIZONTAL_ALIGNMENT_CENTER)
	win.body.add_child(total)
	var err_label := SocialUi.label("", SocialUi.WARN, 12, HORIZONTAL_ALIGNMENT_CENTER)
	err_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win.body.add_child(err_label)
	var count := func() -> int:
		return clampi(int(qty.text) if qty.text.strip_edges().is_valid_int() else 1, 1, PotionShop.MAX_COUNT)
	var update := func() -> void:
		total.text = "Tổng: %s" % PotionShop.cost_text(mid, count.call())
		err_label.text = ""
	qty.text_changed.connect(func(_t: String) -> void: update.call())
	minus.pressed.connect(func() -> void:
		qty.text = str(maxi(1, count.call() - 1))
		update.call())
	plus.pressed.connect(func() -> void:
		qty.text = str(mini(PotionShop.MAX_COUNT, count.call() + 1))
		update.call())
	update.call()
	var buttons := win.add_button_row()
	var buy := SocialUi.stone_button("Mua")
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(func() -> void:
		var r := _buy(mid, count.call())
		if r.get("ok", false) or NetClient.is_in_world():
			win.close_requested.emit()
		else:
			err_label.text = str(r.get("message", "Không thể mua."))
	)
	buttons.add_child(buy)
	var cancel := SocialUi.stone_button("Huỷ")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: win.close_requested.emit())
	buttons.add_child(cancel)
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var target_host: Node = _host if is_instance_valid(_host) else (tree.current_scene if tree != null else null)
	if target_host != null:
		SocialWindow.present(target_host, win, &"potion_buy")

func _get_active_profile() -> PlayerProfile:
	if _profile != null:
		return _profile
	if GameManager.local_profile != null:
		return GameManager.local_profile
	if _host != null and "_profile" in _host and _host.get("_profile") != null:
		return _host.get("_profile") as PlayerProfile
	return null

func _buy(mid: String, n: int) -> Dictionary:
	var p := _get_active_profile()
	if p == null:
		var err := {"ok": false, "message": "Không tìm thấy hồ sơ nhân vật."}
		_message.text = err["message"]
		return err
	if NetClient.is_in_world():
		NetClient.send_shop_buy(mid, n)   ## kết quả: S_NOTICE + S_PROFILE từ server
		return {"ok": true, "message": "Đang gửi yêu cầu mua tới máy chủ…"}
	var r := PotionShop.buy(p, mid, n)
	_message.text = str(r["message"])
	if is_instance_valid(_host) and _host.has_method("_show_toast"):
		_host.call("_show_toast", str(r["message"]))
	if r["ok"]:
		SaveManager.save_profile(p, true)
		if _on_changed.is_valid():
			_on_changed.call()
	return r

func _on_notice(text: String) -> void:
	if is_instance_valid(_message):
		_message.text = text
	if is_instance_valid(_host) and _host.has_method("_show_toast"):
		_host.call("_show_toast", text)
	if _on_changed.is_valid():
		_on_changed.call_deferred()

func _process(_d: float) -> void:
	var p := _get_active_profile()
	if p == null:
		_gold_label.text = ""
		return
	if _current_tab == 0:
		_gold_label.text = "Ngân lượng: %s" % InventoryPopup.format_money(p.gold)
	else:
		_gold_label.text = "Ngân lượng: %s    Điểm Tống Kim: %d" % [InventoryPopup.format_money(p.gold), p.songjin_points]
