extends SocialWindow
class_name HuyHoangWindow
## Quả Huy Hoàng & Hạt Huy Hoàng (Sự kiện kinh điển VLTK — Phong cách IDLE & Flappy Fruit):
##   - Theo chuẩn gốc VLTK: Mỗi ngày tối đa ăn 5 quả Huy hoàng.
##   - Phân cấp quả theo cấp độ nhân vật (Sơ cấp < 90, Trung cấp 90-119, Cao cấp >= 120, Hoàng kim >= 130).
##   - Tích hợp UI icon nguyên bản VLTK cho từng phẩm cấp quả.
##   - Màn chơi "Flappy Fruit" bay vượt qua các hàng cây cổ thụ với hệ số điểm x1, x2, x3, x5.
##   - Hỗ trợ cả 3 chế độ: Hái quả minigame, Hái nhanh 1 quả, hoặc Càn quét tất cả 5 quả!

const RECORD_PATH := "user://huy_hoang_records.json"
const MAX_FRUITS_PER_DAY := 5

const FlappyScript = preload("res://ui/events/huy_hoang_flappy_window.gd")

const TIERS := [
	{
		"id": "low",
		"name": "Quả Huy Hoàng (Sơ Cấp)",
		"icon": "res://assets/items/icons/huihuangzhiguo.png",
		"multiplier": 1,
		"min_level": 40,
		"max_level": 89,
		"reward_exp": 500000,
		"reward_fuyuan": 10,
		"reward_gold": 20000,
		"color": Color(0.4, 0.85, 1.0),
		"desc": "Dành cho hiệp khách cấp 40 - 89. Hấp thu linh khí khai mở kinh mạch sơ cấp."
	},
	{
		"id": "mid",
		"name": "Bách Niên Huy Hoàng Quả (Trung Cấp)",
		"icon": "res://assets/items/icons/huihuangzhiguo_avd1.png",
		"multiplier": 2,
		"min_level": 90,
		"max_level": 119,
		"reward_exp": 2000000,
		"reward_fuyuan": 30,
		"reward_gold": 60000,
		"color": Color(0.9, 0.65, 1.0),
		"desc": "Dành cho cao thủ cấp 90 - 119. Củng cố nội lực chân nguyên, thăng tiến thần tốc."
	},
	{
		"id": "high",
		"name": "Thiên Niên Huy Hoàng Quả (Cao Cấp)",
		"icon": "res://assets/items/icons/huihuangzhiguo_avd2.png",
		"multiplier": 3,
		"min_level": 120,
		"max_level": 129,
		"reward_exp": 5000000,
		"reward_fuyuan": 60,
		"reward_gold": 150000,
		"color": Color(1.0, 0.85, 0.25),
		"desc": "Dành cho tôn sư cấp 120 trở lên. Quả hấp thu linh khí dồi dào, tăng lượng lớn kinh nghiệm."
	},
	{
		"id": "gold",
		"name": "Vạn Niên Hoàng Kim Quả (Chí Bảo)",
		"icon": "res://assets/items/icons/huihuangzhiguo_avd3.png",
		"multiplier": 5,
		"min_level": 130,
		"max_level": 999,
		"reward_exp": 10000000,
		"reward_fuyuan": 120,
		"reward_gold": 300000,
		"color": Color(1.0, 0.5, 0.2),
		"desc": "Đại quả ngàn năm xuất thế tại đỉnh Huy Hoàng. Cấp 130+, nhận 10.000.000 EXP và phúc duyên cực cao."
	}
]

var _profile: PlayerProfile
var _content_box: VBoxContainer
var _status_lbl: Label

static func get_record_path(profile: PlayerProfile) -> String:
	if profile != null:
		var acc := ""
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root and tree.root.has_node("AccountApi"):
			var api = tree.root.get_node("AccountApi")
			if api.has_method("is_logged_in") and api.is_logged_in():
				acc = _sanitize_name(str(api.account.get("id", "")))
		var char_name := _sanitize_name(profile.display_name)
		if not acc.is_empty() and not char_name.is_empty():
			return "user://huy_hoang_records_%s_%s.json" % [acc, char_name]
		elif not char_name.is_empty():
			return "user://huy_hoang_records_%s.json" % char_name
	return RECORD_PATH

static func _sanitize_name(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s[i]
		if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_':
			out += c
		else:
			out += "_"
	return out

static func open(host: Node, profile: PlayerProfile) -> SocialWindow:
	var script: GDScript = load("res://ui/events/huy_hoang_window.gd")
	var win: SocialWindow = script.new(profile)
	return SocialWindow.present(host, win, &"huy_hoang")

func _init(profile: PlayerProfile = null) -> void:
	super._init("Quả Huy Hoàng & Hạt Huy Hoàng", "Hái quả hoàng kim — Hấp thu linh khí bồi tăng công lực", 680.0)
	_profile = profile

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 8)
	body.add_child(_content_box)

	_render()

