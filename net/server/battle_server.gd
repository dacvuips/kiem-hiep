class_name BattleServer
extends RefCounted
## CHIẾN TRƯỜNG TỐNG KIM — chạy trong 1 tiến trình game server RIÊNG (GAME_BATTLE=1, GAME_MAP_DIR = map chiến trường).
## Luật theo script server VLTK gốc (bản 15 phái, script/battles/ + settings/battles/maps/<map>/mapinfo.txt):
##   - Vòng trận lặp liên tục: BÁO DANH (signup) -> KHAI CHIẾN (fight) -> KẾT THÚC (ended, công bố thắng/thua) -> báo danh trận mới.
##     Thời gian gốc 10 phút báo danh / 60 phút đánh (battlehead.lua BAOMING_TIME / FIGHTING_TIME) — chỉnh bằng biến môi trường.
##   - Vào trận chọn phe Tống / Kim. Phe mình đông hơn đối phương >= BALANCE người thì không cho vào (battlejoin.lua 357-362,
##     ngưỡng gốc 5). Mỗi phe tối đa SIDE_CAP người (marshal/head.lua MAX_MEMBERCOUNT). Đã vào 1 phe thì cả trận không đổi phe được.
##   - Mỗi nhân vật chỉ được xin vào 1 lần / JOIN_COOLDOWN giây (chống bấm liên tục).
##   - Lúc báo danh: bị giữ trong khu trại phe mình (hậu doanh + đại doanh, data/battle/map_<id>.json camp_rect) — gốc: cổng đại doanh
##     đẩy lại "Hiện vẫn chưa khai chiến, không được phép rời Đại Doanh!" (centertrap.lua). Khai chiến thì ra được.
##   - Hậu doanh là khu KÍN: bước vào ô cổng hậu doanh (hometrap) -> dịch chuyển sang đại doanh; ô cổng đại doanh về hậu doanh
##     (centertohometrap) -> dịch chuyển về hậu doanh (hometrap1.lua / homeouttrap1.lua).
##   - Chết bấm "Về thành dưỡng sức": về hậu doanh phe mình (SetTempRevPos), REVIVE_PROTECT giây sau cổng hậu doanh mới cho ra.
##   - NGUYÊN SOÁI (marshal/smalltimer.lua 146-167, 221-242): khai chiến được MARSHAL_FIRST thời lượng trận thì Nguyên Soái của phe ÍT
##     điểm hơn xuất hiện ở đại doanh (bằng điểm: cả 2), tới MARSHAL_SECOND thì phe còn lại. Chỉ người phe kia đánh được. Hạ Nguyên Soái
##     phe kia: +MARSHAL_POINTS x hệ số (phe ít người hệ số > 1, battlehead.lua bonus_rate) và phe mình THẮNG (trận vẫn đánh tiếp tới hết
##     giờ); 2 Nguyên Soái đều bị hạ thì người hạ sau +MARSHAL_BOTH_POINTS x hệ số và thắng thua lại tính theo điểm (npcdeath.lua 78-125).
##   - Thưởng cuối trận (marshal/head.lua 122-233, battlehead.lua 302-304, 988-1006): phe thắng +WIN_POINTS điểm tích lũy, +WIN_REPUTE danh
##     vọng, 1 món ngẫu nhiên trong REWARD_ITEMS; phe thua +LOSE_POINTS. x4 trong 20:45-22:05; điểm tích lũy x2 cuối tuần. Phe thua không
##     còn ai thì không ai được thưởng. Điểm trong trận cũng cộng vào điểm tích lũy (PlayerProfile.songjin_points).
##   - Điểm: hạ người phe kia KILL_POINTS, mỗi STREAK_EVERY lần hạ liên tiếp không chết thêm STREAK_POINTS (battlehead.lua 218-230,
##     playerdeath.lua 34-49). Chết không mất điểm. Hết giờ phe nhiều điểm hơn thắng, bằng điểm thì Tống thắng (head.lua 348-356).
## Toàn bộ trạng thái chỉ ở server; game nhận qua S_BATTLE, màn chọn trận đọc qua server tài khoản (/v1/battle).

