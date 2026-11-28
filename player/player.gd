extends CharacterBody2D

const DamageNumberScene := preload("res://effects/damage_number.tscn")
const GuildEmblem = preload("res://systems/social/guild_emblem.gd")
const GuildTag = preload("res://ui/guild_tag.gd")

const SPEED = 150.0
const INVINCIBLE_DURATION = 3.0
const INVINCIBLE_BLINKS = 3
## Vị trí (y) tên nhân vật khi đi bộ — ngay trên đầu nhân vật ghép — và độ nâng thêm khi cưỡi ngựa.
const NAME_LABEL_Y = -66.0
const RIDE_HEAD_RAISE = 24.0
## Thu/phóng camera: < 1 = nhìn rộng hơn. 0.7 cho nhân vật cao ~8.5% chiều cao màn hình như ảnh chụp VLTK gốc (trước đây 1.0 ~ 12%).
## Mức đã chọn lưu trong GameSettings (cài đặt của máy), CAMERA_ZOOM là mặc định.
const CAMERA_ZOOM := GameSettings.DEFAULT_ZOOM
## Lăn chuột chỉnh zoom: mỗi nấc nhân/chia ZOOM_STEP, giới hạn ZOOM_MIN..ZOOM_MAX, camera trượt mượt tới mức mới.
const ZOOM_MIN := GameSettings.ZOOM_MIN
const ZOOM_MAX := GameSettings.ZOOM_MAX
const ZOOM_STEP := 1.1
const ZOOM_SMOOTHING := 12.0
const HealthBarScene := preload("res://ui/HealthBar.tscn")
## Thanh máu trên đầu: nằm ngay dưới tên (tên cao 20px), rộng gấp HP_BAR_WIDTH_SCALE thanh quái.
const NAME_LABEL_HEIGHT := 20.0
const HP_BAR_TOP_OFFSET := 16.0   ## khoảng từ đáy nhãn tên tới gốc HealthBar (thanh vẽ từ y-13 -> cách tên 3px)
const HP_BAR_WIDTH_SCALE := 1.4
const HP_BAR_HEIGHT := 4.0          ## thanh quái cao 6px; thanh trên đầu người chơi mảnh hơn

## NHẢY — công thức KNpc::NewJump/DoJump/ServerJump gốc (frame = 1/18 giây): bay thẳng theo hướng với 12 đơn vị/frame,
## độ cao h = (v0*t - g*t²/2)/8, g = 10, v0 = g*(số frame-1)/2 (đỉnh ở giữa quãng). Tối đa 40 frame (m_CurrentJumpFrame).
## Chuẩn VLTK: quãng tối đa 40 frame = 480 pixel. Có điểm đến (click chuột) thì nhảy tới điểm đó (tối đa 480px).
const VLTK_FPS := 18.0
const JUMP_SPEED := 12.0 * VLTK_FPS
const JUMP_GRAVITY := 10.0
const JUMP_MAX_FRAMES := 40
const JUMP_DEFAULT_FRAMES := 40
## Đổi ngựa phải chờ (MAX_SWITCH_HORSE_FIGHT_NONE = 36 frame gốc).
const HORSE_SWITCH_COOLDOWN := 36.0 / VLTK_FPS
## Đi theo (KPlayerAI m_bFollowPeople): cách mục tiêu quá bán kính này mới chạy tới.
const FOLLOW_RADIUS := 70.0
const FOLLOW_SEARCH_RANGE := 1000.0
## NGỒI (KNpc::DoSit/OnSit): diễn động tác 1 lần rồi giữ frame cuối; mỗi GAME_UPDATE_TIME = 10 frame hồi 0,3% máu tối đa
## (m_CurrentLifeMax * 3 / 1000, tối thiểu 1). Không ngồi được khi cưỡi ngựa; bị đánh/di chuyển/ra đòn thì đứng dậy.
const SIT_TICK := 10.0 / VLTK_FPS
const SIT_HEAL_PER_MILLE := 3

@export var max_health: float = 100.0
@export var base_range: float = 150.0

## Máu hiện tại — mọi thay đổi (trúng đòn, độc, hồi máu, đổi chỉ số) phát health_changed cho HUD.
signal health_changed(health: float, max_health: float)
var health: float:
	set(value):
		health = value
		health_changed.emit(health, max_health)

signal mana_changed(mana: float, max_mana: float)
var max_mana: float = 100.0
var mana: float = 100.0:
	set(value):
		if GmManager and GmManager.is_god_mode:
			mana = maxf(max_mana, 1.0)
			mana_changed.emit(mana, max_mana)
			return
		mana = clampf(value, 0.0, maxf(max_mana, 1.0))
		mana_changed.emit(mana, max_mana)
var last_direction: Vector2 = Vector2.RIGHT
var is_invincible: bool = false
var has_moved: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var profile: PlayerProfile:
	get:
		return GameManager.local_profile
	set(value):
		GameManager.local_profile = value

## Snapshot số liệu combat CHÍNH XÁC 100% VLTK (AttackRating/Defense/Damage/Kháng theo Ngũ Hành) —
## dựng từ PlayerProfile lúc _ready(), xem CombatantStats + CombatFormulas (systems/combat/).
var combat_stats: CombatantStats
## true = tự động thi triển skill khả dụng vào kẻ địch gần nhất; false = chờ người chơi bấm phím.
var is_auto_mode: bool = false
## Phe hiện tại (Camp.Type) = MÀU TÊN — đồng đội là người CÙNG MÀU (CombatTargeting). Lấy từ
## PlayerProfile.get_current_camp(); đổi qua set_camp() để tên đổi màu theo.
var camp: int = Camp.Type.BEGIN
## Bật PK: mới đánh/bùa được người chơi KHÁC màu (phe Sát thủ luôn đánh được).
var pk_enabled: bool = false
var _name_label: Label
var _guild_tag: GuildTag
var _guild_svc: GuildService
var _match_level_tag: String = ""
var _match_side: String = ""
var _zoom_target: float = CAMERA_ZOOM
var _head_hp_bar: Node2D

## Bấm/chạm 1 điểm trên bản đồ -> chạy tới đó (giống VLTK). Giữ chuột/ngón tay -> chạy theo con trỏ.
## Bàn phím/joystick luôn ưu tiên và hủy điểm đến. Chỉ nhận cú bấm GUI không ăn (_unhandled_input),
## nên bấm lên nút/khung/joystick không làm nhân vật chạy.
const MOVE_ARRIVE_DISTANCE := 6.0
const PATH_WAYPOINT_RADIUS := 14.0   ## điểm trung gian của lộ trình: tới gần chừng này là sang điểm kế (cắt góc mượt)
## Kẹt vật cản (đi không tới) quá lâu thì bỏ điểm đến, không giậm chân tại chỗ mãi.
const MOVE_STUCK_TIMEOUT := 0.4
var _move_target: Vector2
var _has_move_target: bool = false
var _move_follow_held: bool = false
var _move_stuck_time: float = 0.0
var _move_marker: Node2D

@onready var range_indicator := $RangeIndicator
## Nhân vật ghép bộ phận kiểu VLTK (mũ/áo/vũ khí đổi hình theo trang bị, 8 hướng) — xem CharacterAvatar.
@onready var avatar: CharacterAvatar = $Avatar
@onready var aura: AnimatedSprite2D = $Aura
@onready var status_controller: StatusEffectController = $StatusEffectController
@onready var skill_controller: SectSkillController = $SectSkillController

var is_attacking: bool = false
var is_casting: bool = false

var _is_jumping: bool = false
var _jump_time: float = 0.0     ## giây đã bay
var _jump_frames: int = 0       ## tổng frame của cú nhảy này
var _jump_dir: Vector2 = Vector2.DOWN
var _air_height: float = 0.0    ## độ cao hiện tại (pixel)
var _last_safe_pos: Vector2 = Vector2.ZERO  ## điểm an toàn cuối trên mặt đất (nSuccessStep gốc)
var _is_sitting: bool = false
var _sit_time: float = 0.0
var _horse_ready_at_ms: int = 0
## Người/NPC đang đi theo (nhóm "followable") — null = không theo ai.
var follow_target: Node2D = null
## Bộ máy Auto đánh (Thiết lập auto đánh) — chạy khi is_auto_mode bật, xem AutoController.
var auto: AutoController

func reset_has_moved() -> void:
	has_moved = false
	spawn_position = global_position

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reset_has_moved()
	var profile := GameManager.local_profile
	if profile == null:
		profile = SaveManager.load_profile()
		if profile == null:
			profile = PlayerProfile.new()
			profile.display_name = "Đại Hiệp"
			profile.level = 10
			profile.sect_id = "vo_dang"
		GameManager.local_profile = profile

	combat_stats = profile.get_combat_stats() if profile else CombatantStats.new()
	if profile and combat_stats != null and combat_stats.max_hp > 0:
		max_health = float(combat_stats.max_hp)
		max_mana = float(combat_stats.max_mana)
	else:
		max_health = 1200.0
		max_mana = 600.0
	health = max_health
	mana = max_mana
	range_indicator.set_radius(get_current_range())
	avatar.action_finished.connect(_on_avatar_action_finished)
	## Aura có sprite_frames gán sẵn trong scene nhưng KHÔNG autoplay — không có dòng này, nó
	## đứng yên tại đúng frame được lưu lúc chỉnh trong Editor, không bao giờ tự động chạy.
	aura.play("default")
	aura.visible = false
	_zoom_target = GameSettings.camera_zoom()
	$Camera2D.zoom = Vector2.ONE * _zoom_target
	## Vòng hào quang dưới chân luôn căn đúng CHÂN avatar (không phụ thuộc số đặt tay trong scene): tâm vòng = chân + 1px.
	aura.position = avatar.position + Vector2(0, 1)

	var sect := SectRegistry.get_by_id(profile.sect_id) if profile else null
	skill_controller.setup(sect)
	skill_controller.skill_cast.connect(_on_skill_cast_for_range)
	skill_controller.skill_cast.connect(_on_skill_cast_abrade)
	for i in PlayerProfile.LOOP_SLOT_COUNT:
		if i < skill_controller.loop_enabled.size() and skill_controller.loop_enabled[i]:
			var s := skill_controller.get_loop_skill(i)
			if s and s.is_aura and profile:
				profile.active_aura_id = s.id
				break
	## Buff/bùa thêm hoặc hết hạn -> dựng lại chỉ số (CombatantStats.build gồm trạng thái đang dính).
	status_controller.stats_changed.connect(refresh_combat_stats)
	status_controller.state_expired.connect(_on_state_expired)
	## Trang bị thay đổi (mặc/tháo đồ từ F3/F4) -> dựng lại chỉ số & đổi ngoại hình ngay lập tức trong trận
	if profile and profile.has_signal("equipment_changed"):
		if not profile.equipment_changed.is_connected(_on_profile_equipment_changed):
			profile.equipment_changed.connect(_on_profile_equipment_changed)
	_build_name_label(profile.display_name if profile else "")
	_build_head_health_bar()
	if profile != null:
		_guild_svc = SocialHub.of(profile).guild
		if _guild_svc != null and not _guild_svc.changed.is_connected(refresh_guild_tag):
			_guild_svc.changed.connect(refresh_guild_tag)
	if NetClient != null and not NetClient.connected_to_world.is_connected(_on_net_connected_for_name):
		NetClient.connected_to_world.connect(_on_net_connected_for_name)
	PotionEffect.restore_profile_states(profile, self)
	refresh_appearance()
	set_camp(get_effective_camp())
	_build_move_marker()
	add_child(RouteDots.new(self))
	auto = AutoController.new(self)
	add_child(auto)
	_refresh_aura_sprite()
	PlayerStats.stats_reset.connect(_on_stats_reset)
	if GameManager:
		if not GameManager.stage_started.is_connected(_on_stage_started):
			GameManager.stage_started.connect(_on_stage_started)
		if not GameManager.stage_completed.is_connected(_on_stage_completed):
			GameManager.stage_completed.connect(_on_stage_completed)
		_apply_stage_settings(GameManager.current_stage)
	if GameModeManager.is_offline() and (GameManager.game_mode == GameManager.GameMode.STAGE or GameManager.field_map.get("survivor_mode", false)):
		var agent_script = load("res://systems/survivor/survivor_combat_agent.gd")
		if agent_script and not has_node("SurvivorCombatAgent"):
			var agent = agent_script.new()
			agent.name = "SurvivorCombatAgent"
			add_child(agent)

func _on_stats_reset() -> void:
	if range_indicator:
		range_indicator.set_radius(get_current_range())

## Đổi phe (màu tên) — VD vào sự kiện/bang chiến, bật PK thành Sát thủ. Đồng đội tính lại tự động vì
## CombatTargeting đọc `camp` mỗi lần quét.
func set_camp(new_camp: int) -> void:
	camp = new_camp
	if _name_label and _match_side == "":
		_name_label.add_theme_color_override("font_color", Camp.get_color(camp))

## Vừa gia nhập môn phái (SectPrompt): nạp skill của phái mới + dựng lại chỉ số + phe (màu tên).
func refresh_sect() -> void:
	var profile := GameManager.local_profile
	skill_controller.setup(SectRegistry.get_by_id(profile.sect_id) if profile else null)
	refresh_combat_stats()
	set_camp(get_effective_camp())

## Tên nhân vật trên đầu, tô màu theo phe (giống VLTK) — đặt ngay trên thanh máu.
## Độ cao nhãn tên hiện tại (đổi khi cưỡi ngựa / nhảy) — ChatBubble hiện lời nói ngay trên đó.
func chat_anchor_y() -> float:
	return _name_label.position.y if _name_label else NAME_LABEL_Y

## ChatBubble đang hiện lời nói thay chỗ tên -> ẩn nhãn tên gốc (và dòng bang hội để tránh đè chữ).
func set_name_label_visible(on: bool) -> void:
	if _name_label:
		_name_label.visible = on
	if _guild_tag:
		_guild_tag.set_suppressed(not on)

