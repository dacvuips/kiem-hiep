extends SocialWindow
class_name RpsWindow
## CỬA SỔ OẲN TÙ XÌ (Búa / Kéo / Bao) — vẽ theo trạng thái server gửi (S_RPS {op:"state"}, xem RpsServer.state_for):
##   - bảng tỉ số: tên 2 người + số ván thắng, số ván hoà, ván thứ mấy;
##   - ván đang chọn: 3 icon lớn Búa / Kéo / Bao + nút Xác nhận (đã xác nhận thì khoá, chờ đối thủ);
##   - cả 2 xác nhận: đếm ngược 3 giây (đối thủ úp "?"), rồi lật 2 lựa chọn + Thắng / Thua / Hoà, tên người thắng / thua;
##   - nút Chơi tiếp (đủ 2 người bấm thì sang ván mới), Rời cuộc chơi; lịch sử vài ván gần nhất.
## Đóng (✕ / Rời) = gửi {op:"leave"}: server kết thúc trận, báo người kia.

const ICON_PATHS := ["res://assets/ui/rps/bua.png", "res://assets/ui/rps/keo.png", "res://assets/ui/rps/bao.png"]
const ICON_SIZE := 150.0   ## = kích thước thật của ảnh (assets/ui/rps 150x150), không co giãn
const REVEAL_SIZE := 150.0

static var current: RpsWindow

var _st: Dictionary = {}
var _round := 0
var _sel := -1
var _deadline_ms := 0
var _finished := false   ## trận đã kết thúc (không gửi "leave" khi đóng)

var _name_me: Label
var _name_opp: Label
var _score_me: Label
var _score_opp: Label
var _mid: Label
var _status: Label
var _pick_row: HBoxContainer
var _pick_btns: Array[Button] = []
var _reveal_row: HBoxContainer
var _reveal_me: TextureRect
var _reveal_opp: TextureRect
var _reveal_me_lbl: Label
var _reveal_opp_lbl: Label
var _reveal_opp_q: Label   ## dấu ? úp lựa chọn đối thủ lúc đếm ngược
var _big: Label
var _confirm: Button
var _next: Button
var _leave: Button
var _history: VBoxContainer

static func _icon(choice: int) -> Texture2D:
	if choice < 0 or choice >= ICON_PATHS.size() or not ResourceLoader.exists(ICON_PATHS[choice]):
		return null
	return load(ICON_PATHS[choice])

static func choice_name(choice: int) -> String:
	return RpsServer.NAMES[choice] if choice >= 0 and choice < RpsServer.NAMES.size() else "?"

## Tin S_RPS {op: state | end} (NetSocial chuyển tới; lời mời "invite" NetSocial tự hỏi).
static func handle(host: Node, msg: Dictionary) -> void:
	match str(msg.get("op", "")):
		"state":
			if current == null or not is_instance_valid(current):
				current = RpsWindow.new()
				SocialWindow.present(host, current, &"rps")
			current.apply(msg)
		"end":
			if current != null and is_instance_valid(current):
				current._finished = true
				current.close_requested.emit()
			current = null
			SocialWindow.info(host, "Oẳn tù xì", str(msg.get("msg", "Trận Oẳn tù xì đã kết thúc.")))

static func close_current() -> void:
	if current != null and is_instance_valid(current):
		current._finished = true
		current.close_requested.emit()
	current = null

func _init() -> void:
	super._init("✊ Oẳn Tù Xì", "Búa thắng Kéo · Kéo thắng Bao · Bao thắng Búa", 560.0)
	_build()
	close_requested.connect(func() -> void:
		if not _finished:
			_finished = true
			NetClient.send_rps({"op": "leave"})
		if current == self:
			current = null)

func _ready() -> void:
	if not NetClient.disconnected.is_connected(_on_disconnected):
		NetClient.disconnected.connect(_on_disconnected)
	super._ready()   ## DraggableWindow: đặt khung giữa màn hình

func _on_disconnected(_code: String, _msg: String) -> void:
	_finished = true
	close_requested.emit()

