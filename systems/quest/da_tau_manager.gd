extends RefCounted
class_name DaTauManager
## Quản lý logic nghiệp vụ Dã Tẩu (TaskLink).

const DaTauData = preload("res://systems/quest/da_tau_data.gd")
## Tất cả method đều là static — không đăng ký làm Autoload.
## Dùng: DaTauManager.accept_quest(profile), DaTauManager.complete_quest(profile), ...
##
## Phụ thuộc: DaTauData (data layer), PlayerProfile (trạng thái)

const RECORD_PATH := "user://da_tau_records.json"
## Khi chạy trên GameServer: không đọc/ghi file user://da_tau_records_*.json cục bộ (tránh lẫn dữ liệu giữa các nhân vật).
static var server_mode: bool = false

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
	if server_mode:
		return {}
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
	if server_mode:
		return
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

	# Di chuyển bảng mốc cũ (theo điểm SHXT) sang mốc theo tổng số nhiệm vụ VLTK 1
	if int(profile.da_tau.get("milestone_version", 1)) < DaTauData.MILESTONE_VERSION:
		profile.da_tau["claimed_milestones"] = []
		profile.da_tau["milestone_version"] = DaTauData.MILESTONE_VERSION
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

## Type 2: Tìm vật phẩm (trang bị / kỳ trân dị bảo theo source tasklink_findgoods.txt)
static func _build_type2(level_link: int, rng: RandomNumberGenerator) -> Dictionary:
	var eligible := DaTauData.get_findgoods_for_level_link(level_link)
	if eligible.is_empty():
		return {}
	var entry := DaTauData.pick_weighted(eligible, level_link, rng)
	if entry.is_empty():
		return {}
	var iname: String = str(entry.get("name", "Vật phẩm"))
	return {
		"type": 2,
		"level_link": level_link,
		"kind": entry.get("kind", "equip"),
		"item_name": iname,
		"detail": entry.get("detail", -1),
		"particular": entry.get("particular", -1),
		"item_level": entry.get("level", -1),
		"series": entry.get("series", -1),
		"misc_id": entry.get("misc_id", ""),
		"base_index": entry.get("base_index", -1),
		"need_num": 1,
		"done_num": 0,
		"reward_pts": entry.get("task_value", 200000),
		"desc": "Tìm 1 món %s đem về cho Dã Tẩu" % iname,
	}