func _build_name_label(display_name: String) -> void:
	if _name_label == null:
		_name_label = Label.new()
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var f := GameUi.game_font_bold() if GameUi else null
		if f != null:
			_name_label.add_theme_font_override("font", f)
		_name_label.add_theme_font_size_override("font_size", 13)
		_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
		_name_label.add_theme_constant_override("outline_size", 4)
		_name_label.z_index = 12
		add_child(_name_label)
	_name_label.text = display_name
	_name_label.size = Vector2(240, NAME_LABEL_HEIGHT)
	_name_label.position = Vector2(-120, NAME_LABEL_Y)
	if _guild_tag == null:
		_guild_tag = GuildTag.new()
		add_child(_guild_tag)
	if _stall_sign == null:
		_stall_sign = StallSign.new()
		_stall_sign.z_index = 12
		_stall_sign.clicked.connect(func() -> void:
			var prof := GameManager.local_profile
			if prof == null:
				return
			if prof.trade_open:
				StallService.close_trade(prof)
				if NetClient.is_in_world():
					NetClient.send_stall(SocialServer.TRADE_CLOSE)
				SaveManager.save_profile(prof)
				notify("Đã tắt mở giao dịch."))
		add_child(_stall_sign)
	refresh_guild_tag()

func _on_net_connected_for_name(_eid: int, _feet: Vector2, my_name: String) -> void:
	var profile := GameManager.local_profile
	if profile != null and profile.display_name.strip_edges() == "" and my_name.strip_edges() != "":
		profile.display_name = my_name
	refresh_nameplate()

func refresh_guild_tag() -> void:
	if _guild_tag == null:
		return
	var profile := GameManager.local_profile if GameManager else null
	if profile != null and profile.guild is Dictionary and not profile.guild.is_empty():
		var gname := str(profile.guild.get("name", ""))
		var emblem := GuildEmblem.resolve_id(profile.guild)
		_guild_tag.set_guild(gname, emblem)
	else:
		_guild_tag.set_guild("", 0)
	_apply_name_y()

func refresh_nameplate() -> void:
	var profile := GameManager.local_profile if GameManager else null
	if profile != null and _name_label != null:
		var look: Dictionary = profile.get_equipped_look() if profile.has_method("get_equipped_look") else Equipment.get_appearance(profile.equipment, "female" if profile.gender == PlayerProfile.Gender.FEMALE else "male", profile.riding)
		_update_name_label_disguise(look)
	refresh_guild_tag()

## BÀY BÁN (StallService): Tính năng mở sạp hàng ngoài thành đã chuyển sang Chợ Giao Thương.
var _stall_sign: StallSign
var _stall_was_open := false

func _tick_stall() -> void:
	var p := GameManager.local_profile
	if p != null and p.stall_open:
		p.stall_open = false
	if p != null and p.trade_open and not _dead:
		_stall_sign.set_title("Mở giao dịch")
	else:
		_stall_sign.set_title("")

func _close_stall(p: PlayerProfile, why: String) -> void:
	StallService.close_stall(p)
	if NetClient.is_in_world():
		NetClient.send_stall(SocialServer.STALL_CLOSE)
	_notice(why)

## Dựng lại combat_stats từ profile — gọi sau khi học/nâng skill nội tại hoặc cộng điểm GIỮA trận
## (VD đóng bảng Kỹ Năng Võ Công) để bonus mới có hiệu lực ngay. Giữ nguyên % máu hiện tại.
func refresh_combat_stats() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	var health_ratio := health / max_health if max_health > 0.0 else 1.0
	var mana_ratio := mana / max_mana if max_mana > 0.0 else 1.0
	combat_stats = profile.get_combat_stats(status_controller.get_state_attrib_sources())
	max_health = float(combat_stats.max_hp)
	max_mana = float(combat_stats.max_mana)
	health = max_health * health_ratio
	mana = max_mana * mana_ratio
	refresh_appearance()
	_refresh_aura_sprite()  ## bật/tắt hào quang đều đi qua đây (SectSkillController._toggle_aura)

func _on_profile_equipment_changed() -> void:
	refresh_combat_stats()

func _exit_tree() -> void:
	PlayerStealth.local_is_hidden = false
	var profile := GameManager.local_profile if GameManager else null
	if profile and profile.has_signal("equipment_changed"):
		if profile.equipment_changed.is_connected(_on_profile_equipment_changed):
			profile.equipment_changed.disconnect(_on_profile_equipment_changed)
	if _guild_svc != null and _guild_svc.changed.is_connected(refresh_guild_tag):
		_guild_svc.changed.disconnect(refresh_guild_tag)
	if NetClient != null and NetClient.connected_to_world.is_connected(_on_net_connected_for_name):
		NetClient.connected_to_world.disconnect(_on_net_connected_for_name)

## Mặc/tháo mũ, áo, vũ khí -> đổi hình nhân vật ngay (gọi kèm refresh_combat_stats sau mỗi lần đổi trang bị).
## Mới có bộ hình nam — nhân vật nữ tạm dùng hình nam cho tới khi nhập bộ nữ.
func refresh_appearance() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	var gender_key := "female" if profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look: Dictionary = profile.get_equipped_look() if profile.has_method("get_equipped_look") else Equipment.get_appearance(profile.equipment, gender_key, profile.riding)
	var final_gender: String = str(look.get("gender", gender_key))
	if avatar != null:
		avatar.voice_gender = final_gender
		avatar.set_gender(final_gender)
		if look["helm"] != avatar.helm_res or look["armor"] != avatar.armor_res or look["weapon"] != avatar.weapon_res \
				or look["horse"] != avatar.horse_res:
			avatar.set_appearance(look["helm"], look["armor"], look["weapon"], look["horse"])
		if look.has("modulate"):
			avatar.modulate = look["modulate"]
		else:
			avatar.modulate = Color.WHITE

	_update_name_label_disguise(look)

func get_current_look() -> Dictionary:
	var profile := GameManager.local_profile
	if profile == null:
		return {}
	var gender_key := "female" if profile.gender == PlayerProfile.Gender.FEMALE else "male"
	var look: Dictionary = profile.get_equipped_look() if profile.has_method("get_equipped_look") else Equipment.get_appearance(profile.equipment, gender_key, profile.riding)
	var final_look := look.duplicate()
	var final_gender: String = str(look.get("gender", gender_key))
	final_look["gender"] = 1 if final_gender == "female" else 0
	final_look["mask_particular"] = int(look.get("mask_particular", -1))
	## 2 lớp hình: hào quang SKILL (máy khác tự suy từ aura_skill bên dưới) + lớp hào quang KHÁC (GM / hộ thể tân thủ) = aura_state.
	var cur_auras := _aura_sprites.keys()
	final_look["aura_state"] = _extra_aura_state
	## Hào quang đang bật (số skill + cấp thật) — máy đồng đội cùng phe đứng gần tự nhận chỉ số hào quang hỗ trợ.
	final_look["aura_skill"] = 0
	final_look["aura_level"] = 0
	if profile.active_aura_id != "" and skill_controller != null:
		var aura_skill: SkillDefinition = skill_controller._find_skill(profile.active_aura_id)
		if aura_skill != null and aura_skill.is_aura and aura_skill.vltk_skill_id > 0:
			final_look["aura_skill"] = aura_skill.vltk_skill_id
			final_look["aura_level"] = skill_controller._learned_level(aura_skill)
	## Hình buff/bùa đang dính (đã có hình trong dữ liệu) — gửi cho người khác thấy; hào quang đi riêng qua aura_state.
	var states := []
	if status_controller:
		for st in status_controller.get_state_display_list():
			var sid := int(st["meta"].get("state_id", 0))
			if sid > 0 and not cur_auras.has(sid) and sid != _extra_aura_state and not states.has(sid) and not VltkSkillData.state(sid).is_empty():
				states.append(sid)
	## Đang bị Băng sát -> máy người khác nhuộm vàng nhân vật mình (mã riêng, không phải hình trạng thái).
	if status_controller and status_controller.has_effect("freeze"):
		states.append(NetProto.MSTATE_FREEZE)
	final_look["states"] = NetProto.sanitize_states(states)
	return final_look

func set_match_level_tag(lvl: int, side: String = "") -> void:
	if lvl > 0:
		_match_level_tag = "[Cấp %d] " % lvl
	else:
		_match_level_tag = ""
		_match_side = ""
	if side != "":
		_match_side = side
	var profile := GameManager.local_profile
	if profile and _name_label:
		var look: Dictionary = profile.get_equipped_look() if profile.has_method("get_equipped_look") else Equipment.get_appearance(profile.equipment, "female" if profile.gender == PlayerProfile.Gender.FEMALE else "male", profile.riding)
		_update_name_label_disguise(look)

func _update_name_label_disguise(look: Dictionary) -> void:
	var profile := GameManager.local_profile
	if _name_label == null or profile == null:
		return
	if look.get("is_masked", false):
		var d_title: String = str(look.get("disguise_title", "Dịch Dung"))
		_name_label.text = "🎭 [%s]\n%s%s" % [d_title, _match_level_tag, profile.display_name]
		_name_label.size = Vector2(240, 36)
		_name_label.position.x = -120
		var m_color: Color = look.get("modulate", Color(1.0, 0.85, 0.4))
		_name_label.add_theme_color_override("font_color", m_color)
	else:
		_name_label.text = "%s%s" % [_match_level_tag, profile.display_name]
		_name_label.size = Vector2(240, NAME_LABEL_HEIGHT)
		_name_label.position.x = -120
		if _match_side != "":
			var side_col := Color(0.2, 0.6, 1.0) if _match_side == "song" else Color(1.0, 0.35, 0.2)
			_name_label.add_theme_color_override("font_color", side_col)
		else:
			_name_label.add_theme_color_override("font_color", Camp.get_color(camp))
	refresh_guild_tag()

## Đổi màu tên và tiền tố phe (VD đấu trường Thách Đấu / Lộn Xộn: [Phe Xanh], [Phe Đỏ]).
func set_name_color(col: Color, prefix: String = "") -> void:
	if _name_label:
		_name_label.add_theme_color_override("font_color", col)
		var p_name := GameManager.local_profile.display_name if GameManager.local_profile else ""
		if prefix != "":
			_name_label.text = "%s %s%s" % [prefix, _match_level_tag, p_name]
		else:
			_name_label.text = "%s%s" % [_match_level_tag, p_name]

## Trả lại màu tên mặc định theo phe/bang/sự kiện
func reset_name_color() -> void:
	if _name_label:
		var p_name := GameManager.local_profile.display_name if GameManager.local_profile else ""
		_name_label.text = "%s%s" % [_match_level_tag, p_name]
		if _match_side != "":
			var side_col := Color(0.2, 0.6, 1.0) if _match_side == "song" else Color(1.0, 0.35, 0.2)
			_name_label.add_theme_color_override("font_color", side_col)
		else:
			_name_label.add_theme_color_override("font_color", Camp.get_color(camp))

## Phe hiệu lực: theo đội trưởng nếu đang trong tổ đội (VLTK gốc: SetTempCurrentCamp), trừ khi đang bật PK Đồ sát / Bang chiến.
func get_effective_camp() -> int:
	if pk_mode == 2:
		return Camp.Type.FREE
	if pk_mode == 3:
		return Camp.Type.TONGWAR
	var p := GameManager.local_profile
	if p:
		var team := SocialHub.of(p).team
		if team and team.in_team() and team.captain != null:
			return team.captain.camp
		return p.get_current_camp()
	return camp

## Cập nhật lại phe và màu tên (vào/rời tổ đội, đổi đội trưởng, đổi phái...)
func refresh_name_color() -> void:
	var cur_camp := get_effective_camp()
	set_camp(cur_camp)
	reset_name_color()

## Thanh máu trên đầu, dưới tên — chạy theo signal health_changed (cùng nguồn với HUD góc trái).
func _build_head_health_bar() -> void:
	_head_hp_bar = HealthBarScene.instantiate()
	_head_hp_bar.z_index = 11
	_head_hp_bar.use_gradient_color = true  ## xanh -> vàng -> đỏ theo % máu
	_head_hp_bar.bar_width = 40.0 * HP_BAR_WIDTH_SCALE   ## rộng bằng thanh cũ (40px x 1.4) nhưng không kéo giãn -> đầu bo tròn không méo
	_head_hp_bar.bar_height = HP_BAR_HEIGHT
	_head_hp_bar.rounded = true
	add_child(_head_hp_bar)
	health_changed.connect(_on_health_changed_head_bar)
	_on_health_changed_head_bar(health, max_health)
	_apply_pk_hp_bar_color()
	_apply_name_y()

func _on_health_changed_head_bar(current: float, maximum: float) -> void:
	if _head_hp_bar == null:
		return
	_head_hp_bar.set_max_health(maxf(maximum, 1.0))
	_head_hp_bar.set_health(maxf(current, 0.0))

## Tên đi theo đầu: cao thêm khi cưỡi ngựa (nhảy thì xuống ngựa tạm) và khi đang bay lên.
func _apply_name_y() -> void:
	if _name_label == null:
		return
	var raise := RIDE_HEAD_RAISE if avatar != null and avatar.is_riding() and not _is_jumping else 0.0
	var label_h := _name_label.size.y
	_name_label.position.y = NAME_LABEL_Y - (label_h - NAME_LABEL_HEIGHT) - raise - (_air_height if _is_jumping else 0.0)
	if _guild_tag != null:
		_guild_tag.place_above(_name_label.position.y)
	if _stall_sign != null:
		var top_y := _guild_tag.top_y() if (_guild_tag != null and _guild_tag.has_guild()) else _name_label.position.y
		_stall_sign.place_above(top_y)
	if _head_hp_bar != null:
		_head_hp_bar.position = Vector2(0.0, _name_label.position.y + label_h + HP_BAR_TOP_OFFSET)

# ------------------------------------------------------------ bấm để chạy tới

## Đang gõ vào ô nhập (chat, đặt tên...) thì phím không điều khiển nhân vật (không chạy / nhảy / ra chiêu khi gõ chữ).
## Đặt mức zoom camera (camera trượt mượt tới) và lưu vào cài đặt máy — lăn chuột và thanh trượt trong Cài đặt đều qua đây.
## Hệ số tầm nhìn của chế độ chơi (Lộn Xộn: Lệnh Bài) — > 1 thì camera thu nhỏ bản đồ (thấy rộng hơn). Không lưu vào cài đặt.
var view_mult := 1.0
## Hệ số tầm đánh skill của chế độ chơi (Lộn Xộn: Lệnh Bài) — riêng từng nhân vật, không dùng PlayerStats chung.
var skill_radius_mult := 1.0

func set_camera_zoom(z: float) -> void:
	_zoom_target = clampf(z, ZOOM_MIN, ZOOM_MAX)
	GameSettings.set_camera_zoom(_zoom_target)

func get_camera_zoom() -> float:
	return _zoom_target

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

func _key_pressed(action: StringName) -> bool:
	return not _typing() and Input.is_action_just_pressed(action)

