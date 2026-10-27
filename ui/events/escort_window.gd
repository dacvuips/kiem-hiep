extends SocialWindow
class_name EscortWindow
## Long Môn Tiêu Cục (Vận Tiêu Giang Hồ — Thuần IDLE & Thực Địa):
##   - Hỗ trợ 4 Bản đồ lớn nguyên bản VLTK: Thành Đô, Tây Phục Ngưu Sơn, Hành Sơn, Lâm An.
##   - Chạy ngầm theo thời gian thực (10 - 45 phút), người chơi có thể thoát game rảnh tay.
##   - Vào bảo vệ / hộ tiêu bất kỳ lúc nào mà không bị reset quãng đường.
##   - Khi cập bến an toàn, nhận lại toàn bộ tiền cọc + lãi Ngân lượng dồi dào + EXP + Điểm Cống Hiến Bang Hội.

const RECORD_PATH := "user://escort_records.json"
const RUNS_PER_DAY := 3

const EscortManagerScript = preload("res://systems/challenge/escort_manager.gd")
const EscortChallengeScript = preload("res://systems/challenge/escort_challenge.gd")

const CARTS := [
	{
		"id": "wood",
		"name": "📦 Tiêu Xa Gỗ (Sơ Cấp)",
		"map_id": 37,
		"map_name": "Biện Kinh (Ngoại Thành)",
		"duration_sec": 600,       ## 10 phút
		"deposit_gold": 50000,
		"deposit_jade": 0,
		"reward_gold": 120000,
		"reward_exp": 150000,
		"reward_contrib": 50,
		"color": Color(0.85, 0.75, 0.55),
		"route": "Quan Lộ Ngoại Thành (Biện Kinh)"
	},
	{
		"id": "bronze",
		"name": "🛡️ Tiêu Xa Đồng (Trung Cấp)",
		"map_id": 37,
		"map_name": "Biện Kinh (Ngoại Thành)",
		"duration_sec": 1200,      ## 20 phút
		"deposit_gold": 150000,
		"deposit_jade": 0,
		"reward_gold": 380000,
		"reward_exp": 350000,
		"reward_contrib": 150,
		"color": Color(0.4, 0.85, 0.95),
		"route": "Quan Lộ Ngoại Thành (Biện Kinh)"
	},
	{
		"id": "silver",
		"name": "⚔️ Tiêu Xa Bạc (Cao Cấp)",
		"map_id": 37,
		"map_name": "Biện Kinh (Ngoại Thành)",
		"duration_sec": 1800,      ## 30 phút
		"deposit_gold": 300000,
		"deposit_jade": 0,
		"reward_gold": 800000,
		"reward_exp": 700000,
		"reward_contrib": 300,
		"color": Color(0.9, 0.65, 1.0),
		"route": "Quan Lộ Ngoại Thành (Biện Kinh)"
	},
	{
		"id": "gold",
		"name": "👑 Thần Tiêu Hoàng Kim (Cực Phẩm)",
		"map_id": 37,
		"map_name": "Biện Kinh (Ngoại Thành)",
		"duration_sec": 2700,      ## 45 phút
		"deposit_gold": 500000,
		"deposit_jade": 20,
		"reward_gold": 1600000,
		"reward_exp": 1500000,
		"reward_contrib": 600,
		"color": Color(1.0, 0.85, 0.25),
		"route": "Toàn Tuyến Quan Lộ Ngoại Thành (Biện Kinh)"
	}
]

var _profile: PlayerProfile
var _on_enter_field: Callable
var _scroll: ScrollContainer
var _content_box: VBoxContainer
var _timer: Timer
var _status_lbl: Label

static func open(host: Node, profile: PlayerProfile, on_enter_field: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/events/escort_window.gd")
	var win: SocialWindow = script.new(profile, on_enter_field)
	return SocialWindow.present(host, win, &"escort")

func _init(profile: PlayerProfile = null, on_enter_field: Callable = Callable()) -> void:
	super._init("Long Môn Tiêu Cục (Vận Tiêu Cá Nhân)", "Xuất hành tiêu xa viễn chinh — Tham gia Hộ Tiêu hoặc Cướp Tiêu đoạt bảo", 700.0)
	_profile = profile
	_on_enter_field = on_enter_field

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 480)
	body.add_child(_scroll)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 10)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_box)

	_timer = Timer.new()
	_timer.wait_time = 10.0 # Danh sách cập nhật 10s / lần
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	_render()

