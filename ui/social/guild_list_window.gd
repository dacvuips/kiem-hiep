extends SocialWindow
class_name GuildListWindow
## "Xem tin Bang khác": bảng các bang hội đang có (tên, bang chủ, phe, nhân số, khuynh hướng, lời chào) và cờ chiêu mộ 🚩.
## Bang nào cắm cờ tuyển người thì hiển thị lá cờ 🚩 và cho phép xin vào; không có cờ thì không thể xin vào.
## Cũng dùng làm nội dung của màn Bang hội khi nhân vật CHƯA có bang (GuildListWindow.fill).

static func open(host: Node, hub: SocialHub) -> GuildListWindow:
	var win := GuildListWindow.new(hub)
	return SocialWindow.present(host, win, &"guild_list") as GuildListWindow

func _init(hub: SocialHub = null) -> void:
	super._init("Các Bang Hội", "Tin chiêu mộ của các bang hội trên giang hồ", 680.0)
	if hub == null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	body.add_child(box)
	GuildListWindow.fill(box, hub, null, true)
	var close := SocialUi.stone_button("Đóng")
	close.pressed.connect(func() -> void: close_requested.emit())
	body.add_child(close)

## Đổ bảng các bang vào `into`. `host` = nơi mở hộp phụ (null → cảnh hiện tại).
static func fill(into: Control, hub: SocialHub, host: Node, show_requirements: bool) -> void:
	var profile := hub.profile
	var guild := hub.guild
	if show_requirements:
		var c: Dictionary = SocialRules.tong()["create"]
		var req := SocialUi.info_box("✦ Điều kiện lập bang hội")
		for line in [
			"Cấp ≥ %d, cấp lãnh đạo ≥ %d" % [int(c["level"]), int(c["lead_level"])],
			"%s lượng, danh vọng ≥ %d, phúc duyên ≥ %d" % [InventoryPopup.format_money(int(c["money"])), int(c["repute"]), int(c["fuyuan"])],
			"Không trong tổ đội, không bày bán/mở giao dịch"
		]:
			req[1].add_child(SocialUi.label("•  " + line, SocialUi.TEXT, 13))
		var blockers := guild.create_blockers(hub.team)
		var b_lbl := SocialUi.label("✔ Bạn đủ điều kiện — bấm [Tạo mới]." if blockers.is_empty() else "Chưa đạt: " + "; ".join(blockers), SocialUi.LABEL_GREEN if blockers.is_empty() else SocialUi.LABEL_RED, 12)
		b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		req[1].add_child(b_lbl)
		into.add_child(req[0])

	var wait := guild.join_cooldown_left()
	var sec := SocialUi.info_box("📜 Danh Sách Bang Hội")
	if wait > 0:
		sec[1].add_child(SocialUi.label("Mới rời bang — còn %d giờ nữa mới xin vào bang khác được." % int(ceil(wait / 3600.0)), SocialUi.WARN, 13))

	## Thanh công cụ lọc & làm mới danh sách
	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 10)
	var filter_recruit := CheckBox.new()
	filter_recruit.text = "🚩 Chỉ hiện bang đang cắm cờ tuyển người"
	filter_recruit.add_theme_color_override("font_color", SocialUi.TEXT)
	filter_bar.add_child(filter_recruit)

	var refresh_btn := SocialUi.small_button("🔄 Làm mới")
	filter_bar.add_child(refresh_btn)
	sec[1].add_child(filter_bar)

	var list_container := VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 8)
	sec[1].add_child(list_container)

	## Render hàm nội bộ
	var render_list := func() -> void:
		for ch in list_container.get_children():
			ch.queue_free()

		var only_recruiting: bool = filter_recruit.button_pressed
		var count := 0

		if NetClient.is_in_world() and NetSocial.current != null:
			var list: Array = NetSocial.current.guild_list
			if list.is_empty():
				list_container.add_child(SocialUi.label("Chưa có bang hội nào trên máy chủ (hoặc đang tải dữ liệu).", SocialUi.MUTED, 13))
				return
			for g in list:
				var is_recruiting := bool(g.get("recruit", false))
				if only_recruiting and not is_recruiting:
					continue
				count += 1
				_build_guild_entry(list_container, g, is_recruiting, wait, guild, hub)
			if count == 0 and only_recruiting:
				list_container.add_child(SocialUi.label("Hiện không có bang hội nào đang cắm cờ tuyển người.", SocialUi.MUTED, 13))
			return

		## Offline / Người chơi giả
		for m in SocialDirectory.players(profile):
			if m.guild_figure != GuildRules.Figure.MASTER or m.guild_name == "":
				continue
			var snap := SocialDirectory.guild_snapshot(profile, m.guild_name)
			var is_recruiting := bool(m.recruit)
			if only_recruiting and not is_recruiting:
				continue
			count += 1
			var g_data := {
				"name": m.guild_name,
				"camp": m.camp,
				"master": m.name,
				"members": snap.get("members", []).size(),
				"cap": SocialRules.tong_member_cap(int(snap.get("level", 1))),
				"level": int(snap.get("level", 1)),
				"recruit": is_recruiting,
				"tendency": snap.get("tendency", "—"),
				"activity": snap.get("activity", "—"),
				"recruit_msg": snap.get("recruit_msg", ""),
				"accept_level": int(snap.get("accept_level", 0)),
				"_mock": m
			}
			_build_guild_entry(list_container, g_data, is_recruiting, wait, guild, hub)

		if count == 0 and only_recruiting:
			list_container.add_child(SocialUi.label("Hiện không có bang hội nào đang cắm cờ tuyển người.", SocialUi.MUTED, 13))

	filter_recruit.toggled.connect(func(_v: bool) -> void: render_list.call())
	refresh_btn.pressed.connect(func() -> void:
		if NetClient.is_in_world():
			NetClient.send_guild(GuildServer.G_LIST)
		render_list.call())

	## Tự động cập nhật khi server gửi gói S_GUILD_LIST mới
	if NetSocial.current != null:
		var cb := func(_l: Array) -> void:
			if list_container.is_inside_tree():
				render_list.call()
		NetSocial.current.guild_list_updated.connect(cb)
		list_container.tree_exited.connect(func() -> void:
			if NetSocial.current != null and NetSocial.current.guild_list_updated.is_connected(cb):
				NetSocial.current.guild_list_updated.disconnect(cb)
		)
		if NetClient.is_in_world():
			NetClient.send_guild(GuildServer.G_LIST)

	render_list.call()
	into.add_child(sec[0])

