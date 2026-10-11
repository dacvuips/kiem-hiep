class_name ServerEntity
extends RefCounted
## Một thực thể trên game server (người chơi / quái). Chỉ dữ liệu — không Node, không hình ảnh.
## `version` tăng mỗi lần trạng thái hiển thị đổi -> server chỉ gửi những gì thay đổi cho từng người xem.

var eid := 0
var kind := NetProto.KIND_PLAYER
var name := ""
var level := 1
var camp := 0
var pos := Vector2.ZERO          ## toạ độ chân
var dir := 0                     ## 0..7 như CharacterAvatar
var action := 0                  ## chỉ số NetProto.ACTIONS
var z := 0                       ## độ cao khi nhảy (px)
var flags := 0
var hp := 100                    ## phần trăm máu 0..100
var look: Dictionary = {}        ## {gender, helm, armor, weapon, horse}
var version := 0
var cell := Vector2i(1 << 30, 1 << 30)   ## ô AOI đang đứng (AoiGrid quản lý)

func touch() -> void:
	version += 1

func write_spawn(b: StreamPeerBuffer) -> void:
	b.put_u32(eid)
	b.put_u8(kind)
	NetProto.put_str(b, name)
	b.put_u16(level)
	b.put_8(camp)
	b.put_float(pos.x)
	b.put_float(pos.y)
	b.put_u8(dir)
	b.put_u8(action)
	b.put_u8(z)
	b.put_u8(flags)
	b.put_u8(hp)
	if kind == NetProto.KIND_PLAYER:
		NetProto.put_look(b, look)

func write_state(b: StreamPeerBuffer) -> void:
	b.put_u32(eid)
	b.put_float(pos.x)
	b.put_float(pos.y)
	b.put_u8(dir)
	b.put_u8(action)
	b.put_u8(z)
	b.put_u8(flags)
	b.put_u8(hp)
