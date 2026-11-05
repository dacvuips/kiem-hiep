extends RefCounted
class_name LivestockManager
## Quản lý đàn gia súc (Khu Chăn Nuôi) trên Nguyệt Ca Đảo (Tọa độ 194/193).
## - Từng con thú có thanh đói (hunger) và thời gian sắp thu hoạch (countdown).
## - Nếu thanh đói và chỉ số đói bằng 0 -> Thời gian thu hoạch TẠM DỪNG cho tới khi được cho ăn.
## - Tương tác trực tiếp trên con thú (click để cho ăn, thu hoạch, chăm sóc).

enum AnimalState {
	HUNGRY = 0,   # Đang đói (chỉ số đói = 0, thời gian thu hoạch tạm dừng)
	GROWING = 1,  # Đang sinh trưởng (thanh đói > 0, thời gian tiếp tục đếm ngược)
	READY = 2     # Đã lớn / Sẵn sàng thu hoạch
}

## Danh mục các loại thức ăn chăn nuôi:
## QUY TẮC CỐT LÕI: Thú chỉ ăn các loại do người chơi TỰ TRỒNG TRỌT hoặc ĐÁNH BẮT / NUÔI CÁ thu hoạch được!
const LIVESTOCK_FEEDS := {
	# --- NÔNG SẢN TỰ TRỒNG TRỌT (Thu hoạch từ các Luống Đất) ---
	"lua_vang": {
		"id": "lua_vang",
		"name": "Lúa Vàng Thần Nông",
		"icon": "damai.png",
		"category_tag": "Nông Sản Trồng Trọt",
		"desc": "Lúa vàng óng ả thu hoạch từ luống đất, thức ăn bổ dưỡng khoái khẩu của gia súc (+45 Đói, +10 Thân Mật, giảm 10% thời gian lớn).",
		"hunger_restore": 45.0,
		"intimacy_bonus": 10,
		"time_reduction_pct": 0.10,
		"bonus_gold_pct": 0.0
	},
	"tao_do": {
		"id": "tao_do",
		"name": "Táo Đỏ Tươi Mọng",
		"icon": "hongpingguo.png",
		"category_tag": "Nông Sản Trồng Trọt",
		"desc": "Táo đỏ chín mọng thơm ngọt bồi dưỡng thể lực đàn thú (+55 Đói, +12 Thân Mật, giảm 15% thời gian lớn).",
		"hunger_restore": 55.0,
		"intimacy_bonus": 12,
		"time_reduction_pct": 0.15,
		"bonus_gold_pct": 0.0
	},
	"hoa_cuc": {
		"id": "hoa_cuc",
		"name": "Hoa Cúc Dược Tính",
		"icon": "jihuazhi.png",
		"category_tag": "Nông Sản Trồng Trọt",
		"desc": "Hoa cúc thanh nhiệt giải độc giúp đàn thú khỏe mạnh (+50 Đói, +10 Thân Mật, giảm 12% thời gian lớn).",
		"hunger_restore": 50.0,
		"intimacy_bonus": 10,
		"time_reduction_pct": 0.12,
		"bonus_gold_pct": 0.0
	},
	"tra_xanh": {
		"id": "tra_xanh",
		"name": "Trà Xanh Tươi Non",
		"icon": "huangcha.png",
		"category_tag": "Nông Sản Trồng Trọt",
		"desc": "Búp trà xanh non mơn mởn bồi bổ tinh thần cho thú (+55 Đói, +12 Thân Mật, giảm 15% thời gian lớn).",
		"hunger_restore": 55.0,
		"intimacy_bonus": 12,
		"time_reduction_pct": 0.15,
		"bonus_gold_pct": 0.0
	},
	"duoc_thao": {
		"id": "duoc_thao",
		"name": "Dược Thảo Sơn Trang",
		"icon": "bainianqixingcao.png",
		"category_tag": "Dược Liệu Trồng Trọt",
		"desc": "Dược thảo quý bồi bổ khí huyết, tăng tốc sinh trưởng đàn thú (+65 Đói, +15 Thân Mật, giảm 20% thời gian lớn).",
		"hunger_restore": 65.0,
		"intimacy_bonus": 15,
		"time_reduction_pct": 0.20,
		"bonus_gold_pct": 0.0
	},
	"linh_chi": {
		"id": "linh_chi",
		"name": "Linh Chi Thần Nông",
		"icon": "heidiaoxin.png",
		"category_tag": "Kỳ Thảo Trồng Trọt",
		"desc": "Linh chi thảo ngàn năm đại bổ dưỡng (+85 Đói, +25 Thân Mật, giảm 35% thời gian lớn, +15% sản lượng vàng).",
		"hunger_restore": 85.0,
		"intimacy_bonus": 25,
		"time_reduction_pct": 0.35,
		"bonus_gold_pct": 0.15
	},
	"nhan_sam": {
		"id": "nhan_sam",
		"name": "Nhân Sâm Nghìn Năm",
		"icon": "bainianqixingcao.png",
		"category_tag": "Tiên Dược Trồng Trọt",
		"desc": "Nhân sâm nghìn năm cực phẩm bồi bổ (+100 Đói đầy bụng, +40 Thân Mật, giảm 60% thời gian lớn, +30% sản lượng vàng).",
		"hunger_restore": 100.0,
		"intimacy_bonus": 40,
		"time_reduction_pct": 0.60,
		"bonus_gold_pct": 0.30
	},
	"mai_hoa": {
		"id": "mai_hoa",
		"name": "Hàn Mai Tuyết Thảo",
		"icon": "canhmai.png",
		"category_tag": "Thần Dược Trồng Trọt",
		"desc": "Hàn mai tuyết thảo trân quý tuyệt đỉnh (+100 Đói đầy bụng, LỚN NGAY LẬP TỨC 100% sẵn sàng thu hoạch, +50% sản lượng vàng, +50 Thân Mật).",
		"hunger_restore": 100.0,
		"intimacy_bonus": 50,
		"time_reduction_pct": 1.0,
		"bonus_gold_pct": 0.50
	},
	# --- THỦY HẢI SẢN ĐÁNH BẮT & NUÔI CÁ (Thu hoạch từ Ao Cá & Bè Biển) ---
	"fish_fresh": {
		"id": "fish_fresh",
		"name": "Cá Trắm Cỏ Hồ",
		"icon": "caoyu.png",
		"category_tag": "Thủy Sản Nuôi & Đánh Bắt",
		"desc": "Cá trắm cỏ tươi sống kéo lưới từ Ao Cá nước ngọt (+70 Đói, +18 Thân Mật, giảm 25% thời gian lớn, +10% sản lượng vàng).",
		"hunger_restore": 70.0,
		"intimacy_bonus": 18,
		"time_reduction_pct": 0.25,
		"bonus_gold_pct": 0.10
	},
	"fish_ocean": {
		"id": "fish_ocean",
		"name": "Cá Vược Biển Sâu",
		"icon": "bianyu.png",
		"category_tag": "Hải Sản Đánh Bắt Biển Sâu",
		"desc": "Cá vược biển tươi roi rói kéo lưới từ Bè Cá Biển Sâu (+100 Đói đầy bụng, +30 Thân Mật, giảm 45% thời gian lớn, +25% sản lượng vàng).",
		"hunger_restore": 100.0,
		"intimacy_bonus": 30,
		"time_reduction_pct": 0.45,
		"bonus_gold_pct": 0.25
	},
	"caoyu": {
		"id": "caoyu",
		"name": "Cá Trắm Cỏ Câu Ven Bờ",
		"icon": "caoyu.png",
		"category_tag": "Thủy Sản Câu Cá",
		"desc": "Cá trắm tươi câu được ven hồ Nguyệt Ca (+70 Đói, +18 Thân Mật, giảm 25% thời gian lớn).",
		"hunger_restore": 70.0,
		"intimacy_bonus": 18,
		"time_reduction_pct": 0.25,
		"bonus_gold_pct": 0.10
	},
	"bianyu": {
		"id": "bianyu",
		"name": "Cá Vược Biển Câu Cầu Tàu",
		"icon": "bianyu.png",
		"category_tag": "Hải Sản Câu Cá",
		"desc": "Cá vược câu được ven cầu tàu đại dương (+100 Đói, +30 Thân Mật, giảm 45% thời gian lớn).",
		"hunger_restore": 100.0,
		"intimacy_bonus": 30,
		"time_reduction_pct": 0.45,
		"bonus_gold_pct": 0.25
	}
}

