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
const CHAR_SCALE := 0.62          ## thu nhỏ so với khung ở màn Tạo Nhân Vật
const FADE := 0.35
const GOLD := Color(0.95, 0.8, 0.4)
const ELEMENT_KEY := {
	ElementTypes.ElementType.KIM: "kim", ElementTypes.ElementType.MOC: "moc", ElementTypes.ElementType.THUY: "thuy",
	ElementTypes.ElementType.HOA: "hoa", ElementTypes.ElementType.THO: "tho",
}

@onready var _stage: Control = %Stage
@onready var _message: Label = %Message
@onready var _enter_btn: Button = %EnterArea
@onready var _create_btn: Button = %CreateArea
@onready var _cancel_btn: Button = %CancelArea
@onready var _quit_btn: Button = %QuitArea

var _slots: Array = []            ## [{profile, card, portrait, aura} | {}] theo ô
var _selected := 0
var _tween: Tween
var _create_ref: Node             ## bản dựng (không vào cây) của CharacterCreate để đọc chỉnh sửa từng nhân vật

func _ready() -> void:
	_create_ref = load(CREATE_SCENE).instantiate()
	_enter_btn.pressed.connect(_on_enter_pressed)
	_create_btn.pressed.connect(_on_create_pressed)
	_cancel_btn.pressed.connect(_go.bind(BACK_SCENE))
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	for b: Button in [_enter_btn, _create_btn, _cancel_btn, _quit_btn]:
		_style_hit_area(b)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)
	if AccountApi.is_logged_in():
		await _build_slots_online()
	else:
		_build_slots()
	var first := 0
	for i in _slots.size():
		if (_slots[i] as Dictionary).has("profile"):
			first = i
			break
	_select(first)

func _exit_tree() -> void:
	if is_instance_valid(_create_ref):
		_create_ref.free()

## Nút trong suốt đặt đè lên vùng chữ của thanh nút; rê chuột thì sáng nhẹ.
func _style_hit_area(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 0.9, 0.55, 0.16)
	hover.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("focus", empty)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# ---------------------------------------------------------------- các ô nhân vật

func _build_slots() -> void:
	var profile: PlayerProfile = GameManager.local_profile
	if profile == null and SaveManager.has_profile():
		profile = SaveManager.load_profile()
		GameManager.local_profile = profile
	var map_name := _map_name()
	for i in SLOT_COUNT:
		var slot := {}
		if i == 0 and profile != null:
			slot = _make_character_slot(i, profile, map_name)
		else:
			slot = {"card": _make_card(i, null, map_name)}
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
	elif r.code == "unauthorized" or r.code == "banned":
		AccountScreen.next_login_message = r.message
		get_tree().change_scene_to_file.call_deferred(AccountScreen.LOGIN_SCENE)
		return
	else:
		_toast(r.message)
	var map_name := _map_name()
	for i in SLOT_COUNT:
		var slot := {}
		if by_slot.has(i) and by_slot[i].get("data") is Dictionary:
			var c: Dictionary = by_slot[i]
			slot = _make_character_slot(i, PlayerProfile.from_dict(c["data"]), map_name)
			slot["character"] = c
		else:
			slot = {"card": _make_card(i, null, map_name)}
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
	_toast("Đã đủ %d nhân vật trên máy chủ này" % SLOT_COUNT)

func _map_name() -> String:
	if FileAccess.file_exists(MINIMAP_META):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(MINIMAP_META))
		if meta is Dictionary and str(meta.get("title", "")) != "":
			return str(meta["title"])
	return "Ba Lăng Huyện"

