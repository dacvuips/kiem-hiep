extends Node2D
class_name RemotePlayer
## Người chơi khác trên map (online). Vẽ bằng CharacterAvatar như nhân vật mình; vị trí NỘI SUY giữa các bản tin server
## (hiển thị trễ NetClient.interp_delay_ms — bộ đệm tự đo độ muộn thật của mẫu) nên chuyển động mượt.
## Gốc node = THÂN (giống Player: chân = gốc + FEET_OFFSET) để sắp độ sâu cùng nhà/cây như Player.

const CharacterAura = preload("res://systems/effects/character_aura.gd")
const GuildTag = preload("res://ui/guild_tag.gd")

const INTERP_DELAY_MS := 140.0
const FEET_OFFSET := 30.0
const MAX_BUFFER := 20
const DamageNumberScene := preload("res://effects/damage_number.tscn")
const HealthBarScene := preload("res://ui/HealthBar.tscn")
## Thanh máu dưới tên — cùng cỡ thanh trên đầu nhân vật mình (player.gd: 40 x 1.4 px, cao 4, cách đáy tên 16).
const HP_BAR_WIDTH := 56.0
const HP_BAR_HEIGHT := 4.0
const HP_BAR_TOP_OFFSET := 16.0

var eid := 0
var display_name := ""
var level := 1
var camp := 0
var nation := 0               ## Nation.Type — phe Tống / Kim trong trận Chiến trường Tống Kim (NONE ngoài trận)
var avatar: CharacterAvatar
var aura: AnimatedSprite2D
var status_controller: StatusEffectController
var _aura_sprite: VltkStateSprite = null
var _aura_sprite_state: int = 0
## StateSpecialId -> hình buff/bùa người này đang dính (theo look.states server gửi).
var _state_sprites: Dictionary = {}
var _label: Label
var _hp_bar: Node2D             ## HealthBar dưới tên — % máu theo snapshot server (máy người đó báo C_HP)
var hp := 100                   ## % máu mới nhất 0..100
var _hp_shown := -1             ## % đang vẽ trên thanh (-1 = chưa vẽ: HealthBar có thể chưa _ready khi setup chạy)
var _guild_tag: GuildTag
var guild_name := ""
var guild_emblem := 0
var _buffer: Array = []        ## [{t, pos, dir, action, z, flags, hp}] theo giờ server
var _action := ""
var flags := 0                ## NetProto.FLAG_* mới nhất (bày bán, mở giao dịch...)
var _look := {}
var _last_vel: Vector2 = Vector2.ZERO   ## vận tốc ước lượng từ 2 mốc cuối (px/giây, dead-reckoning)
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
	status_controller = StatusEffectController.new()
	status_controller.name = "StatusEffectController"
	add_child(status_controller)
	avatar = CharacterAvatar.new()
	avatar.position = Vector2(0, FEET_OFFSET)
	add_child(avatar)
	aura = CharacterAura.create_aura_node()
	aura.position = avatar.position + Vector2(0, 1)
	aura.visible = false
	add_child(aura)
	_label = Label.new()
	_label.text = Nation.decorate_name(display_name, nation)
	var f := GameUi.game_font_bold() if GameUi else null
	if f != null:
		_label.add_theme_font_override("font", f)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", _camp_color())
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(240, 20)
	_label.position = Vector2(-120, -66)
	_label.z_index = 12
	add_child(_label)
	## VLTK gốc (KNpc::PaintLife): người chơi khác cũng có thanh máu dưới tên, xanh >= 50%, vàng >= 25%, đỏ dưới 25%.
	_hp_bar = HealthBarScene.instantiate()
	_hp_bar.z_index = 11
	_hp_bar.use_gradient_color = true
	_hp_bar.bar_width = HP_BAR_WIDTH
	_hp_bar.bar_height = HP_BAR_HEIGHT
	_hp_bar.rounded = true
	add_child(_hp_bar)
	_guild_tag = GuildTag.new()
	add_child(_guild_tag)
	_sign = StallSign.new()
	_sign.z_index = 12
	_sign.clicked.connect(_on_sign_clicked)
	add_child(_sign)
	set_guild(str(info.get("guild_name", "")), int(info.get("guild_emblem", 0)))
	set_look(info.look)
	set_stall_title(str(info.get("stall_title", "")))
	position = info.pos - Vector2(0, FEET_OFFSET)
	_push(NetClient.server_now_ms() - NetClient.interp_delay_ms(NetClient.Interp.PLAYER), info)
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
	if PubgManager.is_active and int(get("pubg_squad_id")) == 1:
		return # Đồng đội trong cùng squad PUBG không thể gây sát thương cho nhau
	var est_dmg := (min_damage + max_damage) / 2
	_accumulate_damage(float(est_dmg))
	if avatar and _action != "attack" and _action != "die":
		avatar.play("hurt")
	NetClient.send_pvp_hit(eid, PvpHit.encode(attacker_stats, min_damage, max_damage, damage_type, attacker_element, mods))

