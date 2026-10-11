extends CharacterBody2D

const DamageNumberScene := preload("res://effects/damage_number.tscn")

const SPEED = 150.0
const INVINCIBLE_DURATION = 3.0
const INVINCIBLE_BLINKS = 3
## Vị trí (y) tên nhân vật khi đi bộ — ngay trên đầu nhân vật ghép — và độ nâng thêm khi cưỡi ngựa.
const NAME_LABEL_Y = -58.0
const RIDE_HEAD_RAISE = 24.0
## Thu/phóng camera: < 1 = nhìn rộng hơn. 0.7 cho nhân vật cao ~8.5% chiều cao màn hình như ảnh chụp VLTK gốc (trước đây 1.0 ~ 12%).
const CAMERA_ZOOM := 0.8
## Lăn chuột chỉnh zoom: mỗi nấc nhân/chia ZOOM_STEP, giới hạn ZOOM_MIN..ZOOM_MAX, camera trượt mượt tới mức mới.
const ZOOM_MIN := 0.225
const ZOOM_MAX := 1.5
const ZOOM_STEP := 1.1
const ZOOM_SMOOTHING := 12.0
const HealthBarScene := preload("res://ui/HealthBar.tscn")
## Thanh máu trên đầu: nằm ngay dưới tên (tên cao 18px), rộng gấp HP_BAR_WIDTH_SCALE thanh quái.
const NAME_LABEL_HEIGHT := 18.0
const HP_BAR_TOP_OFFSET := 13.0   ## khoảng từ gốc node HealthBar tới mép trên thanh (xem HealthBar.tscn)
const HP_BAR_WIDTH_SCALE := 1.4

## NHẢY — công thức KNpc::NewJump/DoJump/ServerJump gốc (frame = 1/18 giây): bay thẳng theo hướng với 12 đơn vị/frame,
## độ cao h = (v0*t - g*t²/2)/8, g = 10, v0 = g*(số frame-1)/2 (đỉnh ở giữa quãng). Tối đa 40 frame (m_CurrentJumpFrame).
## Nút nhảy không chọn điểm đến nên dùng quãng mặc định JUMP_DEFAULT_FRAMES theo hướng đang quay.
const VLTK_FPS := 18.0
const JUMP_SPEED := 12.0 * VLTK_FPS
const JUMP_GRAVITY := 10.0
const JUMP_MAX_FRAMES := 40
const JUMP_DEFAULT_FRAMES := 20
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
var last_direction: Vector2 = Vector2.RIGHT
var is_invincible: bool = false
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
var _is_sitting: bool = false
var _sit_time: float = 0.0
var _horse_ready_at_ms: int = 0
## Người/NPC đang đi theo (nhóm "followable") — null = không theo ai.
var follow_target: Node2D = null

func _ready() -> void:
	var profile := GameManager.local_profile
	combat_stats = profile.get_combat_stats() if profile else CombatantStats.new()
	## HP tối đa hiển thị/dùng trong màn chơi lấy từ CombatantStats (VLTK gốc), KHÔNG dùng
	## @export max_health cũ nữa — giữ @export chỉ để làm giá trị fallback khi chưa có profile
	## (VD chạy thẳng scene này trong Editor để test).
	if profile:
		max_health = float(combat_stats.max_hp)
	health = max_health
	range_indicator.set_radius(get_current_range())
	avatar.action_finished.connect(_on_avatar_action_finished)
	## Aura có sprite_frames gán sẵn trong scene nhưng KHÔNG autoplay — không có dòng này, nó
	## đứng yên tại đúng frame được lưu lúc chỉnh trong Editor, không bao giờ tự động chạy.
	aura.play("default")
	_zoom_target = CAMERA_ZOOM
	$Camera2D.zoom = Vector2.ONE * _zoom_target
	## Vòng hào quang dưới chân luôn căn đúng CHÂN avatar (không phụ thuộc số đặt tay trong scene): tâm vòng = chân + 1px.
	aura.position = avatar.position + Vector2(0, 1)

	var sect := SectRegistry.get_by_id(profile.sect_id) if profile else null
	skill_controller.setup(sect)
	## Buff/bùa thêm hoặc hết hạn -> dựng lại chỉ số (CombatantStats.build gồm trạng thái đang dính).
	status_controller.stats_changed.connect(refresh_combat_stats)
	_build_name_label(profile.display_name if profile else "")
	_build_head_health_bar()
	refresh_appearance()
	set_camp(profile.get_current_camp() if profile else Camp.Type.BEGIN)
	_build_move_marker()
	add_child(RouteDots.new(self))
	_refresh_aura_sprite()

