extends Node2D
class_name RemotePlayer
## Người chơi khác trên map (online). Vẽ bằng CharacterAvatar như nhân vật mình; vị trí NỘI SUY giữa các bản tin server
## (hiển thị trễ INTERP_DELAY_MS so với server) nên chuyển động mượt dù chỉ nhận ~9 bản tin/giây.
## Gốc node = THÂN (giống Player: chân = gốc + FEET_OFFSET) để sắp độ sâu cùng nhà/cây như Player.

const CharacterAura = preload("res://systems/effects/character_aura.gd")

const INTERP_DELAY_MS := 140.0
const FEET_OFFSET := 30.0
const MAX_BUFFER := 20
const DamageNumberScene := preload("res://effects/damage_number.tscn")

var eid := 0
var display_name := ""
var level := 1
var camp := 0
var nation := 0               ## Nation.Type — phe Tống / Kim trong trận Chiến trường Tống Kim (NONE ngoài trận)
var avatar: CharacterAvatar
var aura: AnimatedSprite2D
var _aura_sprite: VltkStateSprite = null
var _aura_sprite_state: int = 0
var _label: Label
var _buffer: Array = []        ## [{t, pos, dir, action, z, flags, hp}] theo giờ server
var _action := ""
var flags := 0                ## NetProto.FLAG_* mới nhất (bày bán, mở giao dịch...)
var _look := {}
var _last_vel: Vector2 = Vector2.ZERO   ## vận tốc ước lượng từ 2 mốc cuối (dead-reckoning)
var _last_feet: Vector2 = Vector2.ZERO  ## vị trí chân cuối đã áp
## Đang cừu sát với mình (giai đoạn đánh): là "địch" — chiêu của mình va chạm và gây sát thương (gửi qua server).
var pk_enemy := false
## Tên quầy đang bày bán ("" = không bày) — biển trên đầu, bấm vào mở quầy xem hàng.
var stall_title := ""
var _sign: StallSign
## Bấm quầy khi đứng xa: chạy lại gần rồi tự mở (hết hạn sau STALL_APPROACH_SEC giây nếu không tới được).
var _open_stall_until := 0
const STALL_APPROACH_SEC := 15
const PK_ENEMY_COLOR := Color(1.0, 0.3, 1.0)   ## gốc: tên đối thủ cừu sát màu tím hồng

## VLTK gốc (NormalSync): gom sát thương theo chu kỳ (~0.2s) rồi mới hiển thị 1 số duy nhất
const DAMAGE_BATCH_INTERVAL := 0.2
var _accumulated_damage: float = 0.0
var _damage_batch_timer: float = 0.0

func setup(info: Dictionary) -> void:
	eid = int(info.eid)
	display_name = str(info.name)
	level = int(info.level)
	camp = int(info.camp)
	nation = int(info.get("nation", Nation.Type.NONE))
	add_to_group("other_players")
	add_to_group("followable")
	avatar = CharacterAvatar.new()
	avatar.position = Vector2(0, FEET_OFFSET)
	add_child(avatar)
	aura = CharacterAura.create_aura_node()
	aura.position = avatar.position + Vector2(0, 1)
	add_child(aura)
	_label = Label.new()
	_label.text = Nation.decorate_name(display_name, nation)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", _camp_color())
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(160, 18)
	_label.position = Vector2(-80, -66)
	add_child(_label)
	_sign = StallSign.new()
	_sign.clicked.connect(_on_sign_clicked)
	add_child(_sign)
	set_look(info.look)
	set_stall_title(str(info.get("stall_title", "")))
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
	refresh_name_color()

## Chiêu của mình trúng đối thủ cừu sát: không tự trừ máu ở đây — gói đòn gửi server, máy họ tự tính né / kháng / trừ máu.
func take_damage_from(attacker_stats: CombatantStats, min_damage: int, max_damage: int,
		damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.PHYSICS,
		attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM,
		mods: CombatFormulas.HitModifiers = null) -> void:
	if not pk_enemy or is_dead():
		return
	var est_dmg := (min_damage + max_damage) / 2
	_accumulate_damage(float(est_dmg))
	if avatar and _action != "attack" and _action != "die":
		avatar.play("hurt")
	NetClient.send_pvp_hit(eid, PvpHit.encode(attacker_stats, min_damage, max_damage, damage_type, attacker_element, mods))

func _accumulate_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if _accumulated_damage <= 0.0:
		_damage_batch_timer = DAMAGE_BATCH_INTERVAL
	_accumulated_damage += amount

func _flush_damage_number() -> void:
	if _accumulated_damage > 0.0:
		var at := global_position + Vector2(0, -50.0)
		var dmg_to_show := _accumulated_damage
		_accumulated_damage = 0.0
		_damage_batch_timer = 0.0
		ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), at, func(number):
			number.set_damage(dmg_to_show))

