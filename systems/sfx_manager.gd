extends Node
## Phát âm thanh hiệu ứng (SFX) có vị trí trong thế giới 2D — đối xứng với VfxManager nhưng cho
## tai thay vì mắt. Mọi nơi muốn phát tiếng (cast skill, trúng đòn...) gọi qua đây, không tự
## tạo AudioStreamPlayer riêng.
##
## Hiệu năng: dùng 1 pool CỐ ĐỊNH VOICE_COUNT AudioStreamPlayer2D tạo sẵn lúc khởi động (không
## new/free node mỗi lần phát). Khi hết voice rảnh thì "cướp" voice cũ nhất thay vì tạo thêm.
## Chống spam: cùng 1 stream không phát lại trong MIN_REPEAT_INTERVAL giây và không vang quá
## MAX_INSTANCES_PER_STREAM bản cùng lúc — VD Ảo Kiếm 6 lưỡi trúng cùng frame chỉ ra 1 tiếng
## thay vì 6 tiếng chồng nhau gây rè/to bất thường.
##
## Online: SFX thuần là trình bày phía client (giống VFX), không ảnh hưởng logic/đồng bộ —
## skill của player khác vẫn phát qua đây với vị trí của họ, tự nhỏ dần theo khoảng cách.

const VOICE_COUNT := 24
const MAX_DISTANCE := 1400.0
const MIN_REPEAT_INTERVAL_MS := 45
const MAX_INSTANCES_PER_STREAM := 3
## Giới hạn số âm thanh được kích hoạt mới trong cùng 1 frame để chống vỡ tiếng (audio clipping/spikes)
const MAX_STARTS_PER_FRAME := 4
const MIN_UI_REPEAT_MS := 40
## Lệch cao độ ngẫu nhiên ±8% mỗi lần phát — tránh cảm giác "lặp máy móc" khi 1 skill bắn liên tục.
const DEFAULT_PITCH_JITTER := 0.08
const BUS_NAME := &"SFX"

## Âm mặc định theo hệ nguyên tố — skill nào không gán cast_sfx/hit_sfx riêng sẽ dùng âm của
## hệ cuối cùng (sau khi Element Gem đổi hệ). Thay âm cả 1 hệ chỉ cần ghi đè file cùng tên.
const SKILL_SFX_DIR := "res://audio/sfx/skill/"
const ELEMENT_FILE_PREFIX := {
	ElementTypes.ElementType.KIM: "kim",
	ElementTypes.ElementType.MOC: "moc",
	ElementTypes.ElementType.THUY: "thuy",
	ElementTypes.ElementType.HOA: "hoa",
	ElementTypes.ElementType.THO: "tho",
}

## Âm giao diện (không có vị trí): vài player 2D-less luân phiên.
const UI_VOICE_COUNT := 4
var _ui_voices: Array[AudioStreamPlayer] = []
var _next_ui_voice: int = 0
var _last_ui_played_ms: Dictionary = {}  ## AudioStream instance_id -> timestamp

var _voices: Array[AudioStreamPlayer2D] = []
var _next_voice: int = 0
var _last_played_ms: Dictionary = {}  ## AudioStream instance_id -> Time.get_ticks_msec()
var _stream_counts: Dictionary = {}   ## AudioStream instance_id -> int (số voice đang phát)
var _element_cast: Dictionary = {}  ## ElementTypes.ElementType -> AudioStream
var _element_hit: Dictionary = {}

var _last_frame_ticks: int = -1
var _starts_this_frame: int = 0

func _ready() -> void:
	var bus := BUS_NAME if AudioServer.get_bus_index(BUS_NAME) != -1 else &"Master"
	for i in VOICE_COUNT:
		var voice := AudioStreamPlayer2D.new()
		voice.bus = bus
		voice.max_distance = MAX_DISTANCE
		voice.finished.connect(func(): _on_voice_finished(voice))
		add_child(voice)
		_voices.append(voice)

	for i in UI_VOICE_COUNT:
		var ui_voice := AudioStreamPlayer.new()
		ui_voice.bus = bus
		add_child(ui_voice)
		_ui_voices.append(ui_voice)

	for element in ELEMENT_FILE_PREFIX:
		var prefix: String = ELEMENT_FILE_PREFIX[element]
		_element_cast[element] = _try_load(SKILL_SFX_DIR + prefix + "_cast.wav")
		_element_hit[element] = _try_load(SKILL_SFX_DIR + prefix + "_hit.wav")

func _on_voice_finished(voice: AudioStreamPlayer2D) -> void:
	if voice.stream != null:
		var key := voice.stream.get_instance_id()
		var count: int = _stream_counts.get(key, 0)
		if count > 1:
			_stream_counts[key] = count - 1
		else:
			_stream_counts.erase(key)