func _key_vector(neg_x: StringName, pos_x: StringName, neg_y: StringName, pos_y: StringName) -> Vector2:
	return Vector2.ZERO if _typing() else Input.get_vector(neg_x, pos_x, neg_y, pos_y)

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	## Lăn chuột = zoom camera (khi con trỏ đang ở trên khung giao diện cuộn được thì khung đó ăn sự kiện, không tới đây).
	## Đang mở popup/khung nào thì KHÔNG zoom (lăn chuột là để cuộn khung); tắt "lăn chuột zoom" trong Cài đặt cũng không zoom.
	if event is InputEventMouseButton and event.pressed 			and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if GameSettings.wheel_zoom() and not UiPopups.any_open(get_tree()):
			var step := ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
			set_camera_zoom(_zoom_target * step)
			get_viewport().set_input_as_handled()
		return
	## Chuột phải (PC/Web): giữ = thi triển skill nút chính về phía con trỏ (SkillBarUI đọc cờ này mỗi khung hình).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		## Chỉ BẬT ở đây; SkillBarUI tắt khi thấy đã nhả (để nhấp nhanh vẫn đánh được 1 phát).
		if event.pressed:
			right_cast_held = true
			auto.on_manual_input()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			## Bấm trúng Tiêu Xa = tự động theo sau bảo vệ tiêu xa
			var cart := _pick_escort_cart_at(World3DView.mouse_world(self))
			if cart != null:
				start_follow(cart)
				get_viewport().set_input_as_handled()
				return
			## Bản web, Shift + bấm trái = ra skill chuột trái tại con trỏ (gốc Shift+LButton -> Mouse_Force0).
			if WebHudBar.enabled() and event.shift_pressed:
				cast_left_skill_at(World3DView.mouse_world(self))
				get_viewport().set_input_as_handled()
				return
			## Bấm trúng quái / người chơi khác = CHỌN làm mục tiêu đánh (hiện vòng đỏ xoay dưới chân), không chạy tới điểm bấm.
			var picked := pick_target_at(World3DView.mouse_world(self))
			if picked != null:
				set_target(picked, true)
				## Bản web: bấm trái vào quái = đuổi theo và đánh LIÊN TỤC bằng skill chuột trái (ô T) — gốc Npc::m_nPeopleIdx.
				if WebHudBar.enabled() and picked.is_in_group("enemies"):
					start_left_attack(picked)
				## Bấm vào người chơi khác: hiện menu (Tán gẫu / Hảo hữu / Tổ đội / Theo sau / Tin tức / Cừu sát / Sổ đen).
				if picked is RemotePlayer:
					PlayerMenu.open(self, picked as RemotePlayer, get_viewport().get_mouse_position())
				get_viewport().set_input_as_handled()
				return
			## Bấm 1 lần = TỰ TÌM ĐƯỜNG vòng vật cản (có map chính); giữ chuột quá HOLD_FOLLOW_TIME thì bám theo con trỏ.
			auto.on_manual_input()
			_clear_chase_main()
			if GmManager and GmManager.is_noclip:
				_set_move_target(World3DView.mouse_world(self))
			else:
				var feet := World3DView.mouse_world(self) + Vector2(0, VltkWorld.FEET_OFFSET)
				if VltkWorld.current == null or not walk_to_feet(feet):
					_set_move_target(World3DView.mouse_world(self))
			_show_route = false  ## bấm chuột trên map chính: không vẽ đường chấm (chỉ mini map / nhập toạ độ mới có)
			_move_follow_held = false
			_mouse_hold_time = 0.0
			_mouse_holding = true
		else:
			_move_follow_held = false
			_mouse_holding = false

# ------------------------------------------------------------ chọn mục tiêu

## Nhóm node có thể bị chọn làm mục tiêu: quái và người chơi khác (online: node của người chơi khác vào nhóm "other_players").
const TARGET_GROUPS := ["enemies", "other_players"]
const TARGET_CLICK_HALF_WIDTH := 36.0
const TARGET_DEFAULT_HEIGHT := 60.0
const TARGET_LOSE_RADIUS := 1200.0   ## xa hơn mức này (theo chuẩn logic dọc nhân đôi) thì bỏ mục tiêu
var selected_target: Node2D = null
## true = mục tiêu do NGƯỜI CHƠI bấm chọn; false = tự chọn theo chiêu vừa đánh trúng (mark_cast_target). Auto chỉ ưu tiên tuyệt đối
## mục tiêu người chơi bấm — không thì đòn đầu tiên của chính Auto khoá cứng mục tiêu, bỏ qua thiết lập ưu tiên Boss / ít máu.
var target_by_player := false
var _target_ring: TargetRing

