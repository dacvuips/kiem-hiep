extends Control
class_name FarmHud
## HUD chuyên dụng cho Sơn Trang Nông Trại:
## - Ẩn cụm phím kỹ năng chiến đấu (SkillBarUI) khi ở trên đảo.
## - Đặt cụm nút công cụ & tiệm sang góc dưới bên phải màn hình (thay thế vị trí skill pad).
## - Giữ góc dưới bên trái thoáng đãng, không bị đè lên ô Chat và thanh thuốc/ngựa.

const FarmWindowsScript = preload("res://ui/son_trang/farm_windows.gd")

signal tool_selected(tool_id: String)

var current_tool: String = "hoe"
var _tool_buttons: Dictionary = {}

var weather_vfx: WeatherVFX = null
var _weather_badge: PanelContainer = null
var _weather_name_lbl: Label = null
var _weather_temp_lbl: Label = null
var _weather_buff_lbl: Label = null
var _season_time_lbl: Label = null
var _level_lbl: Label = null
var _last_displayed_weather: int = -1
var _last_displayed_phase: int = -1
var _weather_check_timer: float = 0.0

## Lớp hiệu ứng trực quan thời tiết (Mưa, Tuyết, Bão, Sương mù, Gió & Lá Thu Bay) phủ màn hình
class WeatherVFX extends Control:
	var particles: Array[Dictionary] = []
	var wind_gust_instances: Array[Dictionary] = []
	var max_particles: int = 75
	var current_weather: int = FarmTimeSystem.Weather.SUNNY
	var flash_alpha: float = 0.0
	var flash_timer: float = 0.0

	var leaf_textures: Array[Texture2D] = []

	var fog_cloud_textures: Array[Texture2D] = []
	var fog_layer_textures: Array[Texture2D] = []
	var fog_wisp_textures: Array[Texture2D] = []
	var fog_layer_scroll: Array[float] = [0.0, 0.0, 0.0]
	var fog_anim_time: float = 0.0

	func _init() -> void:
		_load_autumn_assets()
		_load_fog_assets()
		_reset_particles()

	func _ready() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE

	static func _load_tex_safe(res_path: String) -> Texture2D:
		if ResourceLoader.exists(res_path):
			var res = load(res_path)
			if res is Texture2D:
				return res
		var global_p := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(global_p):
			var img := Image.load_from_file(global_p)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
		return null

	func _load_fog_assets() -> void:
		fog_cloud_textures.clear()
		fog_layer_textures.clear()
		fog_wisp_textures.clear()

		# Nạp các đám mây sương cụm
		var cloud_files = [
			"fog_cloud_large_1.png", "fog_cloud_large_2.png", "fog_cloud_large_3.png",
			"fog_cloud_medium_1.png", "fog_cloud_medium_2.png", "fog_cloud_medium_3.png", "fog_cloud_medium_4.png",
			"fog_puff_small_1.png", "fog_puff_small_2.png", "fog_puff_small_3.png", "fog_puff_small_4.png"
		]
		for cf in cloud_files:
			var p: String = "res://assets/weather/fog/clouds/" + str(cf)
			var tex: Texture2D = _load_tex_safe(p)
			if tex:
				fog_cloud_textures.append(tex)

		# Nạp các dải sương ngang trải dài
		var layer_files = ["fog_layer_ground.png", "fog_layer_mid.png", "fog_layer_high.png"]
		for lf in layer_files:
			var p: String = "res://assets/weather/fog/layers/" + str(lf)
			var tex: Texture2D = _load_tex_safe(p)
			if tex:
				fog_layer_textures.append(tex)

		# Nạp các vệt sương mảnh uốn lượn
		var wisp_files = ["fog_wispy_stream_1.png", "fog_wispy_stream_2.png", "fog_wispy_stream_3.png"]
		for wf in wisp_files:
			var p: String = "res://assets/weather/fog/wisps/" + str(wf)
			var tex: Texture2D = _load_tex_safe(p)
			if tex:
				fog_wisp_textures.append(tex)

	func _load_autumn_assets() -> void:
		leaf_textures.clear()

		# Nạp các sprite chiếc lá mùa thu đặc sắc đã được cắt
		var leaf_names = [
			"autumn_leaf_maple_1.png", "autumn_leaf_maple_16.png", "autumn_leaf_maple_18.png",
			"autumn_leaf_maple_20.png", "autumn_leaf_maple_25.png", "autumn_leaf_maple_30.png",
			"autumn_leaf_red_9.png", "autumn_leaf_red_22.png", "autumn_leaf_yellow_2.png",
			"autumn_leaf_yellow_4.png", "autumn_leaf_yellow_10.png", "autumn_leaf_yellow_34.png"
		]
		for fn in leaf_names:
			var path: String = "res://assets/weather/autumn/leaves/" + str(fn)
			var tex: Texture2D = _load_tex_safe(path)
			if tex:
				leaf_textures.append(tex)

	func _reset_particles() -> void:
		particles.clear()
		var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
		if vp.x <= 0 or vp.y <= 0:
			vp = Vector2(1280, 720)

		# Mật độ hạt tùy chỉnh theo từng kiểu thời tiết (Lá mùa thu thưa thớt nhẹ nhàng, không rối mắt)
		var is_autumn: bool = (FarmTimeSystem.get_current_season() == FarmTimeSystem.Season.AUTUMN)
		var is_windy: bool = (current_weather == FarmTimeSystem.Weather.WINDY)
		
		var particle_count := 18
		match current_weather:
			FarmTimeSystem.Weather.RAINY:
				particle_count = 55
			FarmTimeSystem.Weather.STORM:
				particle_count = 75
			FarmTimeSystem.Weather.SNOWY:
				particle_count = 30
			FarmTimeSystem.Weather.FOGGY:
				particle_count = 14 # 14 đám mây sương bồng bềnh tự nhiên
			FarmTimeSystem.Weather.WINDY:
				particle_count = 18
			_:
				particle_count = 18 if is_autumn else 0

		for _i in range(particle_count):
			if current_weather == FarmTimeSystem.Weather.FOGGY:
				var fog_tex: Texture2D = null
				if not fog_cloud_textures.is_empty():
					fog_tex = fog_cloud_textures.pick_random()
				particles.append({
					"pos": Vector2(randf_range(-150, vp.x), randf_range(-40, vp.y - 80)),
					"speed": randf_range(14.0, 26.0),
					"size": randf_range(30.0, 70.0),
					"angle": randf_range(0, TAU),
					"scale": randf_range(0.85, 1.35),
					"alpha": randf_range(0.32, 0.58),
					"pulse_speed": randf_range(0.4, 0.8),
					"pulse_offset": randf_range(0, TAU),
					"tex": fog_tex
				})
			else:
				var tex: Texture2D = leaf_textures.pick_random() if not leaf_textures.is_empty() else null
				particles.append({
					"pos": Vector2(randf_range(-100, vp.x), randf_range(0, vp.y)),
					"speed": randf_range(0.7, 1.2),
					"size": randf_range(2.0, 4.0),
					"angle": randf_range(0, TAU),
					"rot": randf_range(0, TAU),
					"rot_speed": randf_range(-1.8, 1.8),
					"scale": randf_range(0.30, 0.52),
					"alpha": randf_range(0.60, 0.90),
					"tex": tex
				})

	func update_weather(w: int) -> void:
		current_weather = w
		_reset_particles()
		queue_redraw()

	func _process(delta: float) -> void:
		var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
		if vp.x <= 0 or vp.y <= 0:
			vp = Vector2(1280, 720)

		match current_weather:
			FarmTimeSystem.Weather.RAINY:
				for p in particles:
					p["pos"].x -= 70.0 * p["speed"] * delta
					p["pos"].y += 520.0 * p["speed"] * delta
					if p["pos"].y > vp.y:
						p["pos"].y = -10.0
						p["pos"].x = randf_range(0, vp.x + 100.0)
			FarmTimeSystem.Weather.STORM:
				flash_timer -= delta
				if flash_timer <= 0.0:
					flash_timer = randf_range(4.0, 10.0)
					flash_alpha = 0.35
				if flash_alpha > 0.0:
					flash_alpha = maxf(0.0, flash_alpha - delta * 2.0)

				for p in particles:
					p["pos"].x -= 160.0 * p["speed"] * delta
					p["pos"].y += 720.0 * p["speed"] * delta
					if p["pos"].y > vp.y:
						p["pos"].y = -10.0
						p["pos"].x = randf_range(0, vp.x + 200.0)
			FarmTimeSystem.Weather.SNOWY:
				for p in particles:
					p["angle"] += delta * 1.5
					p["pos"].x += sin(p["angle"]) * 25.0 * delta
					p["pos"].y += 65.0 * p["speed"] * delta
					if p["pos"].y > vp.y:
						p["pos"].y = -10.0
						p["pos"].x = randf_range(0, vp.x)
			FarmTimeSystem.Weather.FOGGY:
				fog_anim_time += delta
				# Cuộn các dải sương ngang với vận tốc khác nhau (Parallax scrolling)
				fog_layer_scroll[0] = fmod(fog_layer_scroll[0] + 12.0 * delta, 1024.0)
				fog_layer_scroll[1] = fmod(fog_layer_scroll[1] + 18.0 * delta, 1024.0)
				fog_layer_scroll[2] = fmod(fog_layer_scroll[2] + 8.0 * delta, 1024.0)

				# Di chuyển các đám sương cụm
				for p in particles:
					p["pos"].x += p["speed"] * delta
					p["pos"].y += sin(fog_anim_time * 0.5 + p["angle"]) * 6.0 * delta
					if p["pos"].x > vp.x + 260.0:
						p["pos"].x = -260.0
						p["pos"].y = randf_range(-40, vp.y - 80)
			FarmTimeSystem.Weather.WINDY, _:
				# Thời tiết Gió hoặc Mùa Thu: lá phong bay nhẹ nhàng, mật độ thưa thoáng mát
				for p in particles:
					p["angle"] += delta * 1.8
					p["rot"] += p["rot_speed"] * delta
					p["pos"].x += 135.0 * p["speed"] * delta
					p["pos"].y += sin(p["angle"]) * 24.0 * delta + 18.0 * delta
					if p["pos"].x > vp.x + 40.0:
						p["pos"].x = randf_range(-160.0, -40.0) # Xuất hiện lại cách đều thưa
						p["pos"].y = randf_range(0, vp.y)
						if not leaf_textures.is_empty():
							p["tex"] = leaf_textures.pick_random()

		queue_redraw()

	func _draw() -> void:
		var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
		var is_autumn: bool = (FarmTimeSystem.get_current_season() == FarmTimeSystem.Season.AUTUMN)
		var is_windy: bool = (current_weather == FarmTimeSystem.Weather.WINDY)

		# Vẽ các hạt thời tiết theo từng loại
		match current_weather:
			FarmTimeSystem.Weather.RAINY:
				for p in particles:
					var p1: Vector2 = p["pos"]
					var p2 := p1 + Vector2(-3.5, 16.0 * p["speed"])
					draw_line(p1, p2, Color(0.65, 0.85, 1.0, p["alpha"] * 0.7), 1.5)
			FarmTimeSystem.Weather.STORM:
				if flash_alpha > 0.0:
					draw_rect(Rect2(Vector2.ZERO, vp), Color(0.9, 0.95, 1.0, flash_alpha))
				for p in particles:
					var p1: Vector2 = p["pos"]
					var p2 := p1 + Vector2(-7.0, 24.0 * p["speed"])
					draw_line(p1, p2, Color(0.75, 0.90, 1.0, p["alpha"] * 0.85), 2.0)
			FarmTimeSystem.Weather.SNOWY:
				for p in particles:
					draw_circle(p["pos"], p["size"] * 0.7, Color(0.95, 0.98, 1.0, p["alpha"]))
			FarmTimeSystem.Weather.FOGGY:
				# 1. Lớp sương lam mờ mỏng dịu mát bao phủ toàn màn hình
				draw_rect(Rect2(Vector2.ZERO, vp), Color(0.88, 0.92, 0.97, 0.14))

				# 2. Vẽ các dải sương ngang trải dài cuộn Parallax (Layers)
				if not fog_layer_textures.is_empty():
					# Dải sương mặt đất (Ground mist)
					var g_tex = fog_layer_textures[0]
					var g_y := vp.y - g_tex.get_height() * 0.9
					var g_x1 := -fog_layer_scroll[0]
					while g_x1 < vp.x:
						draw_texture_rect(g_tex, Rect2(Vector2(g_x1, g_y), g_tex.get_size() * Vector2(1.3, 1.0)), false, Color(1, 1, 1, 0.45))
						g_x1 += g_tex.get_width() * 1.3 - 2

					# Dải sương tầng trung (Mid mist)
					if fog_layer_textures.size() > 1:
						var m_tex = fog_layer_textures[1]
						var m_y := vp.y * 0.30
						var m_x1 := -fog_layer_scroll[1]
						while m_x1 < vp.x:
							draw_texture_rect(m_tex, Rect2(Vector2(m_x1, m_y), m_tex.get_size() * Vector2(1.3, 0.9)), false, Color(1, 1, 1, 0.35))
							m_x1 += m_tex.get_width() * 1.3 - 2

					# Dải sương tầng cao (High mist)
					if fog_layer_textures.size() > 2:
						var h_tex = fog_layer_textures[2]
						var h_y := 0.0
						var h_x1 := -fog_layer_scroll[2]
						while h_x1 < vp.x:
							draw_texture_rect(h_tex, Rect2(Vector2(h_x1, h_y), h_tex.get_size() * Vector2(1.3, 0.85)), false, Color(1, 1, 1, 0.28))
							h_x1 += h_tex.get_width() * 1.3 - 2

				# 3. Vẽ các đám mây sương cụm bồng bềnh (Clouds & Puffs)
				for p in particles:
					var f_tex: Texture2D = p.get("tex")
					if f_tex != null:
						var p_alpha: float = p["alpha"] * (0.8 + 0.2 * sin(fog_anim_time * p.get("pulse_speed", 0.6) + p.get("pulse_offset", 0.0)))
						var sz: Vector2 = f_tex.get_size() * p.get("scale", 1.0)
						draw_texture_rect(f_tex, Rect2(p["pos"], sz), false, Color(1, 1, 1, p_alpha))
					else:
						# Fallback sương trắng xanh mờ ảo (tuyệt đối không dùng hình tròn cam)
						draw_circle(p["pos"], p["size"] * 2.0, Color(0.88, 0.92, 0.98, p["alpha"] * 0.15))
			FarmTimeSystem.Weather.WINDY, _:
				# Nếu là gió hoặc mùa thu: Vẽ các chiếc lá phong vàng/đỏ xoay bay trong gió
				if is_windy or is_autumn:
					for p in particles:
						var tex: Texture2D = p.get("tex")
						if tex != null:
							var sz: Vector2 = tex.get_size() * p.get("scale", 0.5)
							draw_set_transform(p["pos"], p["rot"], Vector2.ONE)
							draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, p["alpha"]))
							draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
						else:
							# Fallback hình học nếu chưa nạp sprite
							var leaf_col := Color(0.92, 0.55, 0.15, p["alpha"]) if is_autumn else Color(0.45, 0.85, 0.4, p["alpha"])
							draw_circle(p["pos"], p["size"], leaf_col)

