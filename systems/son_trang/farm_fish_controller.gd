extends Node2D
class_name FarmFishController
## Quản lý trực quan 2 Khu Nuôi Trồng Thủy Hải Sản trên Nguyệt Ca Đảo:
## 1. Ao Nuôi Cá Nước Ngọt: Tọa độ 181/185 (Gần NPC Khê Hồ Ngư Nương)
## 2. Bè Nuôi Cá Biển Sâu: Tọa độ 188/202 (Khu vực biển Tây Nam, gần bờ biển bãi chăn thả Sơn Trang)
## - Bè cá biển được thiết kế VÙNG HÌNH VUÔNG nổi trên mặt biển với khung bè gỗ và phao liên kết
## - Cho phép người chơi Thả giống, Cho ăn, Bơm oxy/thay nước, Bón khoáng, Nâng cấp ao (Cấp 1 -> 5), Kéo lưới thu hoạch

const COORD_UNIT: float = 256.0

var farm_mgr: FarmManager = null

const FISH_ZONES := [
	{
		"id": "freshwater_pond",
		"name": "Ao Cá Nước Ngọt",
		"coord_name": "181/185",
		"chain_str": "180/185 → 181/184 → 182/184 → 182/186 → 181/186",
		"world_pos": Vector2(46566.0, 47511.0),
		"radius": 175.0,
		"type": "freshwater",
		"color": Color(0.18, 0.55, 0.88, 0.28),
		"border_color": Color(0.38, 0.78, 0.95, 0.95),
		"shadow_color": Color(0.10, 0.18, 0.28, 0.85),
		"post_color": Color(0.55, 0.38, 0.20, 1.0),
		"post_cap_color": Color(0.40, 0.88, 1.0, 1.0),
		"sub_post_color": Color(0.60, 0.44, 0.26, 0.95),
		"polygon": [
			Vector2(-155.6, -74.1), Vector2(-126.8, -84.9), Vector2(-88.7, -95.0), Vector2(-45.5, -99.3),
			Vector2(-2.3, -105.0), Vector2(33.6, -107.9), Vector2(66.0, -100.7), Vector2(102.0, -93.5),
			Vector2(120.0, -76.2), Vector2(127.9, -50.3), Vector2(141.6, -27.3), Vector2(163.2, -9.3),
			Vector2(169.6, 15.9), Vector2(158.1, 41.0), Vector2(134.4, 66.2), Vector2(109.2, 87.8),
			Vector2(69.6, 105.8), Vector2(22.8, 113.0), Vector2(-23.9, 116.6), Vector2(-70.7, 113.0),
			Vector2(-110.3, 105.8), Vector2(-139.1, 91.4), Vector2(-158.5, 69.8), Vector2(-162.8, 37.4),
			Vector2(-162.8, -5.7), Vector2(-160.6, -41.7)
		],
		"landmark_indices": [24, 2, 7, 15, 18],
		"landmark_coords": [
			Vector2i(180, 185), # Tây (gần Khê Hồ Ngư Nương 180/185)
			Vector2i(181, 184), # Tây Bắc
			Vector2i(182, 184), # Đông Bắc
			Vector2i(182, 186), # Đông Nam
			Vector2i(181, 186)  # Nam
		]
	},
	{
		"id": "ocean_cage",
		"name": "Bè Nuôi Cá Biển Sâu",
		"coord_name": "188/202",
		"chain_str": "187/201 → 189/201 → 189/203 → 187/203",
		"world_pos": Vector2(48256.0, 51840.0),
		"radius": 110.0,
		"type": "ocean",
		"color": Color(0.10, 0.45, 0.85, 0.38),
		"border_color": Color(0.98, 0.80, 0.30, 0.98),
		"shadow_color": Color(0.06, 0.16, 0.32, 0.88),
		"post_color": Color(0.85, 0.48, 0.18, 1.0),
		"post_cap_color": Color(1.0, 0.95, 0.50, 1.0),
		"sub_post_color": Color(1.0, 0.70, 0.25, 0.95),
		"polygon": [
			Vector2(-105.0, -105.0), # Tây Bắc
			Vector2(105.0, -105.0),  # Đông Bắc
			Vector2(105.0, 105.0),   # Đông Nam
			Vector2(-105.0, 105.0)   # Tây Nam
		],
		"landmark_indices": [0, 1, 2, 3],
		"landmark_coords": [
			Vector2i(187, 201), # Tây Bắc
			Vector2i(189, 201), # Đông Bắc
			Vector2i(189, 203), # Đông Nam
			Vector2i(187, 203)  # Tây Nam
		]
	}
]

# Trạng thái 2 ao nuôi cá (lưu cấp độ 1..5, cá đang nuôi, tiến độ, oxy, khoáng)
var fish_data: Array[Dictionary] = [
	{
		"level": 1,
		"fish_id": "freshwater_carp",
		"fish_name": "Cá Chép Vàng",
		"state": "GROWING", # HUNGRY, GROWING, READY
		"started_at": 0,
		"total_time": 120,
		"oxy_count": 0,
		"mineral": false
	},
	{
		"level": 1,
		"fish_id": "ocean_salmon",
		"fish_name": "Cá Hồi Đại Dương",
		"state": "GROWING",
		"started_at": 0,
		"total_time": 180,
		"oxy_count": 0,
		"mineral": false
	}
]

