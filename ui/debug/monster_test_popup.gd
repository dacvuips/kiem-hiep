extends PanelContainer
class_name MonsterTestPopup
## POPUP THỬ QUÁI VLTK. Mở ra là LƯỚI HÌNH mọi quái gốc (tìm theo tên/số/bộ hình); bấm vào 1 quái mới hiện các TUỲ CHỌN:
## xem trước từng động tác (đứng, đi, đánh, phép, bị đánh, chết) xoay 8 hướng, thông tin/skill, và TẠO quái quanh người chơi
## với số lượng/cấp tuỳ chọn để thử thật (đi thế nào, đánh bằng skill gì, bị skill của người chơi đánh/chết ra sao).
## Không tạm dừng trận. Dữ liệu: MonsterData (tools/import_vltk_monsters.py), quái chạy thật: VltkMonster.

const PREVIEW_SIZE := Vector2i(260, 180)
const PREVIEW_HOLD_FRAMES := 12.0
const MAX_ALIVE := 300
const COLUMNS := 6
const CELL_SIZE := Vector2(104, 128)
const THUMB_SIZE := 84.0
const CELLS_PER_FRAME := 40       ## dựng lưới dần qua nhiều frame cho khỏi khựng khi mở
const ACTIONS := [["Đứng", "stand"], ["Đi", "walk"], ["Chạy", "run"], ["Đánh 1", "attack1"], ["Đánh 2", "attack2"],
		["Phép", "magic"], ["Bị đánh", "hurt"], ["Chết", "die"]]

var _grid_page: VBoxContainer
var _detail_page: VBoxContainer
var _tab_container: HBoxContainer
var _tab_all_btn: Button
var _tab_gold_btn: Button
var _tab_small_btn: Button
var _current_tab: int = 0 ## 0: All, 1: Gold Boss, 2: Small Gold & Killer
var _search: LineEdit
var _grid: GridContainer
var _count_label: Label
var _detail_title: Label
var _info: Label
var _status: Label
var _count_spin: SpinBox
var _level_spin: SpinBox
var _still_check: CheckBox
var _preview: MonsterSprite
var _shown: Array = []          ## quái đang lọc, theo thứ tự lưới
var _queue_index: int = 0       ## đã dựng tới đâu trong _shown
var _selected_id: int = -1
var _pv_action: String = "stand"
var _pv_dir64: int = 0
var _pv_frames: float = 0.0
var _spawned: Array = []        ## quái đã tạo từ popup (để xoá)

func _ready() -> void:
	add_to_group(UiPopups.GROUP)   ## đang mở thì lăn chuột không zoom camera
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	## Chiếm gần hết màn hình (lề 24px) — luôn vừa cửa sổ dù nhỏ.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	custom_minimum_size = Vector2(560, 360)
	clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.96)
	style.border_color = Color(0.85, 0.7, 0.38)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	_build()
	_refresh_grid("")

func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := Label.new()
	title.text = "Quái & Boss VLTK — thử nghiệm"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	title_row.add_child(title)
	var close := Button.new()
	close.text = "Đóng"
	close.pressed.connect(hide)
	title_row.add_child(close)

	_build_grid_page(root)
	_build_detail_page(root)
	_detail_page.visible = false

# ---------------------------------------------------------------- trang 1: lưới hình

func _build_grid_page(root: VBoxContainer) -> void:
	_grid_page = VBoxContainer.new()
	_grid_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_page.add_theme_constant_override("separation", 6)
	root.add_child(_grid_page)

	# Tab bar chuyển danh mục: Tất cả quái | Boss Hoàng Kim | Tiểu Hoàng Kim & Sát Thủ
	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 8)
	_grid_page.add_child(_tab_container)

	_tab_all_btn = _make_tab_button("Tất cả quái", 0)
	_tab_gold_btn = _make_tab_button("★ Boss Hoàng Kim", 1)
	_tab_small_btn = _make_tab_button("Tiểu Hoàng Kim & Sát Thủ", 2)
	_tab_container.add_child(_tab_all_btn)
	_tab_container.add_child(_tab_gold_btn)
	_tab_container.add_child(_tab_small_btn)
	_update_tab_styles()

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_grid_page.add_child(top)
	_search = LineEdit.new()
	_search.placeholder_text = "Tìm theo tên / số thứ tự / bộ hình…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_refresh_grid)
	top.add_child(_search)
	_count_label = Label.new()
	top.add_child(_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_page.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

func _make_tab_button(tab_text: String, tab_id: int) -> Button:
	var btn := Button.new()
	btn.text = tab_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_switch_tab.bind(tab_id))
	return btn