class AnimalInfo:
	var index: int = 0
	var level: int = 1 # Cấp độ chuồng / thú nuôi (1..5)
	var animal_id: String = "pig"
	var name: String = "Heo Trắng"
	var res: String = "ani063"
	var state: AnimalState = AnimalState.GROWING
	var fed_at: int = 0
	var total_grow_time: int = 120 # Giây sinh trưởng yêu cầu
	var grow_time_elapsed: float = 0.0 # Số giây sinh trưởng đã tích lũy
	var hunger: float = 100.0 # Chỉ số đói (0.0 -> 100.0)
	var max_hunger: float = 100.0
	var hunger_drain_rate: float = 100.0 / 60.0 # Tiêu hao đói (hết trong 60 giây)
	var thirst: float = 100.0 # Chỉ số nước uống (0.0 -> 100.0)
	var max_thirst: float = 100.0
	var thirst_drain_rate: float = 100.0 / 75.0 # Tiêu hao nước (hết trong 75 giây)
	var product_name: String = "Thịt Heo Sạch"
	var product_id: String = "produce_pork"
	var gold_reward: int = 60
	var exp_reward: int = 30
	var care_count: int = 0 # Số lần dùng roi chăn (max 3)
	var is_roaming_outside: bool = true # Thú nuôi tự do di chuyển
	var intimacy: int = 0 # Độ thân mật với chủ nhân
	var bonus_gold_rate: float = 0.0 # Thưởng thêm sản lượng vàng từ thức ăn cao cấp
	var bonus_exp_rate: float = 0.0 # Thưởng thêm exp từ thức ăn cao cấp
	var last_tick_unix: int = 0
	var pos_x: float = 0.0 # Lưu tọa độ thế giới để thú không bị nhảy vị trí
	var pos_y: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"index": index,
			"level": level,
			"animal_id": animal_id,
			"name": name,
			"res": res,
			"state": int(state),
			"fed_at": fed_at,
			"total_grow_time": total_grow_time,
			"grow_time_elapsed": grow_time_elapsed,
			"hunger": hunger,
			"max_hunger": max_hunger,
			"thirst": thirst,
			"max_thirst": max_thirst,
			"product_name": product_name,
			"product_id": product_id,
			"gold_reward": gold_reward,
			"exp_reward": exp_reward,
			"care_count": care_count,
			"is_roaming_outside": is_roaming_outside,
			"intimacy": intimacy,
			"bonus_gold_rate": bonus_gold_rate,
			"bonus_exp_rate": bonus_exp_rate,
			"last_tick_unix": int(Time.get_unix_time_from_system()),
			"pos_x": pos_x,
			"pos_y": pos_y
		}

	func from_dict(d: Dictionary) -> void:
		index = int(d.get("index", 0))
		level = clampi(int(d.get("level", 1)), 1, 5)
		animal_id = str(d.get("animal_id", "pig"))
		name = str(d.get("name", "Heo Trắng"))
		res = str(d.get("res", "ani063"))
		state = int(d.get("state", AnimalState.GROWING)) as AnimalState
		fed_at = int(d.get("fed_at", 0))
		total_grow_time = int(d.get("total_grow_time", 120))
		grow_time_elapsed = float(d.get("grow_time_elapsed", 0.0))
		hunger = float(d.get("hunger", 100.0))
		max_hunger = float(d.get("max_hunger", 100.0))
		thirst = float(d.get("thirst", 100.0))
		max_thirst = float(d.get("max_thirst", 100.0))
		product_name = str(d.get("product_name", "Thịt Heo Sạch"))
		product_id = str(d.get("product_id", "produce_pork"))
		gold_reward = int(d.get("gold_reward", 60))
		exp_reward = int(d.get("exp_reward", 30))
		care_count = int(d.get("care_count", 0))
		is_roaming_outside = bool(d.get("is_roaming_outside", true))
		intimacy = int(d.get("intimacy", 0))
		bonus_gold_rate = float(d.get("bonus_gold_rate", 0.0))
		bonus_exp_rate = float(d.get("bonus_exp_rate", 0.0))
		pos_x = float(d.get("pos_x", 0.0))
		pos_y = float(d.get("pos_y", 0.0))

		# Tương thích ngược dữ liệu cũ nếu chưa có grow_time_elapsed
		if grow_time_elapsed <= 0.0 and fed_at > 0 and state != AnimalState.HUNGRY:
			var now := int(Time.get_unix_time_from_system())
			var old_elapsed := float(now - fed_at)
			if old_elapsed > 0:
				grow_time_elapsed = minf(float(total_grow_time), old_elapsed)
				hunger = maxf(0.0, 100.0 - (grow_time_elapsed * hunger_drain_rate))

		# Mô phỏng thời gian trôi qua khi offline
		var last_saved := int(d.get("last_tick_unix", 0))
		if last_saved > 0:
			var now := int(Time.get_unix_time_from_system())
			if now > last_saved:
				advance_offline_time(float(now - last_saved))

	## Hệ số tốc độ sinh trưởng (Roi Chăn + Nâng Cấp Chuồng)
	func get_growth_rate() -> float:
		var rate := 1.0 + float(care_count) * 0.25 # +25% mỗi lần roi
		rate *= (1.0 + float(level - 1) * 0.15)    # +15% mỗi cấp độ
		return maxf(0.1, rate)

	## Tiến độ sinh trưởng (0.0 -> 1.0)
	func get_progress() -> float:
		if state == AnimalState.READY:
			return 1.0
		if total_grow_time <= 0:
			return 1.0
		return clampf(grow_time_elapsed / float(total_grow_time), 0.0, 1.0)

	## Thời gian còn lại tính bằng giây cho tới lúc thu hoạch
	func get_remaining_time() -> float:
		if state == AnimalState.READY:
			return 0.0
		var remaining_seconds := maxf(0.0, float(total_grow_time) - grow_time_elapsed)
		var rate := get_growth_rate()
		return remaining_seconds / rate

	## Cập nhật tiến độ theo từng khung hình (delta)
	## QUY TẮC CỐT LÕI:
	## Nếu thanh đói hoặc thanh nước cạn về 0 -> Thời gian thu hoạch DỪNG LẠI cho tới khi được cho ăn / uống nước.
	func tick(delta: float) -> void:
		if state == AnimalState.READY:
			return

		# 1. Nếu đói hoặc khát cạn về 0 -> Đang đói/khát, DỪNG THỜI GIAN THU HOẠCH!
		if hunger <= 0.0 or thirst <= 0.0:
			if hunger <= 0.0: hunger = 0.0
			if thirst <= 0.0: thirst = 0.0
			state = AnimalState.HUNGRY
			return

		# 2. Tiêu hao thanh đói & thanh nước dần dần
		hunger = maxf(0.0, hunger - delta * hunger_drain_rate)
		thirst = maxf(0.0, thirst - delta * thirst_drain_rate)

		# 3. Tiến trình thu hoạch tiếp tục tích lũy
		var rate := get_growth_rate()
		grow_time_elapsed += delta * rate

		if grow_time_elapsed >= float(total_grow_time):
			grow_time_elapsed = float(total_grow_time)
			state = AnimalState.READY
		elif hunger <= 0.0 or thirst <= 0.0:
			state = AnimalState.HUNGRY
		else:
			state = AnimalState.GROWING

	## Mô phỏng thời gian offline trôi qua khi thoát game
	func advance_offline_time(elapsed_seconds: float) -> void:
		if elapsed_seconds <= 0.0 or state == AnimalState.READY:
			return
		if hunger <= 0.0 or thirst <= 0.0:
			return

		var time_until_starve := minf(hunger / hunger_drain_rate, thirst / thirst_drain_rate)
		var active_time := minf(elapsed_seconds, time_until_starve)

		hunger = maxf(0.0, hunger - active_time * hunger_drain_rate)
		thirst = maxf(0.0, thirst - active_time * thirst_drain_rate)
		var rate := get_growth_rate()
		grow_time_elapsed = minf(float(total_grow_time), grow_time_elapsed + active_time * rate)

		if grow_time_elapsed >= float(total_grow_time):
			grow_time_elapsed = float(total_grow_time)
			state = AnimalState.READY
		elif hunger <= 0.0:
			hunger = 0.0
			state = AnimalState.HUNGRY
		else:
			state = AnimalState.GROWING

