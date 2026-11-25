class_name ServerEntity
extends RefCounted
## Một thực thể trên game server (người chơi / quái). Chỉ dữ liệu — không Node, không hình ảnh.
## `version` tăng mỗi lần trạng thái hiển thị đổi -> server chỉ gửi những gì thay đổi cho từng người xem.

var eid := 0
var kind := NetProto.KIND_PLAYER
var name := ""
var level := 1
var camp := 0
var stall_title := ""           ## tên quầy đang bày bán ("" = không bày) — biển trên đầu, bấm vào xem hàng
var guild_name := ""            ## tên bang hội ("" = chưa vào bang)
var guild_emblem := 0           ## ID biểu tượng bang hội (GuildEmblem)
var nation := 0                  ## Nation.Type — phe Tống / Kim (khác phe với người xem thì tên đỏ)
var pos := Vector2.ZERO          ## toạ độ chân
var dir := 0                     ## 0..7 như CharacterAvatar
var action := 0                  ## chỉ số NetProto.ACTIONS
var z := 0                       ## độ cao khi nhảy (px)
var flags := 0
var hp := 100                    ## phần trăm máu 0..100
var pos_ms := 0                  ## giờ server (ms) lúc lấy mẫu `pos` (người chơi: dấu giờ trong C_MOVE); 0 = lúc gửi (quái, bot)
var look: Dictionary = {}        ## {gender, helm, armor, weapon, horse}
var version := 0
var cell := Vector2i(1 << 30, 1 << 30)   ## ô AOI đang đứng (AoiGrid quản lý)
var look_dirty := false          ## ngoại hình vừa đổi -> lượt gửi tới gửi kèm S_LOOK
var snap_ver := -1               ## `version` đã đưa vào gói vị trí của ô (GameServer._send_snapshots)
## Phòng train chung (FieldServer) đang ở: 0 = map chính của tiến trình. Mỗi phòng 1 vùng ô AOI riêng (cell_base cộng vào ô) nên
## thực thể ở phòng khác không bao giờ nằm trong 3x3 ô của nhau — phần gửi vị trí theo AOI không cần biết tới phòng.
var room_id := 0
var cell_base := Vector2i.ZERO
var has_moved := false

func touch() -> void:
	version += 1

func write_spawn(b: StreamPeerBuffer) -> void:
	b.put_u32(eid)
	b.put_u8(kind)
	NetProto.put_str(b, name)
	b.put_u16(level)
	b.put_8(camp)
	b.put_u8(nation)
	NetProto.put_str(b, stall_title)
	b.put_float(pos.x)
	b.put_float(pos.y)
	var dir8: int = VltkMath.image_dir(dir, 8) if kind == NetProto.KIND_MONSTER else (dir & 7)
	b.put_u8(dir8)
	b.put_u8(action)
	b.put_u8(z)
	b.put_u16(flags)
	b.put_u8(hp)
	if kind == NetProto.KIND_PLAYER:
		NetProto.put_look(b, look)

## now_ms = giờ ghi trong đầu gói S_STATE: tuổi mẫu = now_ms - pos_ms (game nội suy theo đúng lúc lấy mẫu).
func write_state(b: StreamPeerBuffer, now_ms: int = 0) -> void:
	b.put_u32(eid)
	NetProto.put_state_pos(b, pos)
	var dir8: int = VltkMath.image_dir(dir, 8) if kind == NetProto.KIND_MONSTER else (dir & 7)
	b.put_u8((dir8 & 7) | (action << 3))
	b.put_u8(z)
	b.put_u16(flags)
	b.put_u8(hp)
	## Mẫu của C_MOVE luôn < 360ms (chặn 300ms + 1 tick); cũ hơn = server tự đặt vị trí (hồi sinh, kéo về...) -> tuổi 0.
	var age: int = now_ms - pos_ms if pos_ms > 0 and now_ms > 0 else 0
	if age < 0 or age > 400:
		age = 0
	b.put_u8(age / NetProto.STATE_AGE_UNIT_MS)
