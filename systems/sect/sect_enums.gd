extends RefCounted
## Enum dùng riêng cho hệ thống Môn Phái — môn phái là xuất thân cố định chọn lúc tạo nhân vật.
class_name SectEnums

enum Alignment { CHINH_PHAI, TA_PHAI, TRUNG_LAP }

static func alignment_to_string(alignment: Alignment) -> String:
	match alignment:
		Alignment.CHINH_PHAI: return "Chính Phái"
		Alignment.TA_PHAI: return "Tà Phái"
	return "Trung Lập"
