extends Control
class_name CharacterCreateScreen
## Màn "Tạo Nhân Vật" dựng theo mockup: chọn hệ Ngũ Hành ở giữa, nhân vật nam (trái) / nữ (phải)
## của hệ đó đứng thở 2 bên, nhập tên + tạo + vào game ở hàng dưới.
##
## Bố cục đặt theo toạ độ ảnh mockup 1672x941 trong node Stage, Stage được scale "fit" + căn giữa
## theo kích thước viewport; nền phủ kiểu "cover".
##
## Chỉ chọn hệ: nhân vật mới là Vô Môn Phái, đủ cấp PlayerProfile.NEWBIE_LEVEL mới chọn phái của hệ (SectPrompt).
## Sheet nhân vật còn thiếu: Kim-Nữ, Thủy-Nam (hiện báo "Sắp ra mắt", không cho chọn giới tính đó).

const HUB_SCENE_PATH := "res://ui/character_hub/CharacterHub.tscn"
const ROSTER_SCENE_PATH := "res://ui/character_roster/CharacterRoster.tscn"   ## nút "Quay lại" về danh sách nhân vật
const CHARS_DIR := "res://ui/character_create/chars/"
const NAME_MIN_LENGTH := 2

## Ô nhân vật sẽ tạo (màn Danh sách nhân vật đặt trước khi chuyển sang đây). Chỉ dùng khi đã đăng nhập.
static var target_slot := 0
const FADE_DURATION := 0.35

const ELEMENT_ORDER: Array[ElementTypes.ElementType] = [
	ElementTypes.ElementType.KIM,
	ElementTypes.ElementType.MOC,
	ElementTypes.ElementType.THUY,
	ElementTypes.ElementType.HOA,
	ElementTypes.ElementType.THO,
]
const ELEMENT_KEY := {
	ElementTypes.ElementType.KIM: "kim",
	ElementTypes.ElementType.MOC: "moc",
	ElementTypes.ElementType.THUY: "thuy",
	ElementTypes.ElementType.HOA: "hoa",
	ElementTypes.ElementType.THO: "tho",
}

const ELEMENT_DIM := Color(0.72, 0.7, 0.72)
## Vòng hào quang theo hệ (khoá = kim/moc/thuy/hoa/tho, giá trị = tên vòng trong ui/character_create/aura/aura.json). Chỉnh ở Inspector.
## Hiện chỉ dùng 1 vòng chung (id_5438aef0) cho mọi hệ.
@export var element_aura: Dictionary[String, String] = {
	"kim": "id_5438aef0", "moc": "id_5438aef0", "thuy": "id_5438aef0", "hoa": "id_5438aef0", "tho": "id_5438aef0",
}

const NAME_FAMILY := ["Lý", "Trần", "Nguyễn", "Lê", "Hoàng", "Dương", "Tiêu", "Mộ Dung", "Đoàn", "Lăng", "Bạch", "Triệu", "Phương", "Vân"]
const NAME_GIVEN := ["Vô Kỵ", "Thiên Phong", "Hạo Nhiên", "Tuyết Nhi", "Nhược Hy", "Kiếm Tâm", "Phi Vân", "Thanh Hà", "Ngạo Thiên", "Minh Nguyệt", "Hàn Băng", "Liệt Hỏa", "Tử Yên", "Chiêu Dương"]

@onready var _background: TextureRect = %Background
@onready var _stage: Control = %Stage
@onready var _element_buttons: Array[TextureButton] = [%ElementKim, %ElementMoc, %ElementThuy, %ElementHoa, %ElementTho]
@onready var _male_aura: AuraRing = %MaleAura
@onready var _female_aura: AuraRing = %FemaleAura
@onready var _male_portrait: AnimatedPortrait = %MalePortrait
@onready var _female_portrait: AnimatedPortrait = %FemalePortrait
@onready var _male_missing: Label = %MaleMissing
@onready var _female_missing: Label = %FemaleMissing
@onready var _name_input: LineEdit = %NameInput
@onready var _dice_button: Button = %DiceButton
@onready var _create_button: TextureButton = %CreateButton
@onready var _enter_button: TextureButton = %EnterButton
@onready var _message: Label = %Message
@onready var _back_button: Button = %BackButton
@onready var _side_buttons: Array[TextureButton] = [%AccountButton, %SettingsButton, %SupportButton, %NoticeButton]

