extends CanvasLayer
class_name PubgClient
## Phía game của trận Chiến Trường Sinh Tồn ONLINE (PubgServer trên game server thế giới). Main thêm node này khi vào map PUBG có
## cờ "pubg_online" (PubgManager.start_online_match — từ tin "match" lúc đang ở Hub).
##   - Hồ sơ trong trận là bản TẠM cấp 200 của server (S_PROFILE); bản thật đã sao lưu ở PubgManager.backup_profile_data và được trả
##     lại khi rời trận (PubgManager.end_match). Server không bao giờ lưu hồ sơ tạm.
##   - Popup chọn thẻ đầu trận ghi lựa chọn vào PubgManager.pending_draft -> gửi OP_DRAFT (server sinh ngựa 8x + vũ khí cấp 10 + cộng
##     điểm tiềm năng theo build đã lưu).
##   - Vòng bo: dựng lại theo seed + thời gian đã đấu của server (PubgManager.sync_zone); máy mình trừ máu khi ở ngoài bo như offline.
##   - Địch = người khác đội còn sống (RemotePlayer.set_pk_enemy); đồng đội tên xanh dương.
##   - Chết = bị loại (không hồi sinh): bảng hạng + nút về Hub. Có kết quả -> server mời rời (mã "pubg_end") -> về Hub.

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const SQUAD_COLOR := Color(0.2, 0.65, 1.0)
const ENEMY_COLOR := Color(1.0, 0.45, 0.4)

var _title: Label
var _info: Label
var _leave_button: Button
var _squad_eids: Array = []
var _enemy_eids: Array = []
var _draft_sent := false
var _out := false          ## đã bị loại / trận đã có kết quả
var _leaving := false

static func create() -> PubgClient:
	return PubgClient.new()

func _ready() -> void:
	add_to_group("pubg_client")
	layer = 20
	_build_hud()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.suppress_death_popup = true   ## chết = bị loại: bảng của trận thay cho "Về thành dưỡng sức"
	## Hồ sơ tạm ngay trên máy (server sẽ gửi bản chuẩn) — chỉ làm khi ĐÃ rời Hub (xem PubgManager.start_online_match).
	var prof := GameManager.local_profile
	if prof != null:
		PubgManager.apply_match_build(prof, false)
		if SaveManager != null and SaveManager.has_signal("profile_changed"):
			SaveManager.profile_changed.emit(prof)
	NetClient.pubg_message.connect(_on_message)
	NetClient.entity_spawned.connect(func(_info: Dictionary) -> void: _apply_flags.call_deferred())   ## người mới hiện ra: tô màu / đánh dấu địch
	NetClient.disconnected.connect(_on_disconnected)
	NetClient.connected_to_world.connect(func(_eid: int, _feet: Vector2, _name: String) -> void:
		NetClient.send_pubg(PubgServer.OP_STATE))
	if NetClient.is_in_world():
		NetClient.send_pubg(PubgServer.OP_STATE)

func _process(_delta: float) -> void:
	if not _draft_sent and not PubgManager.pending_draft.is_empty() and PubgManager.match_confirmed and NetClient.is_in_world():
		_draft_sent = true
		PubgManager.load_build()
		var build := {}
		if PubgManager.has_custom_build:
			for k in ["str", "dex", "vit", "eng"]:
				build[k] = int(PubgManager.pubg_potential_stats.get(k, 0))
		var args: Dictionary = PubgManager.pending_draft.duplicate()
		args["build"] = build
		NetClient.send_pubg(PubgServer.OP_DRAFT, args)

func _on_message(msg: Dictionary) -> void:
	match str(msg.get("op", "")):
		"none":
			## Vào lại server mà không còn trong trận nào (trận đã đóng / bị loại lúc mất kết nối): về Hub, không gửi gì thêm.
			if not PubgManager.match_confirmed:
				_leave("Trận đã kết thúc hoặc bạn không còn trong trận.")
		"match":
			PubgManager.match_confirmed = true
			var b: Array = msg.get("box", [])
			if b.size() >= 4:
				PubgManager.fixed_outer_boundary = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
			PubgManager.sync_zone(int(msg.get("seed", 0)), float(msg.get("elapsed", 0.0)))
		"mstate":
			PubgManager.match_confirmed = true
			_on_state(msg)
		"eliminated":
			_on_eliminated(msg)
		"result":
			_on_result(msg)

func _on_state(s: Dictionary) -> void:
	_squad_eids = s.get("squad_eids", [])
	_enemy_eids = s.get("enemy_eids", [])
	if not _out:
		_info.text = "👥 Còn %d người · %d/%d đội" % [int(s.get("alive_players", 0)), int(s.get("alive_squads", 0)), int(s.get("squads", 0))]
	_apply_flags()

