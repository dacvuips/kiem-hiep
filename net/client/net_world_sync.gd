extends Node
class_name NetWorldSync
## Nối map MAIN_MAP với game server khi chơi online (main.gd thêm node này nếu đã đăng nhập + đã chọn nhân vật trên server):
##   - kết nối NetClient, đặt nhân vật mình ở vị trí server cấp;
##   - gửi vị trí / hướng / động tác của mình tối đa NetProto.CLIENT_SEND_RATE lần/giây (đứng yên thì 1 lần/giây);
##   - tạo / cập nhật / xóa RemotePlayer cho người chơi khác trong tầm nhìn;
##   - bị server kéo về (đi quá nhanh / xuyên vật cản) thì đặt lại vị trí.

const RECONNECT_DELAY := 5.0
## Lỗi này thì không tự kết nối lại (phải xử lý ở màn trước).
const FATAL := ["logged_in_elsewhere", "banned", "version", "unauthorized", "character_not_found", "service_key"]

var player: CharacterBody2D   ## player.gd (không có class_name) — gọi hàm theo kiểu động
var _remotes: Dictionary = {}     ## eid -> RemotePlayer
var _monsters: Dictionary = {}    ## eid -> VltkMonster (chế độ online)
var _send_timer := 0.0
var _heartbeat := 0.0
var _last_sent := {}
var _last_look := {}
var _reconnect_in := -1.0

static func is_online_mode() -> bool:
	return AccountApi.is_logged_in() and SaveManager.online_character_id != 0 and not ServerSelectScreen.selected_server.is_empty()

func _ready() -> void:
	NetClient.connected_to_world.connect(_on_connected)
	NetClient.disconnected.connect(_on_disconnected)
	NetClient.entity_spawned.connect(_on_spawn)
	NetClient.entity_despawned.connect(_on_despawn)
	NetClient.entity_state.connect(_on_state)
	NetClient.entity_look.connect(_on_look)
	NetClient.position_corrected.connect(_on_corrected)
	NetClient.monster_attack.connect(_on_monster_attack)
	NetClient.monster_killed.connect(_on_monster_killed)
	NetClient.progress.connect(_on_progress)
	NetClient.saved.connect(SaveManager.set_online_version)
	_connect()

func _exit_tree() -> void:
	## Gửi bản cuối cho game server (server lưu khi mình rời), rồi đánh dấu version phải hỏi lại.
	if NetClient.is_in_world() and GameManager.local_profile:
		NetClient.send_profile(GameManager.local_profile.to_dict())
	NetClient.disconnect_from_server()
	SaveManager.mark_version_unknown()

func _connect() -> void:
	_reconnect_in = -1.0
	_notify("Đang kết nối máy chủ game…")
	var token: String = await AccountApi.access_token()
	if token == "":
		_notify("Phiên đăng nhập đã hết hạn — hãy đăng nhập lại")
		return
	NetClient.connect_to(ServerSelectScreen.selected_server, token, SaveManager.online_character_id)

func _notify(text: String) -> void:
	if player and is_instance_valid(player):
		player.notify(text)

func _on_connected(_eid: int, feet: Vector2, _name: String) -> void:
	_notify("Đã vào máy chủ %s" % ServerSelectScreen.selected_server.get("name", ""))
	_teleport(feet)
	_last_sent = {}
	_last_look = {}

## Kinh nghiệm / cấp do server tính: cộng y hệt cách server cộng (cùng PlayerProfile.add_exp) rồi chốt theo số của server.
func _on_progress(gained: int, level: int, current_exp: int) -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	var before := profile.level
	profile.add_exp(gained)
	profile.level = level
	profile.current_exp = current_exp
	if profile.level != before and player and is_instance_valid(player):
		player.refresh_combat_stats()
		_notify("Lên cấp %d!" % profile.level)

func _on_disconnected(code: String, message: String) -> void:
	SaveManager.mark_version_unknown()
	for r in _remotes.values():
		r.queue_free()
	_remotes.clear()
	for m in _monsters.values():
		if is_instance_valid(m):
			m.queue_free()
	_monsters.clear()
	_notify(message)
	if code not in FATAL:
		_reconnect_in = RECONNECT_DELAY

func _teleport(feet: Vector2) -> void:
	if player == null:
		return
	player.global_position = feet - Vector2(0, RemotePlayer.FEET_OFFSET)
	player.velocity = Vector2.ZERO