var _meta: Dictionary = {}
var _element: ElementTypes.ElementType = ElementTypes.ElementType.HOA
var _gender: PlayerProfile.Gender = PlayerProfile.Gender.MALE
var _message_tween: Tween
var _auras: Dictionary = {}  ## AnimatedPortrait -> AuraRing nằm sau lưng nhân vật (node có sẵn trong scene)

func _ready() -> void:
	_meta = _load_meta()

	for i in _element_buttons.size():
		_setup_element_button(_element_buttons[i], ELEMENT_ORDER[i])
	## Nút hệ Ngũ Hành + 4 nút bên trái LUÔN nằm trên khung nhân vật và vòng hào quang (vẽ sau cùng + nhận bấm trước), dù trong
	## scene có sắp xếp lại thứ tự node.
	for b in _element_buttons:
		b.move_to_front()
	for b in _side_buttons:
		b.move_to_front()
	_auras[_male_portrait] = _male_aura
	_auras[_female_portrait] = _female_aura
	## Vòng hào quang nam/nữ ĐỨNG YÊN 1 vị trí (node MaleAura/FemaleAura trong scene), không đổi theo từng nhân vật.
	_male_portrait.pressed.connect(_on_gender_pressed.bind(PlayerProfile.Gender.MALE))
	_female_portrait.pressed.connect(_on_gender_pressed.bind(PlayerProfile.Gender.FEMALE))
	for b: TextureButton in [_create_button, _enter_button] + _side_buttons:
		b.mouse_entered.connect(_play_ui.bind(VltkSound.UI_HOVER))
	_dice_button.pressed.connect(_on_dice_pressed)
	_create_button.pressed.connect(_on_create_pressed)
	_enter_button.pressed.connect(_on_enter_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.mouse_entered.connect(_play_ui.bind(VltkSound.UI_HOVER))
	_name_input.text_submitted.connect(func(_t: String) -> void: _on_create_pressed())
	for b in _side_buttons:
		if b.name == "AccountButton":
			b.pressed.connect(func() -> void: AccountDialog.open(self))
		else:
			b.pressed.connect(_show_message.bind("Tính năng đang phát triển"))

	## Đã đăng nhập: luôn tạo nhân vật MỚI trên server, không điền sẵn nhân vật cũ.
	var existing: PlayerProfile = null if AccountApi.is_logged_in() else GameManager.local_profile
	if existing == null and SaveManager.has_profile():
		existing = SaveManager.load_profile()
		GameManager.local_profile = existing
	if existing:
		_name_input.text = existing.display_name
		_gender = existing.gender
		_element = existing.get_element()
	_select_element(_element)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_DURATION)

# ---------------------------------------------------------------- Hệ Ngũ Hành

func _setup_element_button(button: TextureButton, element: ElementTypes.ElementType) -> void:
	button.pressed.connect(_on_element_pressed.bind(element))
	button.mouse_entered.connect(_play_ui.bind(VltkSound.UI_HOVER))

## Âm giao diện VLTK gốc (SoundList.txt): chọn ngũ hành/nhân vật, rê nút, bấm nút.
func _play_ui(key: int) -> void:
	SfxManager.play_ui(VltkSound.ui(key))

func _on_element_pressed(element: ElementTypes.ElementType) -> void:
	_play_ui(VltkSound.UI_SELECT)
	_select_element(element)