var animals: Array[AnimalInfo] = []

func _init() -> void:
	_init_default_animals()

func _init_default_animals() -> void:
	animals.clear()
	
	var defs = [
		{
			"id": "pig",
			"name": "Heo Trắng",
			"res": "ani063",
			"grow": 120,
			"prod": "Thịt Heo Sạch",
			"prod_id": "produce_pork",
			"gold": 60,
			"exp": 30
		},
		{
			"id": "buffalo",
			"name": "Trâu Cày",
			"res": "ani029",
			"grow": 180,
			"prod": "Thịt Trâu Tươi",
			"prod_id": "produce_buffalo_meat",
			"gold": 90,
			"exp": 45
		},
		{
			"id": "deer",
			"name": "Hươu Sao",
			"res": "ani061",
			"grow": 240,
			"prod": "Thịt Hươu Tươi",
			"prod_id": "produce_deer_meat",
			"gold": 130,
			"exp": 65
		},
		{
			"id": "boar",
			"name": "Heo Rừng",
			"res": "ani018",
			"grow": 150,
			"prod": "Thịt Heo Rừng",
			"prod_id": "produce_wild_pork",
			"gold": 75,
			"exp": 40
		}
	]

	for i in range(defs.size()):
		var d = defs[i]
		var a := AnimalInfo.new()
		a.index = i
		a.animal_id = d["id"]
		a.name = d["name"]
		a.res = d["res"]
		a.total_grow_time = d["grow"]
		a.product_name = d["prod"]
		a.product_id = d["prod_id"]
		a.gold_reward = d["gold"]
		a.exp_reward = d["exp"]
		# Mặc định ban đầu cho ăn no để thú đang lớn
		a.state = AnimalState.GROWING
		a.hunger = 85.0
		a.grow_time_elapsed = float(d["grow"]) * 0.35
		animals.append(a)

