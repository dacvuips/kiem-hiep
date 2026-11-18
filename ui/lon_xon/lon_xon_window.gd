extends SocialWindow
class_name LonXonWindow
## Modal "Lộn Xộn" — hỗn chiến tự do (mỗi người 1 phe, không tổ đội) trên khung Tống Kim 1 như PUBG nhưng KHÔNG có vòng bo,
## không giới hạn thời gian: chết -> 5 giây hồi sinh trong khung, bị hạ thì rớt hết đồ (trang bị + túi) ra đất.
## Server dựng sẵn LonXonServer.HOST_COUNT host; người chơi chọn 1 host rồi bấm Bắt Đầu.
## Kế hoạch đầy đủ: docs/plans/lon-xon.md. Phần server chưa làm -> nút Bắt Đầu chỉ báo "đang xây dựng".

const HOST_COUNT := 5
const HOST_CAPACITY := 50
const WIN_W := 900.0

var _profile: PlayerProfile
var _on_play: Callable
var _tab := 0
var _tab_buttons: Array[Button] = []
var _content_box: VBoxContainer
var _selected_host := 1
var _host_buttons: Array[Button] = []
## Số người từng host — sẽ lấy từ server (S_LONXON op "hosts"); tạm 0 khi chưa có server.
var _host_players: Array[int] = []

static func open(host: Node, profile: PlayerProfile, on_play: Callable = Callable()) -> SocialWindow:
	var script: GDScript = load("res://ui/lon_xon/lon_xon_window.gd")
	var win: SocialWindow = script.new(profile, on_play)
	return SocialWindow.present(host, win, &"lon_xon")

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init("🌀 LỘN XỘN — HỖN CHIẾN VÕ LÂM", "", WIN_W)
	_profile = profile
	_on_play = on_play
	is_full_width = false
	custom_minimum_size = Vector2(WIN_W, 600.0)
	for i in HOST_COUNT:
		_host_players.append(0)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(tabs)
	for t in [["⚔️ Vào Chơi", 0], ["📜 Luật Chơi", 1]]:
		var b := GameUi.button(str(t[0]), GameUi.TAB)
		b.custom_minimum_size = Vector2(210, 36)
		b.pressed.connect(_select_tab.bind(int(t[1])))
		tabs.add_child(b)
		_tab_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 480.0)
	body.add_child(scroll)
	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 12)
	scroll.add_child(_content_box)
	_select_tab(0)

func _select_tab(idx: int) -> void:
	_tab = idx
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = Color(1.2, 1.1, 0.6) if i == idx else Color(0.8, 0.8, 0.8)
	for c in _content_box.get_children():
		_content_box.remove_child(c)
		c.queue_free()
	if idx == 0:
		_render_play()
	else:
		_render_rules()

# ------------------------------------------------------------------ tab Vào Chơi
func _render_play() -> void:
	var intro := _label("Mỗi người 1 phe — không tổ đội. Chọn 1 host rồi bấm Bắt Đầu để vào chơi chung với mọi người trong host đó.", Color(0.75, 0.8, 0.8))
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_box.add_child(intro)

	_content_box.add_child(_label("🖥️ CHỌN HOST", Color(1.0, 0.85, 0.3)))
	var grid := GridContainer.new()
	grid.columns = HOST_COUNT
	grid.add_theme_constant_override("h_separation", 10)
	_content_box.add_child(grid)
	_host_buttons.clear()
	for i in HOST_COUNT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 70)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.pressed.connect(_pick_host.bind(i + 1))
		grid.add_child(b)
		_host_buttons.append(b)
	_refresh_hosts()

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_child(row)
	var start := Button.new()
	start.text = "⚔️ BẮT ĐẦU"
	start.custom_minimum_size = Vector2(320, 52)
	start.add_theme_font_size_override("font_size", 20)
	start.modulate = Color(0.4, 1.2, 0.55)
	start.pressed.connect(_on_start_pressed)
	row.add_child(start)

	var note := _label("Vào trận là hồ sơ tạm cấp 50 + chọn ngựa 5x và vũ khí 5x, hạ 1 quái +5 cấp (tối đa 200) — không ảnh hưởng nhân vật thật.", Color(0.65, 0.68, 0.68))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_box.add_child(note)

func _pick_host(n: int) -> void:
	_selected_host = n
	_refresh_hosts()

func _refresh_hosts() -> void:
	for i in _host_buttons.size():
		var b := _host_buttons[i]
		var cnt: int = _host_players[i] if i < _host_players.size() else 0
		b.text = "Host %d\n👤 %d/%d" % [i + 1, cnt, HOST_CAPACITY]
		b.button_pressed = (i + 1) == _selected_host
		b.modulate = Color(1.2, 1.1, 0.6) if (i + 1) == _selected_host else Color(0.85, 0.85, 0.85)
		b.disabled = cnt >= HOST_CAPACITY

