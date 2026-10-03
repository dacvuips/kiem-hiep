extends Control
class_name SkillBarUI
## Cụm nút thao tác skill góc dưới-phải màn chơi (kiểu VLTK mobile): 1 nút chính lớn, 8 ô phụ xếp quanh (vị trí
## theo ảnh mẫu), nút Auto, 2 nút "1"/"2" đổi TRANG thanh skill (mỗi trang 8 ô — PlayerProfile.hotbar_page). BỐ CỤC dựng sẵn bằng node trong SkillBarUI.tscn
## (chỉnh vị trí/kích thước trực tiếp trong editor) — script chỉ gắn skill vào nút, cập nhật hồi
## chiêu, kéo thả gắn/gỡ skill và bật/tắt Auto. Bấm nút = thi triển skill qua SectSkillController
## của Player (song song với phím tắt, không thay thế).

const SUB_BUTTON_SIZE := 64.0  ## Kích thước ảnh kéo thả (make_drag_preview), khớp nút phụ trong scene.
const COLOR_AUTO_ON := Color(0.3, 0.75, 0.35, 1.0)
const COLOR_AUTO_OFF := Color(0.25, 0.25, 0.25, 0.9)
const AURA_ON_TINT := Color(1.35, 1.2, 0.6)

## Dữ liệu kéo thả skill vào nút chính/4 nút phụ — nguồn kéo là lưới SkillBookScreen
## (from_slot = FROM_BOOK), nút chính (MAIN_SLOT) hoặc 1 nút phụ (from_slot = chỉ số 0-3).
const DRAG_TYPE := "hotbar_skill"
const FROM_BOOK := -1
const MAIN_SLOT := -2

@onready var _main_button: SkillButton = %MainButton
## Sub1..Sub8 = ô 0..7 của trang đang chọn (chỉ số hotbar = trang * 8 + ô); 4 ô đầu dùng phím skill_1-4.
@onready var _sub_buttons: Array[SkillButton] = [%Sub1, %Sub2, %Sub3, %Sub4, %Sub5, %Sub6, %Sub7, %Sub8]
@onready var _page_buttons: Array[Button] = [%Page1, %Page2]
## Cùng chức năng với phím tắt "toggle_auto" (mặc định Shift) — chung 1 cờ is_auto_mode.
@onready var _auto_button: Button = %AutoButton

var _player: Node
## true khi đang mở bảng Kỹ Năng Võ Công trong trận (main.gd bật/tắt) — chỉ lúc này mới được kéo
## thả gắn/gỡ skill trên 4 nút phụ, và bấm nút KHÔNG thi triển skill (game đang pause).
var editing_hotbar: bool = false
## Nút đang bị kéo đi (MAIN_SLOT hoặc 0-3; NO_DRAG = không kéo từ nút nào) — thả ra ngoài thì gỡ
## skill khỏi nút đó (nút chính thì về đòn chính mặc định của phái).
var _dragged_slot: int = NO_DRAG
const NO_DRAG := -100

static func make_drag_data(skill_id: String, from_slot: int) -> Dictionary:
	return {"type": DRAG_TYPE, "skill_id": skill_id, "from_slot": from_slot}

## Ảnh kéo theo con trỏ: vòng tròn viền trắng chứa ICON skill (cắt tròn, giống hệt nút skill), canh
## giữa con trỏ. Skill chưa có icon (các phái chưa có asset) thì hiện tạm tên skill.
static func make_drag_preview(skill: SkillDefinition) -> Control:
	var size := Vector2(SUB_BUTTON_SIZE, SUB_BUTTON_SIZE)
	var circle := Panel.new()
	circle.size = size
	circle.position = -size * 0.5
	var bg: Color = ElementTypes.ELEMENT_COLOR.get(skill.element, Color.GRAY)
	circle.add_theme_stylebox_override("panel", SkillButton.make_round_style(SUB_BUTTON_SIZE, bg.darkened(0.4)))
	circle.modulate.a = 0.85

	if skill.icon:
		var icon := TextureRect.new()
		icon.texture = skill.icon
		icon.material = SkillButton.make_circle_mask_material()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(2, 2)
		icon.size = size - Vector2(4, 4)
		circle.add_child(icon)
	else:
		var label := Label.new()
		label.text = skill.skill_name
		label.size = size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_font_size_override("font_size", 10)
		circle.add_child(label)

	## Bọc trong 1 Control rỗng: Godot đặt gốc preview đúng tại con trỏ, offset âm của vòng tròn bên
	## trong mới kéo được hình về canh giữa con trỏ.
	var holder := Control.new()
	holder.add_child(circle)
	return holder