static var test_bypass_day: bool = false

static func is_escort_day() -> bool:
	if test_bypass_day:
		return true
	if AccountApi != null and AccountApi.has_method("is_gm") and AccountApi.is_gm():
		return true
	var dt := Time.get_date_dict_from_system()
	var w: int = int(dt.get("weekday", 0))
	return w == Time.WEEKDAY_SUNDAY or w == Time.WEEKDAY_SATURDAY

func _render() -> void:
	for c in _content_box.get_children():
		c.queue_free()

	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var runs_today: int = int(rec.get("runs", {}).get(today, 0))

	# Header info
	var header := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(header)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	header.add_child(hb)

	hb.add_child(SocialUi.label("Hành Trình Vận Tiêu Cá Nhân (Thứ 7 & Chủ Nhật · 3 lượt/ngày)", SocialUi.TITLE, 17))
	var desc := SocialUi.label("Hộ tống tiêu xa cá nhân qua đại đô thành Biện Kinh. Tiêu xa tự hành trình ngầm kể cả khi bạn rảnh tay hoặc thoát game. Có thể trực tiếp vào Hộ Tiêu hoặc Cướp Tiêu trên bảng tiêu xa giang hồ!", SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(desc)

	_status_lbl = SocialUi.label("Lượt xuất tiêu cá nhân hôm nay: %d / %d" % [runs_today, RUNS_PER_DAY], SocialUi.GOLD, 14)
	hb.add_child(_status_lbl)

	var active_cart: Dictionary = rec.get("active_cart", {})
	if not active_cart.is_empty():
		_render_active_cart(active_cart)
	elif not is_escort_day():
		var day_card := GameUi.panel(GameUi.SECTION)
		_content_box.add_child(day_card)
		var db := VBoxContainer.new()
		db.alignment = BoxContainer.ALIGNMENT_CENTER
		db.add_theme_constant_override("separation", 8)
		day_card.add_child(db)
		db.add_child(SocialUi.label("📅 HOẠT ĐỘNG VẬN TIÊU CHỈ MỞ VÀO THỨ 7 & CHỦ NHẬT HÀNG TUẦN", SocialUi.WARN, 15, HORIZONTAL_ALIGNMENT_CENTER))
		db.add_child(SocialUi.label("Hôm nay chưa đến ngày xuất tiêu. Xin đại hiệp vui lòng quay lại vào Thứ Bảy hoặc Chủ Nhật (Tối đa 3 lượt/ngày).", SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		_render_cart_selection(runs_today)

	_render_active_carts_board()

func _render_active_cart(cart: Dictionary) -> void:
	var cid: String = str(cart.get("cart_id", cart.get("id", "wood")))
	var cfg := {}
	for c in CARTS:
		if c.id == cid:
			cfg = c.duplicate()
			break

	if cfg.is_empty():
		cfg = {
			"id": cid,
			"name": str(cart.get("cart_name", "📦 Tiêu Xa")),
			"route": str(cart.get("route", "Tây Môn ➔ Đông Môn (Biện Kinh)")),
			"map_id": 37,
			"map_name": "Biện Kinh Đô Thành",
			"duration_sec": int(cart.get("duration_sec", 600)),
			"reward_gold": int(cart.get("reward_gold", 120000)),
			"reward_exp": int(cart.get("reward_exp", 150000)),
			"reward_contrib": int(cart.get("reward_contrib", 50)),
			"color": Color.WHITE
		}
	else:
		if cart.has("reward_gold") and int(cart["reward_gold"]) > 0:
			cfg["reward_gold"] = int(cart["reward_gold"])
		if cart.has("reward_exp") and int(cart["reward_exp"]) > 0:
			cfg["reward_exp"] = int(cart["reward_exp"])
		if cart.has("reward_contrib") and int(cart["reward_contrib"]) > 0:
			cfg["reward_contrib"] = int(cart["reward_contrib"])
		if cart.has("route") and str(cart["route"]) != "":
			cfg["route"] = str(cart["route"])

	var start_unix: int = int(cart.get("start_unix", 0))
	var duration: int = int(cfg.get("duration_sec", 600))
	var now_unix: int = int(Time.get_unix_time_from_system())
	var elapsed: int = maxi(0, now_unix - start_unix)
	var remaining: int = maxi(0, duration - elapsed)
	var is_completed: bool = (remaining <= 0)

	var card := GameUi.panel(GameUi.SECTION)
	_content_box.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var head_row := HBoxContainer.new()
	box.add_child(head_row)
	head_row.add_child(SocialUi.label(str(cfg.get("name", "")), cfg.get("color", Color.WHITE), 16))

	var status_tag := SocialUi.label("🟢 ĐÃ CẬP BẾN" if is_completed else "🚚 ĐANG LĂN BÁNH...", Color(0.25, 0.95, 0.45) if is_completed else Color(0.4, 0.85, 1.0), 14)
	status_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head_row.add_child(status_tag)

	box.add_child(SocialUi.kv("📍 Tuyến đường:", str(cfg.get("route", "")), SocialUi.LABEL_BLUE, SocialUi.TEXT, 14))

	# Progress bar
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = float(maxi(duration, 1))
	progress.value = float(elapsed)
	progress.show_percentage = false
	progress.custom_minimum_size.y = 16
	box.add_child(progress)

	var time_str := "Đã đến đích an toàn!" if is_completed else "Thời gian còn lại: %02d phút %02d giây" % [remaining / 60, remaining % 60]
	box.add_child(SocialUi.kv("⏱ Tiến trình:", time_str, SocialUi.LABEL_BLUE, SocialUi.GOLD, 14))

	var rew_row := HBoxContainer.new()
	rew_row.add_theme_constant_override("separation", 16)
	box.add_child(rew_row)
	rew_row.add_child(SocialUi.label("🎁 Nhận lại: %s Lượng" % InventoryPopup.format_money(int(cfg.get("reward_gold", 0))), SocialUi.GOLD, 14))
	rew_row.add_child(SocialUi.label("+%s EXP" % InventoryPopup.format_money(int(cfg.get("reward_exp", 0))), SocialUi.LABEL_GREEN, 14))
	rew_row.add_child(SocialUi.label("+%d Cống Hiến Bang" % int(cfg.get("reward_contrib", 0)), SocialUi.LABEL_BLUE, 14))

	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 16)
	box.add_child(act_row)

	if is_completed:
		var claim_btn := SocialUi.stone_button("🎉 Thu Hoạch Bảo Tiêu (Hoàn Thành)", Vector2(280, 44))
		claim_btn.pressed.connect(_claim_cart.bind(cfg))
		act_row.add_child(claim_btn)
	else:
		var enter_btn := SocialUi.stone_button("🛡️ Vào Map Bảo Vệ Tiêu", Vector2(210, 44))
		enter_btn.pressed.connect(func() -> void:
			var cart_uid := str(cart.get("id", ""))
			var m_cart: Dictionary = EscortManagerScript.get_cart(cart_uid)
			if m_cart.is_empty() or str(m_cart.get("status", "")) != "traveling":
				SocialWindow.info(self, "Thông Báo", "Tiêu xa này đã cập bến an toàn!")
				_claim_cart(cfg)
				return
			_enter_escort_field(m_cart)
		)
		act_row.add_child(enter_btn)

		var speedup_btn := SocialUi.stone_button("⚡ Tăng Tốc (10 KNB)", Vector2(180, 44))
		speedup_btn.pressed.connect(_speedup_cart)
		act_row.add_child(speedup_btn)

func _render_cart_selection(runs_today: int) -> void:
	if runs_today >= RUNS_PER_DAY:
		var card := GameUi.panel(GameUi.SECTION)
		_content_box.add_child(card)
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 8)
		card.add_child(vb)
		vb.add_child(SocialUi.label("Đại hiệp đã hoàn thành hết %d lượt vận tiêu hôm nay!" % RUNS_PER_DAY, SocialUi.TITLE, 16, HORIZONTAL_ALIGNMENT_CENTER))
		vb.add_child(SocialUi.label("Xin vui lòng quay lại vào ngày mai để tiếp tục nhận ủy thác tiêu xa.", SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER))
		return

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_content_box.add_child(list)

	for cart in CARTS:
		var card := GameUi.panel(GameUi.PANEL)
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)

		info.add_child(SocialUi.label(str(cart["name"]), cart["color"], 16))
		info.add_child(SocialUi.label("Lộ trình: %s  ·  Thời gian: %d phút" % [cart["route"], int(cart["duration_sec"]) / 60], SocialUi.MUTED, 13))

		var dep_str := "%s Lượng" % InventoryPopup.format_money(int(cart["deposit_gold"]))
		if int(cart["deposit_jade"]) > 0:
			dep_str += " + %d KNB" % int(cart["deposit_jade"])
		info.add_child(SocialUi.label("Tiền cọc: %s  ➔  Thưởng: %s Lượng, +%s EXP, +%d Cống hiến" % [
			dep_str,
			InventoryPopup.format_money(int(cart["reward_gold"])),
			InventoryPopup.format_money(int(cart["reward_exp"])),
			int(cart["reward_contrib"])
		], Color(0.8, 0.95, 0.8), 13))

		var dispatch_btn := SocialUi.stone_button("Xuất Tiêu", Vector2(130, 42))
		dispatch_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dispatch_btn.pressed.connect(_dispatch_cart.bind(cart))
		row.add_child(dispatch_btn)

