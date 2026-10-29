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

const MAX_LEN := 600
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
	## CHỈ khi GAME_TEST_MODE=1 (tests/net_tests): "/testlevel N" đặt cấp nhân vật để thử luật theo cấp (Tân thủ / cừu sát).
	if gs.test_mode and text.begins_with("/testlevel "):
		c.profile.level = clampi(int(text.get_slice(" ", 1)), 1, 200)
		c.entity.level = c.profile.level
		c.entity.touch()
		gs.profile_changed(c)
		return
	## CHỈ khi GAME_TEST_MODE=1: "/testrestart N" khởi động lại êm sau N giây (như lệnh từ web Admin) — thử lưu dữ liệu khi khởi động lại.
	if gs.test_mode and text.begins_with("/testrestart "):
		gs.start_drain(clampi(int(text.get_slice(" ", 1)), 3, 60), "thử nghiệm", c.entity.name)
		return
	## CHỈ khi GAME_TEST_MODE=1: "/testgold N" cộng N lượng (tối đa 100 triệu/lần) để thử giao dịch / bày bán.
	if gs.test_mode and text.begins_with("/testgold "):
		if c.trade:
			gs.notice(c, "Đang giao dịch, không cộng tiền được.")
			return
		var add := clampi(int(text.get_slice(" ", 1)), 0, 100_000_000)
		c.profile.gold += add
		gs.profile_changed(c)
		gs.notice(c, "[Thử nghiệm] Đã cộng %d lượng." % add)
		return
	## Lệnh GM: tạo KNB, Tiền Xu và Tiên Thảo Lộ (chỉ GM hoặc chế độ TEST)
	if text.begins_with("/knb"):
		if not c.is_gm and not gs.test_mode:
			gs.notice(c, "Lệnh này chỉ dành cho GM.")
			return
		var parts := text.split(" ", false)
		var add := 1000
		if parts.size() > 1 and parts[1].is_valid_int():
			add = clampi(int(parts[1]), 1, 100_000_000)
		c.profile.jade += add
		gs.profile_changed(c)
		gs.notice(c, "[GM] Nhận được %d KNB (Kim Nguyên Bảo)." % add)
		return
	if text.begins_with("/xu"):
		if not c.is_gm and not gs.test_mode:
			gs.notice(c, "Lệnh này chỉ dành cho GM.")
			return
		var parts := text.split(" ", false)
		var add := 1000
		if parts.size() > 1 and parts[1].is_valid_int():
			add = clampi(int(parts[1]), 1, 100_000_000)
		c.profile.xu += add
		gs.profile_changed(c)
		gs.notice(c, "[GM] Nhận được %d Tiền Xu." % add)
		return
	if text.begins_with("/ttl") or text.begins_with("/tienthaolo"):
		if not c.is_gm and not gs.test_mode:
			gs.notice(c, "Lệnh này chỉ dành cho GM.")
			return
		var ttl_1h := ItemGenerator.generate_misc("6_1_71")
		var ttl_8h := ItemGenerator.generate_misc("6_1_1181")
		var ttl_hoan := ItemGenerator.generate_misc("6_1_113")
		var knb_item := ItemGenerator.generate_misc("6_1_1877")
		var added := 0
		if ttl_1h and c.profile.add_item(ttl_1h): added += 1
		if ttl_8h and c.profile.add_item(ttl_8h): added += 1
		if ttl_hoan and c.profile.add_item(ttl_hoan): added += 1
		if knb_item and c.profile.add_item(knb_item): added += 1
		gs.profile_changed(c)
		gs.notice(c, "[Hệ thống] Đã thêm Tiên Thảo Lộ & Kim Nguyên Bảo vào hành trang.")
		return
	if text.begins_with("/aura"):
		if not c.is_gm and not gs.test_mode:
			gs.notice(c, "Lệnh này chỉ dành cho GM.")
			return
		var parts := text.split(" ", false)
		if parts.size() < 2:
			gs.notice(c, "Cú pháp: /aura <id_state> [tên_người_chơi hoặc eid]")
			return
		var state_id := int(parts[1])
		var target_c: GameServer.Conn = c
		if parts.size() >= 3:
			var target_str := parts[2]
			if target_str.is_valid_int() and gs.conn_of_eid(int(target_str)) != null:
				target_c = gs.conn_of_eid(int(target_str))
			else:
				for other in gs.in_world_conns():
					if other.entity and (other.entity.name == target_str or other.username == target_str):
						target_c = other
						break
		if target_c == null or target_c.entity == null:
			gs.notice(c, "Không tìm thấy người chơi mục tiêu.")
			return
		target_c.profile.gm_aura_state = state_id
		target_c.data["gm_aura_state"] = state_id
		target_c.entity.look = gs.look_from_profile(target_c.data)
		target_c.entity.look_dirty = true
		if not gs._look_dirty.has(target_c.entity):
			gs._look_dirty.append(target_c.entity)
		gs.profile_changed(target_c)
		gs.notice(c, "[GM] Đã gán hào quang state #%d cho %s." % [state_id, target_c.entity.name])
		return
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
			for e in gs.aoi.around(c.entity.pos, c.entity.cell_base):
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
