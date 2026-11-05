extends RefCounted
class_name FarmTimeSystem
## Hệ thống tính thời gian & Thời Tiết Sơn Trang:
## - Chu kỳ ngày / đêm theo giờ thực của máy (hoặc server).
## - Chu kỳ 4 mùa theo tháng thực trong năm.
## - Hệ thống Thời Tiết động (Nắng, Mưa, Bão, Sương mù, Tuyết rơi, Gió mát) tác động trực tiếp tới nông nghiệp, chăn nuôi và câu cá.

enum Season {
	SPRING = 0, # Xuân (Tháng 3, 4, 5)
	SUMMER = 1, # Hạ   (Tháng 6, 7, 8)
	AUTUMN = 2, # Thu  (Tháng 9, 10, 11)
	WINTER = 3  # Đông (Tháng 12, 1, 2)
}

enum DayPhase {
	DAY = 0,       # 06:00 - 18:00 (Sáng rực rỡ)
	SUNSET = 1,    # 18:00 - 20:00 (Hoàng hôn)
	NIGHT = 2,     # 20:00 - 05:00 (Đêm tối, chỉ sáng xung quanh nhân vật)
	DAWN = 3       # 05:00 - 06:00 (Bình minh)
}

enum Weather {
	SUNNY = 0,  # Nắng Đẹp (Quang hợp tốt: +15% sản lượng cây trồng)
	RAINY = 1,  # Mưa Rào (Tự động tưới mát luống đất, cá hồ cắn câu +30%)
	STORM = 2,  # Mưa Giông (Sấm chớp, gió lớn, cá biển dạt vào bờ +50%)
	FOGGY = 3,  # Sương Mù (Độ ẩm cao, tăng độ thân mật thú nuôi +25%, cá cắn câu nhanh)
	SNOWY = 4,  # Tuyết Rơi (Giá lạnh, Đống lửa trại x2 EXP sưởi ấm)
	WINDY = 5   # Gió Mát (Khí hậu mát mẻ, giảm tiêu hao thể lực)
}

const SEASON_NAMES := {
	Season.SPRING: "Mùa Xuân (Sinh Trưởng)",
	Season.SUMMER: "Mùa Hạ (Nắng Ấm)",
	Season.AUTUMN: "Mùa Thu (Thu Hoạch)",
	Season.WINTER: "Mùa Đông (Giá Lạnh)"
}

## Trạng thái thời tiết hiện tại trong phiên chơi
static var current_weather: Weather = Weather.SUNNY
static var _weather_initialized: bool = false
static var _last_weather_roll_time: int = 0

## Giai đoạn ngày / đêm tùy chỉnh (-1: tự động theo giờ thực tế)
static var custom_day_phase: int = -1

## Trả về mùa hiện tại dựa theo tháng thực
static func get_current_season() -> Season:
	var dt := Time.get_datetime_dict_from_system()
	var month := int(dt.get("month", 1))
	match month:
		3, 4, 5:
			return Season.SPRING
		6, 7, 8:
			return Season.SUMMER
		9, 10, 11:
			return Season.AUTUMN
		_:
			return Season.WINTER

## Trả về tên hiển thị của mùa hiện tại
static func get_season_name(season: int = -1) -> String:
	var s: Season = (get_current_season() if season < 0 else season) as Season
	return SEASON_NAMES.get(s, "Bốn Mùa")

## Trả về giai đoạn ngày / đêm (ưu tiên pha được chọn thủ công, nếu không thì theo giờ thực)
static func get_current_day_phase() -> DayPhase:
	if custom_day_phase >= 0:
		return custom_day_phase as DayPhase
	var dt := Time.get_datetime_dict_from_system()
	var hour := int(dt.get("hour", 12))
	if hour >= 6 and hour < 18:
		return DayPhase.DAY
	elif hour >= 18 and hour < 20:
		return DayPhase.SUNSET
	elif hour >= 5 and hour < 6:
		return DayPhase.DAWN
	else:
		return DayPhase.NIGHT

## Thiết lập giai đoạn ngày / đêm thủ công (DAY, SUNSET, NIGHT, DAWN)
static func set_day_phase(phase: int) -> void:
	custom_day_phase = phase

## Đặt lại chu kỳ ngày / đêm theo giờ thực tế hệ thống
static func reset_day_phase_to_realtime() -> void:
	custom_day_phase = -1

## Trả về tên tiếng Việt của giai đoạn trong ngày
static func get_day_phase_name(phase: int = -1) -> String:
	var p: DayPhase = (get_current_day_phase() if phase < 0 else phase) as DayPhase
	match p:
		DayPhase.DAY:
			return "☀️ Ban Ngày"
		DayPhase.SUNSET:
			return "🌇 Hoàng Hôn"
		DayPhase.NIGHT:
			return "🌙 Ban Đêm"
		DayPhase.DAWN:
			return "🌅 Bình Minh"
	return "☀️ Ban Ngày"