func _switch_tab(tab_id: int) -> void:
	if _current_tab == tab_id:
		return
	_current_tab = tab_id
	_update_tab_styles()
	_refresh_grid(_search.text if _search else "")

func _update_tab_styles() -> void:
	var tabs := [_tab_all_btn, _tab_gold_btn, _tab_small_btn]
	for i in range(tabs.size()):
		var b := tabs[i] as Button
		if b == null:
			continue
		if i == _current_tab:
			b.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		else:
			b.remove_theme_color_override("font_color")

func _refresh_grid(filter: String) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_shown.clear()
	_queue_index = 0
	var needle := filter.strip_edges().to_lower()

	for m in MonsterData.all():
		var id := int(m["id"])
		var raw: Dictionary = MonsterData.monster(id)
		var b_type := str(raw.get("boss_type", ""))

		# Lọc theo Tab đang chọn
		if _current_tab == 1:
			# Tab Boss Hoàng Kim
			if b_type != "gold":
				continue
		elif _current_tab == 2:
			# Tab Tiểu Hoàng Kim & Sát Thủ
			if b_type != "small_gold" and b_type != "killer":
				continue

		var sect := str(raw.get("sect", ""))
		var title := str(raw.get("title", ""))
		var hay := ("%d %s %s %s %s" % [m["id"], m["name"], m["res"], sect, title]).to_lower()
		if needle == "" or hay.contains(needle):
			_shown.append(m)

	var tab_names := ["quái", "Boss Hoàng Kim", "Tiểu Hoàng Kim & Sát Thủ"]
	_count_label.text = "%d %s" % [_shown.size(), tab_names[_current_tab]]
	if not MonsterData.has_data():
		_count_label.text = "Chưa có dữ liệu quái — chạy tools/import_vltk_monsters.py"

## Dựng ô lưới dần (CELLS_PER_FRAME ô mỗi frame) để mở popup không bị khựng với ~1200 quái.
func _process(delta: float) -> void:
	if _grid_page.visible and _queue_index < _shown.size():
		var end := mini(_queue_index + CELLS_PER_FRAME, _shown.size())
		for i in range(_queue_index, end):
			_grid.add_child(_make_cell(_shown[i]))
		_queue_index = end
	if _detail_page.visible and visible and _selected_id >= 0:
		_tick_preview(delta)

func _make_cell(m: Dictionary) -> Button:
	var id := int(m["id"])
	var raw := MonsterData.monster(id)
	var b_type := str(raw.get("boss_type", ""))
	var is_gold := b_type == "gold"
	var is_small_gold := b_type == "small_gold"

	var cell := Button.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.focus_mode = Control.FOCUS_NONE

	var tooltip := "#%d %s · %s" % [m["id"], m["name"], m["res"]]
	if str(raw.get("sect", "")) != "":
		tooltip += " · Môn phái: %s" % raw["sect"]
	if str(raw.get("title", "")) != "":
		tooltip += " (%s)" % raw["title"]
	cell.tooltip_text = tooltip
	cell.pressed.connect(_open_detail.bind(id))

	if is_gold:
		var gold_style := StyleBoxFlat.new()
		gold_style.bg_color = Color(0.18, 0.14, 0.05, 0.8)
		gold_style.border_color = Color(0.98, 0.82, 0.25, 0.9)
		gold_style.set_border_width_all(2)
		gold_style.set_corner_radius_all(6)
		cell.add_theme_stylebox_override("normal", gold_style)
	elif is_small_gold:
		var small_style := StyleBoxFlat.new()
		small_style.bg_color = Color(0.1, 0.14, 0.18, 0.8)
		small_style.border_color = Color(0.35, 0.75, 0.95, 0.9)
		small_style.set_border_width_all(2)
		small_style.set_corner_radius_all(6)
		cell.add_theme_stylebox_override("normal", small_style)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	cell.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.texture = MonsterData.thumb(str(m["res"]))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var label := Label.new()
	label.text = "%d · %s" % [m["id"], m["name"]]
	label.add_theme_font_size_override("font_size", 11)
	if is_gold:
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	elif is_small_gold:
		label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return cell

