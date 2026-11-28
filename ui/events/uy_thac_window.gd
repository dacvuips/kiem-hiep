extends SocialWindow
class_name UyThacWindow
## Ủy Thác Luyện Công (CHỈ ONLINE): quỹ giờ ủy thác, cửa hàng Bạch Câu Hoàn, báo cáo lần ủy thác gần nhất.
## Không tự tính gì ở máy: mua / dùng gửi lệnh C_UY_THAC, game server làm trên hồ sơ của nó rồi gửi S_PROFILE (cửa sổ tự vẽ lại).

var _profile: PlayerProfile
var _on_quit: Callable
var _content: VBoxContainer

static func open(host: Node, profile: PlayerProfile, on_quit: Callable) -> SocialWindow:
	var win := UyThacWindow.new(profile, on_quit)
	return SocialWindow.present(host, win, &"uy_thac")

static func _online() -> bool:
	return not GameModeManager.is_offline() and NetClient.is_in_world()

func _init(profile: PlayerProfile = null, on_quit: Callable = Callable()) -> void:
	super._init("Ủy Thác Luyện Công", "Thoát game — nhân vật vẫn luyện công", 520.0)
	_profile = profile
	_on_quit = on_quit
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	body.add_child(_content)
	_build()
	NetClient.profile_received.connect(func(_d: Dictionary) -> void: _rebuild.call_deferred())

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if GameManager.local_profile != null:
		_profile = GameManager.local_profile
	for ch in _content.get_children():
		ch.queue_free()
	_build()

func _build() -> void:
	var desc := SocialUi.label("Dùng Bạch Câu Hoàn để có giờ ủy thác. Khi thoát game (từ %d phút), nhân vật tiêu giờ ủy thác để luyện công; "
			% (UyThac.MIN_SECS / 60) + "lần vào lại nhận Kinh Nghiệm, đủ thì tự lên cấp.", SocialUi.MUTED, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(desc)
	if not _online():
		_content.add_child(SocialUi.banner("Ủy thác chỉ có ở chế độ Online.", false))
		_add_close_row(false)
		return

	var sec: Array = SocialUi.section("Quỹ ủy thác")
	_content.add_child(sec[0])
	var box: VBoxContainer = sec[1]
	if _profile != null:
		box.add_child(SocialUi.kv("Giờ ủy thác còn:", UyThac.format_duration(UyThac.bank_secs(_profile)), SocialUi.LABEL_BLUE, SocialUi.GOLD))
		var keys: Array = _profile.uy_thac_bank.keys()
		keys.sort()
		for k in keys:
			box.add_child(SocialUi.kv("   Hệ số x%s:" % k, UyThac.format_duration(int(_profile.uy_thac_bank[k]))))
		if _profile.level >= PlayerProfile.MAX_LEVEL:
			box.add_child(SocialUi.kv("Kinh nghiệm / giờ:", "Đã đạt cấp tối đa", SocialUi.LABEL_BLUE, SocialUi.MUTED))
		else:
			box.add_child(SocialUi.kv("Kinh nghiệm / giờ (x1):", "+%s EXP" % UyThac.format_money(UyThac.exp_per_hour(_profile)),
				SocialUi.LABEL_BLUE, SocialUi.GOLD))

	var shop: Array = SocialUi.section("Bạch Câu Hoàn")
	_content.add_child(shop[0])
	var sbox: VBoxContainer = shop[1]
	for mid in UyThac.ITEMS:
		var def: Dictionary = UyThac.ITEMS[mid]
		var rare := bool(def.get("rare", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		sbox.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ItemDatabase.get_icon(ItemDatabase.get_misc(mid), true)
		if rare:   ## viên quý nhất: ô ảnh nền tím + viền tím phát sáng
			var frame := _rare_frame()
			frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.custom_minimum_size = Vector2(28, 28)   ## + viền/lề 2px mỗi bên = 32, thẳng hàng với các viên khác
			frame.add_child(icon)
			row.add_child(frame)
		else:
			row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_text := str(ItemDatabase.get_misc(mid).get("name", mid))
		info.add_child(SocialUi.label(name_text, SocialUi.TITLE, 14))
		info.add_child(SocialUi.label("%d giờ ủy thác · x%.1f EXP · %s" % [int(def["hours"]), float(def["mult"]), UyThac.price_text(mid)],
			SocialUi.MUTED, 12))
		var buy := SocialUi.small_button("Mua")
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.pressed.connect(func() -> void: NetClient.send_uy_thac("buy", {"mid": mid, "n": 1}))
		row.add_child(buy)
		var have := _find_item(mid)
		var use := SocialUi.small_button("Dùng")
		use.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		use.disabled = have == null
		use.tooltip_text = "Có %d viên" % (have.count if have != null else 0)
		use.pressed.connect(func() -> void:
			var it := _find_item(mid)
			if it != null:
				NetClient.send_uy_thac("use", {"uid": it.uid}))
		row.add_child(use)

	var last: Dictionary = _profile.uy_thac_report if _profile != null else {}
	if not last.is_empty():
		var sec2: Array = SocialUi.section("Lần ủy thác gần nhất")
		_content.add_child(sec2[0])
		var b2: VBoxContainer = sec2[1]
		b2.add_child(SocialUi.kv("Thời gian tính:", UyThac.format_duration(int(last.get("secs", 0)))))
		b2.add_child(SocialUi.kv("Kinh nghiệm:", "+%s EXP" % UyThac.format_money(int(last.get("exp", 0))), SocialUi.LABEL_BLUE, SocialUi.GOLD))
		if int(last.get("to", 0)) > int(last.get("from", 0)):
			b2.add_child(SocialUi.kv("Cấp:", "%d → %d" % [int(last.get("from", 0)), int(last.get("to", 0))], SocialUi.LABEL_BLUE, SocialUi.LABEL_GREEN))
	_add_close_row(true)

const RARE_BORDER := Color(0.72, 0.38, 1.0)

## Ô ảnh viên quý: nền tím, viền tím, quầng sáng tím nhấp nháy nhẹ.
func _rare_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.22, 0.08, 0.34, 0.92)
	st.border_color = RARE_BORDER
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	st.shadow_color = Color(0.7, 0.35, 1.0, 0.55)
	st.shadow_size = 6
	st.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", st)
	var tw := frame.create_tween().set_loops()
	tw.tween_property(st, "shadow_size", 12, 0.9).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(st, "border_color", Color(0.95, 0.75, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(st, "shadow_size", 4, 0.9).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(st, "border_color", RARE_BORDER, 0.9).set_trans(Tween.TRANS_SINE)
	return frame

func _find_item(mid: String) -> ItemInstance:
	if _profile == null:
		return null
	for it in _profile.inventory:
		if it != null and it.misc_id == mid:
			return it
	return null

func _add_close_row(with_quit: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	if with_quit:
		var quit_btn := SocialUi.stone_button("🧘 Ủy Thác & Thoát Game")
		quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quit_btn.disabled = not _on_quit.is_valid() or _profile == null or UyThac.bank_secs(_profile) <= 0
		quit_btn.tooltip_text = "Cần có giờ ủy thác (dùng Bạch Câu Hoàn)"
		quit_btn.pressed.connect(func() -> void:
			close_requested.emit()
			_on_quit.call())
		row.add_child(quit_btn)
	var close_btn := SocialUi.stone_button("Đóng")
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(close_btn)
