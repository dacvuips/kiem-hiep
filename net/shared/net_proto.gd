class_name NetProto
## Giao thức game server <-> game (dùng chung 2 phía). Gói nhị phân: [1 byte loại tin][dữ liệu].
## Toạ độ = toạ độ CHÂN nhân vật trên map (pixel map, giống VltkWorld / map.json).
##
## Kênh ENet: 0 = tin cậy có thứ tự (mọi gói game -> server, vào game, xuất hiện/biến mất, sự kiện);
## 1 = không tin cậy (vị trí server gửi xuống, gói sau ghi đè gói trước).
## WebSocket luôn tin cậy — vẫn chạy đúng, chỉ tốn hơn chút.

const VERSION := 3
const TICK_RATE := 18             ## mô phỏng server (khớp GAME_FPS VLTK gốc)
const SNAPSHOT_EVERY := 2         ## gửi vị trí mỗi 2 tick = 9 lần/giây
const CLIENT_SEND_RATE := 15.0    ## game gửi vị trí của mình tối đa 15 lần/giây
const AOI_CELL := 1024.0          ## ô lưới tầm nhìn (px); mỗi người thấy 3x3 ô quanh mình
## ENet tự BỎ gói không tin cậy khi thấy trễ tăng (throttle) — với game gửi đều 9-15 gói/giây thì chỉ làm mất vị trí,
## nên tắt phần giảm (deceleration = 0). Gọi cho mọi ENetPacketPeer mới kết nối, ở cả 2 đầu.
static func tune_enet_peer(peer: ENetPacketPeer) -> void:
	if peer:
		peer.throttle_configure(5000, 32, 0)

const CH_RELIABLE := 0
const CH_STATE := 1

# game -> server
const C_HELLO := 1        ## u16 version, str access_token, u32 character_id, [u8 mode: HELLO_WORLD | HELLO_HUB]
## Chế độ kết nối (byte cuối C_HELLO, thiếu = vào map): HUB = "sảnh" ở Character Hub — không có nhân vật trên map, không ai thấy,
## server chỉ nhận gói xã hội / chợ / lưu nhân vật (GameServer.HUB_ALLOWED).
const HELLO_WORLD := 0
const HELLO_HUB := 1
const C_MOVE := 2         ## f32 x, f32 y, u8 dir, u8 action, u8 z, u8 flags
const C_LOOK := 3         ## i16 helm, i16 armor, i16 weapon, i16 horse
const C_DAMAGE := 4       ## u32 monster_eid, u32 amount, u8 flags (1 = làm khựng) — sát thương đã tính ở máy người đánh
const C_PROFILE := 5      ## u32 grant_ack, json(PlayerProfile.to_dict) nén — game server gộp (ProfileGuard) rồi lưu.
                          ## grant_ack = số thứ tự "quà" (đồ / tiền server cho) cuối cùng game đã áp vào hồ sơ
