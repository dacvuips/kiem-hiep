class_name ChatServer
extends RefCounted
## Chat trên game server: kênh GẦN (3x3 ô tầm nhìn), THẾ GIỚI, TỔ ĐỘI, BANG HỘI, RIÊNG (theo tên nhân vật).
## Server kiểm tra: đang bị cấm chat (web Admin, cập nhật mỗi 30 giây), dài <= MAX_LEN, gửi không quá nhanh
## (kênh thế giới chờ WORLD_COOLDOWN giây giữa 2 tin).

const NEAR := 0
const WORLD := 1
const TEAM := 2
const GUILD := 3
const PRIVATE := 4
const CHANNEL_NAMES := ["Gần", "Thế giới", "Tổ đội", "Bang hội", "Riêng"]

const MAX_LEN := 200
const MIN_INTERVAL := 0.8
const WORLD_COOLDOWN := 10.0

var gs: GameServer

func _init(server: GameServer) -> void:
	gs = server

func on_chat(c, b: StreamPeerBuffer) -> void:
	var channel := b.get_u8()
	var target := NetProto.get_str(b, 64).strip_edges()
	var text := NetProto.get_str(b, 1024).strip_edges().replace("\n", " ")
	if text.is_empty() or channel > PRIVATE:
		return
	if text.length() > MAX_LEN:
		text = text.left(MAX_LEN)
	var now := gs.now()
	var unix := Time.get_unix_time_from_system()
	if c.muted_until > unix:
		gs.notice(c, "Bạn đang bị cấm chat đến %s." % Time.get_datetime_string_from_unix_time(int(c.muted_until + 7 * 3600), true))
		return
	if now - c.last_chat < MIN_INTERVAL:
		gs.notice(c, "Bạn nói nhanh quá, chậm lại chút.")
		return
	if channel == WORLD and now - c.last_world_chat < WORLD_COOLDOWN:
		gs.notice(c, "Kênh thế giới: chờ %d giây nữa." % ceili(WORLD_COOLDOWN - (now - c.last_world_chat)))
		return
	c.last_chat = now
	var targets: Array = []
	match channel:
		NEAR:
			for e in gs.aoi.around(c.entity.pos):
				var to = gs.conn_of_eid(e.eid)
				if to:
					targets.append(to)
		WORLD:
			c.last_world_chat = now
			targets = gs.in_world_conns()
		TEAM:
			if c.team == null:
				gs.notice(c, "Bạn chưa có tổ đội.")
				return
			targets = c.team.members.duplicate()
		GUILD:
			var guild_name: String = str(c.profile.guild.get("name", "")) if c.profile.guild is Dictionary else ""
			if guild_name == "":
				gs.notice(c, "Bạn chưa vào bang hội.")
				return
			for to in gs.in_world_conns():
				if to.profile.guild is Dictionary and str(to.profile.guild.get("name", "")) == guild_name:
					targets.append(to)
		PRIVATE:
			var to = gs.conn_of_name(target)
			if to == null:
				gs.notice(c, "%s không online." % target)
				return
			targets = [to, c]
	var out := NetProto.writer(NetProto.S_CHAT)
	out.put_u8(channel)
	out.put_u32(c.entity.eid)
	NetProto.put_str(out, c.entity.name)
	NetProto.put_str(out, target if channel == PRIVATE else "")
	NetProto.put_str(out, text)
	for to in targets:
		gs.send(to, out)