## Trả về độ tối của bóng đêm tương ứng với giai đoạn
static func get_day_phase_darkness(phase: int = -1) -> float:
	var p: DayPhase = (get_current_day_phase() if phase < 0 else phase) as DayPhase
	match p:
		DayPhase.DAY:
			return 0.0
		DayPhase.SUNSET:
			return 0.42
		DayPhase.NIGHT:
			return 0.86
		DayPhase.DAWN:
			return 0.28
	return 0.0

## Trả về tone màu của bầu trời / màn phủ ban đêm tương ứng
static func get_day_phase_tint(phase: int = -1) -> Color:
	var p: DayPhase = (get_current_day_phase() if phase < 0 else phase) as DayPhase
	match p:
		DayPhase.DAY:
			return Color(0.9, 0.92, 1.0, 1.0)
		DayPhase.SUNSET:
			return Color(0.38, 0.16, 0.08, 1.0) # Sắc hoàng hôn cam trầm ấm
		DayPhase.NIGHT:
			return Color(0.04, 0.06, 0.18, 1.0) # Sắc đêm huyền ảo tím biếc
		DayPhase.DAWN:
			return Color(0.28, 0.20, 0.30, 1.0) # Sắc bình minh tím hồng mờ ảo
	return Color(0.04, 0.06, 0.18, 1.0)

## Kiểm tra có phải ban đêm không
static func is_night() -> bool:
	return get_current_day_phase() == DayPhase.NIGHT

## ======================= HỆ THỐNG THỜI TIẾT =======================

## Khởi tạo hoặc lấy thời tiết hiện tại (tự động luân chuyển hợp lý theo mùa sau mỗi 10 phút)
static func get_current_weather() -> Weather:
	var now := int(Time.get_unix_time_from_system())
	if not _weather_initialized:
		_weather_initialized = true
		_last_weather_roll_time = now
		current_weather = roll_weather_for_season(get_current_season())
	elif now - _last_weather_roll_time > 600: # 10 phút đổi 1 lần
		_last_weather_roll_time = now
		current_weather = roll_weather_for_season(get_current_season())
	return current_weather

## Thiết lập thời tiết thủ công (Dùng cho UI Điều khiển hoặc Sự Kiện Thời Tiết)
static func set_weather(w: Weather) -> void:
	current_weather = w
	_weather_initialized = true
	_last_weather_roll_time = int(Time.get_unix_time_from_system())

## Xúc xắc thời tiết ngẫu nhiên có trọng số phù hợp với từng mùa
static func roll_weather_for_season(season: Season) -> Weather:
	var roll := randf()
	match season:
		Season.SPRING:
			# Xuân: Mưa xuân lất phất, nắng ấm, gió mát
			if roll < 0.40: return Weather.SUNNY
			elif roll < 0.70: return Weather.RAINY
			elif roll < 0.85: return Weather.WINDY
			else: return Weather.FOGGY
		Season.SUMMER:
			# Hạ: Nắng gắt, mưa giông nhiệt đới
			if roll < 0.50: return Weather.SUNNY
			elif roll < 0.75: return Weather.STORM
			elif roll < 0.90: return Weather.RAINY
			else: return Weather.WINDY
		Season.AUTUMN:
			# Thu: Gió heo may, sương thu, nắng vàng
			if roll < 0.35: return Weather.WINDY
			elif roll < 0.65: return Weather.FOGGY
			elif roll < 0.85: return Weather.SUNNY
			else: return Weather.RAINY
		Season.WINTER:
			# Đông: Tuyết trắng buốt giá, sương giá lạnh
			if roll < 0.50: return Weather.SNOWY
			elif roll < 0.75: return Weather.FOGGY
			elif roll < 0.90: return Weather.WINDY
			else: return Weather.SUNNY
	return Weather.SUNNY

