extends CanvasLayer
class_name CountdownOverlay

## Đếm ngược trước trận đấu (1 -> 2 -> 3 -> GO!) hiển thị giữa màn hình thay thế đếm số text.
## Sử dụng hình ảnh kiếm lệnh VLTK (1, 2, 3) và biểu tượng rực lửa "GO!".

signal step_changed(step: int)
signal go_started()
signal finished()

const COUNT_1_PATH := "res://art/countdown/count_1.png"
const COUNT_2_PATH := "res://art/countdown/count_2.png"
const COUNT_3_PATH := "res://art/countdown/count_3.png"
const COUNT_GO_PATH := "res://art/countdown/count_go.png"

const SFX_COUNT_PATH := "res://audio/sfx/skill/kim_hit.wav"
const SFX_GO_PATH := "res://audio/sfx/skill/fire_hit.wav"

const NUMBER_SIZE := Vector2(180, 180)
const GO_SIZE := Vector2(270, 180)

var _root: Control
var _glow_rect: TextureRect
var _tex_rect: TextureRect
var _current_tween: Tween
var _glow_tween: Tween
var _step_timer: float = 0.0
var _current_step: int = 0
var _is_running: bool = false
var _on_go_callback: Callable = Callable()
var _on_finish_callback: Callable = Callable()

var _textures: Dictionary = {}
var _sfx_count: AudioStream
var _sfx_go: AudioStream

static func start(parent: Node, on_go: Callable = Callable(), on_finish: Callable = Callable()) -> CountdownOverlay:
	if parent == null or not is_instance_valid(parent):
		return null
	var existing = parent.get_node_or_null("CountdownOverlay")
	if existing and is_instance_valid(existing):
		return existing as CountdownOverlay

	var overlay := CountdownOverlay.new()
	overlay.name = "CountdownOverlay"
	overlay._on_go_callback = on_go
	overlay._on_finish_callback = on_finish
	parent.add_child(overlay)
	overlay.run()
	return overlay

func _ready() -> void:
	layer = 125
	_load_resources()
	_build_ui()

func _load_resources() -> void:
	_textures[1] = _load_texture(COUNT_1_PATH)
	_textures[2] = _load_texture(COUNT_2_PATH)
	_textures[3] = _load_texture(COUNT_3_PATH)
	_textures[4] = _load_texture(COUNT_GO_PATH)

	if ResourceLoader.exists(SFX_COUNT_PATH):
		_sfx_count = load(SFX_COUNT_PATH) as AudioStream
	if ResourceLoader.exists(SFX_GO_PATH):
		_sfx_go = load(SFX_GO_PATH) as AudioStream

static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var global_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_p):
		var img := Image.new()
		var err := img.load(global_p)
		if err == OK:
			return ImageTexture.create_from_image(img)
	return null

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_glow_rect = TextureRect.new()
	_glow_rect.name = "GlowRect"
	_glow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_root.add_child(_glow_rect)

	_tex_rect = TextureRect.new()
	_tex_rect.name = "TexRect"
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_root.add_child(_tex_rect)

func _center_rect(rect: TextureRect, base_size: Vector2) -> void:
	rect.custom_minimum_size = base_size
	rect.size = base_size
	rect.pivot_offset = base_size * 0.5
	rect.anchor_left = 0.5
	rect.anchor_top = 0.5
	rect.anchor_right = 0.5
	rect.anchor_bottom = 0.5
	rect.offset_left = -base_size.x * 0.5
	rect.offset_top = -base_size.y * 0.5
	rect.offset_right = base_size.x * 0.5
	rect.offset_bottom = base_size.y * 0.5

func run() -> void:
	if _is_running:
		return
	_is_running = true
	_execute_sequence()

func _execute_sequence() -> void:
	# Bước 1: Số 1
	await _play_step(1, NUMBER_SIZE)
	if not _is_running:
		return

	# Bước 2: Số 2
	await _play_step(2, NUMBER_SIZE)
	if not _is_running:
		return

	# Bước 3: Số 3
	await _play_step(3, NUMBER_SIZE)
	if not _is_running:
		return

	# Bước 4: GO!
	await _play_go_step()

