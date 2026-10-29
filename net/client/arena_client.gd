extends CanvasLayer
class_name ArenaClient
## Phía game của ĐẤU TRƯỜNG PK online (ArenaServer ở server): Main thêm node này khi vào đấu trường từ popup PK (PkWindow) lúc đã
## đăng nhập — GameManager.field_map.pk = {mode, online: true, server, action: {op: create | join | watch | match, ...}}.
##   - Kết nối arena server xong -> gửi đúng việc đã chọn (tạo phòng / vào đấu / vào xem / tự tìm đối thủ).
##   - Bảng giữa trên màn hình: phòng #ID, giai đoạn + đếm ngược, 2 người đấu, số người xem; nút "Rời đấu trường".
##   - Đang đấu: CHỈ đối thủ của mình là địch (RemotePlayer.set_pk_enemy) — người xem không đánh / không bị đánh.
##   - Kết quả: ghi thắng / thua (PkMatch.record_result); server mời rời đấu trường -> về Character Hub.
##   - Tự tìm quá 1 phút không có ai (server báo "no_match"): ngắt kết nối, đấu với bot cùng cấp như bản offline (PkMatch).

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const PkRoomBadge = preload("res://ui/hud/pk_room_badge.gd")
const CountdownOverlay = preload("res://ui/common/countdown_overlay.gd")
const GAME_SCENE := "res://Main.tscn"
const LEAVE_DELAY := 3.0
const STATE_NAMES := {"waiting": "Đang chờ đối thủ", "prepare": "Chuẩn bị", "fight": "Đang đấu", "ended": "Đã kết thúc"}

var pk := {}
var mode: PkRules.Mode = PkRules.Mode.LIEN_DAU
var role := ""
var _state := ""
var _opponent_eid := 0
var _enemy_eids: Array = []
var _searching := -1.0
var _done := false
var _box: VBoxContainer
var _title: Label
var _clock: Label
var _info: Label
var _leave_button: Button
var _reject_button: Button
var _start_button: Button
var _ready_button: Button
var _is_ready: bool = false

static func create(pk_entry: Dictionary) -> ArenaClient:
	var a := ArenaClient.new()
	a.pk = pk_entry
	a.mode = int(pk_entry.get("mode", PkRules.Mode.LIEN_DAU)) as PkRules.Mode
	return a

func _ready() -> void:
	add_to_group("arena_client")
	layer = 20
	_build_hud()
	var action: Dictionary = pk.get("action", {})
	var init_room := str(action.get("room", pk.get("room_id", "")))
	var ui_node: Node = get_tree().root.get_node_or_null("Main/UI")
	if ui_node == null:
		ui_node = self
	PkRoomBadge.attach(ui_node, init_room, mode)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.suppress_death_popup = true
		player.hurt_invincible = false
	NetClient.connected_to_world.connect(func(_eid: int, _feet: Vector2, _name: String) -> void: _send_action())
	NetClient.arena_message.connect(_on_message)
	NetClient.disconnected.connect(_on_disconnected)
	if NetClient.is_in_world():
		_send_action()

func _send_action() -> void:
	var action: Dictionary = pk.get("action", {})
	var args := {
		"mode": mode,
		"room": str(action.get("room", "")),
		"password": str(action.get("password", "")),
		"team_size": int(action.get("team_size", 1)),
		"team": str(action.get("team", "")),
		"brawl_type": str(action.get("brawl_type", "solo")),
		"map_id": int(action.get("map_id", 319)),
		"target_kills": int(action.get("target_kills", 20))
	}
	match str(action.get("op", "match")):
		"create":
			NetClient.send_arena(ArenaServer.OP_CREATE, args)
		"join":
			NetClient.send_arena(ArenaServer.OP_JOIN, args)
		"watch":
			NetClient.send_arena(ArenaServer.OP_WATCH, args)
		_:
			NetClient.send_arena(ArenaServer.OP_MATCH, args)

func _on_message(msg: Dictionary) -> void:
	match str(msg.get("op", "")):
		"room":
			role = str(msg.get("role", ""))
			_searching = -1.0
		"searching":
			_searching = 0.0
			_title.text = "%s — đang tìm đối thủ" % PkRules.MODE_NAMES[mode]
		"state":
			_on_state(msg)
		"result":
			_on_result(msg)
		"rejected_opponent":
			_say(str(msg.get("msg", "Đã từ chối đối thủ.")))
		"reject":
			var reason := str(msg.get("msg", "Không vào được đấu trường."))
			if mode == PkRules.Mode.THACH_DAU:
				_say("%s — chuyển sang đấu tập với Bot cùng cấp." % reason)
				_play_bot()
			else:
				_leave(reason)
		"no_match":
			_play_bot()

