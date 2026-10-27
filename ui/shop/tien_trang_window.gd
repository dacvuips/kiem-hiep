extends SocialWindow
class_name TienTrangWindow

## TIỀN TRANG (Hệ thống Tiền Xu, Nạp Thẻ & Quy đổi Kim Nguyên Bảo chuẩn VLTK):
## Cho phép người chơi xem 3 loại tài sản: Ngân Lượng, Tiền Xu (tài khoản/nhân vật), và Kim Nguyên Bảo (KNB).
## Cung cấp 2 chức năng chính:
##   1. Đổi Tiền Xu -> Kim Nguyên Bảo (KNB) cho nhân vật hiện tại.
##   2. Nạp thêm Tiền Xu (hỗ trợ Sandbox test ngay trong game hoặc nạp thẻ thật qua cổng thanh toán).

const ICON_XU := "res://assets/items/icons/tongqian.png"
const ICON_JADE := "res://assets/items/icons/obj_item_cardg.png"
const ICON_GOLD := "res://assets/ui/bo_icon_nhan_vat/tai_nguyen/ico_vang.png"

var _host: Node
var _profile: PlayerProfile
var _on_changed: Callable

var _gold_label: Label
var _xu_label: Label
var _jade_label: Label
var _message: Label

var _tab_transfer_btn: Button
var _tab_topup_btn: Button
var _transfer_panel: VBoxContainer
var _topup_panel: VBoxContainer

var _xu_input: LineEdit
var _transfer_preview: Label
var _transfer_btn: Button

var _jade_per_xu: int = 1
var _xu_per_10k: int = 100
var _is_sandbox: bool = true
var _packs: Array = []

static func open(host: Node, on_changed: Callable = Callable(), profile: PlayerProfile = null) -> TienTrangWindow:
	var win := TienTrangWindow.new()
	win._host = host
	win._on_changed = on_changed
	win._profile = profile
	if win._profile == null and host != null and "_profile" in host:
		win._profile = host.get("_profile") as PlayerProfile
	if win._profile == null:
		win._profile = GameManager.local_profile
	return SocialWindow.present(host, win, &"tien_trang") as TienTrangWindow

func _init() -> void:
	super._init("Chủ Tiền Trang", "Quản lý Tiền Xu tài khoản & Quy đổi Kim Nguyên Bảo", 480.0)
	_build_ui()
	_load_data()

func _build_ui() -> void:
	# Khung tóm tắt 3 loại tiền tệ
	var summary_box := PanelContainer.new()
	summary_box.add_theme_stylebox_override("panel", GameUi.box(GameUi.BG_INNER, GameUi.BORDER, 6, 1, 8))
	body.add_child(summary_box)

	var sum_h := HBoxContainer.new()
	sum_h.add_theme_constant_override("separation", 10)
	summary_box.add_child(sum_h)

	var gold_col := _build_currency_card("Ngân Lượng", ICON_GOLD, SocialUi.GOLD)
	_gold_label = gold_col.get_node("Value") as Label
	sum_h.add_child(gold_col)

	var xu_col := _build_currency_card("Tiền Xu", ICON_XU, Color(0.4, 0.85, 1.0))
	_xu_label = xu_col.get_node("Value") as Label
	sum_h.add_child(xu_col)

	var jade_col := _build_currency_card("Kim Nguyên Bảo", ICON_JADE, Color(1.0, 0.8, 0.2))
	_jade_label = jade_col.get_node("Value") as Label
	sum_h.add_child(jade_col)

	# Thông báo
	_message = SocialUi.label("", SocialUi.WARN, 13)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_message)

	# Tab Header
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	body.add_child(tab_bar)

	_tab_transfer_btn = GameUi.button("Đổi Xu Sang KNB", GameUi.TAB)
	_tab_transfer_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_transfer_btn.pressed.connect(_switch_tab.bind(0))
	tab_bar.add_child(_tab_transfer_btn)

	_tab_topup_btn = GameUi.button("Nạp Tiền Xu", GameUi.TAB)
	_tab_topup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_topup_btn.pressed.connect(_switch_tab.bind(1))
	tab_bar.add_child(_tab_topup_btn)

	var tab_ktc_btn := GameUi.button("Kỳ Trân Các", GameUi.TAB)
	tab_ktc_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_ktc_btn.pressed.connect(func() -> void:
		KyTranCacWindow.open(_host, _on_changed, _profile)
	)
	tab_bar.add_child(tab_ktc_btn)

	# Panel 1: Đổi Xu sang KNB
	_transfer_panel = VBoxContainer.new()
	_transfer_panel.add_theme_constant_override("separation", 10)
	body.add_child(_transfer_panel)
	_build_transfer_tab()

	# Panel 2: Nạp Thẻ
	_topup_panel = VBoxContainer.new()
	_topup_panel.add_theme_constant_override("separation", 10)
	_topup_panel.visible = false
	body.add_child(_topup_panel)
	_build_topup_tab()

	_switch_tab(0)