## Cập nhật toàn bộ đàn gia súc theo delta thời gian
func tick(delta: float) -> void:
	for a in animals:
		a.tick(delta)

## Nhận nuôi / Thêm con vật mới vào chuồng trại khi người chơi mua từ NPC
func adopt_animal(d: Dictionary) -> bool:
	var new_animal := AnimalInfo.new()
	new_animal.animal_id = str(d.get("animal_id", d.get("id", "pig")))
	new_animal.name = str(d.get("name", "Vật Nuôi"))
	new_animal.res = str(d.get("monster_res", d.get("res", "ani063")))
	new_animal.total_grow_time = int(d.get("grow_time", 120))
	var hp := str(d.get("harvest_prod", ""))
	new_animal.product_name = hp if hp != "" else ("Thịt " + new_animal.name)
	new_animal.product_id = str(d.get("prod_id", "prod_" + new_animal.animal_id))
	new_animal.gold_reward = int(d.get("price_gold", 50)) + 20
	new_animal.exp_reward = int(new_animal.gold_reward / 2)
	new_animal.state = AnimalState.GROWING
	new_animal.hunger = 100.0
	new_animal.grow_time_elapsed = 0.0
	new_animal.care_count = 0

	# Cho phép nuôi đàn thú lên tới 48 con tự do dạo chơi ngoài trời
	if animals.size() < 48:
		new_animal.index = animals.size()
		animals.append(new_animal)
		return true

	# Hoặc tìm ô chuồng đã thu hoạch / đói để thay thế
	for i in range(animals.size()):
		if animals[i].state == AnimalState.HUNGRY or animals[i].state == AnimalState.READY:
			new_animal.index = i
			animals[i] = new_animal
			return true

	new_animal.index = 0
	animals[0] = new_animal
	return true

