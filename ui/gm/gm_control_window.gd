extends SocialWindow
class_name GmControlWindow

const AuraDatabase = preload("res://systems/auras/aura_database.gd")

## TRUNG TÂM ĐIỀU HÀNH GAME MASTER (GM CONTROL CENTER)
## Giao diện trực quan tích hợp toàn diện các công cụ hỗ trợ GM quản lý thế giới, người chơi, boss, cấp phát vật phẩm.

enum Tab { PLAYER, SELF, DISPENSER, BOSS, POSSESS, AUDIT, AURA }
const TAB_NAMES := ["1. Người Chơi", "2. Bản Thân", "3. Cấp Đồ & Tiền", "4. Boss & Rớt Đồ", "5. Chiếm Quyền", "6. Nhật Ký GM", "7. Hào Quang Aura"]

var _current_tab: int = Tab.PLAYER
var _tab_bar: HBoxContainer
var _content_area: VBoxContainer
var _status_footer: HBoxContainer
var _selected_player: Dictionary = {}
var _dispenser_res_label: Label = null
var _aura_filter_category: String = "Tất Cả"
var _aura_search_keyword: String = ""

static func open(host: Node) -> SocialWindow:
	if not AccountApi.is_gm():
		return null
	var script: GDScript = load("res://ui/gm/gm_control_window.gd")
	var win = script.new()
	return SocialWindow.present(host, win, &"gm_control")

func _init() -> void:
	super._init("★ TRUNG TÂM ĐIỀU HÀNH GAME MASTER ★", "Bảng công cụ quản trị, giám sát và can thiệp máy chủ", 840.0)
	custom_minimum_size = Vector2(840, 580)

	## Khởi tạo danh mục tab
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	body.add_child(_tab_bar)

	for i in TAB_NAMES.size():
		var btn := GameUi.button(TAB_NAMES[i], GameUi.TAB)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void:
			_current_tab = i
			_render_tab())
		_tab_bar.add_child(btn)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	_content_area = VBoxContainer.new()
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.add_theme_constant_override("separation", 10)
	scroll.add_child(_content_area)

	## Footer thanh trạng thái nhanh
	_status_footer = HBoxContainer.new()
	_status_footer.add_theme_constant_override("separation", 12)
	body.add_child(_status_footer)

	var close_btn := SocialUi.stone_button("Đóng Bảng GM", Vector2(140, 36))
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	body.add_child(close_btn)

	GmManager.gm_state_changed.connect(_refresh_footer)
	GmManager.possession_changed.connect(func(_p: bool, _t: String) -> void: _refresh_footer())
	GmManager.profile_modified.connect(_on_gm_profile_modified)

func _on_gm_profile_modified(_p: PlayerProfile) -> void:
	_refresh_footer()
	if _current_tab == Tab.DISPENSER:
		_update_dispenser_summary()
	elif _current_tab == Tab.PLAYER:
		_render_tab()

func _ready() -> void:
	super._ready()
	_selected_player = _get_default_player()
	_refresh_footer()
	_render_tab()

func _get_default_player() -> Dictionary:
	var list := GmManager.get_player_list()
	return list[0] if not list.is_empty() else {}

func _selected_profile() -> PlayerProfile:
	if _selected_player.get("profile"):
		return _selected_player["profile"]
	return GameManager.local_profile

func _refresh_footer() -> void:
	for c in _status_footer.get_children():
		c.queue_free()

	var inv_lbl := SocialUi.label("Tàng hình: %s" % ("BẬT" if GmManager.is_invisible else "TẮT"),
		SocialUi.LABEL_GREEN if GmManager.is_invisible else SocialUi.MUTED, 12)
	var god_lbl := SocialUi.label("Bất tử: %s" % ("BẬT" if GmManager.is_god_mode else "TẮT"),
		SocialUi.LABEL_GREEN if GmManager.is_god_mode else SocialUi.MUTED, 12)
	var halo_lbl := SocialUi.label("Vòng sáng: %s" % ("BẬT" if GmManager.is_gm_halo else "TẮT"),
		SocialUi.LABEL_GREEN if GmManager.is_gm_halo else SocialUi.MUTED, 12)
	var spd_lbl := SocialUi.label("Tốc độ: %.1fx" % GmManager.speed_mult, SocialUi.LABEL_BLUE, 12)
	var boss_lbl := SocialUi.label("Máu Boss: %.1fx | Rớt đồ: %.1fx" % [GmManager.boss_hp_mult, GmManager.boss_drop_mult], SocialUi.TEXT, 12)

	_status_footer.add_child(inv_lbl)
	_status_footer.add_child(god_lbl)
	_status_footer.add_child(halo_lbl)
	_status_footer.add_child(spd_lbl)
	_status_footer.add_child(boss_lbl)

	if GmManager.is_possessing:
		var pos_lbl := SocialUi.label("★ ĐANG CHIẾM QUYỀN: %s" % GmManager.possessed_profile.display_name, SocialUi.LABEL_RED, 12)
		_status_footer.add_child(pos_lbl)

func _render_tab() -> void:
	for i in _tab_bar.get_child_count():
		var b := _tab_bar.get_child(i) as Button
		GameUi.set_active(b, i == _current_tab)

	for c in _content_area.get_children():
		c.queue_free()

	match _current_tab:
		Tab.PLAYER:
			_build_player_tab()
		Tab.SELF:
			_build_self_tab()
		Tab.DISPENSER:
			_build_dispenser_tab()
		Tab.BOSS:
			_build_boss_tab()
		Tab.POSSESS:
			_build_possess_tab()
		Tab.AUDIT:
			_build_audit_tab()
		Tab.AURA:
			_build_aura_tab()

# ==============================================================================
# TAB 1: QUẢN TRỊ NGƯỜI CHƠI
# ==============================================================================

