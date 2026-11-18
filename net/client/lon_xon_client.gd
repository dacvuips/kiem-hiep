extends CanvasLayer
class_name LonXonClient
## Phía game của màn LỘN XỘN ONLINE (LonXonServer trên game server thế giới). Main thêm node này khi vào map có cờ "lonxon_online"
## (LonXonManager.start_online — từ tin "match" lúc đang ở Hub).
##   - Hồ sơ trong host là bản TẠM cấp 50 của server (S_PROFILE); bản thật sao lưu ở LonXonManager và trả lại khi rời.
##   - Vào host / mỗi lần hồi sinh: popup chọn thẻ 5x (PubgDraftPopup tier 5) -> gửi OP_DRAFT, server sinh ngựa + vũ khí.
##   - Chết: server rải đồ + Lệnh Bài, báo "died" -> đếm ngược 5 giây -> gửi C_REVIVE (lặp tới khi server báo "respawn").
##   - Lệnh Bài đang giữ: nhân vật to hơn, tầm skill xa hơn, camera thu nhỏ (LonXonRules.*_for). Người khác to theo "sizes" của bảng.
##   - Góc trên trái: Top 5 điểm; số hạng 1/2/3 trên đầu người top 3.

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const BADGE_NAME := "LonXonBadge"
const BADGE_COLORS := [Color(1.0, 0.84, 0.2), Color(0.85, 0.88, 0.95), Color(0.85, 0.55, 0.3)]
const REVIVE_RETRY := 1.0

var _title: Label
var _info: Label
var _countdown: Label
var _leave_button: Button
var _board_rows: Array[Label] = []
var _board_me: Label
var _tokens := 0
var _score := 0
var _badges := {}        ## eid -> hạng
var _sizes := {}         ## eid -> Lệnh Bài
var _dead := false
var _revive_in := -1.0   ## > 0: đang đếm ngược; <= 0 sau khi đếm xong: gửi C_REVIVE mỗi REVIVE_RETRY giây
var _revive_retry := 0.0
var _leaving := false

static func create() -> LonXonClient:
	return LonXonClient.new()

func _ready() -> void:
	add_to_group("lonxon_client")
	layer = 20
	_build_hud()
	LonXonRules.in_match = true
	var player := _player()
	if player:
		player.suppress_death_popup = true   ## chết: đếm ngược hồi sinh của Lộn Xộn thay cho "Về thành dưỡng sức"
		if player.has_signal("died"):
			player.died.connect(_on_player_died)
	## Hồ sơ tạm ngay trên máy (server sẽ gửi bản chuẩn) — chỉ làm khi ĐÃ rời Hub (xem LonXonManager.start_online).
	var prof := GameManager.local_profile
	if prof != null:
		LonXonRules.apply_start(prof)
		if SaveManager != null and SaveManager.has_signal("profile_changed"):
			SaveManager.profile_changed.emit(prof)
	NetClient.lonxon_message.connect(_on_message)
	NetClient.entity_spawned.connect(func(_i: Dictionary) -> void: _apply_remote_looks.call_deferred())
	NetClient.disconnected.connect(_on_disconnected)
	NetClient.connected_to_world.connect(func(_eid: int, _feet: Vector2, _name: String) -> void:
		NetClient.send_lonxon(LonXonServer.OP_STATE))
	if NetClient.is_in_world():
		NetClient.send_lonxon(LonXonServer.OP_STATE)
	_open_draft.call_deferred()
	_apply_tokens(0)

func _exit_tree() -> void:
	var player := _player()
	if player:
		player.view_mult = 1.0
		player.skill_radius_mult = 1.0
	LonXonRules.in_match = false

func _player() -> Node:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null

func _process(delta: float) -> void:
	if not PubgDraftPopup.lonxon_pending_draft.is_empty() and LonXonManager.match_confirmed and NetClient.is_in_world() and not _dead:
		NetClient.send_lonxon(LonXonServer.OP_DRAFT, PubgDraftPopup.lonxon_pending_draft.duplicate())
		PubgDraftPopup.lonxon_pending_draft = {}
	if _dead:
		if _revive_in > 0.0:
			_revive_in -= delta
			_countdown.text = "💀 Bị hạ — hồi sinh sau %d giây" % ceili(maxf(_revive_in, 0.0))
		else:
			_revive_retry -= delta
			if _revive_retry <= 0.0:
				_revive_retry = REVIVE_RETRY
				_countdown.text = "Đang hồi sinh…"
				NetClient.send_revive()