var cached_polygons: Array[PackedVector2Array] = []
var cached_triangles: Array[Array] = []
var _hovered_zone_idx: int = -1

func _init() -> void:
	_init_cached_geometry()

func _ready() -> void:
	z_index = -4
	add_to_group("farm_fish_controller")
	farm_mgr = get_node_or_null("/root/FarmManager")
	_init_cached_geometry()
	var now := int(Time.get_unix_time_from_system())
	if fish_data[0]["started_at"] == 0:
		fish_data[0]["started_at"] = now - 40
	if fish_data[1]["started_at"] == 0:
		fish_data[1]["started_at"] = now - 60

func _init_cached_geometry() -> void:
	cached_polygons.clear()
	cached_triangles.clear()
	for i in range(FISH_ZONES.size()):
		var zone: Dictionary = FISH_ZONES[i]
		if zone.has("polygon"):
			var p_arr := PackedVector2Array()
			for pt in zone["polygon"]:
				p_arr.append(pt)
			if not Geometry2D.is_polygon_clockwise(p_arr):
				p_arr.reverse()
			cached_polygons.append(p_arr)
			var indices := Geometry2D.triangulate_polygon(p_arr)
			var tris: Array[PackedVector2Array] = []
			for idx in range(0, indices.size(), 3):
				tris.append(PackedVector2Array([
					p_arr[indices[idx]],
					p_arr[indices[idx+1]],
					p_arr[indices[idx+2]]
				]))
			cached_triangles.append(tris)
		else:
			cached_polygons.append(PackedVector2Array())
			cached_triangles.append([])

func _process(_delta: float) -> void:
	queue_redraw()

static func _get_farm_font() -> Font:
	if ClassDB.class_exists("GameUi") or ResourceLoader.exists("res://ui/common/game_ui.gd"):
		var gf = GameUi.game_font()
		if gf != null:
			return gf
	var t := ThemeDB.get_project_theme()
	if t and t.default_font:
		return t.default_font
	return ThemeDB.fallback_font