func _build_player_tab() -> void:
	var info_sec := SocialUi.info_box("🔍 Tìm Kiếm & Lựa Chọn Mục Tiêu")
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)

	var search_input := SocialUi.line_edit("Nhập Tên nhân vật hoặc ID người chơi...")
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(search_input)

	var search_btn := SocialUi.small_button("Tìm Kiếm")
	var refresh_all_btn := SocialUi.small_button("Hiện Tất Cả")
	search_row.add_child(search_btn)
	search_row.add_child(refresh_all_btn)
	info_sec[1].add_child(search_row)

	var player_list_container := VBoxContainer.new()
	player_list_container.add_theme_constant_override("separation", 4)
	info_sec[1].add_child(player_list_container)
	_content_area.add_child(info_sec[0])

	var target_sec := SocialUi.info_box("🎯 Thao Tác Với Mục Tiêu Đang Chọn")
	var target_detail_label := SocialUi.label("Chưa chọn mục tiêu", SocialUi.TEXT, 13)
	target_sec[1].add_child(target_detail_label)

	var actions_grid := GridContainer.new()
	actions_grid.columns = 4
	actions_grid.add_theme_constant_override("h_separation", 8)
	actions_grid.add_theme_constant_override("v_separation", 8)
	target_sec[1].add_child(actions_grid)
	_content_area.add_child(target_sec[0])

	var mass_sec := SocialUi.info_box("🌍 Dịch Chuyển Hàng Loạt (Sự Kiện)")
	var mass_row := HBoxContainer.new()
	mass_row.add_theme_constant_override("separation", 8)
	var x_input := SocialUi.line_edit("X: 200")
	var y_input := SocialUi.line_edit("Y: 200")
	x_input.text = "200"
	y_input.text = "200"
	x_input.custom_minimum_size.x = 80
	y_input.custom_minimum_size.x = 80
	mass_row.add_child(SocialUi.label("Tọa độ đích:", SocialUi.TEXT, 13))
	mass_row.add_child(x_input)
	mass_row.add_child(y_input)

	var mass_map_btn := SocialUi.small_button("🚀 Dịch Chuyển Toàn Map")
	var mass_all_btn := SocialUi.small_button("🌐 Dịch Chuyển TOÀN SERVER")
	mass_row.add_child(mass_map_btn)
	mass_row.add_child(mass_all_btn)
	mass_sec[1].add_child(mass_row)
	_content_area.add_child(mass_sec[0])

	mass_map_btn.pressed.connect(func() -> void:
		var pos := Vector2(float(x_input.text), float(y_input.text))
		GmManager.teleport_all_players(pos, true)
		_show_toast("Đã dịch chuyển toàn bộ người chơi trong map tới (%d, %d)" % [pos.x, pos.y])
	)
	mass_all_btn.pressed.connect(func() -> void:
		var pos := Vector2(float(x_input.text), float(y_input.text))
		GmManager.teleport_all_players(pos, false)
		_show_toast("Đã phát lệnh kéo TOÀN BỘ NGƯỜI CHƠI tới (%d, %d)" % [pos.x, pos.y])
	)

	var update_target_ui := func() -> void:
		if _selected_player.is_empty():
			target_detail_label.text = "Vui lòng chọn 1 người chơi từ danh sách bên trên."
			return
		var s_text := "ĐANG CHỌN: [%s] (ID: %s)  ·  Cấp: %d  ·  Phái: %s  ·  Bản đồ: %s  ·  Tọa độ: (%d, %d)" % [
			_selected_player.get("name", "?"), _selected_player.get("id", "?"),
			int(_selected_player.get("level", 1)), _selected_player.get("sect", "?"),
			_selected_player.get("map", "?"),
			roundi(_selected_player.get("pos", Vector2.ZERO).x), roundi(_selected_player.get("pos", Vector2.ZERO).y)
		]
		target_detail_label.text = s_text

		for c in actions_grid.get_children():
			c.queue_free()

		var btn_goto := SocialUi.small_button("📍 Bay Đến")
		var btn_summon := SocialUi.small_button("🧲 Kéo Lại Đây")
		var btn_stuck := SocialUi.small_button("🚨 Kích Kẹt Về Làng")
		var btn_rename := SocialUi.small_button("✏ Đổi Tên Nhân Vật")
		var btn_mute := SocialUi.small_button("🔇 Cấm Chat 30 Phút")
		var btn_ban := SocialUi.small_button("⛔ Khóa Nick 3 Ngày")
		var btn_kick := SocialUi.small_button("⚡ Kích Đăng Xuất")
		var btn_unlock := SocialUi.small_button("🔓 Mở Khóa Rương")
		var btn_camp := SocialUi.small_button("🚩 Đổi Phe / Màu PK")
		var btn_reset := SocialUi.small_button("🔄 Tẩy Tủy Toàn Bộ")
		var btn_skills := SocialUi.small_button("📜 Học Full Skill Phái")
		var btn_hkmp := SocialUi.small_button("🏆 Cấp Full Bộ HKMP")
		var btn_pts := SocialUi.small_button("⭐ +500 Tiềm Năng & Skill")
		var btn_custom_pot := SocialUi.small_button("✏ Nhập Số Tiềm Năng Tự Tăng")

		btn_goto.pressed.connect(func() -> void:
			GmManager.goto_player(_selected_player)
			_show_toast("Đã bay đến người chơi %s" % _selected_player.get("name", ""))
		)
		btn_summon.pressed.connect(func() -> void:
			GmManager.summon_player(_selected_player)
			_show_toast("Đã kéo người chơi %s lại đây" % _selected_player.get("name", ""))
		)
		btn_stuck.pressed.connect(func() -> void:
			GmManager.kick_stuck(_selected_player)
			_show_toast("Đã giải kẹt cho %s" % _selected_player.get("name", ""))
		)
		btn_rename.pressed.connect(func() -> void:
			SocialWindow.prompt(get_tree().current_scene, "Đổi Tên Nhân Vật", "Nhập tên mới cho nhân vật:", func(n: String) -> void:
				GmManager.rename_player(_selected_player, n)
				_selected_player["name"] = n
				_render_tab()
			)
		)
		btn_mute.pressed.connect(func() -> void:
			GmManager.mute_player(_selected_player, 30, "GM cấm ngôn 30 phút")
			_show_toast("Đã cấm chat %s trong 30 phút" % _selected_player.get("name", ""))
		)
		btn_ban.pressed.connect(func() -> void:
			GmManager.ban_player(_selected_player, 72, "GM khóa tài khoản 3 ngày")
			_show_toast("Đã khóa nick %s trong 3 ngày" % _selected_player.get("name", ""))
		)
		btn_kick.pressed.connect(func() -> void:
			GmManager.kick_player(_selected_player)
			_show_toast("Đã gửi lệnh ngắt kết nối %s" % _selected_player.get("name", ""))
		)
		btn_unlock.pressed.connect(func() -> void:
			if _selected_player.get("profile"):
				GmManager.unlock_security_storage(_selected_player["profile"])
			_show_toast("Đã xóa pass rương bảo vệ cho %s" % _selected_player.get("name", ""))
		)
		btn_camp.pressed.connect(func() -> void:
			var p: PlayerProfile = _selected_player.get("profile") if _selected_player.get("profile") else GameManager.local_profile
			var cur_c: int = p.get_current_camp() if p else 0
			var next_c: int = (cur_c + 1) % 5
			GmManager.change_player_camp(p, next_c)
			_show_toast("Đã đổi màu PK thành: %s" % Camp.get_camp_name(next_c))
			_render_tab()
		)
		btn_reset.pressed.connect(func() -> void:
			var p: PlayerProfile = _selected_player.get("profile") if _selected_player.get("profile") else GameManager.local_profile
			GmManager.reset_skills_and_stats(p)
			_show_toast("Đã tẩy toàn bộ tiềm năng & kỹ năng cho %s" % _selected_player.get("name", ""))
		)
		btn_skills.pressed.connect(func() -> void:
			var p: PlayerProfile = _selected_player.get("profile") if _selected_player.get("profile") else GameManager.local_profile
			var c: int = GmManager.learn_all_sect_skills(p)
			_show_toast("Đã lĩnh hội full %d kỹ năng môn phái cho %s" % [c, _selected_player.get("name", "")])
		)
		btn_hkmp.pressed.connect(func() -> void:
			var p: PlayerProfile = _selected_profile()
			var c: int = GmManager.give_hkmp_set(p)
			_show_toast("Đã cấp %d món Trang Bị Hoàng Kim Môn Phái cho %s!" % [c, _selected_player.get("name", "")])
		)
		btn_pts.pressed.connect(func() -> void:
			var p: PlayerProfile = _selected_profile()
			GmManager.add_free_points(p, 500, 50)
			_show_toast("Đã cộng +500 tiềm năng và +50 kỹ năng cho %s!" % _selected_player.get("name", ""))
		)
		btn_custom_pot.pressed.connect(func() -> void:
			var p: PlayerProfile = _selected_profile()
			SocialWindow.prompt(get_tree().current_scene, "Tự Tăng Điểm Tiềm Năng", "Nhập số điểm tiềm năng muốn tăng cho %s:" % _selected_player.get("name", "người chơi"), func(val_str: String) -> void:
				var n := int(val_str.strip_edges())
				if n <= 0:
					_show_toast("Số điểm nhập vào không hợp lệ!")
					return
				GmManager.add_potential_points(p, n)
				_show_toast("Đã tăng +%d điểm tiềm năng cho %s (Hiện có: %d)!" % [n, _selected_player.get("name", ""), p.potential_points])
			)
		)

		for b in [btn_goto, btn_summon, btn_stuck, btn_rename, btn_mute, btn_ban, btn_kick, btn_unlock, btn_camp, btn_reset, btn_skills, btn_hkmp, btn_pts, btn_custom_pot]:
			b.custom_minimum_size = Vector2(160, 32)
			actions_grid.add_child(b)

	var populate_list := func(items: Array[Dictionary]) -> void:
		for c in player_list_container.get_children():
			c.queue_free()
		if items.is_empty():
			player_list_container.add_child(SocialUi.label("Không tìm thấy người chơi phù hợp.", SocialUi.MUTED, 12))
			return
		for p in items:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var is_sel: bool = str(p.get("id")) == str(_selected_player.get("id"))
			var label_str := "%s  ·  %s (Cấp %d)  ·  ID: %s  ·  Bản đồ: %s" % [
				"[Bản Thân]" if p.get("is_self") else "[Người Chơi]",
				p.get("name"), int(p.get("level")), p.get("id"), p.get("map")
			]
			var plabel := SocialUi.label(label_str, SocialUi.LABEL_GREEN if p.get("is_self") else SocialUi.TEXT, 13)
			plabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pick_btn := SocialUi.small_button("Chọn" if not is_sel else "✔ Đang Chọn")
			pick_btn.pressed.connect(func() -> void:
				_selected_player = p
				update_target_ui.call()
			)
			row.add_child(plabel)
			row.add_child(pick_btn)
			player_list_container.add_child(row)

	search_btn.pressed.connect(func() -> void: populate_list.call(GmManager.search_players(search_input.text)))
	refresh_all_btn.pressed.connect(func() -> void:
		search_input.text = ""
		populate_list.call(GmManager.get_player_list())
	)
	populate_list.call(GmManager.get_player_list())
	update_target_ui.call()