static func _build_guild_entry(parent: Control, g: Dictionary, is_recruiting: bool, wait: int, guild: GuildService, hub: SocialHub) -> void:
	var item_box := VBoxContainer.new()
	item_box.add_theme_constant_override("separation", 3)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)

	## 1. Cờ chiêu mộ: có cờ 🚩 nếu đang đăng tuyển, ⚐ nếu chưa cắm cờ
	if is_recruiting:
		var flag_badge := SocialUi.label("🚩 [ĐANG TUYỂN]", SocialUi.GOLD, 13)
		flag_badge.tooltip_text = "Bang hội đang cắm cờ chiêu mộ thành viên"
		head.add_child(flag_badge)
	else:
		var flag_badge := SocialUi.label("⚐ [CHƯA MỞ]", SocialUi.MUTED, 13)
		flag_badge.tooltip_text = "Bang hội này chưa cắm cờ tuyển người"
		head.add_child(flag_badge)

	## 2. Tên bang hội
	var name_l := SocialUi.label(str(g.get("name", "")), Camp.get_color(int(g.get("camp", 0))), 15)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)

	## 3. Số thành viên hiển thị rõ ràng: [members] / [cap] người
	var mem_count := int(g.get("members", 0))
	var mem_cap := int(g.get("cap", 40))
	var members_l := SocialUi.label("👥 %d/%d thành viên" % [mem_count, mem_cap], SocialUi.LABEL_GREEN if is_recruiting else SocialUi.MUTED, 13)
	head.add_child(members_l)

	## 4. Nút Xin vào: CÓ CỜ MỚI CHO XIN VÀO, KHÔNG CỜ BỊ VÔ HIỆU HÓA
	var b: Button
	if is_recruiting:
		b = SocialUi.small_button("Xin vào")
		b.disabled = wait > 0 or guild.in_guild()
		if wait > 0:
			b.tooltip_text = "Mới rời bang — vui lòng chờ hết thời gian phạt"
		elif guild.in_guild():
			b.tooltip_text = "Bạn đã có bang hội, không thể xin vào bang khác"
		else:
			b.tooltip_text = "Gửi đơn xin gia nhập bang hội này"

		var target_mock: MockPlayer = g.get("_mock", null)
		if target_mock == null:
			target_mock = MockPlayer.new()
			target_mock.guild_name = str(g.get("name", ""))
		b.pressed.connect(func() -> void:
			guild.apply_join(target_mock, hub.team)
			b.disabled = true
			b.text = "Đã xin"
		)
	else:
		b = SocialUi.small_button("Chưa mở")
		b.disabled = true
		b.tooltip_text = "Bang hội này chưa cắm cờ tuyển người — không thể xin gia nhập."

	head.add_child(b)
	item_box.add_child(head)

	## 5. Dòng thông tin phụ (Bang chủ, Cấp bang, Phe, Yêu cầu cấp, Lời nhắn)
	var sub_info := "Bang chủ: %s · %s · Cấp %d" % [
		g.get("master", "—"),
		Camp.get_camp_name(int(g.get("camp", 0))),
		int(g.get("level", 1))
	]
	var acc_lvl := int(g.get("accept_level", 0))
	if acc_lvl > 0:
		sub_info += " · Cấp ≥ %d tự duyệt" % acc_lvl
	var sub_l := SocialUi.label("   " + sub_info, SocialUi.SUBTITLE, 12)
	item_box.add_child(sub_l)

	var extra_info := "Khuynh hướng: %s · Hoạt động: %s" % [g.get("tendency", "—"), g.get("activity", "—")]
	var msg := str(g.get("recruit_msg", "")).strip_edges()
	if msg != "":
		extra_info += " — \"%s\"" % msg
	var extra_l := SocialUi.label("   " + extra_info, SocialUi.TEXT, 12)
	extra_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_box.add_child(extra_l)

	parent.add_child(item_box)