func _draw() -> void:
	var font := _get_farm_font()

	for i in range(FISH_ZONES.size()):
		var zone: Dictionary = FISH_ZONES[i]
		var data: Dictionary = fish_data[i]
		var local_c := to_local(zone["world_pos"])
		var lvl: int = clampi(int(data.get("level", 1)), 1, 5)
		var prog := _get_progress(i)
		var is_ready := (prog >= 1.0)
		var is_hovered := (i == _hovered_zone_idx)
		var t := Time.get_ticks_msec() / 1000.0 + i * 2.0

		if i < cached_polygons.size() and not cached_polygons[i].is_empty():
			# 1. Vẽ mặt nước hồ cá / bè nổi dập dềnh sóng nước (Vẽ trực tiếp đa giác chuẩn Clockwise)
			var fill_color: Color = zone.get("color", Color(0.18, 0.55, 0.88, 0.28))
			var wave_alpha := clampf(fill_color.a + sin(t * 1.5) * 0.05, 0.15, 0.55)
			fill_color.a = wave_alpha

			var poly_local := PackedVector2Array()
			var base_poly: PackedVector2Array = cached_polygons[i]
			poly_local.resize(base_poly.size())
			for pt_idx in range(base_poly.size()):
				poly_local[pt_idx] = local_c + base_poly[pt_idx]
			
			if not Geometry2D.is_polygon_clockwise(poly_local):
				poly_local.reverse()

			draw_colored_polygon(poly_local, fill_color)

			# 2. Họa tiết lồng bè nuôi cá biển sâu (Lưới bè nổi & Khung bè gỗ hình vuông)
			var poly: PackedVector2Array = cached_polygons[i]
			var n_pts := poly.size()

			if zone["id"] == "ocean_cage":
				# 2a. Vẽ Cầu Tàu Gỗ dẫn từ bờ biển [196/197] ra Bè Cá Biển Sâu [196/198]
				var pier_x := local_c.x
				var pier_top_y := local_c.y - 200.0
				var pier_bot_y := local_c.y - 105.0
				var pier_w := 24.0

				# Sàn cầu gỗ lót ván
				draw_rect(Rect2(pier_x - pier_w, pier_top_y, pier_w * 2.0, pier_bot_y - pier_top_y), Color(0.34, 0.22, 0.12, 0.95))
				draw_line(Vector2(pier_x - pier_w, pier_top_y), Vector2(pier_x - pier_w, pier_bot_y), Color(0.58, 0.38, 0.20, 1.0), 3.0)
				draw_line(Vector2(pier_x + pier_w, pier_top_y), Vector2(pier_x + pier_w, pier_bot_y), Color(0.58, 0.38, 0.20, 1.0), 3.0)

				# Các rãnh chia thanh ván gỗ ngang sàn cầu
				for py in [-190.0, -178.0, -166.0, -154.0, -142.0, -130.0, -118.0]:
					draw_line(Vector2(pier_x - pier_w + 1.0, local_c.y + py), Vector2(pier_x + pier_w - 1.0, local_c.y + py), Color(0.20, 0.12, 0.06, 0.85), 2.0)

				# Cọc gỗ & Dây thừng lan can 2 bên cầu dẫn
				var pier_posts_y := [-195.0, -165.0, -135.0, -105.0]
				for p_idx in range(pier_posts_y.size()):
					var py: float = local_c.y + pier_posts_y[p_idx]
					draw_circle(Vector2(pier_x - pier_w, py), 4.5, Color(0.60, 0.40, 0.22, 1.0))
					draw_circle(Vector2(pier_x - pier_w, py), 2.2, Color(1.0, 0.90, 0.50, 1.0))
					draw_circle(Vector2(pier_x + pier_w, py), 4.5, Color(0.60, 0.40, 0.22, 1.0))
					draw_circle(Vector2(pier_x + pier_w, py), 2.2, Color(1.0, 0.90, 0.50, 1.0))
					if p_idx > 0:
						var prev_py: float = local_c.y + pier_posts_y[p_idx - 1]
						draw_line(Vector2(pier_x - pier_w, prev_py), Vector2(pier_x - pier_w, py), Color(0.85, 0.70, 0.40, 0.9), 2.0)
						draw_line(Vector2(pier_x + pier_w, prev_py), Vector2(pier_x + pier_w, py), Color(0.85, 0.70, 0.40, 0.9), 2.0)

				if font:
					var bridge_label := "⚓ CẦU TÀU ĐÁNH BẮT CÁ BIỂN [188/201] ⚓"
					var bl_pos := Vector2(pier_x - 180.0, pier_top_y - 12.0)
					draw_string_outline(font, bl_pos, bridge_label, HORIZONTAL_ALIGNMENT_CENTER, 360, 11, 2, Color.BLACK)
					draw_string(font, bl_pos, bridge_label, HORIZONTAL_ALIGNMENT_CENTER, 360, 11, Color(0.35, 0.85, 1.0))

				# 2b. Khung giàn bè gỗ nổi hình vuông 4 cạnh
				var wood_col := Color(0.42, 0.26, 0.12, 0.95)
				var wood_hi := Color(0.70, 0.48, 0.26, 0.95)
				for j in range(n_pts):
					var wp1 := local_c + poly[j]
					var wp2 := local_c + poly[(j + 1) % n_pts]
					draw_line(wp1, wp2, wood_col, 8.0)
					draw_line(wp1, wp2, wood_hi, 3.5)

				# Lưới kéo cá biển sâu hình vuông đan xen bên trong bè
				var net_col := Color(0.28, 0.70, 0.95, 0.32)
				for net_v in [-80.0, -50.0, -20.0, 10.0, 40.0, 70.0]:
					draw_line(local_c + Vector2(net_v, -95.0), local_c + Vector2(net_v, 95.0), net_col, 1.2)
					draw_line(local_c + Vector2(-95.0, net_v), local_c + Vector2(95.0, net_v), net_col, 1.2)

			# 3. Đàn cá nhỏ bơi lội sinh động dưới làn nước trong xanh
			for f_idx in range(4):
				var f_angle := t * (1.1 + f_idx * 0.25) + f_idx * 1.57
				var f_radius := (45.0 if zone["id"] == "freshwater_pond" else 42.0) + sin(t * 1.5 + f_idx) * 16.0
				var fish_pos := local_c + Vector2(cos(f_angle) * f_radius, sin(f_angle) * f_radius * 0.6)
				var fish_dir := Vector2(-sin(f_angle), cos(f_angle) * 0.6).normalized()
				var fish_col := Color(0.95, 0.78, 0.35, 0.8) if zone["id"] == "freshwater_pond" else Color(0.35, 0.85, 0.95, 0.8)
				draw_circle(fish_pos, 2.8, fish_col)
				draw_line(fish_pos, fish_pos - fish_dir * 5.0, fish_col, 1.5)

			# 4. HÀNG RÀO CỌC GỖ & DÂY PHAO LIÊN KẾT (BORDER LINK chuẩn như Nuôi Thú)
			var fence_col: Color = zone.get("border_color", Color(0.4, 0.85, 1.0, 0.95))
			var fence_shadow: Color = zone.get("shadow_color", Color(0.12, 0.20, 0.30, 0.85))
			var post_col: Color = zone.get("post_color", Color(0.55, 0.40, 0.25, 1.0))
			var post_cap: Color = zone.get("post_cap_color", Color(0.40, 0.85, 1.0, 1.0))
			var sub_post_col: Color = zone.get("sub_post_color", Color(0.60, 0.45, 0.28, 0.95))

			if is_hovered:
				fence_col = Color(1.0, 0.92, 0.40, 1.0)
				post_cap = Color(1.0, 0.98, 0.60, 1.0)

			for j in range(n_pts):
				var p1 := local_c + poly[j]
				var p2 := local_c + poly[(j + 1) % n_pts]

				# Đường nối bóng đổ & đường viền cọc rào / phao bè liên kết
				draw_line(p1, p2, fence_shadow, 3.5)
				draw_line(p1, p2, fence_col, 2.0)

				# Hào quang rực rỡ khi cá đã lớn sẵn sàng kéo lưới
				if is_ready:
					var pulse := 0.75 + sin(t * 4.0) * 0.25
					var glow_col := Color(1.0, 0.88, 0.25, pulse)
					draw_line(p1, p2, glow_col, 4.0)

				# Cọc phụ / phao nổi phụ cách đều
				var seg_len := p1.distance_to(p2)
				var step_dist: float = 38.0 if zone["id"] == "freshwater_pond" else 30.0
				var num_sub := int(seg_len / step_dist)
				for s in range(num_sub):
					var t_sub := float(s + 1) / float(num_sub + 1)
					var post_pos := p1.lerp(p2, t_sub)
					draw_circle(post_pos, 3.5, sub_post_col)
					if zone["id"] == "ocean_cage":
						draw_circle(post_pos, 1.8, Color(1.0, 0.95, 0.70, 0.9))

			# 5. Cọc gỗ chính & Mốc tọa độ tại các đỉnh mốc (giống như nuôi thú)
			var lm_indices: Array = zone.get("landmark_indices", [])
			var lm_coords: Array = zone.get("landmark_coords", [])
			for k in range(min(lm_indices.size(), lm_coords.size())):
				var pt_idx: int = lm_indices[k]
				if pt_idx < poly.size():
					var p_lm := local_c + poly[pt_idx]
					var c: Vector2i = lm_coords[k]

					# Cọc chính / Thùng phao neo góc
					var main_post_radius: float = 6.0 if zone["id"] == "freshwater_pond" else 7.5
					var main_cap_radius: float = 3.5 if zone["id"] == "freshwater_pond" else 4.5
					draw_circle(p_lm, main_post_radius, post_col)
					draw_circle(p_lm, main_cap_radius, post_cap)

					# Nhãn mốc tọa độ
					if font:
						var coord_str := "%d/%d" % [c.x, c.y]
						var offset_dir := (poly[pt_idx] - Vector2.ZERO).normalized() * 22.0
						draw_string_outline(font, p_lm + offset_dir, coord_str, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, 2, Color.BLACK)
						draw_string(font, p_lm + offset_dir, coord_str, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(1.0, 0.95, 0.6))

			# 6. Bảng tên Banner khu vực trên hàng rào (Area Title Banner chuẩn như Nuôi Thú)
			if font:
				var icon_prefix := "🐟" if zone["id"] == "freshwater_pond" else "🌊"
				var chain_str: String = zone.get("chain_str", zone["coord_name"])
				var status_str := ""
				if is_ready:
					status_str = " [✨ SẴN SÀNG KÉO LƯỚI ✨]"
				else:
					status_str = " [ĐANG NUÔI: %s %d%%]" % [data.get("fish_name", "Cá"), int(prog * 100)]

				var full_title := "%s %s (%s)%s" % [icon_prefix, zone["name"].to_upper(), chain_str, status_str]

				var title_y_offset: float = -128.0 if zone["id"] == "freshwater_pond" else -130.0
				var title_pos := local_c + Vector2(-360, title_y_offset)
				draw_string_outline(font, title_pos, full_title, HORIZONTAL_ALIGNMENT_CENTER, 720, 13, 2, Color.BLACK)
				draw_string(font, title_pos, full_title, HORIZONTAL_ALIGNMENT_CENTER, 720, 13, Color(1.0, 0.92, 0.45))

				# Dòng phụ: Cấp độ sao, độ sạch nước, oxy
				var stars := ""
				var star_char := "⭐" if font and font.has_char(0x2B50) else "★"
				for s in range(lvl):
					stars += star_char
				var water_icon := "💧 " if font and font.has_char(0x1F4A7) else ""
				var oxy_icon := "💨 " if font and font.has_char(0x1F4A8) else ""
				var sub_info := "%s Cấp %d/5  |  %sĐộ Sạch: %d%%  |  %sOxy: %d/3 lần" % [
					stars, lvl, water_icon, 100 - (int(data.get("oxy_count", 0)) * 10), oxy_icon, int(data.get("oxy_count", 0))
				]
				draw_string_outline(font, title_pos + Vector2(0, 16), sub_info, HORIZONTAL_ALIGNMENT_CENTER, 720, 11, 2, Color.BLACK)
				draw_string(font, title_pos + Vector2(0, 16), sub_info, HORIZONTAL_ALIGNMENT_CENTER, 720, 11, Color(0.4, 0.85, 1.0))

				# Dòng gợi ý thao tác nhấp chuột
				var hint_text := "👉 Nhấp chuột vào Giàn Bè / Cầu Tàu để Thả Cá / Bơm Oxy / Kéo Lưới" if zone["id"] == "ocean_cage" else "👉 Nhấp chuột vào Ao để Thả Cá / Bơm Oxy / Kéo Lưới"
				var hint_col := Color(1.0, 0.95, 0.45, 0.95) if is_hovered else Color(0.8, 0.85, 0.9, 0.75)
				draw_string_outline(font, title_pos + Vector2(0, 32), hint_text, HORIZONTAL_ALIGNMENT_CENTER, 720, 10, 2, Color.BLACK)
				draw_string(font, title_pos + Vector2(0, 32), hint_text, HORIZONTAL_ALIGNMENT_CENTER, 720, 10, hint_col)