## Nâng cấp chuồng / thú nuôi (Cấp 1 -> Cấp 5)
func upgrade_animal(idx: int) -> Dictionary:
	if idx < 0 or idx >= animals.size():
		return {"success": false, "msg": "Không tìm thấy thú nuôi!"}
	var a := animals[idx]
	if a.level >= 5:
		return {"success": false, "msg": "%s đã đạt Cấp 5 tối đa (Thần Thú Nở Hoa)!" % a.name}
	var cost := a.level * 150
	a.level += 1
	a.gold_reward = int(a.gold_reward * 1.25)
	a.exp_reward = int(a.exp_reward * 1.25)
	return {
		"success": true,
		"new_level": a.level,
		"cost": cost,
		"msg": "⭐ Đã nâng cấp %s lên Cấp %d (+15%% tốc độ, +25%% sản lượng)!" % [a.name, a.level]
	}

## Bật/tắt cho phép đàn thú nuôi di chuyển dạo chơi ngoài trời
func set_all_roaming_outside(roam: bool) -> void:
	for a in animals:
		a.is_roaming_outside = roam

## Vuốt ve thú nuôi khi đi dạo ngoài trời
func pet_animal(idx: int) -> Dictionary:
	if idx < 0 or idx >= animals.size():
		return {"success": false, "msg": "Không tìm thấy thú nuôi!"}
	var a := animals[idx]
	a.intimacy += 10
	return {
		"success": true,
		"msg": "🐾 Bạn vuốt ve %s, nó mừng rỡ dụi đầu vào tay bạn! (+10 Thân Thiết)" % a.name,
		"intimacy": a.intimacy
	}