func take_damage(amount: float) -> void:
	var a := CombatantStats.new()
	a.attack_rating = 999
	take_damage_from(a, int(amount), int(amount))

## Màu tên theo phe như nhân vật của mình (Camp.COLORS: Tân thủ trắng, Chính phái cam, Tà phái tím, Trung lập xanh...).
## Phe địch trong Chiến trường Tống Kim tô đỏ qua pk_enemy (BattleClient).
func _camp_color() -> Color:
	return Camp.get_color(camp)

## Độ cao nhãn tên (cưỡi ngựa thì cao hơn) — ChatBubble hiện lời nói ngay trên đó.
func chat_anchor_y() -> float:
	return _label.position.y if _label else -66.0

## ChatBubble đang hiện lời nói thay chỗ tên -> ẩn nhãn tên gốc.
func set_name_label_visible(on: bool) -> void:
	if _label:
		_label.visible = on

var _match_level_tag: String = ""

func set_match_level_tag(lvl: int, side: String = "") -> void:
	if lvl > 0:
		_match_level_tag = "[Cấp %d] " % lvl
	else:
		_match_level_tag = ""
	_refresh_nameplate()
	if side != "":
		var mask_part := int(_look.get("mask_particular", -1))
		var mask_info := Equipment.get_mask_appearance_info(mask_part)
		var is_masked: bool = mask_info["is_masked"] or bool(_look.get("is_masked", false))
		if not is_masked and not pk_enemy and _label:
			var side_col := Color(0.2, 0.6, 1.0) if side == "song" else Color(1.0, 0.35, 0.2)
			_label.add_theme_color_override("font_color", side_col)

func set_camp(new_camp: int, new_nation: int = nation) -> void:
	camp = new_camp
	nation = new_nation
	_refresh_nameplate()

## Tô lại màu tên (đổi phe của người này / của mình, bật-tắt cừu sát, mặt nạ dịch dung).
func refresh_name_color() -> void:
	if _label == null:
		return
	var mask_part := int(_look.get("mask_particular", -1))
	var mask_info := Equipment.get_mask_appearance_info(mask_part)
	var is_masked: bool = mask_info["is_masked"] or bool(_look.get("is_masked", false))
	if is_masked and not pk_enemy:
		var m_color: Color = _look.get("modulate", mask_info["modulate"])
		_label.add_theme_color_override("font_color", m_color)
	else:
		_label.add_theme_color_override("font_color", PK_ENEMY_COLOR if pk_enemy else _camp_color())

func _refresh_nameplate() -> void:
	if _label == null:
		return
	var mask_part := int(_look.get("mask_particular", -1))
	var mask_info := Equipment.get_mask_appearance_info(mask_part)
	var is_masked: bool = mask_info["is_masked"] or bool(_look.get("is_masked", false))
	var base_name := "%s%s" % [_match_level_tag, Nation.decorate_name(display_name, nation)]

	if is_masked:
		var d_title: String = str(_look.get("disguise_title", mask_info["disguise_title"]))
		if d_title == "":
			d_title = "Dịch Dung"
		_label.text = "🎭 [%s]\n%s" % [d_title, base_name]
		_label.size = Vector2(200, 32)
		_label.position.x = -100
		if pk_enemy:
			_label.add_theme_color_override("font_color", PK_ENEMY_COLOR)
		else:
			var m_color: Color = _look.get("modulate", mask_info["modulate"])
			_label.add_theme_color_override("font_color", m_color)
	else:
		_label.text = base_name
		_label.size = Vector2(160, 18)
		_label.position.x = -80
		refresh_name_color()

	var base_y := -90.0 if int(_look.get("horse", -1)) >= 0 else -66.0
	_label.position.y = base_y - (_label.size.y - 18.0)
	if _sign:
		_sign.place_above(_label.position.y)

func _refresh_aura_sprite(state_id: int) -> void:
	if state_id == _aura_sprite_state and (state_id == 0 or _aura_sprite != null):
		return
	if _aura_sprite != null and is_instance_valid(_aura_sprite):
		_aura_sprite.queue_free()
	_aura_sprite = VltkStateSprite.attach(self, state_id) if state_id > 0 else null
	_aura_sprite_state = state_id

