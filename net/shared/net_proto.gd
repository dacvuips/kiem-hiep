class_name NetProto
## Giao thức game server <-> game (dùng chung 2 phía). Gói nhị phân: [1 byte loại tin][dữ liệu].
## Toạ độ = toạ độ CHÂN nhân vật trên map (pixel map, giống VltkWorld / map.json).
##
## Kênh ENet: 0 = tin cậy có thứ tự (vào game, xuất hiện/biến mất, sự kiện); 1 = không tin cậy (vị trí, ghi đè được).
## WebSocket luôn tin cậy — vẫn chạy đúng, chỉ tốn hơn chút.

const VERSION := 1
const TICK_RATE := 18             ## mô phỏng server (khớp GAME_FPS VLTK gốc)
const SNAPSHOT_EVERY := 2         ## gửi vị trí mỗi 2 tick = 9 lần/giây
const CLIENT_SEND_RATE := 15.0    ## game gửi vị trí của mình tối đa 15 lần/giây
const AOI_CELL := 1024.0          ## ô lưới tầm nhìn (px); mỗi người thấy 3x3 ô quanh mình
const CH_RELIABLE := 0
const CH_STATE := 1

# game -> server
const C_HELLO := 1        ## u16 version, str access_token, u32 character_id
const C_MOVE := 2         ## f32 x, f32 y, u8 dir, u8 action, u8 z, u8 flags
const C_LOOK := 3         ## i16 helm, i16 armor, i16 weapon, i16 horse
const C_PING := 9         ## u32 client_ms

# server -> game
const S_WELCOME := 1      ## u32 my_eid, f32 x, f32 y, str name
const S_ERROR := 2        ## str code, str message (rồi ngắt kết nối)
const S_SPAWN := 3        ## u32 eid, u8 kind, str name, u16 level, i8 camp, f32 x, f32 y, u8 dir, u8 action, u8 z, u8 flags, u8 hp, look
const S_DESPAWN := 4      ## u32 eid
const S_STATE := 5        ## u32 server_ms, u16 n, n x (u32 eid, f32 x, f32 y, u8 dir, u8 action, u8 z, u8 flags, u8 hp)
const S_CORRECT := 6      ## f32 x, f32 y — server kéo nhân vật của mình về vị trí hợp lệ
const S_LOOK := 7         ## u32 eid, u8 gender, i16 helm, i16 armor, i16 weapon, i16 horse
const S_PONG := 9         ## u32 client_ms, u32 server_ms

const KIND_PLAYER := 1
const KIND_MONSTER := 2

## Động tác hiển thị (chỉ số gửi qua mạng). Khớp tên động tác của CharacterAvatar.
const ACTIONS: Array[String] = ["stand", "run", "attack", "attack2", "cast", "hurt", "die", "jump", "sit"]
const FLAG_RIDING := 1
const FLAG_SITTING := 2
const FLAG_DEAD := 4
const FLAG_JUMPING := 8

static func action_index(action: String) -> int:
	var i := ACTIONS.find(action)
	return i if i >= 0 else 0

static func action_name(i: int) -> String:
	return ACTIONS[i] if i >= 0 and i < ACTIONS.size() else "stand"

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