func _select_element(element: ElementTypes.ElementType) -> void:
	_element = element
	for i in _element_buttons.size():
		var on := ELEMENT_ORDER[i] == element
		var b := _element_buttons[i]
		## Chỉ đổi độ sáng/màu: hệ đang chọn giữ nguyên màu gốc, các hệ khác tối và nhạt màu đi.
		var target := Color.WHITE if on else ELEMENT_DIM
		create_tween().tween_property(b, "modulate", target, 0.15)

	var aura_key: String = element_aura.get(ELEMENT_KEY[element], "id_5438aef0")
	_male_aura.aura_name = aura_key
	_female_aura.aura_name = aura_key
	var has_male := _setup_portrait(_male_portrait, "nam")
	var has_female := _setup_portrait(_female_portrait, "nu")
	_male_missing.visible = not has_male
	_female_missing.visible = not has_female
	var hint := "Sắp ra mắt"
	_male_missing.text = hint
	_female_missing.text = hint
	## Giới tính đang chọn không có sheet ở hệ này -> chuyển sang giới tính còn lại.
	if _gender == PlayerProfile.Gender.MALE and not has_male and has_female:
		_gender = PlayerProfile.Gender.FEMALE
	elif _gender == PlayerProfile.Gender.FEMALE and not has_female and has_male:
		_gender = PlayerProfile.Gender.MALE
	_select_gender(_gender)

## Trả về false nếu hệ này chưa có sheet cho giới tính đó. Hệ thiếu sheet 1 giới tính (nữ Kim, nam Thủy — bản 15 phái
## có Dương Môn/Hoa Sơn nhận cả hai) thì TẠM dùng sheet giới tính kia của cùng hệ; thả <he>_<gioi>.png + mục chars.json
## vào chars/ là tự dùng ảnh thật.
func _setup_portrait(portrait: AnimatedPortrait, gender_key: String) -> bool:
	var char_key := "%s_%s" % [ELEMENT_KEY[_element], gender_key]   ## khoá chỉnh cỡ/vị trí (offsets/scales) — giữ tên thật
	var key := AnimatedPortrait.sheet_for(char_key)
	var path := "%s%s.png" % [CHARS_DIR, key]
	if not _meta.has(key) or not ResourceLoader.exists(path):
		portrait.visible = false
		portrait.set_playing(false)
		return false
	## Vị trí đứng / cỡ nhân vật và vòng hào quang do người chỉnh trong editor (kéo node MalePortrait/FemalePortrait và
	## MaleAura/FemaleAura trong Stage) — code chỉ đổi hình.
	portrait.setup(load(path), _meta[key], char_key)
	portrait.visible = true
	portrait.set_playing(false)
	return true

func _on_gender_pressed(gender: PlayerProfile.Gender) -> void:
	_play_ui(VltkSound.UI_SELECT)
	_select_gender(gender)

func _select_gender(gender: PlayerProfile.Gender) -> void:
	_gender = gender
	var male_on := gender == PlayerProfile.Gender.MALE
	_apply_portrait_state(_male_portrait, male_on)
	_apply_portrait_state(_female_portrait, not male_on)

func _apply_portrait_state(portrait: AnimatedPortrait, on: bool) -> void:
	portrait.set_playing(on)
	(_auras[portrait] as Control).visible = on and portrait.visible
	var target := Color.WHITE if on else Color(0.55, 0.55, 0.6)
	create_tween().tween_property(portrait, "modulate", target, 0.2)

func _load_meta() -> Dictionary:
	var f := FileAccess.open(CHARS_DIR + "chars.json", FileAccess.READ)
	if f == null:
		push_warning("CharacterCreate: thiếu chars.json — chạy tools/build_character_create_assets.py")
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}

# ---------------------------------------------------------------- Tên / Tạo / Vào game

func _on_dice_pressed() -> void:
	_play_ui(VltkSound.UI_POPUP)
	_name_input.text = "%s %s" % [NAME_FAMILY.pick_random(), NAME_GIVEN.pick_random()]

