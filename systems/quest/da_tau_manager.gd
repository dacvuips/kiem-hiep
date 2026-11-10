extends RefCounted
class_name DaTauManager
## Quản lý logic nghiệp vụ Dã Tẩu (TaskLink).

const DaTauData = preload("res://systems/quest/da_tau_data.gd")
## Tất cả method đều là static — không đăng ký làm Autoload.
## Dùng: DaTauManager.accept_quest(profile), DaTauManager.complete_quest(profile), ...
##
## Phụ thuộc: DaTauData (data layer), PlayerProfile (trạng thái)

const RECORD_PATH := "user://da_tau_records.json"

static func get_record_key(profile: PlayerProfile = null) -> String:
	var p := profile if profile != null else GameManager.local_profile
	var acc_id := ""
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("AccountApi"):
		var api = tree.root.get_node("AccountApi")
		if api.has_method("is_logged_in") and api.is_logged_in() and api.account is Dictionary:
			acc_id = str(api.account.get("username", ""))
			if acc_id.is_empty():
				acc_id = str(api.account.get("id", ""))
	var char_name := p.display_name if p != null else ""
	var key := ""
	if not acc_id.is_empty() and not char_name.is_empty():
		key = "%s_%s" % [acc_id, char_name]
	elif not acc_id.is_empty():
		key = acc_id
	elif not char_name.is_empty():
		key = char_name
	else:
		key = "default"

	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		key = key.replace(ch, "_")
	return key

static func get_record_path(profile: PlayerProfile = null) -> String:
	return "user://da_tau_records_%s.json" % get_record_key(profile)

static func load_records(profile: PlayerProfile = null) -> Dictionary:
	var path := get_record_path(profile)
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(RECORD_PATH):
			var old_txt := FileAccess.get_file_as_string(RECORD_PATH)
			var old_p: Variant = JSON.parse_string(old_txt)
			if old_p is Dictionary:
				save_records(old_p, profile)
				return old_p
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

static func save_records(rec: Dictionary, profile: PlayerProfile = null) -> void:
	var path := get_record_path(profile)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rec, "  "))

