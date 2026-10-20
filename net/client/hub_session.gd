extends Node
class_name HubSession
## KẾT NỐI SẢNH ở Character Hub (đã đăng nhập + chọn nhân vật): giữ 1 kết nối NetProto.HELLO_HUB tới game server thế giới để Chợ
## Giao Thương (cùng 1 sổ chợ trên server cho mọi người), giao dịch theo ID, chat, tổ đội, bang, hảo hữu chạy THẬT ngay từ Hub —
## không có nhân vật trên map, không ai thấy; server chỉ nhận gói xã hội / chợ / lưu (GameServer.HUB_ALLOWED).
##   - Hồ sơ / thông báo / lời mời: NetSocial (dùng chung với màn chơi). Hồ sơ đổi -> vẽ lại Hub.
##   - Nhân vật MỚI chưa chọn phái (server_seen 0): chờ chọn phái + lưu xong mới nối (server nhận phái này lúc "vào lần đầu" —
##     ProfileGuard.sanitize_new; nối sớm thì server xử lý "lần đầu" trước khi chọn phái).
##   - Rời Hub (vào map / ra màn chọn nhân vật): gửi bản cuối rồi ngắt — server lưu, màn chơi nối lại bằng kết nối thường.
##   - Mất kết nối bất thường: nối lại sau RECONNECT_SECONDS (trừ bị đá vì đăng nhập nơi khác / khoá tài khoản).

const RECONNECT_SECONDS := 5.0
const NO_RECONNECT := ["logged_in_elsewhere", "banned", "admin_edit", "version", "unauthorized"]

var hub_scene: Node
var _reconnect_in := -1.0
var _social: NetSocial

## Gắn vào Character Hub nếu đang chơi online (đã đăng nhập + đã chọn nhân vật trên máy chủ); null nếu offline.
static func attach(hub: Node) -> HubSession:
	if not NetWorldSync.is_online_mode():
		return null
	var s := HubSession.new()
	s.name = "HubSession"
	s.hub_scene = hub
	hub.add_child(s)
	return s

func _ready() -> void:
	_social = NetSocial.create(_toast)
	_social.profile_applied.connect(_on_profile_applied)
	add_child(_social)
	NetClient.disconnected.connect(_on_disconnected)
	_connect()

func _connect() -> void:
	_reconnect_in = -1.0
	var profile := GameManager.local_profile
	## Nhân vật mới: chờ chọn phái (Character Hub hỏi ngay) rồi đẩy bản lưu HTTP lên trước khi nối.
	while is_inside_tree() and profile != null and profile.server_seen == 0 and profile.needs_sect():
		await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	await SaveManager.flush_online()
	var token: String = await AccountApi.access_token()
	if token == "" or not is_inside_tree():
		return
	NetClient.connect_to(ServerSelectScreen.selected_server, token, SaveManager.online_character_id, true)

func _exit_tree() -> void:
	if NetClient.is_hub:
		if NetClient.is_in_world() and GameManager.local_profile:
			NetClient.send_profile(GameManager.local_profile.to_dict())
		NetClient.disconnect_from_server()
		SaveManager.mark_version_unknown()

func _process(delta: float) -> void:
	if _reconnect_in >= 0.0:
		_reconnect_in -= delta
		if _reconnect_in < 0.0:
			_connect()

func _on_disconnected(code: String, message: String) -> void:
	if not NetClient.is_hub:
		return
	SaveManager.mark_version_unknown()
	if code in NO_RECONNECT:
		_toast(message)
		return
	_reconnect_in = RECONNECT_SECONDS

func _on_profile_applied() -> void:
	if hub_scene:
		if hub_scene.has_method("refresh"):
			hub_scene.refresh()
		if hub_scene.has_method("_refresh_inventory_view"):
			hub_scene.call("_refresh_inventory_view")

func _toast(text: String) -> void:
	if hub_scene and hub_scene.has_method("_show_toast"):
		hub_scene.call("_show_toast", text)