# ==============================================================================
# TAB 2: QUYỀN NĂNG BẢN THÂN
# ==============================================================================

func _build_self_tab() -> void:
	var toggle_sec := SocialUi.info_box("⚡ Quyền Năng Đặc Biệt")
	var toggle_grid := GridContainer.new()
	toggle_grid.columns = 3
	toggle_grid.add_theme_constant_override("h_separation", 12)
	toggle_grid.add_theme_constant_override("v_separation", 10)
	toggle_sec[1].add_child(toggle_grid)
	_content_area.add_child(toggle_sec[0])

	var btn_inv := SocialUi.stone_button("👁 Tàng Hình: %s" % ("BẬT" if GmManager.is_invisible else "TẮT"), Vector2(220, 36))
	var btn_god := SocialUi.stone_button("🛡 Bất Tử: %s" % ("BẬT" if GmManager.is_god_mode else "TẮT"), Vector2(220, 36))
	var btn_noclip := SocialUi.stone_button("👻 Xuyên Tường: %s" % ("BẬT" if GmManager.is_noclip else "TẮT"), Vector2(220, 36))
	var btn_halo := SocialUi.stone_button("✦ Vòng Sáng GM: %s" % ("BẬT" if GmManager.is_gm_halo else "TẮT"), Vector2(220, 36))
	var btn_mask := SocialUi.stone_button("🥋 Ngoại Hình GM: %s" % ("BẬT" if GmManager.is_gm_mask else "TẮT"), Vector2(220, 36))

	btn_inv.pressed.connect(func() -> void:
		GmManager.is_invisible = not GmManager.is_invisible
		btn_inv.text = "👁 Tàng Hình: %s" % ("BẬT" if GmManager.is_invisible else "TẮT")
	)
	btn_god.pressed.connect(func() -> void:
		GmManager.is_god_mode = not GmManager.is_god_mode
		btn_god.text = "🛡 Bất Tử: %s" % ("BẬT" if GmManager.is_god_mode else "TẮT")
	)
	btn_noclip.pressed.connect(func() -> void:
		GmManager.is_noclip = not GmManager.is_noclip
		btn_noclip.text = "👻 Xuyên Tường: %s" % ("BẬT" if GmManager.is_noclip else "TẮT")
	)
	btn_halo.pressed.connect(func() -> void:
		GmManager.is_gm_halo = not GmManager.is_gm_halo
		btn_halo.text = "✦ Vòng Sáng GM: %s" % ("BẬT" if GmManager.is_gm_halo else "TẮT")
		_refresh_footer()
	)
	btn_mask.pressed.connect(func() -> void:
		GmManager.is_gm_mask = not GmManager.is_gm_mask
		btn_mask.text = "🥋 Ngoại Hình GM: %s" % ("BẬT" if GmManager.is_gm_mask else "TẮT")
		_refresh_footer()
	)
	toggle_grid.add_child(btn_inv)
	toggle_grid.add_child(btn_god)
	toggle_grid.add_child(btn_noclip)
	toggle_grid.add_child(btn_halo)
	toggle_grid.add_child(btn_mask)

	var camp_sec := SocialUi.info_box("🚩 Thay Đổi Trạng Thái Phe PK (Màu Chữ GM)")
	var camp_row := HBoxContainer.new()
	camp_row.add_theme_constant_override("separation", 8)
	var camp_options := [
		{"name": "Luyện Công (Trắng)", "id": Camp.Type.BEGIN},
		{"name": "Chính Phái (Cam)", "id": Camp.Type.JUSTICE},
		{"name": "Tà Phái (Tím)", "id": Camp.Type.EVIL},
		{"name": "Trung Lập (Xanh)", "id": Camp.Type.BALANCE},
		{"name": "Sát Thủ (Đỏ)", "id": Camp.Type.FREE},
		{"name": "Game Master (Hồng)", "id": Camp.Type.EVENT},
	]
	for c_opt in camp_options:
		var cb := SocialUi.small_button(str(c_opt["name"]))
		cb.pressed.connect(func() -> void:
			GmManager.change_player_camp(GameManager.local_profile, int(c_opt["id"]))
			_show_toast("Đã chuyển màu PK thành: %s" % str(c_opt["name"]))
		)
		camp_row.add_child(cb)
	camp_sec[1].add_child(camp_row)
	_content_area.add_child(camp_sec[0])

	var skill_sec := SocialUi.info_box("📜 Kỹ Năng & Tẩy Tủy Môn Phái")
	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 10)
	var learn_all_btn := SocialUi.small_button("📖 Học Full Kỹ Năng Phái")
	var reset_pts_btn := SocialUi.small_button("🔄 Tẩy Tủy Toàn Bộ")
	var add_1k_pts_btn := SocialUi.small_button("⭐ +1000 Tiềm Năng & Kỹ Năng")

	learn_all_btn.pressed.connect(func() -> void:
		var c := GmManager.learn_all_sect_skills(GameManager.local_profile)
		_show_toast("Đã học full %d kỹ năng môn phái!" % c)
	)
	reset_pts_btn.pressed.connect(func() -> void:
		GmManager.reset_skills_and_stats(GameManager.local_profile)
		_show_toast("Đã tẩy toàn bộ điểm tiềm năng và kỹ năng về điểm tự do!")
	)
	add_1k_pts_btn.pressed.connect(func() -> void:
		GmManager.add_free_points(GameManager.local_profile, 1000, 100)
		_show_toast("Đã cộng +1000 điểm tiềm năng và +100 điểm kỹ năng!")
	)
	skill_row.add_child(learn_all_btn)
	skill_row.add_child(reset_pts_btn)
	skill_row.add_child(add_1k_pts_btn)
	skill_sec[1].add_child(skill_row)
	_content_area.add_child(skill_sec[0])

	var loc_sec := SocialUi.info_box("📍 Dịch Chuyển Tức Thời Đến Địa Danh Trọng Yếu")
	var loc_grid := GridContainer.new()
	loc_grid.columns = 4
	loc_grid.add_theme_constant_override("h_separation", 8)
	loc_grid.add_theme_constant_override("v_separation", 8)
	for loc_name in GmManager.LOCATIONS.keys():
		var lb := SocialUi.small_button("🚩 %s" % loc_name)
		lb.custom_minimum_size = Vector2(160, 32)
		lb.pressed.connect(func() -> void:
			GmManager.teleport_to_location({"is_self": true, "name": "Bản thân"}, loc_name)
			_show_toast("Đã dịch chuyển tới %s!" % loc_name)
		)
		loc_grid.add_child(lb)
	loc_sec[1].add_child(loc_grid)
	_content_area.add_child(loc_sec[0])

	var spd_sec := SocialUi.info_box("🏃 Tốc Độ Di Chuyển")
	var spd_row := HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 8)
	for m in [1.0, 1.5, 2.0, 3.0, 5.0]:
		var b := SocialUi.small_button("%.1fx%s" % [m, " (Chuẩn)" if m == 1.0 else ""])
		b.pressed.connect(func() -> void:
			GmManager.speed_mult = m
			_show_toast("Tốc độ chạy đặt: %.1fx" % m)
		)
		spd_row.add_child(b)
	spd_sec[1].add_child(spd_row)
	_content_area.add_child(spd_sec[0])

	var stats_sec := SocialUi.info_box("💪 Hồi Máu & Cộng Chỉ Số")
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 10)
	var full_heal_btn := SocialUi.small_button("💚 Hồi Đầy 100% HP/MP/SP")
	var add_100_all := SocialUi.small_button("⭐ +100 Toàn Bộ Chỉ Số")
	var set_lv_100 := SocialUi.small_button("🎖 Đặt Cấp 100")
	var set_lv_150 := SocialUi.small_button("🎖 Đặt Cấp 150")

	full_heal_btn.pressed.connect(func() -> void:
		GmManager.restore_self_full()
		_show_toast("Đã hồi phục toàn bộ Sinh lực & Nội lực!")
	)
	add_100_all.pressed.connect(func() -> void:
		GmManager.adjust_stats(GameManager.local_profile, 100, 100, 100, 100)
		_show_toast("Đã cộng +100 Sức mạnh, Thân pháp, Sinh khí, Nội công!")
	)
	set_lv_100.pressed.connect(func() -> void:
		GmManager.set_player_level(GameManager.local_profile, 100)
		_show_toast("Đã đặt nhân vật lên Cấp 100!")
	)
	set_lv_150.pressed.connect(func() -> void:
		GmManager.set_player_level(GameManager.local_profile, 150)
		_show_toast("Đã đặt nhân vật lên Cấp 150!")
	)
	stats_row.add_child(full_heal_btn)
	stats_row.add_child(add_100_all)
	stats_row.add_child(set_lv_100)
	stats_row.add_child(set_lv_150)
	stats_sec[1].add_child(stats_row)
	_content_area.add_child(stats_sec[0])

	var custom_pts_sec := SocialUi.info_box("⭐ Tăng Điểm Tiềm Năng & Thuộc Tính (Tự Nhập Số)")
	var pts_input_row := HBoxContainer.new()
	pts_input_row.add_theme_constant_override("separation", 10)

	var pts_input := SocialUi.line_edit("Số điểm...")
	pts_input.text = "500"
	pts_input.custom_minimum_size.x = 140
	pts_input_row.add_child(SocialUi.label("Nhập số điểm:", SocialUi.TEXT, 13))
	pts_input_row.add_child(pts_input)

	var btn_add_pot := SocialUi.stone_button("➕ CỘNG ĐIỂM TIỀM NĂNG TỰ DO", Vector2(230, 34))
	pts_input_row.add_child(btn_add_pot)
	custom_pts_sec[1].add_child(pts_input_row)

	btn_add_pot.pressed.connect(func() -> void:
		var n := int(pts_input.text.strip_edges())
		if n <= 0:
			_show_toast("Vui lòng nhập số điểm lớn hơn 0!")
			return
		GmManager.add_potential_points(GameManager.local_profile, n)
		_show_toast("Đã tăng +%d điểm tiềm năng tự do (Hiện có: %d)!" % [n, GameManager.local_profile.potential_points])
	)

	var stat_btns_grid := GridContainer.new()
	stat_btns_grid.columns = 5
	stat_btns_grid.add_theme_constant_override("h_separation", 8)
	stat_btns_grid.add_theme_constant_override("v_separation", 6)

	var btn_add_str := SocialUi.small_button("💪 Tăng Sức Mạnh")
	var btn_add_dex := SocialUi.small_button("🏃 Tăng Thân Pháp")
	var btn_add_vit := SocialUi.small_button("💚 Tăng Sinh Khí")
	var btn_add_eng := SocialUi.small_button("🌀 Tăng Nội Công")
	var btn_add_all := SocialUi.small_button("⭐ Tăng Cả 4 Thuộc Tính")

	btn_add_str.pressed.connect(func() -> void:
		var n := int(pts_input.text.strip_edges())
		if n <= 0: return
		GmManager.add_single_stat(GameManager.local_profile, "str", n)
		_show_toast("Đã tăng +%d Sức mạnh (Hiện có: %d)!" % [n, GameManager.local_profile.strength])
	)
	btn_add_dex.pressed.connect(func() -> void:
		var n := int(pts_input.text.strip_edges())
		if n <= 0: return
		GmManager.add_single_stat(GameManager.local_profile, "dex", n)
		_show_toast("Đã tăng +%d Thân pháp (Hiện có: %d)!" % [n, GameManager.local_profile.dexterity])
	)
	btn_add_vit.pressed.connect(func() -> void:
		var n := int(pts_input.text.strip_edges())
		if n <= 0: return
		GmManager.add_single_stat(GameManager.local_profile, "vit", n)
		_show_toast("Đã tăng +%d Sinh khí (Hiện có: %d)!" % [n, GameManager.local_profile.vitality])
	)
	btn_add_eng.pressed.connect(func() -> void:
		var n := int(pts_input.text.strip_edges())
		if n <= 0: return
		GmManager.add_single_stat(GameManager.local_profile, "eng", n)
		_show_toast("Đã tăng +%d Nội công (Hiện có: %d)!" % [n, GameManager.local_profile.energy])
	)
	btn_add_all.pressed.connect(func() -> void:
		var n := int(pts_input.text.strip_edges())
		if n <= 0: return
		GmManager.adjust_stats(GameManager.local_profile, n, n, n, n)
		_show_toast("Đã tăng đều +%d cho cả 4 thuộc tính cơ bản!" % n)
	)

	for b in [btn_add_str, btn_add_dex, btn_add_vit, btn_add_eng, btn_add_all]:
		b.custom_minimum_size = Vector2(150, 32)
		stat_btns_grid.add_child(b)
	custom_pts_sec[1].add_child(stat_btns_grid)
	_content_area.add_child(custom_pts_sec[0])