## Đổi phe (màu tên) — VD vào sự kiện/bang chiến, bật PK thành Sát thủ. Đồng đội tính lại tự động vì
## CombatTargeting đọc `camp` mỗi lần quét.
func set_camp(new_camp: int) -> void:
	camp = new_camp
	if _name_label:
		_name_label.add_theme_color_override("font_color", Camp.get_color(camp))

## Tên nhân vật trên đầu, tô màu theo phe (giống VLTK) — đặt ngay trên thanh máu.
func _build_name_label(display_name: String) -> void:
	_name_label = Label.new()
	_name_label.text = display_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.size = Vector2(160, 18)
	_name_label.position = Vector2(-80, NAME_LABEL_Y)
	add_child(_name_label)

## Dựng lại combat_stats từ profile — gọi sau khi học/nâng skill nội tại hoặc cộng điểm GIỮA trận
## (VD đóng bảng Kỹ Năng Võ Công) để bonus mới có hiệu lực ngay. Giữ nguyên % máu hiện tại.
func refresh_combat_stats() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	var health_ratio := health / max_health if max_health > 0.0 else 1.0
	combat_stats = profile.get_combat_stats(status_controller.get_state_attrib_sources())
	max_health = float(combat_stats.max_hp)
	health = max_health * health_ratio
	refresh_appearance()
	_refresh_aura_sprite()  ## bật/tắt hào quang đều đi qua đây (SectSkillController._toggle_aura)

## Mặc/tháo mũ, áo, vũ khí -> đổi hình nhân vật ngay (gọi kèm refresh_combat_stats sau mỗi lần đổi trang bị).
## Mới có bộ hình nam — nhân vật nữ tạm dùng hình nam cho tới khi nhập bộ nữ.
func refresh_appearance() -> void:
	var profile := GameManager.local_profile
	if profile == null or avatar == null:
		return
	var gender_key := "female" if profile.gender == PlayerProfile.Gender.FEMALE else "male"
	avatar.voice_gender = gender_key
	avatar.set_gender(gender_key)  ## bộ hình nữ (nếu đã nhập) — chưa có thì giữ hình nam
	var look := Equipment.get_appearance(profile.equipment, avatar.gender, profile.riding)
	if look["helm"] != avatar.helm_res or look["armor"] != avatar.armor_res or look["weapon"] != avatar.weapon_res \
			or look["horse"] != avatar.horse_res:
		avatar.set_appearance(look["helm"], look["armor"], look["weapon"], look["horse"])
	## Cưỡi ngựa thì đầu cao hơn ~24px -> dời tên lên theo.
	if _name_label:
		_apply_name_y()

## Thanh máu trên đầu, dưới tên — chạy theo signal health_changed (cùng nguồn với HUD góc trái).
func _build_head_health_bar() -> void:
	_head_hp_bar = HealthBarScene.instantiate()
	_head_hp_bar.use_gradient_color = true  ## xanh -> vàng -> đỏ theo % máu
	_head_hp_bar.scale = Vector2(HP_BAR_WIDTH_SCALE, 1.0)
	add_child(_head_hp_bar)
	health_changed.connect(_on_health_changed_head_bar)
	_on_health_changed_head_bar(health, max_health)
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
	var raise := RIDE_HEAD_RAISE if avatar.is_riding() and not _is_jumping else 0.0
	_name_label.position.y = NAME_LABEL_Y - raise - (_air_height if _is_jumping else 0.0)
	if _head_hp_bar != null:
		_head_hp_bar.position = Vector2(0.0, _name_label.position.y + NAME_LABEL_HEIGHT + HP_BAR_TOP_OFFSET)

# ------------------------------------------------------------ bấm để chạy tới

