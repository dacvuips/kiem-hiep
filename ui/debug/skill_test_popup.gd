extends PanelContainer
class_name SkillTestPopup
## BẢNG TỔNG HỢP SKILL ĐỂ THỬ: mọi skill của cả 10 phái, PHÂN THEO PHÁI (hàng nút chọn phái ở trên, "Tất cả" thì mỗi phái
## 1 mục riêng), mỗi skill 1 ô có ảnh + tên. Bấm vào 1 skill -> trang tuỳ chọn: thông tin (hệ, tầm, hạn chế vũ khí/ngựa, bộ máy
## chiêu đang dùng), chọn cấp, THI TRIỂN NGAY (bỏ qua yêu cầu học/vũ khí/ngựa/hồi chiêu), lặp lại tự động, và tạo
## "bia" = quái đứng yên trước mặt để đánh thử. Không tạm dừng trận. Cấp chọn ở đây chỉ dùng cho lần thi triển đó —
## không ghi vào cấp skill đã học của nhân vật.

## Popup hẹp, ghim sát lề TRÁI để còn thấy trận đấu bên phải khi thử skill.
const PANEL_WIDTH := 310.0
const PANEL_HEIGHT := 540.0
const COLUMNS := 4
const CELL_SIZE := Vector2(68, 80)
const ICON_SIZE := 40.0
const REPEAT_SECONDS := 1.5
const DUMMY_DEFAULT_MONSTER := 43   ## Heo trắng
const DUMMY_LEVEL := 30

var _sects: Array[SectDefinition] = []
var _tab_buttons: Array[Button] = []
var _selected_sect: String = ""     ## "" = tất cả các phái
var _search: LineEdit
var _only_active: CheckBox
var _list_box: VBoxContainer
var _count_label: Label
var _grid_page: VBoxContainer
var _detail_page: VBoxContainer
var _detail_title: Label
var _detail_icon: TextureRect
var _info: RichTextLabel
var _level_spin: SpinBox
var _ignore_check: CheckBox
var _repeat_check: CheckBox
var _dummy_count: SpinBox
var _dummy_attack: CheckBox
var _dummy_series: OptionButton
var _dummy_filter: LineEdit
var _dummy_pick: OptionButton
var _status: Label
var _timer: Timer
var _skill: SkillDefinition
var _dummies: Array = []

func _ready() -> void:
	add_to_group(UiPopups.GROUP)   ## đang mở thì lăn chuột không zoom camera
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(24, 60)
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.96)
	style.border_color = Color(0.85, 0.7, 0.38)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	_sects = SectRegistry.load_all()
	## Mở sẵn phái của người chơi.
	var profile := GameManager.local_profile
	if profile != null and SectRegistry.get_by_id(profile.sect_id) != null:
		_selected_sect = profile.sect_id
	_timer = Timer.new()
	_timer.wait_time = REPEAT_SECONDS
	_timer.timeout.connect(_on_repeat)
	add_child(_timer)
	_build()
	_refresh_tabs()
	_refresh_list()
	visibility_changed.connect(_on_visibility_changed)

## Kéo thanh tiêu đề để dời bảng; luôn giữ trong màn hình.
var _dragging := false

func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var limit := get_viewport_rect().size - size
		position = (position + event.relative).clamp(Vector2.ZERO, limit.max(Vector2.ZERO))

func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_STOP
	title_row.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_row.tooltip_text = "Kéo thanh tiêu đề để di chuyển bảng"
	title_row.gui_input.connect(_on_title_input)
	root.add_child(title_row)
	var title := Label.new()
	title.text = "Bảng skill — thử nghiệm"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	title_row.add_child(title)
	var close := Button.new()
	close.text = "Đóng"
	close.pressed.connect(hide)
	title_row.add_child(close)

	_build_grid_page(root)
	_build_detail_page(root)
	_detail_page.visible = false

# ---------------------------------------------------------------- trang 1: chọn phái + lưới skill

func _build_grid_page(root: VBoxContainer) -> void:
	_grid_page = VBoxContainer.new()
	_grid_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_page.add_theme_constant_override("separation", 6)
	root.add_child(_grid_page)

	## Hàng nút chọn phái: "Tất cả" + 10 phái.
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	_grid_page.add_child(tabs)
	var all_tab := Button.new()
	all_tab.text = "Tất cả"
	all_tab.toggle_mode = true
	all_tab.pressed.connect(_select_sect.bind(""))
	tabs.add_child(all_tab)
	_tab_buttons.append(all_tab)
	for sect in _sects:
		var b := Button.new()
		b.text = sect.sect_name
		b.toggle_mode = true
		b.pressed.connect(_select_sect.bind(sect.id))
		tabs.add_child(b)
		_tab_buttons.append(b)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	_grid_page.add_child(filters)
	_search = LineEdit.new()
	_search.placeholder_text = "Tìm theo tên skill…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _refresh_list())
	filters.add_child(_search)
	_only_active = CheckBox.new()
	_only_active.text = "Chỉ skill thi triển được"
	_only_active.button_pressed = true
	_only_active.toggled.connect(func(_on: bool) -> void: _refresh_list())
	filters.add_child(_only_active)
	_count_label = Label.new()
	filters.add_child(_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_page.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_list_box)