func _on_state(s: Dictionary) -> void:
	role = str(s.get("role", role))
	_state = str(s.get("state", ""))
	var fighters: Array = s.get("fighters", [])
	var eids: Array = s.get("fighter_eids", [])
	var team_size: int = int(s.get("team_size", 1))
	var my_team: String = str(s.get("my_team", ""))
	var team_a_eids: Array = s.get("team_a_eids", [])
	var team_b_eids: Array = s.get("team_b_eids", [])
	if _done:
		return   ## đã có kết quả: giữ dòng THẮNG / THUA, không ghi đè bằng trạng thái phòng
	var format_str := (" [%s]" % PkRules.format_name(team_size)) if int(s.get("mode", mode)) == PkRules.Mode.THACH_DAU else ""
	var rid := str(s.get("id", ""))
	if rid != "" and rid != "?":
		PkRoomBadge.update_id(rid)
	_title.text = "%s%s · Phòng #%s%s" % [PkRules.MODE_NAMES.get(int(s.get("mode", mode)), ""), format_str, s.get("id", "?"),
			" (xem)" if role == "spectator" else ""]
	var left := int(s.get("left", 0))
	if _state == "prepare":
		CountdownOverlay.start(self)
		_clock.text = "Chuẩn bị"
	else:
		_clock.text = STATE_NAMES.get(_state, _state) + ("" if _state == "waiting" else " · %02d:%02d" % [left / 60, left % 60])
	if team_size > 1:
		var count_a: int = (s.get("team_a", []) as Array).size()
		var count_b: int = (s.get("team_b", []) as Array).size()
		_info.text = "Phe Xanh: %d/%d người   vs   Phe Đỏ: %d/%d người   ·   Khán giả %d" % [
			count_a, team_size, count_b, team_size, int(s.get("spectators", 0))
		]
	else:
		_info.text = "%s   vs   %s   ·   Người xem %d" % [fighters[0] if fighters.size() > 0 else "?",
				fighters[1] if fighters.size() > 1 else "(đang chờ)", int(s.get("spectators", 0))]
	_enemy_eids.clear()
	_opponent_eid = 0
	if role == "fighter":
		if my_team == "a":
			_enemy_eids = team_b_eids
		elif my_team == "b":
			_enemy_eids = team_a_eids
		else:
			for e in eids:
				if int(e) != 0 and int(e) != NetClient.my_eid:
					_enemy_eids.append(int(e))
		if not _enemy_eids.is_empty():
			_opponent_eid = int(_enemy_eids[0])

	# Cập nhật màu tên và tag phe [Phe Xanh] / [Phe Đỏ]
	if team_size > 1 or mode == PkRules.Mode.THACH_DAU:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and player.has_method("set_name_color"):
			if my_team == "a":
				player.set_name_color(Color(0.25, 0.70, 1.0), "[Phe Xanh]")
			elif my_team == "b":
				player.set_name_color(Color(1.0, 0.35, 0.35), "[Phe Đỏ]")
		var sync := NetWorldSync.current
		if sync:
			for r in sync.remotes():
				if is_instance_valid(r) and r.has_method("set_name_color"):
					if team_a_eids.has(r.eid):
						r.set_name_color(Color(0.25, 0.70, 1.0), "[Phe Xanh]")
					elif team_b_eids.has(r.eid):
						r.set_name_color(Color(1.0, 0.35, 0.35), "[Phe Đỏ]")
	_set_enemies(_state == "fight" and role == "fighter")
	if _box and mode == PkRules.Mode.TONG_KIM_LOL:
		_box.visible = (_state == "waiting" or _done)
	if _reject_button:
		var my_name := GameManager.local_profile.display_name if GameManager.local_profile else ""
		var is_host: bool = fighters.size() > 0 and str(fighters[0]) == my_name
		_reject_button.visible = is_host and fighters.size() >= 2 and _state in ["waiting", "prepare"] and not _done
	if _start_button and _ready_button:
		var my_name := GameManager.local_profile.display_name if GameManager.local_profile else ""
		var is_host: bool = fighters.size() > 0 and str(fighters[0]) == my_name
		var can_wait := _state == "waiting" and not _done
		_start_button.visible = is_host and can_wait
		_ready_button.visible = (not is_host) and role == "fighter" and can_wait
		if is_host and can_wait:
			if mode == PkRules.Mode.TONG_KIM_LOL:
				var count_a: int = (s.get("team_a", []) as Array).size()
				var count_b: int = (s.get("team_b", []) as Array).size()
				var is_full := (count_a == team_size and count_b == team_size)
				if not is_full:
					_start_button.disabled = true
					_start_button.text = "Chờ đủ người (%d/%d)" % [fighters.size(), team_size * 2]
				else:
					_start_button.disabled = false
					_start_button.text = "Bắt đầu trận"

## Chỉ đối thủ của mình là địch (chiêu trúng -> gửi server như cừu sát); người xem / người phòng khác không bao giờ.
func _set_enemies(on: bool) -> void:
	var sync := NetWorldSync.current
	if sync == null:
		return
	for r: RemotePlayer in sync.remotes():
		if is_instance_valid(r):
			r.set_pk_enemy(on and _enemy_eids.has(r.eid))

