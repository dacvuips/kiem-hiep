extends SocialWindow
class_name GuildListWindow
## "Xem tin Bang khác": bảng các bang hội đang có (tên, bang chủ, phe, nhân số, khuynh hướng, lời chào) và nút [Xin vào]. Cũng dùng làm nội dung
## của màn Bang hội khi nhân vật CHƯA có bang (GuildListWindow.fill).

static func open(host: Node, hub: SocialHub) -> GuildListWindow:
	var win := GuildListWindow.new(hub)
	return SocialWindow.present(host, win, &"guild_list") as GuildListWindow

func _init(hub: SocialHub = null) -> void:
	super._init("Các Bang Hội", "Tin chiêu mộ của các bang hội quanh đây", 640.0)
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
		for line in ["Cấp ≥ %d, cấp lãnh đạo ≥ %d" % [int(c["level"]), int(c["lead_level"])], "%s lượng, danh vọng ≥ %d, phúc duyên ≥ %d" % [InventoryPopup.format_money(int(c["money"])), int(c["repute"]), int(c["fuyuan"])], "Không trong tổ đội, không bày bán/mở giao dịch"]:
			req[1].add_child(SocialUi.label("•  " + line, SocialUi.TEXT, 13))
		var blockers := guild.create_blockers(hub.team)
		req[1].add_child(SocialUi.label("✔ Bạn đủ điều kiện — bấm [Tạo mới]." if blockers.is_empty() else "Chưa đạt: " + "; ".join(blockers), SocialUi.LABEL_GREEN if blockers.is_empty() else SocialUi.LABEL_RED, 12))
		into.add_child(req[0])
	var wait := guild.join_cooldown_left()
	var sec := SocialUi.info_box("📜 Bang hội đang tuyển người")
	if wait > 0:
		sec[1].add_child(SocialUi.label("Mới rời bang — còn %d giờ nữa mới xin vào bang khác được." % int(ceil(wait / 3600.0)), SocialUi.WARN, 13))
	if NetClient.is_in_world() and NetWorldSync.current != null:
		## Online: danh sách bang thật từ server (S_GUILD_LIST).
		var list: Array = NetWorldSync.current.guild_list
		if list.is_empty():
			sec[1].add_child(SocialUi.label("Chưa có bang hội nào trên máy chủ (hoặc đang tải).", SocialUi.MUTED, 13))
		for g in list:
			var head := HBoxContainer.new()
			head.add_theme_constant_override("separation", 8)
			var name_l := SocialUi.label(str(g.name), Camp.get_color(int(g.camp)), 15)
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(name_l)
			head.add_child(SocialUi.label("Bang chủ %s · %s · %d/%d người" % [g.master, Camp.get_camp_name(int(g.camp)), int(g.members), int(g.cap)], SocialUi.SUBTITLE, 12))
			var b := SocialUi.small_button("Xin vào")
			b.disabled = wait > 0 or guild.in_guild() or not bool(g.recruit)
			var mock := MockPlayer.new()
			mock.guild_name = str(g.name)
			b.pressed.connect(func() -> void: guild.apply_join(mock, hub.team))
			head.add_child(b)
			sec[1].add_child(head)
			sec[1].add_child(SocialUi.label("   Khuynh hướng: %s · Hoạt động: %s — %s" % [g.get("tendency", "—"), g.get("activity", "—"), g.get("recruit_msg", "")], SocialUi.TEXT, 12))
		into.add_child(sec[0])
		return
	for m in SocialDirectory.players(profile):
		if m.guild_figure != GuildRules.Figure.MASTER or m.guild_name == "":
			continue
		var snap := SocialDirectory.guild_snapshot(profile, m.guild_name)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var name_l := SocialUi.label(m.guild_name, Camp.get_color(m.camp), 15)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		head.add_child(SocialUi.label("Bang chủ %s · %s · %d/%d người" % [m.name, Camp.get_camp_name(m.camp), snap.get("members", []).size(), SocialRules.tong_member_cap(int(snap.get("level", 1)))], SocialUi.SUBTITLE, 12))
		var b := SocialUi.small_button("Xin vào")
		b.disabled = wait > 0 or guild.in_guild() or not m.recruit
		b.pressed.connect(func() -> void: guild.apply_join(m, hub.team))
		head.add_child(b)
		sec[1].add_child(head)
		sec[1].add_child(SocialUi.label("   Khuynh hướng: %s · Hoạt động: %s — %s" % [snap.get("tendency", "—"), snap.get("activity", "—"), snap.get("recruit_msg", "")], SocialUi.TEXT, 12))
	into.add_child(sec[0])