## Lấy thông tin chi tiết đầy đủ của thời tiết
static func get_weather_info(w: int = -1) -> Dictionary:
	var target_w: Weather = (get_current_weather() if w < 0 else w) as Weather
	var season := get_current_season()

	# Tính nhiệt độ (°C) và độ ẩm tương đối theo mùa & thời tiết
	var base_temp := 28
	match season:
		Season.SPRING: base_temp = 24
		Season.SUMMER: base_temp = 33
		Season.AUTUMN: base_temp = 21
		Season.WINTER: base_temp = 8

	var temp := base_temp
	var humidity := 65
	var name_str := "Nắng Đẹp"
	var icon_str := "☀️"
	var buff_title := "Quang Hợp Thuận Lợi"
	var buff_desc := "Cây trồng phát triển xanh tốt, tăng +15% sản lượng thu hoạch."
	var auto_water := false
	var crop_bonus := 0.15
	var fish_bonus := 0.0
	var campfire_bonus := 1.0
	var theme_color := Color(1.0, 0.88, 0.3)

	match target_w:
		Weather.SUNNY:
			name_str = "Nắng Đẹp"
			icon_str = "☀️"
			temp = base_temp + 2
			humidity = 55
			buff_title = "Quang Hợp Thuận Lợi"
			buff_desc = "Tia nắng ấm áp giúp cây trồng quang hợp nhanh (+15% sản lượng)."
			auto_water = false
			crop_bonus = 0.15
			fish_bonus = 0.0
			campfire_bonus = 1.0
			theme_color = Color(1.0, 0.85, 0.25)
		Weather.RAINY:
			name_str = "Mưa Rào"
			icon_str = "🌧️"
			temp = base_temp - 3
			humidity = 92
			buff_title = "Đất Mát Nước Dồi Dào"
			buff_desc = "Mưa rào tự động tưới nước toàn bộ đất trồng trọt (+20% tốc độ). Cá hồ cắn câu +30%."
			auto_water = true
			crop_bonus = 0.20
			fish_bonus = 0.30
			campfire_bonus = 1.0
			theme_color = Color(0.4, 0.8, 1.0)
		Weather.STORM:
			name_str = "Mưa Giông Sấm Chớp"
			icon_str = "⛈️"
			temp = base_temp - 5
			humidity = 98
			buff_title = "Sóng Biển Cuộn Trào"
			buff_desc = "Sóng lớn xô cá biển dạt vào gần bờ (+50% tỷ lệ cá hiếm). Tự động tưới nước toàn đảo."
			auto_water = true
			crop_bonus = 0.25
			fish_bonus = 0.50
			campfire_bonus = 1.2
			theme_color = Color(0.7, 0.6, 1.0)
		Weather.FOGGY:
			name_str = "Sương Mù Huyền Bí"
			icon_str = "🌫️"
			temp = base_temp - 2
			humidity = 95
			buff_title = "Khí Trời Ôn Hòa"
			buff_desc = "Sương giăng mờ ảo làm dịu đàn thú (+25% thân mật vuốt ve). Cá cắn câu nhanh x1.5."
			auto_water = false
			crop_bonus = 0.05
			fish_bonus = 0.40
			campfire_bonus = 1.3
			theme_color = Color(0.8, 0.85, 0.95)
		Weather.SNOWY:
			name_str = "Tuyết Rơi Giá Lạnh"
			icon_str = "❄️"
			temp = mini(base_temp - 6, 2)
			humidity = 80
			buff_title = "Lửa Sưởi Ấm Gấp Đôi"
			buff_desc = "Trời lạnh tuyết rơi! Ngồi bên Đống Lửa Sơn Trang nhận x2 EXP tu vi và EXP trang trại."
			auto_water = true
			crop_bonus = -0.10
			fish_bonus = 0.10
			campfire_bonus = 2.0
			theme_color = Color(0.65, 0.92, 1.0)
		Weather.WINDY:
			name_str = "Gió Mát Lành"
			icon_str = "🍃"
			temp = base_temp - 1
			humidity = 60
			buff_title = "Gió Dịu Sảng Khoái"
			buff_desc = "Khí hậu mát mẻ trong lành, đàn thú nuôi di chuyển dạo chơi ngoài trời tung tăng vui vẻ."
			auto_water = false
			crop_bonus = 0.10
			fish_bonus = 0.15
			campfire_bonus = 1.0
			theme_color = Color(0.4, 0.95, 0.6)

	return {
		"id": int(target_w),
		"name": name_str,
		"icon": icon_str,
		"temp": temp,
		"humidity": humidity,
		"buff_title": buff_title,
		"buff_desc": buff_desc,
		"auto_water": auto_water,
		"crop_bonus": crop_bonus,
		"fish_bonus": fish_bonus,
		"campfire_bonus": campfire_bonus,
		"theme_color": theme_color
	}

## Lấy danh sách toàn bộ 6 kiểu thời tiết để hiển thị trong UI
static func get_all_weathers() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for w in [Weather.SUNNY, Weather.RAINY, Weather.STORM, Weather.FOGGY, Weather.SNOWY, Weather.WINDY]:
		list.append(get_weather_info(w))
	return list

## ======================= HỆ SỐ SINH TRƯỞNG =======================

## Hệ số tăng tốc độ sinh trưởng nếu cây được trồng đúng mùa
## +50% nếu đúng mùa, -40% nếu trái mùa (trừ khi cây thích hợp mọi mùa best_season = -1)
static func get_growth_rate_multiplier(plant_best_season: int, current_season: int = -1) -> float:
	if plant_best_season < 0:
		return 1.0 # Cây 4 mùa (như Dược Thảo)
	var cur := get_current_season() if current_season < 0 else (current_season as Season)
	if plant_best_season == cur:
		return 1.5 # +50% tốc độ
	else:
		return 0.6 # -40% tốc độ
