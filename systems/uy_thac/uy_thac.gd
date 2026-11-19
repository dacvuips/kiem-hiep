class_name UyThac
extends RefCounted
## Ủy thác (CHỈ ONLINE): thoát game nhưng nhân vật vẫn luyện công, tiêu giờ ủy thác có được từ Bạch Câu Hoàn.
##   - Mua viên Bạch Câu Hoàn (lệnh "buy") -> dùng (lệnh "use") = cộng giờ vào quỹ `uy_thac_bank` theo hệ số EXP của viên.
##   - Rời game >= MIN_SECS: lúc vào lại (sảnh / map) game server cộng EXP = thời gian rời (không quá số giờ trong quỹ) x tốc độ cấp x hệ số,
##     tiêu giờ hệ số cao trước.
## Mọi thứ do game server làm trên hồ sơ của server, giờ của server; mốc `uy_thac_seen` + quỹ + báo cáo được ProfileGuard (Godot) và
## guardClientSave (Go) giữ bản server — game không tự sửa được. Offline không có ủy thác.

const MIN_SECS := 600            ## rời dưới 10 phút: không tính (đổi map / mất mạng chốc lát)
const CHUNK_SECS := 600          ## mỗi 10 phút tính 1 lần theo cấp lúc đó (lên cấp giữa chừng thì đoạn sau theo cấp mới)
const LEVEL_PER_HOUR := 0.2      ## hệ số x1: mỗi giờ ủy thác ~ 0.2 cấp hiện tại — chỉnh cân bằng ở đây
const BANK_MAX_SECS := 240 * 3600   ## quỹ giờ tối đa (mọi hệ số cộng lại)
const MAX_BUY := 20
const STACK := 50                ## Bạch Câu Hoàn chồng tối đa 50 viên 1 ô (ItemDatabase.get_misc)

## Viên Bạch Câu Hoàn (mã vật phẩm gốc VLTK) -> giờ ủy thác, hệ số EXP, giá (lượng hoặc KNB).
const ITEMS := {
	"6_1_74":   {"hours": 8,  "mult": 1.0, "gold": 100000, "jade": 0},    ## Bạch Câu hoàn
	"6_1_130":  {"hours": 8,  "mult": 1.5, "gold": 0,      "jade": 10},   ## Đại Bạch Câu hoàn
	"6_1_1157": {"hours": 8,  "mult": 2.0, "gold": 0,      "jade": 20},   ## Bạch Câu Hoàn đặc biệt
	"6_1_1434": {"hours": 80, "mult": 1.5, "gold": 0,      "jade": 90},   ## Đại bạch câu trường hiệu
}

static func is_item(misc_id: String) -> bool:
	return ITEMS.has(misc_id)

static func _mult_key(mult: float) -> String:
	return "%.1f" % mult

## Tổng giây còn trong quỹ.
static func bank_secs(profile: PlayerProfile) -> int:
	var total := 0
	for k in profile.uy_thac_bank:
		total += int(profile.uy_thac_bank[k])
	return total

## EXP 1 giờ ủy thác ở cấp hiện tại, hệ số x1.
static func exp_per_hour(profile: PlayerProfile) -> int:
	if profile == null or profile.level >= PlayerProfile.MAX_LEVEL:
		return 0
	return int(profile.get_exp_to_next_level() * LEVEL_PER_HOUR)

static func price_text(mid: String, n: int = 1) -> String:
	var def: Dictionary = ITEMS.get(mid, {})
	if int(def.get("jade", 0)) > 0:
		return "%d KNB" % (int(def["jade"]) * n)
	return "%s lượng" % format_money(int(def.get("gold", 0)) * n)

## Mua `n` viên (server). Trả {ok, message}.
static func buy(profile: PlayerProfile, mid: String, n: int) -> Dictionary:
	if profile == null or not is_item(mid):
		return {"ok": false, "message": "Vật phẩm này không bán."}
	n = clampi(n, 1, MAX_BUY)
	var def: Dictionary = ITEMS[mid]
	var gold := int(def["gold"]) * n
	var jade := int(def["jade"]) * n
	if profile.gold < gold or profile.jade < jade:
		return {"ok": false, "message": "Không đủ %s (cần %s)." % ["KNB" if jade > 0 else "lượng", price_text(mid, n)]}
	var item := ItemGenerator.generate_misc(mid)   ## n viên = 1 chồng (n <= MAX_BUY < STACK)
	if item == null:
		return {"ok": false, "message": "Vật phẩm này không bán."}
	item.count = n
	if not profile.add_item(item):
		return {"ok": false, "message": "Hành trang đã đầy."}
	profile.gold -= gold
	profile.jade -= jade
	return {"ok": true, "message": "Đã mua %d %s (%s)." % [n, item.get_display_name(), price_text(mid, n)]}

