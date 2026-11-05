extends Node
## Autoload: FarmManager (Sơn Trang Quản Gia)
## Quản lý toàn bộ dữ liệu nông trại, kho chứa, cấp độ Sơn Trang, đống lửa, ngày/đêm và lưu/load.

signal farm_data_changed()
signal farm_level_up(new_level: int)
signal campfire_updated(fuel_ratio: float)

const SAVE_PATH := "user://farm_data.json"

var farm_level: int = 1
var farm_exp: int = 0
var campfire_fuel: float = 0.5 # 0.0 -> 1.0 (50% lúc bắt đầu)
var campfire_timer: float = 0.0

# 2 Rương: Nông sản (30 ô) & Vật tư / Công cụ (20 ô)
var farm_chest_produce: Dictionary = {} # item_id -> count
var farm_chest_supplies: Dictionary = {} # item_id -> count

## Ngân lượng đồng bộ với PlayerProfile
var currency_gold: int:
	get:
		return get_player_gold()
	set(val):
		set_player_gold(val)

func get_player_gold() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var gm = tree.root.get_node_or_null("GameManager") if (tree and tree.root) else null
	if gm != null:
		if "local_profile" in gm and gm.local_profile != null:
			return int(gm.local_profile.gold)
		if "profile" in gm and gm.profile != null:
			return int(gm.profile.gold)
	return 0