func _build_currency_card(title_text: String, icon_path: String, val_color: Color) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)

	var header_h := HBoxContainer.new()
	header_h.alignment = BoxContainer.ALIGNMENT_CENTER
	header_h.add_theme_constant_override("separation", 4)
	col.add_child(header_h)

	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header_h.add_child(icon)

	var t_lbl := SocialUi.label(title_text, SocialUi.MUTED, 12)
	header_h.add_child(t_lbl)

	var v_lbl := SocialUi.label("0", val_color, 14, HORIZONTAL_ALIGNMENT_CENTER)
	v_lbl.name = "Value"
	col.add_child(v_lbl)
	return col

func _build_transfer_tab() -> void:
	var info := SocialUi.label("Tỉ lệ: 1 Xu = 1 Kim Nguyên Bảo (KNB).\nKNB quy đổi được cộng trực tiếp vào nhân vật đang chơi.", SocialUi.TEXT, 13)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_transfer_panel.add_child(info)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	_transfer_panel.add_child(input_row)

	var input_lbl := SocialUi.label("Số Xu muốn đổi:", SocialUi.LABEL_BLUE, 14)
	input_row.add_child(input_lbl)

	_xu_input = GameUi.line_edit("Nhập số Xu...")
	_xu_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xu_input.text_changed.connect(_on_xu_input_changed)
	input_row.add_child(_xu_input)

	# Các nút chọn nhanh
	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 6)
	_transfer_panel.add_child(quick_row)

	for val in [10, 50, 100, 500, 1000]:
		var btn := GameUi.button("+%d" % val, GameUi.BUTTON)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 30
		btn.pressed.connect(_add_xu_input.bind(val))
		quick_row.add_child(btn)

	var all_btn := GameUi.button("Tất Cả", GameUi.BUTTON)
	all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_btn.custom_minimum_size.y = 30
	all_btn.pressed.connect(func() -> void:
		_xu_input.text = str(_get_current_xu())
		_on_xu_input_changed(_xu_input.text)
	)
	quick_row.add_child(all_btn)

	_transfer_preview = SocialUi.label("Nhận được: 0 KNB", SocialUi.GOLD, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_transfer_panel.add_child(_transfer_preview)

	_transfer_btn = SocialUi.stone_button("XÁC NHẬN ĐỔI SANG KNB", Vector2(0, 42))
	_transfer_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transfer_btn.pressed.connect(_on_confirm_transfer)
	_transfer_panel.add_child(_transfer_btn)

func _build_topup_tab() -> void:
	var info := SocialUi.label("Chọn mệnh giá nạp tiền vào Ví Xu tài khoản (10.000 VNĐ = 100 Xu):", SocialUi.TEXT, 13)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_topup_panel.add_child(info)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 200
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_topup_panel.add_child(scroll)

	var pack_container := VBoxContainer.new()
	pack_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_container.add_theme_constant_override("separation", 6)
	scroll.add_child(pack_container)
	TouchScrollHelperScript.attach(scroll, pack_container)

	var default_packs := [
		{"amount_vnd": 10000, "xu": 100},
		{"amount_vnd": 20000, "xu": 200},
		{"amount_vnd": 50000, "xu": 500},
		{"amount_vnd": 100000, "xu": 1000},
		{"amount_vnd": 200000, "xu": 2000},
		{"amount_vnd": 500000, "xu": 5000},
		{"amount_vnd": 1000000, "xu": 10000},
	]

	for p in default_packs:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", GameUi.box(GameUi.BG_INNER, GameUi.BORDER, 4, 1, 6))
		pack_container.add_child(row)

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)

		var vnd_lbl := SocialUi.label(InventoryPopup.format_money(int(p.amount_vnd)) + " VNĐ", SocialUi.TEXT, 14)
		vnd_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(vnd_lbl)

		var xu_lbl := SocialUi.label("+%s Xu" % InventoryPopup.format_money(int(p.xu)), Color(0.4, 0.85, 1.0), 14)
		h.add_child(xu_lbl)

		var pay_btn := GameUi.button("Nạp Gói", GameUi.PRIMARY)
		pay_btn.custom_minimum_size = Vector2(80, 32)
		pay_btn.pressed.connect(_on_topup_pack_pressed.bind(int(p.amount_vnd), int(p.xu)))
		h.add_child(pay_btn)

func _switch_tab(idx: int) -> void:
	GameUi.set_active(_tab_transfer_btn, idx == 0)
	GameUi.set_active(_tab_topup_btn, idx == 1)
	_transfer_panel.visible = (idx == 0)
	_topup_panel.visible = (idx == 1)
	_message.text = ""

func _load_data() -> void:
	_refresh_display()
	if AccountApi.is_logged_in():
		var cfg := await AccountApi.shop_config()
		if cfg.ok and cfg.data is Dictionary:
			_jade_per_xu = int(cfg.data.get("jade_per_xu", 1))
			_xu_per_10k = int(cfg.data.get("xu_per_10k", 100))
			_is_sandbox = bool(cfg.data.get("sandbox", true))

		var w := await AccountApi.shop_wallet()
		if w.ok and w.data is Dictionary:
			var wallet_xu := int(w.data.get("xu", 0))
			if _profile:
				_profile.xu = wallet_xu
				_refresh_display()