## Cho ăn con thú: Thú CHỈ ĂN các loại nông sản do người chơi tự trồng hoặc thủy hải sản tự đánh bắt / nuôi cá!
func feed_animal(idx: int, feed_id: String = "") -> Dictionary:
	if idx < 0 or idx >= animals.size():
		return {"success": false, "msg": "Không tìm thấy thú nuôi!"}
	var a := animals[idx]
	if a.state == AnimalState.READY:
		return {"success": false, "msg": "✨ %s đã lớn sẵn sàng thu hoạch, không cần ăn nữa!" % a.name}

	if feed_id == "" or not LIVESTOCK_FEEDS.has(feed_id):
		return {
			"success": false,
			"msg": "🌾 Đàn thú chỉ ăn những loại mà bạn TỰ TRỒNG TRỌT (Lúa, Táo, Hoa Cúc, Trà, Dược Thảo, Sâm, Linh Chi) hoặc ĐÁNH BẮT / NUÔI CÁ (Cá Trắm Cỏ, Cá Vược Biển)!"
		}

	var feed_info: Dictionary = LIVESTOCK_FEEDS[feed_id]
	var feed_name := str(feed_info.get("name", "Nông Sản / Cá"))
	var restore_hunger: float = float(feed_info.get("hunger_restore", 60.0))
	var intimacy_add: int = int(feed_info.get("intimacy_bonus", 10))
	var time_red_pct: float = float(feed_info.get("time_reduction_pct", 0.0))
	var bonus_gold: float = float(feed_info.get("bonus_gold_pct", 0.0))

	if a.hunger >= a.max_hunger and time_red_pct <= 0.0 and bonus_gold <= 0.0:
		return {"success": false, "msg": "🌾 %s đã no nê (100%%)!" % a.name}

	# Trừ nông sản hoặc cá từ Rương Nông Sản (hoặc rương vật tư)
	var tree := Engine.get_main_loop() as SceneTree
	var farm_mgr: Node = tree.root.get_node_or_null("FarmManager") if (tree and tree.root) else null
	if farm_mgr != null and farm_mgr.has_method("remove_from_chest"):
		# Thử trừ trong rương nông sản trước (is_supply = false)
		var removed: bool = bool(farm_mgr.remove_from_chest(feed_id, 1, false))
		if not removed:
			# Dự phòng kiểm tra rương vật tư (is_supply = true)
			removed = bool(farm_mgr.remove_from_chest(feed_id, 1, true))
		if not removed:
			return {
				"success": false,
				"msg": "❌ Không có đủ [%s] trong Rương Sơn Trang! Hãy đi trồng trọt hoặc nuôi/bắt cá để thu hoạch!" % feed_name
			}

	# Hồi phục thanh đói
	a.hunger = minf(a.max_hunger, a.hunger + restore_hunger)

	# Tăng độ thân mật
	a.intimacy += intimacy_add

	# Rút ngắn thời gian lớn nếu có hiệu ứng thức ăn cao cấp
	if time_red_pct >= 1.0:
		a.grow_time_elapsed = float(a.total_grow_time)
	elif time_red_pct > 0.0:
		var remaining := float(a.total_grow_time) - a.grow_time_elapsed
		a.grow_time_elapsed += remaining * time_red_pct

	# Buff sản lượng thu hoạch
	if bonus_gold > 0.0:
		a.bonus_gold_rate = maxf(a.bonus_gold_rate, bonus_gold)
		a.bonus_exp_rate = maxf(a.bonus_exp_rate, bonus_gold)

	# Cập nhật trạng thái sau khi ăn
	if a.grow_time_elapsed >= float(a.total_grow_time):
		a.grow_time_elapsed = float(a.total_grow_time)
		a.state = AnimalState.READY
	elif a.hunger > 0.0 and a.thirst > 0.0:
		a.state = AnimalState.GROWING

	var msg := "🌾 Đã cho %s ăn %s (+%d Đói, +%d Thân Mật)!" % [a.name, feed_name, int(restore_hunger), intimacy_add]
	if time_red_pct >= 1.0:
		msg += " ✨ Lớn ngay lập tức sẵn sàng thu hoạch!"
	elif time_red_pct > 0.0:
		msg += " ⏱️ Rút ngắn %d%% thời gian chờ!" % int(time_red_pct * 100)
	if bonus_gold > 0.0:
		msg += " 💰 +%d%% sản lượng vàng!" % int(bonus_gold * 100)

	return {
		"success": true,
		"type": "feed",
		"msg": msg
	}