func _get_suitable_tier() -> Dictionary:
	var lv := _profile.level if _profile else 1
	for t in TIERS:
		if lv >= int(t["min_level"]) and lv <= int(t["max_level"]):
			return t
	return TIERS[0]

func _render() -> void:
	for c in _content_box.get_children():
		c.queue_free()

	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var eaten_today: int = int(rec.get("eaten", {}).get(today, 0))
	var remaining_today: int = maxi(0, MAX_FRUITS_PER_DAY - eaten_today)

	var head_card := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head_card)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	head_card.add_child(hb)

	hb.add_child(SocialUi.label("Huy Hoàng Đỉnh — Hái Quả Linh Thụ", SocialUi.TITLE, 16))
	var desc := SocialUi.label("Mỗi ngày mỗi hiệp khách được hái tối đa %d Quả Huy Hoàng. Bạn có thể tự mình bay lượn vượt các hàng cổ thụ (Flappy Fruit) để bồi tăng phần thưởng theo hệ số x1, x2, x3, x5, hoặc chọn Hái nhanh rảnh tay!" % MAX_FRUITS_PER_DAY, SocialUi.MUTED, 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(desc)

	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 20)
	hb.add_child(st_row)

	_status_lbl = SocialUi.label("Đã ăn hôm nay: %d / %d quả" % [eaten_today, MAX_FRUITS_PER_DAY], SocialUi.GOLD, 13)
	st_row.add_child(_status_lbl)

	var t_cur := _get_suitable_tier()
	st_row.add_child(SocialUi.label("Phẩm cấp hiện tại: %s" % str(t_cur["name"]), t_cur["color"], 13))

	# Danh sách quả theo cấp — bọc ScrollContainer để không tràn màn hình
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for tier in TIERS:
		var is_active: bool = (str(tier.get("id", "")) == str(t_cur.get("id", "")))
		var card := GameUi.panel(GameUi.SECTION if is_active else GameUi.PANEL)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(card)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		# Icon quả nguyên bản VLTK trong ô viền phát sáng
		var icon_slot := PanelContainer.new()
		icon_slot.custom_minimum_size = Vector2(50, 50)
		var st_slot := StyleBoxFlat.new()
		st_slot.bg_color = Color(0.06, 0.08, 0.12, 0.92)
		st_slot.border_color = tier.get("color", Color.GOLD)
		st_slot.set_border_width_all(2)
		st_slot.set_corner_radius_all(6)
		icon_slot.add_theme_stylebox_override("panel", st_slot)
		row.add_child(icon_slot)

		var icon_tex := TextureRect.new()
		var p_icon := str(tier.get("icon", ""))
		if ResourceLoader.exists(p_icon):
			icon_tex.texture = load(p_icon)
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.custom_minimum_size = Vector2(36, 36)
		icon_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_slot.add_child(icon_tex)

		# Cột thông tin chi tiết
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		info.add_child(name_row)

		name_row.add_child(SocialUi.label(str(tier["name"]), tier["color"], 14))
		name_row.add_child(SocialUi.label("[Điểm Cổ Thụ: x%d]" % int(tier.get("multiplier", 1)), SocialUi.GOLD, 11))

		if is_active:
			name_row.add_child(SocialUi.label("✦ Phù hợp cấp độ", Color(0.25, 0.95, 0.45), 11))

		var req_lbl := SocialUi.label("Yêu cầu: Cấp %d trở lên  ·  %s" % [int(tier["min_level"]), str(tier["desc"])], SocialUi.MUTED, 11)
		req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(req_lbl)

		var rew_lbl := SocialUi.label("Cơ bản: +%s EXP  ·  +%d Phúc Duyên  ·  +%s Lượng" % [
			InventoryPopup.format_money(int(tier["reward_exp"])),
			int(tier["reward_fuyuan"]),
			InventoryPopup.format_money(int(tier["reward_gold"]))
		], Color(0.8, 0.95, 0.8), 12)
		info.add_child(rew_lbl)

		# Cụm nút hành động
		var btn_box := HBoxContainer.new()
		btn_box.add_theme_constant_override("separation", 6)
		btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(btn_box)

		# Nút chơi Flappy Fruit minigame
		var flappy_btn := SocialUi.stone_button("🎮 Bay Vượt Cây", Vector2(125, 36))
		flappy_btn.tooltip_text = "Bay lượn né chướng ngại vật để nhân gấp x%d phần thưởng!" % int(tier.get("multiplier", 1))
		flappy_btn.disabled = not is_active or remaining_today <= 0
		flappy_btn.pressed.connect(_play_flappy_harvest.bind(tier))
		btn_box.add_child(flappy_btn)

		# Nút hái nhanh trực tiếp 1 quả
		var quick_btn := SocialUi.stone_button("⚡ Hái Nhanh", Vector2(92, 36))
		quick_btn.tooltip_text = "Hái nhanh lập tức 1 quả này nhận phần thưởng chuẩn"
		quick_btn.disabled = not is_active or remaining_today <= 0
		quick_btn.pressed.connect(_eat_fruit.bind(tier, 1))
		btn_box.add_child(quick_btn)

	# Nút Càn quét toàn bộ
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	_content_box.add_child(bottom_row)

	var sweep_all_btn := SocialUi.stone_button("⚡ Hái Nhanh Toàn Bộ (%d quả còn lại)" % remaining_today, Vector2(260, 38))
	sweep_all_btn.disabled = remaining_today <= 0
	sweep_all_btn.pressed.connect(_eat_fruit.bind(t_cur, remaining_today))
	bottom_row.add_child(sweep_all_btn)