func _select_sect(sect_id: String) -> void:
	_selected_sect = sect_id
	_refresh_tabs()
	_refresh_list()

func _refresh_tabs() -> void:
	for i in _tab_buttons.size():
		var sect_id := "" if i == 0 else _sects[i - 1].id
		_tab_buttons[i].set_pressed_no_signal(sect_id == _selected_sect)

## Dựng lại danh sách: mỗi phái 1 mục (tiêu đề + lưới ô skill) theo bộ lọc.
func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	var needle := _search.text.strip_edges().to_lower()
	var total := 0
	for sect in _sects:
		if _selected_sect != "" and sect.id != _selected_sect:
			continue
		var skills: Array[SkillDefinition] = []
		for skill in sect.skills:
			if skill.is_hidden:
				continue
			if _only_active.button_pressed and (skill.category != SkillDefinition.SkillCategory.ACTIVE or not skill.is_active):
				continue
			if needle != "" and not skill.skill_name.to_lower().contains(needle):
				continue
			skills.append(skill)
		if skills.is_empty():
			continue
		total += skills.size()
		var header := Label.new()
		header.text = "%s  (%d)" % [sect.sect_name, skills.size()]
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", ElementTypes.ELEMENT_COLOR.get(sect.element, Color(1, 0.88, 0.55)))
		_list_box.add_child(header)
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_list_box.add_child(grid)
		for skill in skills:
			grid.add_child(_make_cell(skill, sect))
	_count_label.text = "%d skill" % total

func _make_cell(skill: SkillDefinition, sect: SectDefinition) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.focus_mode = Control.FOCUS_NONE
	cell.tooltip_text = "%s · %s" % [sect.sect_name, skill.skill_name]
	cell.pressed.connect(_open_detail.bind(skill, sect))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	cell.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = skill.icon
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label := Label.new()
	label.text = skill.skill_name
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return cell

# ---------------------------------------------------------------- trang 2: tuỳ chọn của 1 skill

func _build_detail_page(root: VBoxContainer) -> void:
	_detail_page = VBoxContainer.new()
	_detail_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_page.add_theme_constant_override("separation", 8)
	root.add_child(_detail_page)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_detail_page.add_child(head)
	var back := Button.new()
	back.text = "◀ Danh sách"
	back.pressed.connect(_back_to_list)
	head.add_child(back)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(36, 36)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_detail_icon)
	_detail_title = Label.new()
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.add_theme_font_size_override("font_size", 15)
	_detail_title.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	head.add_child(_detail_title)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.custom_minimum_size = Vector2(0, 110)
	_info.add_theme_font_size_override("normal_font_size", 13)
	_detail_page.add_child(_info)

	var cast_row := HFlowContainer.new()
	cast_row.add_theme_constant_override("separation", 8)
	_detail_page.add_child(cast_row)
	var level_caption := Label.new()
	level_caption.text = "Cấp"
	cast_row.add_child(level_caption)
	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 30
	_level_spin.value = 10
	cast_row.add_child(_level_spin)
	var cast := Button.new()
	cast.text = "Thi triển"
	cast.pressed.connect(_cast)
	cast_row.add_child(cast)
	_repeat_check = CheckBox.new()
	_repeat_check.text = "Lặp lại mỗi %.1f giây" % REPEAT_SECONDS
	_repeat_check.toggled.connect(_on_repeat_toggled)
	cast_row.add_child(_repeat_check)
	_ignore_check = CheckBox.new()
	_ignore_check.text = "Bỏ qua hạn chế vũ khí / ngựa / hồi chiêu"
	_ignore_check.button_pressed = true
	_detail_page.add_child(_ignore_check)

	var dummy_title := Label.new()
	dummy_title.text = "Bia — chọn quái:"
	_detail_page.add_child(dummy_title)
	_dummy_filter = LineEdit.new()
	_dummy_filter.placeholder_text = "Gõ tên quái để lọc…"
	_dummy_filter.clear_button_enabled = true
	_dummy_filter.text_changed.connect(func(_t: String) -> void: _fill_dummy_picker())
	_detail_page.add_child(_dummy_filter)
	_dummy_pick = OptionButton.new()
	_dummy_pick.fit_to_longest_item = false
	_dummy_pick.clip_text = true
	_detail_page.add_child(_dummy_pick)
	_fill_dummy_picker()
	var opt_row := HFlowContainer.new()
	opt_row.add_theme_constant_override("h_separation", 8)
	_detail_page.add_child(opt_row)
	var series_caption := Label.new()
	series_caption.text = "Hệ của quái"
	opt_row.add_child(series_caption)
	_dummy_series = OptionButton.new()
	_dummy_series.add_item("Theo quái gốc", -1)
	for e in ElementTypes.ELEMENT_NAME:
		_dummy_series.add_item(str(ElementTypes.ELEMENT_NAME[e]), int(e))
	opt_row.add_child(_dummy_series)
	_dummy_attack = CheckBox.new()
	_dummy_attack.text = "Cho quái tấn công"
	opt_row.add_child(_dummy_attack)
	var dummy_row := HFlowContainer.new()
	dummy_row.add_theme_constant_override("h_separation", 8)
	_detail_page.add_child(dummy_row)
	var count_caption := Label.new()
	count_caption.text = "Số lượng"
	dummy_row.add_child(count_caption)
	_dummy_count = SpinBox.new()
	_dummy_count.min_value = 1
	_dummy_count.max_value = 30
	_dummy_count.value = 3
	dummy_row.add_child(_dummy_count)
	var spawn := Button.new()
	spawn.text = "Tạo bia"
	spawn.pressed.connect(_spawn_dummies)
	dummy_row.add_child(spawn)
	var clear := Button.new()
	clear.text = "Xoá bia"
	clear.pressed.connect(_clear_dummies)
	dummy_row.add_child(clear)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_detail_page.add_child(_status)

