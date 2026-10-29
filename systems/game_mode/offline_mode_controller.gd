extends RefCounted
class_name OfflineModeController
## BỘ ĐIỀU KHIỂN CHẾ ĐỘ CHƠI OFFLINE (GAME OFFLINE)
##
## Đặc điểm:
## 1. Không cần mạng Internet (requires_internet = false), chạy hoàn toàn độc lập trên máy cục bộ.
## 2. Dữ liệu nhân vật lưu tại user://save/ trên thiết bị.
## 3. Hỗ trợ Bot mô phỏng / hiệp khách đồng hành theo cấu hình của chế độ Offline.
## 4. Tách biệt hoàn toàn khỏi logic Online để sẵn sàng tiếp nhận yêu cầu riêng tiếp theo.

func allows_bot() -> bool:
	return true

func can_create_bot() -> bool:
	return true

func can_add_bot() -> bool:
	return true

func requires_internet() -> bool:
	return false