const C_PICKUP := 6       ## u32 drop_id — nhặt đồ rơi
const C_DISCARD := 7      ## str item_uid — vứt món trong túi xuống đất
const C_REVIVE := 8       ## (không thân) — chết bấm "Về thành dưỡng sức": server đưa về điểm xuất phát (chỉ khi đang chết)
const C_PING := 9         ## u32 client_ms
const C_TRADE_REQ := 10   ## u32 target_eid — xin giao dịch
const C_TRADE_ANSWER := 11 ## u32 from_eid, u8 accept
const C_TRADE_OP := 12    ## u8 op (SocialServer.OP_*), rồi: OFFER/TAKE str uid | MONEY u32 | LOCK/CONFIRM/CANCEL không có gì
const C_CAST := 18        ## u16 vltk_skill_id, u8 level, u8 cast_flags (CAST_*), u32 target_eid (0 = điểm), u24 x*2, u24 y*2 điểm nhắm
const C_FRIEND := 19      ## u8 op (RelationServer.FRIEND_*), u32 eid, u8 arg, str name — hảo hữu
const C_VIEW_EQUIP := 20  ## u32 target_eid — "Tin tức": xem trang bị người đứng gần
const C_ENMITY := 21      ## u32 target_eid — "Cừu sát": tuyên bố cừu sát người đứng gần
const C_PVP_HIT := 22     ## u32 target_eid, u32 n, n byte PvpHit — đòn đánh trúng đối thủ cừu sát (máy người đánh tính)
const C_BATTLE := 23      ## u8 op (BattleServer.OP_*), str json tham số — chiến trường Tống Kim (chỉ battle server)
const C_SECURITY := 17    ## u8 op (SocialServer.SEC_*), str hash1, str hash2 — khoá bảo vệ (gửi MÃ BĂM, không gửi mật mã)
const C_GUILD := 16       ## u8 op (GuildServer.G_*), str json tham số
const C_CHAT := 15        ## u8 channel (ChatServer.NEAR..PRIVATE), str target (tên người nhận khi nhắn riêng), str text
const C_TEAM := 14        ## u8 op (SocialServer.TEAM_*), u32 arg (eid / giá trị), u8 arg2 (đồng ý / chế độ)
const C_TRADE_REQ_ID := 24 ## u32 character_id — xin giao dịch theo ID nhân vật (Chợ › Giao dịch): không cần đứng gần
const C_MARKET := 25      ## str json {op: "list" {filter} | "mine" | "sell" {uid, price, cur} | "buy" {id} | "cancel" {id}} — Chợ Giao Thương
const C_ARENA := 26       ## u8 op (ArenaServer.OP_*) + str json — đấu trường PK (tạo / vào / xem phòng, tự tìm đối thủ, rời)
const C_FIELD := 27       ## u8 op (FieldServer.OP_*) + str json — phòng train chung Vượt Ải (tạo phòng {map_id, tier, stars} / vào {room, map_id})
const C_SHOP_BUY := 28    ## str misc_id, u8 count — mua ở Hiệu thuốc (PotionShop): server trừ tiền + thêm thuốc rồi gửi S_PROFILE
const C_CRAFT := 29       ## str json {op, uids, alt} — Chế tạo (Compound.run trên hồ sơ của server) -> S_NOTICE + S_PROFILE
const C_STALL := 13       ## u8 op (SocialServer.STALL_* / TRADE_OPEN / TRADE_CLOSE), rồi: OPEN str title | BROWSE u32 seller | BUY u32 seller, str uid

# server -> game
const S_WELCOME := 1      ## u32 my_eid, f32 x, f32 y, str name
const S_ERROR := 2        ## str code, str message (rồi ngắt kết nối)
const S_SPAWN := 3        ## u32 eid, u8 kind, str name, u16 level, i8 camp, u8 nation, str stall_title ("" = không bày bán), f32 x, f32 y, u8 dir, u8 action, u8 z, u8 flags, u8 hp,
                          ## rồi: người chơi = look; quái = u16 monster_id, u8 series, u8 blue_boss
