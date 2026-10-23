extends CanvasLayer
class_name TongKimLolClient
## Giao diện HUD 2 phe của Ải Tống Kim LOL (Chiến trường MOBA)
## Hiển thị Toolbar máu 2 Tướng Soái, Đồng hồ 40p, Tỉ số K/D, Bảng Kill Feed, Dải chữ chạy thông báo Boss và Nút Quân Nhu

signal leave_requested

var my_side: String = "song" ## "song" hoặc "jin"
var time_left: float = TongKimLolRules.MATCH_DURATION_SEC

# Trạng thái hiển thị
var song_general_hp: float = 1.0
var jin_general_hp: float = 1.0
var song_kills: int = 0
var song_deaths: int = 0
var jin_kills: int = 0
var jin_deaths: int = 0

# UI Controls
var _song_hp_bar: ProgressBar
var _song_hp_label: Label
var _jin_hp_bar: ProgressBar
var _jin_hp_label: Label
var _timer_label: Label
var _score_label: Label

# Kill feed & Marquee
var _kill_feed_container: VBoxContainer
var _marquee_banner: PanelContainer
var _marquee_label: Label
var _marquee_tween: Tween

# Bottom/Side bar
var _level_label: Label
var _exp_bar: ProgressBar
var _gold_label: Label
var _shop_button: Button
var _leave_button: Button

func _ready() -> void:
	layer = 15
	_build_top_toolbar()
	_build_action_buttons()
	_build_kill_feed()
	_build_marquee_banner()
	_build_bottom_status()

	var state := TongKimLolState.instance()
	state.level_changed.connect(_on_level_changed)
	state.exp_changed.connect(_on_exp_changed)
	state.gold_changed.connect(_on_gold_changed)
	_on_level_changed(state.match_level)
	_on_exp_changed(state.current_match_exp, state.exp_to_next)
	_on_gold_changed(state.match_gold)

func _process(delta: float) -> void:
	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
		var mins := int(time_left) / 60
		var secs := int(time_left) % 60
		_timer_label.text = "%02d:%02d" % [mins, secs]

