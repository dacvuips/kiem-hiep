extends SocialWindow
class_name ThienTamThapLeaderboardWindow

## BẢNG XẾP HẠNG THIÊN TẦM THÁP
## Xếp hạng người chơi vượt qua nhiều ải nhất giang hồ trong Thiên Tầm Tháp.
## Hiển thị Hạng, Tên Đại Hiệp, Môn Phái, Cấp Độ và Số Ải Đã Vượt (sắp xếp giảm dần).

const RANK_COLORS := [
	Color(1.0, 0.84, 0.3),  # Hạng 1: Vàng kim
	Color(0.85, 0.87, 0.9), # Hạng 2: Bạch kim
	Color(0.85, 0.6, 0.35)  # Hạng 3: Đồng thau
]

var _profile: PlayerProfile

static func open(host: Node, profile: PlayerProfile) -> ThienTamThapLeaderboardWindow:
	var win := ThienTamThapLeaderboardWindow.new(profile)
	return SocialWindow.present(host, win, &"thien_tam_thap_leaderboard") as ThienTamThapLeaderboardWindow

func _init(profile: PlayerProfile = null) -> void:
	super._init("Bảng Xếp Hạng Thiên Tầm Tháp", "", 560.0)
	_profile = profile
	_build_ui()

func _build_ui() -> void:
	var chal_script: GDScript = load("res://systems/challenge/thien_tam_thap_challenge.gd")
	var list: Array[Dictionary] = []
	if chal_script != null and chal_script.has_method("get_leaderboard"):
		list = chal_script.get_leaderboard(_profile)

	var sub := SocialUi.label(tr("Vinh danh những cao thủ vượt ải Thiên Tầm Tháp cao nhất toàn máy chủ"), SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(sub)
	body.add_child(SocialUi.divider())

	# Bảng dữ liệu
	var sec := SocialUi.info_box(tr("Bảng Phong Vân Thiên Tầm Tháp"))
	var panel: Control = sec[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)

	# Tiêu đề các cột
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	sec[1].add_child(head_row)

	var h_rank := SocialUi.label(tr("Hạng"), SocialUi.GOLD, 13, HORIZONTAL_ALIGNMENT_CENTER)
	h_rank.custom_minimum_size.x = 45
	head_row.add_child(h_rank)

	var h_name := SocialUi.label(tr("Đại Hiệp"), SocialUi.GOLD, 13)
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(h_name)

	var h_sect := SocialUi.label(tr("Môn Phái"), SocialUi.GOLD, 13)
	h_sect.custom_minimum_size.x = 120
	head_row.add_child(h_sect)

	var h_lvl := SocialUi.label(tr("Đẳng Cấp"), SocialUi.GOLD, 13, HORIZONTAL_ALIGNMENT_CENTER)
	h_lvl.custom_minimum_size.x = 70
	head_row.add_child(h_lvl)

	var h_stage := SocialUi.label(tr("Ải Đã Vượt"), SocialUi.GOLD, 13, HORIZONTAL_ALIGNMENT_RIGHT)
	h_stage.custom_minimum_size.x = 110
	head_row.add_child(h_stage)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.3)
	sec[1].add_child(sep)

	# Danh sách cuộn
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 360.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sec[1].add_child(scroll)
	TouchScrollHelperScript.attach(scroll, panel)

	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 6)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)

	var me := _profile.display_name if _profile else ""
	var my_rank_str := "—"
	var my_stage_val := 0

	for e in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var is_me: bool = bool(e.get("is_me", false)) or str(e["name"]) == me
		var rank: int = int(e["rank"])
		if is_me:
			my_rank_str = "#%d" % rank
			my_stage_val = int(e.get("best_stage", 0))

		# Cột 1: Hạng
		var rank_text := "%d" % rank
		if rank == 1:
			rank_text = "🥇 1"
		elif rank == 2:
			rank_text = "🥈 2"
		elif rank == 3:
			rank_text = "🥉 3"

		var rank_color: Color = RANK_COLORS[rank - 1] if rank <= RANK_COLORS.size() else SocialUi.SUBTITLE
		var rank_l := SocialUi.label(rank_text, rank_color, 14, HORIZONTAL_ALIGNMENT_CENTER)
		rank_l.custom_minimum_size.x = 45
		row.add_child(rank_l)

		# Cột 2: Tên nhân vật
		var name_str := str(e["name"])
		if is_me:
			name_str += " " + tr("[Bạn]")
		var name_l := SocialUi.label(name_str, Color(1.0, 0.85, 0.3) if is_me else SocialUi.TEXT, 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		row.add_child(name_l)

		# Cột 3: Môn phái
		var sect_id: String = str(e.get("sect_id", ""))
		var sect_name := _sect_name(sect_id)
		var sect_l := SocialUi.label(sect_name, SocialUi.SUBTITLE, 13)
		sect_l.custom_minimum_size.x = 120
		row.add_child(sect_l)

		# Cột 4: Đẳng cấp
		var lvl_l := SocialUi.label(tr("Cấp %d") % int(e["level"]), SocialUi.LABEL_BLUE, 13, HORIZONTAL_ALIGNMENT_CENTER)
		lvl_l.custom_minimum_size.x = 70
		row.add_child(lvl_l)

		# Cột 5: Số ải đã vượt
		var stage_text := tr("Vượt %d ải") % int(e.get("best_stage", 0))
		var stage_l := SocialUi.label(stage_text, Color(1.0, 0.88, 0.25), 14, HORIZONTAL_ALIGNMENT_RIGHT)
		stage_l.custom_minimum_size.x = 110
		row.add_child(stage_l)

		rows_box.add_child(row)

	body.add_child(SocialUi.divider())

	# Chân bảng: Vị trí của bạn & Nút Đóng
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 16)
	foot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(foot_row)

	var my_stat_lbl := SocialUi.label(
		tr("Vị trí của bạn: %s   ·   Kỷ lục cá nhân: %s") % [
			my_rank_str,
			tr("Vượt %d ải") % my_stage_val if my_stage_val > 0 else tr("Chưa tham gia")
		],
		SocialUi.GOLD, 14
	)
	my_stat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_row.add_child(my_stat_lbl)

	var close_btn := SocialUi.stone_button(tr("Đóng"), Vector2(100, 36))
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	foot_row.add_child(close_btn)

static func _sect_name(id: String) -> String:
	if id == "":
		return TranslationServer.translate("Vô môn phái")
	var sect := SectRegistry.get_by_id(id)
	return TranslationServer.translate(sect.sect_name) if sect else id
