extends Control
class_name DebugCheatPanel
## Nút "TEST" bật/tắt bảng cheat để thử nhanh nhân vật: lên cấp, cộng điểm kỹ năng, tẩy điểm. Điểm
## tiềm năng KHÔNG có nút cộng riêng — chỉ nhận qua lên cấp (PlayerProfile.level_up), đúng luật game.
## Chỉ hiện ở debug build (chạy từ editor / bản export debug) — bản release tự ẩn hoàn toàn.
##
## Bố cục (vị trí nút, các hàng, hộp xác nhận) dựng sẵn trong DebugCheatPanel.tscn, kéo chỉnh được
## trong editor. Mọi thay đổi ghi thẳng vào GameManager.local_profile rồi lưu save, sau đó phát
## profile_changed để màn chứa (CharacterHub) vẽ lại số liệu.

signal profile_changed

@onready var _toggle_button: Button = %ToggleButton
@onready var _cheat_box: Control = %CheatBox
@onready var _level_label: Label = %LevelLabel
@onready var _skill_points_label: Label = %SkillPointsLabel
@onready var _result_label: Label = %ResultLabel
@onready var _reset_confirm: ConfirmationDialog = %ResetConfirm

func _ready() -> void:
	if not AccountApi.is_gm():
		queue_free()
		return
	visible = true
	_cheat_box.visible = false
	_toggle_button.toggled.connect(func(on: bool) -> void:
		_cheat_box.visible = on
		_result_label.visible = false
		_refresh())
	%LevelUp1.pressed.connect(_add_levels.bind(1))
	%LevelUp10.pressed.connect(_add_levels.bind(10))
	%LevelReset.pressed.connect(%LevelResetConfirm.popup_centered)
	%LevelResetConfirm.confirmed.connect(_on_level_reset_confirmed)
	if has_node("%AddExp10k"):
		%AddExp10k.pressed.connect(_add_exp.bind(10_000))
	if has_node("%AddExp100k"):
		%AddExp100k.pressed.connect(_add_exp.bind(100_000))
	%SkillPoint1.pressed.connect(_add_skill_points.bind(1))
	%SkillPoint10.pressed.connect(_add_skill_points.bind(10))
	%RandomItem1.pressed.connect(_add_random_items.bind(1))
	%RandomItem10.pressed.connect(_add_random_items.bind(10))
	if has_node("%AddMaskBtn"):
		%AddMaskBtn.pressed.connect(_add_masks)
	if has_node("%AddMantleBtn"):
		%AddMantleBtn.pressed.connect(_add_mantles)
	## Tẩy điểm không hoàn tác được -> hỏi xác nhận trước.
	%ResetButton.pressed.connect(_reset_confirm.popup_centered)
	_reset_confirm.confirmed.connect(_on_reset_confirmed)
	_add_social_row()
	_add_sect_row()

## Hàng nút thử chức năng xã hội (lập bang cần tiền, danh vọng, phúc duyên, cấp lãnh đạo — chưa có nguồn tăng trong game).
func _add_social_row() -> void:
	var rows := get_node_or_null("CheatBox/Rows")
	if rows == null:
		return
	var row := HBoxContainer.new()
	var items := [
		["+20tr", func(p: PlayerProfile) -> void: p.gold += 20_000_000],
		["+Danh vọng/Phúc duyên", func(p: PlayerProfile) -> void:
			p.prestige += 100
			p.fuyuan += 100],
		["+Lãnh đạo", func(p: PlayerProfile) -> void: p.lead_level = mini(p.lead_level + 5, 100)],
	]
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			it[1].call(GameManager.local_profile)
			_commit())
		row.add_child(b)
	rows.add_child(row)

func _add_sect_row() -> void:
	var rows := get_node_or_null("CheatBox/Rows")
	if rows == null:
		return
	var row := HBoxContainer.new()
	var b := Button.new()
	b.text = "Gia nhập / Đổi phái"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_choose_sect_pressed)
	row.add_child(b)
	rows.add_child(row)

