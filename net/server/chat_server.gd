class_name ChatServer
extends RefCounted
## Chat trên game server: kênh GẦN (3x3 ô tầm nhìn), THẾ GIỚI, TỔ ĐỘI, BANG HỘI, MÔN PHÁI, RIÊNG (theo tên nhân vật).
## Server kiểm tra: đang bị cấm chat (web Admin, cập nhật mỗi 30 giây), dài <= MAX_LEN, gửi không quá nhanh
## (kênh thế giới chờ WORLD_COOLDOWN giây giữa 2 tin).

const NEAR := 0
const WORLD := 1
const TEAM := 2
const GUILD := 3
const PRIVATE := 4
const FACTION := 5   ## Môn phái: mọi người online cùng phái (sect_id) — kênh "Môn phái" của khung chat gốc
const LAST_CHANNEL := FACTION
const CHANNEL_NAMES := ["Gần", "Thế giới", "Tổ đội", "Bang hội", "Riêng", "Môn phái"]

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
	if text.is_empty() or channel > LAST_CHANNEL:
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
	## CHỈ khi GAME_TEST_MODE=1: "/testbot [phái] [cấp] [độ khó 0-2]" sinh 1 bot (BotCombatBrain) cạnh mình, đánh mình — thử bot người chơi.
	if gs.test_mode and (text == "/testbot" or text.begins_with("/testbot ")):
		var parts := text.split(" ", false)
		var bp := PlayerProfile.new()
		bp.display_name = "Bot %d" % (gs.bots.bots.size() + 1)
		bp.sect_id = parts[1] if parts.size() > 1 else "thieu_lam"
		bp.level = clampi(int(parts[2]) if parts.size() > 2 else 90, 1, PlayerProfile.MAX_LEVEL)
		LonXonRules.refresh_skills(bp)
		LonXonRules.give_potions(bp)
		var spot: Vector2 = gs.grid_of(c.entity).free_near(c.entity.pos + Vector2(120, 0))
		var bot := gs.bots.spawn(bp, spot if spot != Vector2.ZERO else c.entity.pos, c.entity.room_id, c.entity.cell_base, BotCombatBrain.new(c.entity.eid))
		bot.difficulty = clampi(int(parts[3]) if parts.size() > 3 else 1, 0, 2)
		gs.notice(c, "testbot %d" % bot.eid)
		return
	## CHỈ khi GAME_TEST_MODE=1: "/testbots N [độ khó 0-2 | -1 trộn]" sinh N bot hỗn chiến quanh mình (BotArenaPolicy: chết 5 giây thì sống
	## lại) — đo hiệu năng / độ mượt / hành vi bot (tests/bot_bench_tests). "/testbotstats" trả bảng đếm hành vi (JSON) qua thông báo.
	if gs.test_mode and text.begins_with("/testbots "):
		var bp_parts := text.split(" ", false)
		var count := clampi(int(bp_parts[1]) if bp_parts.size() > 1 else 10, 1, 200)
		var diff := clampi(int(bp_parts[2]) if bp_parts.size() > 2 else -1, -1, 2)
		var sects := ["thieu_lam", "thien_vuong_bang", "nga_mi", "duong_mon", "ngu_doc_giao", "con_lon", "vo_dang", "cai_bang", "thuy_yen_mon", "thien_nhan_giao"]
		var arena := BotArenaPolicy.new(c.entity.pos + Vector2(500, 0), 350.0)
		var made: Array[ServerBot] = []
		for i in count:
			var bp := PlayerProfile.new()
			bp.display_name = "Bot %d" % (gs.bots.bots.size() + 1)
			bp.sect_id = sects[(i / 3) % sects.size()]   ## mỗi phái đủ 3 độ khó (không để độ khó trùng chu kỳ với phái)
			bp.level = 100
			bp.apply_start_stats()
			LonXonRules.refresh_skills(bp)
			LonXonRules.give_potions(bp)
			var spot: Vector2 = arena.center + Vector2.from_angle(TAU * i / count) * arena.radius * randf_range(0.4, 1.0)
			var free: Vector2 = gs.grid_of(c.entity).free_near(spot)
			var nb := gs.bots.spawn(bp, free if free != Vector2.ZERO else spot, c.entity.room_id, c.entity.cell_base, BotCombatBrain.new(), arena)
			nb.difficulty = diff if diff >= 0 else i % 3
			made.append(nb)
		for nb in made:
			arena._retarget(nb, gs.bots)
		gs.notice(c, "testbots %d" % made.size())
		return
	if gs.test_mode and text.begins_with("/testbotstats"):
		var by_diff := {}
		var deaths := 0
		for eid in gs.bots.bots:
			var ob: ServerBot = gs.bots.bots[eid]
			var key := str(ob.difficulty)
			if not by_diff.has(key):
				by_diff[key] = {"bots": 0, "casts": 0, "hits": 0, "dmg": 0, "taken": 0, "jumps": 0, "potions": 0, "dodges": 0, "buffs": 0, "kills": 0}
			var row: Dictionary = by_diff[key]
			row.bots += 1
			for k in ob.tally:
				row[k] = int(row.get(k, 0)) + int(ob.tally[k])
			if ob.policy is BotArenaPolicy:
				row.kills += int((ob.policy as BotArenaPolicy).kills_by.get(eid, 0))
				deaths = (ob.policy as BotArenaPolicy).deaths
		gs.notice(c, "botstats " + JSON.stringify({"by_diff": by_diff, "deaths": deaths, "tick_avg": gs._last_tick_avg, "tick_max": gs._last_tick_max, "kbs": gs._last_kbs}))
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
	## Lệnh GM: "/gmlevel <+N|-N|=N> [eid hoặc tên]" — đổi cấp người chơi, lên cấp cộng đủ điểm tiềm năng/kỹ năng.
	if text.begins_with("/gmlevel"):
		if not c.is_gm and not gs.test_mode:
			gs.notice(c, "Lệnh này chỉ dành cho GM.")
			return
		var parts := text.split(" ", false)
		if parts.size() < 2:
			gs.notice(c, "Cú pháp: /gmlevel <+N|-N|=N> [ID người chơi]")
			return
		var arg := parts[1]
		var absolute := arg.begins_with("=")
		var num_str := arg.substr(1) if absolute or arg.begins_with("+") else arg
		if not num_str.is_valid_int():
			gs.notice(c, "Số cấp không hợp lệ: %s" % arg)
			return
		var lv_target_c = c
		if parts.size() >= 3:
			lv_target_c = null
			if parts[2].is_valid_int():
				lv_target_c = gs.conn_of_eid(int(parts[2]))
		if lv_target_c == null or lv_target_c.profile == null:
			gs.notice(c, "Không tìm thấy người chơi có ID này.")
			return
		var old_lv: int = lv_target_c.profile.level
		var new_lv := int(num_str) if absolute else old_lv + int(num_str)
		lv_target_c.profile.gm_set_level(new_lv)
		if lv_target_c.entity:
			lv_target_c.entity.level = lv_target_c.profile.level
			lv_target_c.entity.touch()
		gs.profile_changed(lv_target_c)
		var who_name: String = lv_target_c.entity.name if lv_target_c.entity else lv_target_c.username
		gs.notice(c, "[GM] Cấp của %s: %d -> %d." % [who_name, old_lv, lv_target_c.profile.level])
		if lv_target_c != c:
			gs.notice(lv_target_c, "[GM] Cấp của bạn đã đổi: %d -> %d." % [old_lv, lv_target_c.profile.level])
		return
	if text.begins_with("/aura"):
		if not c.is_gm and not gs.test_mode:
			gs.notice(c, "Lệnh này chỉ dành cho GM.")
			return
		var parts := text.split(" ", false)
		if parts.size() < 2:
			gs.notice(c, "Cú pháp: /aura <id_state> [ID người chơi]")
			return
		var state_id := int(parts[1])
		var target_c = c
		if parts.size() >= 3:
			target_c = gs.conn_of_eid(int(parts[2])) if parts[2].is_valid_int() else null
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
	if text.begins_with("/camp") or text.begins_with("/gmcamp"):
		if not c.is_gm and not gs.test_mode:
			gs.notice(c, "Lệnh này chỉ dành cho GM.")
			return
		var parts := text.split(" ", false)
		if parts.size() < 2:
			gs.notice(c, "Cú pháp: /camp <camp_id> [ID người chơi]")
			return
		var camp_id := int(parts[1])
		if camp_id < 0 or camp_id > 8:
			gs.notice(c, "Camp ID không hợp lệ (0-8).")
			return
		var target_c = c
		if parts.size() >= 3:
			target_c = gs.conn_of_eid(int(parts[2])) if parts[2].is_valid_int() else null
		if target_c == null or target_c.entity == null or target_c.profile == null:
			gs.notice(c, "Không tìm thấy người chơi mục tiêu.")
			return
		target_c.profile.camp = camp_id
		target_c.data["camp"] = camp_id
		target_c.entity.camp = camp_id
		var camp_buf := NetProto.writer(NetProto.S_CAMP)
		camp_buf.put_u32(target_c.entity.eid)
		camp_buf.put_8(camp_id)
		camp_buf.put_u8(target_c.entity.nation)
		gs.send_to_viewers(target_c, camp_buf)
		gs.profile_changed(target_c)
		var who_name: String = target_c.entity.name if target_c.entity else target_c.username
		var camp_name: String = Camp.get_camp_name(camp_id)
		gs.notice(c, "[GM] Đã đổi phe cho %s sang: %s (Camp %d)." % [who_name, camp_name, camp_id])
		if target_c != c:
			gs.notice(target_c, "[GM] Phe của bạn đã đổi sang: %s." % camp_name)
		return
	var now := gs.now()
	var unix := Time.get_unix_time_from_system()
	if c.muted_until > unix:
		gs.notice(c, "Bạn đang bị cấm chat đến %s." % Time.get_datetime_string_from_unix_time(int(c.muted_until + 7 * 3600), true))
		return
	## Kết nối SẢNH (Character Hub) không đứng trên map: kênh Gần không có "người gần" — không lấy vị trí cũ của nhân vật (sẽ lọt tin tới
	## người đang đứng chỗ đó trên map).
	if channel == NEAR and c.hub:
		gs.notice(c, "Kênh Gần chỉ dùng khi đang ở trong map.")
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
		FACTION:
			var sect: String = c.profile.sect_id
			if sect == "":
				gs.notice(c, "Bạn chưa gia nhập môn phái.")
				return
			for to in gs.in_world_conns():
				if str(to.profile.sect_id) == sect:
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