func _make_character_slot(i: int, profile: PlayerProfile, map_name: String) -> Dictionary:
	var slot := {"profile": profile}
	slot["card"] = _make_card(i, profile, map_name)
	var sect := SectRegistry.get_by_id(profile.sect_id)
	var element: ElementTypes.ElementType = sect.element if sect else ElementTypes.ElementType.KIM
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
	portrait.pivot_offset = Vector2(ref.size.x * 0.5, ref.size.y)
	portrait.position = Vector2(SLOT_FEET_X[i], FEET_Y) - portrait.pivot_offset
	portrait.pressed.connect(_select.bind(i))
	## Vòng hào quang: giữ đúng vị trí so với chân như màn Tạo Nhân Vật, rồi thu nhỏ cùng nhân vật.
	var aura := AuraRing.new()
	aura.size = ref_aura.size
	aura.aura_name = ref_aura.aura_name
	aura.tilt = ref_aura.tilt
	aura.fps = ref_aura.fps
	var feet_ref := ref.feet_point(key)
	var delta := (ref_aura.position + ref_aura.size * 0.5) - feet_ref
	aura.scale = Vector2.ONE * CHAR_SCALE
	aura.pivot_offset = aura.size * 0.5
	aura.position = Vector2(SLOT_FEET_X[i], FEET_Y) + delta * CHAR_SCALE - aura.size * 0.5
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

## Thẻ thông tin: viền vàng nền tối; 3 dòng: [cấp]Tên (kem) / map (xanh lá) / cấp (đỏ) - môn phái (vàng). Ô trống: "Ô trống".
func _make_card(i: int, profile: PlayerProfile, map_name: String) -> Button:
	var card := Button.new()
	card.position = Vector2(SLOT_CARD_X[i], 75)
	card.size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.pressed.connect(_select.bind(i))
	_style_card(card, false)
	if profile == null:
		card.add_child(_line("Ô trống", Vector2(20, 14), 20, Color(0.6, 0.56, 0.48)))
		card.add_child(_line("Bấm \"Tạo nhân vật\"", Vector2(20, 48), 16, Color(0.5, 0.47, 0.4)))
	else:
		card.add_child(_line("[%d]%s" % [profile.level, profile.display_name], Vector2(26, 8), 19, Color(0.96, 0.93, 0.85)))
		card.add_child(_line(map_name, Vector2(26, 38), 19, Color(0.3, 0.95, 0.35)))
		var lv := _line(str(profile.level), Vector2(26, 66), 19, Color(0.95, 0.3, 0.25))
		card.add_child(lv)
		card.add_child(_line("-  %s" % profile.sect_name, Vector2(26 + 22 + 6 * str(profile.level).length(), 66), 19, Color(1.0, 0.9, 0.35)))
		var sect := SectRegistry.get_by_id(profile.sect_id)
		var orb_color: Color = ElementTypes.ELEMENT_COLOR.get(sect.element, Color.WHITE) if sect else Color.WHITE
		var orb := _Orb.new()
		orb.color = orb_color
		orb.position = Vector2(CARD_SIZE.x - 50, 24)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(orb)
	_stage.add_child(card)
	return card

func _line(text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Biểu tượng hệ (thay hình mũ lửa của mockup — không có ảnh rời): vòng tròn đúng màu hệ Ngũ Hành của nhân vật.
class _Orb extends Control:
	var color := Color.WHITE
	func _draw() -> void:
		draw_circle(Vector2(18, 18), 19.0, Color(0, 0, 0, 0.7))
		draw_circle(Vector2(18, 18), 16.0, color.darkened(0.25))
		draw_circle(Vector2(18, 18), 12.0, color.lightened(0.1))
		draw_circle(Vector2(13, 12), 4.5, Color(1, 1, 1, 0.5))

func _style_card(card: Button, selected: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.06, 0.05, 0.9 if selected else 0.8)
	s.set_border_width_all(3 if selected else 2)
	s.border_color = GOLD if selected else Color(0.62, 0.5, 0.25)
	s.set_corner_radius_all(2)
	if selected:
		s.shadow_color = Color(1, 0.8, 0.3, 0.55)
		s.shadow_size = 12
	for state in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, s)

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
	var slot: Dictionary = _slots[_selected]
	if not slot.has("profile"):
		_toast("Ô này chưa có nhân vật — bấm \"Tạo nhân vật\"")
		return
	GameManager.local_profile = slot["profile"]
	if slot.has("character"):
		var c: Dictionary = slot["character"]
		SaveManager.set_online_character(int(c["id"]), int(c["version"]))
	_go(HUB_SCENE)

func _go(path: String) -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(get_tree().change_scene_to_file.bind(path))

func _toast(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(1.8)
	_tween.tween_property(_message, "modulate:a", 0.0, 0.4)