func _refresh_display() -> void:
	if _profile == null:
		return
	if _gold_label:
		_gold_label.text = InventoryPopup.format_money(_profile.gold) + " Lượng"
	if _xu_label:
		_xu_label.text = InventoryPopup.format_money(_get_current_xu()) + " Xu"
	if _jade_label:
		_jade_label.text = InventoryPopup.format_money(_profile.jade) + " KNB"
	_on_xu_input_changed(_xu_input.text if _xu_input else "")

func _get_current_xu() -> int:
	return _profile.xu if _profile else 0

func _on_xu_input_changed(text: String) -> void:
	var cleaned := ""
	for c in text:
		if c >= "0" and c <= "9":
			cleaned += c
	var amount := cleaned.to_int()
	if _transfer_preview:
		_transfer_preview.text = "Nhận được: %s Kim Nguyên Bảo" % InventoryPopup.format_money(amount * _jade_per_xu)

func _add_xu_input(amount: int) -> void:
	var cur := _xu_input.text.to_int()
	var next := mini(cur + amount, _get_current_xu())
	_xu_input.text = str(next)
	_on_xu_input_changed(_xu_input.text)

func _on_confirm_transfer() -> void:
	_message.text = ""
	var xu := _xu_input.text.to_int()
	if xu <= 0:
		_message.text = "Vui lòng nhập số Xu muốn đổi."
		_message.add_theme_color_override("font_color", SocialUi.WARN)
		return

	if xu > _get_current_xu():
		_message.text = "Số Tiền Xu trong ví không đủ."
		_message.add_theme_color_override("font_color", SocialUi.WARN)
		return

	_transfer_btn.disabled = true
	var char_id := SaveManager.online_character_id

	# Nếu đã đăng nhập server tài khoản
	if AccountApi.is_logged_in() and char_id > 0:
		var r := await AccountApi.transfer_xu_to_jade(char_id, xu)
		_transfer_btn.disabled = false
		if not r.ok:
			_message.text = str(r.get("message", "Đổi Xu thất bại, vui lòng thử lại."))
			_message.add_theme_color_override("font_color", SocialUi.WARN)
			return

		var remaining_xu := int(r.data.get("xu", _profile.xu - xu))
		var added_jade := int(r.data.get("jade", xu * _jade_per_xu))
		_profile.xu = remaining_xu
		_profile.jade += added_jade
	else:
		# Chế độ Offline / Test local
		_transfer_btn.disabled = false
		_profile.xu -= xu
		_profile.jade += xu * _jade_per_xu

	SaveManager.save_profile(_profile)
	if NetClient.is_in_world():
		NetClient.send_profile(_profile.to_dict())

	_message.text = "Đổi thành công %s Xu sang %s Kim Nguyên Bảo!" % [
		InventoryPopup.format_money(xu), InventoryPopup.format_money(xu * _jade_per_xu)
	]
	_message.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_xu_input.text = ""
	_refresh_display()
	if _on_changed.is_valid():
		_on_changed.call()

func _on_topup_pack_pressed(amount_vnd: int, pack_xu: int) -> void:
	_message.text = "Đang xử lý nạp gói..."
	_message.add_theme_color_override("font_color", SocialUi.MUTED)

	if AccountApi.is_logged_in():
		var r := await AccountApi.create_topup_order(amount_vnd)
		if not r.ok:
			_message.text = str(r.get("message", "Tạo đơn nạp thất bại."))
			_message.add_theme_color_override("font_color", SocialUi.WARN)
			return

		var order: Dictionary = r.data.get("order", {})
		var code: String = str(order.get("code", ""))

		# Nếu sandbox bật, thanh toán giả lập tự động thành công để test tiện lợi
		if _is_sandbox and code != "":
			var p_res := await AccountApi.pay_sandbox_order(code)
			if p_res.ok:
				_profile.xu += pack_xu
				SaveManager.save_profile(_profile)
				_message.text = "Thanh toán giả lập thành công! Nhận +%s Xu." % InventoryPopup.format_money(pack_xu)
				_message.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
				_refresh_display()
				if _on_changed.is_valid():
					_on_changed.call()
				return
		# Nếu là cổng thanh toán thật: mở URL thanh toán
		var pay_url: String = str(r.data.get("pay_url", ""))
		if pay_url != "":
			if pay_url.begins_with("/"):
				pay_url = AccountApi.base_url + pay_url
			OS.shell_open(pay_url)
			_message.text = "Đã mở cổng thanh toán. Hoàn tất nạp thẻ để nhận Xu."
			_message.add_theme_color_override("font_color", SocialUi.GOLD)
	else:
		# Chế độ Offline / Test
		_profile.xu += pack_xu
		SaveManager.save_profile(_profile)
		_message.text = "Nạp thành công +%s Xu (chế độ thử nghiệm)." % InventoryPopup.format_money(pack_xu)
		_message.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		_refresh_display()
		if _on_changed.is_valid():
			_on_changed.call()