func _dispatch_cart(cart: Dictionary) -> void:
	if _profile == null:
		return
	var dep_gold: int = int(cart.get("deposit_gold", 0))
	var dep_jade: int = int(cart.get("deposit_jade", 0))

	if _profile.gold < dep_gold:
		SocialWindow.info(self, "Không Đủ Lượng", "Cần %s lượng tiền cọc để xuất tiêu xa này." % InventoryPopup.format_money(dep_gold))
		return
	if dep_jade > 0 and _profile.jade < dep_jade:
		SocialWindow.info(self, "Không Đủ KNB", "Cần %d KNB tiền cọc bảo hiểm để xuất tiêu xa này." % dep_jade)
		return

	SocialWindow.confirm(self, "Xuất Tiêu Xa",
			"Xuất hành %s?\nTiền cọc: %s lượng%s.\nSau khi cập bến sẽ nhận lại cọc và %s lượng lãi!" % [
				cart["name"],
				InventoryPopup.format_money(dep_gold),
				(" + %d KNB" % dep_jade) if dep_jade > 0 else "",
				InventoryPopup.format_money(int(cart["reward_gold"]))
			],
			func() -> void:
				_execute_dispatch_cart(cart, dep_gold, dep_jade)
	)

func _execute_dispatch_cart(cart: Dictionary, dep_gold: int, dep_jade: int) -> void:
	_profile.gold -= dep_gold
	if dep_jade > 0:
		_profile.jade -= dep_jade

	var created_cart: Dictionary = EscortManagerScript.create_cart(_profile, cart)

	var rec := _get_records()
	rec["active_cart"] = {
		"id": str(created_cart["id"]),
		"cart_id": str(cart["id"]),
		"cart_name": str(cart["name"]),
		"route": str(cart["route"]),
		"map_id": int(cart.get("map_id", 37)),
		"map_name": str(cart.get("map_name", "Biện Kinh Đô Thành")),
		"start_unix": int(created_cart["start_unix"]),
		"duration_sec": int(cart.get("duration_sec", 600)),
		"reward_gold": int(cart.get("reward_gold", 0)),
		"reward_exp": int(cart.get("reward_exp", 0)),
		"reward_contrib": int(cart.get("reward_contrib", 0)),
	}
	_save_records(rec)
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	var map_title := str(cart.get("map_name", "Bản Đồ"))
	SocialWindow.ask_yes_no(self, "Xuất Tiêu Thành Công",
		"Tiêu xa đã xuất hành đến %s và đưa vào danh sách giang hồ!\nĐại hiệp muốn vào map thực địa để hộ tống ngay không?" % map_title,
		func(yes: bool) -> void:
			if yes:
				_enter_escort_field(created_cart)
			else:
				_render(),
		"Vào Map Ngay",
		"Để Xe Tự Chạy"
	)