func _accumulate_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	## Đòn đầu hiện số NGAY; đòn tới dồn trong DAMAGE_BATCH_INTERVAL thì gộp 1 số.
	if _damage_batch_timer <= 0.0:
		_damage_batch_timer = DAMAGE_BATCH_INTERVAL
		_accumulated_damage = amount
		_flush_now()
		return
	_accumulated_damage += amount

func _flush_damage_number() -> void:
	if _accumulated_damage <= 0.0:
		_damage_batch_timer = 0.0
		return
	_flush_now()
	_damage_batch_timer = DAMAGE_BATCH_INTERVAL   ## vẫn đang dồn đòn: giữ nhịp gộp

func _flush_now() -> void:
	if _accumulated_damage > 0.0:
		var at := global_position + Vector2(0, -50.0)
		var dmg_to_show := _accumulated_damage
		_accumulated_damage = 0.0
		ObjectPool.acquire_deferred(DamageNumberScene, get_parent(), at, func(number):
			number.set_damage(dmg_to_show))

func take_damage(amount: float) -> void:
	var a := CombatantStats.new()
	a.attack_rating = 999
	take_damage_from(a, int(amount), int(amount))

## Màu tên theo phe như nhân vật của mình (Camp.COLORS: Tân thủ trắng, Chính phái cam, Tà phái tím, Trung lập xanh...).
## Phe địch trong Chiến trường Tống Kim tô đỏ qua pk_enemy (BattleClient).
## Chung tổ đội với mình: VLTK gốc (KNpc::SetCurrentCamp / SetTempCurrentCamp) cho cả đội mang PHE HIỆN TẠI của đội trưởng
## -> tên đồng đội tô màu phe đội trưởng.
func get_effective_camp() -> int:
	var cap_camp := team_captain_camp()
	return cap_camp if cap_camp != NO_TEAM_CAMP else camp

func _camp_color() -> Color:
	return Camp.get_color(get_effective_camp())

const NO_TEAM_CAMP := -999

## Phe đội trưởng nếu người này cùng tổ đội với mình, NO_TEAM_CAMP nếu không.
func team_captain_camp() -> int:
	var p := GameManager.local_profile
	if p == null:
		return NO_TEAM_CAMP
	var team := SocialHub.of(p).team
	if not team.in_team():
		return NO_TEAM_CAMP
	for m in team.all_members():
		if m.id == eid and not m.is_local:
			return team.captain.camp
	return NO_TEAM_CAMP

## Độ cao nhãn tên (cưỡi ngựa thì cao hơn) — ChatBubble hiện lời nói ngay trên đó.
func chat_anchor_y() -> float:
	return _label.position.y if _label else -66.0

## ChatBubble đang hiện lời nói thay chỗ tên -> ẩn nhãn tên gốc (và dòng bang hội để tránh đè chữ).
func set_name_label_visible(on: bool) -> void:
	if _label:
		_label.visible = on
	if _guild_tag:
		_guild_tag.set_suppressed(not on)

func set_guild(gname: String, emblem_id: int = 0) -> void:
	guild_name = gname.strip_edges()
	guild_emblem = emblem_id
	if _guild_tag:
		_guild_tag.set_guild(guild_name, guild_emblem)
	_refresh_nameplate()