func _ready() -> void:
	name = "FarmHud"
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Tạo lớp hiệu ứng thời tiết phủ toàn màn hình
	weather_vfx = WeatherVFX.new()
	weather_vfx.name = "WeatherVFX"
	add_child(weather_vfx)

	# Ẩn cụm phím kỹ năng chiến đấu & thanh thuốc nhanh (QuickItemBar) vì Sơn Trang là khu vực nông trại hòa bình
	_hide_combat_skill_bar()
	call_deferred("_hide_combat_skill_bar")

	_build_ui()
	_update_weather_ui()

	# Chào mừng vào Sơn Trang: phát ngẫu nhiên 1 trong 3 câu thoại giọng nữ thanh mảnh của Tiểu Linh
	var timer := get_tree().create_timer(0.8)
	if timer != null:
		timer.timeout.connect(_play_welcome_voice)

const WELCOME_VOICES: Array[String] = [
	"res://audio/sfx/son_trang/son_trang_welcome_1.mp3",
	"res://audio/sfx/son_trang/son_trang_welcome_2.mp3",
	"res://audio/sfx/son_trang/son_trang_welcome_3.mp3",
]

func _play_welcome_voice() -> void:
	if not is_inside_tree() or WELCOME_VOICES.is_empty():
		return

	var voice_path: String = WELCOME_VOICES[randi() % WELCOME_VOICES.size()]
	var stream := _load_voice_stream(voice_path)
	if stream != null and SfxManager != null:
		SfxManager.play_ui(stream)