func set_look(look: Dictionary) -> void:
	if look == _look and not _look.is_empty():
		return
	_look = look.duplicate()
	var mask_part := int(look.get("mask_particular", -1))
	var mask_info := Equipment.get_mask_appearance_info(mask_part)
	var is_masked: bool = mask_info["is_masked"] or bool(look.get("is_masked", false))
	var disguise_gender: String = str(mask_info.get("gender", ""))

	var raw_gender := "female" if int(look.get("gender", 0)) == 1 else "male"
	var final_gender := disguise_gender if (is_masked and disguise_gender != "") else raw_gender
	if avatar != null:
		avatar.voice_gender = final_gender
		avatar.set_gender(final_gender)
		avatar.set_appearance(int(look.get("helm", -1)), int(look.get("armor", -1)), int(look.get("weapon", -1)), int(look.get("horse", -1)))
		if is_masked:
			var m_mod: Color = look.get("modulate", mask_info["modulate"])
			avatar.modulate = m_mod
		else:
			avatar.modulate = Color.WHITE

	_refresh_aura_sprite(int(look.get("aura_state", 0)))
	_refresh_nameplate()

func set_stall_title(title: String) -> void:
	stall_title = title
	_refresh_sign()
	if title == "":
		_open_stall_until = 0

func _refresh_sign() -> void:
	if _sign == null or not is_instance_valid(_sign):
		return
	if stall_title != "":
		_sign.set_title(stall_title)
	elif (flags & NetProto.FLAG_TRADE_OPEN) != 0:
		_sign.set_title("Mở giao dịch")
	else:
		_sign.set_title("")

func _on_sign_clicked() -> void:
	if stall_title != "":
		open_stall()
	elif (flags & NetProto.FLAG_TRADE_OPEN) != 0:
		var me := get_tree().get_first_node_in_group("player") as Node2D
		if me != null and is_instance_valid(me):
			PlayerMenu.open(me, self, get_viewport().get_mouse_position())

## Mở quầy xem hàng (bấm biển tên quầy / "Xem quầy" ở menu người chơi). Xa quá thì chạy lại gần trước, tới nơi tự mở.
func open_stall() -> void:
	var me := get_tree().get_first_node_in_group("player") as Node2D
	if stall_title == "" or me == null:
		return
	if me.has_method("get_ground_position") and me.get_ground_position().distance_to(get_ground_position()) > SocialServer.TRADE_RANGE * 0.8:
		if me.has_method("walk_to_feet") and me.walk_to_feet(get_ground_position() + Vector2(0, 40)):
			_open_stall_until = Time.get_ticks_msec() + STALL_APPROACH_SEC * 1000
		elif me.has_method("notify"):
			me.notify("Đứng gần quầy hàng hơn mới xem được.")
		return
	_open_stall_until = 0
	var p := GameManager.local_profile
	var seller := SocialDirectory.find_by_id(p, eid) if p else null
	if seller != null:
		StallBrowseWindow.open(get_tree().current_scene, SocialHub.of(p), seller)

func _tick_stall_approach() -> void:
	if Time.get_ticks_msec() > _open_stall_until:
		_open_stall_until = 0
		return
	var me := get_tree().get_first_node_in_group("player") as Node2D
	if me != null and me.has_method("get_ground_position") and me.get_ground_position().distance_to(get_ground_position()) <= SocialServer.TRADE_RANGE * 0.8:
		open_stall()

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
	if _accumulated_damage > 0.0:
		_damage_batch_timer -= _delta
		if _damage_batch_timer <= 0.0:
			_flush_damage_number()
	if _open_stall_until != 0:
		_tick_stall_approach()
	if _buffer.is_empty():
		## Dead-reckoning: tiếp tục trượt theo vận tốc cuối (giảm dần để không đi xa)
		if _last_vel.length_squared() > 1.0:
			_last_feet += _last_vel * _delta
			_last_vel = _last_vel.lerp(Vector2.ZERO, _delta * 8.0)
			position = _last_feet - Vector2(0, FEET_OFFSET)
		return
	var delay := NetClient.adaptive_interp_delay_ms() if NetClient.has_method("adaptive_interp_delay_ms") else INTERP_DELAY_MS
	var render_t := NetClient.server_now_ms() - delay
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
		## Cập nhật vận tốc cho dead-reckoning
		if span > 0.0:
			_last_vel = (b.pos as Vector2 - a.pos as Vector2) / span
		## Quá xa (dịch chuyển / bị kéo về) thì nhảy thẳng tới, không trượt.
		if (a.pos as Vector2).distance_to(b.pos) > 600.0:
			feet = b.pos if k > 0.5 else a.pos
			_last_vel = Vector2.ZERO
	else:
		## Chỉ còn 1 mốc: dead-reckoning ngoại suy
		var overshoot := render_t - float(a.t)
		if overshoot > 0.0 and _last_vel.length_squared() > 1.0:
			feet = (a.pos as Vector2) + _last_vel * clampf(overshoot / 1000.0, 0.0, 0.1)
	_last_feet = feet
	position = feet - Vector2(0, FEET_OFFSET)
	_apply(a)

func _apply(st: Dictionary) -> void:
	flags = int(st.flags)
	_refresh_sign()
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
