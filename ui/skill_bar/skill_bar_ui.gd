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
## Mã nguồn kéo/thả của 2 ô thi triển liên tục: LOOP_SLOT_BASE + chỉ số ô (0-1).
const LOOP_SLOT_BASE := 100

@onready var _main_button: SkillButton = %MainButton
## Sub1..Sub8 = ô 0..7 của trang đang chọn (chỉ số hotbar = trang * 8 + ô); 4 ô đầu dùng phím skill_1-4.
@onready var _sub_buttons: Array[SkillButton] = [%Sub1, %Sub2, %Sub3, %Sub4, %Sub5, %Sub6, %Sub7, %Sub8]
@onready var _page_buttons: Array[Button] = [%Page1, %Page2]
## Cùng chức năng với phím tắt "toggle_auto" (mặc định Shift) — chung 1 cờ is_auto_mode.
@onready var _auto_button: Button = %AutoButton
## Nhảy / lên-xuống ngựa nhanh / đi theo — cùng chức năng với phím Space / M / F (xem Player).
@onready var _jump_button: Button = %JumpButton
@onready var _horse_button: Button = %HorseButton
@onready var _follow_button: Button = %FollowButton
@onready var _sit_button: Button = %SitButton
@onready var _loop_buttons: Array[SkillButton] = [%Loop1]

var _player: Node
## Vị trí MẶC ĐỊNH (offset_left/top/right/bottom trong scene) của từng nút skill — cộng độ dời của người chơi (PlayerProfile.skill_layout).
var _base_offsets: Dictionary = {}
var _page_swap: Button
## Kéo nút chính để NGẮM HƯỚNG: giữ rồi kéo -> mũi tên dài chỉ hướng đánh trên bản đồ, skill đánh liên tục theo hướng đó tới khi thả.
const AIM_DEAD_ZONE := 14.0
var _aiming := false
var _aim_press_pos := Vector2.ZERO
var _aim_dir := Vector2.ZERO
var _suppress_main_press := false
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

## Nút Auto nằm NGAY DƯỚI mini map (góc phải-trên), canh sát cạnh phải mini map; kích thước/lề lấy từ MiniMap để đổi cỡ vẫn khớp.
const AUTO_BUTTON_SIZE := Vector2(52, 52)
const AUTO_BUTTON_GAP := 6.0
func _place_auto_button() -> void:
	_auto_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var right := MiniMap.SCREEN_MARGIN
	var top := MiniMap.SCREEN_MARGIN + MiniMap.BASE_SIZE.y * MiniMap.UI_SCALE + AUTO_BUTTON_GAP
	_auto_button.offset_right = -right
	_auto_button.offset_left = -right - AUTO_BUTTON_SIZE.x
	_auto_button.offset_top = top
	_auto_button.offset_bottom = top + AUTO_BUTTON_SIZE.y
	_auto_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_auto_button.grow_vertical = Control.GROW_DIRECTION_END

func _ready() -> void:
	_main_button.pressed.connect(_on_main_pressed)
	_main_button.set_drag_forwarding(_get_slot_drag_data.bind(MAIN_SLOT), _can_drop_on_slot.bind(MAIN_SLOT), _drop_on_slot.bind(MAIN_SLOT))
	for i in _sub_buttons.size():
		_sub_buttons[i].pressed.connect(_on_sub_pressed.bind(i))
		_sub_buttons[i].set_drag_forwarding(_get_slot_drag_data.bind(i), _can_drop_on_slot.bind(i), _drop_on_slot.bind(i))
	_auto_button.pressed.connect(_on_auto_pressed)
	_place_auto_button()
	for i in _loop_buttons.size():
		var slot := LOOP_SLOT_BASE + i
		_loop_buttons[i].pressed.connect(_on_loop_pressed.bind(i))
		_loop_buttons[i].set_drag_forwarding(_get_slot_drag_data.bind(slot), _can_drop_on_slot.bind(slot), _drop_on_slot.bind(slot))
	_jump_button.pressed.connect(_on_jump_pressed)
	_horse_button.pressed.connect(_on_horse_pressed)
	_follow_button.pressed.connect(_on_follow_pressed)
	_sit_button.pressed.connect(_on_sit_pressed)
	_style_round_button(_jump_button, "run", 0, 1)
	_style_round_button(_horse_button, "hourse", 0, 1)
	_style_round_button(_follow_button, "party", 0, 2)
	_style_round_button(_sit_button, "sit", 0, 2)
	for p in _page_buttons.size():
		_page_buttons[p].pressed.connect(_set_page.bind(p))
	_main_button.gui_input.connect(_on_main_gui_input)
	_build_page_swap()
	_capture_base_offsets()