## Đang gõ vào ô nhập (chat, đặt tên...) thì phím không điều khiển nhân vật (không chạy / nhảy / ra chiêu khi gõ chữ).
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
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = minf(_zoom_target * ZOOM_STEP, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = maxf(_zoom_target / ZOOM_STEP, ZOOM_MIN)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			## Bấm trúng quái / người chơi khác = CHỌN làm mục tiêu đánh (hiện vòng đỏ xoay dưới chân), không chạy tới điểm bấm.
			var picked := pick_target_at(get_global_mouse_position())
			if picked != null:
				set_target(picked)
				## Bấm vào người chơi khác: hiện menu (Tán gẫu / Hảo hữu / Tổ đội / Theo sau / Tin tức / Cừu sát / Sổ đen).
				if picked is RemotePlayer:
					PlayerMenu.open(self, picked as RemotePlayer, get_viewport().get_mouse_position())
				get_viewport().set_input_as_handled()
				return
			## Bấm 1 lần = TỰ TÌM ĐƯỜNG vòng vật cản (có map chính); giữ chuột quá HOLD_FOLLOW_TIME thì bám theo con trỏ.
			var feet := get_global_mouse_position() + Vector2(0, VltkWorld.FEET_OFFSET)
			if VltkWorld.current == null or not walk_to_feet(feet):
				_set_move_target(get_global_mouse_position())
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

func _is_valid_target(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
		return false
	return not (node.has_method("is_dead") and node.call("is_dead"))

func set_target(node: Node2D) -> void:
	if node == selected_target:
		return
	_clear_ring()
	selected_target = node
	if node == null:
		return
	_target_ring = TargetRing.new()
	node.add_child(_target_ring)

## Skill vừa ra chiêu vào `node`: nếu là quái/người chơi khác thật (không phải điểm ngắm ảo) thì chọn làm mục tiêu.
func mark_cast_target(node: Node2D) -> void:
	if node != null and node != self and _is_valid_target(node) and (node.is_in_group("enemies") or node.is_in_group("other_players")):
		set_target(node)

func clear_target() -> void:
	set_target(null)

func _clear_ring() -> void:
	if _target_ring != null and is_instance_valid(_target_ring):
		_target_ring.queue_free()
	_target_ring = null

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
	_set_move_target(get_canvas_transform().affine_inverse() * screen_position)

func _set_move_target(world_position: Vector2, keep_path: bool = false) -> void:
	if not keep_path:
		_show_route = false
		_path.clear()  ## bấm điểm mới / kéo chuột -> bỏ lộ trình tự đi cũ
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
func walk_to_feet(feet: Vector2) -> bool:
	var points := VltkWorld.find_path(global_position + Vector2(0, VltkWorld.FEET_OFFSET), feet)
	if points.is_empty():
		return false
	_path.clear()
	for p in points:
		_path.append(p - Vector2(0, VltkWorld.FEET_OFFSET))
	_path_final = _path[_path.size() - 1]
	var started := _advance_path()
	_show_route = started
	return started

## Lộ trình còn lại (điểm CHÂN): điểm đang hướng tới rồi tới các điểm sau — để bản đồ lớn vẽ đường chấm. Rỗng nếu không đang đi.
func get_route_feet() -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _has_move_target:
		return out
	out.append(_move_target + Vector2(0, VltkWorld.FEET_OFFSET))
	for p in _path:
		out.append(p + Vector2(0, VltkWorld.FEET_OFFSET))
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
			_set_move_target(get_global_mouse_position())
		else:
			_move_follow_held = false
	var to_target := _move_target - global_position
	## Điểm trung gian của lộ trình: tới gần (hoặc đã bước qua) thì sang điểm kế NGAY trong cùng khung hình — không trả về
	## 0 rồi mới đi tiếp, vì 1 khung "đứng yên" ở mỗi góc làm nhân vật chớp hoạt ảnh chạy/đứng (lắc).
	while not _path.is_empty() and (to_target.length() <= PATH_WAYPOINT_RADIUS or _passed_waypoint(to_target)):
		_advance_path()
		to_target = _move_target - global_position
	if to_target.length() <= MOVE_ARRIVE_DISTANCE:
		if not _move_follow_held and not _advance_path():
			_clear_move_target()
		return Vector2.ZERO
	## Kẹt: vận tốc thực sau move_and_slide gần 0 dù đang muốn chạy.
	if not is_attacking and get_real_velocity().length() < 5.0:
		_move_stuck_time += delta
		if _move_stuck_time >= MOVE_STUCK_TIMEOUT and not _move_follow_held:
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
	if _dead:
		return
	var camera_zoom: float = $Camera2D.zoom.x
	if not is_equal_approx(camera_zoom, _zoom_target):
		$Camera2D.zoom = Vector2.ONE * lerpf(camera_zoom, _zoom_target, minf(1.0, ZOOM_SMOOTHING * delta))
	var input_vector := _key_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		if _has_move_target:
			_clear_move_target()
		stop_follow()
	else:
		input_vector = _get_move_target_vector(delta)
		if input_vector == Vector2.ZERO:
			input_vector = _get_follow_vector()
		if input_vector == Vector2.ZERO:
			input_vector = _get_auto_chase_vector()
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
	var speed := SPEED * (1.0 + combat_stats.move_speed_p / 100.0) * status_controller.move_speed_multiplier
	if _is_jumping:
		velocity = _jump_dir * JUMP_SPEED
	elif _rush_time_left > 0.0 and input_vector != Vector2.ZERO:
		velocity = input_vector * SPEED * RUSH_SPEED_MULT
	else:
		velocity = Vector2.ZERO if is_attacking else input_vector * speed
	velocity = VltkWorld.slide_velocity(global_position + Vector2(0, VltkWorld.FEET_OFFSET), velocity, delta)
	move_and_slide()
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

	range_indicator.set_radius(get_current_range())

	if _key_pressed("toggle_auto"):
		is_auto_mode = not is_auto_mode

	## Bị làm chậm thì hồi chiêu cũng chậm theo — VLTK bỏ qua 1/2 frame MỌI hành động khi đóng băng.
	skill_controller.tick(delta * status_controller.move_speed_multiplier)
	skill_controller.tick_aura(self, delta)
	_tick_loop_skills(delta)
	var target := get_nearest_enemy()

	## Auto CHỈ tự động đòn chính — skill phụ (phím skill_1-4) luôn phải bấm thủ công, kể cả khi
	## đang bật Auto, xem SectSkillController.try_cast_auto().
	if is_auto_mode:
		if target and skill_controller.try_cast_auto(self, target):
			play_cast()
	elif _key_pressed("attack_skill"):
		## Không bắt buộc có mục tiêu ở đây — skill buff lên mình thi triển được khi không có quái gần,
		## SectSkillController._try_cast tự từ chối đòn đánh thiếu mục tiêu.
		if skill_controller.try_cast_main(self, get_cast_target(skill_controller.get_main_skill())):
			play_cast()

	## Phím skill_1-4 = 4 ô đầu của trang thanh skill đang chọn.
	var page_start: int = GameManager.local_profile.hotbar_page * PlayerProfile.HOTBAR_SLOTS_PER_PAGE 			if GameManager.local_profile else 0
	for i in range(4):
		if _key_pressed("skill_%d" % (i + 1)):
			var sub_skill: SkillDefinition = skill_controller.get_sub_skills()[page_start + i]
			if skill_controller.try_cast_skill(page_start + i, self, get_cast_target(sub_skill)):
				play_cast()

func update_facing(direction: Vector2) -> void:
	avatar.face(direction)

func update_move_animation(input_vector: Vector2) -> void:
	var anim_name := "run" if input_vector != Vector2.ZERO else "stand"
	if avatar.action != anim_name:
		avatar.play(anim_name)

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

## Mục tiêu khi người chơi TỰ ra chiêu (phím / nút skill), theo khung "Tùy chỉnh kỹ năng":
##   - Đánh theo hướng trước mặt: luôn là 1 điểm phía trước mặt (không nhắm quái).
##   - Mặc định (MỌI skill đánh): quái gần nhất trong tầm của skill đó; không có quái thì thi triển theo HƯỚNG NHÌN của
##     nhân vật, tới đúng tầm AttackRadius của skill (điểm ảo phía trước mặt) — như VLTK gốc khi bấm skill không chọn địch.
func get_cast_target(skill: SkillDefinition = null) -> Node2D:
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
var _aim_arrow: AimArrow

func set_aim(dir: Vector2) -> void:
	aim_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO
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
	_aim_arrow.set_aim(aim_dir if _is_ranged_skill(main_skill) else Vector2.ZERO, global_position + Vector2(0, 30), _aim_length(main_skill))

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
	return get_skill_radius(skill) if skill != null and skill.vltk_attack_radius > 0 else CAST_POINT_DISTANCE

## Điểm ảo theo hướng ngắm (thay cho get_cast_target) — dùng khi đang giữ kéo nút chính. Dùng LẠI 1 node cho mọi lần bắn (skill chỉ đọc vị
## trí lúc ra chiêu) để không sinh hàng trăm node khi đánh liên tục.
var _aim_point: Node2D

func make_aim_target(skill: SkillDefinition = null) -> Node2D:
	var d := (aim_dir if aim_dir != Vector2.ZERO else last_direction).normalized()
	var distance := get_skill_radius(skill) if skill != null and skill.vltk_attack_radius > 0 else CAST_POINT_DISTANCE
	var logic := Vector2(d.x, d.y * 2.0).normalized() * distance
	if _aim_point == null or not is_instance_valid(_aim_point):
		_aim_point = Node2D.new()
		_aim_point.set_meta("cast_point", true)
		get_parent().add_child(_aim_point)
	_aim_point.global_position = global_position + Vector2(logic.x, logic.y * 0.5)
	return _aim_point

## Điểm mục tiêu ảo phía trước mặt (meta "cast_point" — SectSkillCast/bùa nhận biết để không đuổi/áp trạng thái
## lên nó); tự huỷ sau vài giây.
const CAST_POINT_DISTANCE := 220.0
func _make_cast_point(skill: SkillDefinition = null) -> Node2D:
	var point := Node2D.new()
	point.set_meta("cast_point", true)
	get_parent().add_child(point)
	## Cách người thi triển đúng bằng tầm skill THEO CHUẨN LOGIC VLTK (dọc nhân đôi): đổi hướng nhìn sang logic rồi về
	## màn hình — hướng chéo/dọc không bị kéo dài quá tầm.
	var distance := get_skill_radius(skill) if skill != null and skill.vltk_attack_radius > 0 else CAST_POINT_DISTANCE
	var d := last_direction.normalized()
	var logic := Vector2(d.x, d.y * 2.0).normalized() * distance
	point.global_position = global_position + Vector2(logic.x, logic.y * 0.5)
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
	avatar.play("attack" if physical else "cast", duration)
	return avatar.get_action_duration() if duration <= 0.0 else duration

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
	else:
		return
	avatar.play("stand")

## Điểm chân nhân vật (avatar đặt lệch xuống so với gốc node) — bộ máy chiêu VLTK lấy làm toạ độ người thi triển.
func get_ground_position() -> Vector2:
	return avatar.global_position

## Tầm đánh = AttackRadius gốc của skill (đơn vị logic VLTK: ngang 1 px = 1 đơn vị, dọc 1 px = 2 đơn vị). Skill chưa có
## dữ liệu tầm thì dùng base_range cũ. Nâng cấp tầm (PlayerStats.range_multiplier) vẫn nhân lên.
func get_skill_radius(skill: SkillDefinition) -> float:
	var radius := float(skill.vltk_attack_radius) if skill != null and skill.vltk_attack_radius > 0 else base_range
	return radius * PlayerStats.range_multiplier

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
	if is_attacking or is_casting or _is_jumping or status_controller.is_stunned:
		return
	var aura_claimed := false
	for i in PlayerProfile.LOOP_SLOT_COUNT:
		if not skill_controller.loop_enabled[i]:
			continue
		var skill := skill_controller.get_loop_skill(i)
		if skill == null:
			continue
		var target: Node2D = null
		if skill.is_aura:
			if aura_claimed or skill_controller.is_aura_active(skill):
				aura_claimed = true
				continue
			aura_claimed = true
		elif skill.target_enemy:
			target = get_nearest_enemy(get_skill_radius(skill))
			if target == null:
				continue
		elif status_controller.has_state(skill.id):
			continue
		if skill_controller.try_cast_loop(skill, self, target):
			play_cast()
			return

func get_current_range() -> float:
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
	if chosen != null:
		var cd: Vector2 = chosen.global_position - global_position
		if cd.x * cd.x + cd.y * cd.y * 4.0 <= max_sq:
			return chosen
	for enemy in enemies:
		var d: Vector2 = enemy.global_position - global_position
		var distance_sq := d.x * d.x + d.y * d.y * 4.0
		if distance_sq <= max_sq and distance_sq < best_sq:
			best_sq = distance_sq
			nearest = enemy
	return nearest

func heal(amount: float) -> void:
	health = min(max_health, health + amount)

## Nhận 1 đòn tấn công THẬT — chạy đúng pipeline CombatFormulas.resolve_damage (CHÍNH XÁC 100%
## VLTK: tương khắc Ngũ Hành, % kháng, chí mạng...). `attacker_stats` là CombatantStats của bên gây
## damage (Enemy dùng CombatantStats.from_enemy_tier(), Player khác dùng combat_stats của chính nó
## khi PvP online sau này) — bắt buộc truyền vào để roll trúng/né đúng AttackRating vs Defense của
## CHÍNH player này, không còn dùng % giảm sát thương cố định (PlayerDefenseStats cũ, đã xoá).
## mods: phần phụ của đòn skill — xem Enemy.take_damage_from() / CombatFormulas.HitModifiers.
func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.PHYSICS,
		attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM,
		mods: CombatFormulas.HitModifiers = null) -> void:
	## Đang nhảy (bay trên không): miễn nhiễm mọi sát thương.
	if _dead or is_invincible or _is_jumping:
		return
	var final_damage := HitResolver.receive(self, combat_stats, int(health), attacker_stats,
			min_damage, max_damage, damage_type, attacker_element, mods)
	if final_damage == HitResolver.MISSED:
		spawn_miss_text()
		return
	if final_damage == 0:
		return  ## đòn chỉ mang trạng thái (bùa)

	health -= final_damage
	if health <= 0:
		die()
	else:
		_on_hurt()
		start_invincibility()

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
	var spawn_position := global_position + Vector2(0, -20)
	ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), spawn_position, func(number): number.set_miss())