func _on_choose_sect_pressed() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	if profile.needs_sect():
		var win := SectChoiceWindow.open(get_parent(), profile)
		win.chosen.connect(func(sect: SectDefinition) -> void:
			_commit()
			_result_label.visible = true
			_result_label.text = "Đã gia nhập môn phái %s." % sect.sect_name
		)
		return
	var popup := PopupMenu.new()
	var sects := SectRegistry.load_all()
	for i in sects.size():
		var s := sects[i]
		var elem_str: String = ElementTypes.ELEMENT_NAME.get(s.element, "")
		popup.add_item("%s (%s)" % [s.sect_name, elem_str], i)
	popup.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < sects.size():
			profile.set_sect(sects[id])
			_commit()
			_result_label.visible = true
			_result_label.text = "Đã đổi môn phái sang %s." % sects[id].sect_name
		popup.queue_free()
	)
	popup.popup_hide.connect(func() -> void: popup.queue_free())
	add_child(popup)
	popup.popup_centered(Vector2i(200, 300))

## Lên cấp qua PlayerProfile.level_up() — nhận điểm kỹ năng/tiềm năng y như lên cấp thật.
func _add_levels(count: int) -> void:
	var profile := GameManager.local_profile
	for i in count:
		profile.level_up()
	_commit()

func _add_exp(amount: int) -> void:
	var profile := GameManager.local_profile
	if profile:
		profile.add_exp(amount)
		_commit()
		_result_label.visible = true
		_result_label.text = "Đã nhận +%d EXP (Cấp %d — %d/%d)." % [amount, profile.level, profile.current_exp, profile.get_exp_to_next_level()]

func _add_skill_points(amount: int) -> void:
	GameManager.local_profile.skill_points += amount
	_commit()

## Đồ ngẫu nhiên theo cấp nhân vật (ItemGenerator.random_equipment) vào Hành trang.
func _add_random_items(count: int) -> void:
	var profile := GameManager.local_profile
	var added := 0
	for i in count:
		if profile.add_item(ItemGenerator.random_equipment(profile.level)):
			added += 1
	_commit()
	_result_label.visible = true
	_result_label.text = "Đã nhận %d món đồ (Hành trang %d/%d)." % [added, profile.inventory.size(), PlayerProfile.INVENTORY_CAPACITY]

func _add_masks() -> void:
	var profile := GameManager.local_profile
	var added := 0
	for p in 5:
		var mask := ItemGenerator.generate(ItemDatabase.Detail.MASK, p, 1, int(profile.get_element()), [5, 5, 5, 5, 5, 5])
		if mask and profile.add_item(mask):
			added += 1
	_commit()
	_result_label.visible = true
	_result_label.text = "Đã nhận %d Mặt Nạ (Hành trang %d/%d)." % [added, profile.inventory.size(), PlayerProfile.INVENTORY_CAPACITY]

func _add_mantles() -> void:
	var profile := GameManager.local_profile
	var added := 0
	for lv in [1, 3, 5, 6, 7]:
		var mantle := ItemGenerator.generate(ItemDatabase.Detail.MANTLE, 0, lv, int(profile.get_element()), [6, 6, 6, 6, 6, 6])
		if mantle and profile.add_item(mantle):
			added += 1
	_commit()
	_result_label.visible = true
	_result_label.text = "Đã nhận %d Phi Phong (Hành trang %d/%d)." % [added, profile.inventory.size(), PlayerProfile.INVENTORY_CAPACITY]

func _on_level_reset_confirmed() -> void:
	GameManager.local_profile.reset_to_level_1()
	_commit()
	_result_label.visible = true
	_result_label.text = "Đã đưa nhân vật về cấp 1."

func _on_reset_confirmed() -> void:
	var refunded := GameManager.local_profile.refund_all_points()
	_commit()
	_result_label.visible = true
	if refunded["potential"] == 0 and refunded["skill"] == 0:
		_result_label.text = "Chưa cộng điểm nào — không có gì để tẩy."
	else:
		_result_label.text = "Đã tẩy: hoàn %d điểm tiềm năng, %d điểm kỹ năng." % [refunded["potential"], refunded["skill"]]

func _commit() -> void:
	SaveManager.save_profile(GameManager.local_profile)
	SaveManager.flush_online()
	_refresh()
	profile_changed.emit()

func _refresh() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	_level_label.text = "Cấp: %d" % profile.level
	_skill_points_label.text = "Điểm kỹ năng: %d" % profile.skill_points
