extends VBoxContainer
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
	visible = OS.is_debug_build()
	_cheat_box.visible = false
	_toggle_button.toggled.connect(func(on: bool) -> void:
		_cheat_box.visible = on
		_result_label.visible = false
		_refresh())
	%LevelUp1.pressed.connect(_add_levels.bind(1))
	%LevelUp10.pressed.connect(_add_levels.bind(10))
	%LevelReset.pressed.connect(%LevelResetConfirm.popup_centered)
	%LevelResetConfirm.confirmed.connect(_on_level_reset_confirmed)
	%SkillPoint1.pressed.connect(_add_skill_points.bind(1))
	%SkillPoint10.pressed.connect(_add_skill_points.bind(10))
	%RandomItem1.pressed.connect(_add_random_items.bind(1))
	%RandomItem10.pressed.connect(_add_random_items.bind(10))
	## Tẩy điểm không hoàn tác được -> hỏi xác nhận trước.
	%ResetButton.pressed.connect(_reset_confirm.popup_centered)
	_reset_confirm.confirmed.connect(_on_reset_confirmed)

## Lên cấp qua PlayerProfile.level_up() — nhận điểm kỹ năng/tiềm năng y như lên cấp thật.
func _add_levels(count: int) -> void:
	var profile := GameManager.local_profile
	for i in count:
		profile.level_up()
	_commit()

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
	_refresh()
	profile_changed.emit()

func _refresh() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	_level_label.text = "Cấp: %d" % profile.level
	_skill_points_label.text = "Điểm kỹ năng: %d" % profile.skill_points
