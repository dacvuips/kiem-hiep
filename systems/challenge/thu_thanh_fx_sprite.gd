extends Sprite2D
class_name ThuThanhFxSprite

## RENDERER HOẠT ẢNH HIỆU ỨNG CHIÊU THỨC THẬT VLTK (SKILL FX)
## Cắt từng frame từ spritesheet và xoay hướng chuẩn theo 64 hướng VLTK gốc.

const ANIMS_DATA_PATH := "res://data/skill_fx/anims.json"
const PNG_DIR := "res://assets/skill_fx/"

static var _anims_cache: Dictionary = {}
static var _textures_cache: Dictionary = {}

var anim_key: String = ""
var anim_data: Dictionary = {}
var spr_dirs: int = 1
var total_frames: int = 1
var per_dir_frames: int = 1
var frame_size: Vector2i = Vector2i(64, 64)
var frame_offset: Vector2 = Vector2.ZERO
var cols: int = 1
var current_dir: int = 48   ## Mặc định 48 = bay sang phải trong hệ 64 hướng VLTK

var anim_timer: float = 0.0
var fps: float = 18.0
var loop: bool = true
var is_finished: bool = false

signal finished()

static func get_anim_info(key: String) -> Dictionary:
	if _anims_cache.is_empty():
		if FileAccess.file_exists(ANIMS_DATA_PATH):
			var text := FileAccess.get_file_as_string(ANIMS_DATA_PATH)
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				_anims_cache = parsed
	return _anims_cache.get(key, {})

static func get_fx_texture(key: String) -> Texture2D:
	if _textures_cache.has(key):
		return _textures_cache[key]
	var path := PNG_DIR + key + ".png"
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if err == OK:
		var tex := ImageTexture.create_from_image(img)
		_textures_cache[key] = tex
		return tex
	return null

func setup_fx(p_key: String, p_dir: int = 48, p_loop: bool = true, p_fps: float = 18.0) -> bool:
	anim_key = p_key
	current_dir = p_dir
	loop = p_loop
	fps = p_fps
	anim_timer = 0.0
	is_finished = false

	anim_data = get_anim_info(anim_key)
	if anim_data.is_empty():
		return false

	var tex := get_fx_texture(anim_key)
	if tex == null:
		return false

	texture = tex
	region_enabled = true
	centered = false

	cols = maxi(1, int(anim_data.get("cols", 1)))
	spr_dirs = maxi(1, int(anim_data.get("dirs", 1)))
	total_frames = maxi(1, int(anim_data.get("frames", 1)))
	per_dir_frames = maxi(1, total_frames / spr_dirs)

	var sz: Array = anim_data.get("size", [64, 64])
	frame_size = Vector2i(int(sz[0]), int(sz[1]))

	var ofs: Array = anim_data.get("offset", [0, 0])
	frame_offset = Vector2(float(ofs[0]), float(ofs[1]))

	# Nếu hiệu ứng phát sáng (additive)
	if anim_data.get("additive", false):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	_update_frame(0)
	return true

func set_motion_vector(vec: Vector2) -> void:
	if vec.length_squared() < 0.001:
		current_dir = 48
		return
	# Ánh xạ vector vận tốc sang 64 hướng VLTK (0 = xuống, 16 = trái, 32 = lên, 48 = phải)
	var angle := atan2(-vec.x, vec.y)
	if angle < 0.0:
		angle += TAU
	current_dir = wrapi(roundi(angle * 64.0 / TAU), 0, 64)

func _process(delta: float) -> void:
	if is_finished:
		return

	anim_timer += delta * fps
	var cur_frame_idx := int(anim_timer)

	if not loop and cur_frame_idx >= per_dir_frames:
		is_finished = true
		visible = false
		finished.emit()
		queue_free()
		return

	_update_frame(cur_frame_idx)

func _update_frame(frame_counter: int) -> void:
	if anim_data.is_empty() or texture == null:
		return

	var frame_in_dir := frame_counter % per_dir_frames

	# Tính hướng hiển thị ảnh từ 64 hướng sang spr_dirs hướng
	var dir_idx := 0
	if spr_dirs > 1:
		var step := 64 / spr_dirs
		var d := current_dir / step
		if current_dir % step >= 32 / spr_dirs:
			d += 1
		dir_idx = 0 if d >= spr_dirs else d

	var final_index := dir_idx * per_dir_frames + frame_in_dir
	if final_index >= total_frames:
		final_index = total_frames - 1

	var col_idx := final_index % cols
	var row_idx := final_index / cols

	region_rect = Rect2(col_idx * frame_size.x, row_idx * frame_size.y, frame_size.x, frame_size.y)
	position = frame_offset