# ---------------------------------------------------------------- trang 2: tuỳ chọn của 1 quái

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
	back.pressed.connect(_back_to_grid)
	head.add_child(back)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 17)
	_detail_title.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	head.add_child(_detail_title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	_detail_page.add_child(body)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	container.stretch = true
	left.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.18, 0.2, 0.17)
	backdrop.size = Vector2(PREVIEW_SIZE)
	viewport.add_child(backdrop)
	_preview = MonsterSprite.new()
	_preview.position = Vector2(PREVIEW_SIZE.x * 0.5, 150.0)
	viewport.add_child(_preview)

	var action_row := HFlowContainer.new()
	left.add_child(action_row)
	for entry in ACTIONS:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(_set_preview_action.bind(entry[1]))
		action_row.add_child(b)
	var turn_left := Button.new()
	turn_left.text = "◀"
	turn_left.tooltip_text = "Xoay hướng"
	turn_left.pressed.connect(_turn_preview.bind(-8))
	action_row.add_child(turn_left)
	var turn_right := Button.new()
	turn_right.text = "▶"
	turn_right.tooltip_text = "Xoay hướng"
	turn_right.pressed.connect(_turn_preview.bind(8))
	action_row.add_child(turn_right)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.custom_minimum_size = Vector2(0, 40)
	_info.clip_text = true
	_info.add_theme_font_size_override("font_size", 13)
	right.add_child(_info)

	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override("separation", 8)
	right.add_child(spawn_row)
	var count_caption := Label.new()
	count_caption.text = "Số lượng"
	spawn_row.add_child(count_caption)
	_count_spin = SpinBox.new()
	_count_spin.min_value = 1
	_count_spin.max_value = 100
	_count_spin.value = 1
	spawn_row.add_child(_count_spin)
	var level_caption := Label.new()
	level_caption.text = "Cấp"
	spawn_row.add_child(level_caption)
	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 150
	_level_spin.value = 10
	spawn_row.add_child(_level_spin)
	_still_check = CheckBox.new()
	_still_check.text = "Đứng yên (tắt AI)"
	right.add_child(_still_check)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)
	var spawn := Button.new()
	spawn.text = "Tạo quái quanh người chơi"
	spawn.pressed.connect(_spawn)
	buttons.add_child(spawn)
	var clear := Button.new()
	clear.text = "Xoá quái đã tạo"
	clear.pressed.connect(_clear_spawned)
	buttons.add_child(clear)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	right.add_child(_status)

func _open_detail(id: int) -> void:
	_selected_id = id
	var m := MonsterData.monster(id)
	_preview.set_resource(str(m.get("res", "")))
	_pv_frames = 0.0
	_pv_action = "stand"
	_status.text = ""
	_detail_title.text = "#%d  %s" % [id, m.get("name", "")]
	_show_info(m)
	_grid_page.visible = false
	_detail_page.visible = true

func _back_to_grid() -> void:
	_detail_page.visible = false
	_grid_page.visible = true