## Gọi bởi StatusEffectController khi trúng DOT (nếu về sau player bị debuff từ boss).
func take_status_damage(amount: float, _effect_id: String) -> void:
	if _dead or _is_jumping:
		return  ## đang bay: bỏ qua cả sát thương trạng thái (độc, cháy...)
	health -= amount
	if health <= 0:
		die()

func start_invincibility() -> void:
	is_invincible = true
	var blink_interval := INVINCIBLE_DURATION / (INVINCIBLE_BLINKS * 2.0)
	for i in range(INVINCIBLE_BLINKS * 2):
		avatar.modulate = Color(1, 0.3, 0.3, 1) if i % 2 == 0 else Color(1, 1, 1, 1)
		await get_tree().create_timer(blink_interval).timeout
	avatar.modulate = Color(1, 1, 1, 1)
	is_invincible = false

## Chết: KHÔNG xoá nhân vật — giữ nguyên cảnh vật, nhân vật nằm tại chỗ (tối tím), quái dừng tay (is_game_over), hiện bảng
## "Bạn đã bị trọng thương!" + "Về thành dưỡng sức" (DeathPopup).
var _dead := false

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
	clear_target()
	stop_follow()
	is_auto_mode = false
	aim_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	avatar.play("sit")
	avatar.modulate = Color(0.75, 0.4, 0.95, 1.0)
	GameManager.notify_game_over()
	DeathPopup.show_for(self)