## Đổi màu tên và tiền tố phe (VD đấu trường Thách Đấu / Lộn Xộn: [Phe Xanh], [Phe Đỏ]).
func set_name_color(col: Color, prefix: String = "") -> void:
	if _label:
		_label.add_theme_color_override("font_color", col)
		if prefix != "":
			_label.text = "%s %s%s" % [prefix, _match_level_tag, display_name]
		else:
			_label.text = "%s%s" % [_match_level_tag, display_name]

func reset_name_color() -> void:
	_refresh_nameplate()

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
		var is_pk: bool = (flags & NetProto.FLAG_PK) != 0
		var col: Color = Color(1.0, 0.2, 0.2) if is_pk else (PK_ENEMY_COLOR if pk_enemy else _camp_color())
		_label.add_theme_color_override("font_color", col)

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
		_label.size = Vector2(240, 36)
		_label.position.x = -120
		if pk_enemy:
			_label.add_theme_color_override("font_color", PK_ENEMY_COLOR)
		else:
			var m_color: Color = _look.get("modulate", mask_info["modulate"])
			_label.add_theme_color_override("font_color", m_color)
	else:
		_label.text = base_name
		_label.size = Vector2(240, 20)
		_label.position.x = -120
		refresh_name_color()

	var base_y := -90.0 if int(_look.get("horse", -1)) >= 0 else -66.0
	_label.position.y = base_y - (_label.size.y - 20.0)
	if _guild_tag:
		_guild_tag.place_above(_label.position.y)
	if _sign:
		var top_y := _guild_tag.top_y() if (_guild_tag and _guild_tag.has_guild()) else _label.position.y
		_sign.place_above(top_y)
	if _hp_bar:
		_hp_bar.position = Vector2(0.0, _label.position.y + _label.size.y + HP_BAR_TOP_OFFSET)

func _refresh_aura_sprite(state_id: int) -> void:
	if state_id == _aura_sprite_state and (state_id == 0 or _aura_sprite != null):
		return
	if _aura_sprite != null and is_instance_valid(_aura_sprite):
		_aura_sprite.queue_free()
	_aura_sprite = VltkStateSprite.attach(self, state_id) if state_id > 0 else null
	_aura_sprite_state = state_id

## Gắn/bỏ hình buff/bùa (trên đầu, quanh người, dưới chân) theo danh sách máy người đó báo lên.
func _refresh_state_sprites(states: Variant) -> void:
	var wanted := {}
	for id in NetProto.sanitize_states(states):
		if id != _aura_sprite_state:
			wanted[id] = true
	for id in _state_sprites.keys():
		if not wanted.has(id) or not is_instance_valid(_state_sprites[id]):
			if is_instance_valid(_state_sprites[id]):
				_state_sprites[id].queue_free()
			_state_sprites.erase(id)
	for id in wanted:
		if not _state_sprites.has(id):
			var node := VltkStateSprite.attach(self, id)
			if node != null:
				_state_sprites[id] = node

## Hào quang người này đang bật: Vector2i(số skill VLTK, cấp) — (0, 0) nếu không bật.
func get_aura() -> Vector2i:
	return Vector2i(int(_look.get("aura_skill", 0)), int(_look.get("aura_level", 0)))

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
	_refresh_state_sprites(look.get("states", []))
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
	if NetWorldSync.is_online_mode() or NetClient.is_in_world():
		if me.has_method("notify"):
			me.notify("Tính năng Bày Bán tại chỗ đã đóng — vui lòng sử dụng Chợ Giao Thương để xem/treo bán vật phẩm.")
		return
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
	NetClient.note_sample(NetClient.Interp.PLAYER, float(server_ms))
	## Máu: lấy theo mẫu MỚI NHẤT (không chờ tới lượt vẽ trễ) -> bị đánh là thấy tụt ngay.
	_set_hp(int(st.get("hp", hp)))
	_push(float(server_ms), st)

