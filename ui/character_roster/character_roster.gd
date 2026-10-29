extends Control
class_name CharacterRosterScreen
## Màn "Chọn nhân vật" trong kho của tài khoản (sau Chọn Máy Chủ). Bố cục theo mockup 1672x941: tối đa 4 ô nhân vật — thẻ thông tin
## phía trên ([cấp]Tên / tên map / cấp - môn phái) và nhân vật đứng bên dưới — cùng thanh 4 nút: VÀO GAME, TẠO NHÂN VẬT, HỦY BỎ, THOÁT GAME.
##
## Hình nhân vật + vòng hào quang LẤY Y NGUYÊN từ màn Tạo Nhân Vật (CharacterCreate.tscn): cùng sheet theo HỆ (từ môn phái) + giới tính,
## cùng độ dời/độ phóng đã chỉnh riêng từng nhân vật, cùng vòng aura — chỉ thu nhỏ theo hệ số CHAR_SCALE.
## Đã đăng nhập: nhân vật lấy từ server theo tài khoản + máy chủ đã chọn (tối đa 4 ô); "Tạo nhân vật" tạo vào ô trống đầu tiên.
## Chưa đăng nhập (chạy thẳng scene để test): chỉ có ô 1 từ file lưu trên máy như cũ.

const CREATE_SCENE := "res://ui/character_create/CharacterCreate.tscn"
const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const BACK_SCENE := "res://ui/server_select/ServerSelect.tscn"
const CHARS_DIR := "res://ui/character_create/chars/"
const MINIMAP_META := "res://world/minimap/minimap.json"
const SLOT_COUNT := 4
const SLOT_CARD_X := [140.0, 510.0, 878.0, 1252.0]    ## mép trái thẻ thông tin (toạ độ mockup)
const SLOT_FEET_X := [290.0, 645.0, 1050.0, 1422.0]   ## giữa chân nhân vật
const FEET_Y := 700.0
const CARD_SIZE := Vector2(285, 100)
const CHAR_SCALE := 0.68          ## thu nhỏ so với khung ở màn Tạo Nhân Vật
const FADE := 0.35
const GOLD := Color(0.95, 0.8, 0.4)
const ELEMENT_KEY := {
	ElementTypes.ElementType.KIM: "kim", ElementTypes.ElementType.MOC: "moc", ElementTypes.ElementType.THUY: "thuy",
	ElementTypes.ElementType.HOA: "hoa", ElementTypes.ElementType.THO: "tho",
}

@onready var _stage: Control = %Stage
@onready var _message: Label = %Message
@onready var _enter_btn: BaseButton = %EnterArea
@onready var _create_btn: BaseButton = %CreateArea
@onready var _cancel_btn: BaseButton = %CancelArea
@onready var _quit_btn: BaseButton = %QuitArea

var _slots: Array = []            ## [{profile, card, portrait, aura} | {}] theo ô
var _selected := 0
var _tween: Tween
var _create_ref: Node             ## bản dựng (không vào cây) của CharacterCreate để đọc chỉnh sửa từng nhân vật

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_locale_texts()

func _ready() -> void:
	MusicManager.play_title_music()
	_create_ref = load(CREATE_SCENE).instantiate()
	_enter_btn.pressed.connect(_on_enter_pressed)
	_create_btn.pressed.connect(_on_create_pressed)
	_cancel_btn.pressed.connect(_go.bind(BACK_SCENE))
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	for b: BaseButton in [_enter_btn, _create_btn, _cancel_btn, _quit_btn]:
		_style_pill_button(b)
	_update_locale_texts()
	if LocalizationManager.has_signal("locale_changed"):
		LocalizationManager.locale_changed.connect(func(_l: String) -> void: _update_locale_texts())
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)
	if AccountApi.is_logged_in():
		if AccountApi.has_signal("session_invalidated"):
			AccountApi.session_invalidated.connect(func(reason: String) -> void:
				AccountScreen.next_login_message = reason if reason != "" else "Tài khoản vừa đăng nhập ở thiết bị khác"
				get_tree().change_scene_to_file.call_deferred(AccountScreen.LOGIN_SCENE)
			)
		await _build_slots_online()
	else:
		_build_slots()
	var first := 0
	for i in _slots.size():
		if (_slots[i] as Dictionary).has("profile"):
			first = i
			break
	_select(first)
	_update_locale_texts()
	if "--test-capture-roster" in OS.get_cmdline_args():
		_capture_roster_and_quit()

