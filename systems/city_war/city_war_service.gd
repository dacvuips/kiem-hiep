extends RefCounted
class_name CityWarService
## Dịch vụ quản lý dữ liệu, giải đấu Lôi Đài Oản Tù Xì và Công Thành Chiến

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(CityWarRules.SAVE_PATH):
		return _init_default_data()
	var file := FileAccess.open(CityWarRules.SAVE_PATH, FileAccess.READ)
	if not file:
		return _init_default_data()
	var text := file.get_as_text()
	var json = JSON.parse_string(text)
	if json is Dictionary:
		return json
	return _init_default_data()

static func save_data(data: Dictionary) -> void:
	var file := FileAccess.open(CityWarRules.SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

static func _init_default_data() -> Dictionary:
	var cities_dict: Dictionary = {}
	for c in CityWarRules.CITIES:
		cities_dict[c["id"]] = {
			"owner_guild": c["default_owner"],
			"master_name": c["default_master"],
			"tax_rate": c["tax_rate"],
			"fund_treasury": 5000000
		}
	
	var data := {
		"cities": cities_dict,
		"tournament": {
			"city_id": "bien_kinh",
			"phase": "idle", ## idle, preparing_1h, rps_choosing_30m, finished_rps, battle_ready
			"notify_timestamp": 0,
			"rps_deadline_timestamp": 0,
			"challenger_guilds": ["Hắc Hổ Bang", "Ngũ Nhạc Minh", "Cái Thế Phái"],
			"brackets": [],
			"my_roster": [], ## 20 tên thành viên
			"my_choices": {}, ## { "0": choice_int, ... }
			"opponent_choices": {}, ## { "0": choice_int, ... }
			"rps_revealed": false,
			"winner_guild": ""
		}
	}
	save_data(data)
	return data

## Lấy thông tin 1 thành phố
static func get_city_info(city_id: String) -> Dictionary:
	var data := load_data()
	var cities: Dictionary = data.get("cities", {})
	var cdef := CityWarRules.get_city_def(city_id)
	var cstate: Dictionary = cities.get(city_id, {})
	var res := cdef.duplicate()
	res["owner_guild"] = cstate.get("owner_guild", cdef["default_owner"])
	res["master_name"] = cstate.get("master_name", cdef["default_master"])
	res["tax_rate"] = cstate.get("tax_rate", cdef["tax_rate"])
	res["fund_treasury"] = cstate.get("fund_treasury", 5000000)
	return res

## Đăng ký / Bắt đầu giải đấu cho 1 thành thị
static func start_tournament_for_city(city_id: String, my_guild_name: String) -> Dictionary:
	var data := load_data()
	var tour: Dictionary = data.get("tournament", {})
	tour["city_id"] = city_id
	tour["phase"] = "preparing_1h"
	tour["notify_timestamp"] = int(Time.get_unix_time_from_system())
	tour["rps_deadline_timestamp"] = tour["notify_timestamp"] + int(CityWarRules.NOTIFY_LEADER_TIME_SEC) + int(CityWarRules.RPS_CHOOSE_TIME_SEC)
	
	# Danh sách các bang tham gia tranh đoạt
	var challengers: Array = ["Hắc Hổ Bang", "Ngũ Nhạc Minh", "Cái Thế Phái"]
	if my_guild_name != "" and not challengers.has(my_guild_name):
		challengers.insert(0, my_guild_name)
	tour["challenger_guilds"] = challengers
	tour["my_roster"] = []
	tour["my_choices"] = {}
	tour["opponent_choices"] = {}
	tour["rps_revealed"] = false
	tour["winner_guild"] = ""
	
	data["tournament"] = tour
	save_data(data)
	return data

## Khởi tạo hoặc cập nhật đội hình 20 người
static func save_my_roster(roster: Array) -> void:
	var data := load_data()
	var tour: Dictionary = data.get("tournament", {})
	tour["my_roster"] = roster
	data["tournament"] = tour
	save_data(data)

## Bắt đầu giai đoạn 30 phút Oản Tù Xì
static func advance_to_rps_phase() -> Dictionary:
	var data := load_data()
	var tour: Dictionary = data.get("tournament", {})
	tour["phase"] = "rps_choosing_30m"
	tour["rps_deadline_timestamp"] = int(Time.get_unix_time_from_system()) + int(CityWarRules.RPS_CHOOSE_TIME_SEC)
	
	# Tạo sẵn lựa chọn ngẫu nhiên cho bang đối thủ (được giấu kín)
	var opp_choices: Dictionary = {}
	for i in range(CityWarRules.ROSTER_SIZE):
		opp_choices[str(i)] = randi_range(1, 3)
	tour["opponent_choices"] = opp_choices
	tour["rps_revealed"] = false
	
	data["tournament"] = tour
	save_data(data)
	return data

## Lưu lựa chọn Kéo/Búa/Bao của 1 thành viên (Không được đổi sau khi confirm)
static func record_member_choice(slot_idx: int, choice: int) -> bool:
	var data := load_data()
	var tour: Dictionary = data.get("tournament", {})
	var choices: Dictionary = tour.get("my_choices", {})
	var k := str(slot_idx)
	if choices.has(k) and int(choices[k]) != CityWarRules.RPSChoice.NONE:
		return false ## Đã chốt, không được sửa
	choices[k] = choice
	tour["my_choices"] = choices
	data["tournament"] = tour
	save_data(data)
	return true

## Hết giờ 30 phút hoặc Bang chủ mở bát công khai (Minh bạch 2 bên)
static func reveal_rps_results() -> Dictionary:
	var data := load_data()
	var tour: Dictionary = data.get("tournament", {})
	tour["phase"] = "finished_rps"
	tour["rps_revealed"] = true
	
	var my_choices: Dictionary = tour.get("my_choices", {})
	var opp_choices: Dictionary = tour.get("opponent_choices", {})
	
	var my_wins: int = 0
	var opp_wins: int = 0
	
	for i in range(CityWarRules.ROSTER_SIZE):
		var k := str(i)
		var c_my: int = int(my_choices.get(k, CityWarRules.RPSChoice.NONE))
		var c_opp: int = int(opp_choices.get(k, CityWarRules.RPSChoice.NONE))
		var res := CityWarRules.compare_rps(c_my, c_opp)
		if res > 0:
			my_wins += 1
		elif res < 0:
			opp_wins += 1
			
	var challengers: Array = tour.get("challenger_guilds", ["Bang Hội"])
	var my_guild: String = challengers[0] if challengers.size() > 0 else "Quý Bang"
	var opp_guild: String = challengers[1] if challengers.size() > 1 else "Bang Đối Thủ"
	
	if my_wins >= opp_wins:
		tour["winner_guild"] = my_guild
	else:
		tour["winner_guild"] = opp_guild
		
	data["tournament"] = tour
	save_data(data)
	return {
		"my_wins": my_wins,
		"opp_wins": opp_wins,
		"winner": tour["winner_guild"]
	}

## Cập nhật Thành Chủ sau trận chiến
static func set_city_owner(city_id: String, guild_name: String, master_name: String) -> void:
	var data := load_data()
	var cities: Dictionary = data.get("cities", {})
	var cstate: Dictionary = cities.get(city_id, {})
	cstate["owner_guild"] = guild_name
	cstate["master_name"] = master_name
	cities[city_id] = cstate
	data["cities"] = cities
	save_data(data)
