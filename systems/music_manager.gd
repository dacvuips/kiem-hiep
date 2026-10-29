extends Node
## Nhạc nền (autoload). 2 player luân phiên để chuyển bài mượt (crossfade); mp3 tự lặp.
## Nhạc là trình bày phía client — không ảnh hưởng logic/đồng bộ online.

const BUS_NAME := &"Music"
const FADE_SECONDS := 1.5
const SILENT_DB := -60.0
## Âm lượng gốc trong MusicSet.txt là 0..100 (93 mặc định) -> dB.
const MASTER_OFFSET_DB := -6.0
## Bật/tắt nhạc là cài đặt của máy (không theo nhân vật) — lưu trong user://settings.cfg.
const SETTINGS_PATH := "user://settings.cfg"

## Danh sách nhạc nền gốc tại giao diện Đăng Nhập & Chọn Server (theo LaunchGame.ini của VLTK gốc)
const TITLE_TRACKS: Array[String] = [
	"music001.mp3", # Giấc Mộng Thời Trai (Lam Trường)
	"music002.mp3", # Tìm Em Trong Giấc Mơ (Lam Trường)
	"music003.mp3", # Kiếm Hiệp Tình
]
const DEFAULT_TITLE_TRACK := "music001.mp3"

signal enabled_changed(on: bool)
signal volume_changed(vol: float)

## false = tắt tiếng bus Music (bài vẫn chạy ngầm nên bật lại là nghe tiếp, không phải nạp lại).
var enabled := true:
	set(v):
		if v == enabled:
			return
		enabled = v
		_apply_mute()
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("audio", "music", enabled)
		cfg.save(SETTINGS_PATH)
		enabled_changed.emit(enabled)

## Âm lượng nhạc nền: 0.0 .. 1.0 (0% .. 100%)
var volume: float = 1.0:
	set(v):
		var clamped := clampf(v, 0.0, 1.0)
		if is_equal_approx(clamped, volume):
			return
		volume = clamped
		_apply_volume()
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("audio", "music_volume", volume)
		cfg.save(SETTINGS_PATH)
		volume_changed.emit(volume)

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _tween: Tween

func _ready() -> void:
	if AudioServer.get_bus_index(BUS_NAME) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, &"Master")
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		enabled = bool(cfg.get_value("audio", "music", true))
		volume = float(cfg.get_value("audio", "music_volume", 1.0))
	_apply_mute()
	_apply_volume()
	_ensure_players()

func _ensure_players() -> void:
	if _players.size() >= 2:
		return
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_NAME
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)

func toggle() -> void:
	enabled = not enabled

func _apply_mute() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx != -1:
		AudioServer.set_bus_mute(idx, not enabled)

func _apply_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx != -1:
		var db := linear_to_db(clampf(volume, 0.0001, 1.0)) if volume > 0.0001 else -80.0
		AudioServer.set_bus_volume_db(idx, db)

## Phát bài `file` (tên trong audio/vltk/music, vd "music210.mp3"); đang phát đúng bài này thì giữ nguyên.
func play(file: String, volume_percent: int = 93) -> void:
	if file == "":
		return
	_ensure_players()
	var active_p := _players[_active] if _players.size() > _active else null
	if file == _current and active_p != null and active_p.playing:
		return
	var path := VltkSound.MUSIC_DIR + file
	var stream: AudioStreamMP3 = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStreamMP3
	if stream == null and FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			stream = AudioStreamMP3.new()
			stream.data = bytes
	if stream == null:
		push_warning("MusicManager: không thấy '%s'" % path)
		return
	stream.loop = true
	_current = file
	var old := _players[_active]
	_active = 1 - _active
	var incoming := _players[_active]
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	var target_db := linear_to_db(clampf(volume_percent / 100.0, 0.0, 1.0)) + MASTER_OFFSET_DB
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(incoming, "volume_db", target_db, FADE_SECONDS)
	if old.playing:
		_tween.tween_property(old, "volume_db", SILENT_DB, FADE_SECONDS)
		_tween.chain().tween_callback(old.stop)

## Phát nhạc nền gốc tại giao diện Đăng Nhập & Chọn Máy Chủ (LaunchGame.ini gốc)
## Giữ nguyên bài đang phát liền mạch qua các màn hình, không ngắt bài giữa chừng.
func play_title_music(track_name: String = "") -> void:
	var active_p := _players[_active] if _players.size() > _active else null
	if _current in TITLE_TRACKS and active_p != null and active_p.playing:
		return
	var chosen := track_name
	if chosen == "" or not (chosen in TITLE_TRACKS):
		chosen = DEFAULT_TITLE_TRACK
	play(chosen, 93)

## Nhạc của map VLTK `map_id` (MusicSet.txt); nhiều bài thì chọn ngẫu nhiên. false nếu map không có nhạc.
func play_map(map_id: int) -> bool:
	var tracks := VltkSound.map_music(map_id)
	if tracks.is_empty():
		return false
	var t: Dictionary = tracks.pick_random()
	play(str(t["file"]), int(t.get("volume", 93)))
	return true

func stop(fade: float = FADE_SECONDS) -> void:
	_current = ""
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for p in _players:
		if p.playing:
			_tween.tween_property(p, "volume_db", SILENT_DB, fade)
	_tween.chain().tween_callback(func() -> void:
		for p in _players:
			p.stop())