func _open_detail(skill: SkillDefinition, sect: SectDefinition) -> void:
	_skill = skill
	_status.text = ""
	_repeat_check.button_pressed = false
	_level_spin.max_value = maxi(skill.max_level, 20)
	_level_spin.value = mini(maxi(skill.max_level, 1), 10)
	_detail_icon.texture = skill.icon
	_detail_title.text = "%s · %s" % [sect.sect_name, skill.skill_name]
	_info.text = _info_text(skill)
	_grid_page.visible = false
	_detail_page.visible = true

func _back_to_list() -> void:
	_repeat_check.button_pressed = false
	_detail_page.visible = false
	_grid_page.visible = true

func _info_text(skill: SkillDefinition) -> String:
	var lines := PackedStringArray()
	lines.append("[color=#ffe08c]%s[/color]  ·  hệ %s  ·  %s" % [skill.skill_name,
			ElementTypes.element_to_string(skill.element),
			"Chủ động" if skill.category == SkillDefinition.SkillCategory.ACTIVE else "Nội tại / bị động"])
	if skill.description != "":
		lines.append(skill.description)
	var targets := PackedStringArray()
	if skill.target_enemy:
		targets.append("địch")
	if skill.target_ally:
		targets.append("đồng đội")
	if skill.target_self:
		targets.append("bản thân")
	lines.append("Nhắm: %s%s  ·  hồi chiêu %.1fs  ·  tầm %d" % [", ".join(targets) if not targets.is_empty() else "—",
			" (hào quang bật/tắt)" if skill.is_aura else "", skill.cooldown, skill.vltk_attack_radius])
	var weapon_text := skill.get_weapon_limit_bbcode()
	if weapon_text != "":
		lines.append(weapon_text)
	if skill.horse_limit == 1:
		lines.append("Không thi triển được khi cưỡi ngựa")
	elif skill.horse_limit == 2:
		lines.append("Chỉ thi triển được khi cưỡi ngựa")
	lines.append(_engine_text(skill))
	return "\n".join(lines)

## Skill này chạy bằng bộ máy chiêu VLTK gốc hay đường cũ.
func _engine_text(skill: SkillDefinition) -> String:
	if skill.vltk_skill_id <= 0:
		return "[color=#c0a060]Chưa gắn mã skill VLTK — chạy bằng đường cũ (đạn đơn giản).[/color]"
	var level := int(_level_spin.value) if _level_spin != null else 1
	var data := VltkSkillData.skill(skill.vltk_skill_id, level)
	if data.is_empty():
		return "[color=#c0a060]Mã VLTK #%d, chưa có dữ liệu hiệu ứng — chạy bằng đường cũ.[/color]" % skill.vltk_skill_id
	var path := "bộ máy chiêu VLTK" if VltkSkillRunner.supports(skill, level) else "đường buff/bùa/hào quang (có ảnh xuất chiêu + hình trạng thái)"
	return "Mã VLTK #%d · kiểu %d · đội hình %d · chạy bằng %s" % [skill.vltk_skill_id, int(data.get("style", 0)),
			int(data.get("form", 0)), path]