# ==============================================================================
# TAB 3: CẤP ĐỒ, TIỀN & VẬT PHẨM
# ==============================================================================

func _update_dispenser_summary() -> void:
	if _dispenser_res_label == null or not is_instance_valid(_dispenser_res_label):
		return
	var p: PlayerProfile = _selected_profile()
	if p == null:
		_dispenser_res_label.text = "Chưa có thông tin tài nguyên."
		return
	_dispenser_res_label.text = "💰 Ngân lượng: %s  ·  🪙 Tiền Xu: %s  ·  💎 KNB: %s  ·  Danh vọng: %s  ·  Phúc duyên: %s" % [
		CharacterHubScreen.format_number(p.gold),
		CharacterHubScreen.format_number(p.xu),
		CharacterHubScreen.format_number(p.jade),
		CharacterHubScreen.format_number(p.prestige),
		CharacterHubScreen.format_number(p.fuyuan)
	]

func _build_dispenser_tab() -> void:
	var target_name: String = _selected_player.get("name", "Bản Thân")
	var target_p: PlayerProfile = _selected_player.get("profile") if _selected_player.get("profile") else GameManager.local_profile

	var info_sec := SocialUi.info_box("🎁 Mục Tiêu Nhận Quà: %s" % target_name)
	info_sec[1].add_child(SocialUi.label("Bạn có thể đổi mục tiêu nhận quà tại Tab [1. Người Chơi].", SocialUi.MUTED, 12))

	var res_box := PanelContainer.new()
	var res_sb := StyleBoxFlat.new()
	res_sb.bg_color = Color(0.08, 0.12, 0.18, 0.85)
	res_sb.border_color = Color(0.85, 0.72, 0.25, 0.8)
	res_sb.set_border_width_all(1)
	res_sb.set_corner_radius_all(4)
	res_sb.content_margin_left = 12
	res_sb.content_margin_right = 12
	res_sb.content_margin_top = 6
	res_sb.content_margin_bottom = 6
	res_box.add_theme_stylebox_override("panel", res_sb)

	_dispenser_res_label = SocialUi.label("", SocialUi.GOLD, 13)
	res_box.add_child(_dispenser_res_label)
	info_sec[1].add_child(res_box)
	_update_dispenser_summary()

	_content_area.add_child(info_sec[0])

	var money_sec := SocialUi.info_box("💰 Cấp Ngân Lượng, Tiền Xu & Kim Nguyên Bảo")
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 10)

	var add_10tr := SocialUi.small_button("+1.000 Vạn Lượng")
	var add_50tr := SocialUi.small_button("+5.000 Vạn Lượng")
	var add_1k_xu := SocialUi.small_button("+1.000 Xu")
	var add_5k_xu := SocialUi.small_button("+5.000 Xu")
	var add_1k_knb := SocialUi.small_button("+1.000 KNB")
	var add_10k_knb := SocialUi.small_button("+10.000 KNB")
	var add_rep := SocialUi.small_button("+500 Danh Vọng & Phúc Duyên")

	add_10tr.pressed.connect(func() -> void:
		GmManager.give_resources(target_p, 10_000_000, 0, 0, 0, 0)
		_show_toast("Đã cấp +1.000 vạn lượng cho %s" % target_name)
	)
	add_50tr.pressed.connect(func() -> void:
		GmManager.give_resources(target_p, 50_000_000, 0, 0, 0, 0)
		_show_toast("Đã cấp +5.000 vạn lượng cho %s" % target_name)
	)
	add_1k_xu.pressed.connect(func() -> void:
		GmManager.give_resources(target_p, 0, 0, 0, 0, 1000)
		_show_toast("Đã cấp +1.000 Tiền Xu cho %s" % target_name)
	)
	add_5k_xu.pressed.connect(func() -> void:
		GmManager.give_resources(target_p, 0, 0, 0, 0, 5000)
		_show_toast("Đã cấp +5.000 Tiền Xu cho %s" % target_name)
	)
	add_1k_knb.pressed.connect(func() -> void:
		GmManager.give_resources(target_p, 0, 1000, 0, 0, 0)
		_show_toast("Đã cấp +1.000 KNB cho %s" % target_name)
	)
	add_10k_knb.pressed.connect(func() -> void:
		GmManager.give_resources(target_p, 0, 10000, 0, 0, 0)
		_show_toast("Đã cấp +10.000 KNB cho %s" % target_name)
	)
	add_rep.pressed.connect(func() -> void:
		GmManager.give_resources(target_p, 0, 0, 500, 500, 0)
		_show_toast("Đã cấp +500 Danh vọng và Phúc duyên cho %s" % target_name)
	)

	money_row.add_child(add_10tr)
	money_row.add_child(add_50tr)
	money_row.add_child(add_1k_xu)
	money_row.add_child(add_5k_xu)
	money_row.add_child(add_1k_knb)
	money_row.add_child(add_10k_knb)
	money_row.add_child(add_rep)
	money_sec[1].add_child(money_row)
	_content_area.add_child(money_sec[0])

	var item_sec := SocialUi.info_box("⚔ Cấp Trang Bị & Khoáng Thạch")
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 10)

	var open_creator_btn := SocialUi.small_button("🛠 Bảng Chế Tạo Trang Bị Tự Chọn (Item Creator)")
	var add_10_rnd := SocialUi.small_button("🎲 10 Trang Bị Ngẫu Nhiên")
	var add_xj_10 := SocialUi.small_button("💎 3 Viên Huyền Tinh Cấp 10")

	open_creator_btn.pressed.connect(func() -> void:
		ItemCreatorPopup.open(get_tree().current_scene, target_p, func() -> void:
			SaveManager.save_profile(target_p)
			SaveManager.flush_online.call_deferred()
			GmManager.profile_modified.emit(target_p)
			_show_toast("Đã thêm trang bị tùy chọn vào túi đồ của %s!" % target_name)
		)
	)
	add_10_rnd.pressed.connect(func() -> void:
		for i in 10:
			target_p.add_item(ItemGenerator.random_equipment(target_p.level))
		SaveManager.save_profile(target_p)
		SaveManager.flush_online.call_deferred()
		GmManager.profile_modified.emit(target_p)
		_show_toast("Đã cấp 10 trang bị ngẫu nhiên cho %s" % target_name)
	)
	add_xj_10.pressed.connect(func() -> void:
		for i in 3:
			var xj := ItemGenerator.generate_misc(Compound.XUANJING, 10, 0, 1)
			target_p.add_item(xj)
		SaveManager.save_profile(target_p)
		SaveManager.flush_online.call_deferred()
		GmManager.profile_modified.emit(target_p)
		_show_toast("Đã cấp 3 viên Huyền Tinh Cấp 10 cho %s" % target_name)
	)

	item_row.add_child(open_creator_btn)
	item_row.add_child(add_10_rnd)
	item_row.add_child(add_xj_10)
	item_sec[1].add_child(item_row)
	_content_area.add_child(item_sec[0])

	var gold_sec := SocialUi.info_box("🏆 Bộ Trang Bị Hoàng Kim & Thần Mã (Chuẩn 15 Phái)")
	var gold_grid := GridContainer.new()
	gold_grid.columns = 3
	gold_grid.add_theme_constant_override("h_separation", 10)
	gold_grid.add_theme_constant_override("v_separation", 8)

	var btn_hkmp := SocialUi.small_button("🏆 Cấp Bộ HKMP Hoàn Mỹ (Theo Phái)")
	var btn_ab := SocialUi.small_button("🌟 Cấp Trọn Bộ An Bang")
	var btn_dq := SocialUi.small_button("🛡 Cấp Trọn Bộ Định Quốc")
	var btn_kp := SocialUi.small_button("🎖 Cấp Trọn Bộ Kim Phong")
	var btn_horse_pv := SocialUi.small_button("🐎 Thần Mã Phiên Vũ (Cấp 10)")
	var btn_horse_bt := SocialUi.small_button("🐎 Chiến Mã Bôn Tiêu (Cấp 10)")
	var btn_gems := SocialUi.small_button("🔮 Gói Thủy Tinh, Tinh Hồng & HT 10")

	btn_hkmp.pressed.connect(func() -> void:
		var c := GmManager.give_hkmp_set(target_p)
		_show_toast("Đã cấp trọn bộ HKMP (%d món) cho %s!" % [c, target_name])
	)
	btn_ab.pressed.connect(func() -> void:
		var c := GmManager.give_an_bang_set(target_p)
		_show_toast("Đã cấp bộ An Bang (%d món) cho %s!" % [c, target_name])
	)
	btn_dq.pressed.connect(func() -> void:
		var c := GmManager.give_dinh_quoc_set(target_p)
		_show_toast("Đã cấp bộ Định Quốc (%d món) cho %s!" % [c, target_name])
	)
	btn_kp.pressed.connect(func() -> void:
		var c := GmManager.give_kim_phong_set(target_p)
		_show_toast("Đã cấp bộ Kim Phong (%d món) cho %s!" % [c, target_name])
	)
	btn_horse_pv.pressed.connect(func() -> void:
		GmManager.give_horse_vip(target_p, "Phiên Vũ")
		_show_toast("Đã cấp Thần Mã Phiên Vũ cho %s!" % target_name)
	)
	btn_horse_bt.pressed.connect(func() -> void:
		GmManager.give_horse_vip(target_p, "Bôn Tiêu")
		_show_toast("Đã cấp Chiến Mã Bôn Tiêu cho %s!" % target_name)
	)
	btn_gems.pressed.connect(func() -> void:
		var c := GmManager.give_gem_pack(target_p)
		_show_toast("Đã cấp gói Nguyên liệu & Thủy tinh (%d món) cho %s!" % [c, target_name])
	)

	for b in [btn_hkmp, btn_ab, btn_dq, btn_kp, btn_horse_pv, btn_horse_bt, btn_gems]:
		b.custom_minimum_size = Vector2(230, 32)
		gold_grid.add_child(b)

	gold_sec[1].add_child(gold_grid)
	_content_area.add_child(gold_sec[0])