func _update_locale_texts() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_enter_btn):
		var lbl: Label = _enter_btn.get_node_or_null("Label")
		if lbl:
			lbl.text = tr("VÀO GAME")
	if is_instance_valid(_create_btn):
		var lbl: Label = _create_btn.get_node_or_null("Label")
		if lbl:
			lbl.text = tr("TẠO NHÂN VẬT")
	if is_instance_valid(_cancel_btn):
		var lbl: Label = _cancel_btn.get_node_or_null("Label")
		if lbl:
			lbl.text = tr("QUAY LẠI")
	if is_instance_valid(_quit_btn):
		var lbl: Label = _quit_btn.get_node_or_null("Label")
		if lbl:
			lbl.text = tr("THOÁT GAME")
	for slot in _slots:
		if slot is Dictionary and slot.has("card"):
			var card: Button = slot["card"]
			if is_instance_valid(card):
				var lbl: Label = card.get_node_or_null("TitleLabel")
				if lbl and card.get_meta("is_empty", false):
					lbl.text = tr("Ô trống")

func _capture_roster_and_quit() -> void:
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/559e8e6c-9764-4a53-b7ce-0cbbb23fca67/roster_test.png")
		print("ROSTER_CAPTURE_SUCCESS")
	get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(_create_ref):
		_create_ref.free()

## Hiệu ứng hover và nhấn cho nút ngọc viền kim loại
func _style_pill_button(b: BaseButton) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var lbl: Label = b.get_node_or_null("Label")
	b.mouse_entered.connect(func() -> void:
		b.modulate = Color(1.18, 1.18, 1.05)
		if lbl:
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.88))
	)
	b.mouse_exited.connect(func() -> void:
		b.modulate = Color(1.0, 1.0, 1.0)
		if lbl:
			lbl.remove_theme_color_override("font_color")
	)
	b.button_down.connect(func() -> void:
		b.modulate = Color(0.85, 0.85, 0.8)
	)
	b.button_up.connect(func() -> void:
		b.modulate = Color(1.18, 1.18, 1.05) if b.is_hovered() else Color(1.0, 1.0, 1.0)
	)

# ---------------------------------------------------------------- các ô nhân vật

func _build_slots() -> void:
	var profile: PlayerProfile = GameManager.local_profile
	if profile == null and SaveManager.has_profile():
		profile = SaveManager.load_profile()
		GameManager.local_profile = profile
	if profile == null:
		profile = PlayerProfile.new()
		profile.display_name = "cô Đơn"
		profile.level = 10
		profile.gender = PlayerProfile.Gender.MALE
		profile.sect_id = "hoa_son"
	for i in SLOT_COUNT:
		var slot := {}
		if i == 0 and profile != null:
			slot = _make_character_slot(i, profile)
		else:
			slot = {"card": _make_card(i, null)}
		_slots.append(slot)

