extends RefCounted
class_name PlantData
## Dữ liệu và trạng thái sinh trưởng của 1 giống cây

var id: String = ""
var name: String = ""
var best_season: int = -1
var grow_time_seconds: int = 3600
var seed_price_gold: int = 200
var seed_price_xu: int = 0
var sale_price_gold: int = 400
var exp_reward: int = 50
var stages: int = 3
var chest_drop: String = "chest_moc_tinh"
var icon_path: String = ""
var sprite_growing: String = ""
var sprite_mature: String = ""

static var _catalog: Dictionary = {}

static func _load_catalog() -> void:
	if not _catalog.is_empty():
		return
	var file := FileAccess.open("res://data/son_trang/plants.json", FileAccess.READ)
	if file == null:
		push_warning("PlantData: Không tìm thấy res://data/son_trang/plants.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has("plants"):
		_catalog = parsed["plants"]

static func get_plant(plant_id: String) -> PlantData:
	_load_catalog()
	if not _catalog.has(plant_id):
		return null
	var d: Dictionary = _catalog[plant_id]
	var p := PlantData.new()
	p.id = plant_id
	p.name = str(d.get("name", plant_id))
	p.best_season = int(d.get("best_season", -1))
	p.grow_time_seconds = int(d.get("grow_time_seconds", 3600))
	p.seed_price_gold = int(d.get("seed_price_gold", 0))
	p.seed_price_xu = int(d.get("seed_price_xu", 0))
	p.sale_price_gold = int(d.get("sale_price_gold", 0))
	p.exp_reward = int(d.get("exp_reward", 0))
	p.stages = int(d.get("stages", 3))
	p.chest_drop = str(d.get("chest_drop", "chest_moc_tinh"))
	p.icon_path = str(d.get("icon_path", ""))
	p.sprite_growing = str(d.get("sprite_growing", ""))
	p.sprite_mature = str(d.get("sprite_mature", ""))
	return p

static func get_all_plants() -> Array[PlantData]:
	_load_catalog()
	var res: Array[PlantData] = []
	for pid in _catalog.keys():
		var p := get_plant(pid)
		if p:
			res.append(p)
	return res
