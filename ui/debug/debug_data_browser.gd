extends CanvasLayer
class_name DebugDataBrowser
## Màn DEBUG (không phải UI cho người chơi) — liệt kê TOÀN BỘ EnemyTierData (enemies/data/) và
## StageData (stages/*/*.tres) đã có trong project, kèm chỉ số thô, để kiểm tra nhanh dữ liệu vừa
## tạo/sửa mà không cần mở từng file .tres trong Editor. Quét thư mục lúc mở màn (không cache) nên
## luôn thấy đúng dữ liệu mới nhất.
##
## MỞ MÀN NÀY: gọi DebugDataBrowser.open(get_tree().root) từ bất kỳ đâu (VD gán tạm 1 phím tắt khi
## debug, hoặc gọi thẳng từ 1 nút debug trong Character Hub — xem hướng dẫn cuối file).

const ENEMY_DATA_DIR := "res://enemies/data/"
const STAGES_DIR := "res://stages/"

const BG := Color(0.05, 0.05, 0.05, 0.92)
const GOLD := Color(0.83, 0.68, 0.21)
const TEXT := Color(0.9, 0.9, 0.88)
const TEXT_DIM := Color(0.6, 0.6, 0.58)

var _on_closed: Callable

## `on_closed` gọi khi bấm nút Đóng — truyền `func() -> void: pass` nếu nơi gọi không cần xử lý gì.
static func open(parent: Node, on_closed: Callable) -> void:
	var screen := DebugDataBrowser.new()
	screen._on_closed = on_closed
	parent.add_child(screen)

func _ready() -> void:
	layer = 100  ## Trên cùng mọi UI khác kể cả popup skill/detail, vì đây là debug overlay.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	dim.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "[DEBUG] Danh sách Quái & Map"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(title)

	var close_button := Button.new()
	close_button.text = "Đóng"
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.pressed.connect(func():
		_on_closed.call()
		queue_free()
	)
	vbox.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	_build_enemy_section(content)
	_build_stage_section(content)

## ---------------------------------------------------------------- Quái

func _build_enemy_section(parent: VBoxContainer) -> void:
	var tiers := _scan_enemy_tiers()
	parent.add_child(_section_header("QUÁI (%d loại) — %s" % [tiers.size(), ENEMY_DATA_DIR]))

	if tiers.is_empty():
		parent.add_child(_dim_label("(không tìm thấy file EnemyTierData nào)"))
		return

	var header := HBoxContainer.new()
	for col_text in ["Tên", "Lv", "Hệ", "STR", "DEX", "VIT", "ENG", "HP", "AR", "DEF", "Dmg", "Tốc độ", "Chạm"]:
		header.add_child(_header_cell(col_text))
	parent.add_child(header)

	for tier in tiers:
		parent.add_child(_enemy_row(tier))

func _enemy_row(tier: EnemyTierData) -> HBoxContainer:
	## Bảng "QUÁI" hiện chỉ số GỐC (chưa nhân theo map) — bọc tạm 1 EnemySpawnEntry với multiplier
	## mặc định (1.0) để dùng chung công thức CombatantStats.from_enemy_tier(), tránh viết trùng
	## logic tính HP/AttackRating/Defense ở 2 nơi khác nhau.
	var identity_entry := EnemySpawnEntry.new()
	identity_entry.tier = tier
	var stats := CombatantStats.from_enemy_tier(identity_entry)
	var row := HBoxContainer.new()
	var values := [
		tier.tier_name if not tier.tier_name.is_empty() else "(chưa đặt tên)",
		str(tier.level),
		ElementTypes.ELEMENT_NAME.get(tier.element, "?"),
		str(tier.strength), str(tier.dexterity), str(tier.vitality), str(tier.energy),
		str(stats.max_hp), str(stats.attack_rating), str(stats.defense),
		"%d-%d" % [stats.unarmed_min_damage, stats.unarmed_max_damage],
		str(tier.speed), str(tier.contact_damage),
	]
	for v in values:
		row.add_child(_data_cell(str(v)))
	return row