## Lấy state Dã Tẩu từ profile, đảm bảo tồn tại và đồng bộ 2 chiều với file lưu máy
static func _get_state(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return DaTauData.DEFAULT_STATE.duplicate(true)

	if not profile.da_tau is Dictionary or profile.da_tau.is_empty():
		var disk_rec := load_records(profile)
		if not disk_rec.is_empty():
			profile.da_tau = disk_rec.duplicate(true)
		else:
			profile.da_tau = DaTauData.DEFAULT_STATE.duplicate(true)

	# Đảm bảo các key mới tồn tại (backward compat)
	var changed := false
	for key in DaTauData.DEFAULT_STATE:
		if not profile.da_tau.has(key):
			profile.da_tau[key] = DaTauData.DEFAULT_STATE[key]
			changed = true

	# Reset dữ liệu ngày nếu hôm nay là ngày mới
	var today := Time.get_date_string_from_system()
	if profile.da_tau.get("last_reset_date", "") != today:
		profile.da_tau["done_today"] = 0
		profile.da_tau["skip_today"] = 0
		profile.da_tau["last_reset_date"] = today
		changed = true

	if changed:
		save_records(profile.da_tau, profile)

	return profile.da_tau

## Reset dữ liệu ngày nếu hôm nay là ngày mới
static func reset_daily_if_needed(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var state := _get_state(profile)
	var today := Time.get_date_string_from_system()
	if state.get("last_reset_date", "") != today:
		state["done_today"] = 0
		state["skip_today"] = 0
		state["last_reset_date"] = today
		save_records(state, profile)

## Kiểm tra có thể nhận nhiệm vụ mới không
static func can_accept(profile: PlayerProfile) -> bool:
	var state := _get_state(profile)
	reset_daily_if_needed(profile)
	if state["current_quest"] != null:
		return false  # Đang có nhiệm vụ chưa xong
	return state["done_today"] < DaTauData.MAX_QUEST_PER_DAY

## Nhận nhiệm vụ mới — trả về quest dict đã tạo, hoặc {} nếu không được
static func accept_quest(profile: PlayerProfile) -> Dictionary:
	if not can_accept(profile):
		return {}
	var state := _get_state(profile)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var level_link := DaTauData.get_level_link(profile.level)
	var quest_type := DaTauData.pick_quest_type(level_link, rng)
	var quest := _build_quest(quest_type, level_link, rng, profile)
	if quest.is_empty():
		# Fallback về type 4 nếu không tìm được quest phù hợp
		quest = _build_quest(4, level_link, rng, profile)
	if quest.is_empty():
		return {}
	state["current_quest"] = quest
	state["scroll_count"] = 0
	save_records(state, profile)
	return quest

## Tạo cấu trúc quest từ type và level_link
static func _build_quest(quest_type: int, level_link: int, rng: RandomNumberGenerator, profile: PlayerProfile) -> Dictionary:
	match quest_type:
		1:
			return _build_type1(level_link, rng)
		2:
			return _build_type2(level_link, rng)
		3:
			return _build_type3(level_link, rng)
		4:
			return _build_type4(level_link, rng)
		5:
			return _build_type5(level_link, rng, profile)
		6:
			return _build_type6(level_link, rng, profile)
	return {}

## Type 1: Mua vật phẩm (mua từ NPC thương nhân)
static func _build_type1(level_link: int, _rng: RandomNumberGenerator) -> Dictionary:
	# Vật phẩm theo level_link: đơn giản nhất
	var items := [
		{"name": "Thái Y Linh Đan", "price": 500 * level_link, "quantity": 3},
		{"name": "Linh Dược Tốt", "price": 300 * level_link, "quantity": 5},
		{"name": "Trà Thanh Tâm", "price": 200 * level_link, "quantity": 10},
	]
	var item: Dictionary = items[_rng.randi_range(0, items.size() - 1)]
	return {
		"type": 1,
		"level_link": level_link,
		"desc": "Mua %d %s từ Thương Nhân" % [item["quantity"], item["name"]],
		"item_name": item["name"],
		"need_num": item["quantity"],
		"done_num": 0,
		"reward_pts": 15000 * level_link,
		"gold_cost": item["price"] * item["quantity"],
	}

## Type 2: Tìm vật phẩm (nhặt hoặc mua từ người chơi khác)
static func _build_type2(level_link: int, rng: RandomNumberGenerator) -> Dictionary:
	var eligible := DaTauData.get_findmaps_for_level_link(level_link)
	if eligible.is_empty():
		return {}
	var entry := DaTauData.pick_weighted(eligible, level_link, rng)
	if entry.is_empty():
		return {}
	return {
		"type": 2,
		"level_link": level_link,
		"map_id": entry["map_id"],
		"godot_map_id": entry["godot_map_id"],
		"map_name": entry["map_name"],
		"map_type": entry["map_type"],
		"need_num": entry["num"],
		"done_num": 0,
		"reward_pts": entry["task_value"],
		"desc": "Tìm %d cuộn %s tại %s" % [
			entry["num"],
			("Địa đồ chí" if entry["map_type"] == 1 else "Mật chí"),
			entry["map_name"]
		],
	}

## Type 3: Xem vật phẩm (nộp vật phẩm cho NPC xem rồi lấy lại)
static func _build_type3(level_link: int, rng: RandomNumberGenerator) -> Dictionary:
	var eligible := DaTauData.get_findmaps_for_level_link(level_link)
	if eligible.is_empty():
		return {}
	var entry := DaTauData.pick_weighted(eligible, level_link, rng)
	if entry.is_empty():
		return {}
	return {
		"type": 3,
		"level_link": level_link,
		"map_id": entry["map_id"],
		"godot_map_id": entry["godot_map_id"],
		"map_name": entry["map_name"],
		"map_type": entry["map_type"],
		"need_num": entry["num"],
		"done_num": 0,
		"reward_pts": entry["task_value"],
		"item_submitted": false,  # Người dùng cần đặt vật phẩm vào ô nộp
		"desc": "Đưa cho Dã Tẩu xem %d cuộn %s" % [
			entry["num"],
			("Địa đồ chí" if entry["map_type"] == 1 else "Mật chí"),
		],
	}

## Type 4: Thu thập Địa đồ / Mật chí (giết quái ở map cụ thể)
static func _build_type4(level_link: int, rng: RandomNumberGenerator) -> Dictionary:
	var eligible := DaTauData.get_findmaps_for_level_link(level_link)
	if eligible.is_empty():
		return {}
	var entry := DaTauData.pick_weighted(eligible, level_link, rng)
	if entry.is_empty():
		return {}
	return {
		"type": 4,
		"level_link": level_link,
		"map_id": entry["map_id"],
		"godot_map_id": entry["godot_map_id"],
		"map_name": entry["map_name"],
		"map_type": entry["map_type"],
		"need_num": entry["num"],
		"done_num": 0,
		"reward_pts": entry["task_value"],
		"scroll_type": entry["map_type"],  # 1=Địa đồ, 2=Mật chí
		"desc": "Thu thập %d cuộn %s tại %s" % [
			entry["num"],
			("Địa đồ chí" if entry["map_type"] == 1 else "Mật chí"),
			entry["map_name"]
		],
	}

## Type 5: Nâng cấp chỉ số (cần đủ điểm Lực/Nhanh/Sinh/Nội)
static func _build_type5(level_link: int, rng: RandomNumberGenerator, profile: PlayerProfile) -> Dictionary:
	# Lọc các upground entry phù hợp: profile phải đủ need_value
	var eligible: Array[Dictionary] = []
	var weights: Array[int] = []
	var ll_idx := clampi(level_link - 1, 0, 19)
	for entry in DaTauData.UPGROUND_DATA:
		var r: int = entry["rates"][ll_idx]
		if r <= 0:
			continue
		# Kiểm tra giá trị hiện tại của chỉ số tương ứng
		var cur_value := _get_numeric_value(profile, entry["numeric_type"])
		if cur_value >= entry["need_value"]:
			eligible.append(entry)
			weights.append(r)
	if eligible.is_empty():
		return {}
	# Random có trọng số
	var total := 0
	for w in weights:
		total += w
	var roll := rng.randi_range(0, total - 1)
	var acc := 0
	var chosen := eligible[0]
	for i in eligible.size():
		acc += weights[i]
		if roll < acc:
			chosen = eligible[i]
			break
	var stat_name: String = DaTauData.NUMERIC_TYPE_NAMES.get(chosen["numeric_type"], "Chỉ số")
	return {
		"type": 5,
		"level_link": level_link,
		"numeric_type": chosen["numeric_type"],
		"need_value": chosen["need_value"],
		"reward_pts": chosen["reward_pts"],
		"done_num": 0,
		"need_num": 1,
		"desc": "Đạt %s ≥ %d điểm" % [stat_name, chosen["need_value"]],
	}

## Type 6: Dùng điểm Dã Tẩu (tương đương Sơn Hà Xã Tắc đồ)
static func _build_type6(level_link: int, rng: RandomNumberGenerator, profile: PlayerProfile) -> Dictionary:
	var state := _get_state(profile)
	var cur_pts: int = state.get("da_tau_points_session", 0)
	var eligible: Array[Dictionary] = []
	var weights: Array[int] = []
	var ll_idx := clampi(level_link - 1, 0, 19)
	for entry in DaTauData.WORLDMAPS_DATA:
		var r: int = entry["rates"][ll_idx]
		if r <= 0:
			continue
		if cur_pts >= entry["num"]:  # Đủ điểm để nộp
			eligible.append(entry)
			weights.append(r)
	if eligible.is_empty():
		# Dùng num nhỏ nhất (1 điểm) làm fallback
		if DaTauData.WORLDMAPS_DATA.size() > 0:
			var e := DaTauData.WORLDMAPS_DATA[0]
			return {
				"type": 6,
				"level_link": level_link,
				"num": e["num"],
				"reward_pts": e["reward_pts"],
				"done_num": 0,
				"need_num": e["num"],
				"desc": "Nộp %d điểm Dã Tẩu (hiện có: %d)" % [e["num"], cur_pts],
			}
		return {}
	var total := 0
	for w in weights:
		total += w
	var roll := rng.randi_range(0, total - 1)
	var acc := 0
	var chosen := eligible[0]
	for i in eligible.size():
		acc += weights[i]
		if roll < acc:
			chosen = eligible[i]
			break
	return {
		"type": 6,
		"level_link": level_link,
		"num": chosen["num"],
		"reward_pts": chosen["reward_pts"],
		"done_num": 0,
		"need_num": chosen["num"],
		"desc": "Nộp %d điểm Dã Tẩu (hiện có: %d)" % [chosen["num"], cur_pts],
	}

## Lấy giá trị chỉ số nhân vật theo numeric_type (source)
static func _get_numeric_value(profile: PlayerProfile, numeric_type: int) -> int:
	match numeric_type:
		2: return profile.strength
		3: return profile.dexterity
		4: return profile.vitality
		5: return profile.energy
	return 0

## Lấy quest hiện tại (null nếu không có)
static func get_current_quest(profile: PlayerProfile) -> Variant:
	var state := _get_state(profile)
	return state.get("current_quest", null)

## Kiểm tra nhiệm vụ hoàn thành chưa
static func check_quest_complete(profile: PlayerProfile) -> bool:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null:
		return false
	if not quest is Dictionary:
		return false
	var q := quest as Dictionary
	match int(q.get("type", 0)):
		1, 2, 3, 4:
			return int(q.get("done_num", 0)) >= int(q.get("need_num", 1))
		5:
			# Kiểm tra giá trị chỉ số HIỆN TẠI
			var ntype: int = int(q.get("numeric_type", 2))
			var need: int = int(q.get("need_value", 0))
			return _get_numeric_value(profile, ntype) >= need
		6:
			var state2 := _get_state(profile)
			return int(state2.get("da_tau_points_session", 0)) >= int(q.get("need_num", 1))
	return false

## Định dạng số hiển thị chấm ngăn cách hàng nghìn (ví dụ 240.000)
static func format_num(val: int) -> String:
	var s := str(absi(val))
	var res := ""
	while s.length() > 3:
		res = "." + s.substr(s.length() - 3) + res
		s = s.substr(0, s.length() - 3)
	return ("-" if val < 0 else "") + s + res

## Lấy hoặc sinh 3 Option phần thưởng khi hoàn thành nhiệm vụ (chuẩn JX1 source datau.lua & UiDaTau.ini)
## Option 0: Kinh Nghiệm (EXP)
## Option 1: Ngân Lượng (Bạc)
## Option 2: Vật Phẩm / May Mắn / Khoáng Thạch / Dược Phẩm / Trang Bị
static func get_or_create_reward_options(profile: PlayerProfile) -> Array[Dictionary]:
	var state := _get_state(profile)
	var pending: Array = state.get("pending_options", [])
	if pending.size() == 3:
		var typed_pending: Array[Dictionary] = []
		for item in pending:
			if item is Dictionary:
				typed_pending.append(item as Dictionary)
		if typed_pending.size() == 3:
			return typed_pending

	if not check_quest_complete(profile):
		return []
	var quest: Variant = state.get("current_quest", null)
	if not quest is Dictionary:
		return []
	var q := quest as Dictionary

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var char_level: int = profile.level if profile != null else 1
	var n_level := clampi(int(char_level / 10), 0, 9)
	var n_diff := clampi(int(q.get("level_link", 1)), 1, 20)

	# 1. OPTION 0: KINH NGHIỆM (datau.lua: EXP_REWARDS[nLevel] * nDiff)
	var min_exp: int = DaTauData.EXP_REWARDS[n_level].x * n_diff
	var max_exp: int = DaTauData.EXP_REWARDS[n_level].y * n_diff
	var exp_val: int = rng.randi_range(min_exp, max_exp)
	var opt_exp: Dictionary = {
		"type": "exp",
		"name": "Kinh Nghiệm",
		"icon": "📜",
		"amount": exp_val,
		"desc": "+%s Điểm EXP" % format_num(exp_val),
	}

	# 2. OPTION 1: NGÂN LƯỢNG (datau.lua: nLevel * (2000 + nDiff) * ...)
	var min_gold: int = (n_level + 1) * (2000 + n_diff) * 4
	var max_gold: int = (n_level + 1) * (2000 + n_diff) * n_diff * 8
	var gold_val: int = rng.randi_range(min_gold, max_gold)
	var opt_gold: Dictionary = {
		"type": "gold",
		"name": "Ngân Lượng",
		"icon": "💰",
		"amount": gold_val,
		"desc": "+%s Lượng Bạc" % format_num(gold_val),
	}

	# 3. OPTION 2: VẬT PHẨM / MAY MẮN (datau.lua: mốc nhiệm vụ hoặc ngẫu nhiên khoáng thạch/dược phẩm/trang bị)
	var cur_quest_num: int = int(state.get("done_today", 0)) + 1
	var opt_item: Dictionary = {}

	match cur_quest_num:
		10:
			opt_item = {
				"type": "misc",
				"misc_id": "6_1_71",
				"name": "Tiên Thảo Lộ",
				"icon": "🌿",
				"quantity": 1,
				"desc": "Mốc 10: Tiên Thảo Lộ ×1 (Nhân đôi EXP)",
			}
		20:
			opt_item = {
				"type": "misc",
				"misc_id": "4_238_1",
				"name": "Lam Thủy Tinh",
				"icon": "💎",
				"quantity": 1,
				"desc": "Mốc 20: Lam Thủy Tinh ×1 (Đổi ngũ hành)",
			}
		30:
			opt_item = {
				"type": "misc",
				"misc_id": "4_239_1",
				"name": "Tử Thủy Tinh",
				"icon": "🔮",
				"quantity": 1,
				"desc": "Mốc 30: Tử Thủy Tinh ×1 (Nâng cấp trang bị)",
			}
		40:
			opt_item = {
				"type": "equip",
				"name": "Trang Bị Dã Tẩu Quý",
				"icon": "🛡️",
				"quantity": 1,
				"desc": "Mốc 40: Trang bị hiếm phù hợp cấp độ",
			}
		50:
			opt_item = {
				"type": "misc",
				"misc_id": "4_353_1",
				"name": "Tinh Hồng Bảo Thạch",
				"icon": "❤️",
				"quantity": 1,
				"desc": "Mốc 50: Tinh Hồng Bảo Thạch ×1 (Đại thưởng hoàn thành)",
			}
		_:
			# Nhiệm vụ thông thường: roll theo tỷ lệ gốc VLTK (Dược phẩm 40%, Khoáng thạch 35%, Ngẫu nhiên 25%)
			var roll := rng.randi_range(1, 100)
			if roll <= 40:
				var r_med := rng.randi_range(1, 2)
				if r_med == 1:
					opt_item = {
						"type": "misc",
						"misc_id": "6_1_71",
						"name": "Tiên Thảo Lộ",
						"icon": "🌿",
						"quantity": 1,
						"desc": "Dược phẩm: Tiên Thảo Lộ ×1",
					}
				else:
					opt_item = {
						"type": "item_thaiy",
						"name": "Thái Y Linh Đan",
						"icon": "💊",
						"quantity": maxi(n_diff * 2, 2),
						"desc": "Dược phẩm: Thái Y Linh Đan ×%d" % maxi(n_diff * 2, 2),
					}
			elif roll <= 75:
				var gems := [
					{"id": "4_238_1", "name": "Lam Thủy Tinh", "icon": "💎"},
					{"id": "4_239_1", "name": "Tử Thủy Tinh", "icon": "🔮"},
					{"id": "4_240_1", "name": "Lục Thủy Tinh", "icon": "💠"},
				]
				var gem: Dictionary = gems[rng.randi_range(0, gems.size() - 1)]
				opt_item = {
					"type": "misc",
					"misc_id": gem["id"],
					"name": gem["name"],
					"icon": gem["icon"],
					"quantity": 1,
					"desc": "Khoáng thạch: %s ×1" % gem["name"],
				}
			else:
				var is_equip := rng.randi_range(1, 2) == 1
				if is_equip:
					opt_item = {
						"type": "equip",
						"name": "Trang Bị Dã Tẩu",
						"icon": "⚔️",
						"quantity": 1,
						"desc": "Trang bị ngẫu nhiên theo cấp độ",
					}
				else:
					opt_item = {
						"type": "misc",
						"misc_id": "6_1_1476",
						"name": "Bao Hoàng Kim Dã Tẩu",
						"icon": "🎁",
						"quantity": 1,
						"desc": "Cơ duyên: Bao Hoàng Kim Dã Tẩu ×1",
					}

	var options: Array[Dictionary] = [opt_exp, opt_gold, opt_item]
	state["pending_options"] = options
	save_records(state, profile)
	return options

## Người chơi chọn 1 trong 3 phần thưởng:
## option_idx: 0=Kinh Nghiệm, 1=Ngân Lượng, 2=Vật Phẩm
## Điểm Dã Tẩu luôn luôn được tự động cộng vào tích lũy.
static func claim_reward_option(profile: PlayerProfile, option_idx: int) -> Dictionary:
	var options := get_or_create_reward_options(profile)
	if options.is_empty():
		return {}
	if option_idx < 0 or option_idx >= options.size():
		return {}

	var state := _get_state(profile)
	var quest := state.get("current_quest", null) as Dictionary
	if quest == null:
		return {}

	var chosen: Dictionary = options[option_idx]

	# 1. TỰ ĐỘNG CỘNG ĐIỂM DÃ TẨU (luôn luôn nhận)
	var pts: int = quest.get("reward_pts", 0)
	state["da_tau_points"] = int(state.get("da_tau_points", 0)) + pts
	state["da_tau_points_session"] = int(state.get("da_tau_points_session", 0)) + pts

	# 2. TRAO PHẦN THƯỞNG ĐÃ CHỌN
	if profile != null:
		var otype: String = chosen.get("type", "")
		match otype:
			"exp":
				profile.add_exp(int(chosen.get("amount", 0)))
			"gold":
				profile.gold += int(chosen.get("amount", 0))
			"misc":
				var mid: String = chosen.get("misc_id", "")
				if not mid.is_empty():
					var qty: int = chosen.get("quantity", 1)
					var it := ItemGenerator.generate_misc(mid, 0, 0, qty)
					if it != null:
						profile.add_item(it)
			"equip":
				var eq := ItemGenerator.random_equipment(profile.level, 10)
				if eq != null:
					profile.add_item(eq)
			"item_thaiy":
				var mid := "6_1_71"
				var it := ItemGenerator.generate_misc(mid, 0, 0, chosen.get("quantity", 1))
				if it != null:
					profile.add_item(it)

	# 3. HOÀN THÀNH NHIỆM VỤ & TĂNG TIẾN ĐỘ
	state["done_today"] = int(state.get("done_today", 0)) + 1
	state["total_done"] = int(state.get("total_done", 0)) + 1
	state["current_quest"] = null
	state["pending_options"] = []
	state["scroll_count"] = 0
	save_records(state, profile)

	return {
		"chosen": chosen,
		"points": pts,
		"done_today": state["done_today"],
		"total_done": state["total_done"],
	}

## Hoàn thành nhiệm vụ — hỗ trợ tương thích và tự động nhận Option 0 (EXP) nếu gọi trực tiếp
static func complete_quest(profile: PlayerProfile) -> Dictionary:
	var options := get_or_create_reward_options(profile)
	if options.is_empty():
		return {}
	var res := claim_reward_option(profile, 0)
	res["slots"] = options
	res["quest_pts"] = res.get("points", 0)
	res["gold"] = options[1].get("amount", 0) if options.size() > 1 else 0
	res["exp"] = options[0].get("amount", 0) if options.size() > 0 else 0
	return res

## Tạo thưởng ngẫu nhiên dựa trên quest (8 ô)
static func _gen_reward(quest: Dictionary, profile: PlayerProfile) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var level := profile.level
	var ll := DaTauData.get_level_link(level)
	# Thưởng cơ bản: Lượng + Kinh nghiệm
	var gold_base := 500 + 200 * ll + rng.randi_range(0, 300 * ll)
	var exp_base := 1000 + 500 * ll + rng.randi_range(0, 1000 * ll)
	# 8 ô thưởng
	var slots: Array[Dictionary] = []
	slots.append({"name": "Lượng", "quantity": gold_base, "type": "gold"})
	slots.append({"name": "Kinh nghiệm", "quantity": exp_base, "type": "exp"})
	# Thưởng ngẫu nhiên dựa trên LevelLink
	var bonus_items := _get_bonus_items(ll, rng)
	for item in bonus_items:
		slots.append(item)
	# Điền đủ 8 ô
	while slots.size() < 8:
		slots.append({"name": "Trống", "quantity": 0, "type": "empty"})
	return {
		"slots": slots,
		"gold": gold_base,
		"exp": exp_base,
	}

## Danh sách vật phẩm thưởng ngẫu nhiên theo level link
static func _get_bonus_items(level_link: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	# Thuốc hồi phục
	var herb_qty := rng.randi_range(1, 3) * level_link
	items.append({"name": "Thái Y Linh Đan", "quantity": herb_qty, "type": "item"})
	# Mảnh Dã Tẩu (điểm tích lũy)
	items.append({"name": "Điểm Dã Tẩu", "quantity": rng.randi_range(1, level_link * 2), "type": "da_tau_pts"})
	# Vật phẩm theo cấp
	if level_link >= 3:
		items.append({"name": "Tinh Thạch", "quantity": rng.randi_range(1, level_link), "type": "item"})
	if level_link >= 6:
		items.append({"name": "Mảnh Sơn Hà Xã Tắc", "quantity": rng.randi_range(1, 3), "type": "item"})
	if level_link >= 11:
		items.append({"name": "Hộp Vật Phẩm Tốt", "quantity": 1, "type": "box"})
	if level_link >= 16:
		items.append({"name": "Hộp Vật Phẩm Quý", "quantity": 1, "type": "box"})
	return items

## Bỏ qua nhiệm vụ — trả về true nếu thành công
static func skip_quest(profile: PlayerProfile) -> bool:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null:
		return false
	var skipped: int = state.get("skip_today", 0)
	if skipped >= DaTauData.FREE_SKIP_PER_DAY:
		return false
	state["skip_today"] = skipped + 1
	state["current_quest"] = null
	state["scroll_count"] = 0
	save_records(state, profile)
	return true

## Thêm cuộn Địa đồ/Mật chí khi quái chết (Type 4)
## map_id: source map ID của map hiện tại nhân vật đang đứng
## scroll_type: 1=Địa đồ, 2=Mật chí
## Trả về true nếu cuộn được tính vào nhiệm vụ
static func try_drop_scroll(profile: PlayerProfile, source_map_id: int) -> bool:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null or not quest is Dictionary:
		return false
	var q := quest as Dictionary
	if q.get("type") != 4:
		return false
	# Kiểm tra đúng map
	if q.get("map_id", -1) != source_map_id:
		return false
	# Kiểm tra đã đủ chưa
	if q.get("done_num", 0) >= q.get("need_num", 1):
		return false
	# Roll xác suất drop
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var scroll_type: int = q.get("scroll_type", 1)
	var map_src_id: int = q.get("map_id", 0)
	var rate := DaTauData.get_diadochi_rate(map_src_id) if scroll_type == 1 else DaTauData.get_matchi_rate(map_src_id)
	if rng.randf() > rate:
		return false
	# Nhặt được cuộn
	q["done_num"] = int(q.get("done_num", 0)) + 1
	state["scroll_count"] = int(state.get("scroll_count", 0)) + 1
	save_records(state, profile)
	return true

## Lấy danh sách mốc thưởng có thể nhận
static func get_claimable_milestones(profile: PlayerProfile) -> Array[int]:
	var state := _get_state(profile)
	var total_pts: int = state.get("da_tau_points", 0)
	var claimed: Array = state.get("claimed_milestones", [])
	var claimable: Array[int] = []
	for i in DaTauData.AWARD_MILESTONES.size():
		if total_pts >= DaTauData.AWARD_MILESTONES[i] and not (i in claimed):
			claimable.append(i)
	return claimable

## Nhận thưởng mốc — trả về reward dict hoặc {}
static func claim_milestone(profile: PlayerProfile, milestone_idx: int) -> Dictionary:
	var state := _get_state(profile)
	var total_pts: int = state.get("da_tau_points", 0)
	if milestone_idx < 0 or milestone_idx >= DaTauData.AWARD_MILESTONES.size():
		return {}
	if total_pts < DaTauData.AWARD_MILESTONES[milestone_idx]:
		return {}
	var claimed: Array = state.get("claimed_milestones", [])
	if milestone_idx in claimed:
		return {}
	claimed.append(milestone_idx)
	state["claimed_milestones"] = claimed
	save_records(state, profile)
	return {
		"milestone_idx": milestone_idx,
		"desc": DaTauData.MILESTONE_REWARDS_DESC[milestone_idx],
		"threshold": DaTauData.AWARD_MILESTONES[milestone_idx],
	}

## Cập nhật done_num cho quest Type 1/2/3 từ bên ngoài (UI xác nhận)
static func mark_progress(profile: PlayerProfile, amount: int = 1) -> void:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null or not quest is Dictionary:
		return
	var q := quest as Dictionary
	var t: int = q.get("type", 0)
	if t in [1, 2, 3]:
		q["done_num"] = mini(int(q.get("done_num", 0)) + amount, int(q.get("need_num", 1)))
		save_records(state, profile)

## Tiêu điểm Dã Tẩu (Type 6) — trừ từ da_tau_points_session
static func consume_da_tau_points(profile: PlayerProfile, amount: int) -> bool:
	var state := _get_state(profile)
	var cur: int = state.get("da_tau_points_session", 0)
	if cur < amount:
		return false
	state["da_tau_points_session"] = cur - amount
	var q: Variant = state.get("current_quest", null)
	if q is Dictionary and q.get("type") == 6:
		(q as Dictionary)["done_num"] = amount
	save_records(state, profile)
	return true
