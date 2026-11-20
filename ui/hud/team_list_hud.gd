extends PanelContainer
class_name TeamListHud
## KHUNG DANH SÁCH TỔ ĐỘI góc trên-trái màn chơi (ngay dưới hàng nút chế độ PK "Luyện Công", tức dưới khung "Phòng #ID").
## Mỗi ĐỒNG ĐỘI (không gồm bản thân — máu mình đã có ở thanh trên cùng) 1 dòng: cờ đội trưởng + tên + thanh máu.
## Bản VLTK gốc (S3Client) chỉ có cửa sổ Quản lý tổ đội (UiTeamManage) + cờ đội trưởng; khung này theo bố cục bản di động.
##   - Online: máu đồng đội do server gửi (S_TEAM_HP, ~3 lần/giây khi đổi) — kể cả đồng đội ở ngoài tầm nhìn / khác phòng (tô mờ).
##     Khung này cũng báo % máu của mình lên server (C_HP) khi đổi, để đồng đội thấy.
##   - Offline: đồng đội là người chơi giả (không có thân trên map) — thanh máu đầy.
##   - Bấm vào 1 dòng: chọn đồng đội đó làm mục tiêu nếu đang thấy họ trên map.
## Mọi dòng nằm chung 1 KHUNG LỚN nền bán trong suốt (thấy map phía sau); từng dòng không có khung / nền riêng.
## Ẩn khi không có tổ đội. Màu / chữ lấy từ GameUi.

const WIDTH := 178.0
const ROW_HEIGHT := 32.0
const DEFAULT_TOP := 112.0         ## khi không tìm thấy hàng nút PK (TopLeftActionBar ở main.gd: y 72..104)
const DEFAULT_LEFT := 12.0
const GAP_BELOW_BAR := 8.0
const HP_SEND_INTERVAL := 0.2      ## nhịp kiểm tra máu mình để báo server (chỉ gửi khi % đổi)
const PAD := 6.0                   ## lề trong của khung lớn
const ROW_WIDTH := WIDTH - PAD * 2.0
const FRAME_BG := Color(0.035, 0.040, 0.040, 0.45)       ## nền khung lớn — bán trong suốt
const FRAME_BORDER := Color(0.24, 0.24, 0.21, 0.55)
const ROW_HOVER := Color(1.0, 1.0, 1.0, 0.07)            ## dòng đang trỏ / bấm: sáng nhẹ, không viền

var _profile: PlayerProfile = null
var _team: TeamService = null
var _header: Label
var _list: VBoxContainer           ## tiêu đề + các dòng, nằm trong khung lớn
var _rows: Array = []              ## [{id, name: Label, bar: HpBar, button: Button}]
var _anchor: Control = null        ## hàng nút PK của main.gd — khung bám ngay bên dưới
var _player: Node = null
var _hp_clock := 0.0
var _sent_hp := -1
var _sent_eid := -1

## Thanh máu mảnh (vẽ tay cho nhẹ — không dùng ProgressBar có theme).
class HpBar extends Control:
	var ratio := 1.0
	var dim := false
	func set_ratio(r: float, d: bool) -> void:
		r = clampf(r, 0.0, 1.0)
		if is_equal_approx(r, ratio) and d == dim:
			return
		ratio = r
		dim = d
		queue_redraw()
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, GameUi.BG_INNER)
		if ratio > 0.0:
			var c := Color(0.86, 0.20, 0.18) if ratio > 0.3 else Color(0.95, 0.55, 0.15)
			if dim:
				c = c.darkened(0.45)
			draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2.0) * ratio, size.y - 2.0)), c)
		draw_rect(rect, GameUi.BORDER, false, 1.0)

## Cờ đội trưởng nhỏ (cán + lá cờ đỏ) — vẽ tay để chạy giống nhau trên mọi máy, không phụ thuộc font emoji.
class CaptainFlag extends Control:
	func _draw() -> void:
		var h := size.y
		draw_line(Vector2(2, 1), Vector2(2, h - 1), GameUi.GOLD, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(3, 1), Vector2(size.x - 1, 4.5), Vector2(3, 8)]), Color(0.90, 0.18, 0.15))

func _ready() -> void:
	name = "TeamListHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", GameUi.box(FRAME_BG, FRAME_BORDER, GameUi.RADIUS_PANEL, 1, int(PAD)))
	custom_minimum_size = Vector2(WIDTH, 0)
	size = Vector2(WIDTH, 0)
	visible = false
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 2)
	add_child(_list)
	_header = Label.new()
	_header.add_theme_color_override("font_color", GameUi.TITLE)
	_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_header.add_theme_constant_override("outline_size", 3)
	_header.add_theme_font_size_override("font_size", 12)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(_header)
	_place()

func _process(delta: float) -> void:
	if _profile != GameManager.local_profile:
		_bind(GameManager.local_profile)
	_place()
	_hp_clock += delta
	if _hp_clock >= HP_SEND_INTERVAL:
		_hp_clock = 0.0
		_report_my_hp()

func _exit_tree() -> void:
	_bind(null)

