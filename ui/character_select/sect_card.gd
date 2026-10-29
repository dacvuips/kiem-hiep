extends Button
class_name SectCard
## Thẻ hiển thị 1 môn phái trong danh sách Bước 2 — phát signal khi được chọn thay vì gọi ngược
## lên CharacterSelectScreen, để tái dùng độc lập nếu cần hiển thị ở màn khác sau này.

signal selected(sect: SectDefinition)

var sect: SectDefinition

func setup(sect_def: SectDefinition) -> void:
	sect = sect_def
	text = "%s\n%s" % [sect_def.sect_name, SectEnums.alignment_to_string(sect_def.alignment)]
	if sect_def.id == "minh_giao":
		disabled = true
		tooltip_text = "Môn phái Minh Giáo đang tạm thời đóng gia nhập"
		return
	pressed.connect(func() -> void: selected.emit(sect))
