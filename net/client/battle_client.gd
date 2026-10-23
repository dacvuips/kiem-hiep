extends CanvasLayer
class_name BattleClient
## Phía game của CHIẾN TRƯỜNG TỐNG KIM (BattleServer ở server): Main thêm node này khi vào trận từ màn "Vượt Ải" tab Ải.
##   - Kết nối xong -> gửi báo danh phe đã chọn; server từ chối (lệch quân, đổi phe, chưa đủ cấp...) -> báo lý do, về Character Hub.
##   - Bảng nhỏ giữa trên màn hình: giai đoạn + đếm ngược, số người / điểm 2 phe, điểm / hạ / chết của mình.
##   - Lúc báo danh: giữ trong doanh trại phe mình (VltkWorld.set_confine, server cũng chặn). Ra / vào hậu doanh bằng ô cổng
##     (server dịch chuyển). Mới hồi sinh: cổng hậu doanh chưa cho ra vài giây.
##   - Khai chiến: người phe kia thành địch (RemotePlayer.set_pk_enemy) — chiêu đánh trúng gửi server như cừu sát.
##   - Chết bấm "Về thành dưỡng sức": về hậu doanh phe mình (VltkWorld.respawn_point; server kéo về đúng điểm).
##   - Quân nhu quan (dấu + tên trên bản đồ, ở hậu doanh): đứng gần thì hiện nút mở BattleShopWindow mua thuốc.
##   - Nguyên Soái phe mình không phải mục tiêu (bỏ khỏi nhóm "enemies"); Nguyên Soái phe kia đánh được.

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"
const SIDE_NAMES := {"song": "Tống", "jin": "Kim"}
const PHASE_NAMES := {"signup": "Báo danh — chờ khai chiến", "fight": "Đang khai chiến", "ended": "Đã kết thúc"}
const LEAVE_DELAY := 4.0

var side := ""
var map_id := 0
var _camps := {}                    ## khu "1" / "2" -> {home: Vector2, rect: Rect2}
var area := ""                      ## khu doanh trại phe mình trận này (server bốc thăm, gói "joined")
var _joined := false
var _phase := ""
var _phase_label: Label
var _sides_label: Label
var _me_label: Label
var _shop_button: Button
var _markers: Array[Node] = []

static func create(battle_side: String, battle_map_id: int) -> BattleClient:
	var b := BattleClient.new()
	b.side = battle_side
	b.map_id = battle_map_id
	return b

func _ready() -> void:
	layer = 20
	_load_camps()
	_build_hud()
	NetClient.connected_to_world.connect(func(_eid: int, _feet: Vector2, _name: String) -> void:
		NetClient.send_battle(BattleServer.OP_JOIN, {"side": side}))
	NetClient.battle_message.connect(_on_message)
	NetClient.disconnected.connect(_on_disconnected)
	if NetClient.is_in_world():
		NetClient.send_battle(BattleServer.OP_JOIN, {"side": side})

func _load_camps() -> void:
	var path := "res://data/battle/map_%d.json" % map_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		return
	for s in parsed["areas"]:
		var d: Dictionary = parsed["areas"][s]
		var r: Array = d["camp_rect"]
		var h: Array = d["home"][0]
		_camps[s] = {"home": Vector2(float(h[0]), float(h[1])), "rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
			"doctor": Vector2(float(d["doctor"][0]), float(d["doctor"][1]))}

func _build_hud() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	var panel := GameUi.panel(GameUi.PANEL)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(-210, 52)
	panel.custom_minimum_size.x = 420
	anchor.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_phase_label = GameUi.label("Chiến Trường Tống Kim — đang báo danh phe %s…" % SIDE_NAMES.get(side, "?"), GameUi.TITLE, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_sides_label = GameUi.label("", GameUi.TEXT, 13, HORIZONTAL_ALIGNMENT_CENTER)
	_me_label = GameUi.label("", GameUi.LABEL_GREEN, 13, HORIZONTAL_ALIGNMENT_CENTER)
	for l in [_phase_label, _sides_label, _me_label]:
		box.add_child(l)
	var right := Control.new()
	right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	_shop_button = GameUi.button("Quân nhu quan", GameUi.PRIMARY)
	_shop_button.custom_minimum_size = Vector2(170, 44)
	_shop_button.position = Vector2(-190, -22)
	_shop_button.visible = false
	_shop_button.pressed.connect(func() -> void: BattleShopWindow.open(self))
	right.add_child(_shop_button)

## Hiện nút Quân nhu quan khi đứng gần Quân nhu quan của trại mình.
func _process(_d: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var near := false
	if player and _joined and _camps.has(area):
		var feet := player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
		near = feet.distance_to(_camps[area]["doctor"]) <= BattleServer.DOCTOR_REACH - 40.0
	_shop_button.visible = near

## Dấu Quân nhu quan ở 2 hậu doanh (chưa có hình NPC trong dữ liệu game): vòng tròn + tên.
class QuartermasterMarker extends Node2D:
	func _ready() -> void:
		var l := Label.new()
		l.text = "Quân Nhu Quan"
		l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		l.position = Vector2(-48, -70)
		add_child(l)
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 26.0, Color(0.95, 0.75, 0.25, 0.35))
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.35), 2.0)

