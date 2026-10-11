extends Node2D
class_name RemotePlayer
## Người chơi khác trên map (online). Vẽ bằng CharacterAvatar như nhân vật mình; vị trí NỘI SUY giữa các bản tin server
## (hiển thị trễ INTERP_DELAY_MS so với server) nên chuyển động mượt dù chỉ nhận ~9 bản tin/giây.
## Gốc node = THÂN (giống Player: chân = gốc + FEET_OFFSET) để sắp độ sâu cùng nhà/cây như Player.

const INTERP_DELAY_MS := 140.0
const FEET_OFFSET := 30.0
const MAX_BUFFER := 20

var eid := 0
var display_name := ""
var level := 1
var camp := 0
var avatar: CharacterAvatar
var _label: Label
var _buffer: Array = []        ## [{t, pos, dir, action, z, flags, hp}] theo giờ server
var _action := ""
var flags := 0                ## NetProto.FLAG_* mới nhất (bày bán, mở giao dịch...)
var _look := {}
## Đang cừu sát với mình (giai đoạn đánh): là "địch" — chiêu của mình va chạm và gây sát thương (gửi qua server).
var pk_enemy := false
const PK_ENEMY_COLOR := Color(1.0, 0.3, 1.0)   ## gốc: tên đối thủ cừu sát màu tím hồng

func setup(info: Dictionary) -> void:
	eid = int(info.eid)
	display_name = str(info.name)
	level = int(info.level)
	camp = int(info.camp)
	add_to_group("other_players")
	add_to_group("followable")
	avatar = CharacterAvatar.new()
	avatar.position = Vector2(0, FEET_OFFSET)
	add_child(avatar)
	_label = Label.new()
	_label.text = display_name
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", _camp_color())
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(160, 18)
	_label.position = Vector2(-80, -66)
	add_child(_label)
	set_look(info.look)
	position = info.pos - Vector2(0, FEET_OFFSET)
	_push(NetClient.server_now_ms() - INTERP_DELAY_MS, info)
	_apply(info)

func set_pk_enemy(on: bool) -> void:
	if on == pk_enemy:
		return
	pk_enemy = on
	if on:
		add_to_group("enemies")
	else:
		remove_from_group("enemies")
	_label.add_theme_color_override("font_color", PK_ENEMY_COLOR if on else _camp_color())

## Chiêu của mình trúng đối thủ cừu sát: không tự trừ máu ở đây — gói đòn gửi server, máy họ tự tính né / kháng / trừ máu.
func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.PHYSICS,
		attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM,
		mods: CombatFormulas.HitModifiers = null) -> void:
	if not pk_enemy or is_dead():
		return
	NetClient.send_pvp_hit(eid, PvpHit.encode(attacker_stats, min_damage, max_damage, damage_type, attacker_element, mods))

func take_damage(amount: float) -> void:
	var a := CombatantStats.new()
	a.attack_rating = 999
	take_damage_from(a, int(amount), int(amount))

## Màu tên theo phe như nhân vật của mình (Camp.COLORS: Tân thủ trắng, Chính phái cam, Tà phái tím, Trung lập xanh...).
func _camp_color() -> Color:
	return Camp.get_color(camp)

func set_camp(new_camp: int) -> void:
	camp = new_camp
	if not pk_enemy:
		_label.add_theme_color_override("font_color", _camp_color())

func set_look(look: Dictionary) -> void:
	if look == _look:
		return
	_look = look
	var gender := "female" if int(look.get("gender", 0)) == 1 else "male"
	avatar.voice_gender = gender
	avatar.set_gender(gender)
	avatar.set_appearance(int(look.helm), int(look.armor), int(look.weapon), int(look.horse))
	_label.position.y = -90 if int(look.horse) >= 0 else -66

func push_state(server_ms: int, st: Dictionary) -> void:
	_push(float(server_ms), st)

func _push(t: float, st: Dictionary) -> void:
	var item := st.duplicate()
	item["t"] = t
	_buffer.append(item)
	if _buffer.size() > MAX_BUFFER:
		_buffer.pop_front()

func get_ground_position() -> Vector2:
	return position + Vector2(0, FEET_OFFSET)

func get_body_height() -> float:
	return 70.0

func is_dead() -> bool:
	return _action == "die"

func _process(_delta: float) -> void:
	if _buffer.is_empty():
		return
	var render_t := NetClient.server_now_ms() - INTERP_DELAY_MS
	## Bỏ bản tin đã cũ (giữ lại 1 bản trước thời điểm vẽ để nội suy).
	while _buffer.size() >= 2 and float(_buffer[1].t) <= render_t:
		_buffer.pop_front()
	var a: Dictionary = _buffer[0]
	var feet: Vector2 = a.pos
	if _buffer.size() >= 2:
		var b: Dictionary = _buffer[1]
		var span := float(b.t) - float(a.t)
		var k := clampf((render_t - float(a.t)) / span, 0.0, 1.0) if span > 0.0 else 1.0
		feet = (a.pos as Vector2).lerp(b.pos, k)
		## Quá xa (dịch chuyển / bị kéo về) thì nhảy thẳng tới, không trượt.
		if (a.pos as Vector2).distance_to(b.pos) > 600.0:
			feet = b.pos if k > 0.5 else a.pos
	position = feet - Vector2(0, FEET_OFFSET)
	_apply(a)

func _apply(st: Dictionary) -> void:
	if int(st.flags) != flags:
		flags = int(st.flags)
		_label.text = display_name + ("  [Bày bán]" if (flags & NetProto.FLAG_STALL) != 0 else "")
	var dir := int(st.dir)
	if avatar.direction != dir:
		avatar.face(Vector2.from_angle(_dir_angle(dir)))
	var action := NetProto.action_name(int(st.action))
	if action != _action:
		_action = action
		avatar.play(action)
	avatar.set_height(float(st.z))

## Hướng sprite 0..7 (0 = xuống, 2 = trái, 4 = lên, 6 = phải, theo chiều kim đồng hồ) -> góc màn hình.
static func _dir_angle(dir: int) -> float:
	return PI * 0.5 + dir * PI / 4.0