func _speedup_cart() -> void:
	if _profile == null:
		return
	if _profile.jade < 10:
		SocialWindow.info(self, "Không Đủ KNB", "Cần 10 KNB để tăng tốc hoàn thành chuyến tiêu ngay lập tức.")
		return
	SocialWindow.confirm(self, "Tăng Tốc Vận Tiêu",
			"Dùng 10 KNB để tiêu xa hoàn thành hành trình ngay lập tức?",
			func() -> void:
				_profile.jade -= 10
				var rec := _get_records()
				if rec.has("active_cart"):
					rec["active_cart"]["start_unix"] = 0   ## Làm cho xe đến đích ngay lập tức
					_save_records(rec)
				SaveManager.save_profile(_profile)
				SaveManager.flush_online()
				_render()
	)

func _claim_cart(cfg: Dictionary) -> void:
	if _profile == null:
		return
	var rew_gold: int = int(cfg.get("reward_gold", 120000))
	var rew_exp: int = int(cfg.get("reward_exp", 150000))
	var rew_contrib: int = int(cfg.get("reward_contrib", 50))

	_profile.gold += rew_gold
	_profile.add_exp(rew_exp)
	if _profile.guild is Dictionary and not _profile.guild.is_empty():
		var cur_contrib: int = int(_profile.guild.get("contribution", 0))
		_profile.guild["contribution"] = cur_contrib + rew_contrib

	var rec := _get_records()
	var cart_id := str(rec.get("active_cart", {}).get("id", ""))
	if cart_id != "":
		EscortManagerScript.finish_cart(cart_id)

	var today := Time.get_date_string_from_system()
	var runs_today: int = int(rec.get("runs", {}).get(today, 0)) + 1
	var runs_dict: Dictionary = rec.get("runs", {})
	runs_dict[today] = runs_today
	rec["runs"] = runs_dict
	rec.erase("active_cart")
	_save_records(rec)

	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	SocialWindow.info(self, "Vận Tiêu Hoàn Tất",
			"Tiêu xa đã cập bến an toàn và được xóa khỏi danh sách giang hồ!\nĐại hiệp nhận được:\n+ %s Lượng (đã gồm gốc cọc)\n+ %s Điểm Kinh Nghiệm\n+ %d Cống Hiến Bang Hội" % [
				InventoryPopup.format_money(rew_gold),
				InventoryPopup.format_money(rew_exp),
				rew_contrib
			])
	_render()

