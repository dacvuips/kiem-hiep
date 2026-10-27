extends SocialWindow
class_name PotionShopWindow
## HIỆU THUỐC (nút trong Hành trang): lưới ô như hành trang, mỗi ô 1 loại thuốc đang bán (PotionShop.items()). Bấm 1 ô -> hộp mua:
## nhập số lượng (− / + hoặc gõ), hiện đơn giá + tổng tiền, nút Mua.
##   - Đang ở trên map (online): gửi C_SHOP_BUY, game server mua trên hồ sơ của server rồi gửi bản nhân vật mới (S_PROFILE).
##   - Ngoài map (Hub) / offline: mua trên hồ sơ trong máy (PotionShop.buy) rồi lưu — online thì server tài khoản chỉ nhận thuốc mới khi
##     tiền đã trừ đủ theo bảng giá (profile_guard.go).

const COLUMNS := 8
const CELL := 52.0

var _host: Node
var _profile: PlayerProfile
var _gold_label: Label
var _message: Label
var _on_changed: Callable

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
	_gold_label = SocialUi.label("", SocialUi.GOLD, 14)
	body.add_child(_gold_label)
	_message = SocialUi.label("", SocialUi.WARN, 13)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLUMNS * (CELL + 4) + 12, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)
	var frame := GameUi.panel(GameUi.PANEL)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(frame)
	TouchScrollHelperScript.attach(scroll, frame)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	frame.add_child(grid)
	## Mỗi nhóm công dụng (PotionShop.category_of) bắt đầu ở đầu hàng mới — đệm ô trống cho hết hàng trước.
	var last := -1
	for mid in PotionShop.items():
		var cat := PotionShop.category_of(mid)
		if last != -1 and cat != last:
			while grid.get_child_count() % COLUMNS != 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(CELL, CELL)
				grid.add_child(gap)
		last = cat
		grid.add_child(_cell(mid))
	NetClient.server_notice.connect(_on_notice)

## 1 ô lưới: ảnh thuốc trên nền ô kiểu hành trang.
func _cell(mid: String) -> Control:
	var rec := ItemDatabase.get_misc(mid)
	var b := Button.new()
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "[%s] %s — %s%s" % [PotionShop.CATEGORY_NAMES[PotionShop.category_of(mid)], str(rec.get("name", mid)), PotionShop.cost_text(mid),
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
		if r.get("ok", false) or (NetClient.is_in_world() and not NetClient.is_hub):
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
	if NetClient.is_in_world() and not NetClient.is_hub:
		NetClient.send_shop_buy(mid, n)   ## kết quả: S_NOTICE + S_PROFILE từ server
		return {"ok": true, "message": "Đang gửi yêu cầu mua tới máy chủ…"}
	var r := PotionShop.buy(p, mid, n)
	_message.text = str(r["message"])
	if is_instance_valid(_host) and _host.has_method("_show_toast"):
		_host.call("_show_toast", str(r["message"]))
	if r["ok"]:
		SaveManager.save_profile(p)
		if AccountApi.is_logged_in():
			SaveManager.flush_online()
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
	_gold_label.text = ("Ngân lượng: %s    Điểm Tống Kim: %d" % [InventoryPopup.format_money(p.gold), p.songjin_points]) if p else ""