## Dùng 1 viên có uid `uid` (server): cộng giờ vào quỹ. Trả {ok, message}.
static func use(profile: PlayerProfile, uid: String) -> Dictionary:
	if profile == null or uid == "":
		return {"ok": false, "message": "Vật phẩm không còn trong hành trang."}
	for i in profile.inventory.size():
		var item: ItemInstance = profile.inventory[i]
		if item == null or item.uid != uid or not is_item(item.misc_id):
			continue
		var def: Dictionary = ITEMS[item.misc_id]
		var add := int(def["hours"]) * 3600
		if bank_secs(profile) + add > BANK_MAX_SECS:
			return {"ok": false, "message": "Quỹ ủy thác đã gần đầy (tối đa %d giờ)." % (BANK_MAX_SECS / 3600)}
		var name := item.get_display_name()
		if item.count > 1:
			item.count -= 1
		else:
			profile.inventory.remove_at(i)
		var key := _mult_key(float(def["mult"]))
		profile.uy_thac_bank[key] = int(profile.uy_thac_bank.get(key, 0)) + add
		return {"ok": true, "message": "Dùng %s: +%d giờ ủy thác (x%s EXP). Quỹ còn %s." % [name, int(def["hours"]), key,
			format_duration(bank_secs(profile))]}
	return {"ok": false, "message": "Vật phẩm không còn trong hành trang."}

## Tính + cộng EXP cho khoảng thời gian rời game tới `now` (giây unix, giờ server), tiêu giờ trong quỹ, rồi đặt mốc mới = now.
## Trả {} nếu không được gì; có thì trả bản báo cáo (cũng ghi vào profile.uy_thac_report).
static func settle(profile: PlayerProfile, now: int) -> Dictionary:
	if profile == null:
		return {}
	var since := profile.uy_thac_seen
	profile.uy_thac_seen = now
	if since <= 0 or now - since < MIN_SECS or bank_secs(profile) <= 0:
		return {}   ## chưa có mốc / rời quá ngắn / đồng hồ lùi / hết giờ ủy thác
	var away := now - since
	var left := away
	var from_level := profile.level
	var total := 0
	var used := 0
	var carry := 0.0   ## phần lẻ EXP giữa các đoạn 10 phút (không mất do làm tròn)
	var keys: Array = profile.uy_thac_bank.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(a) > float(b))   ## hệ số cao tiêu trước
	for key in keys:
		var mult := float(key)
		while left > 0 and int(profile.uy_thac_bank[key]) > 0 and profile.level < PlayerProfile.MAX_LEVEL:
			var part := mini(mini(left, CHUNK_SECS), int(profile.uy_thac_bank[key]))
			var exact := exp_per_hour(profile) * mult * part / 3600.0 + carry
			var gain := int(exact)
			carry = exact - gain
			if gain > 0:
				profile.add_exp(gain)
				total += gain
			profile.uy_thac_bank[key] = int(profile.uy_thac_bank[key]) - part
			left -= part
			used += part
		if int(profile.uy_thac_bank[key]) <= 0:
			profile.uy_thac_bank.erase(key)
	if total <= 0:
		return {}
	var report := {"t": now, "away": away, "secs": used, "exp": total, "from": from_level, "to": profile.level,
		"bank_left": bank_secs(profile)}
	profile.uy_thac_report = report
	return report

## 1234567 -> "1.234.567" (không dùng lớp UI: server cũng gọi).
static func format_money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

static func format_duration(secs: int) -> String:
	var h := secs / 3600
	var m := (secs % 3600) / 60
	return "%d giờ %d phút" % [h, m] if h > 0 else "%d phút" % m

## Câu thông báo ngắn (S_NOTICE lúc vào game).
static func format_notice(report: Dictionary) -> String:
	var txt := "Ủy thác %s: +%d EXP" % [format_duration(int(report.get("secs", 0))), int(report.get("exp", 0))]
	var lv_from := int(report.get("from", 0))
	var lv_to := int(report.get("to", 0))
	if lv_to > lv_from:
		txt += " — lên cấp %d → %d" % [lv_from, lv_to]
	txt += ". Quỹ ủy thác còn %s." % format_duration(int(report.get("bank_left", 0)))
	return txt