## Nhân vật trên server: mỗi ô = {profile, character (bản ghi server: id, version...), card, portrait, aura}.
func _build_slots_online() -> void:
	GameManager.local_profile = null
	SaveManager.clear_online_character()
	_toast("Đang tải nhân vật…")
	var r: Dictionary = await AccountApi.characters(ServerSelectScreen.selected_server_id)
	var by_slot := {}
	if r.ok:
		_message.modulate.a = 0.0
		for c in r.data.get("characters", []):
			by_slot[int(c.get("slot", 0))] = c
	elif r.code in ["unauthorized", "banned", "logged_in_elsewhere"]:
		AccountScreen.next_login_message = r.message
		get_tree().change_scene_to_file.call_deferred(AccountScreen.LOGIN_SCENE)
		return
	else:
		_toast(r.message)
	for i in SLOT_COUNT:
		var slot := {}
		if by_slot.has(i) and by_slot[i].get("data") is Dictionary:
			var c: Dictionary = by_slot[i]
			slot = _make_character_slot(i, PlayerProfile.from_dict(c["data"]))
			slot["character"] = c
		else:
			slot = {"card": _make_card(i, null)}
		_slots.append(slot)

func _on_create_pressed() -> void:
	if not AccountApi.is_logged_in():
		_go(CREATE_SCENE)
		return
	for i in _slots.size():
		if not (_slots[i] as Dictionary).has("profile"):
			CharacterCreateScreen.target_slot = i
			_go(CREATE_SCENE)
			return
	_toast(tr("Đã đủ %d nhân vật trên máy chủ này") % SLOT_COUNT)

func _map_name() -> String:
	if FileAccess.file_exists(MINIMAP_META):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(MINIMAP_META))
		if meta is Dictionary and str(meta.get("title", "")) != "":
			return str(meta["title"])
	return "Ba Lăng Huyện"

func _make_character_slot(i: int, profile: PlayerProfile) -> Dictionary:
	var slot := {"profile": profile}
	slot["card"] = _make_card(i, profile)
	var element: ElementTypes.ElementType = profile.get_element()
	var gender_key := "nu" if profile.gender == PlayerProfile.Gender.FEMALE else "nam"
	var key := "%s_%s" % [ELEMENT_KEY[element], gender_key]
	var meta := _chars_meta()
	var path := "%s%s.png" % [CHARS_DIR, key]
	if not meta.has(key) or not ResourceLoader.exists(path):
		return slot   ## hệ này chưa có sheet cho giới tính đó (ví dụ Kim-nữ) -> chỉ có thẻ
	## Cùng tham số với màn Tạo Nhân Vật: lấy khung/độ dời/độ phóng từ node tương ứng của bản dựng CharacterCreate.
	var ref_name := "FemalePortrait" if gender_key == "nu" else "MalePortrait"
	var ref: AnimatedPortrait = _create_ref.get_node("Stage/" + ref_name)
	var ref_aura: AuraRing = _create_ref.get_node("Stage/" + ("FemaleAura" if gender_key == "nu" else "MaleAura"))
	var portrait := AnimatedPortrait.new()
	portrait.size = ref.size
	portrait.offsets = ref.offsets.duplicate()
	portrait.scales = ref.scales.duplicate()
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.setup(load(path), meta[key], key)
	portrait.scale = Vector2.ONE * CHAR_SCALE
	## Điểm chân thực tế trong toạ độ local của portrait (đã tính offset riêng của từng nhân vật)
	var char_offset: Vector2 = portrait.offsets.get(key, Vector2.ZERO)
	var foot_local: Vector2 = Vector2(ref.size.x * 0.5, ref.size.y) + char_offset
	portrait.pivot_offset = foot_local
	portrait.position = Vector2(SLOT_FEET_X[i], FEET_Y) - foot_local
	portrait.pressed.connect(_select.bind(i))
	## Vòng hào quang: đặt tâm chính xác tại chân nhân vật (SLOT_FEET_X[i], FEET_Y), đồng trục và vừa vặn
	var aura := AuraRing.new()
	aura.size = ref_aura.size
	aura.aura_name = ref_aura.aura_name
	aura.tilt = ref_aura.tilt
	aura.fps = ref_aura.fps
	aura.scale = Vector2.ONE * CHAR_SCALE
	aura.pivot_offset = aura.size * 0.5
	aura.position = Vector2(SLOT_FEET_X[i], FEET_Y) - aura.size * 0.5
	_stage.add_child(aura)
	_stage.add_child(portrait)
	slot["portrait"] = portrait
	slot["aura"] = aura
	return slot