const S_DESPAWN := 4      ## u32 eid
const S_STATE := 5        ## u32 server_ms, u16 n, n x (u32 eid, u24 x*2, u24 y*2, u8 dir|action<<3, u8 z, u8 flags, u8 hp) — 14 byte/mục
const S_CORRECT := 6      ## f32 x, f32 y — server kéo nhân vật của mình về vị trí hợp lệ
const S_LOOK := 7         ## u32 eid, u8 gender, i16 helm, i16 armor, i16 weapon, i16 horse
const S_MATTACK := 8      ## u32 monster_eid, u8 skill_slot, u32 target_eid, u8 dir64 — quái bắt đầu ra chiêu vào target
const S_PONG := 9         ## u32 client_ms, u32 server_ms
const S_KILL := 10        ## u32 monster_eid, u16 monster_id, u16 level, u8 series, u8 blue, f32 x, f32 y, u8 share% — mình được thưởng
const S_PROGRESS := 11    ## u32 exp_gained, u16 level, i64 current_exp — kinh nghiệm / cấp do server tính
const S_SAVED := 12       ## u32 version — server vừa lưu nhân vật (game cập nhật version để lần lưu HTTP sau không lệch)
const S_SPAWNS := 13      ## u16 n, n x (thân S_SPAWN) — gộp mọi thực thể mới vào tầm nhìn trong 1 lần gửi
const S_DESPAWNS := 14    ## u16 n, n x u32 eid
const S_PROFILE := 15     ## u32 grant_seq, json nhân vật chuẩn của server — game chép vào hồ sơ đang dùng (vào map, sau giao dịch...)
const S_DROPS := 16       ## u16 n, n x (u32 drop_id, f32 x, f32 y, u32 owner_eid, u8 kind 0 tiền / 1 đồ, u32 tiền | json đồ)
const S_PICKED := 17      ## u32 grant_seq, u32 drop_id, u8 kind, u32 tiền | json đồ (đã nằm trong hồ sơ server, có rx/ry)
const S_DROP_GONE := 18   ## u32 drop_id — đồ rơi đã bị nhặt / hết hạn
const S_NOTICE := 19      ## str — thông báo cho người chơi
const S_TRADE_INVITE := 20 ## u32 from_eid, str name — có người xin giao dịch
const S_TRADE_STATE := 21  ## u32 partner_eid, str partner_name, 2 x (bên mình trước): u32 money, u8 locked, u8 ok, u32 ok_age_ms,
                           ## u16 n, n x str json đồ trong phòng
const S_TRADE_END := 22   ## u8 success, str message
const S_TEAM_STATE := 24  ## u8 in_team; nếu có: u32 captain_eid, u8 open, u8 pick, u8 turn_index, u8 n, n x thành viên
                          ## (u32 eid, str name, u16 level, i8 camp, u8 lead_level, str sect_name) [0 = đội trưởng],
                          ## u8 n_apply, n x (u32 eid, str name, u16 level)
const S_CAST := 30        ## u32 caster_eid + thân C_CAST — người khác vừa ra chiêu: CHỈ VẼ lại, không tính sát thương
const S_FRIEND_INVITE := 31 ## u32 from_eid, str name — có người xin kết giao
const S_FRIEND_LIST := 32   ## str json [{name, online, level}]
const S_VIEW_EQUIP := 33    ## json snapshot (ViewEquipService.snapshot_of_profile)
const S_ENMITY := 34      ## u8 state (RelationServer.ENMITY_*), u32 other_eid, str other_name, u8 launcher
const S_PVP_HIT := 35     ## u32 attacker_eid, u32 n, n byte PvpHit (đã cắt theo trần) — máy bị đánh tự trừ máu
const S_CAMP := 36        ## u32 eid, i8 camp, u8 nation — phe (màu tên) / phe Tống-Kim người chơi đổi (lên cấp 10, vào/rời bang, chọn phe...)
const S_STALL_SIGN := 37  ## u32 eid, str title ("" = dọn quầy) — biển quầy trên đầu người bày bán (gửi người đang thấy + chính mình)
const S_BATTLE := 38      ## str json {op: "state" | "joined" | "reject" | "result", ...} — chiến trường Tống Kim
const S_MARKET := 39      ## json nén {op: "list" | "mine" | "done", items: [listing MarketBook], now, slots, ok, msg} — Chợ Giao Thương
const S_ARENA := 40       ## str json {op: "room" | "state" | "result" | "reject" | "searching" | "no_match", ...} — đấu trường PK
const S_FIELD := 41       ## str json {op: "room" | "reject", id, map_id, tier, stars, host, members, max} — phòng train chung Vượt Ải
const S_GUILD := 27       ## str json bang của mình ("" = không có bang) — cờ "local" ở mục của chính mình
const S_GUILD_LIST := 28  ## str json [{name, camp, level, members, cap, master, recruit, accept_level, tendency, activity, recruit_msg}]
const S_GUILD_INVITE := 29 ## str guild_name, str from_name
const S_CHAT := 26        ## u8 channel, u32 from_eid, str from_name, str to_name (nhắn riêng), str text
const S_TEAM_INVITE := 25 ## u32 captain_eid, str captain_name — được mời vào đội
const S_STALL_ITEMS := 23 ## u32 seller_eid, str title ("" = quầy đóng), u16 n, n x str json đồ (có giá)
const MAX_PROFILE_BYTES := 512 * 1024

