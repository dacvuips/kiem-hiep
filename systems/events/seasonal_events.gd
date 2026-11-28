class_name SeasonalEvents
extends RefCounted
## SỰ KIỆN NĂM (Tết, Valentine, 8/3, 30/4, Sinh nhật VLTK, Trung Thu, Quốc khánh, 20/10, 20/11, Giáng Sinh) — dữ liệu xuất từ source
## VLTK bản 15 phái bằng tools/export_seasonal_events.py -> data/events/seasonal_events.json (xem docs/vltk_seasonal_events_reference.md).
## Logic thuần trên PlayerProfile, dùng chung máy chơi (offline) và game server (online, gói C_EVENT):
##   - lịch: ngày lễ (dương / âm lịch) của năm hiện tại + độ lệch ngày gốc -> khoảng diễn ra; ngày tính theo giờ Việt Nam (+7)
##   - ép (CreateCompose gốc): đặt nguyên liệu -> tự tính số lần ép tối đa, phần dư giữ lại hành trang; nhiều công thức cùng dùng
##     chung nguyên liệu thì chế độ "tự động" thử mọi thứ tự công thức để ép được NHIỀU thành phẩm nhất
##   - mở / dùng vật phẩm (ItemScript gốc): thưởng theo bảng tbAwardTemplet (nhận hết / quay 1 món theo nRate %), thưởng MỐC theo
##     số lần đã dùng, giới hạn số lần mỗi đợt; bộ đếm nằm ở PlayerProfile.event_counters, tách theo năm diễn ra.
##   - HỘP SỰ KIỆN: trong đợt, mọi quái rơi "Hộp <sự kiện>" (box_drop_rate / lần hạ quái — roll_monster_drops, gọi từ VltkMonster
##     offline và GameServer online); mở hộp ra 1 nguyên liệu ngẫu nhiên của sự kiện (món dùng được "ev_box_<id>").
##   - LỊCH GM: GM đặt lại ngày bắt đầu / kết thúc của 1 sự kiện (set_override) để thử theo giờ thật; "Mặc định" xoá về lịch gốc.
##     Offline lưu user://seasonal_event_override.json; online server giữ + gửi mọi người (S_EVENT_TIMES), máy chơi chỉ nhận.

const DATA_PATH := "res://data/events/seasonal_events.json"
const DAY := 86400
const TZ_SEC := 7 * 3600
## Trần số lần ép 1 lượt (giống tham số 50 lần/lượt của CreateCompose gốc nhưng rộng hơn) — chặn yêu cầu quá lớn.
const MAX_BATCH := 1000
## Số ô ước tính cho 1 món trang bị (mặt nạ, ngựa, hoàng kim) khi kiểm tra chỗ trống.
const EQUIP_CELLS := 4
const AUTO := ""

static var _data: Dictionary = {}
static var _events: Array = []
static var _by_id: Dictionary = {}
static var _usable: Dictionary = {}      ## misc_id -> [event_id, spec]

const OVERRIDE_PATH := "user://seasonal_event_override.json"
## Khoảng dài nhất GM được đặt cho 1 đợt.
const OVERRIDE_MAX_DAYS := 366
static var _override: Dictionary = {}    ## event_id -> {"start": unix, "end": unix} — lịch GM đặt (thay đợt gốc)
static var _override_loaded := false
static var _override_remote := false     ## true = bản của server (online) — không đọc / ghi file trên máy
static var _active_ids: Array = []       ## đệm sự kiện đang diễn ra (quái chết liên tục — không tính lịch âm mỗi lần)
static var _active_until := -1

static func _ensure() -> void:
	if not _events.is_empty():
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_warning("SeasonalEvents: thiếu " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return
	_data = parsed
	_events = _data.get("events", [])
	for ev in _events:
		_by_id[str(ev["id"])] = ev
		for mid in (ev.get("usables", {}) as Dictionary):
			if not _usable.has(mid):
				_usable[mid] = [str(ev["id"]), ev["usables"][mid]]

static func events() -> Array:
	_ensure()
	return _events

static func get_event(event_id: String) -> Dictionary:
	_ensure()
	return _by_id.get(event_id, {})

static func get_recipe(ev: Dictionary, recipe_id: String) -> Dictionary:
	for r in ev.get("recipes", []):
		if str(r["id"]) == recipe_id:
			return r
	return {}

# ---------------------------------------------------------------- lịch

static func now_unix() -> int:
	return int(Time.get_unix_time_from_system())

## 0:00 giờ Việt Nam của ngày dương (y, m, d) -> unix.
static func vn_midnight(y: int, m: int, d: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 0, "minute": 0, "second": 0})) - TZ_SEC