func _chars_meta() -> Dictionary:
	var f := FileAccess.open(CHARS_DIR + "chars.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

## Nhãn hiển thị Level và Tên nhân vật (đặt sát phía trên đầu nhân vật, chữ to và đậm nét).
func _make_card(i: int, profile: PlayerProfile) -> Button:
	var card := Button.new()
	var width := 340.0
	var height := 48.0
	card.position = Vector2(SLOT_FEET_X[i] - width * 0.5, 130.0)
	card.size = Vector2(width, height)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.flat = true
	var empty_sb := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, empty_sb)
	card.pressed.connect(_select.bind(i))
	card.set_meta("is_empty", profile == null)

	var lbl := Label.new()
	lbl.name = "TitleLabel"
	lbl.size = card.size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if profile == null:
		lbl.text = tr("Ô trống")
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55, 0.65))
		lbl.add_theme_constant_override("outline_size", 5)
	else:
		lbl.text = "[%d] %s" % [profile.level, profile.display_name]
		lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))

	card.add_child(lbl)
	_stage.add_child(card)
	return card

func _style_card(card: Button, selected: bool) -> void:
	var lbl: Label = card.get_node_or_null("TitleLabel")
	if lbl == null:
		return
	var is_empty: bool = card.get_meta("is_empty", false)
	if is_empty:
		lbl.text = tr("Ô trống")
		lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.72) if selected else Color(0.55, 0.52, 0.45, 0.6))
		lbl.add_theme_constant_override("outline_size", 6 if selected else 4)
	else:
		if selected:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
			lbl.add_theme_constant_override("outline_size", 8)
		else:
			lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
			lbl.add_theme_constant_override("outline_size", 6)

func _select(i: int) -> void:
	_selected = i
	for k in _slots.size():
		var slot: Dictionary = _slots[k]
		_style_card(slot["card"], k == i)
		if slot.has("portrait"):
			var on := k == i
			var p: AnimatedPortrait = slot["portrait"]
			p.set_playing(on)
			create_tween().tween_property(p, "modulate", Color.WHITE if on else Color(0.62, 0.62, 0.66), 0.2)
			(slot["aura"] as Control).visible = on

# ---------------------------------------------------------------- nút

func _on_enter_pressed() -> void:
	if _selected < 0 or _selected >= _slots.size():
		_toast("Vui lòng chọn nhân vật")
		return
	var slot: Dictionary = _slots[_selected]
	if not slot.has("profile"):
		_toast("Ô này chưa có nhân vật — bấm \"Tạo nhân vật\"")
		return

	# Kiểm tra xác thực phiên trước khi vào Hub
	if AccountApi.is_logged_in() and AccountApi.has_method("check_session"):
		var chk: Dictionary = await AccountApi.check_session()
		if not is_inside_tree():
			return
		if not chk.ok:
			AccountScreen.next_login_message = chk.message if chk.message != "" else "Tài khoản vừa đăng nhập ở thiết bị khác"
			get_tree().change_scene_to_file.call_deferred(AccountScreen.LOGIN_SCENE)
			return

	GameManager.local_profile = slot["profile"]
	if slot.has("character"):
		var c: Dictionary = slot["character"]
		SaveManager.set_online_character(int(c["id"]), int(c["version"]))
	## "Vào game" = vào Character Hub trước; từ Hub bấm "Chơi" mới vào map chính.
	_go(HUB_SCENE)

func _go(path: String) -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(get_tree().change_scene_to_file.bind(path))

func _toast(text: String) -> void:
	_message.text = tr(text)
	_message.modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(1.8)
	_tween.tween_property(_message, "modulate:a", 0.0, 0.4)
