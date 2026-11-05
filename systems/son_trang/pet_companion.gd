extends Node2D
class_name PetCompanion
## Thú Cưng / Vật Nuôi Đồng Hành theo sau nhân vật khi di chuyển ở ngoài bản đồ.
## - Tự động chạy theo nhân vật chính, 64 hướng VLTK chuẩn xác.
## - Tự động đổi trạng thái Đi bộ (walk) khi bám theo và Đứng thở (stand) khi dừng lại nghỉ ngơi.
## - Nếu bị tụt lại quá xa (nhân vật cưỡi ngựa nhanh hoặc dùng phù), thú cưng sẽ lập tức đuổi kịp.
## - Nhấp chuột vào thú cưng để tương tác, vuốt ve tăng gắn kết.

var companion_data: Dictionary = {}
var target_player: Node2D = null

var sprite: MonsterSprite = null
var _name_tag: Label = null

var current_dir64: int = 0
var anim_timer: float = 0.0
var move_speed: float = 160.0
var is_moving: bool = false

const STOP_DISTANCE: float = 55.0
const START_DISTANCE: float = 75.0
const TELEPORT_DISTANCE: float = 550.0

func _init(data: Dictionary = {}) -> void:
	companion_data = data

func _ready() -> void:
	z_index = 5
	var res_id: String = str(companion_data.get("res", companion_data.get("monster_res", "ani063")))
	var pet_name: String = str(companion_data.get("name", "Thú Cưng"))

	sprite = MonsterSprite.new()
	sprite.scale = Vector2(0.85, 0.85)
	add_child(sprite)
	sprite.set_resource(res_id)
	sprite.set_pose("stand", current_dir64, 0.0)

	# Nhãn tên thú cưng trên đầu
	_name_tag = Label.new()
	_name_tag.text = "🐾 %s" % pet_name
	_name_tag.custom_minimum_size = Vector2(160, 24)
	_name_tag.position = Vector2(-80, -48)
	_name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_tag.add_theme_font_size_override("font_size", 11)
	_name_tag.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	_name_tag.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_tag.add_theme_constant_override("outline_size", 2)
	add_child(_name_tag)

	# Tìm người chơi nếu chưa được gán
	if target_player == null:
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if target_player != null:
			global_position = target_player.global_position + Vector2(-40, 20)

func _process(delta: float) -> void:
	if sprite == null:
		return

	anim_timer += delta
	z_index = clampi(int(global_position.y / 20.0), -4000, 4000)

	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if target_player == null:
			return

	var player_pos := target_player.global_position
	var dist := global_position.distance_to(player_pos)

	# Nếu cách quá xa (nhân vật teleport, cưỡi ngựa phóng nhanh) -> tức thời đuổi kịp
	if dist > TELEPORT_DISTANCE:
		global_position = player_pos + Vector2(randf_range(-40, 40), randf_range(20, 45))
		is_moving = false
		return

	if not is_moving and dist > START_DISTANCE:
		is_moving = true
	elif is_moving and dist <= STOP_DISTANCE:
		is_moving = false

	# Hướng nhìn và di chuyển
	if is_moving:
		# Lấy tốc độ theo người chơi nếu người chơi chạy nhanh
		var current_speed := move_speed
		if "current_speed" in target_player:
			current_speed = maxf(move_speed, float(target_player.current_speed) * 1.1)

		var target_dest := player_pos + Vector2(-35, 15)
		var d := VltkMath.dir_between(global_position, target_dest)
		if d >= 0:
			current_dir64 = d

		global_position = global_position.move_toward(target_dest, current_speed * delta)
		var walk_prog := fmod(anim_timer * 1.6, 1.0)
		var ok := sprite.set_pose("walk", current_dir64, walk_prog)
		if not ok:
			sprite.set_pose("stand", current_dir64, walk_prog)
	else:
		# Đứng cạnh nghỉ ngơi, quay mặt nhẹ nhàng về hướng người chơi
		var d := VltkMath.dir_between(global_position, player_pos)
		if d >= 0:
			current_dir64 = d
		var stand_prog := fmod(anim_timer * 0.6, 1.0)
		sprite.set_pose("stand", current_dir64, stand_prog)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		if global_position.distance_to(mouse_pos) <= 38.0:
			_on_pet_clicked()
			get_viewport().set_input_as_handled()

func _on_pet_clicked() -> void:
	var pet_name: String = str(companion_data.get("name", "Thú Cưng"))
	var cheer_messages = [
		"🐾 %s vui mừng vẫy đuôi quấn quýt bên chân bạn!" % pet_name,
		"✨ %s dụi đầu vào tay bạn thật âu yếm!" % pet_name,
		"🌿 %s trung thành đồng hành cùng bạn bôn tẩu giang hồ!" % pet_name,
		"💖 Bạn xoa đầu %s, nó phát ra tiếng kêu thích thú!" % pet_name
	]
	var msg: String = cheer_messages[randi() % cheer_messages.size()]
	_show_pet_floating_text(msg)

func _show_pet_floating_text(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(-110, -75)
	lbl.custom_minimum_size = Vector2(220, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 80
	add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 30, 1.6)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.6)
	tween.tween_callback(lbl.queue_free)