func _load_voice_stream(path: String) -> AudioStream:
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			return mp3
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null

func _hide_combat_skill_bar() -> void:
	var parent_ui := get_parent()
	if parent_ui:
		var skill_bar = parent_ui.get_node_or_null("SkillBarUI")
		if skill_bar:
			skill_bar.visible = false
	_set_quick_item_bar_visible(false)

func _exit_tree() -> void:
	# Khôi phục hiện lại cụm skill & QuickItemBar khi rời khỏi Sơn Trang
	var parent_ui := get_parent()
	if parent_ui:
		var skill_bar = parent_ui.get_node_or_null("SkillBarUI")
		if skill_bar:
			skill_bar.visible = true
	_set_quick_item_bar_visible(true)

func _set_quick_item_bar_visible(p_visible: bool) -> void:
	var tree := get_tree()
	if tree:
		for bar in tree.get_nodes_in_group("quick_item_bar"):
			if bar is Control:
				bar.visible = p_visible
	var parent_ui := get_parent()
	if parent_ui:
		for child in parent_ui.get_children():
			if child.is_in_group("quick_item_bar") or child.name == "QuickItemBar" or child is QuickItemBar:
				if child is Control:
					child.visible = p_visible

func _build_ui() -> void:
	# 1. Panel Thông tin Thời Tiết & Cấp Sơn Trang (Góc trên trái)
	var info_panel := PanelContainer.new()
	info_panel.offset_left = 20
	info_panel.offset_top = 118
	info_panel.custom_minimum_size = Vector2(285, 0)
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color(0.06, 0.08, 0.07, 0.65)
	panel_box.border_color = Color(0.70, 0.60, 0.30, 0.80)
	panel_box.set_border_width_all(2)
	panel_box.set_corner_radius_all(8)
	panel_box.content_margin_left = 12
	panel_box.content_margin_top = 8
	panel_box.content_margin_right = 12
	panel_box.content_margin_bottom = 8
	info_panel.add_theme_stylebox_override("panel", panel_box)
	add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_vbox)

	# THẺ THỜI TIẾT ĐỘNG (WEATHER BADGE)
	_weather_badge = PanelContainer.new()
	var wb_style := StyleBoxFlat.new()
	wb_style.bg_color = Color(0.10, 0.14, 0.18, 0.65)
	wb_style.border_color = Color(0.4, 0.8, 1.0, 0.80)
	wb_style.set_border_width_all(1)
	wb_style.set_corner_radius_all(6)
	wb_style.content_margin_left = 8
	wb_style.content_margin_top = 6
	wb_style.content_margin_right = 8
	wb_style.content_margin_bottom = 6
	_weather_badge.add_theme_stylebox_override("panel", wb_style)

	var wb_vbox := VBoxContainer.new()
	wb_vbox.add_theme_constant_override("separation", 2)
	_weather_badge.add_child(wb_vbox)

	var wb_top := HBoxContainer.new()
	_weather_name_lbl = Label.new()
	_weather_name_lbl.add_theme_font_size_override("font_size", 13)
	wb_top.add_child(_weather_name_lbl)

	var wb_sp := Control.new()
	wb_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wb_top.add_child(wb_sp)

	_weather_temp_lbl = Label.new()
	_weather_temp_lbl.add_theme_font_size_override("font_size", 11)
	_weather_temp_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	wb_top.add_child(_weather_temp_lbl)

	var change_w_btn := Button.new()
	change_w_btn.text = "🌦️ Đổi"
	change_w_btn.focus_mode = Control.FOCUS_NONE
	change_w_btn.custom_minimum_size = Vector2(48, 22)
	change_w_btn.add_theme_font_size_override("font_size", 10)
	var cw_style := StyleBoxFlat.new()
	cw_style.bg_color = Color(0.18, 0.25, 0.32, 0.75)
	cw_style.border_color = Color(0.5, 0.8, 1.0, 0.80)
	cw_style.set_border_width_all(1)
	cw_style.set_corner_radius_all(4)
	change_w_btn.add_theme_stylebox_override("normal", cw_style)
	change_w_btn.pressed.connect(_open_weather_dialog)
	wb_top.add_child(change_w_btn)
	wb_vbox.add_child(wb_top)

	_weather_buff_lbl = Label.new()
	_weather_buff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weather_buff_lbl.add_theme_font_size_override("font_size", 11)
	_weather_buff_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	wb_vbox.add_child(_weather_buff_lbl)

	info_vbox.add_child(_weather_badge)

	# Chu kỳ 4 Mùa & Ngày / Đêm
	_season_time_lbl = Label.new()
	_season_time_lbl.name = "SeasonTimeLabel"
	_season_time_lbl.add_theme_font_size_override("font_size", 12)
	_season_time_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	info_vbox.add_child(_season_time_lbl)

	# Cấp độ Sơn Trang & EXP
	_level_lbl = Label.new()
	_level_lbl.name = "LevelLabel"
	_level_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	_level_lbl.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(_level_lbl)

	# 2. BẢNG ĐIỀU KHIỂN NÔNG TRẠI (GÓC PHẢI - XẾP THEO CHIỀU DỌC 3 CỘT)
	var right_panel := PanelContainer.new()
	right_panel.name = "FarmRightPanel"
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 1.0
	right_panel.anchor_bottom = 1.0
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right_panel.offset_right = -15
	right_panel.offset_bottom = -15

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.10, 0.88)
	panel_style.border_color = Color(0.85, 0.70, 0.30, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_bottom = 8
	right_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(right_panel)

	# Lưới icon tiện ích Sơn Trang
	var all_grid := GridContainer.new()
	all_grid.name = "AllIconsGrid"
	all_grid.columns = 3
	all_grid.add_theme_constant_override("h_separation", 6)
	all_grid.add_theme_constant_override("v_separation", 6)
	right_panel.add_child(all_grid)

	# Các nút tiện ích được giữ lại: Thả Ngoài, Tiệm, Rương
	var roam_btn := _make_action_btn("🐾 Thả Ngoài", _toggle_livestock_roam, Vector2(80, 42))
	all_grid.add_child(roam_btn)

	var shop_btn := _make_action_btn("🏪 Tiệm", _open_seed_shop, Vector2(80, 42))
	all_grid.add_child(shop_btn)

	var chest_btn := _make_action_btn("📦 Rương", _open_farm_chest, Vector2(80, 42))
	all_grid.add_child(chest_btn)

func _make_action_btn(label: String, callback: Callable, min_size: Vector2 = Vector2(100, 40)) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = min_size
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.08, 0.92)
	style.border_color = Color(0.95, 0.78, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.pressed.connect(callback)
	return btn

func _select_tool(tool_id: String) -> void:
	current_tool = tool_id
	for tid in _tool_buttons.keys():
		_style_tool_button(_tool_buttons[tid], tid == current_tool)
	tool_selected.emit(current_tool)

func _style_tool_button(btn: Button, is_selected: bool) -> void:
	var st := StyleBoxFlat.new()
	if is_selected:
		st.bg_color = Color(0.30, 0.25, 0.12, 0.95)
		st.border_color = Color(1.0, 0.85, 0.2)
		st.set_border_width_all(2)
	else:
		st.bg_color = Color(0.10, 0.11, 0.10, 0.88)
		st.border_color = Color(0.5, 0.5, 0.5)
		st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", st)

func _get_phase_text() -> String:
	match FarmTimeSystem.get_current_day_phase():
		FarmTimeSystem.DayPhase.DAY: return "Ban Ngày"
		FarmTimeSystem.DayPhase.SUNSET: return "Hoàng Hôn"
		FarmTimeSystem.DayPhase.NIGHT: return "Ban Đêm"
		FarmTimeSystem.DayPhase.DAWN: return "Bình Minh"
	return "Ban Ngày"

func _walk_to_farm() -> void:
	var farm_pos := Vector2(47920.0, 47660.0)
	var plyr = get_tree().get_first_node_in_group("player")
	if plyr:
		if plyr.global_position.distance_to(farm_pos) < 160.0:
			_show_popup_msg("🌱 Bạn đã đứng tại Khu Trồng Trọt!")
			return
		if plyr.has_method("walk_to_feet"):
			plyr.walk_to_feet(farm_pos)
		elif "destination" in plyr:
			plyr.destination = farm_pos
		_show_popup_msg("🏃 Đang di chuyển đến Khu Trồng Trọt [187/186]...")

func _walk_to_livestock() -> void:
	var pen_pos := Vector2(49792.0, 49536.0)
	var plyr = get_tree().get_first_node_in_group("player")
	if plyr:
		_select_tool("whip")
		if plyr.global_position.distance_to(pen_pos) < 160.0:
			_show_popup_msg("🐑 Bạn đã đứng tại Khu Chăn Nuôi [194/193]!")
			return
		if plyr.has_method("walk_to_feet"):
			plyr.walk_to_feet(pen_pos)
		elif "destination" in plyr:
			plyr.destination = pen_pos
		_show_popup_msg("🏃 Đang di chuyển đến Khu Chăn Nuôi [194/193]...")

func _toggle_livestock_roam() -> void:
	var ls = get_tree().root.find_child("LivestockController", true, false)
	if ls != null and ls.has_method("toggle_all_roam_outside"):
		var roaming: bool = ls.toggle_all_roam_outside()
		if roaming:
			_show_popup_msg("🐾 Đã mở cổng! Toàn bộ thú nuôi đang di chuyển dạo chơi ngoài trời!")
		else:
			_show_popup_msg("🐑 Đã lùa đàn thú nuôi trở về chuồng nghỉ ngơi!")
	else:
		_show_popup_msg("🐑 Chưa tìm thấy Khu Chăn Nuôi!")

func _quick_harvest_all() -> void:
	var farm_mgr: FarmManager = get_node_or_null("/root/FarmManager")
	if farm_mgr == null or farm_mgr.plot_mgr == null:
		return
	var harvested_count := 0
	var total_gold := 0
	var total_exp := 0
	for i in range(farm_mgr.plot_mgr.plots.size()):
		var p: PlotManager.PlotInfo = farm_mgr.plot_mgr.plots[i]
		if p.is_unlocked and p.state == PlotManager.PlotState.HARVESTABLE:
			var res = farm_mgr.plot_mgr.harvest_plot(i)
			if res.get("success", false):
				harvested_count += 1
				total_gold += int(res.get("gold", 100))
				total_exp += int(res.get("exp", 50))
				var plant_id = str(res.get("plant_id", ""))
				farm_mgr.add_to_chest(plant_id, 1, false)
	if harvested_count > 0:
		farm_mgr.add_farm_exp(total_exp)
		farm_mgr.save_farm_data()
		_show_popup_msg("✨ Đã thu hoạch nhanh %d luống nông sản!\n(+%d Exp | +%d Lượng)" % [harvested_count, total_exp, total_gold])
	else:
		_show_popup_msg("🌱 Chưa có luống nông sản nào chín để thu hoạch!")

func _open_seed_shop() -> void:
	_show_npc_shop_selector()

func _show_npc_shop_selector() -> void:
	var existing = get_node_or_null("NPCSelectorDialog")
	if existing:
		existing.queue_free()
		return

	var win := PanelContainer.new()
	win.name = "NPCSelectorDialog"
	win.custom_minimum_size = Vector2(520, 420)
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -260
	win.offset_right = 260
	win.offset_top = -210
	win.offset_bottom = 210

	# Cho phép kéo và di chuyển bảng tự do trên màn hình
	var is_dragging := [false]
	var drag_start_mouse := [Vector2.ZERO]
	var drag_start_win_pos := [Vector2.ZERO]

	var handle_drag_input = func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging[0] = true
				drag_start_mouse[0] = event.global_position
				drag_start_win_pos[0] = win.position
				win.move_to_front()
			else:
				is_dragging[0] = false
		elif event is InputEventMouseMotion and is_dragging[0]:
			var delta = event.global_position - drag_start_mouse[0]
			var new_pos = drag_start_win_pos[0] + delta
			var screen = win.get_viewport_rect().size
			if screen.x > 0 and screen.y > 0:
				new_pos.x = clampf(new_pos.x, 0.0, maxf(0.0, screen.x - win.size.x))
				new_pos.y = clampf(new_pos.y, 0.0, maxf(0.0, screen.y - win.size.y))
			win.position = new_pos

	win.mouse_filter = Control.MOUSE_FILTER_PASS
	win.gui_input.connect(handle_drag_input)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.11, 0.98)
	bg.border_color = Color(0.9, 0.78, 0.3)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 16
	bg.content_margin_top = 12
	bg.content_margin_right = 16
	bg.content_margin_bottom = 12
	bg.shadow_color = Color(0, 0, 0, 0.6)
	bg.shadow_size = 12
	win.add_theme_stylebox_override("panel", bg)
	add_child(win)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	win.add_child(vbox)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(handle_drag_input)

	var title := Label.new()
	title.text = "🏪 DANH SÁCH THƯƠNG NHÂN SƠN TRANG"
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	title.add_theme_font_size_override("font_size", 15)
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(title)

	var hint_lbl := Label.new()
	hint_lbl.text = " (Kéo để di chuyển • Cuộn chuột để xem)"
	hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(hint_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.35, 0.12, 0.12, 0.85)
	close_style.border_color = Color(0.85, 0.35, 0.35)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(win.queue_free)
	header.add_child(close_btn)
	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	# Khung cuộn danh sách (ScrollContainer) để không bao giờ bị tràn màn hình
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)
	vbox.add_child(scroll)

	var npcs = [
		{
			"cat": "agriculture",
			"name": "🌾 Thần Nông Tiên Sinh [191/186]",
			"desc": "Điền chủ trồng trọt: Hạt giống, phân bón, cuốc đất",
			"pos": Vector2(49024.0, 47744.0),
			"color": Color(0.4, 0.9, 0.4)
		},
		{
			"cat": "livestock",
			"name": "🐑 Trương Bá [195/192]",
			"desc": "Thương nhân chăn nuôi: Heo, trâu, hươu & con giống",
			"pos": Vector2(50048.0, 49280.0),
			"color": Color(1.0, 0.85, 0.3)
		},
		{
			"cat": "meat_exchange",
			"name": "🍗 Trù Thần Sơn Trang [194/191]",
			"desc": "Thu mua thịt: Đổi thịt chăn nuôi lấy EXP, Tiền & Rương Bách Thú (Skill 150/180)",
			"pos": Vector2(49792.0, 49024.0),
			"color": Color(1.0, 0.68, 0.25)
		},
		{
			"cat": "freshwater_fish",
			"name": "🐟 Khê Hồ Ngư Nương [180/185]",
			"desc": "Ngư nương hồ đầm: Cần câu trúc, trùng mồi, cá trắm",
			"pos": Vector2(46208.0, 47488.0),
			"color": Color(0.4, 0.85, 1.0)
		},
		{
			"cat": "ocean_fish",
			"name": "⚓ Hải Ngư Thuyền Trưởng [196/197]",
			"desc": "Thuyền trưởng biển: Cần câu biển, mồi tôm, cá vược",
			"pos": Vector2(50304.0, 50560.0),
			"color": Color(0.35, 0.75, 1.0)
		},
		{
			"cat": "fish_ocean",
			"name": "🌊 Bè Nuôi Cá Biển Sâu [188/202]",
			"desc": "Khu đánh bắt cá biển: Giàn bè nổi, lưới kéo đại dương, cá hồi biển",
			"pos": Vector2(48256.0, 51840.0),
			"color": Color(0.25, 0.85, 0.95)
		},
		{
			"cat": "campfire",
			"name": "🔥 Đống Lửa Nông Trại [192/187]",
			"coord_name": "192/187",
			"npc_name": "Thần Nông Tiên Sinh",
			"world_pos": Vector2(49280.0, 48000.0),
			"desc": "Lửa trại sưởi ấm: Tăng tu vi +2000 EXP/s, +20 EXP Sơn Trang",
			"pos": Vector2(49280.0, 48000.0),
			"color": Color(1.0, 0.65, 0.2)
		},
		{
			"cat": "campfire",
			"name": "🔥 Đống Lửa Chuồng Trại [195/193]",
			"coord_name": "195/193",
			"npc_name": "Trương Bá (Chăn Nuôi)",
			"world_pos": Vector2(50048.0, 49536.0),
			"desc": "Lửa trại sưởi ấm: Tăng tu vi +2000 EXP/s, +20 EXP Sơn Trang",
			"pos": Vector2(50048.0, 49536.0),
			"color": Color(1.0, 0.65, 0.2)
		},
		{
			"cat": "campfire",
			"name": "🔥 Đống Lửa Bến Hồ [179/185]",
			"coord_name": "179/185",
			"npc_name": "Khê Hồ Ngư Nương",
			"world_pos": Vector2(45952.0, 47488.0),
			"desc": "Lửa trại sưởi ấm: Tăng tu vi +2000 EXP/s, +20 EXP Sơn Trang",
			"pos": Vector2(45952.0, 47488.0),
			"color": Color(1.0, 0.65, 0.2)
		},
		{
			"cat": "campfire",
			"name": "🔥 Đống Lửa Bờ Biển [195/197]",
			"coord_name": "195/197",
			"npc_name": "Hải Ngư Thuyền Trưởng",
			"world_pos": Vector2(50080.0, 50560.0),
			"desc": "Lửa trại sưởi ấm: Tăng tu vi +2000 EXP/s, +20 EXP Sơn Trang",
			"pos": Vector2(50080.0, 50560.0),
			"color": Color(1.0, 0.65, 0.2)
		}
	]

	for n in npcs:
		var pnl := PanelContainer.new()
		var pbox := StyleBoxFlat.new()
		pbox.bg_color = Color(0.13, 0.14, 0.17, 0.9)
		pbox.set_border_width_all(1)
		pbox.border_color = Color(0.3, 0.32, 0.36)
		pbox.set_corner_radius_all(6)
		pbox.content_margin_left = 10
		pbox.content_margin_top = 6
		pbox.content_margin_right = 10
		pbox.content_margin_bottom = 6
		pnl.add_theme_stylebox_override("panel", pbox)

		var rbox := HBoxContainer.new()
		rbox.add_theme_constant_override("separation", 8)
		pnl.add_child(rbox)

		var ivbox := VBoxContainer.new()
		ivbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nlbl := Label.new()
		nlbl.text = n["name"]
		nlbl.add_theme_color_override("font_color", n["color"])
		nlbl.add_theme_font_size_override("font_size", 13)
		ivbox.add_child(nlbl)

		var dlbl := Label.new()
		dlbl.text = n["desc"]
		dlbl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
		dlbl.add_theme_font_size_override("font_size", 11)
		ivbox.add_child(dlbl)
		rbox.add_child(ivbox)

		var walk_b := Button.new()
		walk_b.text = "🏃 Đến"
		walk_b.custom_minimum_size = Vector2(58, 30)
		walk_b.pressed.connect(func():
			win.queue_free()
			_walk_to_target(n["pos"], n["name"])
		)
		rbox.add_child(walk_b)

		var shop_b := Button.new()
		if n["cat"] == "campfire":
			shop_b.text = "Lửa Trại"
		elif n["cat"] == "fish_ocean":
			shop_b.text = "Khu Nuôi"
		elif n["cat"] == "meat_exchange":
			shop_b.text = "Đổi Thịt"
		else:
			shop_b.text = "Mở Tiệm"
		shop_b.custom_minimum_size = Vector2(74, 30)
		shop_b.pressed.connect(func():
			win.queue_free()
			if n["cat"] == "campfire":
				FarmWindowsScript.open_campfire(self, n)
			elif n["cat"] == "fish_ocean":
				var fish_ctrl = get_tree().get_first_node_in_group("farm_fish_controller")
				if fish_ctrl == null:
					fish_ctrl = get_tree().root.find_child("FarmFishController", true, false)
				if fish_ctrl and fish_ctrl.has_method("_open_fish_action_modal"):
					fish_ctrl._open_fish_action_modal(1)
			elif n["cat"] == "meat_exchange":
				FarmWindowsScript.open_meat_exchange(self)
			else:
				FarmNPCShop.open_shop(self, n["cat"])
		)
		rbox.add_child(shop_b)

		list_vbox.add_child(pnl)