## Hình trạng thái (StateSpecialId) của hào quang đang bật — gắn lên người suốt lúc hào quang còn bật.
var _aura_sprite: VltkStateSprite = null
var _aura_sprite_state: int = 0

func _refresh_aura_sprite() -> void:
	var profile := GameManager.local_profile
	var state_id := 0
	if profile and profile.active_aura_id != "":
		var sect := SectRegistry.get_by_id(profile.sect_id)
		if sect:
			for skill in sect.skills:
				if skill.id == profile.active_aura_id:
					state_id = skill.vltk_state_special_id
					break
	if state_id == _aura_sprite_state and (state_id == 0 or _aura_sprite != null):
		return
	if _aura_sprite != null and is_instance_valid(_aura_sprite):
		_aura_sprite.queue_free()
	_aura_sprite = VltkStateSprite.attach(self, state_id) if state_id > 0 else null
	_aura_sprite_state = state_id

# ------------------------------------------------------------ nhảy / ngựa / đi theo

## Bị trúng đòn: đang ngồi thì đứng dậy (KNpc::DoHurt kết thúc bằng DoStand).
func _on_hurt() -> void:
	avatar.play_event_sound("hurt")
	if _is_sitting:
		_stand_up()

func can_cast() -> bool:
	return not _is_jumping

