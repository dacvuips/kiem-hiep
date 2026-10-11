extends Node2D
class_name CharacterAvatar
## Nhân vật GHÉP BỘ PHẬN kiểu VLTK: tối đa 11 lớp (đầu, tóc, vai, thân, tay trái/phải, vũ khí trái/phải, đầu/thân/
## mông ngựa) + bóng,
## mỗi lớp 1 Sprite2D cắt vùng (region) từ sheet PNG dùng chung (AvatarData). Gốc node = CHÂN nhân vật.
##
## Dùng chung cho player, người chơi khác (online: chỉ cần gửi 3 mã hình) và NPC người:
##   avatar.set_appearance(helm_res, armor_res, weapon_res, horse_res)   # mã hình, xem Equipment.get_appearance()
##                                 # horse_res >= 0 -> CƯỠI NGỰA: thêm 3 lớp ngựa + bộ động tác Ride*
##   avatar.play("run")            # stand/run lặp; hurt/die/attack/attack2/cast chạy 1 lần rồi phát action_finished
##   avatar.face(direction_vector) # 8 hướng
##   avatar.set_height(z)          # độ cao so với mặt đất (nhảy) — thân nâng lên, bóng ở lại dưới đất (m_Height gốc)
## Mọi lớp chạy CHUNG 1 bộ đếm frame (giống KNpcRes::Draw) và được sắp lại thứ tự vẽ theo hướng + frame (bảng thứ
## tự vẽ gốc) mỗi khi đổi.

signal action_finished(action: String)

## Ngưỡng (đơn vị = 1 hướng = 45°) để đổi hướng nhìn: > 0.5 nghĩa là phải vượt ranh giới thêm một chút.
const FACE_HYSTERESIS := 0.62
const LOOPING := ["stand", "run"]

@export var gender: String = "male"

var helm_res: int = -1
var armor_res: int = -1
var weapon_res: int = -1
var horse_res: int = -1  ## -1 = đi bộ
var direction: int = 0  ## hướng sprite 0..7: 0 = quay xuống, 2 = trái, 4 = quay lưng, 6 = phải (theo chiều kim đồng hồ)
var action: String = "stand"

var _data: AvatarData
var _vltk_action: String = ""
var _layers: Dictionary = {}       ## số lớp gốc -> Sprite2D
var _layer_part: Dictionary = {}   ## số lớp gốc -> tên bộ phận
var _layer_file: Dictionary = {}   ## số lớp gốc -> mô tả file đang dùng
var _shadow: Sprite2D
var _body: Node2D                  ## chứa mọi lớp trừ bóng — set_height nâng node này
var _shadow_file: Dictionary = {}
var _time: float = 0.0
var _speed: float = 1.0            ## hệ số tốc độ của động tác hiện tại (play với duration)
var _frames_per_dir: int = 1
var _frame: int = -1
var _finished: bool = false
## Giọng nói/tiếng động tác ("male"/"female"). Để trống = theo `gender` của bộ hình. Nhân vật nữ chưa có bộ hình riêng
## (đang dùng hình nam) nên Player đặt giọng theo giới tính hồ sơ — tiếng đánh/chạy/nhảy/bị đánh/chết/ra chiêu là giọng nữ.
var voice_gender: String = ""
var _sound_until_ms: int = 0      ## tiếng động tác đang vang tới lúc này (không chồng cùng tiếng lên nhau)
var _sound_key: String = ""        ## động tác gốc của tiếng đang vang
var _order_key: String = ""

func _ready() -> void:
	_data = AvatarData.get_for(gender)
	_shadow = _make_sprite(self)
	_shadow.z_index = -1
	_body = Node2D.new()
	add_child(_body)
	for part in _data.data.get("layer_ids", {}):
		var id: int = _data.data["layer_ids"][part]
		_layers[id] = _make_sprite(_body)
		_layer_part[id] = part
	if helm_res < 0:
		set_appearance(_data.default_res("helm"), _data.default_res("armor"), _data.default_res("weapon"))
	else:
		_rebuild()