func _on_reject_pressed() -> void:
	if _reject_button:
		_reject_button.visible = false
	if _start_button:
		_start_button.visible = false
	if _ready_button:
		_ready_button.visible = false
	NetClient.send_arena(ArenaServer.OP_REJECT_OPPONENT)
	_say("Đang từ chối đối thủ…")

func _on_result(r: Dictionary) -> void:
	_done = true
	_set_enemies(false)
	if _box and mode == PkRules.Mode.TONG_KIM_LOL:
		_box.visible = (_state == "waiting" or _done)
	if _reject_button:
		_reject_button.visible = false
	if _start_button:
		_start_button.visible = false
	if _ready_button:
		_ready_button.visible = false
	var fighter := bool(r.get("fighter", false))
	if fighter:
		var win := bool(r.get("win", false))
		var delta := int(r.get("points_delta", 0))
		var pts_text := ""
		if delta != 0:
			pts_text = " (+%d điểm)" % delta if delta > 0 else " (%d điểm)" % delta
		_title.text = ("THẮNG" if win else "THUA") + pts_text
		_title.add_theme_color_override("font_color", GameUi.GOLD if win else Color(1.0, 0.4, 0.4))
		PkMatch.record_result(int(r.get("mode", mode)) as PkRules.Mode, win)
	else:
		_title.text = "%s thắng" % r.get("winner", "?")
	_clock.text = str(r.get("why", ""))
	_say(str(r.get("why", "")))

func _process(delta: float) -> void:
	if _searching >= 0.0:
		_searching += delta
		_clock.text = "%s / %s" % [TimeChallenge.format_time(int(_searching)), TimeChallenge.format_time(int(PkRules.MATCH_WAIT_SEC))]

func _on_disconnected(code: String, message: String) -> void:
	if code == "arena_end":
		_leave(message)

## Không có đối thủ thật: đấu với bot cùng cấp (Đại hội võ lâm: cùng phái) ngay trên đấu trường offline.
func _play_bot() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		_leave("Không tìm được đối thủ.")
		return
	_say("Không tìm được đối thủ — ghép với cao thủ cùng cấp.")
	var bot := PkBotProfile.create(profile.level, profile.sect_id if mode == PkRules.Mode.DAI_HOI else "")
	NetClient.disconnect_from_server()
	GameManager.field_map = PkRules.arena_entry({"mode": mode, "opponent": bot.to_dict()})
	get_tree().change_scene_to_file(GAME_SCENE)

var _leaving: bool = false

func _on_leave_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	NetClient.send_arena(ArenaServer.OP_LEAVE)
	_leave("Đã rời đấu trường.")

## Báo lý do rồi về Character Hub.
func _leave(message: String) -> void:
	if not is_inside_tree():
		return
	_leaving = true
	set_process(false)
	_clock.text = message
	_leave_button.disabled = true
	_say(message)
	await get_tree().create_timer(LEAVE_DELAY).timeout
	if is_inside_tree():
		NetClient.disconnect_from_server()
		GameManager.field_map = {}
		get_tree().change_scene_to_file(HUB_SCENE)

func _say(text: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("notify") and text != "":
		player.notify(text)

# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var box := VBoxContainer.new()
	_box = box
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-200, 52)
	box.custom_minimum_size = Vector2(400, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = _label(PkRules.MODE_NAMES[mode], 18, GameUi.GOLD)
	_clock = _label("Đang vào đấu trường…", 22, Color(1, 1, 1))
	_info = _label("", 14, GameUi.TEXT)
	for l in [_title, _clock, _info]:
		box.add_child(l)
	_leave_button = GameUi.button("Rời đấu trường")
	_leave_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave_button.pressed.connect(_on_leave_pressed)
	box.add_child(_leave_button)
	if PkRules.can_kick(mode):
		_reject_button = GameUi.button("Từ chối đối thủ")
		_reject_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_reject_button.visible = false
		_reject_button.pressed.connect(_on_reject_pressed)
		box.add_child(_reject_button)
	if mode == PkRules.Mode.TONG_KIM_LOL or mode == PkRules.Mode.THACH_DAU or mode == PkRules.Mode.LON_XON:
		_start_button = GameUi.button("Bắt đầu trận")
		_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_start_button.visible = false
		_start_button.pressed.connect(func() -> void:
			NetClient.send_arena(ArenaServer.OP_START)
		)
		box.add_child(_start_button)

		_ready_button = GameUi.button("Sẵn sàng")
		_ready_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_ready_button.visible = false
		_ready_button.pressed.connect(func() -> void:
			_is_ready = not _is_ready
			_ready_button.text = "Hủy sẵn sàng" if _is_ready else "Sẵn sàng"
			NetClient.send_arena(ArenaServer.OP_READY, {"ready": _is_ready})
		)
		box.add_child(_ready_button)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