func _jump_height() -> float:
	var t := _jump_time * VLTK_FPS
	var v0 := JUMP_GRAVITY * (_jump_frames - 1) / 2.0
	return maxf((v0 * t - JUMP_GRAVITY * t * t / 2.0) / 8.0, 0.0)

## Nhảy theo hướng đang chạy/đang quay. false = đang bận (đánh, ra chiêu, choáng, đang nhảy).
func start_jump(frames: int = JUMP_DEFAULT_FRAMES) -> bool:
	if _is_jumping or is_attacking or is_casting or status_controller.is_stunned:
		return false
	## Trên ngựa không nhảy được.
	if avatar.is_riding():
		_notice("Đang cưỡi ngựa, không thể nhảy")
		return false
	_is_sitting = false
	var dir := _key_vector("move_left", "move_right", "move_up", "move_down")
	_jump_dir = (dir if dir != Vector2.ZERO else last_direction).normalized()
	last_direction = _jump_dir
	_jump_frames = clampi(frames, 2, JUMP_MAX_FRAMES)
	_jump_time = 0.0
	_air_height = 0.0
	_is_jumping = true
	_clear_move_target()
	stop_follow()
	avatar.face(_jump_dir)
	avatar.play("jump", _jump_frames / VLTK_FPS)  ## co giãn động tác cho vừa đúng thời gian bay
	_apply_name_y()
	return true