func _on_create_pressed() -> void:
	_play_ui(VltkSound.UI_POPUP)
	var player_name := _name_input.text.strip_edges()
	if player_name.length() < NAME_MIN_LENGTH:
		_show_message("Tên cần ít nhất %d ký tự" % NAME_MIN_LENGTH)
		_name_input.grab_focus()
		return
	var sects := SectRegistry.get_by_element(_element)
	if sects.is_empty():
		_show_message("Hệ này chưa có môn phái")
		return
	if AccountApi.is_logged_in():
		_create_online(player_name)
		return

	## Đã có nhân vật thì chỉ đổi tên/giới tính/hệ, giữ nguyên tiến trình (đổi hệ thì bỏ phái cũ, về Vô Môn Phái).
	var is_new := GameManager.local_profile == null
	var profile := GameManager.local_profile if GameManager.local_profile else PlayerProfile.new()
	profile.display_name = player_name
	profile.gender = _gender
	if profile.get_element() != _element or (not profile.has_sect() and profile.element < 0):
		profile.choose_element(_element)
	var need_gender := PlayerProfile.required_gender(int(_element))
	if need_gender >= 0:
		profile.gender = need_gender as PlayerProfile.Gender   ## hệ mà mọi phái cùng đòi 1 giới tính
	if is_new:
		StarterKit.apply(profile)   ## quà tân thủ: cấp 10 + đồ trong túi (vào game là phải chọn phái)
	GameManager.local_profile = profile
	SaveManager.save_profile(profile)
	_show_message("Đã tạo nhân vật %s — %s" % [player_name, profile.sect_name])

## Tạo nhân vật trên server (tài khoản + máy chủ đang chọn, ô target_slot) rồi vào game luôn.
func _create_online(player_name: String) -> void:
	if _create_button.disabled:
		return
	var profile := PlayerProfile.new()
	profile.display_name = player_name
	profile.gender = _gender
	profile.choose_element(_element)
	var need_gender := PlayerProfile.required_gender(int(_element))
	if need_gender >= 0:
		profile.gender = need_gender as PlayerProfile.Gender   ## hệ mà mọi phái cùng đòi 1 giới tính
	## Quà tân thủ để Hub hiện ngay cấp 10 + đồ; bản thật do game server phát lại lúc vào map lần đầu (ProfileGuard.sanitize_new).
	StarterKit.apply(profile)
	_create_button.disabled = true
	_enter_button.disabled = true
	_show_message("Đang tạo nhân vật…")
	var r: Dictionary = await AccountApi.create_character(ServerSelectScreen.selected_server_id, target_slot, player_name, profile.to_dict())
	_create_button.disabled = false
	_enter_button.disabled = false
	if not r.ok:
		_show_message(r.message)
		if r.code in ["bad_name", "name_taken"]:
			_name_input.grab_focus()
			_name_input.select_all()
		return
	var c: Dictionary = r.data
	GameManager.local_profile = PlayerProfile.from_dict(c["data"])
	SaveManager.set_online_character(int(c["id"]), int(c["version"]))
	_show_message("Đã tạo nhân vật %s — %s" % [c["name"], profile.sect_name])
	_on_enter_pressed()

func _on_enter_pressed() -> void:
	_play_ui(VltkSound.UI_ENTER)
	if GameManager.local_profile == null:
		_show_message("Hãy tạo nhân vật trước")
		return
	_enter_button.disabled = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(get_tree().change_scene_to_file.bind(HUB_SCENE_PATH))

## Quay lại màn danh sách nhân vật (không lưu gì thêm; nhân vật đã bấm "Tạo" thì đã được lưu).
func _on_back_pressed() -> void:
	_play_ui(VltkSound.UI_SELECT)
	_back_button.disabled = true
	_enter_button.disabled = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(get_tree().change_scene_to_file.bind(ROSTER_SCENE_PATH))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _back_button.disabled:   # phím Esc cũng quay lại
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.6)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)