## Nút mũi tên đảo chiều giữa "1" và "2": bấm là chuyển nhóm skill 1 <-> 2.
func _build_page_swap() -> void:
	_page_swap = Button.new()
	_page_swap.name = "PageSwap"
	_page_swap.text = "⇄"
	_page_swap.focus_mode = Control.FOCUS_NONE
	_page_swap.tooltip_text = "Đổi nhóm kỹ năng 1 <-> 2"
	_page_swap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var p1 := _page_buttons[0]
	var p2 := _page_buttons[1]
	var gap_left := p1.offset_right
	var gap_right := p2.offset_left
	var width := minf(54.0, maxf(40.0, gap_right - gap_left))
	_page_swap.offset_left = (gap_left + gap_right) * 0.5 - width * 0.5
	_page_swap.offset_right = _page_swap.offset_left + width
	_page_swap.offset_top = p1.offset_top
	_page_swap.offset_bottom = p1.offset_bottom
	_page_swap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_page_swap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_page_swap.add_theme_font_size_override("font_size", 24)
	_page_swap.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	_page_swap.add_theme_color_override("font_outline_color", Color.BLACK)
	_page_swap.add_theme_constant_override("outline_size", 4)
	_page_swap.add_theme_stylebox_override("normal", p1.get_theme_stylebox("normal"))
	_page_swap.add_theme_stylebox_override("hover", p1.get_theme_stylebox("pressed"))
	_page_swap.add_theme_stylebox_override("pressed", p1.get_theme_stylebox("pressed"))
	_page_swap.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_page_swap.pressed.connect(func() -> void:
		var profile := GameManager.local_profile
		if profile != null:
			_set_page(1 - profile.hotbar_page))
	add_child(_page_swap)

## Khoá bố cục của từng nút skill: main, s0..s7, loop0.
func _layout_nodes() -> Dictionary:
	var out := {"main": _main_button}
	for i in _sub_buttons.size():
		out["s%d" % i] = _sub_buttons[i]
	for i in _loop_buttons.size():
		out["loop%d" % i] = _loop_buttons[i]
	return out

func _capture_base_offsets() -> void:
	var nodes := _layout_nodes()
	for key in nodes:
		var c: Control = nodes[key]
		_base_offsets[key] = [c.offset_left, c.offset_top, c.offset_right, c.offset_bottom]

## Áp độ dời tự sắp xếp của người chơi lên vị trí mặc định.
func apply_layout() -> void:
	var profile := GameManager.local_profile
	var nodes := _layout_nodes()
	for key in nodes:
		if not _base_offsets.has(key):
			continue
		var c: Control = nodes[key]
		var b: Array = _base_offsets[key]
		var d := profile.get_layout_offset(key) if profile != null else Vector2.ZERO
		c.offset_left = b[0] + d.x
		c.offset_right = b[2] + d.x
		c.offset_top = b[1] + d.y
		c.offset_bottom = b[3] + d.y

func setup(player: Node) -> void:
	_player = player
	refresh_sub_skills()
	_refresh_auto_button_style()