## Quét TOÀN BỘ file .tres trong enemies/data/ (không đệ quy thư mục con) — thêm quái mới không
## cần sửa code này, chỉ cần thêm file .tres vào đúng thư mục.
func _scan_enemy_tiers() -> Array[EnemyTierData]:
	var result: Array[EnemyTierData] = []
	var dir := DirAccess.open(ENEMY_DATA_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load(ENEMY_DATA_DIR + file_name)
			if res is EnemyTierData:
				result.append(res)
		file_name = dir.get_next()
	result.sort_custom(func(a: EnemyTierData, b: EnemyTierData): return a.tier_name < b.tier_name)
	return result

## ---------------------------------------------------------------- Map

func _build_stage_section(parent: VBoxContainer) -> void:
	var stages := _scan_stages()
	parent.add_child(_section_header("MAP (%d) — %s*/" % [stages.size(), STAGES_DIR]))

	if stages.is_empty():
		parent.add_child(_dim_label("(không tìm thấy file StageData nào)"))
		return

	for stage in stages:
		parent.add_child(_stage_block(stage))

func _stage_block(stage: StageData) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = "▸ %s   (thời lượng: %ds, boss: %s)" % [
		stage.stage_name, int(stage.stage_duration),
		stage.boss_tier.tier.tier_name if stage.boss_tier and stage.boss_tier.tier else "—",
	]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", GOLD)
	block.add_child(name_label)

	if stage.enemy_tiers.is_empty():
		block.add_child(_dim_label("   (chưa gắn quái nào)"))
	else:
		for entry in stage.enemy_tiers:
			block.add_child(_spawn_entry_line(entry))

	return block

## 1 dòng cho 1 EnemySpawnEntry — hiện HP/AttackRating/Defense ĐÃ ÁP hệ số nhân riêng cho map này
## (khác bảng "QUÁI" ở trên vốn hiện chỉ số GỐC chưa nhân) để thấy ngay cùng 1 quái mạnh/yếu khác
## nhau thế nào giữa các map.
func _spawn_entry_line(entry: EnemySpawnEntry) -> Label:
	var line := Label.new()
	if entry.tier == null:
		line.text = "   • (chưa gán EnemyTierData)"
		line.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		line.add_theme_font_size_override("font_size", 13)
		return line

	var stats := CombatantStats.from_enemy_tier(entry)
	line.text = "   • %s  —  HP %d, AR %d, DEF %d  (x%.1f/%.1f/%.1f STR/DEX/VIT)  |  unlock %ds, weight %.1f, đổi %.2f/s" % [
		entry.tier.tier_name, stats.max_hp, stats.attack_rating, stats.defense,
		entry.strength_multiplier, entry.dexterity_multiplier, entry.vitality_multiplier,
		int(entry.unlock_time), entry.spawn_weight, entry.weight_change_per_second,
	]
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", TEXT)
	return line

## Quét TOÀN BỘ file .tres trong stages/ VÀ mọi thư mục con 1 cấp (mỗi map 1 thư mục riêng, xem
## docs/huong_dan_them_quai_va_map.md) — thêm map mới không cần sửa code này.
func _scan_stages() -> Array[StageData]:
	var result: Array[StageData] = []
	_scan_stages_recursive(STAGES_DIR, result)
	result.sort_custom(func(a: StageData, b: StageData): return a.stage_name < b.stage_name)
	return result

func _scan_stages_recursive(path: String, result: Array[StageData]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path + file_name
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_stages_recursive(full_path + "/", result)
		elif file_name.ends_with(".tres"):
			var res: Resource = load(full_path)
			if res is StageData:
				result.append(res)
		file_name = dir.get_next()

## ---------------------------------------------------------------- tiện ích UI

func _section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", GOLD)
	return label

func _header_cell(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 70
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", TEXT_DIM)
	return label

func _data_cell(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 70
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", TEXT)
	return label

func _dim_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", TEXT_DIM)
	return label

## ---------------------------------------------------------------- Cách mở màn này khi debug
##
## Đã gắn sẵn phím F10 (chỉ hoạt động ở debug build, OS.is_debug_build()) tại:
##   - main.gd (trong trận, _unhandled_key_input)
##   - character_hub.gd (ở màn Hub, _unhandled_key_input)
## Muốn mở từ nơi khác, gọi thẳng: DebugDataBrowser.open(self)