const OP_JOIN := 1        ## {side: "song" | "jin"}
const OP_STATE := 2       ## (không tham số) — xin gửi lại trạng thái ngay
const OP_BUY := 3         ## {mid: mã thuốc trong SHOP_ITEMS, count} — mua ở Quân nhu quan trong doanh trại phe mình

## Quân nhu quan (marshal/doctor.lua Sale(99) — buysell.txt dòng 100): các thuốc HỒI SINH LỰC của cửa hàng gốc (Kim Sáng Dược, Hồi Thiên,
## Cửu Chuyển, Thừa Tiên Mật, Thất Xảo, Ngũ Hoa Ngọc Lộ), giá theo goods.txt (cột "price" của misc_items). Thuốc nội lực / giải độc
## của cửa hàng gốc chưa bán vì game chưa có nội lực / hiệu ứng giảm độc.
const SHOP_ITEMS := ["1_0_0_1", "1_0_0_2", "1_0_0_3", "1_0_0_4", "1_0_0_5", "1_2_0_1", "1_2_0_2", "1_2_0_3", "1_2_0_4", "1_2_0_5"]
const SHOP_MAX_COUNT := 20
const DOCTOR_REACH := 400.0    ## đứng cách Quân nhu quan tối đa chừng này mới mua được

const SIDES := ["song", "jin"]
const NATION_OF := {"song": Nation.Type.SONG, "jin": Nation.Type.JIN}
const SIDE_NAMES := {"song": "Tống", "jin": "Kim"}

const BALANCE := 5
const SIDE_CAP := 150
const JOIN_COOLDOWN := 10.0
const REVIVE_PROTECT := 8.0
const KILL_POINTS := 75
const STREAK_EVERY := 3
const STREAK_POINTS := 150
const KILL_CREDIT_SECONDS := 10.0
const END_PAUSE := 60.0            ## giây công bố kết quả trước khi mở báo danh trận mới
const STATE_EVERY := 1.0           ## gửi trạng thái cho người trong trận mỗi chừng này giây
const REPORT_EVERY := 3.0          ## báo trạng thái lên server tài khoản
const NO_SIDE_KICK := 20.0         ## vào map mà không chọn phe trong chừng này giây -> ngắt
## Nguyên Soái: mẫu npcs.txt (Tống / Kim Nguyên Soái), cấp (simtk.lua mặc định 95); xuất hiện ở phút 15 / 20 của trận 60 phút gốc.
const MARSHAL_TPL := {"song": 636, "jin": 642}
const MARSHAL_LEVEL := 95
const MARSHAL_FIRST := 15.0 / 60.0
const MARSHAL_SECOND := 20.0 / 60.0
const MARSHAL_POINTS := 1000
const MARSHAL_BOTH_POINTS := 500
const NPC_RANK6_POINTS := 30          ## điểm hạ NPC hạng 6 (npcdeath.lua: Nguyên Soái)
const WIN_POINTS := 1200
const LOSE_POINTS := 600
const WIN_REPUTE := 3
## sf_aryItems (marshal/head.lua 13-25): phe thắng mỗi người 1 món, bốc đều (cột trọng số gốc không được đọc).
const REWARD_ITEMS := ["6_0_2", "6_0_5", "6_0_4", "6_0_1", "6_0_6", "6_0_10", "6_0_7", "6_0_9", "6_0_8", "6_0_3", "6_0_11", "6_0_20", "6_1_18"]
const TRAP_COOLDOWN := 1.5         ## vừa qua cổng: chừng này giây không kích hoạt cổng nữa (tránh nhảy qua lại)