const KIND_PLAYER := 1
const KIND_MONSTER := 2

## Động tác hiển thị (chỉ số gửi qua mạng). Khớp tên động tác của CharacterAvatar.
const ACTIONS: Array[String] = ["stand", "run", "attack", "attack2", "cast", "hurt", "die", "jump", "sit"]
## Động tác quái (MonsterSprite). Hướng quái gửi 0..63 (VltkMath).
const MONSTER_ACTIONS: Array[String] = ["stand", "walk", "hurt", "die", "attack1", "attack2", "magic"]
const FLAG_RIDING := 1
const FLAG_SITTING := 2
const FLAG_DEAD := 4
const FLAG_JUMPING := 8
## Cờ do SERVER đặt (game không gửi được): đang bày bán / đang mở giao dịch.
const FLAG_STALL := 16
const FLAG_TRADE_OPEN := 32
const FLAG_PK := 64
const CLIENT_FLAGS := 0x4f

static func action_index(action: String) -> int:
	var i := ACTIONS.find(action)
	return i if i >= 0 else 0

static func action_name(i: int) -> String:
	return ACTIONS[i] if i >= 0 and i < ACTIONS.size() else "stand"

static func monster_action_index(action: String) -> int:
	var i := MONSTER_ACTIONS.find(action)
	return i if i >= 0 else 0

static func monster_action_name(i: int) -> String:
	return MONSTER_ACTIONS[i] if i >= 0 and i < MONSTER_ACTIONS.size() else "stand"

# ---------------------------------------------------------------- ghi

## Cờ của C_CAST / S_CAST.
const CAST_SUPPORT := 1   ## skill hỗ trợ (buff / bùa / hào quang): không bám mục tiêu

## Toạ độ trong S_STATE: 24 bit mỗi trục theo nửa pixel (toạ độ thế giới tới ~4 triệu px; map chính nằm ở 71680..84992 px).
const POS_SCALE := 2.0

static func put_state_pos(b: StreamPeerBuffer, p: Vector2) -> void:
	for v in [p.x, p.y]:
		var q := clampi(roundi(v * POS_SCALE), 0, 0xFFFFFF)
		b.put_u16(q & 0xFFFF)
		b.put_u8(q >> 16)

static func get_state_pos(b: StreamPeerBuffer) -> Vector2:
	var x := b.get_u16() | (b.get_u8() << 16)
	var y := b.get_u16() | (b.get_u8() << 16)
	return Vector2(x, y) / POS_SCALE

static func writer(type: int) -> StreamPeerBuffer:
	var b := StreamPeerBuffer.new()
	b.put_u8(type)
	return b

static func put_str(b: StreamPeerBuffer, s: String) -> void:
	var bytes := s.to_utf8_buffer()
	b.put_u16(mini(bytes.size(), 65535))
	b.put_data(bytes.slice(0, 65535))

## Đọc chuỗi an toàn: giới hạn độ dài để gói xấu không làm tốn bộ nhớ.
static func get_str(b: StreamPeerBuffer, max_len := 4096) -> String:
	if b.get_available_bytes() < 2:
		return ""
	var n := b.get_u16()
	if n > max_len or n > b.get_available_bytes():
		return ""
	var r := b.get_data(n)
	return (r[1] as PackedByteArray).get_string_from_utf8() if r[0] == OK else ""