# ==============================================================================
# TAB 4: QUẢN LÝ BOSS & RỚT ĐỒ
# ==============================================================================

func _build_boss_tab() -> void:
	var tuning_sec := SocialUi.info_box("⚙ Điều Chỉnh Thông Số Toàn Bộ Boss")
	var tuning_grid := GridContainer.new()
	tuning_grid.columns = 3
	tuning_grid.add_theme_constant_override("h_separation", 12)
	tuning_grid.add_theme_constant_override("v_separation", 10)

	## Máu Boss
	var hp_row := VBoxContainer.new()
	hp_row.add_child(SocialUi.label("Hệ số Máu Boss (Max HP): %.1fx" % GmManager.boss_hp_mult, SocialUi.TEXT, 13))
	var hp_btn_row := HBoxContainer.new()
	for h in [0.5, 1.0, 2.0, 5.0, 10.0]:
		var b := SocialUi.small_button("%.1fx" % h)
		b.pressed.connect(func() -> void:
			GmManager.boss_hp_mult = h
			_render_tab()
		)
		hp_btn_row.add_child(b)
	hp_row.add_child(hp_btn_row)
	tuning_grid.add_child(hp_row)

	## Dame Boss
	var dmg_row := VBoxContainer.new()
	dmg_row.add_child(SocialUi.label("Hệ số Sát thương Boss: %.1fx" % GmManager.boss_damage_mult, SocialUi.TEXT, 13))
	var dmg_btn_row := HBoxContainer.new()
	for d in [0.5, 1.0, 2.0, 5.0]:
		var b := SocialUi.small_button("%.1fx" % d)
		b.pressed.connect(func() -> void:
			GmManager.boss_damage_mult = d
			_render_tab()
		)
		dmg_btn_row.add_child(b)
	dmg_row.add_child(dmg_btn_row)
	tuning_grid.add_child(dmg_row)

	## Rớt đồ Boss
	var drop_row := VBoxContainer.new()
	drop_row.add_child(SocialUi.label("Hệ số Tỉ Lệ Rớt Đồ: %.1fx" % GmManager.boss_drop_mult, SocialUi.TEXT, 13))
	var drop_btn_row := HBoxContainer.new()
	for r in [1.0, 2.0, 5.0, 10.0, 20.0]:
		var b := SocialUi.small_button("%.1fx" % r)
		b.pressed.connect(func() -> void:
			GmManager.boss_drop_mult = r
			_render_tab()
		)
		drop_btn_row.add_child(b)
	drop_row.add_child(drop_btn_row)
	tuning_grid.add_child(drop_row)

	tuning_sec[1].add_child(tuning_grid)
	_content_area.add_child(tuning_sec[0])

	var radar_sec := SocialUi.info_box("🧭 Quét & Định Vị Boss Hoàng Kim (findgoldboss)")
	var radar_row := HBoxContainer.new()
	radar_row.add_theme_constant_override("separation", 10)
	var scan_btn := SocialUi.small_button("🔍 Quét Toàn Bộ Boss Đang Hoạt Động")
	radar_row.add_child(scan_btn)
	radar_sec[1].add_child(radar_row)

	var radar_results := VBoxContainer.new()
	radar_results.add_theme_constant_override("separation", 6)
	radar_sec[1].add_child(radar_results)
	_content_area.add_child(radar_sec[0])

	scan_btn.pressed.connect(func() -> void:
		for c in radar_results.get_children():
			c.queue_free()
		var found := GmManager.find_bosses()
		if found.is_empty():
			radar_results.add_child(SocialUi.label("Không phát hiện Boss Hoàng Kim nào đang sống trên map.", SocialUi.MUTED, 12))
			return
		for b in found:
			var b_row := HBoxContainer.new()
			b_row.add_theme_constant_override("separation", 10)
			var b_lbl := SocialUi.label("👹 [%s] Cấp %d · Máu: %d/%d · Cách GM: %d mét · Tọa độ: (%d, %d)" % [
				b["name"], b["level"], int(b["hp"]), int(b["max_hp"]), roundi(b["dist"]), roundi(b["pos"].x), roundi(b["pos"].y)
			], SocialUi.GOLD, 12)
			b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var fly_btn := SocialUi.small_button("📍 Bay Đến")
			fly_btn.pressed.connect(func() -> void:
				var p_node := GmManager.get_player_node()
				if p_node:
					p_node.global_position = b["pos"]
					_show_toast("Đã bay đến vị trí của %s!" % b["name"])
			)
			b_row.add_child(b_lbl)
			b_row.add_child(fly_btn)
			radar_results.add_child(b_row)
	)

	var spawn_sec := SocialUi.info_box("👹 Triệu Hồi Đại Boss Hoàng Kim (Chuẩn 15 Phái)")
	var boss_grid := GridContainer.new()
	boss_grid.columns = 3
	boss_grid.add_theme_constant_override("h_separation", 8)
	boss_grid.add_theme_constant_override("v_separation", 8)
	spawn_sec[1].add_child(boss_grid)

	var player_node := GmManager.get_player_node()
	var spawn_pos := player_node.global_position if player_node else Vector2(200, 200)

	var sample_bosses := [
		{"name": "Huyền Giác Đại Sư", "res": "boss003", "series": 0, "level": 95, "type": "gold"},
		{"name": "Cổ Bách", "res": "boss018", "series": 0, "level": 95, "type": "gold"},
		{"name": "Gia Luật Tị Ly", "res": "boss007", "series": 0, "level": 95, "type": "gold"},
		{"name": "Đường Bất Nhiễm", "res": "boss019", "series": 1, "level": 95, "type": "gold"},
		{"name": "Bạch Doanh Doanh", "res": "boss002", "series": 1, "level": 95, "type": "gold"},
		{"name": "Lam Y Y", "res": "boss008", "series": 1, "level": 95, "type": "gold"},
		{"name": "Thanh Tuyệt Sư Thái", "res": "boss004", "series": 2, "level": 95, "type": "gold"},
		{"name": "Yên Hiểu Trái", "res": "boss006", "series": 2, "level": 95, "type": "gold"},
		{"name": "Hà Linh Phiêu", "res": "boss005", "series": 2, "level": 95, "type": "gold"},
		{"name": "Mạnh Thương Lương", "res": "boss012", "series": 3, "level": 95, "type": "gold"},
		{"name": "Hà Nhân Ngã", "res": "boss009", "series": 3, "level": 95, "type": "gold"},
		{"name": "Đoạn Mộc Duệ", "res": "boss010", "series": 3, "level": 95, "type": "gold"},
		{"name": "Tuyền Cơ Tử", "res": "boss011", "series": 4, "level": 95, "type": "gold"},
		{"name": "Từ Đại Nhạc", "res": "boss013", "series": 4, "level": 95, "type": "gold"},
		{"name": "Độc Cô Cầu Kiếm", "res": "boss015", "series": 0, "level": 100, "type": "challenge"}
	]

	for b_info in sample_bosses:
		var btn := SocialUi.small_button("Thả: %s (Cấp %d)" % [b_info["name"], b_info["level"]])
		btn.pressed.connect(func() -> void:
			var m := GmManager.spawn_boss(b_info["name"], b_info["res"], b_info["series"], b_info["level"], b_info["type"], spawn_pos)
			if m:
				_show_toast("Đã triệu hồi %s tại vị trí hiện tại!" % b_info["name"])
		)
		boss_grid.add_child(btn)

	var clear_btn := SocialUi.stone_button("🧹 Dọn Sạch Toàn Bộ Boss Đã Thả", Vector2(260, 36))
	clear_btn.pressed.connect(func() -> void:
		GmManager.clear_spawned_bosses()
		_show_toast("Đã dọn sạch các Boss do GM triệu hồi!")
	)
	spawn_sec[1].add_child(clear_btn)
	_content_area.add_child(spawn_sec[0])

