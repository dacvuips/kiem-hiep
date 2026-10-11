class_name NetProto
## Giao thức game server <-> game (dùng chung 2 phía). Gói nhị phân: [1 byte loại tin][dữ liệu].
## Toạ độ = toạ độ CHÂN nhân vật trên map (pixel map, giống VltkWorld / map.json).
##
## Kênh ENet: 0 = tin cậy có thứ tự (mọi gói game -> server, vào game, xuất hiện/biến mất, sự kiện);
## 1 = không tin cậy (vị trí server gửi xuống, gói sau ghi đè gói trước).
## WebSocket luôn tin cậy — vẫn chạy đúng, chỉ tốn hơn chút.

const VERSION := 2
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
const C_HELLO := 1        ## u16 version, str access_token, u32 character_id
const C_MOVE := 2         ## f32 x, f32 y, u8 dir, u8 action, u8 z, u8 flags
const C_LOOK := 3         ## i16 helm, i16 armor, i16 weapon, i16 horse
const C_DAMAGE := 4       ## u32 monster_eid, u32 amount, u8 flags (1 = làm khựng) — sát thương đã tính ở máy người đánh
const C_PROFILE := 5      ## u32 grant_ack, json(PlayerProfile.to_dict) nén — game server gộp (ProfileGuard) rồi lưu.
                          ## grant_ack = số thứ tự "quà" (đồ / tiền server cho) cuối cùng game đã áp vào hồ sơ
const C_PICKUP := 6       ## u32 drop_id — nhặt đồ rơi
const C_DISCARD := 7      ## str item_uid — vứt món trong túi xuống đất
const C_PING := 9         ## u32 client_ms
const C_TRADE_REQ := 10   ## u32 target_eid — xin giao dịch
const C_TRADE_ANSWER := 11 ## u32 from_eid, u8 accept
const C_TRADE_OP := 12    ## u8 op (SocialServer.OP_*), rồi: OFFER/TAKE str uid | MONEY u32 | LOCK/CONFIRM/CANCEL không có gì
const C_SECURITY := 17    ## u8 op (SocialServer.SEC_*), str hash1, str hash2 — khoá bảo vệ (gửi MÃ BĂM, không gửi mật mã)
const C_GUILD := 16       ## u8 op (GuildServer.G_*), str json tham số
const C_CHAT := 15        ## u8 channel (ChatServer.NEAR..PRIVATE), str target (tên người nhận khi nhắn riêng), str text
const C_TEAM := 14        ## u8 op (SocialServer.TEAM_*), u32 arg (eid / giá trị), u8 arg2 (đồng ý / chế độ)
const C_STALL := 13       ## u8 op (SocialServer.STALL_* / TRADE_OPEN / TRADE_CLOSE), rồi: OPEN str title | BROWSE u32 seller | BUY u32 seller, str uid

# server -> game
const S_WELCOME := 1      ## u32 my_eid, f32 x, f32 y, str name
const S_ERROR := 2        ## str code, str message (rồi ngắt kết nối)
const S_SPAWN := 3        ## u32 eid, u8 kind, str name, u16 level, i8 camp, f32 x, f32 y, u8 dir, u8 action, u8 z, u8 flags, u8 hp,
                          ## rồi: người chơi = look; quái = u16 monster_id, u8 series, u8 blue_boss
const S_DESPAWN := 4      ## u32 eid
const S_STATE := 5        ## u32 server_ms, u16 n, n x (u32 eid, f32 x, f32 y, u8 dir, u8 action, u8 z, u8 flags, u8 hp)
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
const CLIENT_FLAGS := 0x0f

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

## Ngoại hình: gender (0 nam / 1 nữ) + 4 mã hình. look = {gender, helm, armor, weapon, horse}
static func put_look(b: StreamPeerBuffer, look: Dictionary) -> void:
	b.put_u8(int(look.get("gender", 0)))
	for k in ["helm", "armor", "weapon", "horse"]:
		b.put_16(clampi(int(look.get(k, -1)), -1, 32767))

static func get_look(b: StreamPeerBuffer) -> Dictionary:
	var look := {"gender": b.get_u8()}
	for k in ["helm", "armor", "weapon", "horse"]:
		look[k] = b.get_16()
	return look