## Type 3: Xem vật phẩm (trang bị có thuộc tính ma pháp theo source tasklink_showgoods.txt)
static func _build_type3(level_link: int, rng: RandomNumberGenerator) -> Dictionary:
	var eligible := DaTauData.get_showgoods_for_level_link(level_link)
	if eligible.is_empty():
		return {}
	var entry := DaTauData.pick_weighted(eligible, level_link, rng)
	if entry.is_empty():
		return {}
	var min_v: int = int(entry.get("min_value", 0))
	var max_v: int = int(entry.get("max_value", 0))
	var m_name: String = str(entry.get("magic_name", "Thuộc tính"))
	var unit: String = str(entry.get("unit", ""))
	var range_str := ""
	if min_v == max_v:
		range_str = "%d%s" % [min_v, unit]
	else:
		range_str = "%d đến %d%s" % [min_v, max_v, unit]
	return {
		"type": 3,
		"level_link": level_link,
		"magic_code": entry.get("magic_code", 0),
		"attrib": entry.get("attrib", ""),
		"magic_name": m_name,
		"min_value": min_v,
		"max_value": max_v,
		"unit": unit,
		"need_num": 1,
		"done_num": 0,
		"reward_pts": entry.get("task_value", 200000),
		"desc": "Cho Dã Tẩu xem trang bị có thuộc tính %s (%s)" % [m_name, range_str],
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

## Type 5: Tích lũy điểm kinh nghiệm (từ đánh quái / hoạt động)
static func _build_type5(level_link: int, rng: RandomNumberGenerator, _profile: PlayerProfile) -> Dictionary:
	var eligible: Array[Dictionary] = []
	var weights: Array[int] = []
	var ll_idx := clampi(level_link - 1, 0, 19)
	for entry in DaTauData.UPGROUND_DATA:
		var r: int = entry["rates"][ll_idx]
		if r <= 0:
			continue
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
	var need_exp: int = int(chosen["need_value"])
	return {
		"type": 5,
		"level_link": level_link,
		"numeric_type": chosen.get("numeric_type", 2),
		"need_value": need_exp,
		"need_num": need_exp,
		"done_num": 0,
		"reward_pts": chosen["reward_pts"],
		"desc": "Tích lũy %s Điểm Kinh Nghiệm" % format_num(need_exp),
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
				"desc": "Nộp %d Mảnh Sơn Hà Xã Tắc (hiện có: %d)" % [e["num"], cur_pts],
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
		"desc": "Nộp %d Mảnh Sơn Hà Xã Tắc (hiện có: %d)" % [chosen["num"], cur_pts],
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

## Kiểm tra một món đồ cụ thể có thỏa mãn yêu cầu Type 2 không
static func is_item_matching_type2(it: ItemInstance, q: Dictionary) -> bool:
	if it == null or q.is_empty():
		return false
	var kind: String = str(q.get("kind", "equip"))
	var req_detail: int = int(q.get("detail", -1))
	var req_part: int = int(q.get("particular", -1))
	var req_lvl: int = int(q.get("item_level", -1))
	var req_series: int = int(q.get("series", -1))
	var req_misc: String = str(q.get("misc_id", ""))

	if kind == "misc":
		return it.is_misc() and it.misc_id == req_misc
	else:
		if it.is_misc() or it.is_locked():
			return false
		if req_detail >= 0 and it.get_detail() != req_detail:
			return false
		if req_part >= 0 and int(it.get_base().get("particular", 0)) != req_part:
			return false
		if req_lvl > 0 and it.get_level() != req_lvl:
			return false
		if req_series >= 0 and it.series != req_series:
			return false
		return true

## Kiểm tra một món đồ cụ thể có thuộc tính/chỉ số thỏa mãn yêu cầu Type 3 không
static func is_item_matching_type3(it: ItemInstance, q: Dictionary) -> Dictionary:
	if it == null or q.is_empty():
		return {"match": false, "reason": "Không có vật phẩm"}
	if it.is_misc():
		return {"match": false, "reason": "Vật phẩm này không phải là trang bị"}

	var target_attrib: String = str(q.get("attrib", "")).strip_edges()
	var min_v: int = int(q.get("min_value", 0))
	var max_v: int = int(q.get("max_value", 0))
	var m_name: String = str(q.get("magic_name", "Thuộc tính"))

	var all_magic: Array = []
	all_magic.append_array(it.magic)
	all_magic.append_array(it.expand_magic)

	for line in all_magic:
		if line is Dictionary and str(line.get("attrib", "")) == target_attrib:
			var val_arr: Variant = line.get("value", [])
			var cur_v := 0
			if val_arr is Array and val_arr.size() > 0:
				cur_v = int(val_arr[0])
			elif val_arr is int:
				cur_v = int(val_arr)

			var match_ok := false
			if min_v == max_v:
				match_ok = (cur_v >= min_v)
			else:
				match_ok = (cur_v >= min_v and cur_v <= max_v)

			if match_ok:
				return {
					"match": true,
					"cur_value": cur_v,
					"item_name": it.get_display_name()
				}

	return {
		"match": false,
		"reason": "Trang bị không có dòng thuộc tính [%s] hoặc chỉ số chưa đạt yêu cầu" % m_name
	}

## Tìm vị trí món đồ trong hành trang phù hợp yêu cầu Type 2
static func find_matching_item_for_type2(profile: PlayerProfile, q: Dictionary) -> int:
	if profile == null or q.is_empty():
		return -1
	for i in profile.inventory.size():
		var it: ItemInstance = profile.inventory[i]
		if is_item_matching_type2(it, q):
			return i
	return -1

## Nộp một món đồ cụ thể do người chơi tự tay chọn cho Type 2
static func submit_specific_item_for_type2(profile: PlayerProfile, item: ItemInstance) -> bool:
	if profile == null or item == null:
		return false
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null or not quest is Dictionary:
		return false
	var q := quest as Dictionary
	if int(q.get("type", 0)) != 2:
		return false
	if not is_item_matching_type2(item, q):
		return false

	var idx := profile.inventory.find(item)
	if idx >= 0:
		if item.is_misc() and item.count > 1:
			item.count -= 1
		else:
			profile.inventory.remove_at(idx)

	q["done_num"] = int(q.get("need_num", 1))
	save_records(state, profile)
	return true

## Nộp vật phẩm cho quest Type 2 (tự động tìm món hợp lệ đầu tiên — dùng cho fallback/test)
static func submit_item_for_type2(profile: PlayerProfile) -> bool:
	if profile == null:
		return false
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null or not quest is Dictionary:
		return false
	var q := quest as Dictionary
	if int(q.get("type", 0)) != 2:
		return false
	if int(q.get("done_num", 0)) >= int(q.get("need_num", 1)):
		return true

	var idx := find_matching_item_for_type2(profile, q)
	if idx < 0:
		return false

	var it: ItemInstance = profile.inventory[idx]
	if it.is_misc() and it.count > 1:
		it.count -= 1
	else:
		profile.inventory.remove_at(idx)

	q["done_num"] = 1
	save_records(state, profile)
	return true

## Cho Dã Tẩu xem một món đồ cụ thể do người chơi đặt vào rương cho Type 3
static func show_specific_item_for_type3(profile: PlayerProfile, item: ItemInstance) -> Dictionary:
	if profile == null or item == null:
		return {"ok": false, "reason": "Dữ liệu không hợp lệ"}
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null or not quest is Dictionary:
		return {"ok": false, "reason": "Không có nhiệm vụ"}
	var q := quest as Dictionary
	if int(q.get("type", 0)) != 3:
		return {"ok": false, "reason": "Không phải nhiệm vụ xem đồ"}

	var res := is_item_matching_type3(item, q)
	if not res.get("match", false):
		return {"ok": false, "reason": res.get("reason", "Chỉ số chưa đạt yêu cầu")}

	q["done_num"] = int(q.get("need_num", 1))
	save_records(state, profile)
	return {"ok": true, "cur_value": res.get("cur_value", 0), "item_name": res.get("item_name", "")}

## Kiểm tra có trang bị phù hợp yêu cầu xem đồ Type 3 không (quét hành trang + đang mặc, không tiêu hao)
static func find_matching_item_for_type3(profile: PlayerProfile, q: Dictionary) -> Dictionary:
	if profile == null or q.is_empty():
		return {"found": false}

	var candidate_items: Array[ItemInstance] = []
	for part in profile.equipment:
		var eq_item: ItemInstance = profile.equipment[part]
		if eq_item != null and not eq_item.is_misc():
			candidate_items.append(eq_item)
	for bag_item in profile.inventory:
		if bag_item != null and not bag_item.is_misc():
			candidate_items.append(bag_item)

	for it in candidate_items:
		var res := is_item_matching_type3(it, q)
		if res.get("match", false):
			return {
				"found": true,
				"item_name": it.get_display_name(),
				"value": res.get("cur_value", 0)
			}
	return {"found": false}

## Kiểm tra nhiệm vụ hoàn thành chưa
static func check_quest_complete(profile: PlayerProfile) -> bool:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null:
		return false
	if not quest is Dictionary:
		return false
	var q := quest as Dictionary
	if bool(q.get("instant_completed", false)):
		return true
	match int(q.get("type", 0)):
		1:
			return int(q.get("done_num", 0)) >= int(q.get("need_num", 1))
		2:
			# Type 2: Tìm & nộp vật phẩm — PHẢI nộp qua rương nộp đồ (done_num >= need_num), KHÔNG auto hoàn thành từ túi!
			return int(q.get("done_num", 0)) >= int(q.get("need_num", 1))
		3:
			# Type 3: Cho Dã Tẩu xem trang bị/chỉ số — PHẢI đặt vào rương cho xem và xác nhận (done_num >= need_num), KHÔNG auto hoàn thành!
			return int(q.get("done_num", 0)) >= int(q.get("need_num", 1))
		4:
			# Type 4: Thu thập Địa đồ chí / Mật chí
			return int(q.get("done_num", 0)) >= int(q.get("need_num", 1))
		5:
			# Type 5: Tích lũy đủ EXP yêu cầu (từ đánh quái / hoạt động)
			var need := int(q.get("need_num", q.get("need_value", 1)))
			return int(q.get("done_num", 0)) >= need
		6:
			# Type 6: Nộp Mảnh Sơn Hà Xã Tắc — phải bấm nút "Nộp Mảnh" trừ điểm thành công
			return int(q.get("done_num", 0)) >= int(q.get("need_num", 1))
	return false

## Ghi nhận điểm kinh nghiệm nhận được cho nhiệm vụ Dã Tẩu Type 5
static func on_exp_gained(profile: PlayerProfile, amount: int) -> void:
	if profile == null or amount <= 0:
		return
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest is Dictionary and int(quest.get("type", 0)) == 5:
		var q := quest as Dictionary
		var need := int(q.get("need_num", q.get("need_value", 1)))
		var cur := int(q.get("done_num", 0))
		if cur < need:
			var new_val := mini(cur + amount, need)
			q["done_num"] = new_val
			save_records(state, profile)
			var loop := Engine.get_main_loop()
			var sm: Node = (loop as SceneTree).root.get_node_or_null("SaveManager") if loop is SceneTree else null
			if sm != null:
				if new_val >= need:
					sm.save_profile(profile, true)
				elif sm.has_method("request_exp_save"):
					sm.request_exp_save(profile, 5.0)

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

	var n_diff := clampi(int(q.get("level_link", 1)), 1, 20)

	## Công thức chuẩn VLTK gốc (script/task/newtask/tasklink/tasklink_award.lua):
	##   myMainValue = myTaskValue2 * (1 + (myCountLinks + myTimes) * 0.1) + myLoops * 0.2
	##   Tiền = floor((myMainValue * 0.05 * 1.15) * rand(60..100)/100) + myTaskValue1
	##   EXP  = floor(((myTaskValue1 + myMainValue) * 0.36) * rand(80..120)/100)
	var total_done: int = int(state.get("total_done", 0))
	var my_times: int = total_done % 20
	var my_links: int = int(total_done / 20) % 20
	var my_loops: int = int(total_done / 400) % 20
	var task_val1: float = float(maxi(0, int(q.get("gold_cost", 0))))
	var task_val2: float = float(maxi(10000, int(q.get("reward_pts", 15000))))
	var chain_mult: float = 1.0 + float(my_links + my_times) * 0.1

	# 1. OPTION 0: KINH NGHIỆM (tasklink_award.lua -> Spr\datau\ExpBtn.spr)
	var main_val_exp: float = task_val1 + (task_val2 * chain_mult + float(my_loops) * 0.2)
	var exp_val: int = maxi(1000, int(floor((main_val_exp * 0.36) * (float(rng.randi_range(80, 120)) * 0.01))))
	var opt_exp: Dictionary = {
		"type": "exp",
		"name": "Kinh Nghiệm",
		"icon": "📜",
		"btn_icon": "ExpBtn",
		"amount": exp_val,
		"desc": "+%s Điểm EXP" % format_num(exp_val),
	}

	# 2. OPTION 1: NGÂN LƯỢNG (tasklink_award.lua -> Spr\datau\Money.spr)
	var main_val_gold: float = task_val2 * chain_mult + float(my_loops) * 0.2
	var gold_val: int = maxi(500, int(floor((main_val_gold * 0.05 * 1.15) * (float(rng.randi_range(60, 100)) * 0.01)) + task_val1))
	var opt_gold: Dictionary = {
		"type": "gold",
		"name": "Ngân Lượng",
		"icon": "💰",
		"btn_icon": "Money",
		"amount": gold_val,
		"desc": "+%s Lượng Bạc" % format_num(gold_val),
	}

	# 3. OPTION 2: VẬT PHẨM / KHOÁNG THẠCH / NGẪU NHIÊN (Spr\datau\Item.spr, Lucky.spr, Random.spr)
	var cur_quest_num: int = int(state.get("done_today", 0)) + 1
	var opt_item: Dictionary = {}

	match cur_quest_num:
		10:
			opt_item = {
				"type": "misc",
				"misc_id": "6_1_71",
				"name": "Tiên Thảo Lộ",
				"icon": "🌿",
				"btn_icon": "Item",
				"quantity": 1,
				"desc": "Mốc 10: Tiên Thảo Lộ ×1 (Nhân đôi EXP)",
			}
		20:
			opt_item = {
				"type": "misc",
				"misc_id": "4_238_1",
				"name": "Lam Thủy Tinh",
				"icon": "💎",
				"btn_icon": "Lucky",
				"quantity": 1,
				"desc": "Mốc 20: Lam Thủy Tinh ×1 (Đổi ngũ hành)",
			}
		30:
			opt_item = {
				"type": "misc",
				"misc_id": "4_239_1",
				"name": "Tử Thủy Tinh",
				"icon": "🔮",
				"btn_icon": "Lucky",
				"quantity": 1,
				"desc": "Mốc 30: Tử Thủy Tinh ×1 (Nâng cấp trang bị)",
			}
		40:
			opt_item = {
				"type": "equip",
				"name": "Trang Bị Dã Tẩu Quý",
				"icon": "🛡️",
				"btn_icon": "Item",
				"quantity": 1,
				"desc": "Mốc 40: Trang bị hiếm phù hợp cấp độ",
			}
		50:
			opt_item = {
				"type": "misc",
				"misc_id": "4_353_1",
				"name": "Tinh Hồng Bảo Thạch",
				"icon": "❤️",
				"btn_icon": "Lucky",
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
						"btn_icon": "Item",
						"quantity": 1,
						"desc": "Dược phẩm: Tiên Thảo Lộ ×1",
					}
				else:
					opt_item = {
						"type": "item_thaiy",
						"misc_id": "6_1_71",
						"name": "Tiên Thảo Lộ",
						"icon": "🌿",
						"btn_icon": "Item",
						"quantity": maxi(n_diff * 2, 2),
						"desc": "Dược phẩm: Tiên Thảo Lộ ×%d" % maxi(n_diff * 2, 2),
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
					"btn_icon": "Lucky",
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
						"btn_icon": "Item",
						"quantity": 1,
						"desc": "Trang bị ngẫu nhiên theo cấp độ",
					}
				else:
					opt_item = {
						"type": "misc",
						"misc_id": "6_1_1476",
						"name": "Bao Hoàng Kim Dã Tẩu",
						"icon": "🎁",
						"btn_icon": "Random",
						"quantity": 1,
						"desc": "Ngẫu nhiên: Bao Hoàng Kim Dã Tẩu ×1",
					}

	var options: Array[Dictionary] = [opt_exp, opt_gold, opt_item]
	state["pending_options"] = options
	save_records(state, profile)
	return options

## Sinh và thêm vật phẩm misc theo stack tối đa vào hành trang; rollback và trả "" nếu thiếu chỗ trống.
static func _grant_misc_to_profile(profile: PlayerProfile, mid: String, qty: int, added_items: Array[ItemInstance]) -> String:
	if mid.is_empty():
		return "invalid_item"
	var rec := ItemDatabase.get_misc(mid)
	if rec.is_empty():
		return "invalid_item"
	var max_stack := maxi(int(rec.get("stack", 0)), 1)
	var remain := maxi(1, qty)
	while remain > 0:
		var take := mini(remain, max_stack)
		var it := ItemGenerator.generate_misc(mid, 0, 0, take)
		if it == null:
			return "invalid_item"
		if not profile.add_item(it):
			return "inventory_full"
		added_items.append(it)
		remain -= take
	return ""

## Danh sách số túi (1-based) chứa các món vừa nhận, chỉ liệt kê nếu có món rơi vào Túi 2 trở đi.
static func format_bags_suffix(bags: Array) -> String:
	var extra: Array[String] = []
	for b in bags:
		var idx := int(b)
		if idx > 1:
			var lbl := "Túi %d" % idx
			if not (lbl in extra):
				extra.append(lbl)
	if extra.is_empty():
		return ""
	return " (đã xếp vào %s)" % ", ".join(extra)

## Kiểm tra danh sách pending_options có hợp lệ so với quest hiện tại (dùng trên GameServer để chống giả mạo).
static func validate_pending_options(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var state := _get_state(profile)
	var pending: Variant = state.get("pending_options", [])
	var quest: Variant = state.get("current_quest", null)
	if not (pending is Array) or (pending as Array).size() != 3 or not (quest is Dictionary):
		state["pending_options"] = []
		return
	var q := quest as Dictionary
	var total_done: int = int(state.get("total_done", 0))
	var my_times: int = total_done % 20
	var my_links: int = int(total_done / 20) % 20
	var my_loops: int = int(total_done / 400) % 20
	var task_val1: float = float(maxi(0, int(q.get("gold_cost", 0))))
	var task_val2: float = float(maxi(10000, int(q.get("reward_pts", 15000))))
	var chain_mult: float = 1.0 + float(my_links + my_times) * 0.1
	var max_exp: int = maxi(1000, int(floor(((task_val1 + (task_val2 * chain_mult + float(my_loops) * 0.2)) * 0.36) * 1.20)) + 10)
	var max_gold: int = maxi(500, int(floor(((task_val2 * chain_mult + float(my_loops) * 0.2) * 0.05 * 1.15) * 1.00) + task_val1) + 10)
	var allowed_misc := ["6_1_71", "4_238_1", "4_239_1", "4_240_1", "4_353_1", "6_1_1476"]
	for opt in (pending as Array):
		if not (opt is Dictionary):
			state["pending_options"] = []
			return
		var d := opt as Dictionary
		var t := str(d.get("type", ""))
		var ok := false
		match t:
			"exp":
				var amt := int(d.get("amount", 0))
				ok = amt >= 1000 and amt <= max_exp
			"gold":
				var amt := int(d.get("amount", 0))
				ok = amt >= 500 and amt <= max_gold
			"misc":
				ok = str(d.get("misc_id", "")) in allowed_misc and int(d.get("quantity", 1)) == 1
			"item_thaiy":
				var qty := int(d.get("quantity", 1))
				ok = qty >= 2 and qty <= 40
			"equip":
				ok = int(d.get("quantity", 1)) == 1
		if not ok:
			state["pending_options"] = []
			return

## Người chơi chọn 1 trong 3 phần thưởng:
## option_idx: 0=Kinh Nghiệm, 1=Ngân Lượng, 2=Vật Phẩm
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
	var added_items: Array[ItemInstance] = []
	var granted_names: Array[String] = []
	var granted_bags: Array[int] = []

	# Nếu là nhiệm vụ Type 2 và chưa hoàn thành nộp vật phẩm qua rương nộp đồ
	if profile != null and int(quest.get("type", 0)) == 2 and int(quest.get("done_num", 0)) < int(quest.get("need_num", 1)):
		return {"ok": false, "error": "not_submitted"}

	# 1. TRAO PHẦN THƯỞNG ĐÃ CHỌN
	if profile != null:
		var otype: String = chosen.get("type", "")
		var grant_err := ""
		match otype:
			"exp":
				profile.add_exp(int(chosen.get("amount", 0)))
			"gold":
				profile.gold += int(chosen.get("amount", 0))
			"misc":
				var mid: String = str(chosen.get("misc_id", ""))
				var qty: int = int(chosen.get("quantity", 1))
				grant_err = _grant_misc_to_profile(profile, mid, qty, added_items)
			"equip":
				var eq := ItemGenerator.random_equipment(profile.level, 10)
				if eq == null:
					grant_err = "invalid_item"
				elif not profile.add_item(eq):
					grant_err = "inventory_full"
				else:
					added_items.append(eq)
			"item_thaiy":
				var mid := "6_1_71"
				var qty: int = int(chosen.get("quantity", 1))
				grant_err = _grant_misc_to_profile(profile, mid, qty, added_items)
		if not grant_err.is_empty():
			for added in added_items:
				profile.inventory.erase(added)
			return {"ok": false, "error": grant_err}
		for it in added_items:
			granted_names.append(it.get_display_name())
			var bag_num := it.room_bag + 1
			if not (bag_num in granted_bags):
				granted_bags.append(bag_num)

	# 3. HOÀN THÀNH NHIỆM VỤ & TĂNG TIẾN ĐỘ
	state["done_today"] = int(state.get("done_today", 0)) + 1
	state["total_done"] = int(state.get("total_done", 0)) + 1
	state["current_quest"] = null
	state["pending_options"] = []
	state["scroll_count"] = 0
	save_records(state, profile)

	return {
		"ok": true,
		"chosen": chosen,
		"done_today": state["done_today"],
		"total_done": state["total_done"],
		"items": granted_names,
		"bags": granted_bags,
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

static func _count_bag_items(profile: PlayerProfile, misc_id: String) -> int:
	if profile == null or misc_id.is_empty():
		return 0
	var total := 0
	for it in profile.inventory:
		if it != null and it.misc_id == misc_id:
			total += maxi(it.count, 1)
	return total

static func _consume_one_bag_item(profile: PlayerProfile, misc_id: String) -> bool:
	if profile == null or misc_id.is_empty():
		return false
	for i in profile.inventory.size():
		var it: ItemInstance = profile.inventory[i]
		if it != null and it.misc_id == misc_id:
			if it.count > 1:
				it.count -= 1
			else:
				profile.inventory.remove_at(i)
			return true
	return false

## Đếm số vật phẩm cho phép hủy nhiệm vụ miễn phí (Lệnh Bài Hủy Dã Tẩu) trong hành trang
static func count_free_cancel_items(profile: PlayerProfile) -> int:
	return _count_bag_items(profile, DaTauData.FREE_CANCEL_ITEM_ID)

## Kiểm tra có vật phẩm cho phép hủy miễn phí trong hành trang hay không
static func has_free_cancel_item(profile: PlayerProfile) -> bool:
	return count_free_cancel_items(profile) > 0

static func _consume_free_cancel_item(profile: PlayerProfile) -> bool:
	return _consume_one_bag_item(profile, DaTauData.FREE_CANCEL_ITEM_ID)

## Đếm số [Lệnh Bài Hoàn Thành Dã Tẩu] trong hành trang
static func count_instant_complete_items(profile: PlayerProfile) -> int:
	return _count_bag_items(profile, DaTauData.INSTANT_COMPLETE_ITEM_ID)

## Kiểm tra có [Lệnh Bài Hoàn Thành Dã Tẩu] trong hành trang hay không
static func has_instant_complete_item(profile: PlayerProfile) -> bool:
	return count_instant_complete_items(profile) > 0

## Dùng 1 [Lệnh Bài Hoàn Thành Dã Tẩu] trong hành trang để hoàn thành ngay nhiệm vụ hiện tại
static func instant_complete_quest(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {"ok": false, "reason": "no_profile"}
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null or not quest is Dictionary:
		return {"ok": false, "reason": "no_quest"}
	if check_quest_complete(profile):
		return {"ok": false, "reason": "already_complete"}
	if not _consume_one_bag_item(profile, DaTauData.INSTANT_COMPLETE_ITEM_ID):
		return {"ok": false, "reason": "no_item"}
	var q := quest as Dictionary
	q["instant_completed"] = true
	q["done_num"] = int(q.get("need_num", 1))
	save_records(state, profile)
	return {
		"ok": true,
		"item_consumed": true,
		"remaining": count_instant_complete_items(profile),
	}

## Xem trước kết quả nếu hủy nhiệm vụ hiện tại (không làm thay đổi dữ liệu)
static func get_cancel_preview(profile: PlayerProfile) -> Dictionary:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	var free_left := maxi(0, DaTauData.FREE_SKIP_PER_DAY - int(state.get("skip_today", 0)))
	var item_count := count_free_cancel_items(profile)
	var done_today := int(state.get("done_today", 0))
	if quest == null:
		return {
			"has_quest": false,
			"mode": "none",
			"free_left": free_left,
			"item_count": item_count,
			"done_today": done_today,
			"will_reset": false,
		}
	var mode := "reset"
	if free_left > 0:
		mode = "daily_free"
	elif item_count > 0:
		mode = "item_free"
	return {
		"has_quest": true,
		"mode": mode,
		"free_left": free_left,
		"item_count": item_count,
		"done_today": done_today,
		"next_quest_num": 1 if mode == "reset" else (done_today + 2),
		"will_reset": mode == "reset",
	}

## Hủy nhiệm vụ hiện tại:
## - Nếu còn lượt bỏ miễn phí ngày -> dùng lượt miễn phí, tính tiếp số nhiệm vụ (+1 chuỗi).
## - Nếu hết lượt miễn phí ngày nhưng có item Lệnh Bài Hủy Dã Tẩu -> trừ 1 item, tính tiếp số nhiệm vụ (+1 chuỗi).
## - Nếu không có item miễn hủy và hết lượt miễn phí -> phạt reset done_today về 0 (làm lại từ Nhiệm Vụ #1).
static func cancel_quest(profile: PlayerProfile) -> Dictionary:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null:
		return {"ok": false, "reason": "no_quest"}

	var skipped: int = int(state.get("skip_today", 0))
	var mode := "reset"
	var reset_streak := false
	var item_consumed := false

	if skipped < DaTauData.FREE_SKIP_PER_DAY:
		state["skip_today"] = skipped + 1
		state["done_today"] = int(state.get("done_today", 0)) + 1
		state["total_done"] = int(state.get("total_done", 0)) + 1
		mode = "daily_free"
	elif _consume_free_cancel_item(profile):
		state["done_today"] = int(state.get("done_today", 0)) + 1
		state["total_done"] = int(state.get("total_done", 0)) + 1
		mode = "item_free"
		item_consumed = true
	else:
		state["done_today"] = 0
		mode = "reset"
		reset_streak = true

	state["current_quest"] = null
	state["pending_options"] = []
	state["scroll_count"] = 0
	save_records(state, profile)
	return {
		"ok": true,
		"mode": mode,
		"reset_streak": reset_streak,
		"item_consumed": item_consumed,
		"done_today": int(state.get("done_today", 0)),
		"total_done": int(state.get("total_done", 0)),
	}

## Bỏ qua nhiệm vụ miễn phí ngày — trả về true nếu thành công
static func skip_quest(profile: PlayerProfile) -> bool:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null:
		return false
	var skipped: int = state.get("skip_today", 0)
	if skipped >= DaTauData.FREE_SKIP_PER_DAY:
		return false
	state["skip_today"] = skipped + 1
	state["done_today"] = int(state.get("done_today", 0)) + 1
	state["total_done"] = int(state.get("total_done", 0)) + 1
	state["current_quest"] = null
	state["pending_options"] = []
	state["scroll_count"] = 0
	save_records(state, profile)
	return true

## Thêm cuộn Địa đồ/Mật chí khi quái chết (Type 4)
## map_id: source map ID của map hiện tại nhân vật đang đứng
## scroll_type: 1=Địa đồ, 2=Mật chí
## Trả về true nếu cuộn được tính vào nhiệm vụ
static func _add_scroll_to_bag(profile: PlayerProfile, mid: String) -> bool:
	if profile == null:
		return false
	for it in profile.inventory:
		if it != null and it.misc_id == mid:
			it.count = maxi(it.count, 1) + 1
			return true
	var item := ItemGenerator.generate_misc(mid, 0, 0, 1)
	if item == null:
		return false
	return profile.add_item(item)

static func try_drop_scroll(profile: PlayerProfile, source_map_id: int) -> bool:
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null or not quest is Dictionary:
		return false
	var q := quest as Dictionary
	var qtype := int(q.get("type", 0))
	if not qtype in [2, 3, 4]:
		return false
	# Kiểm tra đúng map
	var q_map := int(q.get("map_id", q.get("godot_map_id", -1)))
	if q_map != source_map_id:
		return false
	var scroll_type: int = int(q.get("scroll_type", q.get("map_type", 1)))
	var need_num: int = int(q.get("need_num", 1))
	var done_num: int = int(q.get("done_num", 0))
	if qtype == 4:
		if done_num >= need_num:
			return false
	elif qtype == 3:
		var bag_cnt := count_bag_scrolls(profile, scroll_type)
		if bag_cnt >= need_num:
			return false
	elif qtype == 2:
		var bag_cnt := count_bag_scrolls(profile, scroll_type)
		if (done_num + bag_cnt) >= need_num:
			return false
	# Roll xác suất drop
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var map_src_id: int = int(q.get("map_id", source_map_id))
	var rate := DaTauData.get_diadochi_rate(map_src_id) if scroll_type == 1 else DaTauData.get_matchi_rate(map_src_id)
	if rng.randf() > rate:
		return false

	if qtype == 4:
		# Nhặt được cuộn Type 4 (chuẩn VLTK: Dã Tẩu ghi nhận trực tiếp, không vào túi)
		q["done_num"] = done_num + 1
		state["scroll_count"] = int(state.get("scroll_count", 0)) + 1
		save_records(state, profile)
		return true
	else:
		# Type 2, 3: Thêm cuộn vào hành trang để mang về nộp / cho xem
		var mid := scroll_misc_id(scroll_type)
		if not _add_scroll_to_bag(profile, mid):
			return false
		if qtype == 3:
			q["done_num"] = mini(count_bag_scrolls(profile, scroll_type), need_num)
		state["scroll_count"] = int(state.get("scroll_count", 0)) + 1
		save_records(state, profile)
		return true

## Mã misc_id gốc tương ứng scroll_type (1=Thần bí đồ chí / Địa đồ chí, 2=Thần Bí Lộ Chí / Mật chí)
static func scroll_misc_id(scroll_type: int) -> String:
	return "6_1_206" if scroll_type == 1 else "6_1_213"

## Khi người chơi nhặt được vật phẩm 6_1_206 (Địa đồ chí) hoặc 6_1_213 (Mật chí) từ mặt đất:
## Theo source VLTK gốc (tasklink_goods.lua / tasklink_goods_secret.lua): PickUp trả về 0 — KHÔNG bao giờ vào hành trang!
## - Nếu đang làm nhiệm vụ Dã Tẩu Type 4 đúng map và đúng loại thì Dã Tẩu ghi nhận & tăng tiến độ (done_num += 1).
## - Nếu đang làm Type 2 hoặc Type 3: nhặt vào hành trang (stack count) để nộp hoặc cho xem.
## - Ngược lại (không có NV hợp lệ, sai map, sai loại hoặc đã đủ số lượng) -> quy đổi +1 Mảnh Sơn Hà Xã Tắc (da_tau_points_session += 1).
static func try_collect_picked_scroll(profile: PlayerProfile, misc_id: String, source_map_id: int) -> Dictionary:
	if profile == null or not misc_id in ["6_1_206", "6_1_213"]:
		return {"counted": false, "shxt_added": false}
	var item_name := "Địa đồ chí" if misc_id == "6_1_206" else "Mật chí"
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest is Dictionary:
		var q := quest as Dictionary
		var qtype := int(q.get("type", 0))
		var q_map := int(q.get("map_id", q.get("godot_map_id", -1)))
		var need_num := int(q.get("need_num", 1))
		var done_num := int(q.get("done_num", 0))
		var scroll_type := int(q.get("scroll_type", q.get("map_type", 1)))
		if q_map == source_map_id and scroll_misc_id(scroll_type) == misc_id:
			if qtype == 4 and done_num < need_num:
				done_num += 1
				q["done_num"] = done_num
				state["scroll_count"] = int(state.get("scroll_count", 0)) + 1
				save_records(state, profile)
				return {
					"counted": true,
					"shxt_added": false,
					"name": item_name,
					"done": done_num,
					"need": need_num,
				}
			elif qtype in [2, 3]:
				var bag_cnt := count_bag_scrolls(profile, scroll_type)
				var should_take := (qtype == 3 and bag_cnt < need_num) or (qtype == 2 and (done_num + bag_cnt) < need_num)
				if should_take:
					if not _add_scroll_to_bag(profile, misc_id):
						return {"counted": false, "shxt_added": false, "name": item_name, "bag_full": true}
					var new_bag_cnt := count_bag_scrolls(profile, scroll_type)
					if qtype == 3:
						q["done_num"] = mini(new_bag_cnt, need_num)
					state["scroll_count"] = int(state.get("scroll_count", 0)) + 1
					save_records(state, profile)
					return {
						"counted": true,
						"shxt_added": false,
						"name": item_name,
						"done": new_bag_cnt if qtype == 3 else (done_num + new_bag_cnt),
						"need": need_num,
					}
	var shxt_total: int = int(state.get("da_tau_points_session", 0)) + 1
	state["da_tau_points_session"] = shxt_total
	save_records(state, profile)
	return {
		"counted": false,
		"shxt_added": true,
		"name": item_name,
		"shxt_total": shxt_total,
	}

## Đếm số cuộn Địa đồ chí (6_1_206) / Mật chí (6_1_213) đang có trong hành trang
static func count_bag_scrolls(profile: PlayerProfile, scroll_type: int) -> int:
	if profile == null:
		return 0
	var mid := scroll_misc_id(scroll_type)
	var total := 0
	for it in profile.inventory:
		if it != null and it.misc_id == mid:
			total += maxi(it.count, 1)
	return total

## Nộp cuộn Địa đồ chí / Mật chí từ hành trang cho quest Type 2, 3 hoặc 4 (Type 3 chỉ xem nên không tiêu hao)
static func submit_bag_scrolls(profile: PlayerProfile, max_count: int = 1) -> int:
	if profile == null or max_count <= 0:
		return 0
	var state := _get_state(profile)
	var quest: Variant = state.get("current_quest", null)
	if quest == null or not quest is Dictionary:
		return 0
	var q := quest as Dictionary
	var qtype := int(q.get("type", 0))
	if not qtype in [2, 3, 4]:
		return 0
	var scroll_type := int(q.get("scroll_type", q.get("map_type", 1)))
	var mid := scroll_misc_id(scroll_type)
	var done_num := int(q.get("done_num", 0))
	var need_num := int(q.get("need_num", 1))
	if qtype == 3:
		## Type 3: "Cho Dã Tẩu xem" — kiểm tra đủ trong hành trang không trừ vật phẩm
		var in_bag := count_bag_scrolls(profile, scroll_type)
		var new_done := mini(in_bag, need_num)
		q["done_num"] = new_done
		save_records(state, profile)
		return new_done
	else:
		var remain := maxi(0, need_num - done_num)
		if remain <= 0:
			return 0
		var want := mini(remain, max_count)
		var submitted := 0
		for i in range(profile.inventory.size() - 1, -1, -1):
			if submitted >= want:
				break
			var it: ItemInstance = profile.inventory[i]
			if it != null and it.misc_id == mid:
				var take := mini(want - submitted, maxi(it.count, 1))
				if it.count > take:
					it.count -= take
				else:
					profile.inventory.remove_at(i)
				submitted += take
		if submitted > 0:
			q["done_num"] = done_num + submitted
			if qtype == 4:
				state["scroll_count"] = int(state.get("scroll_count", 0)) + submitted
			save_records(state, profile)
		return submitted

## Lấy danh sách mốc thưởng có thể nhận (theo tổng số nhiệm vụ hoàn thành total_done)
static func get_claimable_milestones(profile: PlayerProfile) -> Array[int]:
	var state := _get_state(profile)
	var total_done: int = int(state.get("total_done", 0))
	var claimed: Array = state.get("claimed_milestones", [])
	var claimable: Array[int] = []
	for i in DaTauData.AWARD_MILESTONES.size():
		if total_done >= DaTauData.AWARD_MILESTONES[i] and not (i in claimed):
			claimable.append(i)
	return claimable

## Chọn ngẫu nhiên 1 món Hoàng Kim Môn Phái (ưu tiên đúng môn phái của nhân vật)
static func _pick_hkmp_gold_index(profile: PlayerProfile, rng: RandomNumberGenerator) -> int:
	var menpai_idx := -1
	if profile != null and not profile.sect_id.is_empty():
		menpai_idx = Equipment.MENPAI_ORDER.find(profile.sect_id)

	var total_gold := ItemDatabase.get_gold_count()
	var classic_pool: Array[int] = []
	var sect_pool: Array[int] = []
	var any_pool: Array[int] = []

	for i in total_gold:
		var rec := ItemDatabase.get_gold(i)
		var g_menpai := int(rec.get("menpai", -1))
		if g_menpai < 0:
			continue
		var g_name := str(rec.get("name", ""))
		if g_name.begins_with("[") or g_name.contains("(kỳ hạn)"):
			continue
		if i < 140:
			any_pool.append(i)
			if g_menpai == menpai_idx:
				classic_pool.append(i)
		if g_menpai == menpai_idx:
			sect_pool.append(i)

	if not classic_pool.is_empty():
		return classic_pool[rng.randi_range(0, classic_pool.size() - 1)]
	if not sect_pool.is_empty():
		return sect_pool[rng.randi_range(0, sect_pool.size() - 1)]
	if not any_pool.is_empty():
		return any_pool[rng.randi_range(0, any_pool.size() - 1)]
	return 0

## Tạo danh sách ItemInstance cho cấu hình thưởng của 1 mốc
static func _build_milestone_items(cfg: Dictionary, profile: PlayerProfile, rng: RandomNumberGenerator) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for m in cfg.get("misc", []):
		var mid: String = str(m.get("id", ""))
		var qty: int = maxi(1, int(m.get("qty", 1)))
		var rec := ItemDatabase.get_misc(mid)
		var max_stack := maxi(int(rec.get("stack", 0)), 1)
		var remain := qty
		while remain > 0:
			var take := mini(remain, max_stack)
			var it := ItemGenerator.generate_misc(mid, 0, 0, take)
			if it == null:
				break
			out.append(it)
			remain -= take

	var gold_pool: Array = cfg.get("gold_pool", [])
	if not gold_pool.is_empty():
		var g_idx := int(gold_pool[rng.randi_range(0, gold_pool.size() - 1)])
		var g_it := ItemGenerator.generate_gold_random(g_idx, rng.randi())
		if g_it != null:
			out.append(g_it)

	if cfg.get("hkmp", false):
		var hk_idx := _pick_hkmp_gold_index(profile, rng)
		var hk_it := ItemGenerator.generate_gold_random(hk_idx, rng.randi())
		if hk_it != null:
			out.append(hk_it)

	if cfg.has("horse"):
		var h: Dictionary = cfg["horse"]
		var horse_it := ItemGenerator.generate(ItemDatabase.Detail.HORSE, int(h.get("particular", 8)), int(h.get("level", 10)), 0, [], 0, rng.randi())
		if horse_it != null:
			out.append(horse_it)
	return out

## Nhận thưởng mốc theo total_done — trao vật phẩm/lượng/danh vọng thật vào profile
static func claim_milestone(profile: PlayerProfile, milestone_idx: int) -> Dictionary:
	if profile == null:
		return {}
	var state := _get_state(profile)
	var total_done: int = int(state.get("total_done", 0))
	if milestone_idx < 0 or milestone_idx >= DaTauData.AWARD_MILESTONES.size():
		return {}
	if total_done < DaTauData.AWARD_MILESTONES[milestone_idx]:
		return {}
	var claimed: Array = state.get("claimed_milestones", [])
	if milestone_idx in claimed:
		return {}

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cfg: Dictionary = DaTauData.MILESTONE_REWARDS[milestone_idx] if milestone_idx < DaTauData.MILESTONE_REWARDS.size() else {}
	var items_to_add := _build_milestone_items(cfg, profile, rng)
	var added_items: Array[ItemInstance] = []
	var granted_names: Array[String] = []
	var granted_bags: Array[int] = []

	for it in items_to_add:
		if not profile.add_item(it):
			for added in added_items:
				profile.inventory.erase(added)
			return {"ok": false, "error": "inventory_full"}
		added_items.append(it)
		var label := it.get_display_name()
		if it.count > 1 and not label.ends_with("x%d" % it.count):
			label = "%s ×%d" % [label, it.count]
		granted_names.append(label)
		var bag_num := it.room_bag + 1
		if not (bag_num in granted_bags):
			granted_bags.append(bag_num)

	var gold_gain: int = int(cfg.get("gold", 0))
	var prestige_gain: int = int(cfg.get("prestige", 0))
	if gold_gain > 0:
		profile.gold += gold_gain
	if prestige_gain > 0:
		profile.prestige += prestige_gain

	claimed.append(milestone_idx)
	state["claimed_milestones"] = claimed
	save_records(state, profile)
	return {
		"ok": true,
		"milestone_idx": milestone_idx,
		"desc": DaTauData.MILESTONE_REWARDS_DESC[milestone_idx],
		"threshold": DaTauData.AWARD_MILESTONES[milestone_idx],
		"items": granted_names,
		"bags": granted_bags,
		"gold": gold_gain,
		"prestige": prestige_gain,
	}

static func format_reward_option_notice(res: Dictionary) -> String:
	var chosen: Dictionary = res.get("chosen", {})
	var items: Array = res.get("items", [])
	var detail := ", ".join(items) if not items.is_empty() else str(chosen.get("desc", chosen.get("name", "")))
	return "🎉 Hoàn thành nhiệm vụ #%d! Đã nhận: %s%s!" % [
		int(res.get("done_today", 1)),
		detail,
		format_bags_suffix(res.get("bags", [])),
	]

static func format_milestone_notice(res: Dictionary) -> String:
	var parts: Array[String] = []
	for item_name in res.get("items", []):
		parts.append(str(item_name))
	var gold_gain: int = int(res.get("gold", 0))
	var prestige_gain: int = int(res.get("prestige", 0))
	if gold_gain > 0:
		parts.append("Lượng ×%s" % format_num(gold_gain))
	if prestige_gain > 0:
		parts.append("Danh Vọng ×%d" % prestige_gain)
	return "🎉 Đã nhận mốc %s nhiệm vụ: %s%s!" % [
		format_num(int(res.get("threshold", 0))),
		" + ".join(parts),
		format_bags_suffix(res.get("bags", [])),
	]

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