# ==============================================================================
# TAB 5: CHIẾM QUYỀN / ĐIỀU KHIỂN NHÂN VẬT (IMPERSONATE)
# ==============================================================================

func _build_possess_tab() -> void:
	var sec := SocialUi.info_box("🎮 Chiếm Quyền & Điều Khiển Trực Tiếp Nhân Vật")
	var target_name: String = _selected_player.get("name", "Chưa chọn")
	var target_p: PlayerProfile = _selected_player.get("profile")

	var desc_lbl := SocialUi.label("Cho phép GM đăng nhập và kiểm soát avatar của mục tiêu như tài khoản của chính mình để kiểm tra lỗi, hỗ trợ kỹ thuật hoặc thử nghiệm trực tiếp.", SocialUi.TEXT, 13)
	sec[1].add_child(desc_lbl)

	var target_lbl := SocialUi.label("Mục tiêu đang chọn: [%s] (ID: %s)" % [target_name, _selected_player.get("id", "?")], SocialUi.GOLD, 14)
	sec[1].add_child(target_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)

	var possess_btn := SocialUi.stone_button("🎮 BẮT ĐẦU ĐIỀU KHIỂN", Vector2(200, 36))
	var release_btn := SocialUi.stone_button("↩ TRẢ LẠI QUYỀN", Vector2(180, 36))
	release_btn.disabled = not GmManager.is_possessing

	possess_btn.pressed.connect(func() -> void:
		if target_p == null:
			_show_toast("Mục tiêu không có dữ liệu profile cục bộ để chiếm quyền!")
			return
		if GmManager.possess_player(target_p):
			_show_toast("ĐÃ CHIẾM QUYỀN ĐIỀU KHIỂN: %s!" % target_name)
			_render_tab()
	)

	release_btn.pressed.connect(func() -> void:
		GmManager.release_possession()
		_show_toast("Đã trả lại quyền điều khiển cho nhân vật gốc!")
		_render_tab()
	)

	btn_row.add_child(possess_btn)
	btn_row.add_child(release_btn)
	sec[1].add_child(btn_row)
	_content_area.add_child(sec[0])