# ---------------------------------------------------------------- thi triển

func _cast() -> void:
	if _skill == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	var profile := GameManager.local_profile
	if player == null or profile == null:
		_status.text = "Không tìm thấy người chơi."
		return
	var sc: SectSkillController = player.skill_controller
	var skill := _skill
	## Chỉ trong lúc thi triển: đặt cấp đã chọn, bỏ hạn chế, xoá hồi chiêu — rồi trả lại nguyên trạng (không đổi cấp đã học).
	var had_level := profile.skill_levels.has(skill.id)
	var old_level := int(profile.skill_levels.get(skill.id, 0))
	var old_weapon := skill.weapon_limit
	var old_horse := skill.horse_limit
	profile.skill_levels[skill.id] = int(_level_spin.value)
	if _ignore_check.button_pressed:
		skill.weapon_limit = -2
		skill.horse_limit = 0
		sc._cooldowns.erase(skill.id)
	var target: Node2D = player.get_cast_target(skill)
	var ok: bool = sc._try_cast(skill, player, target)
	skill.weapon_limit = old_weapon
	skill.horse_limit = old_horse
	if had_level:
		profile.skill_levels[skill.id] = old_level
	else:
		profile.skill_levels.erase(skill.id)
	if ok:
		player.play_cast()
	_status.text = "Đã thi triển cấp %d." % int(_level_spin.value) if ok else "Không thi triển được (đang bận, hồi chiêu, choáng...)."
	_info.text = _info_text(skill)

func _on_repeat_toggled(on: bool) -> void:
	if on:
		_timer.start()
		_cast()
	else:
		_timer.stop()

func _on_repeat() -> void:
	if visible and _detail_page.visible and _repeat_check.button_pressed:
		_cast()

func _on_visibility_changed() -> void:
	if not visible:
		_repeat_check.button_pressed = false
		_timer.stop()

# ---------------------------------------------------------------- bia (quái đứng yên)

## Danh sách quái để chọn (lọc theo tên); giữ lại quái đang chọn nếu còn nằm trong kết quả lọc.
func _fill_dummy_picker() -> void:
	var keep := _dummy_id() if _dummy_pick.item_count > 0 else DUMMY_DEFAULT_MONSTER
	var filter := _dummy_filter.text.strip_edges().to_lower()
	_dummy_pick.clear()
	for m in MonsterData.all():
		var name_text := str(m.get("name", ""))
		if filter != "" and not name_text.to_lower().contains(filter):
			continue
		var id := int(m.get("id", 0))
		_dummy_pick.add_item("%s  (#%d)" % [name_text, id], id)
		if id == keep:
			_dummy_pick.select(_dummy_pick.item_count - 1)

func _dummy_id() -> int:
	return _dummy_pick.get_selected_id() if _dummy_pick != null and _dummy_pick.item_count > 0 else DUMMY_DEFAULT_MONSTER

func _spawn_dummies() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_status.text = "Không tìm thấy người chơi."
		return
	var monster_id := _dummy_id()
	if MonsterData.monster(monster_id).is_empty():
		_status.text = "Không có quái số %d." % monster_id
		return
	_prune_dummies()
	var radius_px := _skill.get_attack_radius_at_level(1) if _skill != null else 200.0
	var distance := clampf(radius_px * 0.6, 110.0, 380.0)
	var forward: Vector2 = player.last_direction.normalized()
	var side := forward.orthogonal()
	var count := int(_dummy_count.value)
	var created := 0
	for i in count:
		var spread := (float(i) - float(count - 1) * 0.5) * 55.0
		var pos: Vector2 = player.global_position + forward * distance + side * spread
		var dummy := VltkMonster.spawn(player.get_parent(), monster_id, DUMMY_LEVEL, pos, _dummy_attack.button_pressed, _dummy_series.get_selected_id())
		if dummy != null:
			_dummies.append(dummy)
			created += 1
	_status.text = "Đã tạo %d bia trước mặt (cách %d)%s%s." % [created, int(distance), ", hệ " + _dummy_series.get_item_text(_dummy_series.selected) if _dummy_series.get_selected_id() >= 0 else "", ", biết tấn công" if _dummy_attack.button_pressed else ""]

func _prune_dummies() -> void:
	_dummies = _dummies.filter(func(m: Variant) -> bool: return is_instance_valid(m))

func _clear_dummies() -> void:
	_prune_dummies()
	var removed := _dummies.size()
	for m in _dummies:
		m.queue_free()
	_dummies.clear()
	_status.text = "Đã xoá %d bia." % removed
