extends SocialWindow
class_name BatNhaWindow
## Vườn Bát Nhã (Trồng Cây Bát Nhã — Thuần IDLE):
##   - Sở hữu 3 ô đất linh thổ để gieo hạt giống Bát Nhã Ba La Mật.
##   - Cây tự lớn theo thời gian thực (15 - 60 phút), kể cả khi tắt game.
##   - Khi quả Bát Nhã chín, thu hoạch nhận lượng lớn EXP, Ngân Lượng, Huyền Tinh và Thủy Tinh!

const RECORD_PATH := "user://bat_nha_records.json"
const PLOT_COUNT := 3

const SEEDS := [
	{
		"id": "small",
		"name": "🌱 Hạt Tiểu Bát Nhã (Thường)",
		"duration_sec": 900,       ## 15 phút
		"cost_gold": 0,
		"cost_jade": 0,
		"reward_exp": 350000,
		"reward_gold": 40000,
		"reward_fuyuan": 15,
		"color": Color(0.4, 0.85, 1.0)
	},
	{
		"id": "big",
		"name": "🌳 Hạt Đại Bát Nhã (Cao Cấp)",
		"duration_sec": 1800,      ## 30 phút
		"cost_gold": 80000,
		"cost_jade": 0,
		"reward_exp": 900000,
		"reward_gold": 120000,
		"reward_fuyuan": 40,
		"color": Color(0.9, 0.65, 1.0)
	},
	{
		"id": "gold",
		"name": "👑 Thần Thụ Bát Nhã (Hoàng Kim)",
		"duration_sec": 3600,      ## 60 phút
		"cost_gold": 0,
		"cost_jade": 40,
		"reward_exp": 2500000,
		"reward_gold": 300000,
		"reward_fuyuan": 100,
		"color": Color(1.0, 0.85, 0.25)
	}
]

var _profile: PlayerProfile
var _scroll: ScrollContainer
var _content_box: VBoxContainer
var _timer: Timer

static func open(host: Node, profile: PlayerProfile) -> SocialWindow:
	var script: GDScript = load("res://ui/events/bat_nha_window.gd")
	var win: SocialWindow = script.new(profile)
	return SocialWindow.present(host, win, &"bat_nha")

func _init(profile: PlayerProfile = null) -> void:
	super._init("Vườn Bát Nhã (Trồng Cây)", "Gieo hạt tích đức — Cây lớn kết trái thụ hưởng linh dược", 680.0)
	_profile = profile

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
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	_render()

