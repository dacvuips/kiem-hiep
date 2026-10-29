extends CanvasLayer
class_name FieldClient
## Phía game của PHÒNG TRAIN CHUNG (FieldServer ở server): Main thêm node này khi vào map luyện công / Địa Ngục từ màn Vượt Ải lúc
## đã đăng nhập — GameManager.field_map.field = {server, action: {op: "create" {map_id, tier, stars} | "join" {room, map_id, tier}}}.
##   - Kết nối field server xong -> gửi tạo phòng / vào phòng.
##   - Khung sát góc trên-trái màn hình: "Phòng #ID" + nút Sao chép (đưa ID cho bạn bè nhập ở màn Vượt Ải), tên map, số người / tối đa.
##   - Server từ chối (sai ID, phòng đầy...) hoặc chủ phòng rời (mã "field_end"): báo lý do rồi về Character Hub.

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const LEAVE_DELAY := 3.0
const MapChatHelper = preload("res://systems/map_chat_helper.gd")

var field := {}
var room_id := ""
var _title: Label
var _info: Label
var _copy: Button
var _share: Button
var _leaving := false

## Chiều cao (xấp xỉ) khung ID phòng góc trên-trái — main.gd đẩy hàng nút debug xuống dưới mức này.
const HUD_HEIGHT := 72.0

static func create(field_entry: Dictionary) -> FieldClient:
	var f := FieldClient.new()
	f.field = field_entry
	return f

func _ready() -> void:
	add_to_group("field_client")
	layer = 20
	_build_hud()
	NetClient.connected_to_world.connect(func(_eid: int, _feet: Vector2, _name: String) -> void: _send_action())
	NetClient.field_message.connect(_on_message)
	NetClient.disconnected.connect(_on_disconnected)
	if NetClient.is_in_world():
		_send_action()

func _send_action() -> void:
	var action: Dictionary = field.get("action", {})
	var args := {"map_id": int(action.get("map_id", 0)), "tier": int(action.get("tier", 0)), "stars": int(action.get("stars", 0)),
		"room": str(action.get("room", "")), "guild": str(action.get("guild", "")),
		"boss_id": int(action.get("boss_id", 0)), "boss_name": str(action.get("boss_name", ""))}
	var op_type: int = FieldServer.OP_CREATE
	if str(action.get("op", "")) == "join":
		op_type = FieldServer.OP_JOIN
	elif str(action.get("op", "")) == "guild":
		op_type = FieldServer.OP_GUILD
	elif str(action.get("op", "")) == "boss":
		op_type = FieldServer.OP_BOSS
	NetClient.send_field(op_type, args)

func _on_message(msg: Dictionary) -> void:
	match str(msg.get("op", "")):
		"room":
			room_id = str(msg.get("id", ""))
			_show(msg)
			if str(msg.get("boss_name", "")) != "" or bool(msg.get("is_boss", false)) or str(field.get("action", {}).get("op", "")) == "boss":
				var bname: String = str(msg.get("boss_name", field.get("action", {}).get("boss_name", "Boss")))
				_say("Đã vào map Boss: %s! Chiến trường tự do, hỗ trợ PK." % bname)
			elif str(msg.get("guild", "")) != "":
				_say("Chào mừng đến Tổng Đà Bang Hội - %s!" % msg.get("guild"))
			elif str(field.get("action", {}).get("op", "")) == "join":
				_say("Đã vào phòng #%s của %s." % [room_id, msg.get("host", "?")])
			else:
				_say("Phòng #%s — đưa ID này cho bạn bè để vào train chung." % room_id)
		"state":
			_show(msg)
		"reject":
			_leave(str(msg.get("msg", "Không vào được phòng.")))

