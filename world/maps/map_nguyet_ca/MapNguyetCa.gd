extends Node2D
## Map Nguyệt Ca Đảo - Bản Đồ Sơn Trang Nông Trại
## Tích hợp chu kỳ 4 mùa, ngày / đêm và quản lý ô đất trồng trọt, đống lửa, NPC.

@onready var night_overlay: ColorRect = $CanvasLayer/NightOverlay
@onready var season_label: Label = $CanvasLayer/HUD/SeasonLabel
@onready var day_phase_label: Label = $CanvasLayer/HUD/DayPhaseLabel
@onready var farm_level_label: Label = $CanvasLayer/HUD/FarmLevelLabel
@onready var plots_container: Node2D = $PlotsContainer
@onready var campfire: Node2D = $Campfire

var farm_mgr: FarmManager = null

func _ready() -> void:
	# Tìm hoặc nạp FarmManager
	if has_node("/root/FarmManager"):
		farm_mgr = get_node("/root/FarmManager")
	else:
		farm_mgr = FarmManager.new()
		add_child(farm_mgr)

	_update_environment_visuals()
	_update_hud()
	
	if farm_mgr:
		farm_mgr.farm_data_changed.connect(_update_hud)

func _process(_delta: float) -> void:
	_update_night_shader_position()

func _update_environment_visuals() -> void:
	var phase := FarmTimeSystem.get_current_day_phase()
	var is_night := (phase == FarmTimeSystem.DayPhase.NIGHT)
	
	if night_overlay and night_overlay.material:
		var mat := night_overlay.material as ShaderMaterial
		if mat:
			var intensity := 0.85 if is_night else (0.4 if phase == FarmTimeSystem.DayPhase.SUNSET else 0.0)
			mat.set_shader_parameter("darkness_intensity", intensity)

func _update_night_shader_position() -> void:
	var player = get_node_or_null("Player")
	if player and night_overlay and night_overlay.material:
		var screen_pos = player.get_global_transform_with_canvas().origin
		var vp_size = get_viewport_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			var uv = Vector2(screen_pos.x / vp_size.x, screen_pos.y / vp_size.y)
			var mat := night_overlay.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("player_screen_pos", uv)

func _update_hud() -> void:
	if season_label:
		season_label.text = "🌿 " + FarmTimeSystem.get_season_name()
	if day_phase_label:
		var phase := FarmTimeSystem.get_current_day_phase()
		var w_info := FarmTimeSystem.get_weather_info()
		var phase_str := "☀️ Ban Ngày"
		match phase:
			FarmTimeSystem.DayPhase.DAY:
				phase_str = "☀️ Ban Ngày"
			FarmTimeSystem.DayPhase.SUNSET:
				phase_str = "🌇 Hoàng Hôn"
			FarmTimeSystem.DayPhase.NIGHT:
				phase_str = "🌙 Ban Đêm"
			FarmTimeSystem.DayPhase.DAWN:
				phase_str = "🌅 Bình Minh"
		day_phase_label.text = "%s  •  %s %s" % [phase_str, w_info.get("icon", ""), w_info.get("name", "")]
	if farm_level_label and farm_mgr:
		farm_level_label.text = "🏰 Sơn Trang Cấp: %d (EXP: %d/%d)" % [
			farm_mgr.farm_level,
			farm_mgr.farm_exp,
			farm_mgr.get_exp_needed_for_level(farm_mgr.farm_level)
		]