func _on_start_pressed() -> void:
	## TODO(Lộn Xộn): gửi C_LONXON {op: join, host: _selected_host}; server trả "match" -> _on_play(LonXonManager.start_online(...)).
	SocialWindow.confirm(self, "Đang Xây Dựng", "🌀 Chế độ Lộn Xộn đang được xây dựng phía máy chủ.\nHost đã chọn: Host %d." % _selected_host, Callable())

# ------------------------------------------------------------------ tab Luật Chơi
func _render_rules() -> void:
	var sections := [
		["🗺️ 1. BẢN ĐỒ & KHUNG CHƠI", "• Diễn ra trên bản đồ Tống Kim 1, mỗi host có 1 khung chơi ngẫu nhiên 140 x 80 region như PUBG.\n• KHÔNG có vòng bo, KHÔNG giới hạn thời gian — host mở liên tục, vào ra lúc nào cũng được.\n• Không thể đi ra ngoài khung chơi."],
		["⚔️ 2. MỖI NGƯỜI 1 PHE", "• Không tổ đội: ai cũng là đối thủ của nhau.\n• Server có sẵn %d host, mỗi host tối đa %d người." % [HOST_COUNT, HOST_CAPACITY]],
		["🧙 3. NHÂN VẬT & LÊN CẤP", "• Vào trận là nhân vật cấp 50, được chọn thẻ như PUBG: 1 trong 5 ngựa 5x (Hoàng Phiêu, Tử Lưu, Ngọc Hoa Thông, Hắc Kỳ, Hồng Ly) và 1 trong 14 loại vũ khí 5x — đều dùng được ngay ở cấp 50.\n• Mỗi con quái hạ được: +5 cấp, tối đa cấp 200.\n• Kỹ năng tự mở theo cấp nhân vật, không cần học: cấp 5x chỉ có kỹ năng tới 5x, lên cấp 80 mở 9x, 120 mở 12x, 150 mở 15x, 180 mở 18x.\n• Kỹ năng thường mở ra là MAX; kỹ năng 9x, 12x, 15x, 18x mở ra ở cấp 1, nâng tiếp bằng Đại Thành Bí Kíp.\n• Hồ sơ trong trận là hồ sơ tạm, rời trận là trả lại nhân vật thật nguyên vẹn."],
		["💀 4. BỊ HẠ GỤC & HỒI SINH", "• Bị hạ gục: TOÀN BỘ trang bị đang mặc và hành trang rớt ra đất ngay tại chỗ, ai cũng nhặt được.\n• Sau 5 giây được hồi sinh tại 1 vị trí ngẫu nhiên trong khung chơi và được chọn lại ngựa 5x + vũ khí 5x."],
		["📦 5. QUÁI RƠI ĐỒ", "• Mỗi con quái rơi khoảng 4 món trang bị: 70% đồ xanh, 25% đồ Hoàng Kim, 5% đồ Hoàng Kim Môn Phái.\n• 50% rơi thêm 1 con ngựa (đủ loại).\n• Chắc chắn rơi 1 bình Hồi Thiên Tái Tạo Đơn."],
		["🏅 6. LỆNH BÀI & BẢNG XẾP HẠNG", "• Mỗi người khi chết rớt 1 Lệnh Bài, cộng thêm 1/2 số Lệnh Bài đang giữ, ra đất cho người khác nhặt.\n• Mỗi Lệnh Bài đang giữ: nhân vật to hơn 10%, bán kính đánh của skill +5%, tầm nhìn bản đồ rộng thêm 10%.\n• Mỗi Lệnh Bài = 1000 điểm. Top 5 điểm cao nhất hiện ở góc trên bên trái màn hình.\n• Top 1, 2, 3 có số thứ hạng hiện trên đầu nhân vật."],
		["📕 7. ĐẠI THÀNH BÍ KÍP", "• Quái có thể rơi Đại Thành Bí Kíp 9x / 12x / 15x / 18x — mỗi lần rơi 1 loại, 5 cuốn.\n• Mỗi cuốn tăng thêm 1 cấp cho 1 kỹ năng đã mở đúng tầng đó (5 cuốn = 5 cấp)."],
	]
	for s in sections:
		var panel := PanelContainer.new()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		panel.add_child(v)
		v.add_child(_label(str(s[0]), Color(1.0, 0.85, 0.2)))
		v.add_child(_label(str(s[1]), Color(0.9, 0.9, 0.88)))
		_content_box.add_child(panel)

func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	return l