func _get_progress(idx: int) -> float:
	var d: Dictionary = fish_data[idx]
	var started: int = int(d.get("started_at", 0))
	if started == 0:
		return 0.0
	var now := int(Time.get_unix_time_from_system())
	var elapsed := float(now - started)
	if elapsed <= 0.0:
		return 0.0

	var rate := 1.0 + float(d.get("oxy_count", 0)) * 0.20
	if d.get("mineral", false):
		rate += 0.30
	rate *= (1.0 + float(int(d.get("level", 1)) - 1) * 0.15)

	var total_t: float = float(d.get("total_time", 120)) / rate
	return clampf(elapsed / total_t, 0.0, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_world := get_global_mouse_position()
		var old_hover := _hovered_zone_idx
		_hovered_zone_idx = -1
		for i in range(FISH_ZONES.size()):
			var zone: Dictionary = FISH_ZONES[i]
			var z_pos: Vector2 = zone["world_pos"]
			if i < cached_polygons.size() and not cached_polygons[i].is_empty():
				var mouse_rel := mouse_world - z_pos
				if Geometry2D.is_point_in_polygon(mouse_rel, cached_polygons[i]):
					_hovered_zone_idx = i
					break
			elif mouse_world.distance_to(z_pos) <= float(zone.get("radius", 80.0)):
				_hovered_zone_idx = i
				break
			if zone["id"] == "ocean_cage":
				var pier_rect := Rect2(z_pos.x - 26.0, z_pos.y - 205.0, 52.0, 105.0)
				if pier_rect.has_point(mouse_world):
					_hovered_zone_idx = i
					break
		if _hovered_zone_idx != old_hover:
			queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen_mouse := get_viewport().get_mouse_position()

		# 0. Nếu đang có bất kỳ modal nông trại nào mở:
		var modal_layer = get_tree().root.get_node_or_null("FarmModalLayer")
		if modal_layer and is_instance_valid(modal_layer):
			for child in modal_layer.get_children():
				if child is Control and is_instance_valid(child) and not child.is_queued_for_deletion() and child.is_visible_in_tree():
					var local_m := (child as Control).get_local_mouse_position()
					if Rect2(Vector2.ZERO, (child as Control).size).has_point(local_m) or (child as Control).get_global_rect().has_point(screen_mouse):
						return
		var old_modal = get_tree().root.get_node_or_null("FishActionModal") as Control
		if old_modal and is_instance_valid(old_modal) and old_modal.is_visible_in_tree():
			var local_m := old_modal.get_local_mouse_position()
			if Rect2(Vector2.ZERO, old_modal.size).has_point(local_m) or old_modal.get_global_rect().has_point(screen_mouse):
				return
			old_modal.queue_free()

		var mouse_world := get_global_mouse_position()
		for i in range(FISH_ZONES.size()):
			var zone: Dictionary = FISH_ZONES[i]
			var is_inside := false
			var z_pos: Vector2 = zone["world_pos"]
			if i < cached_polygons.size() and not cached_polygons[i].is_empty():
				var mouse_rel: Vector2 = mouse_world - z_pos
				is_inside = Geometry2D.is_point_in_polygon(mouse_rel, cached_polygons[i])
			else:
				is_inside = (mouse_world.distance_to(z_pos) <= float(zone.get("radius", 68.0)) + 15.0)

			if not is_inside and zone["id"] == "ocean_cage":
				var pier_rect := Rect2(z_pos.x - 26.0, z_pos.y - 205.0, 52.0, 105.0)
				is_inside = pier_rect.has_point(mouse_world)

			if is_inside:
				get_viewport().set_input_as_handled()
				var plyr = get_tree().get_first_node_in_group("player")
				if plyr and is_instance_valid(plyr):
					var stand_pos: Vector2 = Vector2(48256.0, 51640.0) if zone["id"] == "ocean_cage" else Vector2(46420.0, 47488.0)
					if plyr.global_position.distance_to(stand_pos) > 120.0:
						if plyr.has_method("walk_to_feet"):
							plyr.walk_to_feet(stand_pos)
						elif "destination" in plyr:
							plyr.destination = stand_pos
				_open_fish_action_modal(i)
				return

func _get_or_create_modal_layer() -> CanvasLayer:
	var layer = get_tree().root.get_node_or_null("FarmModalLayer") as CanvasLayer
	if layer == null or not is_instance_valid(layer):
		layer = CanvasLayer.new()
		layer.name = "FarmModalLayer"
		layer.layer = 120
		get_tree().root.add_child(layer)
	return layer

func _attach_modal(win: Control, win_size: Vector2) -> void:
	win.custom_minimum_size = win_size
	win.size = win_size

	var vp_size := Vector2(1280, 720)
	var root_vp = get_tree().root if get_tree() else null
	if root_vp:
		var vs := root_vp.get_visible_rect().size
		if vs.x > 300 and vs.y > 300:
			vp_size = vs
	win.position = Vector2(
		(vp_size.x - win_size.x) * 0.5,
		(vp_size.y - win_size.y) * 0.5
	).round()

	win.mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_drag_window(win)

	var layer := _get_or_create_modal_layer()
	layer.add_child(win)

func _setup_drag_window(win: Control) -> void:
	var is_dragging := [false]
	var drag_start_mouse := [Vector2.ZERO]
	var drag_start_win_pos := [Vector2.ZERO]

	win.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			win.accept_event()
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_dragging[0] = true
					drag_start_mouse[0] = event.global_position
					drag_start_win_pos[0] = win.position
					win.move_to_front()
				else:
					is_dragging[0] = false
		elif event is InputEventMouseMotion and is_dragging[0]:
			win.accept_event()
			var delta: Vector2 = event.global_position - drag_start_mouse[0]
			var new_pos: Vector2 = drag_start_win_pos[0] + delta
			var vp := win.get_viewport_rect().size
			if vp.x > 0 and vp.y > 0:
				new_pos.x = clampf(new_pos.x, 0.0, maxf(0.0, vp.x - win.size.x))
				new_pos.y = clampf(new_pos.y, 0.0, maxf(0.0, vp.y - win.size.y))
			win.position = new_pos
	)