func _show(s: Dictionary) -> void:
	var boss_name: String = str(s.get("boss_name", ""))
	if boss_name != "" or s.get("is_boss", false):
		_title.text = "Săn Boss: %s" % (boss_name if boss_name != "" else str(s.get("name", "Boss Hoàng Kim")))
		var members: Array = s.get("members", [])
		_info.text = "%d cao thủ đang khiêu chiến (Chế độ PK tự do)" % members.size()
		_info.tooltip_text = ", ".join(members)
		_copy.visible = false
		return
	var guild: String = str(s.get("guild", ""))
	if guild != "":
		_title.text = "Tổng Đà: %s" % guild
		var members: Array = s.get("members", [])
		_info.text = "%s  ·  %d thành viên đang ở Tổng Đà" % [guild, members.size()]
		_info.tooltip_text = ", ".join(members)
		_copy.visible = false
		return
	_title.text = "Phòng #%s" % s.get("id", room_id)
	var stars := int(s.get("stars", 0))
	var where := str(s.get("name", ""))
	if stars > 0:
		where += " · Tinh Anh %d★" % stars
	var members: Array = s.get("members", [])
	_info.text = "%s  ·  %d/%d người  ·  Chủ: %s" % [where, members.size(), int(s.get("max", FieldServer.MAX_MEMBERS)), s.get("host", "?")]
	_info.tooltip_text = ", ".join(members)
	_copy.disabled = room_id == ""
	if _share:
		_share.disabled = room_id == ""

func _on_disconnected(code: String, message: String) -> void:
	if code == "field_end":
		_leave(message)

func _copy_id() -> void:
	if room_id == "":
		return
	DisplayServer.clipboard_set(room_id)
	_say("Đã sao chép ID phòng %s." % room_id)

func _share_chat() -> void:
	if room_id == "":
		return
	MapChatHelper.share_room_to_chat(room_id, self)

## Báo lý do rồi về Character Hub (hoặc chuyển sang chế độ Boss đơn nếu máy chủ chưa mở).
func _leave(message: String) -> void:
	if _leaving or not is_inside_tree():
		return
	_leaving = true
	var is_boss_mode: bool = GameManager.field_map.has("boss") or str(field.get("action", {}).get("op", "")) == "boss"
	if is_boss_mode:
		_title.text = "Săn Boss (Cục bộ)"
		_info.text = "Mất kết nối máy chủ — Chuyển sang chiến đấu ngoại tuyến."
		_copy.visible = false
		_say("Mất kết nối máy chủ Boss — Chuyển sang chế độ offline.")
		_leaving = false
		VltkWorld.net_monsters = false
		return
	_info.text = message
	_copy.disabled = true
	_say(message)
	await get_tree().create_timer(LEAVE_DELAY).timeout
	if is_inside_tree():
		NetClient.disconnect_from_server()
		GameManager.field_map = {}
		get_tree().change_scene_to_file(HUB_SCENE)

func _say(text: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("notify"):
		player.notify(text)

func _build_hud() -> void:
	var action: Dictionary = field.get("action", {})
	var is_boss: bool = str(action.get("op", "")) == "boss" or GameManager.field_map.has("boss")
	var panel := PanelContainer.new()
	var bare := StyleBoxEmpty.new()   ## không nền / viền — chỉ giữ lề chữ
	bare.content_margin_left = 6
	bare.content_margin_top = 2
	bare.content_margin_right = 6
	bare.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", bare)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 68.0
	panel.offset_top = 8.0
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	if is_boss:
		var bname: String = str(action.get("boss_name", "Boss Hoàng Kim"))
		_title = GameUi.label("Săn Boss: %s" % bname, GameUi.GOLD, 16)
		head.add_child(_title)
		_copy = SocialUi.small_button("Sao chép")
		_copy.visible = false
		head.add_child(_copy)
		_info = GameUi.label("Chiến trường săn Boss liên đấu (Hỗ trợ PK)", SocialUi.TEXT, 12)
		_info.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(_info)
	else:
		_title = GameUi.label("Đang mở phòng…", GameUi.GOLD, 16)
		head.add_child(_title)
		_copy = SocialUi.small_button("Sao chép")
		_copy.tooltip_text = "Sao chép ID phòng để gửi cho bạn bè"
		_copy.disabled = true
		_copy.pressed.connect(_copy_id)
		head.add_child(_copy)
		_share = SocialUi.small_button("Gắn chat")
		_share.tooltip_text = "Gắn ID phòng vào khung chat để rủ bạn bè"
		_share.disabled = true
		_share.pressed.connect(_share_chat)
		head.add_child(_share)
		_info = GameUi.label("", SocialUi.TEXT, 12)
		_info.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(_info)