## Cho ăn hàng loạt toàn bộ đàn thú nuôi:
## Tự động tìm tất cả con thú đang cần ăn (chưa sẵn sàng thu hoạch và hunger < max_hunger).
## feed_id: nếu để trống thì tự động lấy loại nông sản/cá có sẵn trong rương Sơn Trang.
## Trả về: { "success": bool, "fed_count": int, "hungry_count": int, "msg": String }
func feed_all_animals(feed_id: String = "") -> Dictionary:
	var hungry_indices: Array[int] = []
	for i in range(animals.size()):
		var a := animals[i]
		if a.state != AnimalState.READY and a.get_progress() < 1.0 and a.hunger < a.max_hunger:
			hungry_indices.append(i)

	if hungry_indices.is_empty():
		return {
			"success": false,
			"fed_count": 0,
			"hungry_count": 0,
			"msg": "🌾 Toàn bộ đàn thú đã no nê (100%), không con nào cần ăn!"
		}

	var tree := Engine.get_main_loop() as SceneTree
	var farm_mgr: Node = tree.root.get_node_or_null("FarmManager") if (tree and tree.root) else null

	var fed_count := 0
	for idx in hungry_indices:
		var current_feed := feed_id
		if current_feed == "":
			if farm_mgr != null and farm_mgr.has_method("use_any_feed"):
				current_feed = farm_mgr.use_any_feed(false)
			else:
				current_feed = "lua_vang"
		if current_feed == "":
			break # Hết thức ăn trong rương
		var res := feed_animal(idx, current_feed)
		if res.get("success", false):
			fed_count += 1
		else:
			break

	if fed_count == 0:
		return {
			"success": false,
			"fed_count": 0,
			"hungry_count": hungry_indices.size(),
			"msg": "❌ Không có đủ thức ăn trong kho! Hãy đi trồng trọt hoặc câu/nuôi cá."
		}

	var msg := "🌾 Đã cho ăn hàng loạt %d/%d con thú đang đói!" % [fed_count, hungry_indices.size()]
	if fed_count < hungry_indices.size():
		msg += " (Đã hết thức ăn trong kho)"
	return {
		"success": true,
		"fed_count": fed_count,
		"hungry_count": hungry_indices.size(),
		"msg": msg
	}

## Cho thú uống nước: Hồi phục 100% thanh nước, tiếp tục đếm ngược thu hoạch
func water_animal(idx: int) -> Dictionary:
	if idx < 0 or idx >= animals.size():
		return {"success": false, "msg": "Không tìm thấy thú nuôi!"}
	var a := animals[idx]
	if a.state == AnimalState.READY:
		return {"success": false, "msg": "✨ %s đã lớn sẵn sàng thu hoạch, không cần uống nước nữa!" % a.name}

	if a.thirst >= a.max_thirst:
		return {"success": false, "msg": "💧 %s đã no nước (100%%)!" % a.name}

	a.thirst = a.max_thirst
	a.intimacy += 5
	if a.hunger > 0.0 and a.grow_time_elapsed < float(a.total_grow_time):
		a.state = AnimalState.GROWING
	elif a.grow_time_elapsed >= float(a.total_grow_time):
		a.state = AnimalState.READY

	return {
		"success": true,
		"type": "water",
		"msg": "💧 Đã cho %s uống nước (+100 Nước, +5 Thân Mật)!" % a.name
	}

