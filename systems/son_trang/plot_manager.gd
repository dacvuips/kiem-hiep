extends RefCounted
class_name PlotManager
## Quản lý 6 Luống Đất Trồng Trọt (đánh thứ tự nhỏ tới cao) trên Nguyệt Ca Đảo.
## Mỗi luống có 5 Cấp Độ sinh trưởng & nâng cấp (Cấp 1 -> Cấp 5).

enum PlotState {
	UNTILLED = 0,   # Đất cỏ/chưa cày (cần Cuốc)
	TILLED = 1,     # Đất đã cày (sẵn sàng gieo hạt)
	PLANTED = 2,    # Đang sinh trưởng
	HARVESTABLE = 3 # Đã chín, sẵn sàng thu hoạch
}

class PlotInfo:
	var index: int = 0
	var is_unlocked: bool = false   # Đã khai hoang chưa (Luống 1 mở sẵn, các luống sau cần mua)
	var level: int = 1              # Cấp độ luống (1..5)
	var state: PlotState = PlotState.TILLED
	var plant_id: String = ""
	var planted_at: int = 0         # Unix timestamp khi gieo
	var watered_count: int = 0      # Số lần tưới (tối đa 3 lần/chu kỳ)
	var is_fertilized: bool = false # Đã bón phân chưa (+30% speed)
	var plant_best_season: int = -1
	var total_grow_time: int = 3600

	func to_dict() -> Dictionary:
		return {
			"index": index,
			"is_unlocked": is_unlocked,
			"level": level,
			"state": int(state),
			"plant_id": plant_id,
			"planted_at": planted_at,
			"watered_count": watered_count,
			"is_fertilized": is_fertilized,
			"plant_best_season": plant_best_season,
			"total_grow_time": total_grow_time
		}

	func from_dict(d: Dictionary) -> void:
		index = int(d.get("index", 0))
		is_unlocked = bool(d.get("is_unlocked", index == 0))
		level = clampi(int(d.get("level", 1)), 1, 5)
		state = int(d.get("state", PlotState.TILLED)) as PlotState
		plant_id = str(d.get("plant_id", ""))
		planted_at = int(d.get("planted_at", 0))
		watered_count = int(d.get("watered_count", 0))
		is_fertilized = bool(d.get("is_fertilized", false))
		plant_best_season = int(d.get("plant_best_season", -1))
		total_grow_time = int(d.get("total_grow_time", 3600))

	## Tốc độ sinh trưởng của luống cây (Mùa vụ + Thời tiết + Nước tưới + Phân bón + Cấp độ luống)
	func get_growth_rate() -> float:
		var rate := FarmTimeSystem.get_growth_rate_multiplier(plant_best_season)
		var w_info := FarmTimeSystem.get_weather_info()
		if w_info.get("auto_water", false):
			rate += 0.40
		else:
			rate += float(watered_count) * 0.20
		rate += float(w_info.get("crop_bonus", 0.0))
		if is_fertilized:
			rate += 0.30
		rate *= (1.0 + float(level - 1) * 0.15)
		return maxf(rate, 0.2)

	## Tính tiến độ hoàn thành từ 0.0 đến 1.0 (có tính cấp độ luống 1..5)
	func get_progress() -> float:
		if state != PlotState.PLANTED and state != PlotState.HARVESTABLE:
			return 0.0
		if state == PlotState.HARVESTABLE:
			return 1.0

		var now := int(Time.get_unix_time_from_system())
		var elapsed := float(now - planted_at)
		if elapsed <= 0.0:
			return 0.0

		var rate := get_growth_rate()
		var effective_time := float(total_grow_time) / rate
		var prog := elapsed / effective_time
		if prog >= 1.0:
			state = PlotState.HARVESTABLE
			return 1.0
		return clampf(prog, 0.0, 1.0)

	## Thời gian còn lại tính bằng giây cho tới lúc cây chín sẵn sàng thu hoạch
	func get_remaining_time() -> float:
		if state == PlotState.HARVESTABLE:
			return 0.0
		if state != PlotState.PLANTED or total_grow_time <= 0:
			return 0.0

		var now := int(Time.get_unix_time_from_system())
		var elapsed := float(now - planted_at)
		if elapsed < 0.0:
			elapsed = 0.0

		var rate := get_growth_rate()
		var effective_total_time := float(total_grow_time) / rate
		var remaining := effective_total_time - elapsed
		return maxf(0.0, remaining)

	## Giai đoạn hiển thị cây (1 -> max_stages)
	func get_current_stage(max_stages: int) -> int:
		var prog := get_progress()
		if prog >= 1.0:
			return max_stages
		return maxi(1, int(prog * max_stages) + 1)

const MAX_PLOTS := 34 # 34 Luống Đất: 21 ô Khu Đông + 11 ô Khu Tây + 2 ô Khu Bắc (đã bỏ Luống 33 bị chồng)
var plots: Array[PlotInfo] = []