func _on_corrected(feet: Vector2) -> void:
	_teleport(feet)

func _parent() -> Node:
	if VltkWorld.current and VltkWorld.current.map:
		return VltkWorld.current.map.objects_root
	return get_parent()

func _on_spawn(info: Dictionary) -> void:
	if int(info.kind) == NetProto.KIND_MONSTER:
		_spawn_monster(info)
		return
	if int(info.kind) != NetProto.KIND_PLAYER or _remotes.has(int(info.eid)):
		return
	var r := RemotePlayer.new()
	_parent().add_child(r)
	r.setup(info)
	_remotes[r.eid] = r

func _spawn_monster(info: Dictionary) -> void:
	var eid := int(info.eid)
	if _monsters.has(eid) and is_instance_valid(_monsters[eid]):
		return
	var data := MonsterData.monster(int(info.monster_id))
	if data.is_empty():
		return
	var m := VltkMonster.new()
	m.net_eid = eid
	m.monster_id = int(info.monster_id)
	m.data = data.duplicate()
	m.data["series"] = int(info.series)
	m.level = maxi(1, int(info.level))
	m.blue_boss = bool(info.blue)
	m.ai_enabled = false
	m.position = info.pos
	_parent().add_child(m)
	m.net_push_state(NetClient.server_now_ms() - VltkMonster.NET_INTERP_DELAY_MS, info)
	_monsters[eid] = m

func _on_monster_attack(m_eid: int, slot: int, target_eid: int, dir64: int) -> void:
	var m: VltkMonster = _monsters.get(m_eid)
	if m == null or not is_instance_valid(m):
		return
	var mine := target_eid == NetClient.my_eid
	var target_node: Node2D = player if mine else _remotes.get(target_eid)
	if target_node == null:
		return
	m.net_attack(slot, target_node, dir64, mine)

func _on_monster_killed(k: Dictionary) -> void:
	var m: VltkMonster = _monsters.get(int(k.eid))
	if m == null or not is_instance_valid(m):
		return
	m.grant_rewards(bool(k.last_hit))

func _on_despawn(eid: int) -> void:
	var m: VltkMonster = _monsters.get(eid)
	if m != null:
		_monsters.erase(eid)
		if is_instance_valid(m):
			if player and player.get_selected_target() == m:
				player.clear_target()
			m.queue_free()
		return
	var r: RemotePlayer = _remotes.get(eid)
	if r:
		_remotes.erase(eid)
		if player and player.get_selected_target() == r:
			player.clear_target()
		r.queue_free()

func _on_state(eid: int, server_ms: int, st: Dictionary) -> void:
	var r: RemotePlayer = _remotes.get(eid)
	if r:
		r.push_state(server_ms, st)
		return
	var m: VltkMonster = _monsters.get(eid)
	if m and is_instance_valid(m):
		m.net_push_state(float(server_ms), st)

func _on_look(eid: int, look: Dictionary) -> void:
	var r: RemotePlayer = _remotes.get(eid)
	if r:
		r.set_look(look)

func _process(delta: float) -> void:
	if _reconnect_in > 0.0:
		_reconnect_in -= delta
		if _reconnect_in <= 0.0:
			_connect()
		return
	if not NetClient.is_in_world() or player == null or not is_instance_valid(player):
		return
	var av: CharacterAvatar = player.avatar
	var look := {"helm": av.helm_res, "armor": av.armor_res, "weapon": av.weapon_res, "horse": av.horse_res}
	if look != _last_look:
		_last_look = look
		NetClient.send_look(look)
	_send_timer -= delta
	_heartbeat -= delta
	if _send_timer > 0.0:
		return
	var z: float = av.get_height()
	var flags := 0
	if player.is_riding():
		flags |= NetProto.FLAG_RIDING
	if player.is_sitting():
		flags |= NetProto.FLAG_SITTING
	if player.is_dead():
		flags |= NetProto.FLAG_DEAD
	if z > 0.5:
		flags |= NetProto.FLAG_JUMPING
	var cur := {"feet": player.get_ground_position().round(), "dir": av.direction, "action": av.action, "z": int(z), "flags": flags}
	if cur == _last_sent and _heartbeat > 0.0:
		return
	_last_sent = cur
	_send_timer = 1.0 / NetProto.CLIENT_SEND_RATE
	_heartbeat = 1.0
	NetClient.send_move(cur.feet, cur.dir, cur.action, cur.z, flags)