## Mục tiêu dưới điểm bấm `world_pos` (toạ độ thế giới); gần nhất tính tới giữa thân. null = bấm vào chỗ trống.
func pick_target_at(world_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for group in TARGET_GROUPS:
		for n in get_tree().get_nodes_in_group(group):
			var node := n as Node2D
			if node == null or node == self or not _is_valid_target(node):
				continue
			var h: float = node.call("get_body_height") if node.has_method("get_body_height") else TARGET_DEFAULT_HEIGHT
			var center := node.global_position + Vector2(0.0, -h * 0.5)
			var dx := absf(world_pos.x - center.x)
			var dy := absf(world_pos.y - center.y)
			if dx > TARGET_CLICK_HALF_WIDTH or dy > h * 0.5 + 12.0:
				continue
			var d := dx * dx + dy * dy
			if d < best_d:
				best_d = d
				best = node
	return best

func _is_valid_target(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return false
	var n := node as Node2D
	if n.is_queued_for_deletion() or not n.is_inside_tree():
		return false
	if n.has_method("is_dead") and n.call("is_dead"):
		return false
	if "dead" in n and bool(n.get("dead")):
		return false
	if "is_dying" in n and bool(n.get("is_dying")):
		return false
	if "health" in n and float(n.get("health")) <= 0.0:
		return false
	if "current_health" in n and float(n.get("current_health")) <= 0.0:
	## Người đang ẩn thân không chọn được (KPlayer::FindSelectNpc gốc bỏ m_HideState.nTime > 0).
	if n != self and PlayerStealth.is_hidden(n):
		return false
	var my_side: String = ""
	if "battle_side" in self and str(get("battle_side")) != "":
		my_side = str(get("battle_side"))
	elif TongKimLolState.current != null:
		my_side = TongKimLolState.current.team_side
	if my_side != "" and "battle_side" in n:
		var target_side: String = str(n.get("battle_side"))
		if target_side != "" and target_side == my_side:
			return false
	return true

func set_target(node: Variant, by_player := false) -> void:
	if node != null and (not is_instance_valid(node) or not (node is Node2D)):
		node = null
	if node == selected_target:
		if by_player:
			target_by_player = true
		return
	target_by_player = by_player
	_clear_ring()
	selected_target = node as Node2D
	if selected_target == null:
		return
	if by_player and _chase_main_target != null and _chase_main_target != selected_target:
		var main_skill := skill_controller.get_main_skill() if skill_controller else null
		_start_chase_main(selected_target, main_skill)
	_target_ring = TargetRing.new()
	selected_target.add_child(_target_ring)
	## Vòng nằm ở CHÂN (trùng aura): người chơi khác / bot PK có gốc node ở thân, chân lệch xuống FEET_OFFSET.
	if selected_target.has_method("get_ground_position"):
		_target_ring.position = selected_target.to_local(selected_target.get_ground_position())

## Skill vừa ra chiêu vào `node`: nếu là quái/người chơi khác thật (không phải điểm ngắm ảo) thì chọn làm mục tiêu.
func mark_cast_target(node: Variant) -> void:
	if node != null and is_instance_valid(node) and (node is Node2D) and node != self and _is_valid_target(node) and ((node as Node2D).is_in_group("enemies") or (node as Node2D).is_in_group("other_players")):
		set_target(node)

func clear_target() -> void:
	set_target(null)

func _clear_ring() -> void:
	if _target_ring != null and is_instance_valid(_target_ring):
		_target_ring.queue_free()
	_target_ring = null

## Mục tiêu NGƯỜI CHƠI tự bấm chọn (còn hợp lệ); null nếu không có hoặc chỉ là mục tiêu tự chọn theo chiêu đánh trúng.
func get_player_chosen_target() -> Node2D:
	var t := get_selected_target()
	return t if t != null and target_by_player else null

## Mục tiêu đang chọn nếu còn hợp lệ (còn sống, chưa quá xa); không thì tự bỏ chọn và trả null.
func get_selected_target() -> Node2D:
	if selected_target == null:
		return null
	if not _is_valid_target(selected_target):
		clear_target()
		return null
	var d: Vector2 = selected_target.global_position - global_position
	if d.x * d.x + d.y * d.y * 4.0 > TARGET_LOSE_RADIUS * TARGET_LOSE_RADIUS:
		clear_target()
		return null
	return selected_target

## Chạy tới 1 điểm theo TOẠ ĐỘ MÀN HÌNH (VD cú chạm trong vùng joystick — MoveJoystick.tapped).
func move_to_screen_position(screen_position: Vector2) -> void:
	auto.on_manual_input()
	_clear_chase_main()
	var world := World3DView.screen_to_world(screen_position, get_viewport())
	## Chạm 1 lần = tự tìm đường vòng vật cản như bấm chuột (GM noclip: đi thẳng).
	if GmManager and GmManager.is_noclip:
		_set_move_target(world)
	elif VltkWorld.current == null or not walk_to_feet(world + Vector2(0, VltkWorld.FEET_OFFSET)):
		_set_move_target(world)
	_show_route = false

func _set_move_target(world_position: Vector2, keep_path: bool = false) -> void:
	if not keep_path:
		_show_route = false
		_path.clear()  ## bấm điểm mới / kéo chuột -> bỏ lộ trình tự đi cũ
		_route_goal = Vector2.INF
		_route_continue = false
		_route_ahead = PackedVector2Array()
	_move_target = world_position
	_has_move_target = true
	_move_stuck_time = 0.0
	_move_marker.global_position = world_position
	_move_marker.visible = true

## Lộ trình tự đi (walk_to_feet): các điểm TÂM thân còn phải đi qua, đích cuối là phần tử cuối.
var _mouse_holding := false
var _mouse_hold_time := 0.0
const HOLD_FOLLOW_TIME := 0.25
var _path: PackedVector2Array = PackedVector2Array()
var _show_route := false   ## true = lộ trình do mini map/nhập toạ độ đặt -> màn chính vẽ đường chấm
var _path_final := Vector2.ZERO

## Tự đi tới điểm CHÂN `feet` (toạ độ pixel map) theo đường vòng vật cản trong ô vuông màn chơi (A*). false = không có đường.
## Dùng cho mini map (nhập toạ độ / bấm lên bản đồ). Người chơi kéo joystick/bấm điểm khác thì lộ trình huỷ.
func walk_to_feet(feet: Vector2, _replan := false) -> bool:
	if GmManager and GmManager.is_noclip:
		_path.clear()
		_path.append(feet - Vector2(0, VltkWorld.FEET_OFFSET))
		_path_final = _path[0]
		_show_route = false
		_route_goal = feet
		_route_continue = false
		_route_ahead = PackedVector2Array()
		if not _replan:
			_route_replans = 0
		return _advance_path()
	var points := VltkWorld.find_path(global_position + Vector2(0, VltkWorld.FEET_OFFSET), feet, true)
	if points.is_empty():
		return false
	_path.clear()
	for p in points:
		_path.append(p - Vector2(0, VltkWorld.FEET_OFFSET))
	_path_final = _path[_path.size() - 1]
	var started := _advance_path()
	_show_route = started
	_route_goal = feet
	_route_continue = VltkWorld.last_path_continues
	_route_ahead = VltkWorld.last_route_ahead
	if not _replan:
		_route_replans = 0
	return started

## Đích cuối của lộ trình tự đi (điểm CHÂN), INF = không theo lộ trình (bấm thẳng / bám chuột).
var _route_goal := Vector2.INF
## Đường dài toàn map: đoạn đang đi chỉ tới mép lưới tìm đường gần -> đi hết đoạn thì tìm tiếp (_continue_route).
var _route_continue := false
var _route_ahead := PackedVector2Array()   ## phần lộ trình thô còn lại (điểm CHÂN) — chỉ để vẽ đường chấm
var _route_replans := 0
const MAX_STUCK_REPLANS := 3

## Đi hết 1 đoạn của đường dài: tìm đoạn tiếp tới cùng đích trong lưới tìm đường hiện tại (lưới tự dời theo nhân vật khi đi
## đủ xa — ép dời ở đây sẽ dựng lại lưới thêm 1 lần, gây khựng). false = hết đường / không tiến thêm.
func _continue_route() -> bool:
	if not _route_continue or _route_goal == Vector2.INF:
		return false
	return _replan_route()

## Tìm lại đường tới _route_goal từ chỗ đang đứng (giữ chế độ vẽ đường chấm). false = không có đường / không tiến thêm được.
func _replan_route() -> bool:
	var show := _show_route
	var goal := _route_goal
	if not walk_to_feet(goal, true):
		return false
	_show_route = show
	if _path_final.distance_to(global_position) < MOVE_ARRIVE_DISTANCE * 4.0 and _path.is_empty():
		return false   ## đường mới không đưa đi đâu -> dừng, tránh tìm lại mãi
	return true

## Lộ trình còn lại (điểm CHÂN): điểm đang hướng tới rồi tới các điểm sau — để bản đồ lớn vẽ đường chấm. Rỗng nếu không đang đi.
func get_route_feet() -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _has_move_target:
		return out
	out.append(_move_target + Vector2(0, VltkWorld.FEET_OFFSET))
	for p in _path:
		out.append(p + Vector2(0, VltkWorld.FEET_OFFSET))
	if _route_continue:
		out.append_array(_route_ahead)   ## đường dài: phần lộ trình thô còn lại tới đích
	return out

## Đang tự đi tới 1 điểm (bấm chuột / mini map).
## Có nên vẽ đường chấm trên màn chơi chính (chỉ khi tự đi theo mini map / toạ độ).
func should_show_route() -> bool:
	return _has_move_target and _show_route

func is_moving_to_target() -> bool:
	return _has_move_target

## Đã đi quá điểm đang hướng tới (hướng tới điểm ngược với hướng tới điểm kế) -> không cần quay lại chạm điểm.
func _passed_waypoint(to_target: Vector2) -> bool:
	if _path.is_empty():
		return false
	return to_target.dot(_path[0] - _move_target) < 0.0 and to_target.length() < 60.0

func _advance_path() -> bool:
	if _path.is_empty():
		return false
	var next_point := _path[0]
	_path.remove_at(0)
	_set_move_target(next_point, true)
	_move_marker.global_position = _path_final  ## chấm đích hiện ở điểm cuối, không nhảy theo từng điểm trung gian
	return true

## Auto bỏ lộ trình đang đi (VD quay sang đánh quái vừa thấy).
func stop_walking() -> void:
	if _has_move_target:
		_clear_move_target()

func _clear_move_target() -> void:
	_path.clear()
	_has_move_target = false
	_move_follow_held = false
	_move_marker.visible = false

## Hướng chạy tới điểm đến (Vector2.ZERO = không có / đã tới nơi).
func _get_move_target_vector(delta: float) -> Vector2:
	if not _has_move_target:
		return Vector2.ZERO
	## Đang giữ chuột: điểm đến bám theo con trỏ (nhả ở chỗ nào cũng phải dừng bám, kể cả trên UI).
	if _mouse_holding and not _move_follow_held:
		_mouse_hold_time += delta
		if _mouse_hold_time >= HOLD_FOLLOW_TIME and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_move_follow_held = true
	if _move_follow_held:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_set_move_target(World3DView.mouse_world(self))
		else:
			_move_follow_held = false
	var to_target := _move_target - global_position
	## Điểm trung gian của lộ trình: tới gần (hoặc đã bước qua) thì sang điểm kế NGAY trong cùng khung hình — không trả về
	## 0 rồi mới đi tiếp, vì 1 khung "đứng yên" ở mỗi góc làm nhân vật chớp hoạt ảnh chạy/đứng (lắc).
	while not _path.is_empty() and (to_target.length() <= PATH_WAYPOINT_RADIUS or _passed_waypoint(to_target)):
		_advance_path()
		to_target = _move_target - global_position
	if to_target.length() <= MOVE_ARRIVE_DISTANCE:
		if not _move_follow_held and not _advance_path() and not _continue_route():
			_clear_move_target()
		return Vector2.ZERO
	## Kẹt: vận tốc thực sau move_and_slide gần 0 dù đang muốn chạy.
	if not is_attacking and get_real_velocity().length() < 5.0 and not (GmManager and GmManager.is_noclip):
		_move_stuck_time += delta
		if _move_stuck_time >= MOVE_STUCK_TIMEOUT and not _move_follow_held:
			## Kẹt giữa đường (cạ góc tường, bị đẩy lệch): tìm lại đường từ chỗ đang đứng vài lần rồi mới bỏ.
			_move_stuck_time = 0.0
			if _route_goal != Vector2.INF and _route_replans < MAX_STUCK_REPLANS:
				_route_replans += 1
				if _replan_route():
					return (_move_target - global_position).normalized()
			_clear_move_target()
			return Vector2.ZERO
	else:
		_move_stuck_time = 0.0
	return to_target.normalized()

## Vòng tròn nhỏ đánh dấu điểm đến — top_level để đứng yên trên bản đồ, không chạy theo nhân vật.
func _build_move_marker() -> void:
	_move_marker = MoveTargetMarker.new()
	_move_marker.top_level = true
	_move_marker.visible = false
	_move_marker.z_index = -1
	add_child(_move_marker)

func _physics_process(delta: float) -> void:
	_tick_stall()
	_tick_stealth()
	if _dead:
		return
	var camera_zoom: float = $Camera2D.zoom.x
	var want_zoom := _zoom_target / maxf(view_mult, 0.1)
	if not is_equal_approx(camera_zoom, want_zoom):
		$Camera2D.zoom = Vector2.ONE * lerpf(camera_zoom, want_zoom, minf(1.0, ZOOM_SMOOTHING * delta))
	## Chế độ 3D đã xoay camera: "lên" là ra xa camera -> đổi sang hướng thế giới 2D.
	var input_vector := World3DView.screen_dir_to_world(_key_vector("move_left", "move_right", "move_up", "move_down"))
	if input_vector != Vector2.ZERO:
		if _has_move_target:
			_clear_move_target()
		stop_follow()
		_clear_chase_main()
		auto.on_manual_input()
	else:
		if not is_auto_mode:
			_tick_chase_main(delta)
		input_vector = _get_move_target_vector(delta)
		if input_vector == Vector2.ZERO:
			input_vector = _get_follow_vector()
		if input_vector == Vector2.ZERO:
			input_vector = auto.get_move_vector()
	## Choáng (m_StunState gốc): đứng yên, không di chuyển/ra chiêu (_try_cast cũng tự chặn).
	if _rush_time_left > 0.0:
		input_vector = _tick_rush(delta)  ## đang lao tới mục tiêu: bỏ qua phím/điểm bấm
	if status_controller.is_stunned:
		_rush_time_left = 0.0
		input_vector = Vector2.ZERO
		_move_stuck_time = 0.0
	if _is_sitting:
		if input_vector != Vector2.ZERO:
			_stand_up()
		else:
			_tick_sit(delta)
	if _is_jumping:
		_tick_jump(delta)
		input_vector = Vector2.ZERO  ## đang bay: không đổi hướng/không chạy
	if input_vector != Vector2.ZERO and not is_attacking:
		last_direction = input_vector
		update_facing(input_vector)

	## Làm chậm (Băng sát) giảm tốc độ chạy theo StatusEffectController.move_speed_multiplier.
	## fastwalkrun_p (buff tốc chạy, VD Thanh Phong phù) cộng % tốc độ gốc.
	var gm_spd: float = GmManager.speed_mult if GmManager else 1.0
	var speed := SPEED * (1.0 + combat_stats.move_speed_p / 100.0) * status_controller.move_speed_multiplier * PlayerStats.move_speed_multiplier * gm_spd
	if _is_jumping:
		velocity = _jump_dir * JUMP_SPEED
	elif _rush_time_left > 0.0 and input_vector != Vector2.ZERO:
		velocity = input_vector * SPEED * RUSH_SPEED_MULT
	else:
		velocity = Vector2.ZERO if is_attacking else input_vector * speed
		## Chạy rất nhanh (buff / chỉ số TEST): 1 khung có thể đi xa hơn quãng còn lại tới đích -> vượt qua rồi quay lại (giật).
		## Bước cuối dừng đúng tại đích.
		if _has_move_target and _path.is_empty() and not _move_follow_held and delta > 0.0:
			var remaining := (_move_target - global_position).length()
			if velocity.length() * delta > remaining:
				velocity = velocity.normalized() * (remaining / delta)
	var noclip: bool = GmManager.is_noclip if GmManager else false
	if noclip:
		global_position += velocity * delta
	else:
		velocity = VltkWorld.slide_velocity(global_position + Vector2(0, VltkWorld.FEET_OFFSET), velocity, delta, _is_jumping, false)
		move_and_slide()
	_tick_move_abrade()
	if not has_moved:
		if global_position.distance_squared_to(spawn_position) > 100.0 or velocity.length_squared() > 10.0 or is_attacking or is_casting:
			has_moved = true
	if _is_jumping and get_slide_collision_count() > 0:
		_end_jump()  ## đụng vật cản: hạ xuống tại chỗ (gốc cắt quãng nhảy trước vật cản)

	if not is_attacking and not is_casting and not _is_jumping and not _is_sitting:
		update_move_animation(input_vector)

	if _key_pressed("jump"):
		start_jump()
	if _key_pressed("toggle_horse"):
		toggle_ride()
	if _key_pressed("toggle_follow"):
		toggle_follow()
	if _key_pressed("toggle_sit"):
		toggle_sit()

	if _key_pressed("attack") and not is_attacking:
		play_attack()

	range_indicator.set_radius(_display_range())
	## Phe đổi (lên cấp 10 hết Tân thủ, vào/rời bang, vào/rời tổ đội...): đổi màu tên theo.
	var cur_camp: int = get_effective_camp()
	if cur_camp != camp:
		set_camp(cur_camp)

	if _key_pressed("toggle_auto"):
		is_auto_mode = not is_auto_mode

	## Bị làm chậm thì hồi chiêu cũng chậm theo — VLTK bỏ qua 1/2 frame MỌI hành động khi đóng băng.
	skill_controller.tick(delta * status_controller.move_speed_multiplier)
	skill_controller.tick_aura(self, delta)
	_tick_loop_skills(delta)

	# Hồi phục Khiên Chân Khí sau thời gian không bị đánh (Kim Chung Tráo)
	if PlayerStats.max_shield > 0.0 and PlayerStats.current_shield < PlayerStats.max_shield:
		PlayerStats.shield_timer -= delta
		if PlayerStats.shield_timer <= 0.0:
			PlayerStats.current_shield = minf(PlayerStats.max_shield, PlayerStats.current_shield + PlayerStats.max_shield * 0.25 * delta)
			PlayerStats.shield_changed.emit(PlayerStats.current_shield, PlayerStats.max_shield)

	# Tự hồi phục Sinh Lực theo thời gian (Dịch Cân Kinh)
	if PlayerStats.hp_regen_percent > 0.0 and health < max_health and not _dead:
		heal(max_health * PlayerStats.hp_regen_percent * delta)

	# Tự hồi phục Nội Lực trong chế độ PUBG (1s hồi 30 mana)
	if PubgManager.is_pubg_active() and not _dead and mana < max_mana:
		restore_mana(30.0 * delta)

	# Quản lý Hộ thể Mộng Điệp (Tân thủ <= 80 trong map luyện: hồi 100 HP & 100 MP mỗi 0.5s, aura Mộng Điệp, lên cấp 81 là hết)
	var mong_diep_on := is_mong_diep_active()
	if mong_diep_on != _last_mong_diep_active:
		_last_mong_diep_active = mong_diep_on
		_refresh_aura_sprite()

	if mong_diep_on:
		var need_regen := (health < max_health) or (mana < max_mana)
		if need_regen:
			if _mong_diep_just_lost:
				# Vừa mất máu hoặc mana -> hồi ngay lập tức 30 điểm
				_mong_diep_just_lost = false
				_mong_diep_timer = 0.0
				if health < max_health:
					heal(MONG_DIEP_REGEN_AMOUNT)
				if mana < max_mana:
					restore_mana(MONG_DIEP_REGEN_AMOUNT)
			else:
				_mong_diep_timer += delta
				if _mong_diep_timer >= MONG_DIEP_REGEN_INTERVAL:
					_mong_diep_timer = 0.0
					if health < max_health:
						heal(MONG_DIEP_REGEN_AMOUNT)
					if mana < max_mana:
						restore_mana(MONG_DIEP_REGEN_AMOUNT)
		else:
			_mong_diep_timer = 0.0
			_mong_diep_just_lost = true
	else:
		_mong_diep_timer = 0.0
		_mong_diep_just_lost = true

	## Auto: chọn mục tiêu / ra chiêu / buff / nhặt đồ theo "Thiết lập auto đánh" (AutoController). Skill phụ phím skill_1-4
	## vẫn bấm tay được song song.
	auto.tick(delta, is_auto_mode)
	if not is_auto_mode and _key_pressed("attack_skill"):
		use_main_skill()

	## Phím skill_1-4 (bàn phím 5-8; 1-4 dành cho 4 ô thuốc QuickItemBar) = 4 ô đầu của trang thanh skill đang chọn.
	## Bản web: phím 1-9 là 9 ô vật phẩm của thanh dưới gốc (WebHudBar), skill đổi bằng Q E R Y U H -> không dùng skill_1-4.
	if WebHudBar.enabled():
		return
	var page_start: int = GameManager.local_profile.hotbar_page * PlayerProfile.HOTBAR_SLOTS_PER_PAGE 			if GameManager.local_profile else 0
	for i in range(4):
		if _key_pressed("skill_%d" % (i + 1)):
			_clear_chase_main()
			var sub_skill: SkillDefinition = skill_controller.get_sub_skills()[page_start + i]
			if skill_controller.try_cast_skill(page_start + i, self, get_cast_target(sub_skill)):
				play_cast()

func update_facing(direction: Vector2) -> void:
	avatar.face(direction)

func update_move_animation(input_vector: Vector2) -> void:
	var anim_name := "run" if input_vector != Vector2.ZERO else "stand"
	if avatar.action != anim_name:
		avatar.play(anim_name)
	if combat_stats != null and combat_stats.walk_run_shadow > 0:
		if input_vector != Vector2.ZERO:
			if not avatar.is_blur_on():
				avatar.set_blur(true)
		else:
			if avatar.is_blur_on() and not is_attacking:
				avatar.set_blur(false)
	elif avatar.is_blur_on() and not is_attacking:
		avatar.set_blur(false)

## ẨN THÂN (Ngự Tuyết Ẩn / Huyền Băng Vô Tắc -> Dung Tuyết Vô Tung): trạng thái mang thuộc tính "hide" đang chạy.
func is_hidden() -> bool:
	return status_controller != null and status_controller.is_hidden()

## Báo AI quái / bot (PlayerStealth) + thân người mờ 50% như KNpcRes gốc (chỉ chính chủ thấy mình).
var _stealth_shown := false

func _tick_stealth() -> void:
	var hidden := is_hidden() and not _dead
	PlayerStealth.local_is_hidden = hidden
	if hidden != _stealth_shown:
		_stealth_shown = hidden
		avatar.set_stealth(hidden)

func play_attack() -> void:
	if _is_jumping:
		return
	_is_sitting = false
	is_attacking = true
	_face_nearest_enemy()
	avatar.play("attack")

## Ra chiêu: quay về phía mục tiêu gần nhất rồi diễn động tác thi triển (chạy 1 lần, xong tự về đứng/chạy).
func play_cast() -> void:
	if is_attacking or is_casting or _is_jumping:
		return
	_is_sitting = false
	is_casting = true
	_face_nearest_enemy()
	avatar.play("cast")

# ------------------------------------------------------------ Tiếp cận & Thi triển Skill Đánh Chính
const CHASE_SEARCH_MAX_RADIUS := 3000.0

var _chase_main_target: Node2D = null
var _chase_main_skill: SkillDefinition = null
var _chase_replan_timer: float = 0.0
var _chase_elapsed_time: float = 0.0

## Sử dụng Skill Đánh Chính (bấm phím attack_skill hoặc nhấp nút chính trên SkillBarUI):
##   - Nếu có quái trong phạm vi thi triển skill chính -> thi triển ngay vào quái gần nhất.
##   - Nếu không có quái trong phạm vi thi triển -> tự động tiến tới quái gần nhất cho đến khi vào phạm vi rồi đánh.
func use_main_skill() -> void:
	if _dead or _is_jumping or status_controller.is_stunned:
		return
	if _is_sitting:
		_stand_up()

	# Trong chế độ vượt ải / survivor: khi bấm đánh, thi triển toàn bộ các kỹ năng đã học đang sẵn sàng
	if GameModeManager.is_offline() and (GameManager.game_mode == GameManager.GameMode.STAGE or (GameManager.field_map != null and GameManager.field_map.get("survivor_mode", false) == true)):
		var agent = get_node_or_null("SurvivorCombatAgent")
		if agent != null and agent.has_method("cast_all_ready_skills"):
			agent.cast_all_ready_skills()
			return

	var main_skill := skill_controller.get_main_skill() if skill_controller else null
	if main_skill == null:
		return

	# Hào quang hoặc buff bản thân: thi triển ngay lên mình
	if SectSkillController.is_self_buff(main_skill) or main_skill.is_aura:
		_clear_chase_main()
		if skill_controller.try_cast_main(self, null):
			play_cast()
		return

	# Thiết lập đánh theo hướng nhìn hoặc đang ngắm hướng kéo:
	var profile := GameManager.local_profile
	if (profile and profile.get_skill_setting("face_direction")) or aim_dir != Vector2.ZERO:
		_clear_chase_main()
		var pt := _make_cast_point(main_skill)
		if skill_controller.try_cast_main(self, pt):
			play_cast()
		return

	var skill_range := get_skill_radius(main_skill)

	# 1. Kiểm tra xem có quái nằm trong phạm vi thi triển skill chính hay không
	# (Ưu tiên mục tiêu người chơi đã bấm chọn nếu mục tiêu đó còn sống và trong tầm)
	var chosen := get_selected_target()
	var target_in_range: Node2D = null
	if chosen != null and _is_valid_target(chosen) and chosen.is_in_group("enemies"):
		var cd: Vector2 = chosen.global_position - global_position
		if cd.x * cd.x + cd.y * cd.y * 4.0 <= skill_range * skill_range:
			target_in_range = chosen

	if target_in_range == null:
		target_in_range = get_nearest_enemy(skill_range)

	if target_in_range != null:
		_clear_chase_main()
		if is_moving_to_target():
			stop_walking()
		update_facing(target_in_range.global_position - global_position)
		if skill_controller.try_cast_main(self, target_in_range):
			play_cast()
		return

	# Trong chế độ vượt ải / survivor: chỉ đánh quái khi quái đi vào trong vòng tầm đánh của skill
	if GameModeManager.is_offline() and (GameManager.game_mode == GameManager.GameMode.STAGE or GameManager.field_map.get("survivor_mode", false)):
		return

	# 2. Không có quái trong phạm vi thi triển: tìm quái gần nhất trên bản đồ để tiến tới
	var target_to_chase: Node2D = null
	if chosen != null and _is_valid_target(chosen) and chosen.is_in_group("enemies"):
		target_to_chase = chosen
	else:
		target_to_chase = get_nearest_enemy(CHASE_SEARCH_MAX_RADIUS)

	if target_to_chase != null:
		_start_chase_main(target_to_chase, main_skill)
	else:
		# Không có quái nào trên bản đồ: thi triển điểm ảo phía trước mặt (nếu có đạn)
		_clear_chase_main()
		var pt := _make_cast_point(main_skill)
		if skill_controller.try_cast_main(self, pt):
			play_cast()

func _start_chase_main(target: Variant, skill: SkillDefinition) -> void:
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return
	var n := target as Node2D
	_chase_main_target = n
	_chase_main_skill = skill
	_chase_replan_timer = 0.35
	_chase_elapsed_time = 0.0
	set_target(n, false)
	_move_towards_target(n)

## Bản web — skill CHUỘT TRÁI (ô T, WebMouseSkills.left_skill): bấm trái vào kẻ địch -> đuổi theo rồi đánh LIÊN TỤC bằng skill
## đó (ra tiếp mỗi khi hết hồi chiêu) tới khi mục tiêu chết / mất / người chơi bấm chỗ khác hoặc tự đi — như Npc::m_nPeopleIdx
## của client gốc (KPlayer::ProcessMouse, Key == 0 + quan hệ địch).
var _chase_keep := false
const KEEP_ATTACK_SLACK := 1.5

func start_left_attack(target: Node2D) -> void:
	if _dead or target == null:
		return
	var skill := WebMouseSkills.left_skill(skill_controller)
	if skill == null:
		return
	if _is_sitting:
		_stand_up()
	auto.on_manual_input()
	_start_chase_main(target, skill)
	set_target(target, true)   ## người chơi tự bấm chọn (_start_chase_main đặt như mục tiêu tự chọn)
	_chase_keep = true

## Shift + bấm trái (bản web): ra skill chuột trái 1 lần về phía con trỏ / vào địch dưới con trỏ (gốc Mouse_Force0).
func cast_left_skill_at(world_pos: Vector2) -> void:
	if _dead or _is_jumping or status_controller.is_stunned:
		return
	var skill := WebMouseSkills.left_skill(skill_controller)
	if skill == null or skill.is_aura:
		return
	if _is_sitting:
		_stand_up()
	_clear_chase_main()
	var picked := pick_target_at(world_pos)
	var target: Node2D = null
	if picked != null and picked.is_in_group("enemies"):
		target = picked
		update_facing(picked.global_position - global_position)
	else:
		var aim: Array = aim_toward(world_pos, skill)
		if aim[0] == Vector2.ZERO:
			return
		set_aim(aim[0], aim[1], false)
		target = make_aim_target(skill)
	if skill_controller.try_cast_loop(skill, self, target):
		play_cast()
	set_aim(Vector2.ZERO)

func _clear_chase_main() -> void:
	_chase_keep = false
	_chase_main_target = null
	_chase_main_skill = null
	_chase_replan_timer = 0.0
	_chase_elapsed_time = 0.0

func _move_towards_target(target: Variant) -> void:
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return
	var n := target as Node2D
	var feet := VltkMath.ground_of(n)
	if VltkWorld.current == null or not walk_to_feet(feet):
		_set_move_target(n.global_position)
	_show_route = false

func _tick_chase_main(delta: float) -> void:
	if _chase_main_target == null:
		return
	if not _is_valid_target(_chase_main_target):
		_clear_chase_main()
		stop_walking()
		return

	_chase_elapsed_time += delta
	if _chase_elapsed_time > 10.0:
		_clear_chase_main()
		stop_walking()
		return

	var d: Vector2 = _chase_main_target.global_position - global_position
	var dist_logic: float = sqrt(d.x * d.x + d.y * d.y * 4.0)
	var skill_range: float = get_skill_radius(_chase_main_skill) if _chase_main_skill else get_current_range()

	# Đã tiến tới mức phạm vi có thể thi triển skill. Đánh liên tục (bản web) bằng chiêu CẬN CHIẾN: như get_cast_target, quái trong
	# vùng quét là ra chiêu luôn — bộ chạy chiêu tự lao tới (VltkSkillRunner._melee_approach), không đi bộ theo đường (đường chỉ tới
	# ô kề quái nên có thể không bao giờ vào đúng tầm).
	var melee_keep := _chase_keep and _chase_main_skill != null and _chase_main_skill.vltk_skill_id > 0 \
			and dist_logic <= AUTO_CHASE_RADIUS \
			and VltkSkillRunner.is_melee_supported(VltkSkillData.skill(_chase_main_skill.vltk_skill_id, 1))
	# Thân quái chặn không cho đứng sát hơn (đi từ trên / dưới, trục dọc tính gấp đôi): đã sát trong 1.5 lần tầm thì ra chiêu.
	var near_keep := _chase_keep and dist_logic <= skill_range * KEEP_ATTACK_SLACK
	if dist_logic <= skill_range or melee_keep or near_keep:
		stop_walking()
		update_facing(_chase_main_target.global_position - global_position)
		var target := _chase_main_target
		## Đánh liên tục (skill chuột trái bản web): ra chiêu mỗi khi được, giữ mục tiêu; đứng trong tầm thì không tính hết giờ đuổi.
		if _chase_keep:
			_chase_elapsed_time = 0.0
			if skill_controller.try_cast_loop(_chase_main_skill, self, target):
				play_cast()
			return
		if skill_controller.try_cast_main(self, target):
			play_cast()
			_clear_chase_main()
		elif not skill_controller.is_skill_usable(skill_controller.get_main_skill()):
			if _chase_elapsed_time > 2.0:
				_clear_chase_main()
		return

	# Chưa tới phạm vi: định kỳ cập nhật đường đi nếu quái di chuyển hoặc chưa có đường
	_chase_replan_timer -= delta
	if _chase_replan_timer <= 0.0:
		_chase_replan_timer = 0.35
		if not is_moving_to_target() or dist_logic > skill_range * 1.3:
			_move_towards_target(_chase_main_target)

## Mục tiêu khi người chơi TỰ ra chiêu (phím / nút skill), theo khung "Tùy chỉnh kỹ năng":
##   - Đánh theo hướng trước mặt: luôn là 1 điểm phía trước mặt (không nhắm quái).
##   - Mặc định (MỌI skill đánh): quái gần nhất trong tầm của skill đó; không có quái thì thi triển theo HƯỚNG NHÌN của
##     nhân vật, tới đúng tầm AttackRadius của skill (điểm ảo phía trước mặt) — như VLTK gốc khi bấm skill không chọn địch.
func get_cast_target(skill: SkillDefinition = null) -> Node2D:
	if skill != null and not skill.target_enemy:
		return _make_cast_point(skill)
	var profile := GameManager.local_profile
	if profile and profile.get_skill_setting("face_direction"):
		return _make_cast_point(skill)
	var target := get_nearest_enemy(get_skill_radius(skill) if skill != null else -1.0)
	## Skill CẬN CHIẾN (tầm ngắn): không có quái trong tầm thì nhắm quái gần nhất trong vùng quét — nhân vật sẽ chạy tới đó rồi mới
	## đánh (VltkSkillRunner._melee_approach), thay vì đánh vào khoảng không.
	if target == null and skill != null and skill.vltk_skill_id > 0 			and VltkSkillRunner.is_melee_supported(VltkSkillData.skill(skill.vltk_skill_id, 1)):
		target = get_nearest_enemy(AUTO_CHASE_RADIUS)
	if target == null:
		return _make_cast_point(skill)
	return target

## ---- NGẮM HƯỚNG (kéo nút chính trong SkillBarUI) ----
## `aim_dir` (hướng trên màn hình, đã chuẩn hoá; ZERO = không ngắm): nhân vật quay mặt theo hướng đó, skill đánh vào 1 điểm ảo theo hướng
## đó (không nhắm quái) và 1 mũi tên dài vẽ trên bản đồ chỉ hướng đánh.
var aim_dir := Vector2.ZERO
## Tỉ lệ khoảng cách điểm thi triển so với tầm tối đa của skill (AIM_MIN_FRACTION..1): kéo nút chính gần = đánh gần, kéo xa = đánh ở tầm max.
var aim_fraction := 1.0
const AIM_MIN_FRACTION := 0.2
var _aim_arrow: AimArrow
## Đang giữ CHUỘT PHẢI trên bản đồ (PC/Web): SkillBarUI thi triển skill nút chính về phía con trỏ.
var right_cast_held := false

## `show_arrow` = false: ngắm bằng chuột phải — không vẽ mũi tên xanh (con trỏ đã chỉ điểm đánh).
func set_aim(dir: Vector2, fraction: float = 1.0, show_arrow: bool = true) -> void:
	aim_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO
	aim_fraction = clampf(fraction, AIM_MIN_FRACTION, 1.0) if aim_dir != Vector2.ZERO else 1.0
	if aim_dir != Vector2.ZERO:
		last_direction = aim_dir
		if not is_attacking and not is_casting and not _is_jumping:
			avatar.face(aim_dir)
	if _aim_arrow == null:
		_aim_arrow = AimArrow.new()
		_aim_arrow.top_level = true
		add_child(_aim_arrow)
	var main_skill := skill_controller.get_main_skill()
	## Mũi tên chỉ vẽ cho skill TẦM XA (đạn bay); skill cận chiến/đánh sát không có mũi tên (vẫn xoay và đánh theo hướng kéo).
	_aim_arrow.set_aim(aim_dir if show_arrow and _is_ranged_skill(main_skill) else Vector2.ZERO, get_ground_position(), _aim_length(main_skill) * aim_fraction)

## Skill tầm xa = có đạn bay (không phải kiểu cận chiến VLTK) và tầm đánh đủ dài (> AIM_ARROW_MIN_RADIUS pixel).
const AIM_ARROW_MIN_RADIUS := 120.0
func _is_ranged_skill(skill: SkillDefinition) -> bool:
	if skill == null:
		return false
	if skill.vltk_skill_id > 0 and VltkSkillRunner.is_melee_supported(VltkSkillData.skill(skill.vltk_skill_id, 1)):
		return false
	return skill.vltk_attack_radius <= 0 or get_skill_radius(skill) >= AIM_ARROW_MIN_RADIUS

## Độ dài mũi tên theo tầm của skill (logic VLTK dọc nhân đôi -> chiếu lên màn hình như _make_cast_point).
func _aim_length(skill: SkillDefinition) -> float:
	var r := get_skill_radius(skill) if skill != null else 0.0
	return r if r > 0.0 else CAST_POINT_DISTANCE

## Điểm ảo theo hướng ngắm (thay cho get_cast_target) — dùng khi đang giữ kéo nút chính. Dùng LẠI 1 node cho mọi lần bắn (skill chỉ đọc vị
## trí lúc ra chiêu) để không sinh hàng trăm node khi đánh liên tục.
var _aim_point: Node2D

func make_aim_target(skill: SkillDefinition = null) -> Node2D:
	var d := (aim_dir if aim_dir != Vector2.ZERO else last_direction).normalized()
	var r := get_skill_radius(skill) if skill != null else 0.0
	var distance := (r if r > 0.0 else CAST_POINT_DISTANCE) * (aim_fraction if aim_dir != Vector2.ZERO else 1.0)
	var logic := Vector2(d.x, d.y * 2.0).normalized() * distance
	if _aim_point == null or not is_instance_valid(_aim_point):
		_aim_point = Node2D.new()
		_aim_point.set_meta("cast_point", true)
		get_parent().add_child(_aim_point)
	## Tính từ CHÂN (gốc đo tầm của bộ máy chiêu, cũng là gốc mũi tên) -> điểm nổ trùng đầu mũi tên.
	_aim_point.global_position = get_ground_position() + Vector2(logic.x, logic.y * 0.5)
	return _aim_point

## Hướng + tỉ lệ khoảng cách để ngắm tới 1 điểm trên bản đồ (chuột phải): khoảng cách tính theo logic VLTK (dọc nhân đôi),
## quá tầm skill thì giữ ở tầm max. Trả về [dir màn hình, fraction].
func aim_toward(world_point: Vector2, skill: SkillDefinition = null) -> Array:
	var off := world_point - get_ground_position()
	if off.length() < 1.0:
		return [Vector2.ZERO, 1.0]
	var r := get_skill_radius(skill) if skill != null else 0.0
	var max_d := r if r > 0.0 else CAST_POINT_DISTANCE
	var logic_len := Vector2(off.x, off.y * 2.0).length()
	return [off.normalized(), clampf(logic_len / max_d, AIM_MIN_FRACTION, 1.0)]

## Điểm mục tiêu ảo phía trước mặt (meta "cast_point" — SectSkillCast/bùa nhận biết để không đuổi/áp trạng thái
## lên nó); tự huỷ sau vài giây.
const CAST_POINT_DISTANCE := 220.0
func _make_cast_point(skill: SkillDefinition = null) -> Node2D:
	var point := Node2D.new()
	point.set_meta("cast_point", true)
	get_parent().add_child(point)
	## Cách người thi triển đúng bằng tầm skill THEO CHUẨN LOGIC VLTK (dọc nhân đôi): đổi hướng nhìn sang logic rồi về
	## màn hình — hướng chéo/dọc không bị kéo dài quá tầm.
	var r := get_skill_radius(skill) if skill != null else 0.0
	var distance := r if r > 0.0 else CAST_POINT_DISTANCE
	var d := (aim_dir if aim_dir != Vector2.ZERO else last_direction).normalized()
	var logic := Vector2(d.x, d.y * 2.0).normalized() * distance
	point.global_position = get_ground_position() + Vector2(logic.x, logic.y * 0.5)
	get_tree().create_timer(3.0).timeout.connect(point.queue_free)
	return point

func _face_nearest_enemy() -> void:
	if aim_dir != Vector2.ZERO:
		avatar.face(aim_dir)  ## đang ngắm bằng nút chính: không xoay về quái
		return
	if GameManager.local_profile and GameManager.local_profile.get_skill_setting("face_direction"):
		avatar.face(last_direction)  ## đánh theo hướng đang quay — không xoay về quái
		return
	var target := get_nearest_enemy()
	if target:
		last_direction = (target.global_position - global_position).normalized()
	avatar.face(last_direction)

## Động tác ra chiêu của bộ máy chiêu VLTK (VltkSkillRunner): quay về điểm nhắm, ngoại công diễn "đánh", nội công
## diễn "thi triển". Trả về thời lượng động tác (giây) — đạn bắn ở 60% thời lượng này.
## `duration` > 0: co giãn động tác cho vừa đúng thời gian đó (đòn đánh liên tiếp của skill cận chiến ngắn hơn động tác thường).
func begin_skill_action(physical: bool, aim_position: Vector2, duration: float = -1.0) -> float:
	var to_aim := aim_position - global_position
	if to_aim.length() > 1.0:
		last_direction = to_aim.normalized()
	avatar.face(last_direction)
	_is_sitting = false
	is_casting = true
	var speed_mult: float = maxf(0.5, PlayerStats.attack_speed_multiplier)
	## Độ dài động tác như gốc (ảnh SPR được kéo giãn cho vừa): 18 frame ngoại công / 20 frame nội công theo tốc độ đánh —
	## khớp khoá động tác của SectSkillController.
	var speed: int = (combat_stats.attack_speed if physical else combat_stats.cast_speed) if combat_stats else 0
	var speed_factor: float = 100.0 / maxf(1.0, float(speed + 100))
	var base_dur := (duration * speed_factor) if duration > 0.0 else SectSkillController.action_seconds(physical, combat_stats)
	var act_duration := base_dur / speed_mult
	avatar.play("attack" if physical else "cast", act_duration)
	## Băng sát: động tác chạy chậm (avatar.get_time_scale) -> thời điểm ra đòn 60% / hết đòn cũng lùi theo.
	return act_duration / avatar.get_time_scale()

## CHẠY LAO TỚI mục tiêu (Melee_RunAndAttack gốc): tới khi cách mục tiêu `stop_distance` hoặc hết `seconds` thì dừng và
## phát signal rush_finished. Trong lúc lao không nhận phím di chuyển; xuyên qua quái nhưng vẫn vướng vật cản.
signal rush_finished
const RUSH_SPEED_MULT := 2.6
var _rush_target_id: int = 0
var _rush_time_left: float = 0.0
var _rush_stop_distance: float = 40.0

func rush_toward(target: Node2D, seconds: float, stop_distance: float) -> void:
	if target == null or seconds <= 0.0:
		return
	_rush_target_id = target.get_instance_id()
	_rush_time_left = seconds
	_rush_stop_distance = stop_distance
	_is_sitting = false
	is_casting = true
	_clear_move_target()
	stop_follow()
	avatar.play("run")

func is_rushing() -> bool:
	return _rush_time_left > 0.0

## Tốc độ lao (pixel/giây) — skill chạy-tới-đánh dùng để tính cần lao bao lâu mới tới mục tiêu.
func get_rush_speed() -> float:
	return SPEED * RUSH_SPEED_MULT

## Hướng lao tới trong frame này (ZERO = đã xong).
func _tick_rush(delta: float) -> Vector2:
	var target := instance_from_id(_rush_target_id) as Node2D
	_rush_time_left -= delta
	if target == null or not target.is_inside_tree() or _rush_time_left <= 0.0 \
			or global_position.distance_to(target.global_position) <= _rush_stop_distance:
		_rush_time_left = 0.0
		rush_finished.emit()
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()

func _on_avatar_action_finished(finished: String) -> void:
	if finished == "attack" and is_attacking:
		is_attacking = false
	elif finished == "cast" or finished == "attack":
		is_casting = false
	elif finished == "hurt":
		pass
	else:
		return
	avatar.play("stand")

## Điểm chân nhân vật (avatar đặt lệch xuống so với gốc node) — bộ máy chiêu VLTK lấy làm toạ độ người thi triển.
func get_ground_position() -> Vector2:
	return avatar.global_position

## Tầm đánh = AttackRadius gốc của skill (đơn vị logic VLTK: ngang 1 px = 1 đơn vị, dọc 1 px = 2 đơn vị). Skill chưa có
## dữ liệu tầm thì dùng base_range cũ. Nâng cấp tầm (PlayerStats.range_multiplier) vẫn nhân lên.
## Vòng tầm dưới chân: hiện tầm của skill VỪA DÙNG (đòn chính, phím 1-4, ô liên tục) trong RANGE_SHOW_MS, rồi trở về tầm đòn
## chính. Skill không có tầm (buff, hào quang) thì không đổi vòng.
const RANGE_SHOW_MS := 3000
var _range_skill: SkillDefinition = null
var _range_until_ms := 0

## ---- Độ bền trang bị (ItemDurability, KItemList::Abrade gốc) — OFFLINE tính ở đây; online do game server tính trên hồ sơ của nó
## và gửi S_ITEM_DUR / S_PROFILE về (máy người chơi không tự trừ để khỏi lệch).
const _NO_REGION := Vector2i(-2147483647, -2147483647)
var _abrade_region := _NO_REGION

func _on_skill_cast_abrade(_skill_id: String) -> void:
	_apply_abrade(ItemDurability.Kind.ATTACK)   ## KNpc::DoSkill: mỗi lần ra chiêu

func _tick_move_abrade() -> void:
	var region := ItemDurability.region_of(global_position)
	if region == _abrade_region:
		return
	var first := _abrade_region == _NO_REGION
	_abrade_region = region
	if not first:
		_apply_abrade(ItemDurability.Kind.MOVE)   ## đổi vùng bản đồ (KNpc -> PlayerChangeRegion gốc)

func _apply_abrade(kind: int) -> void:
	var prof := GameManager.local_profile
	if prof == null or NetWorldSync.is_online_mode():
		return
	var changes := ItemDurability.abrade(prof, kind)
	if changes.is_empty():
		return
	for ch in changes:
		var msg := ItemDurability.change_message(ch)
		if msg != "":
			ChatBox.push_system("[color=#ff6060]%s[/color]" % msg)
	SaveManager.save_profile(prof)

func _on_skill_cast_for_range(skill_id: String) -> void:
	var s := skill_controller.get_skill(skill_id)
	if s != null and (s.vltk_attack_radius > 0 or s.vltk_attribs.has("skill_attackradius") or ("range" in s and s.range > 0)):
		_range_skill = s
		_range_until_ms = Time.get_ticks_msec() + RANGE_SHOW_MS

func _display_range() -> float:
	if _range_skill != null and Time.get_ticks_msec() < _range_until_ms:
		return get_skill_radius(_range_skill)
	return get_current_range()

func get_skill_radius(skill: SkillDefinition) -> float:
	if skill == null:
		return base_range * PlayerStats.range_multiplier * skill_radius_mult
	var lvl := 1
	if skill_controller != null and skill_controller.has_method("_learned_level"):
		lvl = skill_controller._learned_level(skill)
	var radius := skill.get_attack_radius_at_level(lvl)
	if radius <= 0.0:
		radius = skill.range if ("range" in skill and skill.range > 0.0) else base_range
	return radius * PlayerStats.range_multiplier * skill_radius_mult

## Tầm của đòn chính đang chọn — vòng chỉ tầm và Auto dùng tầm này.
## Ô THI TRIỂN LIÊN TỤC: mỗi LOOP_CHECK_INTERVAL giây thử ra chiêu skill trong các ô (mỗi lượt tối đa 1 skill):
##   - skill đánh: chỉ ra khi có quái trong TẦM của skill; hồi chiêu do SectSkillController lo;
##   - hào quang (kể cả Vô Hình Độc): giữ BẬT — VLTK chỉ cho 1 hào quang cùng lúc nên chỉ hào quang ở ô đầu tiên được giữ bật
##     (nếu 2 ô đều là hào quang thì chúng sẽ liên tục giành nhau); buff: ra lại khi trạng thái cũ đã hết.
const LOOP_CHECK_INTERVAL := 0.2
var _loop_timer: float = 0.0

func _tick_loop_skills(delta: float) -> void:
	_loop_timer += delta
	if _loop_timer < LOOP_CHECK_INTERVAL:
		return
	_loop_timer = 0.0
	if _is_jumping or status_controller.is_stunned or _dead:
		return
	var profile := GameManager.local_profile
	var aura_claimed := false
	for i in PlayerProfile.LOOP_SLOT_COUNT:
		if not skill_controller.loop_enabled[i]:
			continue
		var skill := skill_controller.get_loop_skill(i)
		if skill == null:
			continue
		if skill.is_aura:
			if not aura_claimed:
				aura_claimed = true
				if not skill_controller.is_aura_active(skill):
					if profile:
						profile.active_aura_id = skill.id
						SaveManager.save_profile(profile)
					refresh_combat_stats()
					_refresh_aura_sprite()
					if SectSkillController.USE_VLTK_SKILL_FX:
						VltkSkillRunner.play_support(self, null, skill, skill_controller._learned_level(skill))
			continue
		elif SectSkillController.is_self_buff(skill):
			# Cửu Kiếm Hợp Nhất (Hoa Sơn): kỹ năng bị động kích hoạt khi gắn ô thi triển liên tục,
			# không cần thi triển bùa active nền làm gián đoạn nhân vật.
			if skill.id == "hoa_son_cuu_kiem_hop_nhat":
				continue
			# Buff hỗ trợ bản thân (Từ Hàng Phổ Độ buff máu Nga My, v.v.):
			# Thi triển nền liên tục không làm dừng di chuyển hay ngắt đòn đánh của nhân vật.
			if not status_controller.has_state(skill.id):
				skill_controller.try_cast_loop(skill, self, null)
			continue
		elif not skill.is_aura and not SectSkillController.is_self_buff(skill):
			if is_attacking or is_casting:
				continue
			var target: Node2D = get_nearest_enemy(get_skill_radius(skill))
			if target != null and skill_controller.try_cast_loop(skill, self, target):
				play_cast()
				return

## Gọi khi người chơi kéo thả hoặc gán skill vào ô thi triển liên tục ngoài trận / trong bảng skill
func on_loop_slot_updated(_index: int, skill_id: String) -> void:
	var profile := GameManager.local_profile
	refresh_combat_stats()
	_refresh_aura_sprite()
	if skill_id == "":
		return
	var skill := skill_controller.get_skill(skill_id) if skill_controller else null
	if skill == null:
		return
	if skill.is_aura:
		if profile:
			profile.active_aura_id = skill.id
			SaveManager.save_profile(profile)
		refresh_combat_stats()
		_refresh_aura_sprite()
		if SectSkillController.USE_VLTK_SKILL_FX:
			VltkSkillRunner.play_support(self, null, skill, skill_controller._learned_level(skill))
	elif SectSkillController.is_self_buff(skill):
		if skill_id != "hoa_son_cuu_kiem_hop_nhat":
			skill_controller.try_cast_loop(skill, self, null)

func get_current_range() -> float:
	if GameModeManager.is_offline() and (GameManager.game_mode == GameManager.GameMode.STAGE or (GameManager.field_map != null and GameManager.field_map.get("survivor_mode", false) == true)):
		var s_dict := SurvivorManager.active_skills if not SurvivorManager.active_skills.is_empty() else PlayerStats.survivor_skills
		if not s_dict.is_empty():
			var max_r := 0.0
			for s_id in s_dict.keys():
				var s := skill_controller.get_skill(str(s_id)) if skill_controller else null
				if s != null and not s.is_aura and not SectSkillController.is_self_buff(s):
					max_r = maxf(max_r, get_skill_radius(s))
			if max_r > 0.0:
				return max_r
	return get_skill_radius(skill_controller.get_main_skill() if skill_controller else null)

## Quái gần nhất trong tầm `radius` (< 0 = tầm đòn chính). Khoảng cách theo chuẩn logic VLTK (dọc nhân đôi) nên vùng
## đánh là hình elip rộng ngang, đúng KNpc/NpcSet::GetDistance gốc.
func get_nearest_enemy(radius: float = -1.0) -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var best_sq: float = INF
	var max_range := radius if radius >= 0.0 else get_current_range()
	var max_sq := max_range * max_range
	## Đang chọn mục tiêu (bấm vào quái/người): ưu tiên đánh nó nếu nằm trong tầm.
	var chosen := get_selected_target()
	if chosen != null and _is_valid_target(chosen):
		var cd: Vector2 = chosen.global_position - global_position
		if cd.x * cd.x + cd.y * cd.y * 4.0 <= max_sq:
			return chosen
	for enemy in enemies:
		if not _is_valid_target(enemy):
			continue
		var d: Vector2 = enemy.global_position - global_position
		var distance_sq := d.x * d.x + d.y * d.y * 4.0
		if distance_sq <= max_sq and distance_sq < best_sq:
			best_sq = distance_sq
			nearest = enemy
	return nearest

func heal(amount: float) -> void:
	health = min(max_health, health + amount)

func restore_mana(amount: float) -> void:
	mana = minf(max_mana, mana + amount)

## Tăng tốc độ chạy tạm thời (Phi Tốc Đan, buff chiêu...)
func apply_speed_buff(percent: float, duration: float) -> void:
	if status_controller and status_controller.has_method("apply_speed_buff"):
		status_controller.apply_speed_buff(percent, duration)

## Hồi máu theo thời gian (HOT: Heal Over Time)
func apply_hot(total_heal: float, duration: float) -> void:
	if duration <= 0.0:
		heal(total_heal)
		return
	var tick_interval := 0.5
	var ticks := int(duration / tick_interval)
	if ticks <= 0:
		heal(total_heal)
		return
	var heal_per_tick := total_heal / float(ticks)
	var t := create_tween()
	for i in ticks:
		t.tween_callback(func() -> void: heal(heal_per_tick))
		t.tween_interval(tick_interval)

## Nhận 1 đòn tấn công THẬT — chạy đúng pipeline CombatFormulas.resolve_damage (CHÍNH XÁC 100%
## VLTK: tương khắc Ngũ Hành, % kháng, chí mạng...). `attacker_stats` là CombatantStats của bên gây
## damage (Enemy dùng CombatantStats.from_enemy_tier(), Player khác dùng combat_stats của chính nó
## khi PvP online sau này) — bắt buộc truyền vào để roll trúng/né đúng AttackRating vs Defense của
## CHÍNH player này, không còn dùng % giảm sát thương cố định (PlayerDefenseStats cũ, đã xoá).
## mods: phần phụ của đòn skill — xem Enemy.take_damage_from() / CombatFormulas.HitModifiers.
var last_attacker: Node = null
var last_attacker_name: String = ""
## 0 Luyện công, 1 Chiến đấu phe, 2 Đồ sát, 3 Bang chiến (Main.set_pk_mode gán).
var pk_mode: int = 0:
	set(v):
		pk_mode = v
		_apply_pk_hp_bar_color()

## Màu ống máu theo trạng thái PK — đúng KNpc::PaintLife gốc: Đồ sát (238,18,137), Bang chiến (170,30,255);
## Luyện công / Chiến đấu giữ màu theo % máu (xanh -> vàng -> đỏ).
const PK_HP_BAR_COLORS := {2: Color8(238, 18, 137), 3: Color8(170, 30, 255)}

func _apply_pk_hp_bar_color() -> void:
	if _head_hp_bar != null and is_instance_valid(_head_hp_bar):
		_head_hp_bar.set_fixed_color(PK_HP_BAR_COLORS.get(pk_mode, Color(0, 0, 0, 0)))

func on_hit_target(target: Node, skill_info: Dictionary = {}) -> void:
	if skill_controller != null and is_instance_valid(target) and target is Node2D:
		skill_controller.trigger_auto_attack_skills(self, target as Node2D, skill_info)

	# Survivor Perk: Hút máu (+0.5% mỗi cấp dựa vào sát thương)
	var leech_ratio := SurvivorPerks.get_life_leech_ratio()
	if leech_ratio > 0.0 and is_instance_valid(target):
		var target_hp: float = float(target.get("max_health")) if target.get("max_health") != null else 100.0
		var healed := maxf(1.0, target_hp * leech_ratio)
		heal(healed)

func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.PHYSICS,
		attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM,
		mods: CombatFormulas.HitModifiers = null) -> void:
	## Đang nhảy (bay trên không) hoặc GM God Mode / Tàng Hình: miễn nhiễm mọi sát thương.
	if _dead or is_invincible or _is_jumping or (GmManager and (GmManager.is_god_mode or GmManager.is_invisible)):
		return

	## Hóa Giải Sát Thương (Hấp Tinh Trận 180 Đường Môn: chặn 100% sát thương phải chịu)
	var status_ctrl: StatusEffectController = get_node_or_null("StatusEffectController")
	if status_ctrl != null and status_ctrl.has_state("duong_mon_hoa_giai_sat_thuong"):
		return

	# Survivor Perk: Khiên Quán Quân Tinh Anh Sái chặn 100% đòn đánh
	var shield_comp = get_node_or_null("SurvivorShieldComponent")
	if shield_comp != null and shield_comp.has_method("try_absorb_hit") and shield_comp.try_absorb_hit():
		return
	if mods != null and mods.attacker_node != null:
		last_attacker = mods.attacker_node
		if "profile" in last_attacker and last_attacker.profile:
			last_attacker_name = str(last_attacker.profile.display_name)
		elif "display_name" in last_attacker:
			last_attacker_name = str(last_attacker.display_name)
	var final_damage := HitResolver.receive(self, combat_stats, int(health), attacker_stats,
			min_damage, max_damage, damage_type, attacker_element, mods)
	if final_damage == HitResolver.MISSED:
		return
	if final_damage == 0:
		return  ## đòn chỉ mang trạng thái (bùa)

	## Kích hoạt kỹ năng tự động khi nhận đòn (autoreplyskill: Chinh Chiến Bát Phương...)
	if skill_controller != null and not _dead:
		var atk_node: Node2D = (mods.attacker_node as Node2D) if (mods != null and mods.attacker_node is Node2D) else null
		skill_controller.trigger_auto_reply_skills(self, atk_node)

	# Hấp thụ sát thương bằng Khiên Chân Khí Kim Chung Tráo nếu có
	if PlayerStats.current_shield > 0.0:
		PlayerStats.shield_timer = PlayerStats.shield_recharge_delay
		if PlayerStats.current_shield >= final_damage:
			PlayerStats.current_shield -= final_damage
			PlayerStats.shield_changed.emit(PlayerStats.current_shield, PlayerStats.max_shield)
			VfxManager.play("hit", global_position)
			return
		else:
			final_damage -= int(PlayerStats.current_shield)
			PlayerStats.current_shield = 0.0
			PlayerStats.shield_changed.emit(0.0, PlayerStats.max_shield)

	var new_hp := health - final_damage
	if status_controller != null and status_controller.has_state("vu_hon_vu_muc_di_thu"):
		var st: Dictionary = status_controller.get_state("vu_hon_vu_muc_di_thu")
		var attribs: Dictionary = st.get("attribs", {})
		var lock_val: float = float((attribs.get("lock_life", Vector3i(100, 0, 0)) as Vector3i).x)
		if lock_val > 0.0:
			new_hp = maxf(new_hp, lock_val)
	health = new_hp
	if health <= 0:
		die()
	else:
		_on_hurt()
		if hurt_invincible:
			start_invincibility()
		if health <= max_health * 0.25 and skill_controller != null and not _dead:
			skill_controller.trigger_auto_rescue_skills(self)

## Đường tắt cho va chạm đơn giản (enemy contact_damage kiểu bullet-heaven hiện tại — không phải
## đòn "thật" có AttackRating riêng) — bọc thành 1 đòn physics tay không với AttackRating cố định
## cao (100 = luôn gần như trúng, giữ đúng cảm giác "chạm là dính" của thể loại này) cho tới khi
## enemy có CombatantStats riêng đầy đủ qua from_enemy_tier(). Enemy nên gọi take_damage_from()
## trực tiếp với CombatantStats thật của nó khi đã setup xong (xem enemy.gd).
func take_damage(amount: float) -> void:
	var fallback_attacker := CombatantStats.new()
	fallback_attacker.attack_rating = 999  ## Gần như luôn trúng — khớp cảm giác va chạm "chắc trúng"
	var whole := int(amount)
	take_damage_from(fallback_attacker, whole, whole)

func spawn_miss_text() -> void:
	## Không hiển thị chữ "Miss" khi quái đánh trượt người chơi
	pass

## Gọi bởi StatusEffectController khi trúng DOT (nếu về sau player bị debuff từ boss/độc).
func take_status_damage(amount: float, _effect_id: String, source_node: Node = null) -> void:
	if _dead or _is_jumping or (GmManager and (GmManager.is_god_mode or GmManager.is_invisible)):
		return  ## đang bay hoặc GM: bỏ qua cả sát thương trạng thái (độc, cháy...)
	if source_node != null:
		last_attacker = source_node
		if "profile" in last_attacker and last_attacker.profile:
			last_attacker_name = str(last_attacker.profile.display_name)
		elif "display_name" in last_attacker:
			last_attacker_name = str(last_attacker.display_name)
	var new_dmg_hp := health - amount
	if status_controller != null and status_controller.has_state("vu_hon_vu_muc_di_thu"):
		var st: Dictionary = status_controller.get_state("vu_hon_vu_muc_di_thu")
		var attribs: Dictionary = st.get("attribs", {})
		var lock_val: float = float((attribs.get("lock_life", Vector3i(100, 0, 0)) as Vector3i).x)
		if lock_val > 0.0:
			new_dmg_hp = maxf(new_dmg_hp, lock_val)
	health = new_dmg_hp
	if health <= 0:
		die()

var invincible_duration: float = 0.35
var invincible_blinks: int = 2

func _on_stage_started(stage: StageData) -> void:
	_apply_stage_settings(stage)

func _on_stage_completed(_stage: StageData) -> void:
	hurt_invincible = false

func _apply_stage_settings(stage: StageData) -> void:
	if stage != null and stage.enable_hit_invincibility:
		hurt_invincible = true
		invincible_duration = stage.hit_invincibility_duration
	else:
		hurt_invincible = false

func start_invincibility() -> void:
	is_invincible = true
	var blinks := maxi(1, invincible_blinks)
	var blink_interval := invincible_duration / (blinks * 2.0)
	for i in range(blinks * 2):
		avatar.modulate = Color(1, 0.4, 0.4, 0.8) if i % 2 == 0 else Color(1, 1, 1, 1)
		await get_tree().create_timer(blink_interval).timeout
	avatar.modulate = Color(1, 1, 1, 1)
	is_invincible = false

## Chết: KHÔNG xoá nhân vật — giữ nguyên cảnh vật, nhân vật nằm tại chỗ (tối tím), quái dừng tay (is_game_over), hiện bảng
## "Bạn đã bị trọng thương!" + "Về thành dưỡng sức" (DeathPopup).
var _dead := false
signal died
## true = trúng đòn được bất tử INVINCIBLE_DURATION giây (cơ chế cũ kiểu game sinh tồn). VLTK gốc KHÔNG có -> mặc định tắt:
## trúng đòn là mất máu ngay, quái đánh dồn được như gốc.
var hurt_invincible := false
## true = chết không hiện bảng "Bạn đã bị trọng thương!" (trận PK tự xử lý thắng/thua và đưa về Hub — PkMatch).
var suppress_death_popup := false

func is_dead() -> bool:
	return _dead

func die() -> void:
	if _dead:
		return
	_dead = true
	health = 0.0
	print("Player died")
	avatar.play_event_sound("die")
	_clear_move_target()
	_clear_chase_main()
	clear_target()
	stop_follow()
	var prof := GameManager.local_profile
	if prof != null and prof.trade_open:
		StallService.close_trade(prof)
		if NetClient.is_in_world():
			NetClient.send_stall(SocialServer.TRADE_CLOSE)
	if is_auto_mode:
		auto.on_player_died()
	is_auto_mode = false
	auto.tick(0.0, false)
	aim_dir = Vector2.ZERO
	right_cast_held = false
	velocity = Vector2.ZERO
	avatar.play("sit")
	avatar.modulate = Color(0.75, 0.4, 0.95, 1.0)
	died.emit()
	if suppress_death_popup:
		return
	_apply_abrade(ItemDurability.Kind.DEFEND)   ## KNpc::DeathPunish: chết ngoài trận đặc biệt -> đồ phòng thủ tụt + % theo trị PK
	GameManager.notify_game_over()
	DeathPopup.show_for(self)

## "Về thành dưỡng sức": sống lại đầy máu ở điểm xuất phát của map (online: server xác nhận vị trí qua C_REVIVE -> S_CORRECT).
func revive_at_start() -> void:
	if not _dead:
		return
	_dead = false
	health = max_health
	avatar.modulate = Color(1, 1, 1, 1)
	avatar.play("stand")
	GameManager.is_game_over = false
	if VltkWorld.current != null and VltkWorld.current.map != null:
		VltkWorld.current.place_at_start(self)
	velocity = Vector2.ZERO
	if NetWorldSync.is_online_mode():
		NetClient.send_revive()

## Hồi sinh tại toạ độ chỉ định (chế độ đấu trường / lộn xộn).
func respawn_at(spawn_pos: Vector2) -> void:
	_dead = false
	health = max_health
	avatar.modulate = Color(1, 1, 1, 1)
	avatar.play("stand")
	GameManager.is_game_over = false
	global_position = spawn_pos
	velocity = Vector2.ZERO
	last_attacker = null
	last_attacker_name = ""
	start_invincibility()

## Hồi sinh tại chỗ đầy máu (phục vụ các chế độ đặc biệt).
func revive() -> void:
	if not _dead:
		return
	_dead = false
	health = max_health
	avatar.modulate = Color(1, 1, 1, 1)
	avatar.play("stand")
	GameManager.is_game_over = false
	velocity = Vector2.ZERO
	last_attacker = null
	last_attacker_name = ""
	start_invincibility()

## Hình trạng thái (StateSpecialId) của hào quang SKILL đang bật — gắn lên người suốt lúc hào quang còn bật.
## Hào quang tổng hợp (Bế Nguyệt Phất Trần) có nhiều hình cùng lúc: state_id -> VltkStateSprite.
var _aura_sprites: Dictionary = {}
## Lớp hào quang KHÁC chồng lên (hào quang GM gán / hộ thể tân thủ Võ Lâm Hào Kiệt) — độc lập với hào quang skill.
var _extra_aura_sprite: VltkStateSprite = null
var _extra_aura_state: int = 0

## Trạng thái Hộ thể Mộng Điệp (Tân thủ <= 80 trong map luyện công):
## Hồi 100 HP & 100 MP mỗi 0.5s và hiển thị Aura Võ Lâm Hào Kiệt (State ID 173 — wulinhaojie.spr) trong lúc còn được tự hồi.
## Lên level 81 là hết.
const STATE_ID_MONG_DIEP := 173
const MONG_DIEP_REGEN_INTERVAL := 0.5
const MONG_DIEP_REGEN_AMOUNT := 100.0

var _mong_diep_timer: float = 0.0
var _last_mong_diep_active: bool = false
var _mong_diep_just_lost: bool = true

func is_mong_diep_active() -> bool:
	if _dead:
		return false
	var profile := GameManager.local_profile
	if profile == null:
		return false
	# Lên cấp 81 là hết hộ thể (chỉ có tác dụng từ cấp 80 trở xuống)
	if profile.level > 80:
		return false
	# Chỉ áp dụng trong phần luyện (map luyện công dã ngoại)
	if GameManager == null or not GameManager.is_training_stage():
		return false
	return true

func set_gm_aura(state_id: int) -> void:
	var profile := GameManager.local_profile
	if profile:
		if profile.get("gm_aura_state") != null:
			profile.set("gm_aura_state", state_id)
		SaveManager.save_profile(profile)
		SaveManager.flush_online.call_deferred()
	_refresh_aura_sprite()
	if NetClient.is_in_world():
		NetClient.send_look(get_current_look())

func _refresh_aura_sprite() -> void:
	var profile := GameManager.local_profile
	## Lớp 1 — hào quang skill đang bật (Lưu Thủy, Mộng Điệp...): LUÔN hiện khi bật.
	var skill_states: Array[int] = []
	if profile and profile.active_aura_id != "":
		var sect := SectRegistry.get_by_id(profile.sect_id)
		if sect:
			for skill in sect.skills:
				if skill.id == profile.active_aura_id:
					skill_states = skill.aura_state_ids(sect, maxi(1, profile.get_skill_level(skill.id)),
							func(s: SkillDefinition) -> int: return profile.get_skill_level(s.id))
					break
	for sid: int in _aura_sprites.keys():
		if not skill_states.has(sid) or not is_instance_valid(_aura_sprites[sid]):
			if is_instance_valid(_aura_sprites[sid]):
				(_aura_sprites[sid] as Node).queue_free()
			_aura_sprites.erase(sid)
	for sid in skill_states:
		if not _aura_sprites.has(sid):
			var spr := VltkStateSprite.attach(self, sid)
			if spr != null:
				_aura_sprites[sid] = spr
	## Lớp 2 — hào quang khác chồng lên: GM gán, không có thì hộ thể tân thủ (Võ Lâm Hào Kiệt).
	var extra := int(profile.get("gm_aura_state")) if profile and profile.get("gm_aura_state") != null else 0
	if extra <= 0 and is_mong_diep_active():
		extra = STATE_ID_MONG_DIEP
	if skill_states.has(extra):
		extra = 0   ## cùng 1 hình thì không vẽ 2 lần
	if not (extra == _extra_aura_state and (extra == 0 or is_instance_valid(_extra_aura_sprite))):
		if _extra_aura_sprite != null and is_instance_valid(_extra_aura_sprite):
			_extra_aura_sprite.queue_free()
		_extra_aura_sprite = VltkStateSprite.attach(self, extra) if extra > 0 else null
		_extra_aura_state = extra

# ------------------------------------------------------------ nhảy / ngựa / đi theo

## Bị trúng đòn: đang ngồi thì đứng dậy (KNpc::DoHurt kết thúc bằng DoStand). Diễn động tác khựng đòn (hurt).
func _on_hurt() -> void:
	avatar.play_event_sound("hurt")
	if _is_sitting:
		_stand_up()
	if not is_attacking and not is_casting and not _is_jumping and avatar.action != "die":
		var recover := int(combat_stats.hit_recover) if combat_stats else 0
		if recover < 100:
			var duration := 0.28 * float(100 - recover) / 100.0
			avatar.play("hurt", maxf(0.08, duration))

func can_cast() -> bool:
	return not _is_jumping

func _jump_height() -> float:
	var t := _jump_time * VLTK_FPS
	var v0 := JUMP_GRAVITY * (_jump_frames - 1) / 2.0
	return maxf((v0 * t - JUMP_GRAVITY * t * t / 2.0) / 8.0, 0.0)

## Nhảy theo hướng đang chạy/đang quay hoặc hướng điểm đến (chuẩn VLTK gốc: tối đa 40 frame = 480 pixel).
func start_jump(frames: int = JUMP_DEFAULT_FRAMES, target_pos: Vector2 = Vector2.INF) -> bool:
	if _is_jumping or is_attacking or is_casting or status_controller.is_stunned:
		return false
	_clear_chase_main()
	## Trên ngựa không nhảy được.
	if avatar.is_riding():
		_notice("Đang cưỡi ngựa, không thể nhảy")
		return false
	_is_sitting = false
	var dir := World3DView.screen_dir_to_world(_key_vector("move_left", "move_right", "move_up", "move_down"))
	if target_pos != Vector2.INF:
		var diff := target_pos - global_position
		if diff.length() > 20.0:
			_jump_dir = diff.normalized()
			var want_dist := minf(diff.length(), float(JUMP_MAX_FRAMES * 12))
			_jump_frames = clampi(int(round(want_dist / 12.0)), 2, JUMP_MAX_FRAMES)
		else:
			_jump_dir = last_direction.normalized()
			_jump_frames = clampi(frames, 2, JUMP_MAX_FRAMES)
	elif dir != Vector2.ZERO:
		_jump_dir = dir.normalized()
		_jump_frames = clampi(frames, 2, JUMP_MAX_FRAMES)
	elif _has_move_target:
		var diff := _move_target - global_position
		if diff.length() > 20.0:
			_jump_dir = diff.normalized()
			var want_dist := minf(diff.length(), float(JUMP_MAX_FRAMES * 12))
			_jump_frames = clampi(int(round(want_dist / 12.0)), 2, JUMP_MAX_FRAMES)
		else:
			_jump_dir = last_direction.normalized()
			_jump_frames = clampi(frames, 2, JUMP_MAX_FRAMES)
	else:
		_jump_dir = last_direction.normalized()
		_jump_frames = clampi(frames, 2, JUMP_MAX_FRAMES)

	last_direction = _jump_dir
	_jump_time = 0.0
	_air_height = 0.0
	_last_safe_pos = global_position
	_is_jumping = true
	_clear_move_target()
	stop_follow()
	avatar.face(_jump_dir)
	avatar.play("jump", _jump_frames / VLTK_FPS)  ## co giãn động tác cho vừa đúng thời gian bay
	_apply_name_y()
	return true

func _tick_jump(delta: float) -> void:
	_jump_time += delta
	var feet := global_position + Vector2(0, VltkWorld.FEET_OFFSET)
	var w := VltkWorld.current
	if w == null or not w._blocked_at(feet, false):
		_last_safe_pos = global_position
	if _jump_time * VLTK_FPS >= _jump_frames:
		_end_jump()
		return
	_air_height = _jump_height()
	avatar.set_height(_air_height)
	_apply_name_y()

func _end_jump() -> void:
	_is_jumping = false
	_air_height = 0.0
	avatar.set_height(0.0)
	var feet := global_position + Vector2(0, VltkWorld.FEET_OFFSET)
	var w := VltkWorld.current
	if w != null and w._blocked_at(feet, false) and _last_safe_pos != Vector2.ZERO:
		global_position = _last_safe_pos  ## lỡ rớt vào nước/vật cản: lùi về điểm an toàn cuối (nSuccessStep gốc)
	if not is_attacking and not is_casting:
		avatar.play("stand")
	_apply_name_y()

## Lên/xuống ngựa nhanh (KNpc::SwitchRideHorse). Trả về lời nhắn lỗi ("" = thành công).
func toggle_ride() -> String:
	var profile := GameManager.local_profile
	if profile == null or not profile.equipment.has(Equipment.Part.HORSE):
		return _notice("Chưa có ngựa")
	if _is_sitting:
		return _notice("Đang ngồi, không thể lên/xuống ngựa")
	if _is_jumping or is_attacking or is_casting:
		return ""
	var now := Time.get_ticks_msec()
	if now < _horse_ready_at_ms:
		return _notice("Đổi ngựa quá nhanh, hãy chờ chút")
	_horse_ready_at_ms = now + int(HORSE_SWITCH_COOLDOWN * 1000.0)
	profile.riding = not profile.riding
	refresh_combat_stats()  ## chỉ số ngựa chỉ có hiệu lực khi cưỡi; kèm dựng lại hình
	## Lưu ngay: online, server tính ngoại hình người khác thấy từ hồ sơ (riding) — chờ lần lưu sau thì có lúc
	## server dựng lại hình từ bản cũ, người khác thấy mình lên/xuống ngựa sai.
	SaveManager.save_profile(profile, true)
	return ""

func is_riding() -> bool:
	return avatar.is_riding()

func can_toggle_ride() -> bool:
	return GameManager.local_profile != null and GameManager.local_profile.equipment.has(Equipment.Part.HORSE)

## Bật/tắt đi theo người gần nhất trong nhóm "followable" (người chơi khác, NPC...).
func toggle_follow() -> void:
	if follow_target:
		stop_follow()
		_notice("Dừng đi theo")
		return
	var best: Node2D = null
	var best_distance := FOLLOW_SEARCH_RANGE
	for node in get_tree().get_nodes_in_group("followable"):
		if node == self or not node is Node2D:
			continue
		var d := global_position.distance_to((node as Node2D).global_position)
		if d < best_distance:
			best_distance = d
			best = node
	if best == null:
		_notice("Không có ai để đi theo")
		return
	follow_target = best
	_notice("Đi theo %s" % best.name)

## "Theo sau" từ menu người chơi / nhấp vào tiêu xa: đi theo đúng đối tượng này.
func start_follow(node: Node2D) -> void:
	if node == null or node == self:
		return
	_clear_move_target()
	_clear_chase_main()
	follow_target = node
	_notice("Đi theo %s" % (node.display_name if "display_name" in node else node.name))

## Kiểm tra vị trí bấm chuột có trúng Tiêu Xa (nhóm "escort_carts") không.
func _pick_escort_cart_at(world_pos: Vector2) -> Node2D:
	for n in get_tree().get_nodes_in_group("escort_carts"):
		var cart := n as Node2D
		if cart == null or not is_instance_valid(cart) or not cart.is_inside_tree():
			continue
		var center := cart.global_position + Vector2(0.0, -60.0)
		var dx := absf(world_pos.x - center.x)
		var dy := absf(world_pos.y - center.y)
		if dx <= 100.0 and dy <= 80.0:
			return cart
	return null

func stop_follow() -> void:
	follow_target = null

func is_following() -> bool:
	return follow_target != null

## Skill cận chiến bấm tay mà không có quái trong tầm: nhắm quái gần nhất trong vùng quét này (get_cast_target).
## Auto đuổi quái theo "Phạm vi" trong Thiết lập auto đánh (AutoController).
const AUTO_CHASE_RADIUS := 800.0

## Hướng chạy tới người đang theo (ZERO = không theo / đã đủ gần).
func _get_follow_vector() -> Vector2:
	if follow_target == null:
		return Vector2.ZERO
	if not is_instance_valid(follow_target):
		follow_target = null
		return Vector2.ZERO
	var to_target := follow_target.global_position - global_position
	return to_target.normalized() if to_target.length() > FOLLOW_RADIUS else Vector2.ZERO

## Hiện dòng chữ nổi cho nơi khác gọi (VD skill bị chặn vì sai vũ khí).
func notify(text: String) -> void:
	_notice(text)

## Dòng chữ nổi ngắn trên đầu (lỗi/trạng thái). Trả lại chính chuỗi để hàm gọi trả thẳng ra.
## Cùng 1 câu chỉ hiện lại sau NOTICE_REPEAT_MS — chế độ Auto thử ra chiêu mỗi frame, không được dội chữ liên tục.
const NOTICE_REPEAT_MS := 1500
var _last_notice_text: String = ""
var _last_notice_ms: int = -NOTICE_REPEAT_MS
func _notice(text: String) -> String:
	var now := Time.get_ticks_msec()
	if text == _last_notice_text and now - _last_notice_ms < NOTICE_REPEAT_MS:
		return text
	_last_notice_text = text
	_last_notice_ms = now
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.size = Vector2(220, 20)
	label.position = Vector2(-110, NAME_LABEL_Y - 40.0)
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 24.0, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)
	return text