func _ready() -> void:
	_main_button.pressed.connect(_on_main_pressed)
	_main_button.set_drag_forwarding(_get_slot_drag_data.bind(MAIN_SLOT), _can_drop_on_slot.bind(MAIN_SLOT), _drop_on_slot.bind(MAIN_SLOT))
	for i in _sub_buttons.size():
		_sub_buttons[i].pressed.connect(_on_sub_pressed.bind(i))
		_sub_buttons[i].set_drag_forwarding(_get_slot_drag_data.bind(i), _can_drop_on_slot.bind(i), _drop_on_slot.bind(i))
	_auto_button.pressed.connect(_on_auto_pressed)
	for p in _page_buttons.size():
		_page_buttons[p].pressed.connect(_set_page.bind(p))

func setup(player: Node) -> void:
	_player = player
	refresh_sub_skills()
	_refresh_auto_button_style()

## Gắn lại skill vào nút chính + 4 nút phụ theo PlayerProfile (main_skill_id, hotbar_skill_ids) hiện
## tại — ô phụ trống hiện "+".
func refresh_sub_skills() -> void:
	if _player == null:
		return
	var main_skill: SkillDefinition = _player.skill_controller.get_main_skill()
	_main_button.visible = main_skill != null
	if main_skill:
		_main_button.setup(main_skill, true)
	var skills: Array[SkillDefinition] = _player.skill_controller.get_sub_skills()
	var start := _page_start()
	for i in _sub_buttons.size():
		_sub_buttons[i].setup(skills[start + i] if start + i < skills.size() else null, false)
	var page := GameManager.local_profile.hotbar_page if GameManager.local_profile else 0
	## "Chạm nhả": ra chiêu khi nhả tay; tắt = ra chiêu ngay lúc chạm.
	var on_release := GameManager.local_profile != null and GameManager.local_profile.get_skill_setting("tap_release")
	for b in [_main_button] + _sub_buttons:
		(b as BaseButton).action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE if on_release \
				else BaseButton.ACTION_MODE_BUTTON_PRESS
	for p in _page_buttons.size():
		_page_buttons[p].set_pressed_no_signal(p == page)

## Chỉ số hotbar của ô đầu trang đang chọn.
func _page_start() -> int:
	var profile := GameManager.local_profile
	return profile.hotbar_page * PlayerProfile.HOTBAR_SLOTS_PER_PAGE if profile else 0

func _set_page(page: int) -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	profile.hotbar_page = page
	SaveManager.save_profile(profile)
	refresh_sub_skills()

## ---- Kéo thả gắn/gỡ skill (chỉ khi editing_hotbar) ----
## Thả skill từ bảng Kỹ Năng Võ Công lên 1 nút = gắn (skill đang ở nút khác thì rời nút đó). Kéo
## nút này thả lên nút khác = đổi chỗ (kể cả giữa nút chính và nút phụ). Kéo nút THẢ RA NGOÀI = gỡ
## (nút phụ thành ô trống, nút chính về đòn chính mặc định) — xem _notification.
func _slot_button(slot: int) -> SkillButton:
	return _main_button if slot == MAIN_SLOT else _sub_buttons[slot]

func _get_slot_drag_data(_at_position: Vector2, slot: int) -> Variant:
	var button := _slot_button(slot)
	if not editing_hotbar or button.skill == null:
		return null
	_dragged_slot = slot
	button.set_drag_preview(make_drag_preview(button.skill))
	return make_drag_data(button.skill.id, slot)

