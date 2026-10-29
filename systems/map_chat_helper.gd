class_name MapChatHelper
extends RefCounted
## Helper hỗ trợ chia sẻ ID phòng / Bản đồ vào khung chat, hiển thị link xanh có underline [Map:ID]
## và mở popup xác nhận dịch chuyển người chơi tới map / phòng đó khi nhấp vào.

const COLOR_MAP_LINK := "00E5FF"   ## Màu xanh lam ngọc sáng nổi bật
const GAME_SCENE_PATH := "res://main.tscn"

## Lấy ID phòng hoặc ID map hiện tại mà người chơi đang đứng
static func get_current_room_or_map_id() -> String:
	# 1. Kiểm tra FieldClient (phòng train chung / săn Boss)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var field_nodes: Array[Node] = tree.root.find_children("*", "FieldClient", true, false)
		for fn in field_nodes:
			if is_instance_valid(fn) and str(fn.get("room_id")) != "":
				return str(fn.get("room_id"))

	# 2. Kiểm tra PkRoomBadge (phòng đấu trường PK / Lộn xộn / Tống Kim)
	if PkRoomBadge.current != null and is_instance_valid(PkRoomBadge.current):
		var pk_id := PkRoomBadge.current._room_id.strip_edges()
		if pk_id != "":
			return pk_id

	# 3. Kiểm tra GameManager.field_map
	var fm = GameManager.field_map
	if fm is Dictionary and not fm.is_empty():
		var rid := str(fm.get("pk", {}).get("room_id", fm.get("room", {}).get("id", ""))).strip_edges()
		if rid != "":
			return rid
		var mid := str(fm.get("id", "")).strip_edges()
		if mid != "":
			return mid

	return ""

## Chuyển đổi các cú pháp [Map:ID] hoặc {map:ID} thành BBCode link tương tác
static func format_chat_map_bbcode(text: String) -> String:
	if text.is_empty():
		return ""
	var regex := RegEx.new()
	# Khớp cú pháp [Map:123456], [lb]Map:123456] (sau khi escape) hoặc {map:123456}
	regex.compile("(?i)(\\[(?:lb\\])?Map:([A-Za-z0-9_]+)\\]|\\{map:([A-Za-z0-9_]+)\\})")
	var result := ""
	var last_pos := 0

	for m in regex.search_all(text):
		var start := m.get_start()
		var end := m.get_end()
		if start > last_pos:
			result += text.substr(last_pos, start - last_pos)

		var room_id := m.get_string(2)
		if room_id.is_empty():
			room_id = m.get_string(3)

		# Format BBCode: màu xanh sáng + underline [u]
		var link_bbcode := "[url=map:%s][color=#%s][u][b][Map:%s][/b][/u][/color][/url]" % [room_id, COLOR_MAP_LINK, room_id]
		result += link_bbcode
		last_pos = end

	if last_pos < text.length():
		result += text.substr(last_pos)

	return result

## Gắn link [Map:ID] của phòng hiện tại vào khung chat
static func share_current_room_to_chat(host: Node) -> void:
	var rid := get_current_room_or_map_id()
	if rid.is_empty():
		_notify_player(host, "Hiện tại bạn không ở trong phòng hoặc bản đồ có ID để chia sẻ.")
		return
	share_room_to_chat(rid, host)

## Gắn một ID phòng cụ thể vào khung chat và mở khung chat
static func share_room_to_chat(room_id: String, host: Node) -> void:
	var panel := ChatPanel.open(host)
	if panel != null:
		var tag := "[Map:%s]" % room_id.strip_edges()
		panel.insert_text(tag)

## Hiển thị popup xác nhận trước khi dịch chuyển người chơi tới map
static func confirm_and_teleport(room_id: String, host: Node) -> void:
	var id := room_id.strip_edges()
	if id.is_empty():
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Dịch Chuyển Bản Đồ"
	dialog.dialog_text = "Hiệp khách có muốn dịch chuyển đến phòng/bản đồ [Map: %s] không?" % id
	dialog.ok_button_text = "Đồng ý"
	dialog.cancel_button_text = "Hủy"

	dialog.confirmed.connect(func() -> void:
		teleport_to_room_or_map(id, host)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	var tree := host.get_tree() if host != null else Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(dialog)
		dialog.popup_centered()

## Thực hiện đưa player vào phòng / map đúng số ID
static func teleport_to_room_or_map(room_id: String, host: Node) -> void:
	var id := room_id.strip_edges()
	if id.is_empty():
		return

	var tree := host.get_tree() if host != null else Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	# 1. Thử tìm xem có phải là ID phòng train chung (FieldServer)
	if id.length() == 6 and id.is_valid_int():
		var r_data = await AccountApi.field(ServerSelectScreen.selected_server_id)
		if r_data.ok and r_data.data is Dictionary:
			var st: Dictionary = r_data.data
			var target_room: Dictionary = {}
			for r in st.get("rooms", []):
				if r is Dictionary and str(r.get("id", "")) == id:
					target_room = r
					break

			if not target_room.is_empty():
				var entry := MapSelectWindow.join_entry(target_room)
				if not entry.is_empty() and MapCatalog.is_playable(entry):
					entry["field"] = {
						"server": MapSelectWindow._field_server(st, target_room),
						"action": {"op": "join", "room": id, "map_id": int(target_room["map_id"]), "tier": int(target_room.get("tier", 0))}
					}
					_execute_enter_map(entry, tree)
					return

	# 2. Thử tìm xem có phải map ID thông thường (từ MapCatalog)
	if id.is_valid_int():
		var mid := int(id)
		for m in MapCatalog.all():
			if int(m.get("id", -1)) == mid:
				if MapCatalog.is_playable(m):
					var entry: Dictionary = m.duplicate(true)
					_execute_enter_map(entry, tree)
					return
				else:
					_notify_player(host, "Bản đồ #%s chưa có tài nguyên hoặc chưa mở." % id)
					return

	# 3. Thử tìm trong danh sách Boss
	if id.is_valid_int():
		var mid := int(id)
		for b in MapSelectWindow.BOSS_LIST:
			if int(b.get("map_id", -1)) == mid:
				for m in MapCatalog.all():
					if int(m.get("id", -1)) == mid and MapCatalog.is_playable(m):
						var entry: Dictionary = m.duplicate(true)
						entry["boss"] = b
						_execute_enter_map(entry, tree)
						return

	_notify_player(host, "Không tìm thấy phòng hoặc bản đồ #%s (phòng đã đóng hoặc ID không tồn tại)." % id)

static func _execute_enter_map(entry: Dictionary, tree: SceneTree) -> void:
	if GameManager.local_profile != null:
		SaveManager.save_profile(GameManager.local_profile)
		await SaveManager.flush_online()
	if NetClient.is_connected_to_server():
		NetClient.disconnect_from_server()

	GameManager.game_mode = GameManager.GameMode.MAIN_MAP
	GameManager.field_map = entry
	GameManager.current_stage = null
	GameManager.is_game_over = false

	# Đóng các cửa sổ chat đang mở
	if ChatPanel._open_panel != null and is_instance_valid(ChatPanel._open_panel):
		ChatPanel._open_panel.close()

	tree.change_scene_to_file(GAME_SCENE_PATH)

static func _notify_player(host: Node, msg: String) -> void:
	var tree := host.get_tree() if host != null else Engine.get_main_loop() as SceneTree
	if tree != null:
		var player := tree.get_first_node_in_group("player")
		if player != null and player.has_method("notify"):
			player.notify(msg)
			return
	print("[MapChatHelper] ", msg)