## Đổi bộ hình nam <-> nữ (nạp data/avatar/<gender>.json, dựng lại các lớp). Chưa có dữ liệu giới tính đó thì giữ nguyên.
## Gọi được trước hoặc sau _ready.
func set_gender(new_gender: String) -> void:
	if new_gender == gender or not FileAccess.file_exists(AvatarData.DATA_PATH % new_gender):
		return
	gender = new_gender
	if _data == null:
		return  ## chưa _ready: _ready sẽ nạp theo `gender`
	_data = AvatarData.get_for(gender)
	for sprite in _layers.values():
		sprite.queue_free()
	_layers.clear()
	_layer_part.clear()
	_layer_file.clear()
	for part in _data.data.get("layer_ids", {}):
		var id: int = _data.data["layer_ids"][part]
		_layers[id] = _make_sprite(_body)
		_layer_part[id] = part
	set_appearance(_data.default_res("helm"), _data.default_res("armor"), _data.default_res("weapon"), horse_res)

func _make_sprite(parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.region_enabled = true
	s.visible = false
	parent.add_child(s)
	return s

func set_appearance(new_helm: int, new_armor: int, new_weapon: int, new_horse: int = -1) -> void:
	helm_res = new_helm
	armor_res = new_armor
	weapon_res = new_weapon
	horse_res = new_horse
	if _data:
		_rebuild()

## Phát động tác game. `duration` > 0: co giãn cho vừa đúng thời gian đó (VD theo tốc độ đánh).
func play(new_action: String, duration: float = -1.0) -> void:
	action = new_action
	_time = 0.0
	_finished = false
	_frame = -1
	_rebuild()
	var natural := get_action_duration()
	_speed = natural / duration if duration > 0.0 and natural > 0.0 else 1.0
	_play_action_sound()

## KNpcRes::PlaySound: phát tiếng của động tác (bảng 主角动作声音表) lúc động tác bắt đầu — đánh tay/vũ khí, chạy, nhảy, bị đánh,
## chết, cưỡi ngựa. Động tác lặp (chạy) phát lại mỗi vòng, nhưng KHÔNG chồng lên tiếng cũ còn đang vang (như gốc: IsPlaying -> bỏ qua).
func is_voice_female() -> bool:
	return (voice_gender if voice_gender != "" else gender) == "female"

func _play_action_sound() -> void:
	if not is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if _sound_key == _vltk_action and now < _sound_until_ms:
		return  ## chính tiếng này còn đang vang
	var stream := VltkSound.player_action(_vltk_action, is_voice_female())
	if stream == null:
		return
	_sound_key = _vltk_action
	_sound_until_ms = now + int(stream.get_length() * 1000.0)
	SfxManager.play(stream, global_position)

## Phát tiếng của 1 động tác game ("hurt", "die"...) mà KHÔNG đổi hình đang diễn — dành cho sự kiện chưa có hoạt ảnh riêng
## (người chơi bị đánh / chết hiện chỉ nháy màu). Dùng đúng bảng động tác theo vũ khí + đang cưỡi ngựa như play().
func play_event_sound(game_action: String) -> void:
	if _data == null:
		return
	var weapon := weapon_res if weapon_res >= 0 else _data.default_res("weapon")
	var riding: bool = is_riding() and str(_data.get_action_set(weapon, true).get(game_action, "")) != ""
	var vltk_action: String = _data.get_action_set(weapon, riding).get(game_action, "")
	var stream := VltkSound.player_action(vltk_action, is_voice_female())
	if stream != null:
		SfxManager.play(stream, global_position)

## Thời lượng tự nhiên (giây) của động tác hiện tại: số frame mỗi hướng / 18 fps.
func get_action_duration() -> float:
	return _frames_per_dir / _data.fps if _data else 0.0

func is_riding() -> bool:
	return horse_res >= 0

## Độ cao (pixel) so với mặt đất — vẽ nhân vật cao lên z, bóng giữ nguyên (KNpcRes vẽ bóng ở z = 0).
func set_height(z: float) -> void:
	if _body:
		_body.position.y = -z

## Độ cao hiện tại so với mặt đất (đang nhảy > 0).
func get_height() -> float:
	return -_body.position.y if _body else 0.0

func face(vec: Vector2) -> void:
	if vec == Vector2.ZERO:
		return
	## Hướng 0 = xuống (góc 90°), tăng theo chiều kim đồng hồ: 1 = xuống-trái, 2 = trái...
	var raw := (rad_to_deg(vec.angle()) - 90.0) / 45.0
	var d := wrapi(roundi(raw), 0, 8)
	## Trễ ở ranh giới: hướng mới phải lệch hẳn khỏi hướng hiện tại (> ~0,62 ô thay vì 0,5) mới đổi — đi đường chéo/vòng không bị
	## nhấp nháy giữa 2 hướng kề nhau.
	if d != direction and absf(wrapf(raw - float(direction), -4.0, 4.0)) < FACE_HYSTERESIS:
		return
	if d != direction:
		direction = d
		_frame = -1
		_apply_frame()

func _rebuild() -> void:
	var weapon := weapon_res if weapon_res >= 0 else _data.default_res("weapon")
	## Động tác không có bản cưỡi ngựa (nhảy: cột JunpFly bảng cưỡi ngựa để trống) -> vẽ như đang đi bộ, ẩn ngựa —
	## đúng KNpc gốc: `if (m_bRideHorse && m_ClientDoing == cdo_jump) m_DataRes.SetRideHorse(FALSE)`.
	var riding: bool = is_riding() and str(_data.get_action_set(weapon, true).get(action, "")) != ""
	_vltk_action = _data.get_action_set(weapon, riding).get(action, "")
	var res_of := {}
	var group_res := {"helm": helm_res, "armor": armor_res, "weapon": weapon, "horse": horse_res if riding else -1}
	for group in _data.data.get("groups", {}):
		var res: int = group_res.get(group, -1)
		for part in _data.data["groups"][group]:
			res_of[part] = res
	_frames_per_dir = 1
	for id in _layers:
		var res: int = res_of.get(_layer_part[id], -1)
		var key := _data.get_sprite_key(_layer_part[id], res, _vltk_action) if res >= 0 else ""
		_set_layer(_layers[id], key)
		_layer_file[id] = _data.get_file(key) if key != "" else {}
		if _layer_part[id] == "body" and not _layer_file[id].is_empty():
			_frames_per_dir = int(_layer_file[id]["frames_per_dir"])
	var shadow_key := _data.get_shadow_key(_vltk_action)
	_set_layer(_shadow, shadow_key)
	_shadow_file = _data.get_file(shadow_key) if shadow_key != "" else {}
	if _frames_per_dir <= 1:
		for id in _layer_file:
			if not _layer_file[id].is_empty():
				_frames_per_dir = maxi(_frames_per_dir, int(_layer_file[id]["frames_per_dir"]))
	_order_key = ""
	_frame = -1
	_apply_frame()

func _set_layer(sprite: Sprite2D, key: String) -> void:
	var tex: Texture2D = _data.get_texture(key) if key != "" else null
	sprite.texture = tex
	sprite.visible = tex != null
	if tex:
		var f := _data.get_file(key)
		sprite.position = Vector2(f["offset"][0], f["offset"][1]) - _data.anchor

func _process(delta: float) -> void:
	if _finished:
		return
	_time += delta * _speed
	var frame := int(_time * _data.fps)
	if action in LOOPING:
		frame %= maxi(_frames_per_dir, 1)
		if frame < _frame:  ## sang vòng lặp mới -> phát lại tiếng động tác (tiếng bước chân khi chạy)
			_play_action_sound()
	elif frame >= _frames_per_dir:
		frame = _frames_per_dir - 1
		_finished = true
		_set_frame(frame)
		action_finished.emit(action)
		return
	_set_frame(frame)

func _set_frame(frame: int) -> void:
	if frame != _frame:
		_frame = frame
		_apply_frame()

func _apply_frame() -> void:
	var frame := maxi(_frame, 0)
	for id in _layers:
		_update_region(_layers[id], _layer_file[id], frame)
	_update_region(_shadow, _shadow_file, frame)
	## Thứ tự vẽ: chỉ sắp lại khi đổi động tác/hướng/frame có ghi đè.
	var order := _data.get_draw_order(_vltk_action, direction, direction * _frames_per_dir + frame)
	var key := "%s|%d|%s" % [_vltk_action, direction, str(order)]
	if key == _order_key:
		return
	_order_key = key
	## Sắp bằng thứ tự node (không dùng z_index) để cả nhân vật vẫn là 1 khối trong Y-sort 2.5D của màn chơi —
	## z_index của lớp con sẽ đẩy nhân vật đè lên quái/cây bất kể đứng trước hay sau.
	var next := 0
	for raw_id in order:
		var id: int = int(raw_id)  ## JSON trả số thực (14.0) — phải ép int mới khớp khoá của _layers
		if _layers.has(id):
			_body.move_child(_layers[id], next)
			next += 1

func _update_region(sprite: Sprite2D, file: Dictionary, frame: int) -> void:
	if file.is_empty() or not sprite.visible:
		return
	var w: int = file["size"][0]
	var h: int = file["size"][1]
	var col := frame % int(file["frames_per_dir"])
	var row := direction % int(file["dirs"])
	sprite.region_rect = Rect2(col * w, row * h, w, h)
