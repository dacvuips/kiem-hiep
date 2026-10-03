extends Resource
class_name SectDefinition
## Dữ liệu THUẦN của 1 môn phái (xuất thân cố định chọn lúc tạo nhân vật) — tham chiếu tinh thần
## hệ thống môn phái/ngũ hành của Võ Lâm Truyền Kỳ.

@export var id: String = ""
@export var sect_name: String = ""
@export var element: ElementTypes.ElementType = ElementTypes.ElementType.KIM
@export var alignment: SectEnums.Alignment = SectEnums.Alignment.TRUNG_LAP
@export var icon: Texture2D
@export_multiline var description: String = ""
@export var skills: Array[SkillDefinition] = []