## Gắn lại skill vào nút chính + 4 nút phụ theo PlayerProfile (main_skill_id, hotbar_skill_ids) hiện
## tại — ô phụ trống hiện "+".
func refresh_sub_skills() -> void:
	if _player == null:
		return
	apply_layout()
	var main_skill: SkillDefinition = _player.skill_controller.get_main_skill()
	_main_button.visible = main_skill != null
	if main_skill:
		_main_button.setup(main_skill, true)
	for i in _loop_buttons.size():
		var loop_skill: SkillDefinition = _player.skill_controller.get_loop_skill(i)
		_loop_buttons[i].setup(loop_skill, false)
		if loop_skill == null:
			_loop_buttons[i].text = "∞"  ## ô thi triển liên tục còn trống
			_loop_buttons[i].add_theme_font_size_override("font_size", 20)
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
	if slot >= LOOP_SLOT_BASE:
		return _loop_buttons[slot - LOOP_SLOT_BASE]
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
	if slot >= LOOP_SLOT_BASE:
		profile.set_loop_slot(slot - LOOP_SLOT_BASE, skill_id)
	elif slot == MAIN_SLOT:
		profile.set_main_skill(skill_id)
	else:
		profile.set_hotbar_slot(_page_start() + slot, skill_id)

func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	if _dragged_slot != NO_DRAG and not get_viewport().gui_is_drag_successful():
		if _dragged_slot >= LOOP_SLOT_BASE:
			GameManager.local_profile.set_loop_slot(_dragged_slot - LOOP_SLOT_BASE, "")
		elif _dragged_slot == MAIN_SLOT:
			GameManager.local_profile.set_main_skill("")
		else:
			GameManager.local_profile.hotbar_skill_ids[_page_start() + _dragged_slot] = ""
		_save_hotbar()
	_dragged_slot = NO_DRAG

func _save_hotbar() -> void:
	SaveManager.save_profile(GameManager.local_profile)
	refresh_sub_skills()

## Bấm ô liên tục = tạm dừng/tiếp tục tự ra chiêu skill đó (trừ lúc đang chỉnh thanh skill).
func _on_loop_pressed(index: int) -> void:
	if editing_hotbar or _player.skill_controller.get_loop_skill(index) == null:
		return
	_player.skill_controller.loop_enabled[index] = not _player.skill_controller.loop_enabled[index]

func _on_jump_pressed() -> void:
	if not editing_hotbar:
		_player.start_jump()

func _on_horse_pressed() -> void:
	if not editing_hotbar:
		_player.toggle_ride()

func _on_sit_pressed() -> void:
	if not editing_hotbar:
		_player.toggle_sit()

func _on_follow_pressed() -> void:
	if not editing_hotbar:
		_player.toggle_follow()

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
	## Đang ngắm: mũi tên chỉ hướng + đánh liên tục theo hướng đó (hồi chiêu của skill vẫn áp dụng).
	if _aiming and _aim_dir != Vector2.ZERO and not editing_hotbar:
		_player.set_aim(_aim_dir)
		if _player.skill_controller.try_cast_main(_player, _player.make_aim_target(_main_button.skill)):
			_player.play_cast()
	var controller: SectSkillController = _player.skill_controller
	## Hào quang đang bật: nút sáng vàng.
	for b in [_main_button] + _sub_buttons:
		(b as Control).modulate = AURA_ON_TINT if controller.is_aura_active(b.skill) else Color.WHITE
	## Ô liên tục: hiện hồi chiêu; mờ đi khi đang tạm dừng.
	for i in _loop_buttons.size():
		var loop_button := _loop_buttons[i]
		if loop_button.skill != null:
			loop_button.refresh(controller.get_cooldown_ratio(loop_button.skill.id), true)
		loop_button.modulate = Color.WHITE if controller.loop_enabled[i] or loop_button.skill == null \
				else Color(1, 1, 1, 0.4)
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

	## Nút ngựa: mờ đi khi chưa có ngựa. Nút đi theo sáng lên khi đang theo.
	var has_horse: bool = _player.can_toggle_ride()
	## Toggle: sáng = đang cưỡi. Đồng bộ lại mỗi frame vì bấm lúc đang chờ đổi ngựa không đổi được trạng thái.
	_horse_button.set_pressed_no_signal(_player.is_riding())
	_horse_button.modulate = Color.WHITE if has_horse else Color(1, 1, 1, 0.45)
	## Ngồi/nhảy không dùng được khi cưỡi ngựa -> mờ đi; nút ngồi sáng khi đang ngồi.
	_sit_button.set_pressed_no_signal(_player.is_sitting())
	_sit_button.modulate = Color(1, 1, 1, 0.45) if _player.is_riding() else Color.WHITE
	_jump_button.modulate = Color(1, 1, 1, 0.45) if _player.is_riding() else Color.WHITE
	_follow_button.modulate = COLOR_AUTO_ON.lightened(0.5) if _player.is_following() else Color.WHITE