## Dictionary <-> JSON nén (dữ liệu nhân vật ~10-50 KB -> vài KB).
static func put_json(b: StreamPeerBuffer, d: Dictionary) -> void:
	var raw := JSON.stringify(d).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	b.put_u32(raw.size())
	b.put_u32(packed.size())
	b.put_data(packed)

static func get_json(b: StreamPeerBuffer) -> Dictionary:
	if b.get_available_bytes() < 8:
		return {}
	var raw_size := b.get_u32()
	var packed_size := b.get_u32()
	if raw_size > MAX_PROFILE_BYTES or packed_size > b.get_available_bytes():
		return {}
	var r := b.get_data(packed_size)
	if r[0] != OK:
		return {}
	var raw := (r[1] as PackedByteArray).decompress(raw_size, FileAccess.COMPRESSION_GZIP)
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

static func reader(packet: PackedByteArray) -> StreamPeerBuffer:
	var b := StreamPeerBuffer.new()
	b.data_array = packet
	return b

## Ngoại hình: gender (0 nam / 1 nữ) + 4 mã hình + mask_particular + aura_state. look = {gender, helm, armor, weapon, horse, mask_particular, aura_state}
static func put_look(b: StreamPeerBuffer, look: Dictionary) -> void:
	b.put_u8(int(look.get("gender", 0)))
	for k in ["helm", "armor", "weapon", "horse"]:
		b.put_16(clampi(int(look.get(k, -1)), -1, 32767))
	b.put_16(int(look.get("mask_particular", -1)))
	b.put_16(int(look.get("aura_state", 0)))

static func get_look(b: StreamPeerBuffer) -> Dictionary:
	var look := {"gender": b.get_u8()}
	for k in ["helm", "armor", "weapon", "horse"]:
		look[k] = b.get_16()
	if b.get_available_bytes() >= 4:
		look["mask_particular"] = b.get_16()
		look["aura_state"] = b.get_16()
	else:
		look["mask_particular"] = -1
		look["aura_state"] = 0
	return look

# ---------------------------------------------------------------- Đấu trường PK Binary Packing
const ARENA_MAGIC_BIN := 0xFA
const ARENA_MAGIC_GZIP := 0xFB

const ARENA_STATE_WAITING := 0
const ARENA_STATE_PREPARE := 1
const ARENA_STATE_FIGHT := 2
const ARENA_STATE_ENDED := 3

static func arena_state_to_code(st: String) -> int:
	match st:
		"prepare": return ARENA_STATE_PREPARE
		"fight": return ARENA_STATE_FIGHT
		"ended": return ARENA_STATE_ENDED
		_: return ARENA_STATE_WAITING

static func arena_code_to_state(code: int) -> String:
	match code:
		ARENA_STATE_PREPARE: return "prepare"
		ARENA_STATE_FIGHT: return "fight"
		ARENA_STATE_ENDED: return "ended"
		_: return "waiting"