func set_player_gold(val: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gm = tree.root.get_node_or_null("GameManager") if (tree and tree.root) else null
	if gm != null:
		if "local_profile" in gm and gm.local_profile != null:
			gm.local_profile.gold = val
		elif "profile" in gm and gm.profile != null:
			gm.profile.gold = val

# Các công cụ người chơi đang sở hữu trong Sơn Trang
# [hoe: bool, watering_can: bool, whip: bool, fishing_rod_bamboo: bool]
var owned_tools: Dictionary = {
	"hoe": false,              # Cần có Cuốc Thép (mua tại Điền Chủ hoặc mua nhanh trong bảng luống)
	"watering_can": true,      # Bình tưới khởi nghiệp
	"whip": false,
	"fishing_rod_bamboo": false
}

var plot_mgr: PlotManager = null
var livestock_mgr: LivestockManager = null

## Thú cưng đồng hành theo sau nhân vật khi di chuyển ở ngoài bản đồ
var active_companion: Dictionary = {}

func set_active_companion(companion: Dictionary) -> void:
	active_companion = companion.duplicate()
	save_farm_data()
	farm_data_changed.emit()

func clear_active_companion() -> void:
	active_companion = {}
	save_farm_data()
	farm_data_changed.emit()

func _ready() -> void:
	plot_mgr = PlotManager.new()
	livestock_mgr = LivestockManager.new()
	load_farm_data()
	ensure_starter_supplies()

func ensure_starter_supplies() -> void:
	var modified := false
	if int(farm_chest_supplies.get("fresh_water_pot", 0)) <= 0 and int(farm_chest_supplies.get("water", 0)) <= 0:
		farm_chest_supplies["fresh_water_pot"] = 25
		modified = true
	if int(farm_chest_supplies.get("fertilizer", 0)) <= 0:
		farm_chest_supplies["fertilizer"] = 15
		modified = true
	if get_feed_count() <= 0:
		farm_chest_produce["lua_vang"] = 15
		farm_chest_produce["fish_fresh"] = 10
		modified = true
	if int(farm_chest_supplies.get("seed_rice", 0)) <= 0:
		farm_chest_supplies["seed_rice"] = 8
		modified = true
	if int(farm_chest_supplies.get("fingerling_carp", 0)) <= 0:
		farm_chest_supplies["fingerling_carp"] = 5
		modified = true
	if modified:
		save_farm_data()

## Lấy tổng số lượng nước (thùng nước suối / nước) trong rương vật tư
func get_water_count() -> int:
	return int(farm_chest_supplies.get("fresh_water_pot", 0)) + int(farm_chest_supplies.get("water", 0))

## Sử dụng nước từ rương
func use_water(count: int = 1) -> bool:
	if int(farm_chest_supplies.get("fresh_water_pot", 0)) >= count:
		return remove_from_chest("fresh_water_pot", count, true)
	elif int(farm_chest_supplies.get("water", 0)) >= count:
		return remove_from_chest("water", count, true)
	return false

## Lấy số lượng phân bón vi sinh trong rương vật tư
func get_fertilizer_count() -> int:
	return int(farm_chest_supplies.get("fertilizer", 0))

## Sử dụng phân bón từ rương
func use_fertilizer(count: int = 1) -> bool:
	return remove_from_chest("fertilizer", count, true)

## Lấy số lượng Cuốc Thép trong rương vật tư
func get_tool_hoe_count() -> int:
	var cnt: int = int(farm_chest_supplies.get("tool_hoe", 0))
	if cnt <= 0:
		cnt = int(farm_chest_supplies.get("hoe", 0))
	return cnt

## Tiêu hao Cuốc Thép khi nâng cấp luống đất
func use_tool_hoe(count: int = 1) -> bool:
	if int(farm_chest_supplies.get("tool_hoe", 0)) >= count:
		return remove_from_chest("tool_hoe", count, true)
	elif int(farm_chest_supplies.get("hoe", 0)) >= count:
		return remove_from_chest("hoe", count, true)
	return false

## Danh sách các loại nông sản và cá thú nuôi có thể ăn (được trồng hoặc câu/nuôi cá thu hoạch)
const VALID_PET_FEEDS := [
	"lua_vang", "tao_do", "hoa_cuc", "tra_xanh", "duoc_thao", "linh_chi", "nhan_sam", "mai_hoa",
	"fish_fresh", "fish_ocean", "caoyu", "bianyu"
]

## Lấy tổng số lượng thức ăn (nông sản trồng trọt & cá đánh bắt/nuôi) trong rương
func get_feed_count() -> int:
	var total := 0
	for k in VALID_PET_FEEDS:
		total += int(farm_chest_produce.get(k, 0)) + int(farm_chest_supplies.get(k, 0))
	return total

## Tìm một loại thức ăn có sẵn trong rương để cho thú ăn
func use_any_feed(consume: bool = false) -> String:
	for k in VALID_PET_FEEDS:
		if int(farm_chest_produce.get(k, 0)) > 0:
			if consume:
				remove_from_chest(k, 1, false)
			return k
		if int(farm_chest_supplies.get(k, 0)) > 0:
			if consume:
				remove_from_chest(k, 1, true)
			return k
	return ""

func _process(delta: float) -> void:
	# Cập nhật đàn gia súc (tiêu hao đói & thời gian thu hoạch)
	if livestock_mgr != null:
		livestock_mgr.tick(delta)

	# Cập nhật đống lửa
	if campfire_fuel > 0.0:
		campfire_fuel = maxf(0.0, campfire_fuel - (delta / 1200.0)) # 20 phút cháy hết 1 thanh củi
		campfire_timer += delta
		# Cứ mỗi 1 giây ở gần đống lửa trong Sơn Trang -> sinh 2000 exp
		if campfire_timer >= 1.0:
			campfire_timer = 0.0
			_tick_campfire_reward()
			campfire_updated.emit(campfire_fuel)

func _tick_campfire_reward() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gm = tree.root.get_node_or_null("GameManager") if (tree and tree.root) else null
	if gm != null and "local_profile" in gm and gm.local_profile != null:
		# Nhận EXP nhân vật: 2000 exp mỗi 1s (theo thời tiết x2 khi có tuyết rơi)
		var mult := 1.0
		var w_info := FarmTimeSystem.get_weather_info()
		if w_info.has("campfire_bonus"):
			mult = float(w_info["campfire_bonus"])
		gm.local_profile.add_exp(int(2000 * mult))
		add_farm_exp(20)

func add_farm_exp(amount: int) -> void:
	if amount <= 0:
		return
	farm_exp += amount
	var needed := get_exp_needed_for_level(farm_level)
	while farm_exp >= needed and farm_level < 50:
		farm_exp -= needed
		farm_level += 1
		farm_level_up.emit(farm_level)
		needed = get_exp_needed_for_level(farm_level)
	farm_data_changed.emit()

func get_exp_needed_for_level(lvl: int) -> int:
	return lvl * 100 + (lvl * lvl * 10)

## Thêm củi vào đống lửa
func feed_campfire(amount: float = 0.3) -> void:
	campfire_fuel = clampf(campfire_fuel + amount, 0.0, 1.0)
	campfire_updated.emit(campfire_fuel)
	farm_data_changed.emit()

## Thêm vật phẩm vào rương nông sản hoặc vật tư
func add_to_chest(item_id: String, count: int = 1, is_supply: bool = false) -> void:
	var target_chest := farm_chest_supplies if is_supply else farm_chest_produce
	target_chest[item_id] = int(target_chest.get(item_id, 0)) + count
	farm_data_changed.emit()

func remove_from_chest(item_id: String, count: int = 1, is_supply: bool = false) -> bool:
	var target_chest := farm_chest_supplies if is_supply else farm_chest_produce
	var cur := int(target_chest.get(item_id, 0))
	if cur < count:
		return false
	target_chest[item_id] = cur - count
	if target_chest[item_id] <= 0:
		target_chest.erase(item_id)
	farm_data_changed.emit()
	return true

## Mua công cụ hoặc hạt giống bằng tiền xu/lượng của nhân vật
func buy_item_with_currency(price_gold: int, price_xu: int) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var gm = tree.root.get_node_or_null("GameManager") if (tree and tree.root) else null
	var profile: PlayerProfile = gm.local_profile if (gm and "local_profile" in gm) else null
	if profile == null:
		return false
	if price_gold > 0 and profile.gold < price_gold:
		return false
	if price_xu > 0 and profile.xu < price_xu:
		return false

	if price_gold > 0:
		profile.gold -= price_gold
	if price_xu > 0:
		profile.xu -= price_xu
	return true

## Bán sản phẩm lấy tiền vàng
func earn_gold(amount: int) -> void:
	if amount <= 0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var gm = tree.root.get_node_or_null("GameManager") if (tree and tree.root) else null
	var profile: PlayerProfile = gm.local_profile if (gm and "local_profile" in gm) else null
	if profile:
		profile.gold = mini(PlayerProfile.MAX_GOLD, profile.gold + amount)

# ======================= SAVE / LOAD =======================

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"farm_level": farm_level,
		"farm_exp": farm_exp,
		"campfire_fuel": campfire_fuel,
		"plots": plot_mgr.to_array() if plot_mgr else [],
		"livestock": livestock_mgr.to_array() if livestock_mgr else [],
		"chest_produce": farm_chest_produce,
		"chest_supplies": farm_chest_supplies,
		"owned_tools": owned_tools,
		"active_companion": active_companion,
		"saved_time": int(Time.get_unix_time_from_system())
	}

func from_dict(d: Dictionary) -> void:
	farm_level = int(d.get("farm_level", 1))
	farm_exp = int(d.get("farm_exp", 0))
	campfire_fuel = float(d.get("campfire_fuel", 0.5))
	if plot_mgr:
		plot_mgr.from_array(d.get("plots", []))
	if livestock_mgr:
		livestock_mgr.from_array(d.get("livestock", []))
	farm_chest_produce = d.get("chest_produce", {})
	farm_chest_supplies = d.get("chest_supplies", {})
	active_companion = d.get("active_companion", {})
	var tools = d.get("owned_tools", {})
	if tools is Dictionary:
		for k in tools.keys():
			owned_tools[k] = bool(tools[k])

func save_farm_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()

func load_farm_data() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		from_dict(parsed)
		return true
	return false