func _can_drop_on_slot(_at_position: Vector2, data: Variant, _slot: int) -> bool:
	return editing_hotbar and data is Dictionary and data.get("type") == DRAG_TYPE

func _drop_on_slot(_at_position: Vector2, data: Variant, slot: int) -> void:
	var skill_id: String = data["skill_id"]
	var from_slot: int = data["from_slot"]
	if from_slot == slot:
		return
	## Skill đang nằm ở nút đích TRƯỚC khi thả — dùng để đổi chỗ về nút nguồn khi kéo giữa 2 nút.
	var target_skill := _slot_button(slot).skill
	var previous_id := target_skill.id if target_skill else ""
	_assign(slot, skill_id)
	if from_slot != FROM_BOOK and previous_id != "" and previous_id != skill_id:
		_assign(from_slot, previous_id)
	_save_hotbar()

func _assign(slot: int, skill_id: String) -> void:
	var profile := GameManager.local_profile
	if slot == MAIN_SLOT:
		profile.set_main_skill(skill_id)
	else:
		profile.set_hotbar_slot(_page_start() + slot, skill_id)

func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	if _dragged_slot != NO_DRAG and not get_viewport().gui_is_drag_successful():
		if _dragged_slot == MAIN_SLOT:
			GameManager.local_profile.set_main_skill("")
		else:
			GameManager.local_profile.hotbar_skill_ids[_page_start() + _dragged_slot] = ""
		_save_hotbar()
	_dragged_slot = NO_DRAG

func _save_hotbar() -> void:
	SaveManager.save_profile(GameManager.local_profile)
	refresh_sub_skills()

func _on_auto_pressed() -> void:
	_player.is_auto_mode = not _player.is_auto_mode
	_refresh_auto_button_style()

func _refresh_auto_button_style() -> void:
	var is_on: bool = _player.is_auto_mode
	_auto_button.button_pressed = is_on
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_AUTO_ON if is_on else COLOR_AUTO_OFF
	style.set_corner_radius_all(8)
	_auto_button.add_theme_stylebox_override("normal", style)
	_auto_button.add_theme_stylebox_override("pressed", style)
	_auto_button.add_theme_color_override("font_color", Color.WHITE)

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or GameManager.local_profile == null:
		return
	var controller: SectSkillController = _player.skill_controller
	## Hào quang đang bật: nút sáng vàng.
	for b in [_main_button] + _sub_buttons:
		(b as Control).modulate = AURA_ON_TINT if controller.is_aura_active(b.skill) else Color.WHITE
	if _main_button.skill:
		_main_button.refresh(controller.get_cooldown_ratio(_main_button.skill.id), true)
	for button in _sub_buttons:
		if button.skill == null:
			button.refresh(0.0, true)
			continue
		var learned := SectSkillController.DEBUG_UNLOCK_ALL_SKILLS or GameManager.local_profile.get_skill_level(button.skill.id) > 0
		button.refresh(controller.get_cooldown_ratio(button.skill.id), learned)

	## Đồng bộ hiển thị nút Auto với is_auto_mode — cần refresh mỗi frame vì phím tắt "toggle_auto"
	## (Shift) đổi cờ này TRỰC TIẾP trong player.gd, không đi qua _on_auto_pressed() ở trên.
	if _auto_button.button_pressed != _player.is_auto_mode:
		_refresh_auto_button_style()

func _on_main_pressed() -> void:
	if editing_hotbar:
		return
	## Mục tiêu có thể null — skill buff lên mình vẫn thi triển được (xem SectSkillController._try_cast).
	var target: Node2D = _player.get_cast_target()
	if _player.skill_controller.try_cast_main(_player, target):
		_player.play_cast()

func _on_sub_pressed(index: int) -> void:
	if editing_hotbar:
		return
	var target: Node2D = _player.get_cast_target()
	if _player.skill_controller.try_cast_skill(_page_start() + index, _player, target):
		_player.play_cast()