func _push(t: float, st: Dictionary) -> void:
	var item := st.duplicate()
	item["t"] = t
	## Đứng yên một lúc (server không gửi gì) rồi mới đi: chèn mốc "vẫn ở chỗ cũ" ngay trước mẫu mới, để nhân vật bắt đầu
	## bước từ chỗ cũ theo đúng nhịp thay vì trượt chậm cả quãng nghỉ rồi giật lên.
	if not _buffer.is_empty():
		var last: Dictionary = _buffer[-1]
		if t - float(last.t) > NetProto.SNAPSHOT_MS * 2.5:
			var hold := last.duplicate()
			hold["t"] = t - NetProto.SNAPSHOT_MS
			_buffer.append(hold)
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
	if _damage_batch_timer > 0.0:
		_damage_batch_timer -= _delta
		if _damage_batch_timer <= 0.0:
			_flush_damage_number()
	if _open_stall_until != 0:
		_tick_stall_approach()
	if _buffer.is_empty():
		## Dead-reckoning: tiếp tục trượt theo vận tốc cuối (giảm dần để không đi xa) — chỉ khi đang chạy
		if _action == "run" and _last_vel.length_squared() > 1.0:
			_last_feet += _last_vel * _delta
			_last_vel = _last_vel.lerp(Vector2.ZERO, _delta * 8.0)
			position = _last_feet - Vector2(0, FEET_OFFSET)
		return
	var delay := NetClient.interp_delay_ms(NetClient.Interp.PLAYER)
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
			_last_vel = (b.pos as Vector2 - a.pos as Vector2) / (span / 1000.0)   ## px/giây (span tính bằng ms)
		## Quá xa (dịch chuyển / bị kéo về) thì nhảy thẳng tới, không trượt.
		if (a.pos as Vector2).distance_to(b.pos) > 600.0:
			feet = b.pos if k > 0.5 else a.pos
			_last_vel = Vector2.ZERO
	else:
		## Chỉ còn 1 mốc: dead-reckoning ngoại suy
		var overshoot := render_t - float(a.t)
		## Chỉ đoán tiếp khi mẫu cuối đang CHẠY (dừng rồi thì đứng đúng chỗ, không trượt quá); tối đa 1 nhịp gửi.
		var running := NetProto.action_name(int(a.action)) == "run"
		if running and overshoot > 0.0 and _last_vel.length_squared() > 1.0:
			feet = (a.pos as Vector2) + _last_vel * clampf(overshoot / 1000.0, 0.0, NetProto.SNAPSHOT_MS / 1000.0)
	_last_feet = feet
	position = feet - Vector2(0, FEET_OFFSET)
	_apply(a)

func _apply(st: Dictionary) -> void:
	var old_flags := flags
	flags = int(st.flags)
	if flags != old_flags:
		_refresh_sign()
		refresh_name_color()
		if (flags & NetProto.FLAG_PK) != 0:
			set_pk_enemy(true)
		else:
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.get("_pk_mode") != 1:
				set_pk_enemy(false)
	## Máu đã lấy theo mẫu mới nhất ở push_state; ở đây chỉ áp khi chưa có mẫu nào khác (lúc xuất hiện) / vẽ lại thanh.
	_set_hp(int(st.get("hp", hp)) if _buffer.size() <= 1 else hp)
	var dir := int(st.dir)
	if avatar.direction != dir:
		avatar.face(Vector2.from_angle(_dir_angle(dir)))
	var action := NetProto.action_name(int(st.action))
	if action != _action:
		_action = action
		avatar.play(action)
	avatar.set_height(float(st.z))

func _set_hp(v: int) -> void:
	hp = clampi(v, 0, 100)
	if hp != _hp_shown and _hp_bar and _hp_bar.is_node_ready():
		_hp_shown = hp
		_hp_bar.set_health(float(hp), 100.0)

## Hướng sprite 0..7 (0 = xuống, 2 = trái, 4 = lên, 6 = phải, theo chiều kim đồng hồ) -> góc màn hình.
static func _dir_angle(dir: int) -> float:
	return PI * 0.5 + dir * PI / 4.0