# ------------------------------------------------------------------ dữ liệu
func _bind(p: PlayerProfile) -> void:
	if _team:
		if _team.changed.is_connected(_rebuild):
			_team.changed.disconnect(_rebuild)
		if _team.hp_changed.is_connected(_refresh_hp):
			_team.hp_changed.disconnect(_refresh_hp)
	_profile = p
	_team = SocialHub.of(p).team if p else null
	if _team:
		_team.changed.connect(_rebuild)
		_team.hp_changed.connect(_refresh_hp)
	_rebuild()

## Đồng đội cần hiện (đội trưởng trước), không gồm bản thân.
func _shown_members() -> Array:
	var out := []
	if _team == null or not _team.in_team():
		return out
	for m in _team.all_members():
		if not m.is_local:
			out.append(m)
	return out

func _rebuild() -> void:
	for r in _rows:
		_list.remove_child(r.button)
		(r.button as Node).queue_free()
	_rows.clear()
	_refresh_world_name_colors()
	var shown := _shown_members()
	visible = not shown.is_empty()
	if not visible:
		return
	_header.text = "Tổ đội %d/%d" % [_team.total(), _team.capacity()]
	for m in shown:
		_rows.append(_make_row(m, m == _team.captain))
	reset_size()
	_refresh_hp()

## Vào / rời đội, đổi đội trưởng: tô lại tên người chơi khác trên map (đồng đội mang màu phe đội trưởng — RemotePlayer._camp_color).
func _refresh_world_name_colors() -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("other_players"):
		if n is RemotePlayer:
			(n as RemotePlayer).refresh_name_color()

func _make_row(m: TeamService.Member, is_captain: bool) -> Dictionary:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "%s — cấp %d%s" % [m.name, m.level, " (đội trưởng)" if is_captain else ""]
	var hover := GameUi.box(ROW_HOVER, Color(0, 0, 0, 0), 4, 0, 0)
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_on_row_pressed.bind(m.id))
	_list.add_child(btn)

	var flag_w := 12.0
	if is_captain:
		var flag := CaptainFlag.new()
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flag.position = Vector2(1, 5)
		flag.size = Vector2(flag_w, 13)
		btn.add_child(flag)
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = m.name
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))   ## nền khung trong suốt: viền chữ cho dễ đọc
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_color", GameUi.GOLD if is_captain else GameUi.TEXT)
	lbl.position = Vector2(2.0 + (flag_w + 2.0 if is_captain else 0.0), 1)
	lbl.size = Vector2(ROW_WIDTH - lbl.position.x - 2.0, 18)
	btn.add_child(lbl)
	var bar := HpBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(2, ROW_HEIGHT - 10)
	bar.size = Vector2(ROW_WIDTH - 4, 6)
	btn.add_child(bar)
	return {"id": m.id, "member": m, "name": lbl, "bar": bar, "button": btn, "captain": is_captain}

func _refresh_hp() -> void:
	if _team == null:
		return
	for r in _rows:
		var m: TeamService.Member = r.member
		var hp := _team.hp_of(m)
		var near := _team.is_near(m)
		(r.bar as HpBar).set_ratio(hp / 100.0, not near)
		var col: Color = GameUi.GOLD if r.captain else GameUi.TEXT
		if hp <= 0 or not near:
			col = GameUi.MUTED
		(r.name as Label).add_theme_color_override("font_color", col)

## Số liệu cho test: [{name, hp, captain, near}] đúng thứ tự đang hiện.
func snapshot() -> Array:
	var out := []
	for r in _rows:
		out.append({"name": (r.name as Label).text, "hp": int(round((r.bar as HpBar).ratio * 100.0)),
			"captain": bool(r.captain), "near": not (r.bar as HpBar).dim})
	return out

# ------------------------------------------------------------------ bấm chọn
func _on_row_pressed(member_id: int) -> void:
	var player := _local_player()
	if player == null or NetWorldSync.current == null or not player.has_method("set_target"):
		return
	var r := NetWorldSync.current.remote_of(member_id)
	if r != null:
		player.call("set_target", r, true)

# ------------------------------------------------------------------ vị trí
func _place() -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		_anchor = null
		var scene := get_tree().current_scene if is_inside_tree() else null
		if scene:
			_anchor = scene.find_child("TopLeftActionBar", true, false) as Control
	var pos := Vector2(DEFAULT_LEFT, DEFAULT_TOP)
	if _anchor and _anchor.is_visible_in_tree():
		var r := _anchor.get_global_rect()
		pos = Vector2(r.position.x, r.end.y + GAP_BELOW_BAR)   ## get_global_rect đã tính scale của hàng nút
	if not position.is_equal_approx(pos):
		position = pos

# ------------------------------------------------------------------ báo máu mình
func _local_player() -> Node:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return _player

func _report_my_hp() -> void:
	if not NetClient.is_in_world():
		_sent_hp = -1
		return
	var p := _local_player()
	if p == null:
		return
	var mx := float(p.get("max_health"))
	var pct := 100
	if p.has_method("is_dead") and p.call("is_dead"):
		pct = 0
	elif mx > 0.0:
		pct = clampi(int(round(100.0 * float(p.get("health")) / mx)), 0, 100)
		if pct == 0 and float(p.get("health")) > 0.0:
			pct = 1   ## còn sống thì thanh máu không về 0
	if pct != _sent_hp or NetClient.my_eid != _sent_eid:
		_sent_hp = pct
		_sent_eid = NetClient.my_eid
		NetClient.send_hp(pct)
