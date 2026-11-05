@tool
extends Node2D
## Showcase / Xem trước Đống Lửa VLTK trong Godot Editor và Game.
## Hiển thị đầy đủ các biến thể hoạt ảnh đống lửa trích xuất từ source gốc Võ Lâm Truyền Kỳ.

@export var play_animation: bool = true
@export var scale_factor: float = 1.0:
	set(v):
		scale_factor = v
		_update_scales()

var tan_lua_sprite: Sprite2D = null
var ho_lua_sprite: Sprite2D = null
var sjzh_sprite: Sprite2D = null
var yandi_sprite: Sprite2D = null

var timer_20: float = 0.0
var frame_20: int = 0
var timer_10: float = 0.0
var frame_10: int = 0
var timer_7: float = 0.0
var frame_7: int = 0

func _ready() -> void:
	_setup_showcase()

func _setup_showcase() -> void:
	for c in get_children():
		c.queue_free()
	
	# 1. Tàn Lửa VLTK Chuẩn (20 frames) - Trung tâm chính
	tan_lua_sprite = _create_flame_sprite(
		"res://assets/campfire/tan_lua_sheet.png",
		20,
		Vector2(0, -10),
		Vector2(0.45, 0.45),
		"🔥 TÀN LỬA TRẠI VLTK CHUẨN (20 Frames)"
	)
	
	# 2. Ngọn Lửa Chiến Hỏa VLTK (10 frames) - Bên Trái
	sjzh_sprite = _create_flame_sprite(
		"res://assets/campfire/sjzh_huo_sheet.png",
		10,
		Vector2(-260, 0),
		Vector2(1.8, 1.8),
		"🔥 CHIẾN HỎA VLTK (10 Frames)"
	)
	
	# 3. Hố Lửa VLTK HD (20 frames) - Bên Phải
	ho_lua_sprite = _create_flame_sprite(
		"res://assets/campfire/ho_lua_sheet.png",
		20,
		Vector2(260, 0),
		Vector2(0.45, 0.45),
		"🔥 HỐ LỬA VLTK (20 Frames)"
	)
	
	# 4. Ngọn Lửa Viêm Đế VLTK (7 frames) - Phía Dưới
	yandi_sprite = _create_flame_sprite(
		"res://assets/campfire/yandihuoyan_sheet.png",
		7,
		Vector2(0, 160),
		Vector2(1.8, 1.8),
		"🔥 VIÊM ĐẾ HỎA DIỄM (7 Frames)"
	)

func _create_flame_sprite(path: String, h_frames: int, pos: Vector2, p_scale: Vector2, label_text: String) -> Sprite2D:
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	
	var container := Node2D.new()
	container.position = pos
	add_child(container)
	
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = h_frames
	spr.frame = 0
	spr.scale = p_scale
	container.add_child(spr)
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(280, 24)
	lbl.position = Vector2(-140, 50)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	container.add_child(lbl)
	
	return spr

func _process(delta: float) -> void:
	if not play_animation:
		return
	
	# Loop 20 frames
	timer_20 += delta
	if timer_20 >= 0.08:
		timer_20 = 0.0
		frame_20 = (frame_20 + 1) % 20
		if tan_lua_sprite != null:
			tan_lua_sprite.frame = frame_20
		if ho_lua_sprite != null:
			ho_lua_sprite.frame = frame_20
	
	# Loop 10 frames
	timer_10 += delta
	if timer_10 >= 0.09:
		timer_10 = 0.0
		frame_10 = (frame_10 + 1) % 10
		if sjzh_sprite != null:
			sjzh_sprite.frame = frame_10
	
	# Loop 7 frames
	timer_7 += delta
	if timer_7 >= 0.10:
		timer_7 = 0.0
		frame_7 = (frame_7 + 1) % 7
		if yandi_sprite != null:
			yandi_sprite.frame = frame_7

func _update_scales() -> void:
	if tan_lua_sprite:
		tan_lua_sprite.scale = Vector2(0.45, 0.45) * scale_factor
	if ho_lua_sprite:
		ho_lua_sprite.scale = Vector2(0.45, 0.45) * scale_factor
	if sjzh_sprite:
		sjzh_sprite.scale = Vector2(1.8, 1.8) * scale_factor
	if yandi_sprite:
		yandi_sprite.scale = Vector2(1.8, 1.8) * scale_factor