func _render() -> void:
	for c in _content_box.get_children():
		c.queue_free()

	var head_card := GameUi.panel(GameUi.PANEL)
	_content_box.add_child(head_card)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	head_card.add_child(hb)

	hb.add_child(SocialUi.label("Linh Thổ Bát Nhã — Gieo Hạt Nhận Phúc Duyên", SocialUi.TITLE, 17))
	var desc := SocialUi.label("Bạn có 3 ô đất màu mỡ. Hãy chọn hạt giống Bát Nhã để gieo trồng. Cây sẽ tự động sinh trưởng theo thời gian thực (ngay cả khi tắt máy rời game). Có thể tưới Nước Thần (5 KNB, -50% thời gian) hoặc Hoàn Thành Ngay (10 KNB). Khi quả chín, hãy bấm thu hoạch!", SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(desc)

	var rec := _get_records()
	var plots: Array = rec.get("plots", [{}, {}, {}])
	while plots.size() < PLOT_COUNT:
		plots.append({})

	var plots_box := VBoxContainer.new()
	plots_box.add_theme_constant_override("separation", 10)
	_content_box.add_child(plots_box)

	for i in PLOT_COUNT:
		var plot_data: Dictionary = plots[i]
		plots_box.add_child(_plot_card(i, plot_data))

func _plot_card(idx: int, data: Dictionary) -> Control:
	var card := GameUi.panel(GameUi.PANEL)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var top_row := HBoxContainer.new()
	vb.add_child(top_row)

	var p_title := SocialUi.label("🌱 Ô Đất Số %d" % (idx + 1), SocialUi.GOLD, 15)
	top_row.add_child(p_title)

	if data.is_empty():
		var empty_tag := SocialUi.label("(Đất Trống — Chưa gieo hạt)", SocialUi.MUTED, 13)
		empty_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(empty_tag)

		var plant_row := HBoxContainer.new()
		plant_row.add_theme_constant_override("separation", 10)
		vb.add_child(plant_row)

		for s in SEEDS:
			var btn := SocialUi.stone_button(str(s["name"]), Vector2(0, 38))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(_plant_seed.bind(idx, s))
			plant_row.add_child(btn)
	else:
		var sid: String = str(data.get("seed_id", "small"))
		var cfg := {}
		for s in SEEDS:
			if s.id == sid:
				cfg = s
				break

		var start_unix := int(data.get("start_unix", 0))
		var duration := int(cfg.get("duration_sec", 900))
		var now_unix := int(Time.get_unix_time_from_system())
		var elapsed := maxi(0, now_unix - start_unix)
		var remaining := maxi(0, duration - elapsed)
		var is_ready: bool = (remaining <= 0)

		var st_tag := SocialUi.label("🍈 ĐÃ KẾT TRÁI — SẴN SÀNG THU HOẠCH!" if is_ready else "🌿 ĐANG SINH TRƯỞNG...", Color(0.25, 0.95, 0.45) if is_ready else Color(0.4, 0.85, 1.0), 13)
		st_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_row.add_child(st_tag)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = float(duration)
		bar.value = float(elapsed)
		bar.show_percentage = false
		bar.custom_minimum_size.y = 12
		vb.add_child(bar)

		var info_row := HBoxContainer.new()
		vb.add_child(info_row)

		var time_str := "Cây đã chín vàng!" if is_ready else "Còn lại: %02d phút %02d giây" % [remaining / 60, remaining % 60]
		info_row.add_child(SocialUi.label("Loại cây: %s  ·  %s" % [cfg.get("name", ""), time_str], cfg.get("color", Color.WHITE), 13))

		var rew_lbl := SocialUi.label("Thưởng: +%s EXP, +%s Lượng, +%d Phúc Duyên" % [
			InventoryPopup.format_money(int(cfg.get("reward_exp", 0))),
			InventoryPopup.format_money(int(cfg.get("reward_gold", 0))),
			int(cfg.get("reward_fuyuan", 0))
		], Color(0.8, 0.95, 0.8), 13)
		rew_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rew_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		info_row.add_child(rew_lbl)

		var act_row := HBoxContainer.new()
		act_row.add_theme_constant_override("separation", 12)
		act_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(act_row)

		if is_ready:
			var harvest_btn := SocialUi.stone_button("🎉 Thu Hoạch Quả Bát Nhã", Vector2(230, 38))
			harvest_btn.pressed.connect(_harvest_plot.bind(idx, cfg))
			act_row.add_child(harvest_btn)
		else:
			var water_btn := SocialUi.stone_button("💧 Tưới Nước Thần (-50% giờ, 5 KNB)", Vector2(215, 36))
			water_btn.pressed.connect(_water_plot.bind(idx))
			act_row.add_child(water_btn)

			var speed_btn := SocialUi.stone_button("⚡ Hoàn Thành Ngay (10 KNB)", Vector2(190, 36))
			speed_btn.pressed.connect(_speedup_plot.bind(idx))
			act_row.add_child(speed_btn)

	return card

func _plant_seed(idx: int, seed_cfg: Dictionary) -> void:
	if _profile == null:
		return
	var cost_gold := int(seed_cfg.get("cost_gold", 0))
	var cost_jade := int(seed_cfg.get("cost_jade", 0))

	if cost_gold > 0 and _profile.gold < cost_gold:
		SocialWindow.info(self, "Không Đủ Lượng", "Cần %s lượng để mua hạt giống này." % InventoryPopup.format_money(cost_gold))
		return
	if cost_jade > 0 and _profile.jade < cost_jade:
		SocialWindow.info(self, "Không Đủ KNB", "Cần %d KNB để mua hạt giống này." % cost_jade)
		return

	if cost_gold > 0:
		_profile.gold -= cost_gold
	if cost_jade > 0:
		_profile.jade -= cost_jade

	var rec := _get_records()
	var plots: Array = rec.get("plots", [{}, {}, {}])
	while plots.size() <= idx:
		plots.append({})

	plots[idx] = {
		"seed_id": str(seed_cfg["id"]),
		"start_unix": int(Time.get_unix_time_from_system())
	}
	rec["plots"] = plots
	_save_records(rec)

	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	_render()

func _water_plot(idx: int) -> void:
	if _profile == null:
		return
	if _profile.jade < 5:
		SocialWindow.info(self, "Không Đủ KNB", "Cần 5 KNB để tưới Nước Thần (giảm 50% thời gian sinh trưởng).")
		return
	_profile.jade -= 5

	var rec := _get_records()
	var plots: Array = rec.get("plots", [{}, {}, {}])
	if idx < plots.size() and not plots[idx].is_empty():
		var p: Dictionary = plots[idx]
		var sid: String = str(p.get("seed_id", "small"))
		var duration := 900
		for s in SEEDS:
			if s.id == sid:
				duration = int(s.get("duration_sec", 900))
				break
		# Giảm 50% thời gian bằng cách trừ start_unix
		p["start_unix"] = int(p.get("start_unix", 0)) - int(duration * 0.5)
		_save_records(rec)

	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	_render()

func _speedup_plot(idx: int) -> void:
	if _profile == null:
		return
	if _profile.jade < 10:
		SocialWindow.info(self, "Không Đủ KNB", "Cần 10 KNB để chín cây lập tức.")
		return
	_profile.jade -= 10
	var rec := _get_records()
	var plots: Array = rec.get("plots", [{}, {}, {}])
	if idx < plots.size() and not plots[idx].is_empty():
		plots[idx]["start_unix"] = 0
		_save_records(rec)
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	_render()

func _harvest_plot(idx: int, cfg: Dictionary) -> void:
	if _profile == null:
		return
	var rew_exp := int(cfg.get("reward_exp", 0))
	var rew_gold := int(cfg.get("reward_gold", 0))
	var rew_fuyuan := int(cfg.get("reward_fuyuan", 0))

	_profile.add_exp(rew_exp)
	_profile.gold += rew_gold
	_profile.fuyuan += rew_fuyuan

	var rec := _get_records()
	var plots: Array = rec.get("plots", [{}, {}, {}])
	if idx < plots.size():
		plots[idx] = {}
	rec["plots"] = plots
	_save_records(rec)

	SaveManager.save_profile(_profile)
	SaveManager.flush_online()

	SocialWindow.info(self, "Thu Hoạch Thành Công",
			"Đại hiệp đã thu hoạch quả từ %s!\nNhận được:\n+ %s Điểm Kinh Nghiệm\n+ %s Lượng\n+ %d Điểm Phúc Duyên" % [
				str(cfg["name"]),
				InventoryPopup.format_money(rew_exp),
				InventoryPopup.format_money(rew_gold),
				rew_fuyuan
			])
	_render()

func _on_tick() -> void:
	if is_inside_tree():
		var rec := _get_records()
		var plots: Array = rec.get("plots", [])
		var has_growing := false
		for p in plots:
			if not p.is_empty():
				has_growing = true
				break
		if has_growing:
			_render()

# ---------------------------------------------------------------- LƯU TRỮ

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
			return "user://bat_nha_records_%s_%s.json" % [acc, char_name]
		elif not char_name.is_empty():
			return "user://bat_nha_records_%s.json" % char_name
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