var gs: GameServer
var map_id := 0
var map_name := "Chiến Trường Tống Kim"
var signup_seconds := 600.0
var fight_seconds := 3600.0
var min_level := 40
## CHỈ KIỂM THỬ (GAME_BATTLE_MARSHAL_LIFE, chỉ nhận khi GAME_TEST_MODE=1 — máy thật đặt nhầm cũng không làm Nguyên Soái yếu đi): đặt
## sinh lực Nguyên Soái. 0 = theo script cấp gốc soldier6 + npcs.txt server: cấp <= 75 / <= 95 / > 95 = 15 / 30 / 6 triệu (cấp 95: 30 triệu).
var marshal_life := 0.0
var public_host := "127.0.0.1"
var public_port := 7777
var public_ws := ""
var camps := {}                    ## khu "1" / "2" -> {home, center: [Vector2], home_trap, back_trap: {Vector2i ô: true}, camp_rect: Rect2}
## Phe nào đóng khu nào — bốc thăm lại mỗi trận (battlehead.lua camparea).
var area_of := {"song": "1", "jin": "2"}

var phase := "signup"
var phase_left := 0.0
var points := {"song": 0, "jin": 0}
var winner := ""
## character_id -> {side, name, points, kills, deaths, streak} — giữ cả khi rớt mạng / vào lại trong cùng 1 trận.
var members := {}
var _protect_until := {}           ## character_id -> giây (gs.now()) — mới hồi sinh, chưa được rời trại
var _last_try := {}                ## character_id -> lần xin vào gần nhất
var _arrived := {}                 ## character_id -> lúc vào map (chưa chọn phe)
var marshals := {}                 ## side -> ServerMonster (Nguyên Soái phe đó, đang có trên map)
var _marshal_stage := 0            ## 0 chưa ra, 1 đã ra phe đầu, 2 đã ra cả 2
## Phe đã hạ Nguyên Soái phe kia trước ("song" / "jin"), "both" = cả 2 Nguyên Soái đều bị hạ, "" = chưa.
var marshal_death := ""
var _trap_at := {}                 ## character_id -> lần qua cổng / bị cổng từ chối gần nhất
var _state_acc := 0.0
var _report_acc := REPORT_EVERY

