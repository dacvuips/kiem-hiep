extends Control
class_name CharacterSelectScreen
## Màn "Chọn Nhân Vật" — hiển thị TRƯỚC khi vào màn chơi (main scene của project).
##
## 3 bước theo tinh thần môn phái/ngũ hành của Võ Lâm Truyền Kỳ:
##   Bước 1: chọn 1 trong 5 hệ Ngũ Hành (Kim/Mộc/Thủy/Hỏa/Thổ).
##   Bước 2: chọn 1 môn phái trong các môn phái thuộc hệ đó (SectRegistry lọc theo element).
##   Bước 3: xem bảng skill preview của môn phái + chọn giới tính + nhập tên + Tạo Nhân Vật.
##
## Dựng bằng Control/Container thuần (không có ảnh mockup thật cho môn phái/skill) — khi có asset
## thật sau này chỉ cần thay Theme/StyleBox và icon, không cần sửa logic.

const HUB_SCENE_PATH := "res://ui/character_hub/CharacterHub.tscn"
const NAME_MIN_LENGTH := 2
const FADE_DURATION := 0.35

const ELEMENT_ORDER: Array[ElementTypes.ElementType] = [
	ElementTypes.ElementType.KIM,
	ElementTypes.ElementType.MOC,
	ElementTypes.ElementType.THUY,
	ElementTypes.ElementType.HOA,
	ElementTypes.ElementType.THO,
]

@onready var _step_element: Control = %StepElement
@onready var _step_sect: Control = %StepSect
@onready var _step_preview: Control = %StepPreview

@onready var _element_grid: GridContainer = %ElementGrid
@onready var _quit_button: Button = %QuitButton

@onready var _sect_title: Label = %Title
@onready var _sect_list: VBoxContainer = %SectList
@onready var _sect_back_button: Button = %SectBackButton

@onready var _sect_header: Label = %SectHeader
@onready var _skill_list: VBoxContainer = %SkillList
@onready var _male_card: Button = %MaleCard
@onready var _female_card: Button = %FemaleCard
@onready var _name_input: LineEdit = %NameInput
@onready var _error_label: Label = %ErrorLabel
@onready var _create_button: Button = %CreateButton
@onready var _preview_back_button: Button = %PreviewBackButton

var _current_step: int = 0
var _selected_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM
var _selected_sect: SectDefinition
var _selected_gender: PlayerProfile.Gender = PlayerProfile.Gender.MALE

func _ready() -> void:
	## Mở game lần đầu trong phiên mà đã có nhân vật lưu sẵn -> vào thẳng màn Nhân Vật. Khi quay lại
	## từ màn Nhân Vật thì local_profile đã có, nên không tự chuyển nữa (cho phép sửa tên/giới tính).
	if GameManager.local_profile == null and SaveManager.has_profile():
		GameManager.local_profile = SaveManager.load_profile()
		if GameManager.local_profile:
			get_tree().change_scene_to_file.call_deferred(HUB_SCENE_PATH)
			return

	MusicManager.play_title_music()
	_build_element_grid()
	_male_card.pressed.connect(_select_gender.bind(PlayerProfile.Gender.MALE))
	_female_card.pressed.connect(_select_gender.bind(PlayerProfile.Gender.FEMALE))
	_create_button.pressed.connect(_on_create_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_sect_back_button.pressed.connect(_on_sect_back_pressed)
	_preview_back_button.pressed.connect(_on_preview_back_pressed)
	_name_input.text_submitted.connect(func(_text: String) -> void: _on_create_pressed())
	_name_input.text_changed.connect(func(_text: String) -> void: _error_label.text = "")

	var existing := GameManager.local_profile
	if existing:
		_name_input.text = existing.display_name
		_selected_gender = existing.gender
		var existing_sect := SectRegistry.get_by_id(existing.sect_id)
		if existing_sect:
			_selected_element = existing_sect.element
			_selected_sect = existing_sect
			_populate_sect_list()
			_populate_skill_preview(existing_sect)
			_select_gender(existing.gender)
			_go_to_step(2)
		else:
			_go_to_step(0)
	else:
		_select_gender(PlayerProfile.Gender.MALE)
		_go_to_step(0)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_DURATION)

# ---------------------------------------------------------------- Bước 1: Hệ Ngũ Hành