func _init() -> void:
	plots.clear()
	# Khởi tạo 34 luống đất (Luống 1 -> 34)
	# Luống 1 mở sẵn (Đất Cấp 1), các luống 2..34 chưa kích hoạt (border đứt khúc)
	for i in range(MAX_PLOTS):
		var p := PlotInfo.new()
		p.index = i
		p.is_unlocked = (i == 0) # Luống 1 mở sẵn, các luống sau chưa kích hoạt (border đứt khúc)
		p.level = 1
		p.state = PlotState.TILLED
		plots.append(p)

## Giá mở khóa luống đất (100, 200, 300, 400, 500 Lượng)
func get_unlock_cost(index: int) -> int:
	if index <= 0:
		return 0
	return index * 100

## Mua đất mới -> kích hoạt luống đất cấp 1
func unlock_plot(index: int) -> Dictionary:
	if index < 0 or index >= plots.size():
		return {"success": false, "msg": "Không tìm thấy luống!"}
	var p := plots[index]
	if p.is_unlocked:
		return {"success": false, "msg": "Luống %d đã được khai hoang rồi!" % (index + 1)}
	
	var cost := get_unlock_cost(index)
	p.is_unlocked = true
	p.level = 1
	p.state = PlotState.TILLED
	return {
		"success": true,
		"cost": cost,
		"msg": "🎉 Đã khai hoang thành công Luống Đất %d (Đất Cấp 1)!" % (index + 1)
	}

## Nâng cấp cấp độ luống (Cấp 1 -> Cấp 5)
func upgrade_plot(index: int) -> Dictionary:
	if index < 0 or index >= plots.size():
		return {"success": false, "msg": "Không tìm thấy luống!"}
	var p := plots[index]
	if p.level >= 5:
		return {"success": false, "msg": "Luống %d đã đạt Cấp 5 tối đa (Thần Nông Nở Hoa)!" % (index + 1)}
	
	var cost := p.level * 100 # 100, 200, 300, 400 Lượng vàng
	p.level += 1
	return {
		"success": true,
		"new_level": p.level,
		"cost": cost,
		"msg": "✨ Luống %d đã nâng cấp thành công lên Cấp %d!" % [index + 1, p.level]
	}

## Dùng cuốc xới ô đất
func till_plot(index: int) -> bool:
	if index < 0 or index >= plots.size():
		return false
	var p := plots[index]
	if p.state == PlotState.UNTILLED:
		p.state = PlotState.TILLED
		return true
	return false

## Gieo hạt giống vào ô đất đã cày
func plant_seed(index: int, plant_id: String) -> bool:
	if index < 0 or index >= plots.size():
		return false
	var p := plots[index]
	if p.state != PlotState.TILLED:
		return false

	var plant := PlantData.get_plant(plant_id)
	if plant == null:
		return false

	p.state = PlotState.PLANTED
	p.plant_id = plant.id
	p.planted_at = int(Time.get_unix_time_from_system())
	p.watered_count = 0
	p.is_fertilized = false
	p.plant_best_season = plant.best_season
	p.total_grow_time = plant.grow_time_seconds
	return true

## Tưới nước cho ô cây
func water_plot(index: int) -> bool:
	if index < 0 or index >= plots.size():
		return false
	var p := plots[index]
	if p.state == PlotState.PLANTED and p.watered_count < 3:
		p.watered_count += 1
		return true
	return false

## Bón phân
func fertilize_plot(index: int) -> bool:
	if index < 0 or index >= plots.size():
		return false
	var p := plots[index]
	if p.state == PlotState.PLANTED and not p.is_fertilized:
		p.is_fertilized = true
		return true
	return false

## Thu hoạch cây đã chín
## Trả về Dictionary kết quả { "success": bool, "plant": PlantData, "gold": int, "exp": int, "chest": String }
func harvest_plot(index: int) -> Dictionary:
	if index < 0 or index >= plots.size():
		return {"success": false}
	var p := plots[index]
	if p.state != PlotState.HARVESTABLE:
		return {"success": false}

	var plant := PlantData.get_plant(p.plant_id)
	var base_gold: int = plant.sale_price_gold if plant else 100
	var base_exp: int = plant.exp_reward if plant else 50

	# Cấp độ luống cao cho thêm tiền thưởng
	if p.level >= 4:
		base_gold = int(base_gold * (1.0 + float(p.level - 3) * 0.25))

	var res := {
		"success": true,
		"plant_id": p.plant_id,
		"plant_name": plant.name if plant else "Nông Sản",
		"gold": base_gold,
		"exp": base_exp,
		"chest": plant.chest_drop if plant else "chest_moc_tinh"
	}

	# Sau thu hoạch -> luống đất trở về TILLED để trồng tiếp
	p.state = PlotState.TILLED
	p.plant_id = ""
	p.planted_at = 0
	p.watered_count = 0
	p.is_fertilized = false
	p.total_grow_time = 3600
	return res

func to_array() -> Array:
	var arr: Array = []
	for p in plots:
		arr.append(p.to_dict())
	return arr

func from_array(arr: Array) -> void:
	plots.clear()
	for i in range(MAX_PLOTS):
		var p := PlotInfo.new()
		p.index = i
		if i < arr.size() and (arr[i] is Dictionary):
			p.from_dict(arr[i])
		else:
			p.is_unlocked = (i == 0)
			p.level = 1
			p.state = PlotState.TILLED
		plots.append(p)