# ==============================================================================
# TAB 6: NHẬT KÝ GM & THÔNG BÁO SERVER
# ==============================================================================

func _build_audit_tab() -> void:
	var bc_sec := SocialUi.info_box("📢 Phát Thông Báo Toàn Server")
	var bc_row := HBoxContainer.new()
	bc_row.add_theme_constant_override("separation", 8)
	var bc_input := SocialUi.line_edit("Nhập nội dung thông báo toàn server...")
	bc_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bc_btn := SocialUi.small_button("Phát Loa")
	bc_row.add_child(bc_input)
	bc_row.add_child(bc_btn)
	bc_sec[1].add_child(bc_row)
	_content_area.add_child(bc_sec[0])

	bc_btn.pressed.connect(func() -> void:
		var text := bc_input.text.strip_edges()
		if text != "":
			GmManager.broadcast_announcement(text)
			bc_input.text = ""
			_show_toast("Đã phát thông báo: %s" % text)
	)

	var server_sec := SocialUi.info_box("⚙ Vận Hành Máy Chủ & Chống Rollback")
	var server_row := HBoxContainer.new()
	server_row.add_theme_constant_override("separation", 10)
	var kick_all_btn := SocialUi.stone_button("💾 LƯU TOÀN BỘ TIẾN TRÌNH & KICK ALL (CHỐNG ROLLBACK)", Vector2(400, 36))
	kick_all_btn.pressed.connect(func() -> void:
		GmManager.kick_all_save_data()
		_show_toast("Đã lưu an toàn toàn bộ dữ liệu máy chủ!")
	)
	server_row.add_child(kick_all_btn)
	server_sec[1].add_child(server_row)
	_content_area.add_child(server_sec[0])

	var log_sec := SocialUi.info_box("📜 Lịch Sử Thao Tác Của Game Master (Audit Logs)")
	var log_list := VBoxContainer.new()
	log_list.add_theme_constant_override("separation", 6)
	log_sec[1].add_child(log_list)

	if GmManager.audit_logs.is_empty():
		log_list.add_child(SocialUi.label("Chưa có thao tác GM nào được ghi nhận trong phiên này.", SocialUi.MUTED, 12))
	else:
		for entry in GmManager.audit_logs:
			var item_text := "[%s] GM: %s  ·  Hành động: %s  ·  Mục tiêu: %s  ·  Chi tiết: %s" % [
				entry.get("time", ""), entry.get("gm", ""), entry.get("action", ""),
				entry.get("target", ""), entry.get("detail", "")
			]
			log_list.add_child(SocialUi.label(item_text, SocialUi.TEXT, 12))

	_content_area.add_child(log_sec[0])