## Bảng Tùy Chọn Đầy Đủ khi nhấp vào Ao Nuôi Cá / Bè Cá:
## Thả cá giống, Cho ăn, Bơm Oxy, Bón khoáng, Nâng cấp ao, Kéo lưới thu hoạch
func _open_fish_action_modal(idx: int) -> void:
	var layer = get_tree().root.get_node_or_null("FarmModalLayer")
	if layer and is_instance_valid(layer):
		for child in layer.get_children():
			child.queue_free()
	var old = get_tree().root.get_node_or_null("FishActionModal")
	if old:
		old.queue_free()

	var zone: Dictionary = FISH_ZONES[idx]
	var data: Dictionary = fish_data[idx]
	var lvl: int = clampi(int(data.get("level", 1)), 1, 5)
	var prog := _get_progress(idx)

	var win := PanelContainer.new()
	win.name = "FishActionModal"

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	bg.border_color = Color(0.35, 0.75, 1.0)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 16
	bg.content_margin_top = 12
	bg.content_margin_right = 16
	bg.content_margin_bottom = 12
	win.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	win.add_child(vbox)

	# 1. Header
	var header := HBoxContainer.new()
	var stars := ""
	for s in range(lvl):
		stars += "⭐"
	var title_lbl := Label.new()
	title_lbl.text = "🐟 %s (%s CẤP %d/5)" % [zone["name"], stars, lvl]
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(title_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(win.queue_free)
	header.add_child(close_btn)
	vbox.add_child(header)

	# 2. Chi tiết trạng thái
	var status_panel := PanelContainer.new()
	var sp_bg := StyleBoxFlat.new()
	sp_bg.bg_color = Color(0.12, 0.16, 0.22, 0.9)
	sp_bg.set_corner_radius_all(6)
	sp_bg.content_margin_left = 10
	sp_bg.content_margin_top = 8
	sp_bg.content_margin_right = 10
	sp_bg.content_margin_bottom = 8
	status_panel.add_theme_stylebox_override("panel", sp_bg)

	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 4)
	status_panel.add_child(status_vbox)

	var info_lbl := Label.new()
	var prog_pct := int(prog * 100)
	var state_desc := "✨ Sẵn sàng kéo lưới thu hoạch!" if prog >= 1.0 else "Đang sinh trưởng bơi lội dưới nước"
	info_lbl.text = "Giống cá: %s | Trạng thái: %s (%d%%)\n💨 Bơm Oxy: %d/3 lần | 🧪 Khoáng vi sinh: %s\n⭐ Hiệu quả ao: Tăng +%d%% tốc độ sinh trưởng thủy sản" % [
		data.get("fish_name", "Cá"), state_desc, prog_pct, data.get("oxy_count", 0), ("Đã bón" if data.get("mineral", false) else "Chưa bón"), (lvl - 1) * 15
	]
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	status_vbox.add_child(info_lbl)
	vbox.add_child(status_panel)

	# 3. DANH SÁCH THAO TÁC NUÔI CÁ (DẠNG DANH SÁCH DỌC - FULL WIDTH)
	var action_list := VBoxContainer.new()
	action_list.add_theme_constant_override("separation", 6)

	if prog >= 1.0:
		var harvest_btn := Button.new()
		harvest_btn.text = "✨ KÉO LƯỚI THU HOẠCH CÁ NGAY ✨"
		harvest_btn.custom_minimum_size = Vector2(0, 36)
		harvest_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		harvest_btn.focus_mode = Control.FOCUS_NONE
		_apply_prominent_button_style(harvest_btn, Color(0.72, 0.52, 0.12, 0.96), Color(1.0, 0.95, 0.45), Color(1.0, 1.0, 0.88), 6)
		harvest_btn.pressed.connect(func():
			_harvest_fish(idx)
			win.queue_free()
		)
		action_list.add_child(harvest_btn)

	var seed_key := "fingerling_carp" if idx == 0 else "fingerling_sea_bass"
	var seed_name := "Cá Trắm Cỏ Giống" if idx == 0 else "Cá Vược Biển Giống"
	var seed_stock: int = int(farm_mgr.farm_chest_supplies.get(seed_key, 0)) if farm_mgr else 0

	var stock_btn := Button.new()
	stock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_btn.custom_minimum_size = Vector2(0, 34)
	stock_btn.focus_mode = Control.FOCUS_NONE
	if seed_stock > 0:
		stock_btn.text = "🐟 Thả Cá Giống (Hiện có %d con trong rương)" % seed_stock
		_apply_prominent_button_style(stock_btn, Color(0.14, 0.42, 0.68, 0.96), Color(0.45, 0.9, 1.0), Color(0.95, 1.0, 1.0), 6)
		stock_btn.pressed.connect(func():
			if farm_mgr and farm_mgr.remove_from_chest(seed_key, 1, true):
				data["started_at"] = int(Time.get_unix_time_from_system())
				data["fish_name"] = "Cá Trắm Cỏ" if idx == 0 else "Cá Vược Biển"
				data["oxy_count"] = 0
				data["mineral"] = false
				farm_mgr.save_farm_data()
				farm_mgr.farm_data_changed.emit()
				_show_floating_text("✨ Đã thả 1 %s vào nuôi sinh sôi!" % seed_name, zone["world_pos"])
				win.queue_free()
		)
	else:
		stock_btn.text = "🐟 Thả Cá Giống (Chưa có con giống trong rương)"
		_apply_prominent_button_style(stock_btn, Color(0.24, 0.32, 0.42, 0.95), Color(0.5, 0.7, 0.9, 0.8), Color(0.85, 0.92, 0.98), 6)
		stock_btn.pressed.connect(func():
			var npc_hint := "Khê Hồ Ngư Nương (180/185)" if idx == 0 else "Hải Ngư Thuyền Trưởng (196/197)"
			_show_floating_text("⚠️ Chưa có giống trong rương! Mua tại %s" % npc_hint, zone["world_pos"])
		)
	action_list.add_child(stock_btn)

	var feed_btn := Button.new()
	feed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_btn.custom_minimum_size = Vector2(0, 34)
	feed_btn.text = "🍞 Cho Ăn (Rải cám cho đàn cá mau lớn)"
	feed_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(feed_btn, Color(0.48, 0.32, 0.12, 0.96), Color(0.95, 0.8, 0.35), Color(1.0, 0.96, 0.88), 6)
	feed_btn.pressed.connect(func():
		_show_floating_text("🍞 Đã rải cám cho đàn cá ăn no nê!", zone["world_pos"])
		win.queue_free()
	)
	action_list.add_child(feed_btn)

	var oxy_btn := Button.new()
	oxy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oxy_btn.custom_minimum_size = Vector2(0, 34)
	oxy_btn.focus_mode = Control.FOCUS_NONE
	var oxy_c: int = int(data.get("oxy_count", 0))
	if oxy_c < 3:
		oxy_btn.text = "💨 Bơm Oxy Sục Khí (%d/3 lần) [+20%% Tốc độ]" % oxy_c
		_apply_prominent_button_style(oxy_btn, Color(0.14, 0.42, 0.54, 0.96), Color(0.45, 0.92, 0.98), Color(0.92, 1.0, 1.0), 6)
		oxy_btn.pressed.connect(func():
			data["oxy_count"] = oxy_c + 1
			_show_floating_text("💨 Đã bơm oxy sủi bọt khí tăng tốc (+20%)!", zone["world_pos"])
			win.queue_free()
		)
	else:
		oxy_btn.text = "💨 Bơm Oxy Sục Khí (Đã tối đa 3/3 lần)"
		_apply_prominent_button_style(oxy_btn, Color(0.14, 0.42, 0.54, 0.96), Color(0.45, 0.92, 0.98), Color(0.92, 1.0, 1.0), 6)
		oxy_btn.disabled = true
	action_list.add_child(oxy_btn)

	var min_btn := Button.new()
	min_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_btn.custom_minimum_size = Vector2(0, 34)
	min_btn.focus_mode = Control.FOCUS_NONE
	if not data.get("mineral", false):
		min_btn.text = "🧪 Bón Khoáng Vi Sinh Sinh Học [+30% Tốc độ]"
		_apply_prominent_button_style(min_btn, Color(0.14, 0.46, 0.24, 0.96), Color(0.48, 0.95, 0.55), Color(0.92, 1.0, 0.92), 6)
		min_btn.pressed.connect(func():
			data["mineral"] = true
			_show_floating_text("🧪 Đã bón khoáng vi sinh sinh học (+30%)!", zone["world_pos"])
			win.queue_free()
		)
	else:
		min_btn.text = "🧪 Khoáng Vi Sinh (Đã bón khoáng thành công)"
		_apply_prominent_button_style(min_btn, Color(0.14, 0.46, 0.24, 0.96), Color(0.48, 0.95, 0.55), Color(0.92, 1.0, 0.92), 6)
		min_btn.disabled = true
	action_list.add_child(min_btn)

	# NÂNG CẤP AO / BÈ CÁ (CẤP 1 -> CẤP 5)
	if lvl < 5:
		var up_pond_btn := Button.new()
		var next_lvl := lvl + 1
		var cost := lvl * 150
		up_pond_btn.text = "⭐ Nâng Cấp %s Lên Cấp %d (%d Lượng)" % [("Ao Cá" if idx == 0 else "Bè Biển"), next_lvl, cost]
		up_pond_btn.custom_minimum_size = Vector2(0, 34)
		up_pond_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up_pond_btn.focus_mode = Control.FOCUS_NONE
		_apply_prominent_button_style(up_pond_btn, Color(0.18, 0.34, 0.5, 0.96), Color(0.42, 0.88, 1.0), Color(1.0, 1.0, 0.9), 6)

		up_pond_btn.pressed.connect(func():
			if farm_mgr and farm_mgr.buy_item_with_currency(cost, 0):
				data["level"] = next_lvl
				farm_mgr.save_farm_data()
				_show_floating_text("⭐ Đã nâng cấp thành công lên Cấp %d (+15%% tốc độ)!" % next_lvl, zone["world_pos"])
				win.queue_free()
			else:
				up_pond_btn.text = "Không đủ ngân lượng!"
		)
		action_list.add_child(up_pond_btn)
	else:
		var max_lbl := Label.new()
		max_lbl.text = "👑 Ao Thủy Sản Đã Đạt Cấp 5 Tối Đa (Long Ngư Nở Hoa)"
		max_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		max_lbl.add_theme_font_size_override("font_size", 12)
		action_list.add_child(max_lbl)

	vbox.add_child(action_list)

	_attach_modal(win, Vector2(500, 450))