func _walk_to_target(target_pos: Vector2, target_name: String) -> void:
	var plyr = get_tree().get_first_node_in_group("player")
	if plyr:
		if plyr.global_position.distance_to(target_pos) < 120.0:
			_show_popup_msg("Bạn đã đứng cạnh %s!" % target_name)
			return
		if plyr.has_method("walk_to_feet"):
			plyr.walk_to_feet(target_pos)
		elif "destination" in plyr:
			plyr.destination = target_pos
		_show_popup_msg("🏃 Đang di chuyển đến %s..." % target_name)

func _open_farm_chest() -> void:
	FarmWindowsScript.open_chest(self)

func _feed_campfire() -> void:
	FarmWindowsScript.open_campfire(self)

func _show_popup_msg(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	lbl.position = Vector2(get_viewport_rect().size.x * 0.5 - 150, get_viewport_rect().size.y * 0.5 - 100)
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 40, 1.5)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.tween_callback(lbl.queue_free)

func _process(delta: float) -> void:
	_weather_check_timer += delta
	if _weather_check_timer >= 1.0:
		_weather_check_timer = 0.0
		var cur_w := FarmTimeSystem.get_current_weather()
		var cur_phase := int(FarmTimeSystem.get_current_day_phase())
		if int(cur_w) != _last_displayed_weather or cur_phase != _last_displayed_phase:
			_update_weather_ui()

