extends RefCounted
class_name RepairActions
## SỬA TRANG BỊ — Thợ rèn gốc (KPlayer::RepairItem + thoren.lua "Sửa trang bị hư tổn"):
##   - Nút "Sửa" trong hành trang = chế độ sửa (GOI_TRADE_NPC_REPAIR gốc: con trỏ búa, bấm món nào sửa món đó).
##   - Nút "Sửa (x lượng)" trong popup chi tiết món.
## Offline: sửa thẳng trên hồ sơ. Online: gửi C_REPAIR, server sửa trên hồ sơ của nó rồi trả S_NOTICE + S_PROFILE.

## Danh sách [nhãn, Callable] để nối vào actions của ItemDetailPopup. `on_done` gọi sau khi sửa offline (làm mới giao diện).
static func for_item(profile: PlayerProfile, item: ItemInstance, on_done: Callable = Callable(), show: Callable = Callable()) -> Array:
	var out := []
	if profile == null or item == null or item.is_misc():
		return out
	if ItemDurability.can_repair(item):
		var price := ItemDurability.repair_price(item)
		out.append(["Sửa (%d lượng)" % price, func() -> void: _run(profile, item.ensure_uid(), NetProto.REPAIR_NORMAL, on_done, show)])
		var all_price := ItemDurability.repair_all_price(profile)
		if all_price > price:
			out.append(["Sửa tất cả (%d lượng)" % all_price, func() -> void: _run(profile, "", NetProto.REPAIR_NORMAL, on_done, show)])
	elif ItemDurability.is_broken(item) and not item.is_gold():
		out.append(["Sửa hỏng nặng (50 vạn lượng)", func() -> void:
			_run(profile, item.ensure_uid(), NetProto.REPAIR_BROKEN_GOLD, on_done, show)])
		out.append(["Sửa hỏng nặng (%d xu)" % ItemDurability.BROKEN_REPAIR_XU, func() -> void:
			_run(profile, item.ensure_uid(), NetProto.REPAIR_BROKEN_XU, on_done, show)])
	return out

## Bấm 1 món khi đang ở chế độ Sửa. `show(text, is_error)` = báo trên cửa sổ đang mở.
## Còn độ bền -> sửa ngay (gốc: đủ tiền là gửi lệnh sửa luôn). Đã hỏng hẳn -> hỏi cách trả (50 vạn lượng / xu) vì đắt.
static func click(profile: PlayerProfile, item: ItemInstance, host: Node, on_done: Callable, show: Callable) -> void:
	if profile == null or item == null:
		return
	if not ItemDurability.has_durability(item):
		_say(show, "Vật phẩm này không cần sửa.", true)
	elif ItemDurability.is_broken(item):
		if item.is_gold():
			_say(show, "Tính năng chỉ sửa trang bị xanh!", true)
		else:
			ItemDetailPopup.open(host, "[color=#ff6060]Trang bị đã hư hỏng hoàn toàn. Thợ rèn sửa hỏng nặng:[/color]\n" \
				+ ItemText.build(item, profile, -1, -1, false), for_item(profile, item, on_done, show), item)
	elif ItemDurability.can_repair(item):
		_run(profile, item.ensure_uid(), NetProto.REPAIR_NORMAL, on_done, show)
	else:
		_say(show, "Trang bị này không cần sửa.", true)

## Câu gợi ý khi bật chế độ Sửa (kèm tổng tiền sửa hết).
static func mode_hint(profile: PlayerProfile) -> String:
	var total := ItemDurability.repair_all_price(profile) if profile != null else 0
	var tail := " Sửa hết đồ đang hư tổn: %d lượng." % total if total > 0 else ""
	return "Chế độ Sửa: Nhấp vào trang bị để sửa (Bấm nút Sửa để tắt).%s" % tail

## Nút "Sửa" đặt cạnh nút "Bán" (cùng kiểu, chép từ nút Bán trong cảnh).
static func make_button(sell_btn: Button) -> Button:
	var b := sell_btn.duplicate(0) as Button
	b.unique_name_in_owner = false
	b.name = "RepairButton"
	b.text = "Sửa"
	b.tooltip_text = "Bật/Tắt chế độ sửa: Nhấp vào trang bị để thợ rèn sửa (tốn lượng bạc theo độ bền đã mất)."
	sell_btn.add_sibling(b)
	return b

## Kiểu nút khi đang bật chế độ Sửa (giữ lại kiểu gốc của nút để trả về khi tắt).
static func set_button_active(btn: Button, active: bool) -> void:
	if btn == null:
		return
	if not btn.has_meta("orig_styles"):
		var orig := {}
		for s in ["normal", "hover", "pressed"]:
			orig[s] = btn.get_theme_stylebox(s) if btn.has_theme_stylebox_override(s) else null
		btn.set_meta("orig_styles", orig)
	if active:
		btn.text = "Đang Sửa"
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.12, 0.32, 0.55, 0.95)
		st.border_color = Color(0.45, 0.8, 1.0, 1.0)
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		st.shadow_color = Color(0.2, 0.6, 1.0, 0.6)
		st.shadow_size = 4
		for s in ["normal", "hover", "pressed"]:
			btn.add_theme_stylebox_override(s, st)
		btn.add_theme_color_override("font_color", Color(0.85, 0.97, 1.0))
	else:
		btn.text = "Sửa"
		var orig: Dictionary = btn.get_meta("orig_styles")
		for s in ["normal", "hover", "pressed"]:
			if orig.get(s) != null:
				btn.add_theme_stylebox_override(s, orig[s])
			else:
				btn.remove_theme_stylebox_override(s)
		btn.remove_theme_color_override("font_color")

static func _say(show: Callable, text: String, is_error: bool) -> void:
	if show.is_valid():
		show.call(text, is_error)
	else:
		ChatBox.push_system("[color=%s]%s[/color]" % ["#ff6060" if is_error else "#5cd882", text])

static func _run(profile: PlayerProfile, uid: String, mode: int, on_done: Callable, show: Callable = Callable()) -> void:
	if NetWorldSync.is_online_mode():
		NetClient.send_repair(uid, mode)   ## kết quả về qua S_NOTICE (khung chat) + S_PROFILE (làm mới hành trang)
		return
	var r: Dictionary
	if uid == "" and mode == NetProto.REPAIR_NORMAL:
		r = ItemDurability.repair_all(profile)
	else:
		var item := ItemDurability.find_by_uid(profile, uid)
		if mode == NetProto.REPAIR_NORMAL:
			r = ItemDurability.repair(profile, item)
		else:
			r = ItemDurability.repair_broken(profile, item, mode == NetProto.REPAIR_BROKEN_XU)
	_say(show, str(r["message"]), not r["ok"])
	if r["ok"]:
		if SfxManager != null and VltkSound != null:
			SfxManager.play_ui(VltkSound.ui(VltkSound.UI_ITEM))
		SaveManager.save_profile(profile)
		if on_done.is_valid():
			on_done.call()