## Cho uống nước hàng loạt toàn bộ đàn thú nuôi:
## Tự động tìm tất cả con thú đang cần uống nước (chưa sẵn sàng thu hoạch và thirst < max_thirst).
## Trả về: { "success": bool, "watered_count": int, "thirsty_count": int, "msg": String }
func water_all_animals() -> Dictionary:
	var thirsty_indices: Array[int] = []
	for i in range(animals.size()):
		var a := animals[i]
		if a.state != AnimalState.READY and a.get_progress() < 1.0 and a.thirst < a.max_thirst:
			thirsty_indices.append(i)

	if thirsty_indices.is_empty():
		return {
			"success": false,
			"watered_count": 0,
			"thirsty_count": 0,
			"msg": "💧 Toàn bộ đàn thú đã no nước (100%), không con nào bị khát!"
		}

	var tree := Engine.get_main_loop() as SceneTree
	var farm_mgr: Node = tree.root.get_node_or_null("FarmManager") if (tree and tree.root) else null

	var watered_count := 0
	for idx in thirsty_indices:
		if farm_mgr != null:
			if farm_mgr.has_method("get_water_count") and farm_mgr.get_water_count() <= 0:
				break
			if farm_mgr.has_method("use_water"):
				if not farm_mgr.use_water(1):
					break
		var res := water_animal(idx)
		if res.get("success", false):
			watered_count += 1
		else:
			break

	if watered_count == 0:
		return {
			"success": false,
			"watered_count": 0,
			"thirsty_count": thirsty_indices.size(),
			"msg": "❌ Hết nước uống trong kho! Hãy bấm nút [+ Lấy Nước] để bổ sung."
		}

	var msg := "💧 Đã cho uống nước hàng loạt %d/%d con thú đang khát!" % [watered_count, thirsty_indices.size()]
	if watered_count < thirsty_indices.size():
		msg += " (Đã hết nước trong kho)"
	return {
		"success": true,
		"watered_count": watered_count,
		"thirsty_count": thirsty_indices.size(),
		"msg": msg
	}

## Cho ăn / Quất roi chăn gia súc (Tương thích ngược)
func feed_or_care_animal(idx: int) -> Dictionary:
	if idx < 0 or idx >= animals.size():
		return {"success": false, "msg": "Không tìm thấy chuồng!"}
	var a := animals[idx]
	if a.state == AnimalState.READY:
		return {"success": false, "msg": "Gia súc đã lớn, hãy thu hoạch!"}

	# Nếu đang đói hoặc chưa đầy thanh đói -> Ưu tiên cho ăn
	if a.hunger < a.max_hunger or a.state == AnimalState.HUNGRY:
		return feed_animal(idx)

	# Nếu đã no -> Quất roi chăm sóc tăng tốc
	if a.care_count < 3:
		a.care_count += 1
		return {"success": true, "type": "care", "msg": "✨ Dùng Roi Chăn chăm sóc %s (+25%% tốc độ)!" % a.name}
	else:
		return {"success": false, "msg": "%s đã no nê và được chăm sóc tối đa!" % a.name}

## Thu hoạch sản phẩm chăn nuôi (Mất con thú nuôi đó và chuyển thành thịt)
func harvest_animal(idx: int) -> Dictionary:
	if idx < 0 or idx >= animals.size():
		return {"success": false, "msg": "Không tìm thấy thú nuôi!"}
	var a := animals[idx]
	if a.get_progress() < 1.0 and a.state != AnimalState.READY:
		return {"success": false, "msg": "Chưa đến thời điểm thu hoạch!"}

	var meat_count := maxi(1, a.level)
	var final_gold := int(float(a.gold_reward) * (1.0 + a.bonus_gold_rate))
	var final_exp := int(float(a.exp_reward) * (1.0 + a.bonus_exp_rate))

	var res := {
		"success": true,
		"animal_id": a.animal_id,
		"animal_name": a.name,
		"product_name": a.product_name,
		"product_id": a.product_id,
		"gold": final_gold,
		"exp": final_exp,
		"bonus_gold": final_gold - a.gold_reward,
		"meat_count": meat_count
	}

	# Thu hoạch sẽ làm mất con thú đó khỏi chuồng/đàn nuôi (chuyển hóa thành thịt)
	animals.remove_at(idx)

	# Cập nhật lại chỉ số index cho các con vật còn lại
	for i in range(animals.size()):
		animals[i].index = i

	return res

func to_array() -> Array:
	var arr: Array = []
	for a in animals:
		arr.append(a.to_dict())
	return arr

func from_array(arr: Array) -> void:
	if arr.is_empty():
		return
	animals.clear()
	for i in range(arr.size()):
		var d = arr[i]
		if d is Dictionary:
			var a := AnimalInfo.new()
			a.from_dict(d)
			animals.append(a)