func _play_flappy_harvest(tier: Dictionary) -> void:
	if _profile == null:
		return
	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var eaten_today: int = int(rec.get("eaten", {}).get(today, 0))
	if eaten_today >= MAX_FRUITS_PER_DAY:
		SocialWindow.info(self, "Hết Lượt", "Hôm nay đại hiệp đã ăn đủ %d Quả Huy Hoàng rồi. Ngày mai hãy tiếp tục!" % MAX_FRUITS_PER_DAY)
		return

	FlappyScript.launch(self, _profile, tier, func(score: int, total_exp: int, total_gold: int, total_fuyuan: int) -> void:
		# Nếu 0% hoàn thành (0 EXP, 0 Vàng, 0 Phúc Duyên), giữ nguyên lượt ăn quả để người chơi có thể chơi lại
		if total_exp <= 0 and total_gold <= 0 and total_fuyuan <= 0:
			return

		_profile.add_exp(total_exp)
		_profile.gold += total_gold
		_profile.fuyuan += total_fuyuan

		var r := _get_records()
		var eaten_d: Dictionary = r.get("eaten", {})
		eaten_d[today] = int(eaten_d.get(today, 0)) + 1
		r["eaten"] = eaten_d
		_save_records(r)

		SaveManager.save_profile(_profile)
		SaveManager.flush_online()
		_render()
	)

func _eat_fruit(tier: Dictionary, count: int) -> void:
	if _profile == null or count <= 0:
		return

	var rec := _get_records()
	var today := Time.get_date_string_from_system()
	var eaten_today: int = int(rec.get("eaten", {}).get(today, 0))
	var actual_count := mini(count, MAX_FRUITS_PER_DAY - eaten_today)
	if actual_count <= 0:
		SocialWindow.info(self, "Hết Lượt", "Hôm nay đại hiệp đã ăn đủ %d Quả Huy Hoàng rồi. Ngày mai hãy tiếp tục!" % MAX_FRUITS_PER_DAY)
		return

	var total_exp := int(tier.get("reward_exp", 0)) * actual_count
	var total_fuyuan := int(tier.get("reward_fuyuan", 0)) * actual_count
	var total_gold := int(tier.get("reward_gold", 0)) * actual_count

	_profile.add_exp(total_exp)
	_profile.fuyuan += total_fuyuan
	_profile.gold += total_gold

	var eaten_dict: Dictionary = rec.get("eaten", {})
	eaten_dict[today] = eaten_today + actual_count
	rec["eaten"] = eaten_dict
	_save_records(rec)

	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	SocialWindow.info(self, "Hái Quả Thành Công",
			"Đại hiệp đã thưởng thức %d %s!\nNhận được:\n+ %s Điểm Kinh Nghiệm\n+ %d Điểm Phúc Duyên\n+ %s Lượng" % [
				actual_count,
				str(tier["name"]),
				InventoryPopup.format_money(total_exp),
				total_fuyuan,
				InventoryPopup.format_money(total_gold)
			])
	_render()

# ---------------------------------------------------------------- LƯU TRỮ

func _get_records() -> Dictionary:
	var path := get_record_path(_profile)
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(RECORD_PATH):
			var old_txt := FileAccess.get_file_as_string(RECORD_PATH)
			var old_p: Variant = JSON.parse_string(old_txt)
			if old_p is Dictionary:
				_save_records(old_p)
				return old_p
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

func _save_records(rec: Dictionary) -> void:
	var path := get_record_path(_profile)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rec, " "))