func _init(server: GameServer, map_dir: String) -> void:
	gs = server
	map_id = int(map_dir.get_file().trim_prefix("map_"))
	signup_seconds = float(gs._env("GAME_BATTLE_SIGNUP", "600"))
	fight_seconds = float(gs._env("GAME_BATTLE_FIGHT", "3600"))
	min_level = int(gs._env("GAME_BATTLE_MIN_LEVEL", "40"))
	marshal_life = float(gs._env("GAME_BATTLE_MARSHAL_LIFE", "0")) if gs.test_mode else 0.0
	public_host = gs._env("GAME_PUBLIC_HOST", "127.0.0.1")
	public_port = int(gs._env("GAME_ENET_PORT", "7777"))
	public_ws = gs._env("GAME_PUBLIC_WS", "ws://%s:%s" % [public_host, gs._env("GAME_WS_PORT", "7778")])
	var path := "res://data/battle/map_%d.json" % map_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		push_error("BattleServer: thiếu %s (tools/import_vltk_battle_map.py)" % path)
		return
	for area in parsed["areas"]:
		var s: Dictionary = parsed["areas"][area]
		var r: Array = s["camp_rect"]
		camps[area] = {"home": _pts(s["home"]), "center": _pts(s["center"]), "home_trap": _cells(s["home_trap"]),
			"back_trap": _cells(s["back_trap"]), "general": Vector2(float(s["general"][0]), float(s["general"][1])), "doctor": Vector2(float(s["doctor"][0]), float(s["doctor"][1])), "camp_rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))}
	phase_left = signup_seconds
	_draw_areas()
	print("Chiến trường: map %d, báo danh %ds, khai chiến %ds, cấp tối thiểu %d" % [map_id, int(signup_seconds), int(fight_seconds), min_level])

## Bốc thăm khu cho 2 phe (gọi lúc mở báo danh mỗi trận).
func _draw_areas() -> void:
	var first := "1" if randi() % 2 == 0 else "2"
	area_of = {"song": first, "jin": "2" if first == "1" else "1"}

## Doanh trại của phe `side` trong trận này.
func camp_of(side: String) -> Dictionary:
	return camps[area_of[side]]

func _pts(list: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in list:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out

func _cells(list: Array) -> Dictionary:
	var out := {}
	for p in _pts(list):
		out[gs.grid.world_to_cell(p)] = true
	return out

func is_ready() -> bool:
	return camps.size() == 2

func side_of(c) -> String:
	if c == null:
		return ""
	var m: Dictionary = members.get(c.character_id, {})
	return str(m.get("side", ""))

## Phe Tống / Kim hiện trên đầu trong trận (Nation.Type).
func nation_of(c) -> int:
	var side := side_of(c)
	return int(NATION_OF[side]) if side != "" else Nation.Type.NONE

func count(side: String) -> int:
	var n := 0
	for c in gs.in_world_conns():
		if side_of(c) == side:
			n += 1
	return n

# ---------------------------------------------------------------- vòng trận

func tick(delta: float) -> void:
	if not is_ready():
		return
	phase_left -= delta
	if phase_left <= 0.0:
		_next_phase()
	if phase == "fight":
		_tick_marshals()
	var now := gs.now()
	for c in gs.in_world_conns():
		if side_of(c) == "" and now - float(_arrived.get(c.character_id, now)) > NO_SIDE_KICK:
			gs.kick(c, "battle_no_side", "Chưa chọn phe — rời chiến trường")
	_state_acc += delta
	if _state_acc >= STATE_EVERY:
		_state_acc = 0.0
		for c in gs.in_world_conns():
			if side_of(c) != "":
				_send(c, _state_for(c))
	_report_acc += delta
	if _report_acc >= REPORT_EVERY:
		_report_acc = 0.0
		_report()

func _next_phase() -> void:
	match phase:
		"signup":
			phase = "fight"
			phase_left = fight_seconds
			_broadcast_notice("Khai chiến! Cổng doanh trại đã mở — hãy ra trận.")
		"fight":
			phase = "ended"
			phase_left = END_PAUSE
			winner = marshal_death if SIDES.has(marshal_death) else ("song" if points["song"] >= points["jin"] else "jin")
			_broadcast_notice("Chiến trường kết thúc — phe %s thắng (%d : %d)." % [SIDE_NAMES[winner], points["song"], points["jin"]])
			var rewards := _give_rewards(winner)
			for c in gs.in_world_conns():
				var m: Dictionary = members.get(c.character_id, {})
				_send(c, {"op": "result", "winner": winner, "song_points": points["song"], "jin_points": points["jin"],
					"me": _me(m), "reward": rewards.get(c.character_id, {})})
		"ended":
			for c in gs.in_world_conns():
				gs.kick(c, "battle_end", "Trận Tống Kim đã kết thúc")
			phase = "signup"
			phase_left = signup_seconds
			points = {"song": 0, "jin": 0}
			winner = ""
			members.clear()
			_draw_areas()
			_protect_until.clear()
			_clear_marshals()
	_report_acc = REPORT_EVERY   ## báo ngay đổi giai đoạn

# ---------------------------------------------------------------- Quân nhu quan

## Mua thuốc: server trừ tiền + thêm vào túi rồi gửi bản nhân vật mới (S_PROFILE). Hết chỗ thì chỉ tính tiền số bình đã thêm.
func _buy(c, mid: String, n: int) -> void:
	var side := side_of(c)
	if side == "" or not SHOP_ITEMS.has(mid):
		return
	if c.entity.pos.distance_to(camp_of(side)["doctor"]) > DOCTOR_REACH:
		gs.notice(c, "Hãy đến gần Quân nhu quan trong hậu doanh.")
		return
	var record := ItemDatabase.get_misc(mid)
	var price := int(record.get("price", 0))
	n = clampi(n, 1, SHOP_MAX_COUNT)
	if price <= 0:
		return
	if c.profile.gold < price * n:
		gs.notice(c, "Không đủ tiền (cần %s lượng)." % InventoryPopup.format_money(price * n))
		return
	var bought := 0
	for i in n:
		var item := ItemGenerator.generate_misc(mid)
		if item == null or not c.profile.add_item(item):
			break
		bought += 1
	if bought == 0:
		gs.notice(c, "Hành trang đã đầy.")
		return
	c.profile.gold -= price * bought
	gs.profile_changed(c)
	gs.notice(c, "Đã mua %d %s (%s lượng)%s." % [bought, str(record.get("name", "")), InventoryPopup.format_money(price * bought),
		"" if bought == n else " — hành trang đã đầy"])

# ---------------------------------------------------------------- Nguyên Soái

func _tick_marshals() -> void:
	var elapsed := fight_seconds - phase_left
	if _marshal_stage == 0 and elapsed >= fight_seconds * MARSHAL_FIRST:
		_marshal_stage = 1
		if points["song"] == points["jin"]:
			_marshal_stage = 2
			_spawn_marshal("song")
			_spawn_marshal("jin")
		else:
			_spawn_marshal("song" if points["song"] < points["jin"] else "jin")   ## phe ít điểm hơn ra trước
	elif _marshal_stage == 1 and elapsed >= fight_seconds * MARSHAL_SECOND:
		_marshal_stage = 2
		for side in SIDES:
			if not marshals.has(side):
				_spawn_marshal(side)

func _spawn_marshal(side: String) -> void:
	var p: Vector2 = gs.grid.free_near(camp_of(side)["general"])
	var m := ServerMonster.from_entry({"t": MARSHAL_TPL[side], "lv": MARSHAL_LEVEL, "px": p.x, "py": p.y, "respawn": 1.0e9}, 0)
	if m == null:
		push_error("BattleServer: thiếu dữ liệu mẫu Nguyên Soái %d" % MARSHAL_TPL[side])
		return
	m.battle_side = side
	if marshal_life > 0.0:
		m.max_hp = marshal_life
		m.cur_hp = marshal_life
	gs.add_monster(m)
	print("Nguyên Soái %s: eid %d, sinh lực %d, tại %s" % [side, m.eid, int(m.max_hp), m.pos])
	marshals[side] = m
	_broadcast_notice("Nguyên Soái phe %s đã xuất hiện tại đại doanh!" % SIDE_NAMES[side])

func _clear_marshals() -> void:
	for m in marshals.values():
		gs.remove_monster(m)
	marshals.clear()
	_marshal_stage = 0
	marshal_death = ""

## Hệ số thưởng của phe `side` (battlehead.lua bonus_rate): phe ít người hơn > 1, đông hơn < 1.
func bonus_rate(side: String) -> float:
	var avg := (count("song") + count("jin")) / 2.0
	return 1.0 if avg <= 0.0 else 1.0 - (count(side) - avg) / avg

## Người chơi `c` có được đánh quái `m` không (Nguyên Soái: chỉ người phe kia, lúc khai chiến).
func can_hit_monster(c, m: ServerMonster) -> bool:
	var side := side_of(c)
	return phase == "fight" and side != "" and side != m.battle_side

func on_monster_killed(m: ServerMonster, killer) -> void:
	var side := side_of(killer)
	if side == "" or side == m.battle_side:
		return
	var k: Dictionary = members[killer.character_id]
	var gain := NPC_RANK6_POINTS
	if marshal_death == _other(side):     ## phe kia đã hạ Nguyên Soái phe mình trước -> hoà về điểm
		marshal_death = "both"
		gain += floori(bonus_rate(side) * MARSHAL_BOTH_POINTS)
	else:
		marshal_death = side
		gain += floori(bonus_rate(side) * MARSHAL_POINTS)
	k["points"] = int(k["points"]) + gain
	points[side] = int(points[side]) + gain
	_broadcast_notice("%s phe %s đã hạ Nguyên Soái phe %s (+%d điểm)!" % [killer.entity.name, SIDE_NAMES[side], SIDE_NAMES[m.battle_side], gain])

# ---------------------------------------------------------------- thưởng cuối trận

## Hệ số thưởng theo giờ (bt_getgn_awardtimes): x4 trong 20:45 - 22:05.
static func reward_multiplier() -> int:
	var t := Time.get_time_dict_from_system()
	var minute := int(t.hour) * 60 + int(t.minute)
	return 4 if minute >= 20 * 60 + 45 and minute < 22 * 60 + 5 else 1

## Cuối tuần điểm tích lũy x2 (battlehead.lua isCuoiTuan).
static func weekend_multiplier() -> int:
	var wd := int(Time.get_date_dict_from_system().weekday)
	return 2 if wd == Time.WEEKDAY_SATURDAY or wd == Time.WEEKDAY_SUNDAY else 1

## Thưởng người đang trong trận: character_id -> {points, repute, item}. Phe thua không còn ai thì không thưởng.
func _give_rewards(win_side: String) -> Dictionary:
	var out := {}
	if count(_other(win_side)) == 0:
		_broadcast_notice("Phe %s không còn ai trên chiến trường — trận này không có phần thưởng." % SIDE_NAMES[_other(win_side)])
		return out
	var mult := reward_multiplier()
	var weekend := weekend_multiplier()
	for c in gs.in_world_conns():
		var side := side_of(c)
		if side == "":
			continue
		var m: Dictionary = members[c.character_id]
		var won := side == win_side
		var add := ((WIN_POINTS if won else LOSE_POINTS) * mult + int(m["points"])) * weekend
		c.profile.songjin_points += add
		var r := {"points": add, "total": c.profile.songjin_points}
		if won:
			c.profile.prestige += WIN_REPUTE * mult
			r["repute"] = WIN_REPUTE * mult
			var item := ItemGenerator.generate_misc(REWARD_ITEMS[randi() % REWARD_ITEMS.size()])
			if item and c.profile.add_item(item):
				r["item"] = item.get_display_name()
			elif item:
				gs.notice(c, "Hành trang đã đầy — không nhận được %s." % item.get_display_name())
		gs.profile_changed(c)
		gs.notice(c, "Nhận %d điểm tích lũy Tống Kim%s%s." % [add, (", %d danh vọng" % r["repute"]) if r.has("repute") else "",
			(", " + str(r["item"])) if r.has("item") else ""])
		out[c.character_id] = r
	return out

# ---------------------------------------------------------------- người chơi

## Vừa vào map (sau xác thực): đứng tạm ở điểm xuất phát, chờ gói chọn phe. Vào lại giữa trận (rớt mạng) thì về trại phe cũ.
func on_join_world(c) -> void:
	_arrived[c.character_id] = gs.now()
	if side_of(c) != "":
		_place_home(c)
		_send(c, {"op": "joined", "side": side_of(c), "area": area_of[side_of(c)]})
		gs.refresh_camp(c)

func on_leave(c) -> void:
	_arrived.erase(c.character_id)
	_trap_at.erase(c.character_id)

func on_battle(c, b: StreamPeerBuffer) -> void:
	var op := b.get_u8()
	var parsed: Variant = JSON.parse_string(NetProto.get_str(b, 512))
	var args: Dictionary = parsed if parsed is Dictionary else {}
	match op:
		OP_JOIN:
			_join(c, str(args.get("side", "")))
		OP_STATE:
			if side_of(c) != "":
				_send(c, _state_for(c))
		OP_BUY:
			_buy(c, str(args.get("mid", "")), int(args.get("count", 1)))

func _join(c, side: String) -> void:
	if not SIDES.has(side):
		return
	var cid: int = c.character_id
	var current := side_of(c)
	if current == side:   ## vào lại phe cũ (rớt mạng): không tính lượt chờ
		on_join_world(c)
		return
	var now := gs.now()
	var wait := JOIN_COOLDOWN - (now - float(_last_try.get(cid, -INF)))
	if wait > 0.0:
		_reject(c, "Thao tác quá nhanh — %d giây nữa mới báo danh lại được." % ceili(wait))
		return
	_last_try[cid] = now
	if phase == "ended":
		_reject(c, "Trận này đã kết thúc, xin chờ trận sau.")
		return
	if current != "":
		_reject(c, "Bạn đã báo danh phe %s trong trận này, không thể đổi phe." % SIDE_NAMES[current])
		return
	if c.profile.level < min_level:
		_reject(c, "Cấp %d trở lên mới được vào chiến trường Tống Kim." % min_level)
		return
	var mine := count(side)
	var other := count(_other(side))
	if mine >= SIDE_CAP:
		_reject(c, "Phe %s đã đủ %d người." % [SIDE_NAMES[side], SIDE_CAP])
		return
	if mine - other >= BALANCE:
		_reject(c, "Hiện tại binh lực phe ta là %d người, địch phương là %d người, cách biệt %d người. Quân lực phe ta đã dư sức, tráng sĩ hãy vào phe %s hoặc đợi trận sau." % [mine, other, mine - other, SIDE_NAMES[_other(side)]])
		return
	members[cid] = {"side": side, "name": c.entity.name, "points": 0, "kills": 0, "deaths": 0, "streak": 0}
	_arrived.erase(cid)
	_place_home(c)
	gs.refresh_camp(c)
	_send(c, {"op": "joined", "side": side, "area": area_of[side]})
	_send(c, _state_for(c))
	gs.notice(c, "Đã báo danh phe %s. %s" % [SIDE_NAMES[side], "Chờ khai chiến trong doanh trại." if phase == "signup" else "Trận đang diễn ra — xông lên!"])
	_report_acc = REPORT_EVERY

func _reject(c, message: String) -> void:
	_send(c, {"op": "reject", "message": message})

func _other(side: String) -> String:
	return "jin" if side == "song" else "song"

func _place_home(c) -> void:
	var homes: Array = camp_of(side_of(c))["home"]
	var p: Vector2 = gs.grid.free_near(homes[randi() % homes.size()])
	_trap_at[c.character_id] = gs.now()
	gs.teleport(c, p)

## Sau mỗi bước đi server đã nhận: đứng lên ô cổng của trại phe mình thì dịch chuyển.
func on_moved(c, p: Vector2) -> void:
	var side := side_of(c)
	if side == "" or (c.entity.flags & NetProto.FLAG_DEAD) != 0:
		return
	var now := gs.now()
	if now - float(_trap_at.get(c.character_id, -INF)) < TRAP_COOLDOWN:
		return
	var cell: Vector2i = gs.grid.world_to_cell(p)
	var camp: Dictionary = camp_of(side)
	if camp["home_trap"].has(cell):
		_trap_at[c.character_id] = now
		var wait := float(_protect_until.get(c.character_id, 0.0)) - now
		if wait > 0.0:
			gs.notice(c, "%d giây sau bạn mới có thể rời khỏi hậu doanh! Xin đợi chút nữa!" % ceili(wait))
			return
		var centers: Array = camp["center"]
		gs.teleport(c, gs.grid.free_near(centers[randi() % centers.size()]))
	elif camp["back_trap"].has(cell):
		_place_home(c)

## Có được đứng ở `p` không: lúc báo danh phải ở trong khu trại phe mình (cổng đại doanh chưa mở — centertrap.lua).
func allows_pos(c, p: Vector2) -> bool:
	var side := side_of(c)
	if side == "":
		return true
	return phase != "signup" or (camp_of(side)["camp_rect"] as Rect2).has_point(p)

## Đòn PvP giữa 2 người: chỉ lúc khai chiến, 2 phe khác nhau.
func allows_hit(a, b) -> bool:
	if phase != "fight" or a == null or b == null:
		return false
	var sa := side_of(a)
	var sb := side_of(b)
	return sa != "" and sb != "" and sa != sb

## Nhân vật `c` vừa chết (cờ FLAG_DEAD từ game): cộng điểm cho người hạ nếu là phe kia và vừa đánh trúng.
func on_died(c) -> void:
	var victim: Dictionary = members.get(c.character_id, {})
	if victim.is_empty():
		return
	victim["deaths"] = int(victim["deaths"]) + 1
	victim["streak"] = 0
	if phase != "fight" or gs.now() - c.last_pvp_at > KILL_CREDIT_SECONDS:
		return
	var killer = gs.conn_of_eid(c.last_pvp_from)
	if killer == null or not allows_hit(killer, c):
		return
	var k: Dictionary = members[killer.character_id]
	var gain := KILL_POINTS
	k["kills"] = int(k["kills"]) + 1
	k["streak"] = int(k["streak"]) + 1
	if int(k["streak"]) % STREAK_EVERY == 0:
		gain += STREAK_POINTS
		gs.notice(killer, "Liên trảm %d người! Thêm %d điểm." % [int(k["streak"]), STREAK_POINTS])
	k["points"] = int(k["points"]) + gain
	points[k["side"]] = int(points[k["side"]]) + gain
	gs.notice(killer, "Bạn đã hạ %s (+%d điểm)." % [c.entity.name, gain])
	gs.notice(c, "Bạn bị %s hạ." % killer.entity.name)

## Hồi sinh: về hậu doanh phe mình, chưa rời trại được REVIVE_PROTECT giây. Trả về false nếu không phải người trong trận.
func on_revive(c) -> bool:
	if side_of(c) == "":
		return false
	_protect_until[c.character_id] = gs.now() + REVIVE_PROTECT
	_place_home(c)
	gs.notice(c, "%d giây sau mới có thể rời khỏi hậu doanh!" % int(REVIVE_PROTECT))
	return true

# ---------------------------------------------------------------- gửi trạng thái

func _me(m: Dictionary) -> Dictionary:
	return {"side": m.get("side", ""), "points": m.get("points", 0), "kills": m.get("kills", 0), "deaths": m.get("deaths", 0)}

func _state_for(c) -> Dictionary:
	return {"op": "state", "phase": phase, "left": ceili(phase_left), "song": count("song"), "jin": count("jin"), "areas": area_of,
		"song_points": points["song"], "jin_points": points["jin"], "me": _me(members.get(c.character_id, {})),
		"protect": maxf(0.0, float(_protect_until.get(c.character_id, 0.0)) - gs.now())}

func _send(c, msg: Dictionary) -> void:
	var b := NetProto.writer(NetProto.S_BATTLE)
	NetProto.put_str(b, JSON.stringify(msg))
	gs.send(c, b)

func _broadcast_notice(text: String) -> void:
	for c in gs.in_world_conns():
		gs.notice(c, text)

func _report() -> void:
	gs.account.report_battle({"server_id": gs.account.server_id, "map_id": map_id, "map_name": map_name, "phase": phase,
		"phase_left": ceili(phase_left), "song": count("song"), "jin": count("jin"), "song_points": points["song"],
		"jin_points": points["jin"], "balance": BALANCE, "side_cap": SIDE_CAP, "min_level": min_level, "winner": winner,
		"host": public_host, "port": public_port, "ws_url": public_ws, "open": true})
