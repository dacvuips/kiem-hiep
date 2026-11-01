extends Node
class_name CityWarMatch
## Trình điều phối Chiến trường Công Thành Chiến (20 vs 20 trên Map 378 - 20 phút)
## Quản lý: 3 Cột Long Trụ, 20 Chiến binh Phe Công vs 20 Chiến binh Phe Thủ,
## Đếm ngược 20 phút (1200s), xác định Thắng/Thua và cập nhật Thành Chủ mới.

const HUB_SCENE := "res://ui/character_hub/CharacterHub.tscn"

var city_id: String = "bien_kinh"
var is_attacker: bool = true
var match_time: float = CityWarRules.MATCH_DURATION_SEC
var is_ended: bool = false

## 3 Long Trụ (Tả - Giữa - Hữu)
var pillars: Array[VltkMonster] = []
var pillar_owners: Array[int] = [1, 1, 1] ## 1: Phe Thủ, 2: Phe Công (Ban đầu thuộc phe Thủ)

var allies: Array[PkBot] = []
var enemies: Array[PkBot] = []

var hud: Control = null
var timer_label: Label = null
var score_label: Label = null

func _ready() -> void:
	var field: Dictionary = GameManager.field_map
	city_id = str(field.get("city_id", "bien_kinh"))
	is_attacker = bool(field.get("is_attacker", true))
	
	_setup_hud()
	_setup_player()
	_spawn_pillars()
	_spawn_armies()

func _setup_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 320.0
	top_panel.offset_right = -320.0
	top_panel.offset_top = 10.0
	top_panel.offset_bottom = 75.0
	hud.add_child(top_panel)
	
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	top_panel.add_child(vb)
	
	var cdef := CityWarRules.get_city_def(city_id)
	var title := Label.new()
	title.text = "⚔️ CÔNG THÀNH CHIẾN — %s (20 vs 20) ⚔️" % cdef.get("name", "Biện Kinh")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)
	
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 30)
	vb.add_child(hb)
	
	timer_label = Label.new()
	timer_label.text = "⏱️ Thời Gian: 20:00"
	timer_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	timer_label.add_theme_font_size_override("font_size", 15)
	hb.add_child(timer_label)
	
	score_label = Label.new()
	score_label.text = "🚩 Trụ Phe Thủ: 3  |  Trụ Phe Công: 0"
	score_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	score_label.add_theme_font_size_override("font_size", 15)
	hb.add_child(score_label)
	
	var leave_btn := Button.new()
	leave_btn.text = "Rời Trận"
	leave_btn.focus_mode = Control.FOCUS_NONE
	leave_btn.pressed.connect(_on_leave_pressed)
	hb.add_child(leave_btn)

func _setup_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var spawn_pos: Vector2 = TongKimLolRules.HOME_SONG_POS if is_attacker else TongKimLolRules.HOME_JIN_POS
		player.global_position = spawn_pos
		if VltkWorld.current != null:
			VltkWorld.current.respawn_point = spawn_pos

func _spawn_pillars() -> void:
	var positions := [CityWarRules.PILLAR_LEFT_POS, CityWarRules.PILLAR_MID_POS, CityWarRules.PILLAR_RIGHT_POS]
	var names := ["Tả Thủ Long Trụ", "Trung Tâm Long Trụ", "Hữu Thủ Long Trụ"]
	
	for i in range(3):
		var p := VltkMonster.new()
		p.name = "LongTru%d" % i
		p.display_name = names[i]
		p.max_hp = CityWarRules.PILLAR_MAX_HP
		p.current_hp = CityWarRules.PILLAR_MAX_HP
		p.is_boss = true
		p.position = positions[i]
		add_child(p)
		pillars.append(p)
		
		var idx := i
		p.tree_exiting.connect(func() -> void: _on_pillar_destroyed(idx))