func _update_weather_ui() -> void:
	var w_info := FarmTimeSystem.get_weather_info()
	_last_displayed_weather = int(w_info.get("id", 0))
	_last_displayed_phase = int(FarmTimeSystem.get_current_day_phase())

	# 1. Cập nhật nhãn và theme thẻ thời tiết
	if _weather_name_lbl:
		_weather_name_lbl.text = "%s %s" % [w_info["icon"], w_info["name"]]
		_weather_name_lbl.add_theme_color_override("font_color", w_info["theme_color"])

	if _weather_temp_lbl:
		_weather_temp_lbl.text = "🌡️ %d°C  |  💧 %d%%" % [w_info["temp"], w_info["humidity"]]

	if _weather_buff_lbl:
		_weather_buff_lbl.text = "✨ %s" % w_info["buff_desc"]

	if _weather_badge:
		var sb := _weather_badge.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.border_color = w_info["theme_color"]

	# 2. Cập nhật chu kỳ ngày/đêm và mùa
	if _season_time_lbl:
		_season_time_lbl.text = "🌿 %s  •  %s" % [
			FarmTimeSystem.get_season_name(),
			FarmTimeSystem.get_day_phase_name()
		]

	# 3. Cập nhật cấp độ Sơn Trang
	if _level_lbl:
		var farm_mgr: FarmManager = get_node_or_null("/root/FarmManager")
		var lvl: int = farm_mgr.farm_level if farm_mgr != null else 1
		var exp_cur: int = farm_mgr.farm_exp if farm_mgr != null else 0
		var exp_need: int = farm_mgr.get_exp_needed_for_level(lvl) if farm_mgr != null else 100
		_level_lbl.text = "⭐ Trang Trại Cấp %d (%d/%d EXP)" % [lvl, exp_cur, exp_need]

	# 4. Cập nhật visual particles
	if weather_vfx:
		weather_vfx.update_weather(int(w_info["id"]))