func _build() -> void:
	## Bảng tỉ số
	var board := GameUi.panel(GameUi.PANEL)
	body.add_child(board)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	board.add_child(brow)
	var col_me := _score_col(GameUi.LABEL_GREEN)
	_name_me = col_me[1]
	_score_me = col_me[2]
	brow.add_child(col_me[0])
	_mid = GameUi.label("VS", GameUi.TITLE, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_mid.custom_minimum_size.x = 120
	_mid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brow.add_child(_mid)
	var col_opp := _score_col(GameUi.LABEL_RED)
	_name_opp = col_opp[1]
	_score_opp = col_opp[2]
	brow.add_child(col_opp[0])

	_status = GameUi.label("", GameUi.TEXT, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 44
	body.add_child(_status)

	## 3 icon lớn để chọn
	_pick_row = HBoxContainer.new()
	_pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pick_row.add_theme_constant_override("separation", 14)
	body.add_child(_pick_row)
	for i in 3:
		var b := _pick_button(i)
		_pick_btns.append(b)
		_pick_row.add_child(b)

	## Lật bài: lựa chọn của mình | số đếm / kết quả | lựa chọn đối thủ
	_reveal_row = HBoxContainer.new()
	_reveal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal_row.add_theme_constant_override("separation", 10)
	body.add_child(_reveal_row)
	var rm := _reveal_card()
	_reveal_me = rm[1]
	_reveal_me_lbl = rm[2]
	_reveal_row.add_child(rm[0])
	_big = GameUi.label("", GameUi.GOLD, 44, HORIZONTAL_ALIGNMENT_CENTER)
	_big.custom_minimum_size = Vector2(150, REVEAL_SIZE)
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.add_theme_color_override("font_outline_color", Color.BLACK)
	_big.add_theme_constant_override("outline_size", 6)
	_reveal_row.add_child(_big)
	var ro := _reveal_card()
	_reveal_opp = ro[1]
	_reveal_opp_lbl = ro[2]
	_reveal_opp_q = ro[3]
	_reveal_row.add_child(ro[0])

	var row := add_button_row()
	_confirm = SocialUi.stone_button("Xác nhận")
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)
	_next = SocialUi.stone_button("Chơi tiếp")
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(func() -> void:
		_next.disabled = true
		NetClient.send_rps({"op": "next"}))
	row.add_child(_next)
	_leave = SocialUi.small_button("Rời cuộc chơi")
	_leave.custom_minimum_size = Vector2(130, 40)
	_leave.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(_leave)

	## Lịch sử ván gần nhất
	var hist_title := GameUi.label("Các ván gần đây", GameUi.SUBTITLE, 13)
	body.add_child(hist_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 74
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_history = VBoxContainer.new()
	_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history.add_theme_constant_override("separation", 1)
	scroll.add_child(_history)

## [VBox, nhãn tên, nhãn số thắng]
func _score_col(color: Color) -> Array:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	var n := GameUi.label("", color, 16, HORIZONTAL_ALIGNMENT_CENTER)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(n)
	var s := GameUi.label("0", GameUi.GOLD, 34, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(s)
	v.add_child(GameUi.label("ván thắng", GameUi.MUTED, 12, HORIZONTAL_ALIGNMENT_CENTER))
	return [v, n, s]

func _pick_button(choice: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(ICON_SIZE + 16, ICON_SIZE + 40)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_pick(b, false)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 6
	v.offset_bottom = -4
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var t := TextureRect.new()
	t.texture = _icon(choice)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var l := GameUi.label(choice_name(choice), GameUi.TITLE, 16, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.pressed.connect(func() -> void: _select(choice))
	return b

func _style_pick(b: Button, active: bool) -> void:
	var normal := GameUi.box(GameUi.ACTIVE_BG if active else GameUi.BG_INNER, GameUi.BORDER_ACTIVE if active else GameUi.BORDER, 10, 3 if active else 1, 4)
	var hover := GameUi.box(GameUi.ACTIVE_BG if active else GameUi.BUTTON_BG_HOVER, GameUi.BORDER_ACTIVE, 10, 3 if active else 2, 4)
	for st in ["normal", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("disabled", normal)

## [VBox, TextureRect, nhãn tên lựa chọn, dấu ? (ẩn)]
func _reveal_card() -> Array:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", GameUi.box(GameUi.BG_INNER, GameUi.BORDER, 10, 1, 4))
	v.add_child(p)
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(REVEAL_SIZE, REVEAL_SIZE)
	p.add_child(t)
	var q := GameUi.label("?", GameUi.GOLD, 72, HORIZONTAL_ALIGNMENT_CENTER)
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.visible = false
	p.add_child(q)
	var l := GameUi.label("", GameUi.TEXT, 15, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(l)
	return [v, t, l, q]

func _select(choice: int) -> void:
	if str(_st.get("phase", "")) != "pick" or bool((_st.get("me", {}) as Dictionary).get("picked", false)):
		return
	_sel = choice
	_refresh_picks(false)
	_confirm.disabled = false

func _on_confirm() -> void:
	if _sel < 0:
		return
	_confirm.disabled = true
	NetClient.send_rps({"op": "pick", "choice": _sel})

func _refresh_picks(locked: bool) -> void:
	for i in _pick_btns.size():
		var b := _pick_btns[i]
		b.set_pressed_no_signal(i == _sel)
		_style_pick(b, i == _sel)
		b.disabled = locked
		b.modulate = Color(1, 1, 1, 0.45) if locked and i != _sel else Color.WHITE

## Áp trạng thái server (RpsServer.state_for).
func apply(st: Dictionary) -> void:
	_st = st
	var me: Dictionary = st.get("me", {})
	var opp: Dictionary = st.get("opp", {})
	var phase := str(st.get("phase", "pick"))
	var rnd := int(st.get("round", 1))
	if rnd != _round:
		_round = rnd
		_sel = -1
	var me_name := str(me.get("name", ""))
	var opp_name := str(opp.get("name", ""))
	_name_me.text = "%s (bạn)" % me_name
	_name_opp.text = opp_name
	_score_me.text = str(int(me.get("wins", 0)))
	_score_opp.text = str(int(opp.get("wins", 0)))
	_mid.text = "Ván %d\nVS\nHoà: %d" % [rnd, int(st.get("draws", 0))]
	_pick_row.visible = phase == "pick"
	_reveal_row.visible = phase != "pick"
	_confirm.visible = phase == "pick"
	_next.visible = phase == "result"
	_big.add_theme_color_override("font_color", GameUi.GOLD)
	match phase:
		"pick":
			var picked := bool(me.get("picked", false))
			if picked:
				_sel = int(me.get("choice", _sel))
			_refresh_picks(picked)
			_confirm.disabled = picked or _sel < 0
			_confirm.text = "Đã xác nhận" if picked else "Xác nhận"
			var opp_txt := ("%s đã xác nhận!" if bool(opp.get("picked", false)) else "%s đang chọn...") % opp_name
			if picked:
				_status.text = "Bạn đã chọn %s — chờ %s xác nhận.\n%s" % [choice_name(_sel), opp_name, opp_txt]
			else:
				_status.text = "Chọn Búa, Kéo hoặc Bao rồi bấm Xác nhận.\n%s" % opp_txt
		"countdown":
			_show_reveal(int(me.get("choice", -1)), -1, me_name, opp_name)
			_deadline_ms = Time.get_ticks_msec() + int(float(st.get("countdown", 3.0)) * 1000.0)
			_status.text = "Cả hai đã xác nhận! Oẳn... tù... xì..."
			_tick_countdown()
		"result":
			_show_reveal(int(me.get("choice", -1)), int(opp.get("choice", -1)), me_name, opp_name)
			var res := str(st.get("result", "draw"))
			match res:
				"win":
					_big.text = "THẮNG!"
					_big.add_theme_color_override("font_color", GameUi.LABEL_GREEN)
				"lose":
					_big.text = "THUA"
					_big.add_theme_color_override("font_color", GameUi.LABEL_RED)
				_:
					_big.text = "HOÀ"
			var line := "Hoà! Cả hai cùng ra %s." % choice_name(int(me.get("choice", -1))) if res == "draw" \
				else "Người thắng: %s  ·  Người thua: %s" % [str(st.get("winner", "")), str(st.get("loser", ""))]
			var ready_me := bool(me.get("ready", false))
			var ready_opp := bool(opp.get("ready", false))
			_next.disabled = ready_me
			_next.text = "Chờ %s..." % opp_name if ready_me else "Chơi tiếp"
			var tail := ""
			if ready_opp and not ready_me:
				tail = "\n%s muốn chơi ván tiếp!" % opp_name
			elif ready_me:
				tail = "\nĐang chờ %s bấm Chơi tiếp..." % opp_name
			_status.text = line + tail
	_fill_history(st.get("history", []) as Array)
	reset_size()

func _show_reveal(mine: int, theirs: int, me_name: String, opp_name: String) -> void:
	_reveal_me.texture = _icon(mine)
	_reveal_me_lbl.text = "%s: %s" % [me_name, choice_name(mine)]
	_reveal_opp.texture = _icon(theirs)
	_reveal_opp_q.visible = theirs < 0
	_reveal_opp_lbl.text = "%s: %s" % [opp_name, choice_name(theirs)]

func _process(_delta: float) -> void:
	if str(_st.get("phase", "")) == "countdown":
		_tick_countdown()

func _tick_countdown() -> void:
	var left := maxi(0, _deadline_ms - Time.get_ticks_msec())
	_big.text = str(maxi(1, ceili(left / 1000.0)))

func _fill_history(hist: Array) -> void:
	for c in _history.get_children():
		c.queue_free()
	for i in range(hist.size() - 1, -1, -1):
		var h: Dictionary = hist[i]
		var r := int(h.get("r", 0))
		var who := "Hoà" if r == 0 else "%s thắng" % str(h.get("winner", ""))
		var color := GameUi.MUTED if r == 0 else (GameUi.LABEL_GREEN if r > 0 else GameUi.LABEL_RED)
		_history.add_child(GameUi.label("Ván %d:  %s vs %s  —  %s" % [int(h.get("round", 0)), choice_name(int(h.get("me", -1))),
			choice_name(int(h.get("op", -1))), who], color, 13))