func _place_markers() -> void:
	if not _markers.is_empty():
		return
	var parent: Node = VltkWorld.entity_parent()
	if parent == null:
		return
	for a in _camps:
		var mk := QuartermasterMarker.new()
		mk.position = _camps[a]["doctor"]
		parent.add_child(mk)
		_markers.append(mk)

func _exit_tree() -> void:
	for mk in _markers:
		if is_instance_valid(mk):
			mk.queue_free()

# ---------------------------------------------------------------- gói từ server

func _on_message(msg: Dictionary) -> void:
	match str(msg.get("op", "")):
		"joined":
			_joined = true
			side = str(msg.get("side", side))
			area = str(msg.get("area", ""))
			_place_markers()
			if VltkWorld.current and _camps.has(area):
				VltkWorld.current.respawn_point = _camps[area]["home"]
		"state":
			_on_state(msg)
		"reject":
			_leave(str(msg.get("message", "Không vào được chiến trường")))
		"result":
			var w := str(msg.get("winner", ""))
			var me: Dictionary = msg.get("me", {})
			_phase = "ended"
			_phase_label.text = "Phe %s thắng!  %d : %d" % [SIDE_NAMES.get(w, "?"), int(msg.get("song_points", 0)), int(msg.get("jin_points", 0))]
			_me_label.text = "Bạn: %d điểm · hạ %d · chết %d" % [int(me.get("points", 0)), int(me.get("kills", 0)), int(me.get("deaths", 0))]
			var rw: Dictionary = msg.get("reward", {})
			if not rw.is_empty():
				_sides_label.text = "Thưởng: %d điểm tích lũy (tổng %d)%s%s" % [int(rw.get("points", 0)), int(rw.get("total", 0)),
					(" · %d danh vọng" % int(rw["repute"])) if rw.has("repute") else "", (" · " + str(rw["item"])) if rw.has("item") else ""]
			_set_enemies(false)
			_confine(false)

func _on_state(s: Dictionary) -> void:
	_phase = str(s.get("phase", ""))
	var left := int(s.get("left", 0))
	_phase_label.text = "%s · %02d:%02d" % [PHASE_NAMES.get(_phase, _phase), left / 60, left % 60]
	_sides_label.text = "Tống %d người · %d điểm      Kim %d người · %d điểm" % [int(s.get("song", 0)), int(s.get("song_points", 0)),
		int(s.get("jin", 0)), int(s.get("jin_points", 0))]
	var me: Dictionary = s.get("me", {})
	_me_label.text = "Bạn (%s): %d điểm · hạ %d · chết %d" % [SIDE_NAMES.get(side, "?"), int(me.get("points", 0)), int(me.get("kills", 0)), int(me.get("deaths", 0))]
	_confine(_phase == "signup")
	_set_enemies(_phase == "fight")

## Lúc chưa khai chiến / mới hồi sinh: chỉ đi trong doanh trại phe mình.
func _confine(on: bool) -> void:
	if VltkWorld.current == null or not _camps.has(area):
		return
	VltkWorld.current.set_confine(_camps[area]["rect"] if on else Rect2())

## Người phe kia là địch (đánh được) chỉ khi đang khai chiến.
func _set_enemies(on: bool) -> void:
	var sync := NetWorldSync.current
	if sync == null:
		return
	var mine := int(BattleServer.NATION_OF.get(side, Nation.Type.NONE))
	for r: RemotePlayer in sync.remotes():
		if is_instance_valid(r):
			r.set_pk_enemy(on and Nation.is_hostile(mine, r.nation))
	## Nguyên Soái phe mình: không phải mục tiêu của chiêu mình.
	var own_marshal := int(BattleServer.MARSHAL_TPL.get(side, -1))
	for m in sync.monsters():
		if is_instance_valid(m) and int(m.monster_id) == own_marshal and m.is_in_group("enemies"):
			m.remove_from_group("enemies")

func _on_disconnected(code: String, message: String) -> void:
	if code in ["battle_end", "battle_no_side"]:
		_leave(message)

## Báo lý do rồi về Character Hub.
func _leave(message: String) -> void:
	_phase_label.text = message
	_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sides_label.text = "Đang trở về…"
	_me_label.text = ""
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("notify"):
		player.notify(message)
	set_process(false)
	await get_tree().create_timer(LEAVE_DELAY).timeout
	if is_inside_tree():
		NetClient.disconnect_from_server()
		get_tree().change_scene_to_file(HUB_SCENE)