## unix -> {year, month, day, hour, minute} theo giờ Việt Nam.
static func vn_date(unix: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(unix + TZ_SEC)

## Ngày lễ của sự kiện trong năm `year` (dương lịch; lễ âm lịch đổi qua LunarCalendar) -> unix 0:00 giờ VN.
static func anchor_unix(ev: Dictionary, year: int) -> int:
	var a: Array = ev.get("anchor", [1, 1])
	if str(ev.get("calendar", "solar")) == "lunar":
		var s := LunarCalendar.lunar_to_solar(int(a[1]), int(a[0]), year)
		return vn_midnight(int(s["year"]), int(s["month"]), int(s["day"]))
	return vn_midnight(year, int(a[0]), int(a[1]))

## Đợt diễn ra của năm `year`: {start, end (giây cuối cùng), anchor, year}.
static func period(ev: Dictionary, year: int) -> Dictionary:
	var anchor := anchor_unix(ev, year)
	return {
		"year": year,
		"anchor": anchor,
		"start": anchor + int(ev.get("start_offset", 0)) * DAY,
		"end": anchor + (int(ev.get("end_offset", 0)) + 1) * DAY - 1,
	}

## Đợt đang diễn ra, không thì đợt sắp tới gần nhất (status "ongoing" / "upcoming"). Lịch GM (nếu có, chưa hết) đứng trước.
static func current_period(ev: Dictionary, now: int = -1) -> Dictionary:
	if now < 0:
		now = now_unix()
	var ov := get_override(str(ev.get("id", "")))
	if not ov.is_empty() and now <= int(ov["end"]):
		var gp := _override_period(ov)
		gp["status"] = "ongoing" if now >= int(ov["start"]) else "upcoming"
		return gp
	var y := int(vn_date(now)["year"])
	var best := {}
	for yy in [y - 1, y, y + 1, y + 2]:
		var p := period(ev, yy)
		if now >= p["start"] and now <= p["end"]:
			p["status"] = "ongoing"
			return p
		if p["start"] > now and (best.is_empty() or p["start"] < best["start"]):
			best = p
	best["status"] = "upcoming"
	return best

## Đợt gần nhất đã bắt đầu (đang diễn ra hoặc vừa kết thúc) — để tính bộ đếm / hạn dùng khi mở đồ sau sự kiện.
static func last_period(ev: Dictionary, now: int = -1) -> Dictionary:
	if now < 0:
		now = now_unix()
	var y := int(vn_date(now)["year"])
	var best := {}
	for yy in [y - 1, y, y + 1]:
		var p := period(ev, yy)
		if p["start"] <= now and (best.is_empty() or p["start"] > best["start"]):
			best = p
	var ov := get_override(str(ev.get("id", "")))
	if not ov.is_empty() and int(ov["start"]) <= now and (best.is_empty() or int(ov["start"]) >= int(best["start"])):
		return _override_period(ov)
	return best if not best.is_empty() else period(ev, y)

static func is_active(ev: Dictionary, now: int = -1) -> bool:
	return str(current_period(ev, now).get("status", "")) == "ongoing"

## Mã các sự kiện đang diễn ra (giờ thật đệm 60 giây — gọi mỗi lần hạ quái).
static func active_ids(now: int = -1) -> Array:
	var real := now < 0
	if real:
		now = now_unix()
		if now < _active_until:
			return _active_ids
	var out: Array = []
	for ev in events():
		if is_active(ev, now):
			out.append(str(ev["id"]))
	if real:
		_active_ids = out
		_active_until = now + 60
	return out

# ---------------------------------------------------------------- lịch GM

static func _override_period(ov: Dictionary) -> Dictionary:
	var st := int(ov["start"])
	return {"year": int(vn_date(st)["year"]), "anchor": st, "start": st, "end": int(ov["end"]), "gm": true}

static func _ensure_override() -> void:
	if _override_loaded:
		return
	_override_loaded = true
	_override = {}
	if _override_remote or not FileAccess.file_exists(OVERRIDE_PATH):
		return
	var f := FileAccess.open(OVERRIDE_PATH, FileAccess.READ)
	if f:
		_override = _clean_overrides(JSON.parse_string(f.get_as_text()))

static func _clean_overrides(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			var v: Variant = raw[k]
			if v is Dictionary and v.has("start") and v.has("end") and not get_event(str(k)).is_empty():
				var st := int(v["start"])
				var en := int(v["end"])
				if en > st and en - st <= OVERRIDE_MAX_DAYS * DAY:
					out[str(k)] = {"start": st, "end": en}
	return out

static func overrides() -> Dictionary:
	_ensure_override()
	return _override

static func get_override(event_id: String) -> Dictionary:
	_ensure_override()
	return _override.get(event_id, {})

## GM đặt lịch cho 1 sự kiện. Trả "" nếu được, khác = lý do từ chối.
static func set_override(event_id: String, start: int, end: int, persist := true) -> String:
	if get_event(event_id).is_empty():
		return "Sự kiện không tồn tại."
	if end <= start:
		return "Ngày kết thúc phải sau ngày bắt đầu."
	if end - start > OVERRIDE_MAX_DAYS * DAY:
		return "Một đợt tối đa %d ngày." % OVERRIDE_MAX_DAYS
	_ensure_override()
	_override[event_id] = {"start": start, "end": end}
	_active_until = -1
	if persist:
		save_overrides()
	return ""

static func clear_override(event_id: String, persist := true) -> void:
	_ensure_override()
	_override.erase(event_id)
	_active_until = -1
	if persist:
		save_overrides()

static func save_overrides() -> void:
	if _override_remote or OS.get_environment("KIEMHIEP_NO_SAVE") != "":
		return
	var f := FileAccess.open(OVERRIDE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_override))

## Online: lịch GM do server gửi (S_EVENT_TIMES) — thay hẳn bản trên máy, không ghi file.
static func apply_remote_overrides(raw: Variant) -> void:
	_override_remote = true
	_override_loaded = true
	_override = _clean_overrides(raw)
	_active_until = -1

## Rời online: dùng lại lịch GM của máy (offline).
static func use_local_overrides() -> void:
	_override_remote = false
	_override_loaded = false
	_active_until = -1

# ---------------------------------------------------------------- hộp sự kiện rơi từ quái

static func box_drop_rate() -> float:
	_ensure()
	return float(_data.get("box_drop_rate", 0.0))

## Bản ghi vật phẩm các hộp (ItemDatabase nạp chung bảng vật phẩm khác).
static func box_records() -> Array:
	_ensure()
	return (_data.get("boxes", {}) as Dictionary).values()

## Nguyên liệu sự kiện + hộp: chồng tối đa event_stack() (ItemDatabase nâng "stack" của các món này khi nạp bảng vật phẩm).
static func stack_items() -> Array:
	_ensure()
	return _data.get("stack_items", [])

static func event_stack() -> int:
	_ensure()
	return int(_data.get("event_stack", 100))

static func drop_box_of(ev: Dictionary) -> String:
	return str(ev.get("drop_box", ""))

## Hạ 1 quái: tung 1 lần (box_drop_rate) — trúng thì rơi ĐÚNG 1 hộp; nhiều sự kiện cùng diễn ra (VD GM kích hoạt thêm) thì chọn
## ngẫu nhiên hộp của 1 sự kiện. -> [{type: "item", item: ItemInstance}] (dạng DropTable), rỗng nếu không rơi.
static func roll_monster_drops(now: int = -1, rng: RandomNumberGenerator = null) -> Array:
	var rate := box_drop_rate()
	if rate <= 0.0:
		return []
	var boxes: Array = []
	for eid in active_ids(now):
		var b := drop_box_of(get_event(eid))
		if b != "":
			boxes.append(b)
	if boxes.is_empty():
		return []
	var roll := rng.randf() if rng != null else randf()
	if roll >= rate:
		return []
	var pick: String = boxes[(rng.randi() if rng != null else randi()) % boxes.size()]
	var it := ItemGenerator.generate_misc(pick)
	if it == null:
		return []
	it.count = 1
	return [{"type": "item", "item": it}]

## Sự kiện năm theo thứ tự: đang diễn ra trước, rồi theo ngày bắt đầu sắp tới.
static func sorted_events(now: int = -1) -> Array:
	var out: Array = []
	for ev in events():
		out.append({"event": ev, "period": current_period(ev, now)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ao: bool = a["period"]["status"] == "ongoing"
		var bo: bool = b["period"]["status"] == "ongoing"
		if ao != bo:
			return ao
		return int(a["period"]["start"]) < int(b["period"]["start"]))
	return out

static func format_date(unix: int) -> String:
	var d := vn_date(unix)
	return "%02d/%02d/%04d" % [d["day"], d["month"], d["year"]]

# ---------------------------------------------------------------- tra cứu vật phẩm

static func item_name(mid: String) -> String:
	var rec := ItemDatabase.get_misc(mid)
	return str(rec.get("name", mid))

static func item_icon(mid: String, small := true) -> Texture2D:
	var rec := ItemDatabase.get_misc(mid)
	return ItemDatabase.get_icon(rec, small) if not rec.is_empty() else null

static func is_usable(mid: String) -> bool:
	_ensure()
	return _usable.has(mid)

static func usable_event(mid: String) -> String:
	_ensure()
	return str(_usable[mid][0]) if _usable.has(mid) else ""

## Mọi mã nguyên liệu của sự kiện (để chặn đặt đồ lạ vào ô chế tạo).
static func material_ids(ev: Dictionary) -> Dictionary:
	var out := {}
	for r in ev.get("recipes", []):
		for m in r.get("materials", []):
			for mid in mat_items(m):
				out[mid] = true
	return out

## Mã vật phẩm của 1 dòng nguyên liệu: {"item": mid} -> [mid]; {"any": [mid, ...]} (1 món bất kỳ trong nhóm, VD Đoan Ngọ
## nâng cấp bánh tốn thêm 1 nguyên liệu bất kỳ) -> cả nhóm, theo thứ tự ưu tiên trừ.
static func mat_items(m: Dictionary) -> Array:
	if m.has("any"):
		var out: Array = []
		for x in m["any"]:
			out.append(str(x))
		return out
	return [str(m["item"])]

## Thành phẩm trực tiếp (món) của 1 cây thưởng — vật phẩm có thể ra, theo thứ tự.
static func result_items(node: Variant, out: Array = []) -> Array:
	if node is Dictionary:
		if node.has("item"):
			if not out.has(str(node["item"])):
				out.append(str(node["item"]))
		for k in ["all", "pick"]:
			if node.has(k):
				for c in node[k]:
					result_items(c, out)
	return out

# ---------------------------------------------------------------- bộ đếm theo năm

static func _counter_key(ev_id: String, cycle: int, key: String) -> String:
	return "%s:%d:%s" % [ev_id, cycle, key]

static func get_counter(profile: PlayerProfile, ev_id: String, cycle: int, key: String) -> int:
	return int(profile.event_counters.get(_counter_key(ev_id, cycle, key), 0))

static func _bump_counter(profile: PlayerProfile, ev_id: String, cycle: int, key: String) -> int:
	var k := _counter_key(ev_id, cycle, key)
	var v := int(profile.event_counters.get(k, 0)) + 1
	profile.event_counters[k] = v
	return v

## Bỏ bộ đếm của các đợt quá 2 năm (giữ hồ sơ gọn).
static func prune_counters(profile: PlayerProfile, now: int = -1) -> void:
	var y := int(vn_date(now if now >= 0 else now_unix())["year"])
	for k in profile.event_counters.keys():
		var parts := str(k).split(":")
		if parts.size() >= 2 and parts[1].is_valid_int() and int(parts[1]) < y - 2:
			profile.event_counters.erase(k)

# ---------------------------------------------------------------- lập kế hoạch ép

## Món đặt vào ô chế tạo: uid -> số lượng. Trả {ok, message, avail: misc_id -> tổng, items: misc_id -> [[ItemInstance, n], ...]}.
static func collect_placed(profile: PlayerProfile, placed: Dictionary) -> Dictionary:
	var by_uid := {}
	for it in profile.inventory:
		by_uid[it.uid] = it
	var avail := {}
	var items := {}
	for uid in placed:
		var n := int(placed[uid])
		if n <= 0:
			continue
		var it: ItemInstance = by_uid.get(str(uid))
		if it == null or not it.is_misc():
			return {"ok": false, "message": "Vật phẩm đặt vào không còn trong hành trang."}
		if n > it.count:
			return {"ok": false, "message": "%s chỉ còn %d." % [it.get_display_name(), it.count]}
		if SecurityLock.is_item_locked(it) or it.trade_price > 0:
			return {"ok": false, "message": "%s đang khoá / đặt giá bán, không dùng được." % it.get_display_name()}
		avail[it.misc_id] = int(avail.get(it.misc_id, 0)) + n
		if not items.has(it.misc_id):
			items[it.misc_id] = []
		items[it.misc_id].append([it, n])
	return {"ok": true, "message": "", "avail": avail, "items": items}

## Số lần ép tối đa của 1 công thức với nguyên liệu + tiền hiện có (`cap` = trần số lần, -1 = không trần).
static func max_times(recipe: Dictionary, avail: Dictionary, gold: int, cap: int = -1) -> int:
	var t := MAX_BATCH if cap < 0 else mini(cap, MAX_BATCH)
	var mats: Array = recipe.get("materials", [])
	var has_any := false
	for m in mats:
		var have := 0
		for mid in mat_items(m):
			have += maxi(int(avail.get(mid, 0)), 0)
		has_any = has_any or m.has("any")
		t = mini(t, have / maxi(int(m["count"]), 1))
	var money := int(recipe.get("money", 0))
	if money > 0:
		t = mini(t, gold / money)
	if mats.is_empty() and cap < 0:
		return 0   ## công thức chỉ cần tiền (mua) phải nói rõ số lần
	## nhóm "bất kỳ" có thể trùng món cụ thể của cùng công thức -> lùi tới khi trừ thử vừa đủ
	while has_any and t > 0 and not _fits(recipe, t, avail):
		t -= 1
	return maxi(t, 0)

static func _fits(recipe: Dictionary, times: int, avail: Dictionary) -> bool:
	var a := avail.duplicate()
	_apply_use(recipe, times, a)
	for k in a:
		if int(a[k]) < 0:
			return false
	return true

## Trừ nguyên liệu `times` lần vào `avail` (món cụ thể trước, nhóm "bất kỳ" sau — lấy lần lượt theo thứ tự nhóm). Trả tiền tốn.
static func _apply_use(recipe: Dictionary, times: int, avail: Dictionary) -> int:
	var gold_used := int(recipe.get("money", 0)) * times
	var anys: Array = []
	for m in recipe.get("materials", []):
		if m.has("any"):
			anys.append(m)
			continue
		var mid := str(m["item"])
		avail[mid] = int(avail.get(mid, 0)) - int(m["count"]) * times
	for m in anys:
		var need := int(m["count"]) * times
		var ids := mat_items(m)
		for mid in ids:
			if need <= 0:
				break
			var take := mini(maxi(int(avail.get(mid, 0)), 0), need)
			if take > 0:
				avail[mid] = int(avail[mid]) - take
				need -= take
		if need > 0:   ## thiếu: ghi âm vào món đầu để _fits báo không đủ
			avail[ids[0]] = int(avail.get(ids[0], 0)) - need
	return gold_used

## Số lần còn được ép công thức có "limit" (lần / đợt) — -1 = không giới hạn.
static func limit_left(profile: PlayerProfile, ev: Dictionary, recipe: Dictionary, now: int = -1) -> int:
	var lim := int(recipe.get("limit", 0))
	if lim <= 0:
		return -1
	var per := last_period(ev, now)
	return maxi(lim - get_counter(profile, str(ev["id"]), int(per["year"]), "craft:" + str(recipe["id"])), 0)

static func _cap_for(profile: PlayerProfile, ev: Dictionary, recipe: Dictionary, times_cap: int, now: int = -1) -> int:
	var left := limit_left(profile, ev, recipe, now)
	if left < 0:
		return times_cap
	if times_cap < 0:
		return left if not (recipe.get("materials", []) as Array).is_empty() else -1
	return mini(times_cap, left)

## Kế hoạch ép: recipe_id = AUTO -> tối ưu trên mọi công thức dùng được; khác -> chỉ công thức đó.
## Trả {ok, message, steps: [[recipe, times]], total, money, used: misc_id -> n, left: misc_id -> n}.
static func plan(profile: PlayerProfile, ev: Dictionary, recipe_id: String, placed: Dictionary, times_cap: int = -1,
		now: int = -1) -> Dictionary:
	var col := collect_placed(profile, placed)
	if not col["ok"]:
		return col
	var avail: Dictionary = col["avail"]
	var allowed := material_ids(ev)
	for mid in avail:
		if not allowed.has(mid):
			return {"ok": false, "message": "%s không phải nguyên liệu của %s." % [item_name(mid), ev.get("name", "")]}
	var steps: Array = []
	if recipe_id != AUTO:
		var r := get_recipe(ev, recipe_id)
		if r.is_empty():
			return {"ok": false, "message": "Công thức không tồn tại."}
		if limit_left(profile, ev, r, now) == 0:
			return {"ok": false, "message": "%s đã đủ %d lần trong đợt này." % [r.get("name", ""), int(r["limit"])]}
		var t := max_times(r, avail, profile.gold, _cap_for(profile, ev, r, times_cap, now))
		if t > 0:
			steps.append([r, t])
	else:
		var cands: Array = []
		var caps := {}
		for r in ev.get("recipes", []):
			var c := _cap_for(profile, ev, r, -1, now)
			if not (r.get("materials", []) as Array).is_empty() and max_times(r, avail, profile.gold, c) > 0:
				cands.append(r)
				caps[str(r["id"])] = c
		steps = _best_order(cands, avail, profile.gold, caps)
	var total := 0
	var money := 0
	var left := avail.duplicate()
	for s in steps:
		total += int(s[1])
		money += _apply_use(s[0], int(s[1]), left)
	var used := {}
	for mid in avail:
		var u := int(avail[mid]) - int(left.get(mid, 0))
		if u > 0:
			used[mid] = u
	for mid in left.keys():
		if int(left[mid]) <= 0:
			left.erase(mid)
	if total <= 0:
		return {"ok": false, "message": _missing_text(ev, recipe_id, avail, profile.gold, times_cap), "steps": [], "total": 0,
			"money": 0, "used": {}, "left": left}
	return {"ok": true, "message": "", "steps": steps, "total": total, "money": money, "used": used, "left": left}

## Thử mọi thứ tự các công thức (≤ 6 công thức có thể ép) — lấy thứ tự ép được nhiều thành phẩm nhất, hoà thì thừa ít nguyên liệu hơn.
static func _best_order(cands: Array, avail: Dictionary, gold: int, caps: Dictionary = {}) -> Array:
	if cands.is_empty():
		return []
	var orders: Array = [cands]
	if cands.size() <= 6:
		orders = _permutations(cands)
	var best: Array = []
	var best_total := -1
	var best_left := 1 << 62
	for order in orders:
		var a := avail.duplicate()
		var g := gold
		var steps: Array = []
		var total := 0
		for r in order:
			var t := max_times(r, a, g, int(caps.get(str(r["id"]), -1)))
			if t <= 0:
				continue
			g -= _apply_use(r, t, a)
			steps.append([r, t])
			total += t
		var left := 0
		for k in a:
			left += maxi(int(a[k]), 0)
		if total > best_total or (total == best_total and left < best_left):
			best_total = total
			best_left = left
			best = steps
	return best

static func _permutations(arr: Array) -> Array:
	if arr.size() <= 1:
		return [arr.duplicate()]
	var out: Array = []
	for i in arr.size():
		var rest := arr.duplicate()
		var head: Variant = rest.pop_at(i)
		for p in _permutations(rest):
			out.append([head] + p)
	return out

static func _missing_text(ev: Dictionary, recipe_id: String, avail: Dictionary, gold: int, times_cap: int) -> String:
	if recipe_id == AUTO:
		return "Nguyên liệu đặt vào chưa đủ cho công thức nào của %s." % ev.get("name", "")
	var r := get_recipe(ev, recipe_id)
	if (r.get("materials", []) as Array).is_empty() and times_cap <= 0:
		return "Nhập số lần muốn mua."
	var lack: Array = []
	for m in r.get("materials", []):
		var have := 0
		var names: Array = []
		for mid in mat_items(m):
			have += int(avail.get(mid, 0))
			names.append(item_name(mid))
		if have < int(m["count"]):
			var nm: String = names[0] if names.size() == 1 else "1 trong (%s)" % " / ".join(names)
			lack.append("%s (%d/%d)" % [nm, have, int(m["count"])])
	if int(r.get("money", 0)) > gold:
		lack.append("%s lượng" % _fmt(int(r["money"])))
	return "Thiếu: " + ", ".join(lack) if not lack.is_empty() else "Không ép được."

# ---------------------------------------------------------------- kiểm tra chỗ trống

static func free_cells(profile: PlayerProfile) -> int:
	var inv := PlayerProfile.ROOM_WIDTH * PlayerProfile.ROOM_HEIGHT * PlayerProfile.OPEN_BAGS - profile.get_used_cells()
	var st := 0
	var box := profile.storage
	var used := 0
	for it in box.inventory:
		var s := it.get_size()
		used += s.x * s.y
	st = box.room_width * box.room_height * maxi(box.bag_count, 1) - used
	return maxi(inv, 0) + maxi(st, 0)

## Số ô tối đa thành phẩm có thể chiếm khi nhận `node` `times` lần (món cùng loại tính gộp chồng).
static func _need_cells(node: Variant, times: int, acc: Dictionary) -> void:
	if not node is Dictionary:
		return
	if node.has("item"):
		var mid := str(node["item"])
		acc[mid] = int(acc.get(mid, 0)) + int(node.get("count", 1)) * times
	elif node.has("equip") or node.has("gold_row"):
		acc["__equip"] = int(acc.get("__equip", 0)) + times
	for k in ["all", "pick"]:
		if node.has(k):
			for c in node[k]:
				_need_cells(c, times, acc)

static func cells_for(acc: Dictionary) -> int:
	var cells := 0
	for mid in acc:
		if mid == "__equip":
			cells += int(acc[mid]) * EQUIP_CELLS
		else:
			cells += int(ceil(float(acc[mid]) / ItemDatabase.max_stack(mid)))
	return cells

# ---------------------------------------------------------------- ép

## Ép theo kế hoạch: trừ nguyên liệu + tiền, mỗi lần quay tỷ lệ thành công (thất bại vẫn mất nguyên liệu — đúng gốc), thành phẩm
## vào hành trang (đầy thì sang rương). Trả {ok, message, success, fail, gains}.
static func craft(profile: PlayerProfile, event_id: String, recipe_id: String, placed: Dictionary, times_cap: int = -1,
		rng: RandomNumberGenerator = null, now: int = -1) -> Dictionary:
	var ev := get_event(event_id)
	if ev.is_empty():
		return {"ok": false, "message": "Sự kiện không tồn tại."}
	if now < 0:
		now = now_unix()
	var per := current_period(ev, now)
	if per.get("status", "") != "ongoing":
		return {"ok": false, "message": "%s chưa diễn ra (bắt đầu %s)." % [ev["name"], format_date(int(per.get("start", now)))]}
	var p := plan(profile, ev, recipe_id, placed, times_cap, now)
	if not p["ok"]:
		return p
	var acc := {}
	for s in p["steps"]:
		_need_cells(s[0]["result"], int(s[1]), acc)
		if s[0].has("fail_result"):
			_need_cells(s[0]["fail_result"], int(s[1]), acc)
		for ms in (s[0].get("milestones", {}) as Dictionary).values():
			_need_cells(ms, 1, acc)
	var need := cells_for(acc)
	if need > free_cells(profile):
		return {"ok": false, "message": "Hành trang và rương không đủ chỗ (cần khoảng %d ô trống). Hãy ép ít lại." % need}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	## trừ nguyên liệu theo đúng các chồng đã đặt
	var col := collect_placed(profile, placed)
	var used: Dictionary = p["used"]
	for mid in used:
		var need_n := int(used[mid])
		for pair in col["items"].get(mid, []):
			if need_n <= 0:
				break
			var it: ItemInstance = pair[0]
			var take := mini(int(pair[1]), need_n)
			_take(profile, it, take)
			need_n -= take
	profile.gold -= int(p["money"])
	var ctx := _ctx(profile, ev, per, now)
	var ok_n := 0
	var fail_n := 0
	for s in p["steps"]:
		var r: Dictionary = s[0]
		var rate := float(r.get("rate", 100.0))
		for i in int(s[1]):
			if rate < 100.0 and rng.randf() * 100.0 >= rate:
				fail_n += 1
				if r.has("fail_result"):   ## Đoan Ngọ: nâng bánh hỏng thì trả lại Bánh chưng Thập cẩm (+ nguyên liệu chưa dùng)
					give(r["fail_result"], rng, ctx)
				continue
			ok_n += 1
			give(r["result"], rng, ctx)
			var cnt := _bump_counter(profile, event_id, int(per["year"]), "craft:" + str(r["id"]))
			var ms: Dictionary = r.get("milestones", {})
			if ms.has(str(cnt)):
				give(ms[str(cnt)], rng, ctx)
	var msg := "Ép %d lần" % (ok_n + fail_n)
	if fail_n > 0:
		msg += " — thành công %d, thất bại %d" % [ok_n, fail_n]
	if int(p["money"]) > 0:
		msg += " (−%s lượng)" % _fmt(int(p["money"]))
	var g := gains_text(ctx)
	if g != "":
		msg += ".\nNhận: " + g
	return {"ok": true, "message": msg, "success": ok_n, "fail": fail_n, "gains": ctx["gains"], "plan": p}

# ---------------------------------------------------------------- mở / dùng vật phẩm

static func use_block_reason(profile: PlayerProfile, item: ItemInstance, now: int = -1) -> String:
	if item == null or not is_usable(item.misc_id):
		return "Vật phẩm này không dùng được."
	var info: Array = _usable[item.misc_id]
	var spec: Dictionary = info[1]
	var ev := get_event(str(info[0]))
	if profile.level < int(spec.get("min_level", 0)):
		return "Cần đạt cấp %d mới dùng được %s." % [int(spec["min_level"]), item.get_display_name()]
	var lim := int(spec.get("limit", 0))
	if lim > 0:
		var per := last_period(ev, now)
		if get_counter(profile, str(ev["id"]), int(per["year"]), "use:" + item.misc_id) >= lim:
			return "Đã dùng đủ %d lần %s trong đợt này." % [lim, item.get_display_name()]
	return ""

static func open_item(profile: PlayerProfile, uid: String, rng: RandomNumberGenerator = null, now: int = -1) -> Dictionary:
	var item: ItemInstance = null
	for it in profile.inventory:
		if it.uid == uid:
			item = it
			break
	if item == null:
		return {"ok": false, "message": "Vật phẩm không còn trong hành trang."}
	var block := use_block_reason(profile, item, now)
	if block != "":
		return {"ok": false, "message": block}
	if now < 0:
		now = now_unix()
	var info: Array = _usable[item.misc_id]
	var ev := get_event(str(info[0]))
	var spec: Dictionary = info[1]
	var acc := {}
	_need_cells(spec["result"], 1, acc)
	if cells_for(acc) > free_cells(profile):
		return {"ok": false, "message": "Hành trang và rương đầy, hãy dọn bớt rồi mở."}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var per := last_period(ev, now)
	var name := item.get_display_name()
	var mid := item.misc_id
	_take(profile, item, 1)
	var ctx := _ctx(profile, ev, per, now)
	give(spec["result"], rng, ctx)
	var cnt := _bump_counter(profile, str(ev["id"]), int(per["year"]), "use:" + mid)
	var ms: Dictionary = spec.get("milestones", {})
	var bonus := ""
	if ms.has(str(cnt)):
		var ctx2 := _ctx(profile, ev, per, now)
		give(ms[str(cnt)], rng, ctx2)
		bonus = "\nMốc dùng %d lần: %s" % [cnt, gains_text(ctx2)]
		for k in ctx2["gains"]:
			ctx["gains"][k] = int(ctx["gains"].get(k, 0)) + int(ctx2["gains"][k])
	var g := gains_text(ctx)
	return {"ok": true, "message": "Dùng %s: %s%s" % [name, g if g != "" else "không nhận được gì", bonus], "gains": ctx["gains"]}

# ---------------------------------------------------------------- phát thưởng (tbAwardTemplet gốc)

static func _ctx(profile: PlayerProfile, ev: Dictionary, per: Dictionary, now: int) -> Dictionary:
	var end := int(per.get("end", now))
	if end <= now:
		end = now + 7 * DAY   ## mở đồ sau khi sự kiện kết thúc: món hạn "cuối đợt" cho thêm 7 ngày
	return {"profile": profile, "event_end": end, "now": now, "gains": {}, "lost": 0}

## Phát 1 cây thưởng: {"all": [...]} nhận hết, {"pick": [...]} quay 1 món theo rate (% / 100 — tổng < 100 có thể trượt).
static func give(node: Variant, rng: RandomNumberGenerator, ctx: Dictionary) -> void:
	if not node is Dictionary:
		return
	if node.has("all"):
		for c in node["all"]:
			give(c, rng, ctx)
		return
	if node.has("pick"):
		var r := rng.randf() * 100.0
		var acc := 0.0
		for c in node["pick"]:
			acc += float(c.get("rate", 0.0))
			if r < acc:
				give(c, rng, ctx)
				return
		return
	var profile: PlayerProfile = ctx["profile"]
	var gains: Dictionary = ctx["gains"]
	if node.has("exp"):
		profile.add_exp(int(node["exp"]))
		gains["exp"] = int(gains.get("exp", 0)) + int(node["exp"])
	elif node.has("gold"):
		profile.gold += int(node["gold"])
		gains["gold"] = int(gains.get("gold", 0)) + int(node["gold"])
	elif node.has("item"):
		var mid := str(node["item"])
		var it := ItemGenerator.generate_misc(mid, int(node.get("level", 0)))
		if it == null:
			return
		it.count = maxi(int(node.get("count", 1)), 1)
		_set_expire(it, node, ctx)
		var n := it.count
		_deliver(profile, it, ctx)
		gains["item:" + mid] = int(gains.get("item:" + mid, 0)) + n
	elif node.has("equip"):
		var e: Array = node["equip"]
		var it2 := ItemGenerator.generate(int(e[0]), int(e[1]), int(e[2]) if e.size() > 2 else 1, rng.randi_range(0, 4), [])
		if it2 != null:
			_set_expire(it2, node, ctx)
			_deliver(profile, it2, ctx)
			gains["equip:" + it2.get_display_name()] = int(gains.get("equip:" + it2.get_display_name(), 0)) + 1
	elif node.has("gold_row"):
		var gi := ItemDatabase.gold_index_of_row(int(node["gold_row"]))
		var it3 := ItemGenerator.generate_gold(gi) if gi >= 0 else null
		if it3 != null:
			_set_expire(it3, node, ctx)
			_deliver(profile, it3, ctx)
			gains["equip:" + it3.get_display_name()] = int(gains.get("equip:" + it3.get_display_name(), 0)) + 1

static func _set_expire(it: ItemInstance, node: Dictionary, ctx: Dictionary) -> void:
	var ex: Variant = node.get("expire")
	if not ex is Dictionary:
		return
	if ex.get("event_end", false):
		it.expire_at = int(ctx["event_end"])
	elif ex.has("days"):
		it.set_expire_days(int(ex["days"]), int(ctx["now"]))

## Hành trang trước (gộp chồng), phần không vừa sang rương chứa đồ.
static func _deliver(profile: PlayerProfile, it: ItemInstance, ctx: Dictionary) -> void:
	it.uid = ItemInstance.new_uid()
	if profile.add_item_stacked(it):
		return
	while it.count > 0:
		var part := it
		var cap := ItemDatabase.max_stack(it.misc_id) if it.is_misc() else 1
		if it.count > cap:
			part = ItemInstance.from_dict(it.to_dict())
			part.uid = ItemInstance.new_uid()
			part.count = cap
		if not profile.storage.add_item(part):
			ctx["lost"] = int(ctx["lost"]) + it.count
			return
		if part == it:
			return
		it.count -= cap

static func _take(profile: PlayerProfile, item: ItemInstance, n: int) -> void:
	if item.count > n:
		item.count -= n
	else:
		profile.inventory.erase(item)

static func gains_text(ctx_or_gains: Dictionary) -> String:
	var gains: Dictionary = ctx_or_gains.get("gains", ctx_or_gains) if ctx_or_gains.has("gains") else ctx_or_gains
	var parts: Array = []
	for k in gains:
		var key := str(k)
		var n := int(gains[k])
		if key == "exp":
			parts.append("%s kinh nghiệm" % _fmt(n))
		elif key == "gold":
			parts.append("%s lượng" % _fmt(n))
		elif key.begins_with("item:"):
			parts.append("%d %s" % [n, item_name(key.substr(5))])
		elif key.begins_with("equip:"):
			parts.append("%d %s" % [n, key.substr(6)])
	return ", ".join(parts)

# ---------------------------------------------------------------- mô tả (Hướng dẫn)

## Mô tả cây thưởng thành các dòng chữ (cho cửa sổ Hướng dẫn).
static func describe(node: Variant, indent := "") -> Array:
	var out: Array = []
	if not node is Dictionary:
		return out
	if node.has("all"):
		for c in node["all"]:
			out.append_array(describe(c, indent))
	elif node.has("pick"):
		var picks: Array = node["pick"]
		var total := 0.0
		for c in picks:
			total += float(c.get("rate", 0.0))
		out.append(indent + "Quay ngẫu nhiên 1 trong %d phần thưởng%s:" % [picks.size(), "" if total >= 99.99 else " (%s%% có quà)" % pct(total)])
		var sorted_picks := picks.duplicate()
		sorted_picks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("rate", 0)) > float(b.get("rate", 0)))
		for c in sorted_picks:
			var d := describe(c, "")
			out.append(indent + "   • %s — %s%%" % [", ".join(d), pct(float(c.get("rate", 0.0)))])
	elif node.has("exp"):
		out.append(indent + "%s kinh nghiệm" % _fmt(int(node["exp"])))
	elif node.has("gold"):
		out.append(indent + "%s lượng" % _fmt(int(node["gold"])))
	elif node.has("item"):
		out.append(indent + "%d %s" % [int(node.get("count", 1)), item_name(str(node["item"]))])
	elif node.has("equip") or node.has("gold_row"):
		out.append(indent + (str(node.get("name", "")) if str(node.get("name", "")) != "" else "Trang bị"))
	return out

## Tỷ lệ % gọn: 0.05 -> "0,05", 40.0 -> "40".
static func pct(v: float) -> String:
	var s := ("%.3f" % v).rstrip("0").rstrip(".")
	return s.replace(".", ",")

static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