## Hiển thị Bảng Tiêu Xa Giang Hồ theo danh sách phòng PK (Chọn Phe Hộ Tiêu / Cướp Tiêu · 5v5 Cân Bằng)
func _render_active_carts_board() -> void:
	var sec := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(sec)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	sec.add_child(vb)

	# Tiêu đề bảng phong cách Đấu trường PK
	var head_box := HBoxContainer.new()
	vb.add_child(head_box)

	var title_lbl := SocialUi.label("📜 BẢNG TIÊU XA GIANG HỒ (CHỌN PHE HỘ TIÊU / CƯỚP TIÊU)", SocialUi.TITLE, 15)
	head_box.add_child(title_lbl)

	var sep_head := Control.new()
	sep_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_box.add_child(sep_head)

	var refresh_tag := SocialUi.label("🔄 Cập nhật 10s/lần", SocialUi.MUTED, 12)
	head_box.add_child(refresh_tag)

	var rule_note := SocialUi.label("• Hai phe phải cân bằng nhau (chênh lệch tối đa 1 người). Tối đa 5 người mỗi bên.\n• Hộ tiêu: xuất hiện tại xe tiêu. Cướp tiêu: xuất hiện ở tọa độ kết thúc để chặn đầu.", SocialUi.MUTED, 12)
	rule_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(rule_note)

	var all_carts: Array[Dictionary] = EscortManagerScript.get_active_carts()
	if all_carts.is_empty():
		vb.add_child(SocialUi.label("Hiện tại chưa có tiêu xa nào đang xuất hành trên giang hồ.", SocialUi.MUTED, 13))
		return

	var my_name := _profile.display_name if _profile else ""
	for c in all_carts:
		var item_card := GameUi.panel(GameUi.SECTION)
		vb.add_child(item_card)
		var card_vb := VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 8)
		item_card.add_child(card_vb)

		var c_uid := str(c.get("id", ""))
		var c_owner := str(c.get("owner_name", "Ẩn Danh"))
		var c_name := str(c.get("cart_name", "📦 Tiêu Xa"))
		var c_hp: int = int(c.get("hp", 60000))
		var c_max_hp: int = int(c.get("max_hp", 60000))
		var defs: Array = c.get("defenders", [])
		var raiders: Array = c.get("raiders", [])

		var is_mine := (c_owner == my_name)
		var owner_tag := " [Tiêu Xa Của Bạn]" if is_mine else ""

		# 1. Thông tin Tiêu Xa & Sinh lực
		var top_row := HBoxContainer.new()
		card_vb.add_child(top_row)

		top_row.add_child(SocialUi.label("%s — Chủ xe: %s%s" % [c_name, c_owner, owner_tag], SocialUi.GOLD if is_mine else SocialUi.TITLE, 14))
		var top_sep := Control.new()
		top_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(top_sep)
		top_row.add_child(SocialUi.label("❤️ Máu xe: %s / %s" % [InventoryPopup.format_money(c_hp), InventoryPopup.format_money(c_max_hp)], SocialUi.WARN, 12))

		# 2. Hai cột hiển thị danh sách thành viên 2 phe (PK style)
		var teams_box := HBoxContainer.new()
		teams_box.add_theme_constant_override("separation", 12)
		card_vb.add_child(teams_box)

		# Cột Hộ Tiêu (Xanh / Vàng)
		var def_box := PanelContainer.new()
		def_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var def_st := StyleBoxFlat.new()
		def_st.bg_color = Color(0.08, 0.12, 0.18, 0.85)
		def_st.border_color = Color(0.3, 0.7, 1.0, 0.7)
		def_st.set_border_width_all(1)
		def_st.set_corner_radius_all(4)
		def_box.add_theme_stylebox_override("panel", def_st)
		teams_box.add_child(def_box)

		var def_inner := VBoxContainer.new()
		def_inner.add_theme_constant_override("separation", 4)
		def_box.add_child(def_inner)
		def_inner.add_child(SocialUi.label("🛡️ Phe Hộ Tiêu (%d/5)" % defs.size(), Color(0.4, 0.85, 1.0), 13))
		var def_list_txt := ", ".join(defs) if not defs.is_empty() else "Chưa có hộ tiêu"
		var def_lbl := SocialUi.label(def_list_txt, SocialUi.TEXT, 11)
		def_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		def_inner.add_child(def_lbl)

		# Cột Cướp Tiêu (Đỏ)
		var raid_box := PanelContainer.new()
		raid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var raid_st := StyleBoxFlat.new()
		raid_st.bg_color = Color(0.18, 0.08, 0.08, 0.85)
		raid_st.border_color = Color(1.0, 0.35, 0.35, 0.7)
		raid_st.set_border_width_all(1)
		raid_st.set_corner_radius_all(4)
		raid_box.add_theme_stylebox_override("panel", raid_st)
		teams_box.add_child(raid_box)

		var raid_inner := VBoxContainer.new()
		raid_inner.add_theme_constant_override("separation", 4)
		raid_box.add_child(raid_inner)
		raid_inner.add_child(SocialUi.label("⚔️ Phe Cướp Tiêu (%d/5)" % raiders.size(), Color(1.0, 0.45, 0.45), 13))
		var raid_list_txt := ", ".join(raiders) if not raiders.is_empty() else "Chưa có ai cướp tiêu"
		var raid_lbl := SocialUi.label(raid_list_txt, SocialUi.TEXT, 11)
		raid_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		raid_inner.add_child(raid_lbl)

		# 3. Hai nút bấm chọn phe (PK Lobby action)
		var act_row := HBoxContainer.new()
		act_row.alignment = BoxContainer.ALIGNMENT_CENTER
		act_row.add_theme_constant_override("separation", 16)
		card_vb.add_child(act_row)

		# Kiểm tra điều kiện gia nhập 2 phe
		var chk_def: Dictionary = EscortManagerScript.can_join_team(c, "defender", my_name)
		var chk_raid: Dictionary = EscortManagerScript.can_join_team(c, "raider", my_name)

		var def_btn := SocialUi.stone_button("🛡️ Vào Hộ Tiêu (%d/5)" % defs.size(), Vector2(200, 38))
		if not chk_def.get("ok", false):
			def_btn.disabled = true
			def_btn.tooltip_text = str(chk_def.get("reason", "Không thể tham gia"))
		def_btn.pressed.connect(func() -> void:
			_on_join_team_pressed(c_uid, "defender")
		)
		act_row.add_child(def_btn)

		var raid_btn := SocialUi.stone_button("⚔️ Vào Cướp Tiêu (%d/5)" % raiders.size(), Vector2(200, 38))
		if not chk_raid.get("ok", false):
			raid_btn.disabled = true
			raid_btn.tooltip_text = str(chk_raid.get("reason", "Không thể tham gia"))
		raid_btn.pressed.connect(func() -> void:
			_on_join_team_pressed(c_uid, "raider")
		)
		act_row.add_child(raid_btn)