func _tick_jump(delta: float) -> void:
	_jump_time += delta
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

## "Theo sau" từ menu người chơi: đi theo đúng người này.
func start_follow(node: Node2D) -> void:
	if node == null or node == self:
		return
	follow_target = node
	_notice("Đi theo %s" % (node.display_name if "display_name" in node else node.name))

func stop_follow() -> void:
	follow_target = null

func is_following() -> bool:
	return follow_target != null

## AUTO "DÍ THEO QUÁI" (KPlayerAI::FollowAttack gốc, m_bFollowTarget): đang bật Auto mà quái nằm NGOÀI tầm skill nhưng còn trong
## vùng quét AUTO_CHASE_RADIUS thì tự chạy tới quái gần nhất, tới khi vào tầm (85% tầm skill) thì dừng để ra chiêu. Đo khoảng
## cách theo chuẩn logic VLTK (dọc nhân đôi). Phím di chuyển / bấm điểm trên bản đồ luôn ưu tiên và tạm dừng việc đuổi.
const AUTO_CHASE_RADIUS := 800.0
const AUTO_CHASE_STOP_RATIO := 0.85

func _get_auto_chase_vector() -> Vector2:
	if not is_auto_mode or is_attacking or is_casting or _is_jumping or status_controller.is_stunned:
		return Vector2.ZERO
	var enemy := get_nearest_enemy(AUTO_CHASE_RADIUS)
	if enemy == null:
		return Vector2.ZERO
	var d: Vector2 = enemy.global_position - global_position
	var logic_distance := sqrt(d.x * d.x + d.y * d.y * 4.0)
	if logic_distance <= get_current_range() * AUTO_CHASE_STOP_RATIO:
		return Vector2.ZERO
	return d.normalized()

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

## Hồi máu khi ngồi: mỗi SIT_TICK hồi max_health * 3/1000 (tối thiểu 1) — KNpc::ProcessState gốc.
## (Game chưa trừ nội lực nên chưa có phần hồi nội lực.)
func _tick_sit(delta: float) -> void:
	_sit_time += delta
	while _sit_time >= SIT_TICK:
		_sit_time -= SIT_TICK
		heal(maxf(1.0, floorf(max_health * SIT_HEAL_PER_MILLE / 1000.0)))