## Thiếu file thì im lặng (trả null) thay vì crash — cho phép xoá/đổi tên âm thanh lúc làm game.
func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("SfxManager: không tìm thấy '%s'." % path)
		return null
	return load(path)

func _is_out_of_range(world_position: Vector2) -> bool:
	if world_position == Vector2.ZERO:
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var p := tree.get_first_node_in_group("player") as Node2D
	if p != null and is_instance_valid(p):
		return world_position.distance_to(p.global_position) > MAX_DISTANCE
	var vp := tree.root.get_viewport()
	if vp != null:
		var cam := vp.get_camera_2d()
		if cam != null and is_instance_valid(cam):
			return world_position.distance_to(cam.get_screen_center_position()) > MAX_DISTANCE
	return false

func play(stream: AudioStream, world_position: Vector2, volume_db: float = 0.0, pitch_jitter: float = DEFAULT_PITCH_JITTER, is_priority: bool = false) -> void:
	if stream == null:
		return
	if not is_priority and _is_out_of_range(world_position):
		return
	var now := Time.get_ticks_msec()
	var key := stream.get_instance_id()
	if now - int(_last_played_ms.get(key, -MIN_REPEAT_INTERVAL_MS)) < MIN_REPEAT_INTERVAL_MS:
		return
	if _count_playing(stream) >= MAX_INSTANCES_PER_STREAM:
		return

	# Giới hạn số âm thanh bắt đầu trong 1 frame để chống giật/vỡ âm thanh hỗn chiến
	var frame_idx := Engine.get_process_frames()
	if frame_idx != _last_frame_ticks:
		_last_frame_ticks = frame_idx
		_starts_this_frame = 0
	if not is_priority and _starts_this_frame >= MAX_STARTS_PER_FRAME:
		return
	if not is_priority:
		_starts_this_frame += 1

	_last_played_ms[key] = now

	var voice := _pick_voice()
	voice.stream = stream
	voice.global_position = world_position
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	_stream_counts[key] = int(_stream_counts.get(key, 0)) + 1
	voice.play()

## Tiếng giao diện (SoundList.txt, xem VltkSound.UI_*) — không theo vị trí trong thế giới.
func play_ui(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	var key := stream.get_instance_id()
	if now - int(_last_ui_played_ms.get(key, -MIN_UI_REPEAT_MS)) < MIN_UI_REPEAT_MS:
		return
	_last_ui_played_ms[key] = now
	var voice := _ui_voices[_next_ui_voice]
	_next_ui_voice = (_next_ui_voice + 1) % UI_VOICE_COUNT
	voice.stream = stream
	voice.volume_db = volume_db
	voice.play()

func play_skill_cast(stats: ResolvedSkillStats, world_position: Vector2, is_priority: bool = false) -> void:
	var stream: AudioStream = stats.cast_sfx if stats.cast_sfx else _element_cast.get(stats.element)
	play(stream, world_position, stats.sfx_volume_db, DEFAULT_PITCH_JITTER, is_priority)

func play_skill_hit(stats: ResolvedSkillStats, world_position: Vector2, is_priority: bool = false) -> void:
	var stream: AudioStream = stats.hit_sfx if stats.hit_sfx else _element_hit.get(stats.element)
	play(stream, world_position, stats.sfx_volume_db, DEFAULT_PITCH_JITTER, is_priority)

## Cho các hiệu ứng phụ không gắn với 1 skill cụ thể (VD tia sét aura của Skill Director).
func play_element_hit(element: ElementTypes.ElementType, world_position: Vector2, volume_db: float = 0.0, is_priority: bool = false) -> void:
	play(_element_hit.get(element), world_position, volume_db, DEFAULT_PITCH_JITTER, is_priority)

func _count_playing(stream: AudioStream) -> int:
	if stream == null:
		return 0
	return int(_stream_counts.get(stream.get_instance_id(), 0))

## Ưu tiên voice đang rảnh; hết rảnh thì dùng lại voice kế tiếp theo vòng tròn (cũ nhất).
func _pick_voice() -> AudioStreamPlayer2D:
	for i in VOICE_COUNT:
		var index := (_next_voice + i) % VOICE_COUNT
		if not _voices[index].playing:
			_next_voice = (index + 1) % VOICE_COUNT
			return _voices[index]
	var stolen := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	if stolen.playing and stolen.stream != null:
		var old_key := stolen.stream.get_instance_id()
		var count: int = _stream_counts.get(old_key, 0)
		if count > 1:
			_stream_counts[old_key] = count - 1
		else:
			_stream_counts.erase(old_key)
	return stolen