# ---------------------------------------------------------------- tin server

func _on_message(msg: Dictionary) -> void:
	match str(msg.get("op", "")):
		"match":
			LonXonManager.match_confirmed = true
			_title.text = "🌀 LỘN XỘN — HOST %d" % int(msg.get("host", LonXonManager.host))
		"tokens":
			_tokens = int(msg.get("n", 0))
			_score = int(msg.get("score", 0))
			_apply_tokens(_tokens)
			if int(msg.get("gained", 0)) > 0:
				_say("🏅 +%d Lệnh Bài (đang giữ %d — %d điểm)" % [int(msg.gained), _tokens, _score])
		"board":
			_on_board(msg)
		"level":
			_say("⬆️ Lên cấp %d (+%d)" % [int(msg.get("level", 0)), int(msg.get("gained", 0))])
			_refresh_info()
		"died":
			_start_countdown(float(msg.get("respawn_in", LonXonRules.RESPAWN_SEC)))
			var killer := str(msg.get("killer", ""))
			_say("💀 %sRớt %d món + %d Lệnh Bài." % ["Bị %s hạ. " % killer if killer != "" else "", int(msg.get("items", 0)), int(msg.get("tokens", 0))])
		"respawn":
			_on_respawn()
		"reject":
			_say(str(msg.get("msg", "")))

func _on_player_died() -> void:
	## Server sẽ báo "died" (kèm thời gian chờ) — chưa nhận thì vẫn đếm từ lúc chết ở máy mình.
	if not _dead:
		_start_countdown(LonXonRules.RESPAWN_SEC)

func _start_countdown(sec: float) -> void:
	_dead = true
	_revive_in = maxf(_revive_in, sec) if _revive_in > 0.0 else sec
	_revive_retry = 0.0
	_countdown.visible = true

func _on_respawn() -> void:
	_dead = false
	_revive_in = -1.0
	_countdown.visible = false
	var player := _player()
	if player and player.has_method("revive"):
		player.revive()
	_say("✨ Đã hồi sinh — miễn sát thương %d giây." % int(LonXonRules.SPAWN_PROTECT_SEC))
	_open_draft()

func _open_draft() -> void:
	var prof := GameManager.local_profile
	if prof == null or _leaving or not is_inside_tree():
		return
	var player := _player()
	var on_done := func() -> void:
		if is_instance_valid(player) and player.has_method("refresh_combat_stats"):
			player.refresh_combat_stats()
		elif is_instance_valid(player) and player.has_method("refresh_appearance"):
			player.refresh_appearance()
	PubgDraftPopup.open(get_tree().current_scene, prof, on_done, PubgDraftPopup.TIER_LONXON)

# ---------------------------------------------------------------- Lệnh Bài / bảng / số hạng

func _apply_tokens(n: int) -> void:
	var player := _player()
	if player:
		player.view_mult = LonXonRules.view_mult_for(n)
		player.skill_radius_mult = LonXonRules.radius_mult_for(n)
		_scale_node(player, n)
		_set_badge(player, int(_badges.get(NetClient.my_eid, 0)), n)
	_refresh_info()

static func _scale_node(node: Node, tokens: int) -> void:
	var av = node.get("avatar")
	if av is Node2D:
		(av as Node2D).scale = Vector2.ONE * LonXonRules.scale_for(tokens)

## Số hạng 1/2/3 to trên đầu (0 = gỡ).
static func _set_badge(node: Node, rank: int, tokens: int) -> void:
	var lbl := node.get_node_or_null(BADGE_NAME) as Label
	if rank <= 0:
		if lbl:
			lbl.queue_free()
		return
	if lbl == null:
		lbl = Label.new()
		lbl.name = BADGE_NAME
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(60, 40)
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.z_index = 13
		node.add_child(lbl)
	lbl.text = str(rank)
	lbl.add_theme_color_override("font_color", BADGE_COLORS[clampi(rank - 1, 0, 2)])
	lbl.position = Vector2(-30, -112.0 - 60.0 * (LonXonRules.scale_for(tokens) - 1.0))