## Cửa sổ Dự Báo & Chuyển Đổi Thời Tiết (Weather Forecast & Controller Modal)
func _open_weather_dialog() -> void:
	var old = get_node_or_null("WeatherForecastDialog")
	if old:
		old.queue_free()
		return

	var win := PanelContainer.new()
	win.name = "WeatherForecastDialog"
	win.custom_minimum_size = Vector2(540, 520)
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -270
	win.offset_right = 270
	win.offset_top = -260
	win.offset_bottom = 260

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.11, 0.14, 0.98)
	bg.border_color = Color(0.92, 0.78, 0.3)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 16
	bg.content_margin_top = 12
	bg.content_margin_right = 16
	bg.content_margin_bottom = 12
	win.add_theme_stylebox_override("panel", bg)
	add_child(win)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	win.add_child(vbox)

	# 1. Header
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "🌦️ THỜI TIẾT & CHU KỲ NGÀY ĐÊM SƠN TRANG"
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title.add_theme_font_size_override("font_size", 14)
	head.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)

	var close_b := Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(26, 26)
	close_b.pressed.connect(win.queue_free)
	head.add_child(close_b)
	vbox.add_child(head)

	# 2. Cụm điều khiển Chu kỳ Ngày & Đêm
	var time_section := PanelContainer.new()
	var ts_bg := StyleBoxFlat.new()
	ts_bg.bg_color = Color(0.12, 0.15, 0.19, 0.90)
	ts_bg.border_color = Color(0.65, 0.78, 0.92, 0.75)
	ts_bg.set_border_width_all(1)
	ts_bg.set_corner_radius_all(6)
	ts_bg.content_margin_left = 10
	ts_bg.content_margin_top = 8
	ts_bg.content_margin_right = 10
	ts_bg.content_margin_bottom = 8
	time_section.add_theme_stylebox_override("panel", ts_bg)
	vbox.add_child(time_section)

	var ts_vbox := VBoxContainer.new()
	ts_vbox.add_theme_constant_override("separation", 6)
	time_section.add_child(ts_vbox)

	var ts_lbl := Label.new()
	ts_lbl.text = "⏰ CHUYỂN ĐỔI NGÀY & ĐÊM (Ban đêm Đống Lửa phát sáng rực rỡ):"
	ts_lbl.add_theme_font_size_override("font_size", 11)
	ts_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	ts_vbox.add_child(ts_lbl)

	var phase_hbox := HBoxContainer.new()
	phase_hbox.add_theme_constant_override("separation", 6)
	ts_vbox.add_child(phase_hbox)

	var phase_opts = [
		{"phase": -1, "label": "⏱️ Giờ Thực"},
		{"phase": FarmTimeSystem.DayPhase.DAY, "label": "☀️ Ban Ngày"},
		{"phase": FarmTimeSystem.DayPhase.SUNSET, "label": "🌇 Hoàng Hôn"},
		{"phase": FarmTimeSystem.DayPhase.NIGHT, "label": "🌙 Ban Đêm"},
		{"phase": FarmTimeSystem.DayPhase.DAWN, "label": "🌅 Bình Minh"}
	]

	var cur_phase = FarmTimeSystem.custom_day_phase

	for opt in phase_opts:
		var p_btn := Button.new()
		p_btn.text = opt["label"]
		p_btn.focus_mode = Control.FOCUS_NONE
		p_btn.custom_minimum_size = Vector2(92, 30)
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.add_theme_font_size_override("font_size", 11)
		var is_selected: bool = (cur_phase == opt["phase"])
		var b_style := StyleBoxFlat.new()
		if is_selected:
			b_style.bg_color = Color(0.35, 0.28, 0.12, 0.95)
			b_style.border_color = Color(1.0, 0.85, 0.25)
			b_style.set_border_width_all(2)
		else:
			b_style.bg_color = Color(0.16, 0.18, 0.22, 0.85)
			b_style.border_color = Color(0.4, 0.45, 0.5)
			b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(4)
		p_btn.add_theme_stylebox_override("normal", b_style)
		p_btn.pressed.connect(func():
			if opt["phase"] < 0:
				FarmTimeSystem.reset_day_phase_to_realtime()
				_show_popup_msg("⏱️ Đã khôi phục Chu kỳ Ngày/Đêm theo Giờ Thực Tế!")
			else:
				FarmTimeSystem.set_day_phase(opt["phase"])
				_show_popup_msg("✨ Đã chuyển sang: %s!\n(Đống lửa sẽ sáng rực rỡ một vùng xung quanh)" % opt["label"])
			_update_weather_ui()
			win.queue_free()
			_open_weather_dialog()
		)
		phase_hbox.add_child(p_btn)

	# 3. Scroll list các kiểu thời tiết
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(list_vbox)

	var cur_w_id := int(FarmTimeSystem.get_current_weather())
	var all_w := FarmTimeSystem.get_all_weathers()

	for item in all_w:
		var w_id: int = item["id"]
		var is_active: bool = (w_id == cur_w_id)

		var card := PanelContainer.new()
		var card_bg := StyleBoxFlat.new()
		card_bg.bg_color = Color(0.14, 0.17, 0.22, 0.95) if is_active else Color(0.11, 0.12, 0.14, 0.85)
		card_bg.border_color = item["theme_color"] if is_active else Color(0.3, 0.35, 0.4)
		card_bg.set_border_width_all(2 if is_active else 1)
		card_bg.set_corner_radius_all(6)
		card_bg.content_margin_left = 10
		card_bg.content_margin_top = 8
		card_bg.content_margin_right = 10
		card_bg.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_bg)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		card.add_child(hbox)

		# Icon to
		var icon_lbl := Label.new()
		icon_lbl.text = item["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 24)
		hbox.add_child(icon_lbl)

		# Thông tin chi tiết
		var ivbox := VBoxContainer.new()
		ivbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ivbox.add_theme_constant_override("separation", 2)

		var r1 := HBoxContainer.new()
		var n_lbl := Label.new()
		n_lbl.text = item["name"]
		n_lbl.add_theme_color_override("font_color", item["theme_color"])
		n_lbl.add_theme_font_size_override("font_size", 13)
		r1.add_child(n_lbl)

		var t_lbl := Label.new()
		t_lbl.text = " (🌡️ %d°C | 💧 %d%%)" % [item["temp"], item["humidity"]]
		t_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		t_lbl.add_theme_font_size_override("font_size", 11)
		r1.add_child(t_lbl)
		ivbox.add_child(r1)

		var b_lbl := Label.new()
		b_lbl.text = item["buff_desc"]
		b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b_lbl.add_theme_font_size_override("font_size", 11)
		b_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
		ivbox.add_child(b_lbl)
		hbox.add_child(ivbox)

		# Nút chọn thời tiết
		if is_active:
			var act_lbl := Label.new()
			act_lbl.text = "✓ Đang Kích Hoạt"
			act_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
			act_lbl.add_theme_font_size_override("font_size", 11)
			hbox.add_child(act_lbl)
		else:
			var pick_btn := Button.new()
			pick_btn.text = "⚡ Chuyển"
			pick_btn.custom_minimum_size = Vector2(72, 32)
			pick_btn.focus_mode = Control.FOCUS_NONE
			var pb_style := StyleBoxFlat.new()
			pb_style.bg_color = Color(0.20, 0.28, 0.38)
			pb_style.border_color = item["theme_color"]
			pb_style.set_border_width_all(1)
			pb_style.set_corner_radius_all(4)
			pick_btn.add_theme_stylebox_override("normal", pb_style)
			pick_btn.pressed.connect(func():
				FarmTimeSystem.set_weather(w_id as FarmTimeSystem.Weather)
				_update_weather_ui()
				_show_popup_msg("🌤️ Đã hô mưa gọi gió! Thời tiết chuyển sang: %s" % item["name"])
				win.queue_free()
				_open_weather_dialog()
			)
			hbox.add_child(pick_btn)

		list_vbox.add_child(card)