func _show_info(m: Dictionary) -> void:
	var skills := []
	for slot in 4:
		var sk: Array = m["skills"][slot]
		if int(sk[0]) > 0:
			var s := VltkSkillData.skill(int(sk[0]), int(sk[1]))
			var name_text: String = str(s.get("name", "")) if not s.is_empty() else "chưa có dữ liệu"
			skills.append("%d) #%d %s (tầm %s)" % [slot + 1, int(sk[0]), name_text, str(s.get("attack_radius", "?"))])
	
	var boss_header := ""
	var b_type := str(m.get("boss_type", ""))
	if b_type == "gold":
		boss_header = "★ [ĐẠI BOSS HOÀNG KIM]"
	elif b_type == "small_gold":
		boss_header = "◆ [TIỂU HOÀNG KIM]"
	elif b_type == "killer":
		boss_header = "⚔ [BOSS SÁT THỦ]"
	
	if str(m.get("sect", "")) != "":
		boss_header += " · Phái: %s" % m["sect"]
	if str(m.get("title", "")) != "":
		boss_header += " · Danh hiệu: %s" % m["title"]
	if boss_header != "":
		boss_header += "\n"

	_info.text = "%sBộ hình %s · hệ %s\nTốc độ đi %d · chạy %d · tầm nhìn %d · vùng hoạt động %d · AI loại %d\nKỹ năng:\n  %s" % [
			boss_header,
			m["res"], ElementTypes.element_to_string(clampi(int(m["series"]), 0, 4) as ElementTypes.ElementType),
			int(m["walk_speed"]), int(m["run_speed"]), int(m["vision"]), int(m["active"]), int(m["ai_mode"]),
			"\n  ".join(skills) if not skills.is_empty() else "(không có)"]

# ---------------------------------------------------------------- xem trước

func _set_preview_action(action_name: String) -> void:
	_pv_action = action_name
	_pv_frames = 0.0

func _turn_preview(step: int) -> void:
	_pv_dir64 = wrapi(_pv_dir64 + step, 0, VltkMath.MAX_DIR)

func _tick_preview(delta: float) -> void:
	var m := MonsterData.monster(_selected_id)
	var len_frames := float(MonsterData.action_frames(m, _pv_action))
	var looping := _pv_action in ["stand", "walk", "run"]
	_pv_frames += delta * VltkMath.FPS
	var cycle := len_frames if looping else len_frames + PREVIEW_HOLD_FRAMES
	_pv_frames = fmod(_pv_frames, cycle)
	_preview.set_pose(_pv_action, _pv_dir64, minf(_pv_frames, len_frames) / len_frames)

# ---------------------------------------------------------------- tạo / xoá quái thử

func _spawn() -> void:
	if _selected_id < 0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_status.text = "Không tìm thấy người chơi."
		return
	_prune()
	var count := int(_count_spin.value)
	if _spawned.size() + count > MAX_ALIVE:
		count = maxi(0, MAX_ALIVE - _spawned.size())
	var parent: Node = player.get_parent()
	var created := 0
	for i in count:
		## Rải đều trên vòng tròn logic quanh người chơi (dọc nén 1/2 như bản đồ VLTK), vòng ngoài khi số lượng đông.
		var ring := i / 12
		var angle := TAU * float(i % 12) / float(mini(12, count - ring * 12)) + float(ring) * 0.35
		var radius := 280.0 + 70.0 * ring
		var pos: Vector2 = player.global_position + Vector2(cos(angle) * radius, sin(angle) * radius * 0.5)
		var monster := VltkMonster.spawn(parent, _selected_id, int(_level_spin.value), pos, not _still_check.button_pressed)
		if monster != null:
			_spawned.append(monster)
			created += 1
	_status.text = "Đã tạo %d quái (đang có %d)." % [created, _spawned.size()]

func _prune() -> void:
	_spawned = _spawned.filter(func(m: Variant) -> bool: return is_instance_valid(m))

func _clear_spawned() -> void:
	_prune()
	var removed := _spawned.size()
	for m in _spawned:
		m.queue_free()
	_status.text = "Đã xoá %d quái." % removed
	_spawned.clear()
