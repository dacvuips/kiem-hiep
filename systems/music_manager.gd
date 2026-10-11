extends Node
## Nhạc nền (autoload). 2 player luân phiên để chuyển bài mượt (crossfade); mp3 tự lặp.
## Nhạc là trình bày phía client — không ảnh hưởng logic/đồng bộ online.

const BUS_NAME := &"Music"
const FADE_SECONDS := 1.5
const SILENT_DB := -60.0
## Âm lượng gốc trong MusicSet.txt là 0..100 (93 mặc định) -> dB.
const MASTER_OFFSET_DB := -6.0

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
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_NAME
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)

## Phát bài `file` (tên trong audio/vltk/music, vd "music210.mp3"); đang phát đúng bài này thì giữ nguyên.
func play(file: String, volume_percent: int = 93) -> void:
	if file == "" or file == _current:
		return
	var path := VltkSound.MUSIC_DIR + file
	if not ResourceLoader.exists(path):
		push_warning("MusicManager: không thấy '%s'" % path)
		return
	var stream := load(path) as AudioStreamMP3
	if stream == null:
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