func _spawn_armies() -> void:
	if not GameModeManager.allows_bot():
		return
	
	var my_camp_pos: Vector2 = TongKimLolRules.HOME_SONG_POS if is_attacker else TongKimLolRules.HOME_JIN_POS
	var opp_camp_pos: Vector2 = TongKimLolRules.HOME_JIN_POS if is_attacker else TongKimLolRules.HOME_SONG_POS
	
	# Sinh 19 đồng minh bot (cùng người chơi là đủ 20)
	for i in range(19):
		var bot_p := PkBotProfile.create(GameManager.local_profile.level)
		bot_p.display_name = "Đồng Minh %d" % (i + 1)
		var ally := PkBot.new()
		ally.setup(bot_p)
		ally.global_position = my_camp_pos + Vector2(randf_range(-150, 150), randf_range(-150, 150))
		add_child(ally)
		allies.append(ally)
		
	# Sinh 20 đối thủ bot
	for i in range(20):
		var bot_p := PkBotProfile.create(GameManager.local_profile.level)
		bot_p.display_name = "Thủ Thành Quân %d" % (i + 1)
		var enemy := PkBot.new()
		enemy.setup(bot_p)
		enemy.global_position = opp_camp_pos + Vector2(randf_range(-150, 150), randf_range(-150, 150))
		add_child(enemy)
		enemies.append(enemy)

func _process(delta: float) -> void:
	if is_ended:
		return
		
	match_time -= delta
	if match_time <= 0.0:
		match_time = 0.0
		_end_match(false, "Hết thời gian 20 phút!")
		return
		
	var m := int(match_time / 60.0)
	var s := int(match_time) % 60
	if timer_label:
		timer_label.text = "⏱️ Thời Gian: %02d:%02d" % [m, s]

func _on_pillar_destroyed(idx: int) -> void:
	if is_ended:
		return
	# Trụ bị hạ gục -> Đổi chủ sở hữu
	var current_owner: int = pillar_owners[idx]
	pillar_owners[idx] = 2 if current_owner == 1 else 1
	
	var def_count: int = 0
	var atk_count: int = 0
	for o in pillar_owners:
		if o == 1:
			def_count += 1
		else:
			atk_count += 1
			
	if score_label:
		score_label.text = "🚩 Trụ Phe Thủ: %d  |  Trụ Phe Công: %d" % [def_count, atk_count]
		
	# Nếu phe Công chiếm trọn 3 trụ -> Thắng tuyệt đối
	if atk_count >= 3:
		_end_match(true, "Phe Công Thành đã đoạt toàn bộ 3 Long Trụ!")
	elif def_count >= 3:
		_end_match(false, "Phe Thủ Thành bảo vệ toàn vẹn 3 Long Trụ!")

func _end_match(attacker_won: bool, reason: String) -> void:
	if is_ended:
		return
	is_ended = true
	
	var my_win: bool = (attacker_won and is_attacker) or (not attacker_won and not is_attacker)
	var title_str := "KHẢI HOÀN THẮNG LỢI! 🏆" if my_win else "CÔNG THÀNH THẤT BẠI! ⚔️"
	var body_str := "%s\n\n" % reason
	
	if my_win:
		body_str += "Chúc mừng quý bang đã đoạt quyền kiểm soát thành trì!\nNhận danh hiệu Thành Chủ và hưởng thuế thành mỗi ngày."
		if is_attacker and GameManager.local_profile:
			var gname := str(GameManager.local_profile.guild.get("name", "Đại Hiệp Bang"))
			CityWarService.set_city_owner(city_id, gname, GameManager.local_profile.display_name)
	else:
		body_str += "Thành lũy đối phương quá kiên cố, hãy hội quân phục thù vào đợt sau!"
		
	SocialWindow.confirm(self, title_str, body_str + "\n\nNhấn Đồng ý để trở về Character Hub.", func() -> void:
		_on_leave_pressed()
	)

func _on_leave_pressed() -> void:
	GameManager.current_stage = null
	GameManager.field_map = {}
	get_tree().change_scene_to_file(HUB_SCENE)