func _build_element_grid() -> void:
	for element in ELEMENT_ORDER:
		var card := _make_element_card(element)
		_element_grid.add_child(card)

func _make_element_card(element: ElementTypes.ElementType) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(120, 120)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.text = ElementTypes.ELEMENT_NAME.get(element, "?")
	card.add_theme_font_size_override("font_size", 20)

	var style := StyleBoxFlat.new()
	style.bg_color = ElementTypes.ELEMENT_COLOR.get(element, Color.GRAY)
	style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color(1, 0.84, 0.4, 1)
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)

	card.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04))
	card.pressed.connect(_on_element_selected.bind(element))
	return card

func _on_element_selected(element: ElementTypes.ElementType) -> void:
	_selected_element = element
	_selected_sect = null
	_populate_sect_list()
	_go_to_step(1)

func _on_quit_pressed() -> void:
	## Quay lại màn hình chọn chế độ chơi
	get_tree().change_scene_to_file.call_deferred("res://ui/mode_select/ModeSelect.tscn")

# ---------------------------------------------------------------- Bước 2: Môn Phái

func _populate_sect_list() -> void:
	_sect_title.text = "Chọn Môn Phái (Hệ %s)" % ElementTypes.ELEMENT_NAME.get(_selected_element, "?")
	for child in _sect_list.get_children():
		child.queue_free()
	for sect in SectRegistry.get_by_element(_selected_element):
		var card := SectCard.new()
		card.custom_minimum_size = Vector2(0, 56)
		card.setup(sect)
		card.selected.connect(_on_sect_selected)
		_sect_list.add_child(card)

func _on_sect_selected(sect: SectDefinition) -> void:
	_selected_sect = sect
	_populate_skill_preview(sect)
	_go_to_step(2)

func _on_sect_back_pressed() -> void:
	_go_to_step(0)

# ---------------------------------------------------------------- Bước 3: Preview + Tạo

func _populate_skill_preview(sect: SectDefinition) -> void:
	_sect_header.text = "%s — %s" % [sect.sect_name, SectEnums.alignment_to_string(sect.alignment)]
	for child in _skill_list.get_children():
		child.queue_free()
	for skill in sect.skills:
		var row: SkillRow = preload("res://ui/character_select/SkillRow.tscn").instantiate()
		_skill_list.add_child(row)
		row.setup(skill)

func _select_gender(gender: PlayerProfile.Gender) -> void:
	_selected_gender = gender
	var is_male := gender == PlayerProfile.Gender.MALE
	_set_card_selected(_male_card, is_male)
	_set_card_selected(_female_card, not is_male)

func _set_card_selected(card: Button, selected: bool) -> void:
	card.get_node("Glow").visible = selected
	card.get_node("Dim").visible = not selected

func _on_preview_back_pressed() -> void:
	_go_to_step(1)

func _on_create_pressed() -> void:
	if _selected_sect == null:
		_error_label.text = "Vui lòng chọn môn phái"
		return
	var player_name := _name_input.text.strip_edges()
	if player_name.length() < NAME_MIN_LENGTH:
		_error_label.text = "Tên cần ít nhất %d ký tự" % NAME_MIN_LENGTH
		_name_input.grab_focus()
		return

	## Đã có nhân vật (quay lại từ màn Nhân Vật) thì chỉ đổi tên/giới tính/môn phái, giữ nguyên tiến trình.
	var profile := GameManager.local_profile if GameManager.local_profile else PlayerProfile.new()
	profile.display_name = player_name
	profile.gender = _selected_gender
	if profile.has_sect():
		profile.set_sect(_selected_sect)   ## offline: nhân vật đã vào phái vẫn đổi phái được (thử nghiệm)
	else:
		profile.choose_element(_selected_sect.element)   ## nhân vật mới: Vô Môn Phái, cấp 10 mới chọn phái (SectPrompt)
	GameManager.local_profile = profile
	SaveManager.save_profile(profile)

	_create_button.disabled = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(get_tree().change_scene_to_file.bind(HUB_SCENE_PATH))

# ---------------------------------------------------------------- Điều hướng bước

func _go_to_step(step: int) -> void:
	_current_step = step
	_step_element.visible = step == 0
	_step_sect.visible = step == 1
	_step_preview.visible = step == 2