func _apply_flags() -> void:
	var sync := NetWorldSync.current
	if sync == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_name_color") and _squad_eids.size() > 1:
		player.set_name_color(SQUAD_COLOR)
	for r: RemotePlayer in sync.remotes():
		if not is_instance_valid(r):
			continue
		var enemy := _enemy_eids.has(r.eid) and not _out
		r.set_pk_enemy(enemy)
		if _squad_eids.has(r.eid):
			r.set_name_color(SQUAD_COLOR, "[Đồng đội]")
		elif _enemy_eids.has(r.eid):
			r.set_name_color(ENEMY_COLOR)

func _on_eliminated(e: Dictionary) -> void:
	_out = true
	_set_no_enemies()
	var rank := int(e.get("rank", 0))
	if bool(e.get("squad_out", true)) and rank > 0:
		_title.text = "BỊ LOẠI — HẠNG #%d / %d" % [rank, int(e.get("squads", 0))]
	else:
		_title.text = "BẠN ĐÃ BỊ LOẠI"
	_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_info.text = "%s · Đồng đội vẫn có thể chiến đấu tiếp." % str(e.get("why", "")) if not bool(e.get("squad_out", true)) else str(e.get("why", ""))
	_leave_button.text = "Về Character Hub"

func _on_result(r: Dictionary) -> void:
	_out = true
	_set_no_enemies()
	var win := bool(r.get("win", false))
	_title.text = "🏆 ĐẠI CÁT ĐẠI LỢI — TOP 1!" if win else "HẠNG #%d / %d" % [int(r.get("rank", 0)), int(r.get("squads", 0))]
	_title.add_theme_color_override("font_color", GameUi.GOLD if win else Color(0.9, 0.9, 0.9))
	var winners: Array = r.get("winners", [])
	_info.text = "%s%s" % [str(r.get("why", "")), "" if winners.is_empty() else "  ·  Thắng: %s" % ", ".join(PackedStringArray(winners.map(func(n): return str(n))))]
	_leave_button.text = "Về Character Hub"
	_say(_title.text)

func _set_no_enemies() -> void:
	var sync := NetWorldSync.current
	if sync == null:
		return
	for r: RemotePlayer in sync.remotes():
		if is_instance_valid(r):
			r.set_pk_enemy(false)

func _on_leave_pressed() -> void:
	if _leaving:
		return
	if _out:
		_leave("Đã rời Chiến Trường Sinh Tồn.")
		return
	SocialWindow.confirm(get_tree().current_scene, "Rời trận", "Rời trận bây giờ sẽ bị tính là BỊ LOẠI. Đồ nhặt trong trận sẽ mất hết. Chắc chắn rời?",
		func() -> void:
			NetClient.send_pubg(PubgServer.OP_QUIT)
			_leave("Đã rời Chiến Trường Sinh Tồn."))

func _on_disconnected(code: String, message: String) -> void:
	PubgManager.match_confirmed = false
	if code == "pubg_end":
		_leave(message if message != "" else "Chiến Trường Sinh Tồn đã kết thúc.")
	elif not _leaving:
		_leave("Mất kết nối — bạn đã bị loại khỏi trận.")

## Trả hồ sơ thật (bản sao lưu lúc vào trận) rồi về Character Hub. Ngắt kết nối TRƯỚC để không gửi gì thêm lên trận.
func _leave(message: String) -> void:
	if _leaving or not is_inside_tree():
		return
	_leaving = true
	PubgManager.match_confirmed = false
	set_process(false)
	_say(message)
	_leave_button.disabled = true
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	if NetClient.is_in_world():
		NetClient.disconnect_from_server()
	PubgManager.end_match(GameManager.local_profile)
	GameManager.field_map = {}
	get_tree().paused = false
	var transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if transition != null and transition.has_method("change_scene"):
		transition.change_scene(HUB_SCENE, "Về Thành")
	else:
		get_tree().change_scene_to_file(HUB_SCENE)

func _say(text: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("notify") and text != "":
		player.notify(text)

# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-200, 96)
	box.custom_minimum_size = Vector2(400, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = _label("CHIẾN TRƯỜNG SINH TỒN", 16, GameUi.GOLD)
	_info = _label("Đang vào trận…", 14, GameUi.TEXT)
	box.add_child(_title)
	box.add_child(_info)
	_leave_button = GameUi.button("Rời trận")
	_leave_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave_button.pressed.connect(_on_leave_pressed)
	box.add_child(_leave_button)

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