# ---------------------------------------------------------------- Top Toolbar
func _build_top_toolbar() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-330, 52)
	panel.custom_minimum_size = Vector2(660, 52)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.45) # Mờ nền hơn nhiều để nhìn rõ bối cảnh bản đồ
	sb.border_color = Color(0.35, 0.40, 0.50, 0.35) # Viền mờ nhẹ nhàng
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	panel.add_child(main_vbox)

	# --- HÀNG 1: TƯỚNG TỐNG - THỜI GIAN/TỶ SỐ - TƯỚNG KIM ---
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(row1)

	# 1. Phe Tống (Bên Trái)
	var song_box := VBoxContainer.new()
	song_box.custom_minimum_size.x = 210
	song_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_child(song_box)

	var song_header := HBoxContainer.new()
	var song_tag := Label.new()
	song_tag.text = "TƯỚNG TỐNG"
	song_tag.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	song_tag.add_theme_font_size_override("font_size", 12)
	song_header.add_child(song_tag)

	_song_hp_label = Label.new()
	_song_hp_label.text = "100%"
	_song_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_song_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_song_hp_label.add_theme_font_size_override("font_size", 12)
	song_header.add_child(_song_hp_label)
	song_box.add_child(song_header)

	_song_hp_bar = ProgressBar.new()
	_song_hp_bar.custom_minimum_size.y = 8
	_song_hp_bar.max_value = 1.0
	_song_hp_bar.value = 1.0
	_song_hp_bar.show_percentage = false
	var sb_song := StyleBoxFlat.new()
	sb_song.bg_color = Color(0.15, 0.55, 0.95)
	sb_song.set_corner_radius_all(3)
	_song_hp_bar.add_theme_stylebox_override("fill", sb_song)
	song_box.add_child(_song_hp_bar)

	# 2. Khu Vực Giữa: Thời Gian & Tỷ Số
	var center_box := VBoxContainer.new()
	center_box.custom_minimum_size.x = 170
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_child(center_box)

	_timer_label = Label.new()
	_timer_label.text = "40:00"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 16)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_label.add_theme_constant_override("outline_size", 3)
	center_box.add_child(_timer_label)

	_score_label = Label.new()
	_score_label.text = "0  -  VS  -  0"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 11)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	center_box.add_child(_score_label)

	# 3. Phe Kim (Bên Phải)
	var jin_box := VBoxContainer.new()
	jin_box.custom_minimum_size.x = 210
	jin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_child(jin_box)

	var jin_header := HBoxContainer.new()
	_jin_hp_label = Label.new()
	_jin_hp_label.text = "100%"
	_jin_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jin_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_jin_hp_label.add_theme_font_size_override("font_size", 12)
	jin_header.add_child(_jin_hp_label)

	var jin_tag := Label.new()
	jin_tag.text = "TƯỚNG KIM"
	jin_tag.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2))
	jin_tag.add_theme_font_size_override("font_size", 12)
	jin_header.add_child(jin_tag)
	jin_box.add_child(jin_header)

	_jin_hp_bar = ProgressBar.new()
	_jin_hp_bar.custom_minimum_size.y = 8
	_jin_hp_bar.max_value = 1.0
	_jin_hp_bar.value = 1.0
	_jin_hp_bar.show_percentage = false
	var sb_jin := StyleBoxFlat.new()
	sb_jin.bg_color = Color(0.95, 0.35, 0.2)
	sb_jin.set_corner_radius_all(3)
	_jin_hp_bar.add_theme_stylebox_override("fill", sb_jin)
	jin_box.add_child(_jin_hp_bar)

	# --- HÀNG 2: TIẾN TRÌNH NHÂN VẬT & VÀNG (Gọn gàng & cân đối) ---
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(row2)

	_level_label = Label.new()
	_level_label.text = "Cấp 1"
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_level_label.add_theme_font_size_override("font_size", 12)
	row2.add_child(_level_label)

	_exp_bar = ProgressBar.new()
	_exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp_bar.custom_minimum_size = Vector2(280, 8)
	_exp_bar.show_percentage = false
	var sb_exp := StyleBoxFlat.new()
	sb_exp.bg_color = Color(0.2, 0.8, 0.4)
	sb_exp.set_corner_radius_all(3)
	_exp_bar.add_theme_stylebox_override("fill", sb_exp)
	row2.add_child(_exp_bar)

	_gold_label = Label.new()
	_gold_label.text = "🪙 100 Vàng"
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_gold_label.add_theme_font_size_override("font_size", 12)
	row2.add_child(_gold_label)

# ---------------------------------------------------------------- Action Buttons (Quân Nhu & Rời Ải)
func _build_action_buttons() -> void:
	var container := HBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	container.add_theme_constant_override("separation", 8)

	# Vị trí: Đặt ngay trên 4 ô dùng thuốc (QuickItemBar nằm ở BOTTOM=306, cao 56 -> đỉnh 362)
	# Mép dưới nút đặt ở -370, cách hàng thuốc 8px, bề rộng vừa đúng 254px của cụm 4 ô thuốc
	var right_margin := 14.0
	var bottom_margin := 370.0
	var btn_height := 32.0
	var btn_width := 123.0

	container.offset_right = -right_margin
	container.offset_bottom = -bottom_margin
	container.offset_top = -bottom_margin - btn_height
	container.offset_left = -right_margin - (btn_width * 2 + 8)

	_shop_button = GameUi.button("Quân Nhu", GameUi.PRIMARY)
	_shop_button.custom_minimum_size = Vector2(btn_width, btn_height)
	_shop_button.add_theme_font_size_override("font_size", 13)
	_shop_button.pressed.connect(func() -> void: TongKimLolShopWindow.open(self))
	container.add_child(_shop_button)

	_leave_button = GameUi.button("Rời Ải")
	_leave_button.custom_minimum_size = Vector2(btn_width, btn_height)
	_leave_button.add_theme_font_size_override("font_size", 13)
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	container.add_child(_leave_button)

	add_child(container)