## Đóng gói gói tin S_ARENA nhị phân: giảm 90-95% băng thông so với JSON thuần
static func pack_arena_msg(b: StreamPeerBuffer, msg: Dictionary) -> void:
	if msg.get("op") == "state":
		b.put_u8(ARENA_MAGIC_BIN)
		put_str(b, str(msg.get("id", "")))
		b.put_u8(int(msg.get("mode", 0)))
		b.put_u8(arena_state_to_code(str(msg.get("state", "waiting"))))
		b.put_u16(clampi(int(msg.get("left", 0)), 0, 65535))
		b.put_u8(int(msg.get("round", 1)))
		b.put_u16(clampi(int(msg.get("spectators", 0)), 0, 65535))
		put_str(b, str(msg.get("role", "")))
		put_str(b, str(msg.get("my_team", "")))

		# Team A: [cid, eid, name]
		var team_a: Array = msg.get("team_a", [])
		var eids_a: Array = msg.get("team_a_eids", [])
		var names_a: Array = msg.get("team_a_names", [])
		b.put_u8(mini(team_a.size(), 255))
		for i in team_a.size():
			b.put_u32(int(team_a[i]))
			b.put_u32(int(eids_a[i]) if i < eids_a.size() else 0)
			put_str(b, str(names_a[i]) if i < names_a.size() else "")

		# Team B: [cid, eid, name]
		var team_b: Array = msg.get("team_b", [])
		var eids_b: Array = msg.get("team_b_eids", [])
		var names_b: Array = msg.get("team_b_names", [])
		b.put_u8(mini(team_b.size(), 255))
		for i in team_b.size():
			b.put_u32(int(team_b[i]))
			b.put_u32(int(eids_b[i]) if i < eids_b.size() else 0)
			put_str(b, str(names_b[i]) if i < names_b.size() else "")
		return

	# Với các op khác: nén GZIP nếu JSON > 80 bytes
	var raw := JSON.stringify(msg).to_utf8_buffer()
	if raw.size() > 80:
		var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
		if packed.size() < raw.size():
			b.put_u8(ARENA_MAGIC_GZIP)
			b.put_u32(raw.size())
			b.put_u32(packed.size())
			b.put_data(packed)
			return

	# Fallback chuẩn UTF-8 string
	b.put_u8(0)
	put_str(b, JSON.stringify(msg))

## Giải nén gói tin S_ARENA nhị phân / GZIP / JSON chuỗi
static func unpack_arena_msg(b: StreamPeerBuffer) -> Dictionary:
	if b.get_available_bytes() < 1:
		return {}
	var magic := b.get_u8()
	if magic == ARENA_MAGIC_BIN:
		var st := {"op": "state"}
		st["id"] = get_str(b)
		st["mode"] = b.get_u8()
		st["state"] = arena_code_to_state(b.get_u8())
		st["left"] = b.get_u16()
		st["round"] = b.get_u8()
		st["spectators"] = b.get_u16()
		st["role"] = get_str(b)
		st["my_team"] = get_str(b)

		var na := b.get_u8()
		var team_a := []
		var eids_a := []
		var names_a := []
		for i in na:
			team_a.append(b.get_u32())
			eids_a.append(b.get_u32())
			names_a.append(get_str(b))

		var nb := b.get_u8()
		var team_b := []
		var eids_b := []
		var names_b := []
		for i in nb:
			team_b.append(b.get_u32())
			eids_b.append(b.get_u32())
			names_b.append(get_str(b))

		st["team_a"] = team_a
		st["team_b"] = team_b
		st["team_a_eids"] = eids_a
		st["team_b_eids"] = eids_b
		st["team_a_names"] = names_a
		st["team_b_names"] = names_b
		st["fighters"] = team_a + team_b
		st["fighter_eids"] = eids_a + eids_b
		return st
	elif magic == ARENA_MAGIC_GZIP:
		var raw_size := b.get_u32()
		var packed_size := b.get_u32()
		if raw_size > 1 << 20 or packed_size > b.get_available_bytes():
			return {}
		var r := b.get_data(packed_size)
		if r[0] != OK:
			return {}
		var raw := (r[1] as PackedByteArray).decompress(raw_size, FileAccess.COMPRESSION_GZIP)
		var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
		return parsed if parsed is Dictionary else {}
	elif magic == 0:
		var parsed: Variant = JSON.parse_string(get_str(b, 1 << 16))
		return parsed if parsed is Dictionary else {}
	else:
		# Trường hợp gói cũ không có byte magic: rewind 1 byte
		b.seek(b.get_position() - 1)
		var parsed: Variant = JSON.parse_string(get_str(b, 1 << 16))
		return parsed if parsed is Dictionary else {}
