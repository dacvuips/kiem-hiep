extends RefCounted
class_name GameplayUnits
## Quy đổi "mét tượng trưng" (đơn vị balance số liệu, dễ đọc hơn pixel thô) sang pixel thật của
## world — dùng khi so sánh bán kính/khoảng cách balance với distance_to() (luôn tính bằng pixel).

const PIXELS_PER_METER := 100.0

static func meters_to_pixels(meters: float) -> float:
	return meters * PIXELS_PER_METER