## Định dạng phong cách nút bấm theo chuẩn Kiếm Hiệp Wuxia (Ảnh 2: nền ngọc thạch tối, viền kim sắc, canh lề trái)
func _apply_prominent_button_style(btn: Button, _bg_normal: Color = Color.TRANSPARENT, _border_color: Color = Color.TRANSPARENT, font_color: Color = Color.WHITE, radius: int = 6) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.16, 0.18, 0.95)
	normal.border_color = Color(0.72, 0.58, 0.28, 0.85)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(radius)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.09, 0.26, 0.28, 1.0)
	hover.border_color = Color(1.0, 0.88, 0.45, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.04, 0.13, 0.15, 0.95)
	pressed.border_color = Color(0.72, 0.58, 0.28, 0.85)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.10, 0.12, 0.6)
	disabled.border_color = Color(0.35, 0.35, 0.35, 0.4)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(radius)
	disabled.content_margin_left = 14
	disabled.content_margin_right = 14
	disabled.content_margin_top = 5
	disabled.content_margin_bottom = 5

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", font_color if font_color != Color.WHITE else Color(0.95, 0.95, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.60, 0.7))
	btn.add_theme_font_size_override("font_size", 13)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _harvest_fish(idx: int) -> void:
	var d: Dictionary = fish_data[idx]
	var zone: Dictionary = FISH_ZONES[idx]
	var fish_name: String = str(d.get("fish_name", "Cá Tươi"))
	var exp_reward := 50
	var prod_id := "fish_fresh" if idx == 0 else "fish_ocean"

	if farm_mgr:
		farm_mgr.add_to_chest(prod_id, 1, false)
		farm_mgr.add_farm_exp(exp_reward)
		farm_mgr.save_farm_data()

	# Khởi động lại đợt nuôi mới
	d["started_at"] = int(Time.get_unix_time_from_system())
	d["oxy_count"] = 0
	d["mineral"] = false

	_show_floating_text("✨ Kéo lưới thu hoạch %s thành công!\n(+%d Exp nông trại)" % [fish_name, exp_reward], zone["world_pos"])

func _show_floating_text(text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = to_local(pos) - Vector2(100, 30)
	lbl.custom_minimum_size = Vector2(200, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 20
	add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 35, 1.5)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.tween_callback(lbl.queue_free)