func _show_toast(msg: String) -> void:
	var toast := SocialUi.banner(msg, true)
	body.add_child(toast)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
	)

# ==============================================================================
# TAB 7: QUẢN LÝ HÀO QUANG (AURA GRID & CẤP PHÁT)
# ==============================================================================

func _build_aura_tab() -> void:
	# 1. Khung chọn mục tiêu & điều khiển nhanh
	var target_sec := SocialUi.info_box("✨ Mục Tiêu Áp Dụng Hào Quang (Aura)")
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)

	var player_list := GmManager.get_player_list()
	var opt_target := OptionButton.new()
	opt_target.custom_minimum_size = Vector2(280, 34)
	var current_idx := 0
	for i in player_list.size():
		var p: Dictionary = player_list[i]
		var label_str: String = ("★ [Bản Thân] %s" % str(p.get("name", "?"))) if p.get("is_self", false) else ("👤 [Khác] %s (Cấp %d)" % [str(p.get("name", "?")), int(p.get("level", 1))])
		opt_target.add_item(label_str, i)
		if not _selected_player.is_empty() and _selected_player.get("id") == p.get("id"):
			current_idx = i

	if not player_list.is_empty():
		opt_target.selected = current_idx
		_selected_player = player_list[current_idx]

	opt_target.item_selected.connect(func(idx: int) -> void:
		if idx >= 0 and idx < player_list.size():
			_selected_player = player_list[idx]
			_render_tab()
	)
	target_row.add_child(SocialUi.label("Mục tiêu áp dụng:", SocialUi.LABEL_BLUE, 13))
	target_row.add_child(opt_target)

	var clear_btn := SocialUi.small_button("❌ Tháo Hào Quang Hiện Tại")
	clear_btn.pressed.connect(func() -> void:
		GmManager.clear_player_aura(_selected_player)
		_show_toast("Đã tháo hào quang của %s" % _selected_player.get("name", "Mục tiêu"))
		_render_tab()
	)
	target_row.add_child(clear_btn)
	target_sec[1].add_child(target_row)

	var cur_aura_id := 0
	if _selected_player.get("is_self", false) or _selected_player.get("profile") == GameManager.local_profile:
		cur_aura_id = GameManager.local_profile.gm_aura_state if GameManager.local_profile else 0
	elif _selected_player.get("profile") != null:
		cur_aura_id = _selected_player["profile"].gm_aura_state
	elif _selected_player.get("remote_node") != null:
		var r = _selected_player["remote_node"]
		cur_aura_id = int(r._aura_sprite_state) if "_aura_sprite_state" in r else 0

	var cur_aura_info := AuraDatabase.get_by_state(cur_aura_id)
	var cur_name: String = str(cur_aura_info.get("name", "Chưa trang bị" if cur_aura_id == 0 else "State #%d" % cur_aura_id))
	var status_lbl := SocialUi.label("Hào quang đang mang: %s" % cur_name, SocialUi.LABEL_GREEN if cur_aura_id > 0 else SocialUi.MUTED, 12)
	target_sec[1].add_child(status_lbl)
	_content_area.add_child(target_sec[0])

	# 2. Bộ lọc danh mục & Tìm kiếm
	var filter_sec := SocialUi.info_box("🏷 Bộ Lọc & Tìm Kiếm Hào Quang")
	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	var categories := AuraDatabase.get_categories()
	for cat in categories:
		var btn := SocialUi.small_button(cat)
		if cat == _aura_filter_category:
			GameUi.set_active(btn, true)
		btn.pressed.connect(func() -> void:
			_aura_filter_category = cat
			_render_tab()
		)
		cat_row.add_child(btn)
	filter_sec[1].add_child(cat_row)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	var search_input := SocialUi.line_edit("Tìm theo tên hoặc từ khóa hào quang...")
	search_input.text = _aura_search_keyword
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_changed.connect(func(new_text: String) -> void:
		_aura_search_keyword = new_text.strip_edges()
	)
	var apply_search_btn := SocialUi.small_button("🔍 Lọc Danh Sách")
	apply_search_btn.pressed.connect(func() -> void:
		_render_tab()
	)
	search_row.add_child(search_input)
	search_row.add_child(apply_search_btn)
	filter_sec[1].add_child(search_row)
	_content_area.add_child(filter_sec[0])

	# 3. Lưới hiển thị danh sách Hào Quang (Grid)
	var grid_sec := SocialUi.info_box("🌟 Danh Sách Hào Quang Võ Lâm (Grid View - %s)" % _aura_filter_category)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var all_auras := AuraDatabase.get_all()
	var kw := _aura_search_keyword.to_lower()
	var shown_count := 0

	for item in all_auras:
		var cat: String = str(item.get("category", "Khác"))
		var a_name: String = str(item.get("name", ""))
		var state_id: int = int(item.get("state_id", 0))

		if _aura_filter_category != "Tất Cả" and cat != _aura_filter_category:
			continue
		if kw != "" and not a_name.to_lower().contains(kw) and not str(state_id).contains(kw):
			continue

		shown_count += 1
		var card := _build_aura_card(item, cur_aura_id == state_id)
		grid.add_child(card)

	if shown_count == 0:
		var empty_lbl := SocialUi.label("Không tìm thấy hào quang nào phù hợp với bộ lọc.", SocialUi.MUTED, 13)
		grid_sec[1].add_child(empty_lbl)
	else:
		grid_sec[1].add_child(grid)
	_content_area.add_child(grid_sec[0])

func _build_aura_card(item: Dictionary, is_active: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(185, 175)
	var border_color := GameUi.GOLD if is_active else Color(0.25, 0.3, 0.4, 0.6)
	var bg_color := Color(0.18, 0.22, 0.15, 0.95) if is_active else Color(0.12, 0.16, 0.22, 0.85)
	card.add_theme_stylebox_override("panel", GameUi.box(bg_color, border_color, 6, 2 if is_active else 1, 6))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER

	# Thumbnail image (72x72)
	var thumb_rect := TextureRect.new()
	thumb_rect.custom_minimum_size = Vector2(72, 72)
	thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := AuraDatabase.get_thumb(str(item.get("thumb", "")))
	if tex != null:
		thumb_rect.texture = tex
	vb.add_child(thumb_rect)

	# Name label
	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "Aura"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", GameUi.GOLD if is_active else GameUi.TEXT)
	name_lbl.custom_minimum_size = Vector2(170, 28)
	vb.add_child(name_lbl)

	# Category badge
	var cat_lbl := Label.new()
	cat_lbl.text = "[%s]" % str(item.get("category", "Khác"))
	cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_lbl.add_theme_font_size_override("font_size", 9)
	cat_lbl.add_theme_color_override("font_color", GameUi.MUTED)
	vb.add_child(cat_lbl)

	# Action button
	var btn_text := "✔ Đang Mang" if is_active else "Gắn Hào Quang"
	var btn := SocialUi.small_button(btn_text)
	btn.custom_minimum_size = Vector2(150, 26)
	if is_active:
		GameUi.set_active(btn, true)
	var sid: int = int(item.get("state_id", 0))
	btn.pressed.connect(func() -> void:
		GmManager.set_player_aura(_selected_player, sid)
		_show_toast("Đã gắn %s cho %s!" % [item.get("name"), _selected_player.get("name", "mục tiêu")])
		_render_tab()
	)
	vb.add_child(btn)

	card.add_child(vb)
	return card