func _play_step(step: int, size: Vector2) -> void:
	_current_step = step
	step_changed.emit(step)

	var tex: Texture2D = _textures.get(step)
	if tex == null:
		await get_tree().create_timer(1.0).timeout
		return

	_center_rect(_tex_rect, size)
	_center_rect(_glow_rect, size)

	_tex_rect.texture = tex
	_glow_rect.texture = tex

	_play_audio(_sfx_count, 0.0)

	# Hiệu ứng nảy và rung cảm xúc
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()

	_tex_rect.scale = Vector2(0.25, 0.25)
	_tex_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	# Nảy lên mạnh (punch)
	_current_tween.tween_property(_tex_rect, "scale", Vector2(1.25, 1.25), 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(_tex_rect, "modulate:a", 1.0, 0.10)

	# Định vị lại kích thước chuẩn
	_current_tween.chain().tween_property(_tex_rect, "scale", Vector2(1.0, 1.0), 0.14)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Cuối giây: thu nhỏ nhẹ chuẩn bị sang số tiếp
	_current_tween.chain().tween_property(_tex_rect, "scale", Vector2(1.08, 1.08), 0.5)\
		.set_trans(Tween.TRANS_LINEAR)
	_current_tween.parallel().tween_property(_tex_rect, "modulate:a", 0.3, 0.2).set_delay(0.4)

	# Hiệu ứng sóng năng lượng mở rộng (shockwave glow)
	_glow_rect.scale = Vector2(1.0, 1.0)
	_glow_rect.modulate = Color(1.0, 0.95, 0.6, 0.7)
	_glow_tween = create_tween()
	_glow_tween.set_parallel(true)
	_glow_tween.tween_property(_glow_rect, "scale", Vector2(1.6, 1.6), 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(_glow_rect, "modulate:a", 0.0, 0.35)

	await get_tree().create_timer(1.0).timeout

func _play_go_step() -> void:
	_current_step = 4
	step_changed.emit(4)

	var tex: Texture2D = _textures.get(4)
	if tex != null:
		_center_rect(_tex_rect, GO_SIZE)
		_center_rect(_glow_rect, GO_SIZE)
		_tex_rect.texture = tex
		_glow_rect.texture = tex

	_play_audio(_sfx_go, 2.0)

	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()

	_tex_rect.scale = Vector2(0.3, 0.3)
	_tex_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.tween_property(_tex_rect, "scale", Vector2(1.35, 1.35), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(_tex_rect, "modulate:a", 1.0, 0.08)

	_current_tween.chain().tween_property(_tex_rect, "scale", Vector2(1.15, 1.15), 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Shockwave cho GO!
	_glow_rect.scale = Vector2(1.0, 1.0)
	_glow_rect.modulate = Color(1.0, 0.7, 0.2, 0.85)
	_glow_tween = create_tween()
	_glow_tween.set_parallel(true)
	_glow_tween.tween_property(_glow_rect, "scale", Vector2(1.7, 1.7), 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(_glow_rect, "modulate:a", 0.0, 0.4)

	# Kích hoạt trận đấu ngay khi chữ GO! bùng nổ
	go_started.emit()
	if _on_go_callback.is_valid():
		_on_go_callback.call()

	# Chờ hiển thị chữ GO trong 0.6 giây trước khi biến mất
	await get_tree().create_timer(0.6).timeout
	if not _is_running:
		return

	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(_tex_rect, "scale", Vector2(1.4, 1.4), 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(_tex_rect, "modulate:a", 0.0, 0.25)
	await fade_tween.finished

	finished.emit()
	if _on_finish_callback.is_valid():
		_on_finish_callback.call()
	queue_free()

func _play_audio(stream: AudioStream, vol_db: float = 0.0) -> void:
	if stream == null:
		return
	if Engine.has_singleton("SfxManager"):
		var sm = Engine.get_singleton("SfxManager")
		if sm and sm.has_method("play_ui"):
			sm.play_ui(stream, vol_db)
			return
	var player_node := AudioStreamPlayer.new()
	player_node.stream = stream
	player_node.volume_db = vol_db
	player_node.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(player_node)
	player_node.play()
	player_node.finished.connect(player_node.queue_free)

func cancel() -> void:
	_is_running = false
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	queue_free()