# ---------------------------------------------------------------- Marquee Banner
func _build_marquee_banner() -> void:
	_marquee_banner = PanelContainer.new()
	_marquee_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_marquee_banner.position = Vector2(0, 126)
	_marquee_banner.custom_minimum_size.y = 28
	_marquee_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee_banner.visible = false
	add_child(_marquee_banner)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.6, 0.45, 0.05, 0.85)
	sb.border_color = Color(1.0, 0.85, 0.3)
	sb.set_border_width_all(1)
	_marquee_banner.add_theme_stylebox_override("panel", sb)

	_marquee_label = Label.new()
	_marquee_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marquee_label.add_theme_font_size_override("font_size", 14)
	_marquee_label.add_theme_color_override("font_color", Color.WHITE)
	_marquee_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_marquee_label.add_theme_constant_override("outline_size", 3)
	_marquee_banner.add_child(_marquee_label)

func show_marquee_announcement(msg: String) -> void:
	_marquee_label.text = msg
	_marquee_banner.visible = true
	_marquee_banner.modulate.a = 0.0
	if _marquee_tween and _marquee_tween.is_valid():
		_marquee_tween.kill()
	_marquee_tween = create_tween()
	_marquee_tween.tween_property(_marquee_banner, "modulate:a", 1.0, 0.4)
	_marquee_tween.tween_interval(5.0)
	_marquee_tween.tween_property(_marquee_banner, "modulate:a", 0.0, 0.8)
	_marquee_tween.tween_callback(func() -> void: _marquee_banner.visible = false)

# ---------------------------------------------------------------- Kill Feed Box
func _build_kill_feed() -> void:
	_kill_feed_container = VBoxContainer.new()
	_kill_feed_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_kill_feed_container.position = Vector2(-310, 126)
	_kill_feed_container.custom_minimum_size = Vector2(300, 150)
	_kill_feed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_feed_container.add_theme_constant_override("separation", 4)
	add_child(_kill_feed_container)

func add_kill_feed(killer_name: String, killer_side: String, victim_name: String, victim_side: String) -> void:
	var item := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	sb.set_corner_radius_all(4)
	item.add_theme_stylebox_override("panel", sb)

	var lbl := RichTextLabel.new()
	lbl.fit_content = true
	lbl.bbcode_enabled = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var k_col := "#3399ff" if killer_side == "song" else "#ff5533"
	var v_col := "#3399ff" if victim_side == "song" else "#ff5533"
	lbl.text = "[color=%s]%s[/color] [color=#e0e0e0]đã tiêu diệt[/color] [color=%s]%s[/color]!" % [k_col, killer_name, v_col, victim_name]
	item.add_child(lbl)

	_kill_feed_container.add_child(item)
	var t := create_tween()
	t.tween_interval(4.0)
	t.tween_property(item, "modulate:a", 0.0, 0.6)
	t.tween_callback(item.queue_free)

# ---------------------------------------------------------------- Bottom Controls
func _build_bottom_status() -> void:
	# Đã gộp thanh trạng thái nhân vật vào hàng 2 của Top Toolbar để không che thanh chat ở đáy màn hình
	pass

# ---------------------------------------------------------------- Cập nhật trạng thái
func update_generals(song_pct: float, jin_pct: float) -> void:
	song_general_hp = clampf(song_pct, 0.0, 1.0)
	jin_general_hp = clampf(jin_pct, 0.0, 1.0)
	_song_hp_bar.value = song_general_hp
	_song_hp_label.text = "%d%%" % int(song_general_hp * 100)
	_jin_hp_bar.value = jin_general_hp
	_jin_hp_label.text = "%d%%" % int(jin_general_hp * 100)

func update_scores(s_k: int, s_d: int, j_k: int, j_d: int) -> void:
	song_kills = s_k
	song_deaths = s_d
	jin_kills = j_k
	jin_deaths = j_d
	_score_label.text = "%d / %d   - VS -   %d / %d" % [song_kills, song_deaths, jin_kills, jin_deaths]

func _on_level_changed(lvl: int) -> void:
	_level_label.text = "Cấp %d" % lvl

func _on_exp_changed(cur: float, max_exp: float) -> void:
	_exp_bar.max_value = max_exp
	_exp_bar.value = cur

func _on_gold_changed(gold: int) -> void:
	_gold_label.text = "🪙 %d Vàng" % gold