## Ngồi/đứng dậy (KPlayer PA_SIT). Không ngồi được khi cưỡi ngựa, đang bay, đánh, ra chiêu hay choáng.
func toggle_sit() -> void:
	if _is_sitting:
		_stand_up()
		return
	if avatar.is_riding():
		_notice("Đang cưỡi ngựa, không thể ngồi")
		return
	if _is_jumping or is_attacking or is_casting or status_controller.is_stunned:
		return
	_is_sitting = true
	_sit_time = 0.0
	_clear_move_target()
	stop_follow()
	avatar.play("sit")  ## chạy 1 lần rồi giữ frame cuối (action_finished bị bỏ qua ở _on_avatar_action_finished)

func _stand_up() -> void:
	_is_sitting = false
	if not is_attacking and not is_casting and not _is_jumping:
		avatar.play("stand")

func is_sitting() -> bool:
	return _is_sitting

## Hồi máu & nội lực khi ngồi: mỗi SIT_TICK hồi max_health * 3/1000 và max_mana * 3/1000 (tối thiểu 1) — KNpc::ProcessState gốc.
func _tick_sit(delta: float) -> void:
	_sit_time += delta
	while _sit_time >= SIT_TICK:
		_sit_time -= SIT_TICK
		heal(maxf(1.0, floorf(max_health * SIT_HEAL_PER_MILLE / 1000.0)))
		restore_mana(maxf(1.0, floorf(max_mana * SIT_HEAL_PER_MILLE / 1000.0)))

func _on_state_expired(source_id: String, meta: Dictionary) -> void:
	if skill_controller != null and not _dead:
		skill_controller.on_state_expired(self, source_id, meta)
