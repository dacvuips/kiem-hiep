extends RefCounted
class_name GameModeManager
## TRÌNH QUẢN LÝ CHẾ ĐỘ CHƠI (GAME MODE ARCHITECTURE)
##
## Phân chia độc lập và rõ ràng giữa 2 chế độ chơi:
## - OFFLINE: Không cần mạng, lưu cục bộ, xử lý độc lập (chuẩn bị cho yêu cầu riêng tiếp theo).
## - ONLINE: BẮT BUỘC có mạng Internet, KHÔNG có bot, KHÔNG có chức năng tạo hoặc thêm bot.

enum Mode { OFFLINE, ONLINE }

static var current_mode: Mode = Mode.OFFLINE

static var _online_controller: OnlineModeController = null
static var _offline_controller: OfflineModeController = null

static func get_online_controller() -> OnlineModeController:
	if _online_controller == null:
		_online_controller = OnlineModeController.new()
	return _online_controller

static func get_offline_controller() -> OfflineModeController:
	if _offline_controller == null:
		_offline_controller = OfflineModeController.new()
	return _offline_controller

static func _get_game_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

## Thiết lập chế độ chơi
static func set_mode(mode: Mode) -> void:
	current_mode = mode
	var gm := _get_game_manager()
	if gm and "network_mode" in gm:
		gm.network_mode = 1 if mode == Mode.ONLINE else 0
	print("GameModeManager: Chuyển sang chế độ -> %s" % ("ONLINE (Trực tuyến)" if mode == Mode.ONLINE else "OFFLINE (Ngoại tuyến)"))

## Kiểm tra có đang ở chế độ Online không
static func is_online() -> bool:
	return current_mode == Mode.ONLINE

## Kiểm tra có đang ở chế độ Offline không
static func is_offline() -> bool:
	return current_mode == Mode.OFFLINE

## Quy tắc cốt lõi: Có cho phép BOT hay không?
## - Khi ONLINE: Luôn trả về FALSE (Không có bất kỳ bot nào trong cảnh, map, pk, ải).
## - Khi OFFLINE: Cho phép theo logic riêng của offline.
static func allows_bot() -> bool:
	if is_online():
		return false
	return get_offline_controller().allows_bot()

## Có cho phép người chơi hoặc hệ thống tạo BOT hay không?
static func can_create_bot() -> bool:
	if is_online():
		return false
	return get_offline_controller().can_create_bot()

## Có cho phép thêm BOT vào phòng (PK, ải, v.v.) hay không?
static func can_add_bot() -> bool:
	if is_online():
		return false
	return get_offline_controller().can_add_bot()

## Chế độ hiện tại có yêu cầu Internet hay không?
static func requires_internet() -> bool:
	if is_online():
		return true
	return false

## Lấy controller chuyên biệt tương ứng
static func get_active_controller() -> RefCounted:
	if is_online():
		return get_online_controller()
	return get_offline_controller()