## ---- Ngắm hướng bằng nút chính ----
func _on_main_gui_input(event: InputEvent) -> void:
	if editing_hotbar or _player == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_aiming = false
			_aim_press_pos = event.global_position
		else:
			if _aiming:
				_suppress_main_press = true   ## đã ngắm: lúc thả không bắn thêm 1 phát theo kiểu bấm thường
			_stop_aim()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var v: Vector2 = event.global_position - _aim_press_pos
		if v.length() >= AIM_DEAD_ZONE:
			_aiming = true
			_aim_dir = v.normalized()

func _stop_aim() -> void:
	_aiming = false
	_aim_dir = Vector2.ZERO
	if _player != null and is_instance_valid(_player) and _player.has_method("set_aim"):
		_player.set_aim(Vector2.ZERO)

func _on_main_pressed() -> void:
	if editing_hotbar:
		return
	if _suppress_main_press:
		_suppress_main_press = false
		return
	## Mục tiêu có thể null — skill buff lên mình vẫn thi triển được (xem SectSkillController._try_cast).
	var target: Node2D = _player.get_cast_target(_main_button.skill)
	if _player.skill_controller.try_cast_main(_player, target):
		_player.play_cast()

func _on_sub_pressed(index: int) -> void:
	if editing_hotbar:
		return
	var target: Node2D = _player.get_cast_target(_sub_buttons[index].skill)
	if _player.skill_controller.try_cast_skill(_page_start() + index, _player, target):
		_player.play_cast()


## Nút tròn kiểu VLTK: ảnh gốc trong assets/ui/toolbar (tools: spr_to_png từ Spr/Ui3/UiToolsControlBar), các frame ghép ngang —
## `normal_frame` lúc thường, `active_frame` lúc rê chuột/đang bật. Bỏ chữ, khung vuông 56x56.
func _style_round_button(button: Button, sheet_name: String, normal_frame: int, active_frame: int) -> void:
	var sheet: Texture2D = load("res://assets/ui/toolbar/%s.png" % sheet_name)
	if sheet == null:
		return
	var frames := maxi(1, sheet.get_width() / sheet.get_height())  ## các frame đều vuông, ghép ngang
	var frame_w := sheet.get_width() / frames
	var make := func(frame: int) -> StyleBoxTexture:
		var box := StyleBoxTexture.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(minf(frame, frames - 1) * frame_w, 0, frame_w, sheet.get_height())
		box.texture = atlas
		return box
	button.text = ""
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_stylebox_override("normal", make.call(normal_frame))
	button.add_theme_stylebox_override("hover", make.call(active_frame if button.toggle_mode == false else normal_frame))
	button.add_theme_stylebox_override("pressed", make.call(active_frame))
	button.add_theme_stylebox_override("hover_pressed", make.call(active_frame))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.offset_left = -408.0
	button.offset_right = -352.0
	button.offset_bottom = button.offset_top + 56.0
