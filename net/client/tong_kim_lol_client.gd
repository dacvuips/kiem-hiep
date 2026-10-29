extends CanvasLayer
class_name TongKimLolClient

const VsScoreBar := preload("res://ui/common/vs_score_bar.gd")
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
var _song_hp_bar: ProgressBar = null
var _song_hp_label: Label = null
var _jin_hp_bar: ProgressBar = null
var _jin_hp_label: Label = null
var _timer_label: Label = null
var _score_label: Label = null
var _vs_bar: VsScoreBar

# Kill feed & Marquee
var _kill_feed_container: VBoxContainer
var _marquee_banner: PanelContainer
var _marquee_label: Label
var _marquee_tween: Tween

# Bottom/Side bar (Quân Nhu, Rời Ải, Vàng, EXP)
var _level_label: Label = null
var _exp_bar: ProgressBar = null
var _gold_label: Label = null
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
	bind_state(state)

func _process(delta: float) -> void:
	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
		var mins := int(time_left) / 60
		var secs := int(time_left) % 60
		var time_str := "%02d:%02d" % [mins, secs]
		if _timer_label:
			_timer_label.text = time_str
		if _vs_bar:
			_vs_bar.set_timer(time_str)

# ---------------------------------------------------------------- Top Toolbar
func _build_top_toolbar() -> void:
	# Banner Tướng Tống vs Tướng Kim hiển thị trực tiếp ở giữa trên đỉnh màn hình
	# Không dùng nền đen che bản đồ, số hiển thị trong banner chính là % máu 2 Tướng
	_vs_bar = VsScoreBar.new()
	_vs_bar.set_sides("Tướng Tống", "100%", "100%", "Tướng Kim")
	_vs_bar.set_timer("40:00")
	add_child(_vs_bar)

# ---------------------------------------------------------------- Action Buttons (Quân Nhu, Rời Ải & Vàng)
func _build_action_buttons() -> void:
	# Vị trí: Đặt ngay trên 4 ô dùng thuốc (QuickItemBar nằm ở BOTTOM=384, cao 56 -> đỉnh 440)
	# Mép dưới nút đặt cách hàng thuốc 8px, bề rộng vừa đúng 254px của cụm 4 ô thuốc
	var right_margin := QuickItemBar.RIGHT
	var bottom_margin := QuickItemBar.TOP_OFFSET + 8.0
	var btn_height := 32.0
	var btn_width := 123.0
	var total_width := btn_width * 2 + 8

	# 1. Khung hiển thị Vàng và EXP đặt ngay phía trên cụm nút Quân Nhu & Rời Ải
	var gold_container := PanelContainer.new()
	gold_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	gold_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gold_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	gold_container.offset_right = -right_margin
	gold_container.offset_bottom = -bottom_margin - btn_height - 6.0
	gold_container.offset_top = -bottom_margin - btn_height - 36.0
	gold_container.offset_left = -right_margin - total_width
	gold_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb_gold := StyleBoxFlat.new()
	sb_gold.bg_color = Color(0.06, 0.08, 0.12, 0.65)
	sb_gold.border_color = Color(0.75, 0.65, 0.25, 0.6)
	sb_gold.set_border_width_all(1)
	sb_gold.set_corner_radius_all(4)
	sb_gold.content_margin_left = 8
	sb_gold.content_margin_right = 8
	sb_gold.content_margin_top = 2
	sb_gold.content_margin_bottom = 2
	gold_container.add_theme_stylebox_override("panel", sb_gold)

	var gold_vbox := VBoxContainer.new()
	gold_vbox.add_theme_constant_override("separation", 2)
	gold_container.add_child(gold_vbox)

	_gold_label = Label.new()
	_gold_label.text = "🪙 100 Vàng"
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	_gold_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_gold_label.add_theme_constant_override("outline_size", 2)
	_gold_label.add_theme_font_size_override("font_size", 13)
	gold_vbox.add_child(_gold_label)

	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(0, 3)
	_exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp_bar.show_percentage = false
	var sb_exp := StyleBoxFlat.new()
	sb_exp.bg_color = Color(0.2, 0.8, 0.4)
	sb_exp.set_corner_radius_all(2)
	_exp_bar.add_theme_stylebox_override("fill", sb_exp)
	gold_vbox.add_child(_exp_bar)

	add_child(gold_container)

	# 2. Cụm nút Quân Nhu & Rời Ải
	var container := HBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	container.add_theme_constant_override("separation", 8)

	container.offset_right = -right_margin
	container.offset_bottom = -bottom_margin
	container.offset_top = -bottom_margin - btn_height
	container.offset_left = -right_margin - total_width

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
	if _vs_bar:
		_vs_bar.set_scores("%d%%" % int(roundf(song_general_hp * 100.0)), "%d%%" % int(roundf(jin_general_hp * 100.0)))

func update_scores(s_k: int, s_d: int, j_k: int, j_d: int) -> void:
	song_kills = s_k
	song_deaths = s_d
	jin_kills = j_k
	jin_deaths = j_d
	if _score_label:
		_score_label.text = "%d / %d   - VS -   %d / %d" % [song_kills, song_deaths, jin_kills, jin_deaths]

func _on_level_changed(lvl: int) -> void:
	if _level_label:
		_level_label.text = "Cấp %d" % lvl

func _on_exp_changed(cur: float, max_exp: float) -> void:
	if _exp_bar:
		_exp_bar.max_value = max_exp
		_exp_bar.value = cur

func bind_state(s: TongKimLolState) -> void:
	if s == null:
		return
	if not s.level_changed.is_connected(_on_level_changed):
		s.level_changed.connect(_on_level_changed)
	if not s.exp_changed.is_connected(_on_exp_changed):
		s.exp_changed.connect(_on_exp_changed)
	if not s.gold_changed.is_connected(_on_gold_changed):
		s.gold_changed.connect(_on_gold_changed)
	_on_level_changed(s.match_level)
	_on_exp_changed(s.current_match_exp, s.exp_to_next)
	_on_gold_changed(s.match_gold)

func _on_gold_changed(gold: int) -> void:
	if _gold_label:
		_gold_label.text = "🪙 %d Vàng" % gold