func _on_board(msg: Dictionary) -> void:
	_badges.clear()
	for k in msg.get("badges", {}):
		_badges[int(k)] = int(msg.badges[k])
	_sizes.clear()
	for k in msg.get("sizes", {}):
		_sizes[int(k)] = int(msg.sizes[k])
	var top: Array = msg.get("top", [])
	var my_rank := 0
	for i in _board_rows.size():
		var row := _board_rows[i]
		if i < top.size():
			var e: Dictionary = top[i]
			var mine := int(e.get("eid", 0)) == NetClient.my_eid
			if mine:
				my_rank = i + 1
			row.text = "%d. %s — %s" % [i + 1, str(e.get("name", "?")), _fmt(int(e.get("score", 0)))]
			row.add_theme_color_override("font_color", GameUi.GOLD if mine else (BADGE_COLORS[i] if i < 3 else GameUi.TEXT))
			row.visible = true
		else:
			row.visible = i == 0
			row.text = "Chưa ai có Lệnh Bài" if i == 0 else ""
			row.add_theme_color_override("font_color", GameUi.TEXT)
	_board_me.visible = my_rank == 0
	_board_me.text = "Bạn: %s điểm (%d Lệnh Bài)" % [_fmt(_score), _tokens]
	_apply_tokens(_tokens)
	_apply_remote_looks()

func _apply_remote_looks() -> void:
	var sync := NetWorldSync.current
	if sync == null:
		return
	for r: RemotePlayer in sync.remotes():
		if not is_instance_valid(r):
			continue
		var n := int(_sizes.get(r.eid, 0))
		_scale_node(r, n)
		_set_badge(r, int(_badges.get(r.eid, 0)), n)
		r.set_pk_enemy(true)   ## mỗi người 1 phe: ai cũng là đối thủ

static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out

func _refresh_info() -> void:
	if _info == null:
		return
	var prof := GameManager.local_profile
	_info.text = "Cấp %d · 🏅 %d Lệnh Bài · %s điểm" % [prof.level if prof else 0, _tokens, _fmt(_score)]

# ---------------------------------------------------------------- rời host

func _on_leave_pressed() -> void:
	if _leaving:
		return
	SocialWindow.confirm(get_tree().current_scene, "Rời Lộn Xộn", "Rời bây giờ: toàn bộ đồ và Lệnh Bài đang giữ sẽ rớt ra đất. Chắc chắn rời?",
		func() -> void:
			NetClient.send_lonxon(LonXonServer.OP_QUIT)
			_leave("Đã rời Lộn Xộn."))

func _on_disconnected(code: String, message: String) -> void:
	LonXonManager.match_confirmed = false
	if code == "lonxon_end":
		_leave(message if message != "" else "Đã rời Lộn Xộn.")
	elif not _leaving:
		_leave("Mất kết nối — đã rời Lộn Xộn.")

## Trả hồ sơ thật rồi về Character Hub. Ngắt kết nối TRƯỚC để không gửi gì thêm lên host.
func _leave(message: String) -> void:
	if _leaving or not is_inside_tree():
		return
	_leaving = true
	set_process(false)
	_say(message)
	_leave_button.disabled = true
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	if NetClient.is_in_world():
		NetClient.disconnect_from_server()
	LonXonManager.end(GameManager.local_profile)
	get_tree().paused = false
	var transition: Node = get_tree().root.get_node_or_null("SceneTransition")
	if transition != null and transition.has_method("change_scene"):
		transition.change_scene(HUB_SCENE, "Về Thành")
	else:
		get_tree().change_scene_to_file(HUB_SCENE)

func _say(text: String) -> void:
	var player := _player()
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
	_title = _label("🌀 LỘN XỘN", 16, GameUi.GOLD)
	_info = _label("Đang vào host…", 14, GameUi.TEXT)
	box.add_child(_title)
	box.add_child(_info)
	_leave_button = GameUi.button("Rời Lộn Xộn")
	_leave_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave_button.pressed.connect(_on_leave_pressed)
	box.add_child(_leave_button)

	_countdown = _label("", 22, Color(1.0, 0.5, 0.4))
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_countdown.custom_minimum_size = Vector2(520, 40)
	_countdown.position = Vector2(-260, -120)
	_countdown.visible = false
	add_child(_countdown)

	## Top 5 góc trên trái (dưới khung thông tin nhân vật).
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 168)
	panel.custom_minimum_size = Vector2(260, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.62)
	sb.border_color = Color(0.95, 0.8, 0.3, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var head := _label("🏆 TOP 5 — LỆNH BÀI", 14, GameUi.GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(head)
	for i in LonXonRules.BOARD_SIZE:
		var row := _label("Chưa ai có Lệnh Bài" if i == 0 else "", 13, GameUi.TEXT)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.visible = i == 0
		v.add_child(row)
		_board_rows.append(row)
	_board_me = _label("", 12, Color(0.75, 0.8, 0.85))
	_board_me.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_board_me)

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