func _on_join_team_pressed(cart_target_id: String, role: String) -> void:
	var my_name := _profile.display_name if _profile else ""
	var live_c := EscortManagerScript.get_cart(cart_target_id)
	if live_c.is_empty() or str(live_c.get("status", "")) != "traveling":
		SocialWindow.info(self, "Hành Trình Kết Thúc", "Tiêu xa này đã hoàn tất hành trình hoặc không còn hoạt động!")
		_render()
		return

	var res := EscortManagerScript.join_cart_team(cart_target_id, my_name, role)
	if not res.get("ok", false):
		SocialWindow.info(self, "Không Thể Vào", str(res.get("reason", "2 phe chưa cân bằng")))
		_render()
		return

	live_c = EscortManagerScript.get_cart(cart_target_id)
	_enter_escort_field(live_c, role)

func _enter_escort_field(cart_dict: Dictionary, role: String = "defender") -> void:
	var entry: Dictionary = EscortChallengeScript.map_entry(cart_dict, role)
	if _on_enter_field.is_valid():
		queue_free()
		_on_enter_field.call(entry)
	else:
		queue_free()
		GameManager.game_mode = GameManager.GameMode.MAIN_MAP
		GameManager.field_map = entry
		get_tree().change_scene_to_file("res://Main.tscn")
		get_tree().change_scene_to_file("res://Main.tscn")

