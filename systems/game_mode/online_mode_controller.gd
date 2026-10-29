extends RefCounted
class_name OnlineModeController
## BỘ ĐIỀU KHIỂN CHẾ ĐỘ CHƠI ONLINE (GAME ONLINE)
##
## Đặc điểm & Quy tắc bất biến:
## 1. Yêu cầu bắt buộc phải có kết nối Internet (requires_internet = true).
## 2. Tuyệt đối KHÔNG xuất hiện BOT trong mọi cảnh, map, đấu trường PK, hoạt động ải.
## 3. KHÔNG có chức năng tạo bot, thêm bot, điền bot hay tự động ghép với bot khi chờ quá lâu.
## 4. Mọi người chơi và tương tác đều qua máy chủ kết nối trực tuyến (NetWorldSync, ArenaClient, FieldClient, BattleClient).

signal connection_lost(reason: String)
signal internet_checked(is_available: bool)

const MANIFEST_URL := "https://kiem-hiep-api.viettheo.site/v1/client/manifest"

var is_connected: bool = false
var last_check_time: float = 0.0

func allows_bot() -> bool:
	# Bất biến: Chế độ Online cấm hoàn toàn bot
	return false

func can_create_bot() -> bool:
	return false

func can_add_bot() -> bool:
	return false

func requires_internet() -> bool:
	return true

## Kiểm tra kết nối Internet thực tế tới máy chủ
func check_internet(http_node: Node, timeout: float = 5.0) -> bool:
	if http_node == null:
		return false
	var req := HTTPRequest.new()
	req.name = "OnlineCheckReq_%d" % Time.get_ticks_msec()
	req.timeout = timeout
	http_node.add_child(req)
	
	var url := MANIFEST_URL
	var tree := Engine.get_main_loop() as SceneTree
	var account_api: Node = tree.root.get_node_or_null("AccountApi") if (tree and tree.root) else null
	if account_api and "base_url" in account_api and str(account_api.base_url) != "":
		url = str(account_api.base_url) + "/v1/client/manifest"
		
	var err := req.request(url)
	if err != OK:
		req.queue_free()
		is_connected = false
		internet_checked.emit(false)
		return false
		
	var res: Array = await req.request_completed
	req.queue_free()
	
	var result_code := int(res[0])
	var http_code := int(res[1])
	is_connected = (result_code == HTTPRequest.RESULT_SUCCESS or http_code > 0)
	last_check_time = Time.get_ticks_msec() / 1000.0
	internet_checked.emit(is_connected)
	return is_connected

## Xử lý khi phát hiện mất kết nối mạng trong quá trình chơi
func notify_disconnect(reason: String = "Mất kết nối Internet tới máy chủ") -> void:
	is_connected = false
	connection_lost.emit(reason)