func _on_tick() -> void:
	if is_inside_tree():
		var rec := _get_records()
		if rec.has("active_cart"):
			_render()

# ---------------------------------------------------------------- LƯU TRỮ

static func get_record_key(profile: PlayerProfile = null) -> String:
	var p := profile if profile != null else GameManager.local_profile
	var acc_id := ""
	if AccountApi != null and AccountApi.is_logged_in():
		acc_id = str(AccountApi.account.get("id", ""))
		if acc_id.is_empty():
			acc_id = str(AccountApi.account.get("username", ""))
	var char_name := p.display_name if p != null else ""
	var key := ""
	if not acc_id.is_empty() and not char_name.is_empty():
		key = "%s_%s" % [acc_id, char_name]
	elif not acc_id.is_empty():
		key = acc_id
	elif not char_name.is_empty():
		key = char_name
	else:
		key = "default"

	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		key = key.replace(ch, "_")
	return key

static func get_runs_today(profile: PlayerProfile = null) -> int:
	var rec := _get_records_for(profile)
	var today := Time.get_date_string_from_system()
	return int(rec.get("runs", {}).get(today, 0))

static func get_record_path(profile: PlayerProfile = null) -> String:
	return "user://escort_records_%s.json" % get_record_key(profile)

func _get_records() -> Dictionary:
	return _get_records_for(_profile)

func _save_records(rec: Dictionary) -> void:
	_save_records_for(rec, _profile)

static func _get_records_for(profile: PlayerProfile = null) -> Dictionary:
	var path := get_record_path(profile)
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

static func _save_records_for(rec: Dictionary, profile: PlayerProfile = null) -> void:
	var path := get_record_path(profile)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rec, " "))
