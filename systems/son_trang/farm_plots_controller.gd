extends Node2D
class_name FarmPlotsController
## Quản lý trực quan 34 Luống Đất Trồng Trọt:
## - Khu Đông: 21 thửa đất (đã xóa 3 thửa vướng cối xay, hàng rào, NPC ở ảnh 1)
## - Khu Tây Mở Rộng: 11 thửa đất bên trái (đã bỏ 4 thửa vách đá & rặng cây)
## - Khu Bắc Mở Rộng: 2 thửa đất trên bãi cỏ thoáng (đã bỏ ô bị chồng lên Luống 24)
## - Lối đi thông thoáng giữa các khu, không chồng chéo, bảo tồn trọn vẹn nền cỏ tự nhiên

var farm_mgr = null

const COORD_UNIT: float = 256.0

## Tọa độ thế giới trung tâm khu đất canh tác (Dịch lên gần chân bờ đá)
const FARM_CENTER_WORLD := Vector2(48512.0, 47998.0)

# Kích thước ảnh luống đất 1:1 chuẩn xác với 5 ảnh (159 x 130 px)
const PLOT_W: float = 159.0
const PLOT_H: float = 130.0

# Khu Đông: 24 luống (6 x 4)
const EAST_COLS: int = 6
const EAST_ROWS: int = 4
const EAST_COUNT: int = 24
const GAP_X: float = 48.0
const GAP_Y: float = 40.0

# Khu Tây bên trái: 11 luống (đã bỏ 4 ô nằm trên bờ đá / rặng cây)
const WEST_COLS: int = 3
const WEST_ROWS: int = 5
const WEST_COUNT: int = 11
const WEST_GAP_X: float = 44.0
const WEST_GAP_Y: float = 32.0

const TOTAL_LUONG: int = 34

# 5 Cấp độ hình ảnh luống đất
var plot_textures: Array[Texture2D] = []
var _crop_textures: Dictionary = {}
var _plot_areas: Array[Rect2] = []
var _hovered_plot_idx: int = -1

func _ready() -> void:
	z_index = -5 # Nằm trên mặt đất, dưới chân nhân vật
	farm_mgr = get_node_or_null("/root/FarmManager")
	_load_plot_textures()
	_preload_crop_textures()
	_calculate_plot_areas()

func _get_texture_safe(path: String) -> Texture2D:
	if path == "":
		return null
	if _crop_textures.has(path):
		return _crop_textures[path]

	var tex: Texture2D = null

	# 1. Thử nạp trực tiếp qua load / ResourceLoader (hỗ trợ .remap trên Web/PCK)
	if ResourceLoader.has_cached(path):
		var c = ResourceLoader.get_cached_ref(path)
		if c is Texture2D:
			tex = c

	if tex == null:
		var res = load(path)
		if res is Texture2D:
			tex = res

	if tex == null and ResourceLoader.exists(path):
		var res2 = ResourceLoader.load(path)
		if res2 is Texture2D:
			tex = res2

	# 2. Nếu đường dẫn thuộc assets/items/icons/ thì kiểm tra kho assets/farm/icons/ (luôn được đóng gói vào bản Web)
	if tex == null and path.begins_with("res://assets/items/icons/"):
		var farm_path := path.replace("res://assets/items/icons/", "res://assets/farm/icons/")
		var res_farm = load(farm_path)
		if res_farm is Texture2D:
			tex = res_farm

	# 3. Fallback file hệ thống cho môi trường local
	if tex == null:
		var global_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_p):
			var img := Image.new()
			if img.load(global_p) == OK:
				tex = ImageTexture.create_from_image(img)
		elif FileAccess.file_exists(path):
			var img := Image.new()
			if img.load(path) == OK:
				tex = ImageTexture.create_from_image(img)

	# 4. Fallback mặc định đảm bảo Web không bao giờ bị trắng / lỗi ảnh
	if tex == null and path.ends_with(".png"):
		var seed_res = load("res://assets/farm/crops/seed.png")
		if seed_res is Texture2D:
			tex = seed_res

	if tex != null:
		_crop_textures[path] = tex
	return tex

func _preload_crop_textures() -> void:
	_get_texture_safe("res://assets/farm/crops/seed.png")
	_get_texture_safe("res://assets/farm/crops/sprout.png")
	var plants := PlantData.get_all_plants()
	for p in plants:
		if p.sprite_growing != "":
			_get_texture_safe(p.sprite_growing)
		if p.sprite_mature != "":
			_get_texture_safe(p.sprite_mature)
		if p.icon_path != "":
			_get_texture_safe(p.icon_path)

func _load_plot_textures() -> void:
	plot_textures.clear()
	for lvl in range(1, 6):
		var path := "res://assets/farm/plots/plot_level_%d.png" % lvl
		var tex := _get_texture_safe(path)
		if tex != null:
			plot_textures.append(tex)
		else:
			push_warning("Không tìm thấy ảnh luống cấp %d: %s" % [lvl, path])
			plot_textures.append(null)

## Tính toán vị trí 35 ô đất: 21 ô Khu Đông + 11 ô Khu Tây + 3 ô bãi cỏ thoáng phía Bắc (ảnh 2)
func _calculate_plot_areas() -> void:
	_plot_areas.clear()

	# 1. Khu Đông (21 ô: đã xóa 3 ô r=0 c=3,4,5 vướng cối xay, hàng rào, NPC ở ảnh 1)
	var east_total_w := EAST_COLS * PLOT_W + (EAST_COLS - 1) * GAP_X
	var east_total_h := EAST_ROWS * PLOT_H + (EAST_ROWS - 1) * GAP_Y
	var east_start_x := -east_total_w * 0.5
	var east_start_y := -east_total_h * 0.5

	for r in range(EAST_ROWS):
		for c in range(EAST_COLS):
			# Xóa 3 ô vướng vật cản ở ảnh 1: r=0, c=3,4,5 (cối xay đá, hàng rào, NPC Thần Nông Tiên Sinh)
			if r == 0 and c >= 3:
				continue
			var x := east_start_x + c * (PLOT_W + GAP_X)
			var y := east_start_y + r * (PLOT_H + GAP_Y)
			_plot_areas.append(Rect2(Vector2(x, y), Vector2(PLOT_W, PLOT_H)))

	# 2. Khu Tây bên trái (11 ô: Luống 22..32)
	# Bỏ 4 ô nằm trên bờ đá, vách núi và rặng cây theo đánh dấu X của người chơi:
	# - Bỏ (r=3, c=0): Nằm trên vách đá phía Tây
	# - Bỏ (r=4, c=0), (r=4, c=1), (r=4, c=2): Toàn bộ hàng 4 nằm trên vách đá và bụi cây phía Nam
	var west_total_w := WEST_COLS * PLOT_W + (WEST_COLS - 1) * WEST_GAP_X
	var west_base_total_h := 5 * PLOT_H + 4 * WEST_GAP_Y
	var pathway_gap := 110.0 # Khoảng trống lối đi rặng cây ở giữa hai khu
	var west_start_x := east_start_x - pathway_gap - west_total_w
	var west_start_y := -west_base_total_h * 0.5

	for r in range(5):
		for c in range(WEST_COLS):
			# Bỏ 4 ô bị đánh dấu X
			if (r == 3 and c == 0) or (r == 4):
				continue
			var x := west_start_x + c * (PLOT_W + WEST_GAP_X)
			var y := west_start_y + r * (PLOT_H + WEST_GAP_Y)
			_plot_areas.append(Rect2(Vector2(x, y), Vector2(PLOT_W, PLOT_H)))

	# 3. Thêm 2 ô trên bãi cỏ thoáng phía Bắc:
	# Nằm trên dải cỏ xanh thoáng phía trên Luống 1 và Luống 2 (đã bỏ Luống 33 vì bị chồng lên Luống 24)
	var north_y := east_start_y - (PLOT_H + GAP_Y) # y = -490.0
	_plot_areas.append(Rect2(Vector2(east_start_x + 0 * (PLOT_W + GAP_X), north_y), Vector2(PLOT_W, PLOT_H))) # Phía trên Luống 1 (x = -597.0)
	_plot_areas.append(Rect2(Vector2(east_start_x + 1 * (PLOT_W + GAP_X), north_y), Vector2(PLOT_W, PLOT_H))) # Phía trên Luống 2 (x = -390.0)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if farm_mgr == null or farm_mgr.plot_mgr == null:
		return

	# Vẽ 39 Luống Đất (Slot đã kích hoạt vẽ ảnh theo cấp, Slot chưa kích hoạt vẽ viền đứt khúc)
	var plots = farm_mgr.plot_mgr.plots
	for i in range(min(plots.size(), _plot_areas.size())):
		var p: PlotManager.PlotInfo = plots[i]
		var r: Rect2 = _plot_areas[i]
		_draw_single_luong(p, r, i)

## Vẽ viền đứt khúc (Dashed Rectangle)
func _draw_dashed_rect(r: Rect2, color: Color, width: float = 2.0, dash: float = 8.0) -> void:
	draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), color, width, dash)
	draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, color, width, dash)
	draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), color, width, dash)
	draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, color, width, dash)

static func _get_farm_font() -> Font:
	if ClassDB.class_exists("GameUi") or ResourceLoader.exists("res://ui/common/game_ui.gd"):
		var gf = GameUi.game_font()
		if gf != null:
			return gf
	var t := ThemeDB.get_project_theme()
	if t and t.default_font:
		return t.default_font
	return ThemeDB.fallback_font

func _draw_single_luong(p: PlotManager.PlotInfo, r: Rect2, idx: int) -> void:
	var font := _get_farm_font()

	# Hiệu ứng viền vàng phát sáng khi rê chuột qua ô luống
	if idx == _hovered_plot_idx:
		draw_rect(r.grow(2.0), Color(1.0, 0.9, 0.35, 0.9), false, 2.5)
		draw_rect(r, Color(1.0, 0.9, 0.35, 0.12), true)

	# TRƯỜNG HỢP 1: Ô ĐẤT CHƯA KÍCH HOẠT -> Border đứt khúc vàng kim, không có nền đen
	if not p.is_unlocked:
		_draw_dashed_rect(r, Color(0.95, 0.82, 0.35, 0.95), 2.2, 8.0)

		# 4 góc nhấn
		var cl := 12.0
		draw_line(r.position, r.position + Vector2(cl, 0), Color(1.0, 0.85, 0.2), 2.5)
		draw_line(r.position, r.position + Vector2(0, cl), Color(1.0, 0.85, 0.2), 2.5)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - cl, r.position.y), Color(1.0, 0.85, 0.2), 2.5)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + cl), Color(1.0, 0.85, 0.2), 2.5)

		if font:
			var cost: int = farm_mgr.plot_mgr.get_unlock_cost(idx) if farm_mgr and farm_mgr.plot_mgr else idx * 100
			var lock_prefix := "🔒 " if font.has_char(0x1F512) else "[Khóa] "
			draw_string(font, Vector2(r.position.x, r.position.y + 40), "%sLuống %d" % [lock_prefix, idx + 1], HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), 13, Color(1.0, 0.88, 0.3))
			draw_string(font, Vector2(r.position.x, r.position.y + 64), "[+] Mua Đất Cấp 1", HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), 12, Color(0.4, 0.95, 0.4))
			draw_string(font, Vector2(r.position.x, r.position.y + 88), "(%d Lượng)" % cost, HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), 11, Color(0.85, 0.88, 0.92))
		return

	# TRƯỜNG HỢP 2: Ô ĐẤT ĐÃ KÍCH HOẠT -> Hiển thị hình ảnh luống theo Cấp độ (1..5)
	var lvl := clampi(p.level, 1, 5)

	# 1. Hình ảnh luống đất thật do người dùng cung cấp
	if lvl - 1 < plot_textures.size() and plot_textures[lvl - 1] != null:
		draw_texture_rect(plot_textures[lvl - 1], r, false)
	else:
		draw_rect(r, Color(0.3, 0.2, 0.1, 0.9), true)
		draw_rect(r, Color(0.6, 0.5, 0.3), false, 2.0)

	# 2. Cây trồng trên luống nếu có
	if p.state == PlotManager.PlotState.PLANTED or p.state == PlotManager.PlotState.HARVESTABLE:
		_draw_crop_on_plot(p, r)

	# 3. Phù hiệu cấp độ luống & Số thứ tự
	if font:
		var stars := ""
		var star_char := "⭐" if font.has_char(0x2B50) else "★"
		for s in range(lvl):
			stars += star_char
		var luong_title := "Luống %d (%s Cấp %d)" % [idx + 1, stars, lvl]
		draw_string(font, Vector2(r.position.x + 6, r.position.y - 6), luong_title, HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x), 11, Color(1.0, 0.95, 0.4))

		# Trạng thái luống
		var status_text := ""
		var status_col := Color.WHITE
		match p.state:
			PlotManager.PlotState.UNTILLED:
				status_text = "Đất Cỏ (Cần Cuốc)"
				status_col = Color(0.75, 0.75, 0.75)
			PlotManager.PlotState.TILLED:
				var sprout := "🌱 " if font.has_char(0x1F331) else ""
				status_text = "%sĐất Sẵn Sàng Gieo" % sprout
				status_col = Color(0.4, 0.9, 0.4)
			PlotManager.PlotState.PLANTED:
				var prog_pct := int(p.get_progress() * 100)
				var plant := PlantData.get_plant(p.plant_id)
				var pname := plant.name if plant else "Cây"
				status_text = "%s: %d%%" % [pname, prog_pct]
				status_col = Color(0.4, 0.85, 1.0)
			PlotManager.PlotState.HARVESTABLE:
				var spark := "✨ " if font.has_char(0x2728) else ""
				status_text = "%sTHU HOẠCH%s" % [spark, (" " + spark if spark != "" else "")]
				status_col = Color(1.0, 0.88, 0.2)

		draw_string(font, Vector2(r.position.x + 6, r.position.y + r.size.y + 14), status_text, HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x), 11, status_col)

	# 4. Icon nước hoặc phân bón ở góc ô đất
	if p.state == PlotManager.PlotState.PLANTED:
		if p.watered_count > 0:
			draw_circle(Vector2(r.position.x + 16, r.position.y + 20), 5.0, Color(0.3, 0.7, 1.0, 0.9))
		if p.is_fertilized:
			draw_circle(Vector2(r.position.x + 30, r.position.y + 20), 5.0, Color(0.9, 0.6, 0.2, 0.9))

## Vẽ cây trồng & hạt giống sinh động trên luống đất theo từng giai đoạn
func _draw_crop_on_plot(p: PlotManager.PlotInfo, r: Rect2) -> void:
	var prog := p.get_progress()
	var is_harvestable := (p.state == PlotManager.PlotState.HARVESTABLE or prog >= 1.0)
	var plant := PlantData.get_plant(p.plant_id)
	var plant_id := p.plant_id

	# Xác định giai đoạn sinh trưởng & đường dẫn ảnh tương ứng
	var sprite_path := ""
	var crop_size := 52.0

	if prog < 0.22:
		# Giai đoạn 1: Hạt giống vừa gieo trong đất (Seed stage)
		sprite_path = "res://assets/farm/crops/seed.png"
		crop_size = 42.0
	elif prog < 0.48:
		# Giai đoạn 2: Mầm non mới đâm chồi xanh biếc (Sprout stage)
		sprite_path = "res://assets/farm/crops/sprout.png"
		crop_size = 50.0
	elif not is_harvestable and prog < 0.85:
		# Giai đoạn 3: Cây đang lớn xum xuê (Growing stage)
		if plant and plant.sprite_growing != "":
			sprite_path = plant.sprite_growing
		else:
			sprite_path = "res://assets/farm/crops/sprout.png"
		crop_size = 58.0
	else:
		# Giai đoạn 4: Cây trưởng thành / chín vàng trĩu quả (Mature / Harvestable stage)
		if plant and plant.sprite_mature != "":
			sprite_path = plant.sprite_mature
		elif plant and plant.sprite_growing != "":
			sprite_path = plant.sprite_growing
		else:
			sprite_path = "res://assets/farm/crops/sprout.png"
		crop_size = 66.0

	var tex := _get_texture_safe(sprite_path)

	# Vị trí tâm luống đất, gốc cây nằm tự nhiên trên lòng đất
	var center := r.get_center()
	var crop_pos := Vector2(center.x - crop_size * 0.5, center.y - crop_size * 0.5 + 4.0)

	# Hiệu ứng hào quang lung linh tiên khí khi cây chín vàng sẵn sàng thu hoạch
	if is_harvestable:
		var t := Time.get_ticks_msec() / 240.0
		var pulse := 1.0 + sin(t) * 0.12
		var glow_r := crop_size * 0.55 * pulse
		draw_circle(center + Vector2(0, 4), glow_r, Color(1.0, 0.88, 0.25, 0.35))
		draw_arc(center + Vector2(0, 4), glow_r, 0, TAU, 32, Color(1.0, 0.95, 0.45, 0.85), 2.2)
		draw_arc(center + Vector2(0, 4), glow_r * 0.75, 0, TAU, 24, Color(1.0, 1.0, 0.7, 0.5), 1.2)

	if tex != null:
		draw_texture_rect(tex, Rect2(crop_pos, Vector2(crop_size, crop_size)), false)
	else:
		# Fallback vẽ mỹ thuật tự sinh - ĐẢM BẢO TUYỆT ĐỐI KHÔNG BAO GIỜ HIỆN KHỐI TRẮNG
		_draw_procedural_crop_fallback(center + Vector2(0, 4), prog, is_harvestable, plant_id)

## Fallback vẽ vector nghệ thuật - Không bao giờ để luống đất bị hiện khối vuông trắng
func _draw_procedural_crop_fallback(base_pos: Vector2, prog: float, is_harvestable: bool, plant_id: String) -> void:
	# Bóng đổ gốc cây trên đất
	draw_circle(base_pos + Vector2(0, 10), 16.0, Color(0.12, 0.08, 0.04, 0.55))

	if prog < 0.22:
		# Ụ đất hạt mầm
		draw_circle(base_pos + Vector2(0, 6), 12.0, Color(0.35, 0.24, 0.15, 0.95))
		draw_circle(base_pos + Vector2(-4, 5), 3.0, Color(0.85, 0.7, 0.35, 1.0))
		draw_circle(base_pos + Vector2(4, 6), 3.0, Color(0.80, 0.65, 0.30, 1.0))
		# Mầm xanh nhỏ
		draw_line(base_pos + Vector2(0, 6), base_pos + Vector2(0, -6), Color(0.35, 0.85, 0.3), 2.5)
		draw_circle(base_pos + Vector2(-3, -8), 3.5, Color(0.45, 0.95, 0.35))
		draw_circle(base_pos + Vector2(3, -8), 3.5, Color(0.55, 0.98, 0.4))
	elif prog < 0.48:
		# Mầm non đang lớn
		draw_line(base_pos + Vector2(0, 10), base_pos + Vector2(0, -14), Color(0.3, 0.75, 0.25), 3.5)
		draw_circle(base_pos + Vector2(-8, -10), 6.0, Color(0.4, 0.88, 0.3))
		draw_circle(base_pos + Vector2(8, -12), 6.5, Color(0.45, 0.92, 0.35))
		draw_circle(base_pos + Vector2(0, -18), 7.0, Color(0.55, 0.98, 0.45))
	else:
		# Cây trưởng thành / đơm hoa kết trái
		draw_line(base_pos + Vector2(0, 12), base_pos + Vector2(0, -12), Color(0.4, 0.3, 0.18), 4.5)
		draw_circle(base_pos + Vector2(-12, -6), 12.0, Color(0.2, 0.65, 0.25))
		draw_circle(base_pos + Vector2(12, -8), 13.0, Color(0.22, 0.7, 0.28))
		draw_circle(base_pos + Vector2(0, -16), 15.0, Color(0.3, 0.8, 0.35))

		# Điểm hoa / trái theo loại cây
		var dot_col := Color(0.95, 0.2, 0.2)
		match plant_id:
			"tao_do":
				dot_col = Color(0.95, 0.15, 0.15)
			"mai_hoa":
				dot_col = Color(1.0, 0.65, 0.8)
			"lua_vang":
				dot_col = Color(1.0, 0.85, 0.2)
			"hoa_cuc":
				dot_col = Color(1.0, 0.9, 0.1)
			"duoc_thao":
				dot_col = Color(0.65, 0.4, 1.0)
			"tra_xanh":
				dot_col = Color(0.7, 1.0, 0.4)
			"linh_chi":
				dot_col = Color(0.75, 0.2, 0.15)
			"nhan_sam":
				dot_col = Color(1.0, 0.25, 0.25)

		var dots = [Vector2(-8, -12), Vector2(8, -14), Vector2(0, -22), Vector2(-12, 0), Vector2(10, -2)]
		for d_pos in dots:
			draw_circle(base_pos + d_pos, 4.0, dot_col)
			draw_circle(base_pos + d_pos + Vector2(-1, -1), 1.5, Color.WHITE)

## Bắt sự kiện click chuột chuẩn xác qua _input (chạy trước player movement, không bị nuốt sự kiện)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Nếu đang có modal nông trại mở: không kích hoạt hover làm sáng các ô đất phía sau modal
		var active_modal := _get_active_modal()
		if active_modal != null and _is_mouse_inside_modal(active_modal):
			if _hovered_plot_idx != -1:
				_hovered_plot_idx = -1
				queue_redraw()
			return

		var mouse_world := get_global_mouse_position()
		var old_hover := _hovered_plot_idx
		_hovered_plot_idx = -1
		for i in range(_plot_areas.size()):
			var world_r := Rect2(global_position + _plot_areas[i].position, _plot_areas[i].size)
			if world_r.has_point(mouse_world):
				_hovered_plot_idx = i
				break
		if _hovered_plot_idx != old_hover:
			queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_world := get_global_mouse_position()

		# 1. NẾU ĐANG CÓ MODAL NÔNG TRẠI MỞ:
		var active_modal := _get_active_modal()
		if active_modal != null:
			# A. Nếu nhấp vào bên trong khung modal đang hiển thị:
			if _is_mouse_inside_modal(active_modal):
				# Để GUI của modal (Button, Drag window, Text...) tự xử lý bình thường.
				# Tuyệt đối không kiểm tra ô đất phía sau, không làm ảnh hưởng đến đất!
				return

			# B. Nếu nhấp ra ngoài modal (vào vùng đất trống hoặc ô đất phía sau/bên ngoài modal):
			# Theo đúng chuẩn UX Modal: Đóng modal hiện tại và nuốt sự kiện click (set_input_as_handled)
			# để TUYỆT ĐỐI KHÔNG làm ảnh hưởng đến đất và nhân vật phía sau!
			get_viewport().set_input_as_handled()
			_close_all_modals()
			return

		# 2. Nếu click trúng UI Control khác (ví dụ nút FarmHud, thanh Chat, MiniMap...) -> bỏ qua không chọn luống
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null:
			var cur: Node = hovered
			while cur != null:
				if cur is Window:
					break
				if cur.name in ["FarmHud", "FarmRightPanel", "WeatherVFX", "MiniMap", "ChatWindow", "QuickItemBar", "SkillBarUI"]:
					return
				cur = cur.get_parent()

		# 3. Kiểm tra xem người dùng có nhấp vào một thửa ruộng (luống đất) hay không (CHỈ KHI KHÔNG CÓ MODAL NÀO ĐANG MỞ)
		var clicked_idx := -1
		for i in range(_plot_areas.size()):
			var world_r := Rect2(global_position + _plot_areas[i].position, _plot_areas[i].size)
			if world_r.has_point(mouse_world):
				clicked_idx = i
				break

		# Nếu nhấp vào thửa ruộng -> Mở modal thông tin của thửa ruộng đó
		if clicked_idx >= 0:
			get_viewport().set_input_as_handled()
			_handle_luong_click(clicked_idx)
			return

## Xử lý khi người dùng nhấp vào một slot đất
func _handle_luong_click(idx: int) -> void:
	if farm_mgr == null or farm_mgr.plot_mgr == null:
		return
	var plots = farm_mgr.plot_mgr.plots
	if idx >= plots.size():
		return
	var p: PlotManager.PlotInfo = plots[idx]

	# Slot chưa kích hoạt -> Mở bảng xác nhận Mua Đất Cấp 1
	if not p.is_unlocked:
		_open_unlock_modal(idx)
		return

	# Slot đã kích hoạt -> Mở Bảng Tùy Chọn Đầy Đủ (Cuốc, Gieo, Tưới, Bón, Nâng cấp, Thu hoạch)
	_open_luong_modal(idx)

func _get_tree_safe() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	return Engine.get_main_loop() as SceneTree

func _get_current_gold() -> int:
	var tree := _get_tree_safe()
	if tree and tree.root:
		var gm = tree.root.get_node_or_null("GameManager")
		if gm and "profile" in gm and gm.profile:
			return int(gm.profile.gold)
	if farm_mgr and "currency_gold" in farm_mgr:
		return int(farm_mgr.currency_gold)
	return 0

## Gắn modal vào CanvasLayer độc lập (layer 120) và căn giữa màn hình mượt mà
func _get_or_create_modal_layer() -> CanvasLayer:
	var tree := _get_tree_safe()
	if tree == null or tree.root == null:
		push_error("FarmPlotsController: Không tìm thấy tree hoặc tree.root")
		return null
	var layer = tree.root.get_node_or_null("FarmModalLayer") as CanvasLayer
	if layer == null or not is_instance_valid(layer):
		layer = CanvasLayer.new()
		layer.name = "FarmModalLayer"
		layer.layer = 120
		tree.root.add_child(layer)
	return layer

func _attach_modal(win: Control, win_size: Vector2) -> void:
	win.custom_minimum_size = win_size
	win.size = win_size

	var vp_size := Vector2(1280, 720)
	var tree := _get_tree_safe()
	if tree and tree.root:
		var vs := tree.root.get_visible_rect().size
		if vs.x > 300 and vs.y > 300:
			vp_size = vs
	win.position = Vector2(
		(vp_size.x - win_size.x) * 0.5,
		(vp_size.y - win_size.y) * 0.5
	).round()

	win.mouse_filter = Control.MOUSE_FILTER_STOP
	win.add_to_group("ui_popups")
	_setup_drag_window(win)

	# Tự động dọn lớp chắn khi cửa sổ modal bị đóng
	win.tree_exited.connect(func():
		var tree_ref := _get_tree_safe()
		if tree_ref and tree_ref.root:
			var l = tree_ref.root.get_node_or_null("FarmModalLayer")
			if l and is_instance_valid(l):
				var has_modal := false
				for c in l.get_children():
					if c != win and c.name != "ModalBlocker" and is_instance_valid(c) and not c.is_queued_for_deletion():
						has_modal = true
						break
				if not has_modal:
					var b = l.get_node_or_null("ModalBlocker")
					if b and is_instance_valid(b):
						b.queue_free()
	)

	var layer := _get_or_create_modal_layer()
	if layer != null:
		# Thêm ModalBlocker chắn chuột toàn màn hình, nằm dưới modal (index 0)
		var blocker = layer.get_node_or_null("ModalBlocker") as Control
		if blocker == null or not is_instance_valid(blocker):
			blocker = Control.new()
			blocker.name = "ModalBlocker"
			blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
			blocker.mouse_filter = Control.MOUSE_FILTER_STOP
			blocker.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					get_viewport().set_input_as_handled()
					_close_all_modals()
			)
			layer.add_child(blocker)
		layer.move_child(blocker, 0)
		layer.add_child(win)
	else:
		add_child(win)

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

## Kiểm tra con trỏ chuột có đang nằm trên modal (chính xác tuyệt đối trong mọi tỉ lệ/độ phân giải màn hình)
func _is_mouse_inside_modal(modal: Control) -> bool:
	if modal == null or not is_instance_valid(modal) or not modal.is_visible_in_tree():
		return false
	# 1. Kiểm tra toạ độ cục bộ của modal
	var local_m := modal.get_local_mouse_position()
	if Rect2(Vector2.ZERO, modal.size).has_point(local_m):
		return true
	# 2. Kiểm tra global rect
	if modal.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return true
	# 3. Kiểm tra control đang hover trong hệ thống GUI
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and (hovered == modal or modal.is_ancestor_of(hovered)):
		return true
	return false

func _get_active_modal() -> Control:
	var tree := _get_tree_safe()
	if tree and tree.root:
		var layer = tree.root.get_node_or_null("FarmModalLayer")
		if layer and is_instance_valid(layer):
			for child in layer.get_children():
				if child.name == "ModalBlocker":
					continue
				if child is Control and is_instance_valid(child) and not child.is_queued_for_deletion() and child.is_visible_in_tree():
					return child
		for modal_name in ["LuongActionModal", "PlotUnlockModal", "SeedPickerModal", "AnimalActionModal", "FishActionModal"]:
			var m = tree.root.get_node_or_null(modal_name) as Control
			if m and is_instance_valid(m) and not m.is_queued_for_deletion() and m.is_visible_in_tree():
				return m
	return null

func _close_all_modals() -> void:
	var tree := _get_tree_safe()
	if tree and tree.root:
		var layer = tree.root.get_node_or_null("FarmModalLayer")
		if layer and is_instance_valid(layer):
			for child in layer.get_children():
				child.queue_free()
		for modal_name in ["PlotUnlockModal", "LuongActionModal", "SeedPickerModal", "AnimalActionModal", "FishActionModal"]:
			var existing = tree.root.get_node_or_null(modal_name)
			if existing and is_instance_valid(existing):
				existing.queue_free()

## Bảng Mua Đất Mới (Khai hoang mở rộng luống đất thành Đất Cấp 1)
func _open_unlock_modal(idx: int) -> void:
	_close_all_modals()

	var cost: int = farm_mgr.plot_mgr.get_unlock_cost(idx)
	var win := PanelContainer.new()
	win.name = "PlotUnlockModal"

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.10, 0.12, 0.98)
	bg.border_color = Color(0.95, 0.8, 0.3)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 18
	bg.content_margin_top = 14
	bg.content_margin_right = 18
	bg.content_margin_bottom = 14
	win.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	win.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "🚜 KHAI HOANG MỞ ĐẤT — LUỐNG %d" % (idx + 1)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title_lbl.add_theme_font_size_override("font_size", 15)
	header.add_child(title_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_close_all_modals)
	header.add_child(close_btn)
	vbox.add_child(header)

	var desc_lbl := Label.new()
	desc_lbl.text = "Luống đất này đang ở trạng thái hoang sơ.\nKhai hoang để sở hữu Đất Cấp 1 màu mỡ bắt đầu canh tác gieo trồng!"
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vbox.add_child(desc_lbl)

	var cost_lbl := Label.new()
	var current_gold: int = _get_current_gold()
	cost_lbl.text = "💰 Chi phí khai hoang: %d Lượng  (Hiện có: %d Lượng)" % [cost, current_gold]
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(cost_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "🛒 Mua Đất Cấp 1 (%d Lượng)" % cost
	buy_btn.custom_minimum_size = Vector2(0, 38)
	buy_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(buy_btn, Color(0.20, 0.46, 0.22, 0.96), Color(0.5, 0.95, 0.45), Color(0.95, 1.0, 0.92), 6)

	buy_btn.pressed.connect(func():
		if farm_mgr and farm_mgr.buy_item_with_currency(cost, 0):
			var res = farm_mgr.plot_mgr.unlock_plot(idx)
			farm_mgr.save_farm_data()
			_show_floating_text(res.get("msg", "Đã khai hoang đất!"), _plot_areas[idx].get_center())
			win.queue_free()
			queue_redraw()
			# Mở ngay menu thao tác của luống đất vừa mua
			_open_luong_modal(idx)
		else:
			buy_btn.text = "Không đủ ngân lượng để mua đất!"
	)
	vbox.add_child(buy_btn)

	_attach_modal(win, Vector2(420, 240))

## Bảng Tùy Chọn Đầy Đủ khi nhấp vào slot đất:
## - Bên Trái: Thông tin Luống, Thời gian thu hoạch, Mức nước, Mức bón phân, Nút "Tưới nước", "Bón phân", "Thu hoạch"
## - Bên Phải: Kho nguyên liệu phân rõ Nước tưới, Phân bón, Hạt giống còn lại và nút Mua thêm nhanh
func _open_luong_modal(idx: int) -> void:
	_close_all_modals()

	var plots = farm_mgr.plot_mgr.plots
	var p: PlotManager.PlotInfo = plots[idx]

	var win := PanelContainer.new()
	win.name = "LuongActionModal"

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.10, 0.12, 0.98)
	bg.border_color = Color(0.9, 0.78, 0.3)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 14
	bg.content_margin_top = 10
	bg.content_margin_right = 14
	bg.content_margin_bottom = 10
	win.add_theme_stylebox_override("panel", bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	win.add_child(root_vbox)

	# 1. Header
	var header := HBoxContainer.new()
	var stars := ""
	for s in range(p.level):
		stars += "⭐"
	var title_lbl := Label.new()
	title_lbl.text = "🌾 LUỐNG ĐẤT THỨ %d (%s CẤP %d/5)" % [idx + 1, stars, p.level]
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	title_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(title_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_close_all_modals)
	header.add_child(close_btn)
	root_vbox.add_child(header)

	# 2. Main 2-Side Layout
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(main_hbox)

	# ===================== BÊN TRÁI: THÔNG TIN LUỐNG ĐẤT & THAO TÁC =====================
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(left_vbox)

	# Khung trạng thái luống đất & cây trồng
	var status_panel := PanelContainer.new()
	var sp_bg := StyleBoxFlat.new()
	sp_bg.bg_color = Color(0.14, 0.16, 0.19, 0.95)
	sp_bg.border_color = Color(0.3, 0.35, 0.42)
	sp_bg.set_border_width_all(1)
	sp_bg.set_corner_radius_all(6)
	sp_bg.content_margin_left = 10
	sp_bg.content_margin_top = 8
	sp_bg.content_margin_right = 10
	sp_bg.content_margin_bottom = 8
	status_panel.add_theme_stylebox_override("panel", sp_bg)

	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 6)
	status_panel.add_child(status_vbox)

	var land_info := Label.new()
	land_info.text = "🌱 Đất Cấp %d: Tăng +%d%% tốc độ sinh trưởng của cây trồng" % [p.level, (p.level - 1) * 15]
	land_info.add_theme_font_size_override("font_size", 11)
	land_info.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	status_vbox.add_child(land_info)

	var crop_preview_hbox := HBoxContainer.new()
	crop_preview_hbox.add_theme_constant_override("separation", 10)
	var crop_preview_tr := TextureRect.new()
	crop_preview_tr.custom_minimum_size = Vector2(38, 38)
	crop_preview_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crop_preview_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crop_preview_tr.visible = false
	crop_preview_hbox.add_child(crop_preview_tr)

	var crop_name_lbl := Label.new()
	crop_name_lbl.add_theme_font_size_override("font_size", 12)
	crop_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crop_preview_hbox.add_child(crop_name_lbl)
	status_vbox.add_child(crop_preview_hbox)

	# 2.1 Thời gian thu hoạch
	var harvest_box := VBoxContainer.new()
	harvest_box.add_theme_constant_override("separation", 2)
	var harvest_lbl := Label.new()
	harvest_lbl.add_theme_font_size_override("font_size", 11)
	harvest_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	harvest_box.add_child(harvest_lbl)

	var harvest_bar := ProgressBar.new()
	harvest_bar.min_value = 0.0
	harvest_bar.max_value = 100.0
	harvest_bar.value = p.get_progress() * 100.0
	harvest_bar.custom_minimum_size = Vector2(0, 10)
	harvest_bar.show_percentage = false
	var hv_fill := StyleBoxFlat.new()
	hv_fill.bg_color = Color(0.2, 0.75, 1.0)
	hv_fill.set_corner_radius_all(3)
	harvest_bar.add_theme_stylebox_override("fill", hv_fill)
	harvest_box.add_child(harvest_bar)
	status_vbox.add_child(harvest_box)

	# 2.2 Mức nước (Độ ẩm đất)
	var water_box := VBoxContainer.new()
	water_box.add_theme_constant_override("separation", 2)
	var water_lbl := Label.new()
	water_lbl.add_theme_font_size_override("font_size", 11)
	water_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	water_box.add_child(water_lbl)

	var water_bar := ProgressBar.new()
	water_bar.min_value = 0.0
	water_bar.max_value = 3.0
	water_bar.value = float(p.watered_count)
	water_bar.custom_minimum_size = Vector2(0, 10)
	water_bar.show_percentage = false
	var wb_fill := StyleBoxFlat.new()
	wb_fill.bg_color = Color(0.25, 0.65, 0.95)
	wb_fill.set_corner_radius_all(3)
	water_bar.add_theme_stylebox_override("fill", wb_fill)
	water_box.add_child(water_bar)
	status_vbox.add_child(water_box)

	# 2.3 Mức bón phân
	var fert_box := VBoxContainer.new()
	fert_box.add_theme_constant_override("separation", 2)
	var fert_lbl := Label.new()
	fert_lbl.add_theme_font_size_override("font_size", 11)
	fert_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	fert_box.add_child(fert_lbl)

	var fert_bar := ProgressBar.new()
	fert_bar.min_value = 0.0
	fert_bar.max_value = 1.0
	fert_bar.value = 1.0 if p.is_fertilized else 0.0
	fert_bar.custom_minimum_size = Vector2(0, 10)
	fert_bar.show_percentage = false
	var fb_fill := StyleBoxFlat.new()
	fb_fill.bg_color = Color(0.25, 0.85, 0.35)
	fb_fill.set_corner_radius_all(3)
	fert_bar.add_theme_stylebox_override("fill", fb_fill)
	fert_box.add_child(fert_bar)
	status_vbox.add_child(fert_box)
	left_vbox.add_child(status_panel)

	# DANH SÁCH THAO TÁC LUỐNG ĐẤT (DẠNG DANH SÁCH DỌC - FULL WIDTH)
	var action_list := VBoxContainer.new()
	action_list.add_theme_constant_override("separation", 6)

	var hoe_btn := Button.new()
	hoe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hoe_btn.custom_minimum_size = Vector2(0, 32)
	hoe_btn.focus_mode = Control.FOCUS_NONE
	hoe_btn.text = "⛏️ Cuốc Xới Đất"
	_apply_prominent_button_style(hoe_btn, Color(0.42, 0.28, 0.14, 0.96), Color(0.85, 0.65, 0.35), Color(1.0, 0.95, 0.85), 6)
	hoe_btn.pressed.connect(func():
		if farm_mgr.plot_mgr.till_plot(idx):
			farm_mgr.save_farm_data()
			_show_floating_text("⛏️ Đã cuốc đất Luống %d tơi xốp!" % (idx + 1), _plot_areas[idx].get_center())
			queue_redraw()
	)
	action_list.add_child(hoe_btn)

	var plant_btn := Button.new()
	plant_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plant_btn.custom_minimum_size = Vector2(0, 32)
	plant_btn.focus_mode = Control.FOCUS_NONE
	plant_btn.text = "🌱 Gieo Hạt Giống"
	_apply_prominent_button_style(plant_btn, Color(0.18, 0.44, 0.22, 0.96), Color(0.45, 0.92, 0.5), Color(0.92, 1.0, 0.92), 6)
	plant_btn.pressed.connect(func():
		win.queue_free()
		_open_seed_picker_for_plot(idx)
	)
	action_list.add_child(plant_btn)

	var water_btn := Button.new()
	water_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	water_btn.custom_minimum_size = Vector2(0, 32)
	water_btn.focus_mode = Control.FOCUS_NONE
	water_btn.text = "💧 Tưới Nước"
	_apply_prominent_button_style(water_btn, Color(0.12, 0.38, 0.68, 0.96), Color(0.45, 0.88, 1.0), Color(0.92, 0.98, 1.0), 6)
	action_list.add_child(water_btn)

	var fert_btn := Button.new()
	fert_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fert_btn.custom_minimum_size = Vector2(0, 32)
	fert_btn.focus_mode = Control.FOCUS_NONE
	fert_btn.text = "🧪 Bón Phân"
	_apply_prominent_button_style(fert_btn, Color(0.14, 0.46, 0.24, 0.96), Color(0.48, 0.95, 0.55), Color(0.92, 1.0, 0.92), 6)
	action_list.add_child(fert_btn)

	var harvest_btn := Button.new()
	harvest_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harvest_btn.custom_minimum_size = Vector2(0, 32)
	harvest_btn.focus_mode = Control.FOCUS_NONE
	harvest_btn.text = "✨ Thu Hoạch"
	_apply_prominent_button_style(harvest_btn, Color(0.72, 0.52, 0.12, 0.96), Color(1.0, 0.95, 0.45), Color(1.0, 1.0, 0.88), 6)
	action_list.add_child(harvest_btn)

	# Nâng cấp luống đất
	if p.level < 5:
		var upgrade_btn := Button.new()
		var next_lvl := p.level + 1
		var cost := p.level * 100
		upgrade_btn.text = "⭐ Nâng Cấp Luống Lên Cấp %d (%d Lượng + 1 Cuốc Thép)" % [next_lvl, cost]
		upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_btn.custom_minimum_size = Vector2(0, 32)
		upgrade_btn.focus_mode = Control.FOCUS_NONE
		_apply_prominent_button_style(upgrade_btn, Color(0.18, 0.34, 0.5, 0.96), Color(0.42, 0.88, 1.0), Color(1.0, 1.0, 0.9), 6)
		upgrade_btn.pressed.connect(func():
			if farm_mgr == null:
				return
			if farm_mgr.get_tool_hoe_count() <= 0:
				upgrade_btn.text = "Thiếu Cuốc Thép!"
				_show_floating_text("⛏️ Cần có Cuốc Thép để nâng cấp luống! Hãy mua ở cột bên phải.", _plot_areas[idx].get_center())
				var tree := _get_tree_safe()
				if tree:
					var err_t := tree.create_timer(1.5)
					err_t.timeout.connect(func():
						if is_instance_valid(upgrade_btn):
							upgrade_btn.text = "⭐ Nâng Cấp Luống Lên Cấp %d (%d Lượng + 1 Cuốc Thép)" % [next_lvl, cost]
					)
				return
			if not farm_mgr.buy_item_with_currency(cost, 0):
				upgrade_btn.text = "Không đủ ngân lượng!"
				_show_floating_text("Không đủ ngân lượng!", _plot_areas[idx].get_center())
				var tree := _get_tree_safe()
				if tree:
					var err_t := tree.create_timer(1.5)
					err_t.timeout.connect(func():
						if is_instance_valid(upgrade_btn):
							upgrade_btn.text = "⭐ Nâng Cấp Luống Lên Cấp %d (%d Lượng + 1 Cuốc Thép)" % [next_lvl, cost]
					)
				return
			farm_mgr.use_tool_hoe(1)
			var res = farm_mgr.plot_mgr.upgrade_plot(idx)
			farm_mgr.save_farm_data()
			_show_floating_text(res.get("msg", "Đã nâng cấp luống!"), _plot_areas[idx].get_center())
			win.queue_free()
			queue_redraw()
		)
		action_list.add_child(upgrade_btn)

	left_vbox.add_child(action_list)

	# ===================== BÊN PHẢI: KHO NGUYÊN LIỆU (NƯỚC, PHÂN BÓN, HẠT GIỐNG) =====================
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(230, 0)
	var rp_bg := StyleBoxFlat.new()
	rp_bg.bg_color = Color(0.12, 0.14, 0.17, 0.98)
	rp_bg.border_color = Color(0.75, 0.65, 0.25)
	rp_bg.set_border_width_all(1)
	rp_bg.set_corner_radius_all(6)
	rp_bg.content_margin_left = 10
	rp_bg.content_margin_top = 8
	rp_bg.content_margin_right = 10
	rp_bg.content_margin_bottom = 8
	right_panel.add_theme_stylebox_override("panel", rp_bg)
	main_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_vbox)

	var right_title := Label.new()
	right_title.text = "📦 NGUYÊN LIỆU TRONG KHO"
	right_title.add_theme_font_size_override("font_size", 12)
	right_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(right_title)

	right_vbox.add_child(HSeparator.new())

	# Box 1: Nước tưới
	var water_stock_box := VBoxContainer.new()
	water_stock_box.add_theme_constant_override("separation", 2)
	var w_lbl := Label.new()
	w_lbl.text = "💧 NƯỚC TƯỚI CÂY TRỒNG:"
	w_lbl.add_theme_font_size_override("font_size", 11)
	w_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	water_stock_box.add_child(w_lbl)

	var water_stock_lbl := Label.new()
	water_stock_lbl.add_theme_font_size_override("font_size", 11)
	water_stock_box.add_child(water_stock_lbl)

	var buy_water_btn := Button.new()
	buy_water_btn.text = "[+] Lấy Nước (5 Lg / 10)"
	buy_water_btn.custom_minimum_size = Vector2(0, 28)
	buy_water_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(buy_water_btn, Color(0.12, 0.32, 0.52, 0.95), Color(0.4, 0.8, 1.0), Color(0.9, 0.98, 1.0), 5)
	buy_water_btn.pressed.connect(func():
		if farm_mgr and farm_mgr.buy_item_with_currency(5, 0):
			farm_mgr.add_to_chest("fresh_water_pot", 10, true)
			farm_mgr.save_farm_data()
			_show_floating_text("Đã lấy thêm 10 Bình Nước Tưới!", _plot_areas[idx].get_center())
		else:
			_show_floating_text("Không đủ ngân lượng!", _plot_areas[idx].get_center())
	)
	water_stock_box.add_child(buy_water_btn)
	right_vbox.add_child(water_stock_box)

	right_vbox.add_child(HSeparator.new())

	# Box 2: Phân bón
	var fert_stock_box := VBoxContainer.new()
	fert_stock_box.add_theme_constant_override("separation", 2)
	var f_lbl := Label.new()
	f_lbl.text = "🧪 PHÂN BÓN VI SINH:"
	f_lbl.add_theme_font_size_override("font_size", 11)
	f_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	fert_stock_box.add_child(f_lbl)

	var fert_stock_lbl := Label.new()
	fert_stock_lbl.add_theme_font_size_override("font_size", 11)
	fert_stock_box.add_child(fert_stock_lbl)

	var buy_fert_btn := Button.new()
	buy_fert_btn.text = "[+] Mua Phân (10 Lg / 5)"
	buy_fert_btn.custom_minimum_size = Vector2(0, 28)
	buy_fert_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(buy_fert_btn, Color(0.14, 0.4, 0.22, 0.95), Color(0.45, 0.85, 0.45), Color(0.9, 1.0, 0.9), 5)
	buy_fert_btn.pressed.connect(func():
		if farm_mgr and farm_mgr.buy_item_with_currency(10, 0):
			farm_mgr.add_to_chest("fertilizer", 5, true)
			farm_mgr.save_farm_data()
			_show_floating_text("Đã mua thêm 5 Bao Phân Bón Vi Sinh!", _plot_areas[idx].get_center())
		else:
			_show_floating_text("Không đủ ngân lượng!", _plot_areas[idx].get_center())
	)
	fert_stock_box.add_child(buy_fert_btn)
	right_vbox.add_child(fert_stock_box)

	right_vbox.add_child(HSeparator.new())

	# Box 3: Cuốc Thép Nâng Cấp
	var hoe_stock_box := VBoxContainer.new()
	hoe_stock_box.add_theme_constant_override("separation", 2)
	var h_lbl := Label.new()
	h_lbl.text = "⛏️ CUỐC THÉP NÂNG CẤP:"
	h_lbl.add_theme_font_size_override("font_size", 11)
	h_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	hoe_stock_box.add_child(h_lbl)

	var hoe_stock_lbl := Label.new()
	hoe_stock_lbl.add_theme_font_size_override("font_size", 11)
	hoe_stock_box.add_child(hoe_stock_lbl)

	var buy_hoe_btn := Button.new()
	buy_hoe_btn.text = "[+] Mua Cuốc Thép (50 Lg)"
	buy_hoe_btn.custom_minimum_size = Vector2(0, 28)
	buy_hoe_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(buy_hoe_btn, Color(0.35, 0.25, 0.12, 0.95), Color(0.9, 0.75, 0.35), Color(1.0, 0.95, 0.85), 5)
	buy_hoe_btn.pressed.connect(func():
		if farm_mgr and farm_mgr.buy_item_with_currency(50, 0):
			farm_mgr.add_to_chest("tool_hoe", 1, true)
			farm_mgr.save_farm_data()
			_show_floating_text("Đã mua thêm 1 Cuốc Thép Khai Hoang!", _plot_areas[idx].get_center())
		else:
			_show_floating_text("Không đủ ngân lượng!", _plot_areas[idx].get_center())
	)
	hoe_stock_box.add_child(buy_hoe_btn)
	right_vbox.add_child(hoe_stock_box)

	right_vbox.add_child(HSeparator.new())

	# Box 4: Hạt giống
	var seed_stock_box := VBoxContainer.new()
	seed_stock_box.add_theme_constant_override("separation", 2)
	var s_lbl := Label.new()
	s_lbl.text = "🌱 HẠT GIỐNG TRONG KHO:"
	s_lbl.add_theme_font_size_override("font_size", 11)
	s_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	seed_stock_box.add_child(s_lbl)

	var seed_stock_lbl := Label.new()
	seed_stock_lbl.add_theme_font_size_override("font_size", 11)
	seed_stock_box.add_child(seed_stock_lbl)

	var buy_seed_btn := Button.new()
	buy_seed_btn.text = "[+] Mua Hạt Giống (15 Lg / 6)"
	buy_seed_btn.custom_minimum_size = Vector2(0, 28)
	buy_seed_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(buy_seed_btn, Color(0.42, 0.32, 0.12, 0.95), Color(0.95, 0.8, 0.35), Color(1.0, 0.95, 0.85), 5)
	buy_seed_btn.pressed.connect(func():
		if farm_mgr and farm_mgr.buy_item_with_currency(15, 0):
			farm_mgr.add_to_chest("seed_rice", 3, true)
			farm_mgr.add_to_chest("seed_cabbage", 3, true)
			farm_mgr.save_farm_data()
			_show_floating_text("Đã mua Gói Hạt Giống (3 Lúa + 3 Cải)!", _plot_areas[idx].get_center())
		else:
			_show_floating_text("Không đủ ngân lượng!", _plot_areas[idx].get_center())
	)
	seed_stock_box.add_child(buy_seed_btn)
	right_vbox.add_child(seed_stock_box)

	right_vbox.add_child(HSeparator.new())

	# Box 4: Ngân lượng
	var gold_lbl := Label.new()
	gold_lbl.add_theme_font_size_override("font_size", 11)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	right_vbox.add_child(gold_lbl)

	# Gắn sự kiện các nút Tưới Nước, Bón Phân, Thu Hoạch
	water_btn.pressed.connect(func():
		if p.state != PlotManager.PlotState.PLANTED:
			_show_floating_text("Chưa có cây trồng để tưới nước!", _plot_areas[idx].get_center())
			return
		if p.watered_count >= 3:
			_show_floating_text("Đất đã đủ ẩm (3/3 lần)!", _plot_areas[idx].get_center())
			return
		if farm_mgr == null or farm_mgr.get_water_count() <= 0:
			_show_floating_text("Hết nước tưới! Bấm nút [+ Lấy Nước] ở cột bên phải.", _plot_areas[idx].get_center())
			return
		farm_mgr.use_water(1)
		farm_mgr.plot_mgr.water_plot(idx)
		farm_mgr.save_farm_data()
		_show_floating_text("💧 Đã tưới nước cho Luống %d!" % (idx + 1), _plot_areas[idx].get_center())
		queue_redraw()
	)

	fert_btn.pressed.connect(func():
		if p.state != PlotManager.PlotState.PLANTED:
			_show_floating_text("Chưa có cây trồng để bón phân!", _plot_areas[idx].get_center())
			return
		if p.is_fertilized:
			_show_floating_text("Luống đã được bón phân vi sinh!", _plot_areas[idx].get_center())
			return
		if farm_mgr == null or farm_mgr.get_fertilizer_count() <= 0:
			_show_floating_text("Hết phân bón! Bấm nút [+ Mua Phân] ở cột bên phải.", _plot_areas[idx].get_center())
			return
		farm_mgr.use_fertilizer(1)
		farm_mgr.plot_mgr.fertilize_plot(idx)
		farm_mgr.save_farm_data()
		_show_floating_text("🧪 Đã bón phân vi sinh cho Luống %d!" % (idx + 1), _plot_areas[idx].get_center())
		queue_redraw()
	)

	harvest_btn.pressed.connect(func():
		if p.state == PlotManager.PlotState.HARVESTABLE:
			_harvest(idx)
			win.queue_free()
		else:
			_show_floating_text("Nông sản chưa chín, chưa thể thu hoạch!", _plot_areas[idx].get_center())
	)

	# Cập nhật thông số trực tiếp mỗi 0.25s
	var update_stats := func():
		if not is_instance_valid(win) or p == null or farm_mgr == null:
			return

		# Cập nhật ảnh xem trước cây trồng / hạt giống
		var p_tex: Texture2D = null
		if p.state == PlotManager.PlotState.PLANTED or p.state == PlotManager.PlotState.HARVESTABLE:
			var prog_val := p.get_progress()
			var pl := PlantData.get_plant(p.plant_id)
			if prog_val < 0.22:
				p_tex = _get_texture_safe("res://assets/farm/crops/seed.png")
			elif prog_val < 0.48:
				p_tex = _get_texture_safe("res://assets/farm/crops/sprout.png")
			elif prog_val < 0.85 and pl and pl.sprite_growing != "":
				p_tex = _get_texture_safe(pl.sprite_growing)
			elif pl and pl.sprite_mature != "":
				p_tex = _get_texture_safe(pl.sprite_mature)
			elif pl and pl.icon_path != "":
				p_tex = _get_texture_safe(pl.icon_path)
		crop_preview_tr.visible = (p_tex != null)
		crop_preview_tr.texture = p_tex

		# 1. Trạng thái đất và cây trồng
		match p.state:
			PlotManager.PlotState.UNTILLED:
				crop_name_lbl.text = "Trạng thái: Đất cỏ hoang sơ (Cần cuốc đất xới tơi)"
				crop_name_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
				harvest_lbl.text = "⏳ Chưa gieo trồng"
				harvest_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
				harvest_bar.value = 0.0
				hoe_btn.visible = true
				hoe_btn.disabled = false
				plant_btn.visible = false
				water_btn.visible = false
				fert_btn.visible = false
				harvest_btn.visible = false
			PlotManager.PlotState.TILLED:
				crop_name_lbl.text = "Trạng thái: Đất màu mỡ đã cày xới (Sẵn sàng gieo hạt)"
				crop_name_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
				harvest_lbl.text = "🌱 Chờ gieo hạt giống"
				harvest_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
				harvest_bar.value = 0.0
				hoe_btn.visible = false
				plant_btn.visible = true
				plant_btn.disabled = false
				water_btn.visible = false
				fert_btn.visible = false
				harvest_btn.visible = false
			PlotManager.PlotState.PLANTED:
				hoe_btn.visible = false
				plant_btn.visible = false
				var plant := PlantData.get_plant(p.plant_id)
				var pname := plant.name if plant else "Cây trồng"
				var prog_pct := int(p.get_progress() * 100)
				crop_name_lbl.text = "🌾 Cây Trồng: %s (Tiến độ sinh trưởng: %d%%)" % [pname, prog_pct]
				crop_name_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))

				var rem_sec := int(p.get_remaining_time())
				var mins := rem_sec / 60
				var secs := rem_sec % 60
				harvest_lbl.text = "⏳ Thời Gian Thu Hoạch Còn: %02d:%02d (Tiến độ %d%%)" % [mins, secs, prog_pct]
				harvest_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
				harvest_bar.value = prog_pct
				hv_fill.bg_color = Color(0.2, 0.75, 1.0)

				water_btn.visible = true
				water_btn.disabled = (p.watered_count >= 3)
				water_btn.text = "💧 Tưới Nước (%d/3 lần) [+20%%]" % p.watered_count
				fert_btn.visible = true
				fert_btn.disabled = p.is_fertilized
				fert_btn.text = "🧪 Đã Bón Phân Vi Sinh" if p.is_fertilized else "🧪 Bón Phân Vi Sinh [+30%% Tốc độ]"
				harvest_btn.visible = true
				harvest_btn.disabled = true
				harvest_btn.text = "⏳ Chưa Chín (%d%%)" % prog_pct
				_apply_prominent_button_style(harvest_btn, Color(0.28, 0.24, 0.36, 0.96), Color(0.72, 0.62, 0.85), Color(0.92, 0.9, 0.98), 6)
			PlotManager.PlotState.HARVESTABLE:
				hoe_btn.visible = false
				plant_btn.visible = false
				var plant := PlantData.get_plant(p.plant_id)
				var pname := plant.name if plant else "Nông sản"
				crop_name_lbl.text = "✨ %s đã chín vàng rực rỡ, sẵn sàng thu hoạch!" % pname
				crop_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))

				harvest_lbl.text = "✨ ĐÃ CHÍN VÀNG! SẴN SÀNG THU HOẠCH! (100%)"
				harvest_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
				harvest_bar.value = 100.0
				hv_fill.bg_color = Color(1.0, 0.85, 0.2)

				water_btn.visible = false
				fert_btn.visible = false
				harvest_btn.visible = true
				harvest_btn.disabled = false
				harvest_btn.text = "✨ THU HOẠCH NÔNG SẢN NGAY ✨"
				_apply_prominent_button_style(harvest_btn, Color(0.72, 0.52, 0.12, 0.96), Color(1.0, 0.95, 0.45), Color(1.0, 1.0, 0.88), 6)

		# 2. Mức nước và Mức bón phân
		water_bar.value = float(p.watered_count)
		var w_bonus := p.watered_count * 20
		water_lbl.text = "💧 Mức Nước: %d / 3 lần (+%d%% Tốc độ)" % [p.watered_count, w_bonus]

		fert_bar.value = 1.0 if p.is_fertilized else 0.0
		if p.is_fertilized:
			fert_lbl.text = "🧪 Mức Bón Phân: ĐÃ BÓN PHÂN VI SINH (+30% Tốc độ sinh trưởng) ✨"
			fert_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.45))
		else:
			fert_lbl.text = "🧪 Mức Bón Phân: Chưa bón phân vi sinh (0%)"
			fert_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

		# 3. Kho nguyên liệu bên phải
		var water_cnt: int = farm_mgr.get_water_count()
		water_stock_lbl.text = "Hiện có: %d bình nước" % water_cnt
		water_stock_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if water_cnt > 0 else Color(1.0, 0.4, 0.4))

		var fert_cnt: int = farm_mgr.get_fertilizer_count()
		fert_stock_lbl.text = "Hiện có: %d bao phân" % fert_cnt
		fert_stock_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if fert_cnt > 0 else Color(1.0, 0.4, 0.4))

		var hoe_cnt: int = farm_mgr.get_tool_hoe_count() if farm_mgr else 0
		hoe_stock_lbl.text = "Hiện có: %d cái" % hoe_cnt
		hoe_stock_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if hoe_cnt > 0 else Color(1.0, 0.4, 0.4))

		var rice_cnt: int = int(farm_mgr.farm_chest_supplies.get("seed_rice", 0))
		var cab_cnt: int = int(farm_mgr.farm_chest_supplies.get("seed_cabbage", 0))
		var total_seeds := rice_cnt + cab_cnt
		seed_stock_lbl.text = "Lúa Vàng: x%d | Bắp Cải: x%d" % [rice_cnt, cab_cnt]
		seed_stock_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if total_seeds > 0 else Color(1.0, 0.4, 0.4))

		gold_lbl.text = "💰 Ngân Lượng: %d Lượng" % _get_current_gold()

	update_stats.call()

	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(update_stats)
	win.add_child(timer)

	_attach_modal(win, Vector2(640, 520))

## Bảng chọn hạt giống khi bấm Trồng Cây
func _open_seed_picker_for_plot(idx: int) -> void:
	_close_all_modals()

	var win := PanelContainer.new()
	win.name = "SeedPickerModal"

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.10, 0.12, 0.98)
	bg.border_color = Color(0.4, 0.85, 0.4)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 14
	bg.content_margin_top = 12
	bg.content_margin_right = 14
	bg.content_margin_bottom = 12
	win.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	win.add_child(vbox)

	var header := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "🌱 CHỌN HẠT GIỐNG CHO LUỐNG THỨ %d" % (idx + 1)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	title_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(title_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func():
		win.queue_free()
		_open_luong_modal(idx)
	)
	header.add_child(close_btn)
	vbox.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

	var plants := PlantData.get_all_plants()
	for p in plants:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		var icon_tex := _get_texture_safe(p.sprite_mature)
		if icon_tex == null and p.icon_path != "":
			icon_tex = _get_texture_safe(p.icon_path)
		if icon_tex == null:
			icon_tex = _get_texture_safe("res://assets/farm/crops/seed.png")
		if icon_tex != null:
			var icon_tr := TextureRect.new()
			icon_tr.custom_minimum_size = Vector2(32, 32)
			icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_tr.texture = icon_tex
			row.add_child(icon_tr)

		var name_lbl := Label.new()
		name_lbl.text = p.name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
		row.add_child(name_lbl)

		var time_lbl := Label.new()
		time_lbl.text = "%d phút" % [p.grow_time_seconds / 60]
		time_lbl.custom_minimum_size = Vector2(70, 0)
		time_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		time_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(time_lbl)

		var plant_b := Button.new()
		plant_b.text = "Gieo"
		plant_b.custom_minimum_size = Vector2(70, 30)
		plant_b.focus_mode = Control.FOCUS_NONE
		_apply_prominent_button_style(plant_b)
		plant_b.pressed.connect(func():
			if farm_mgr.plot_mgr.plant_seed(idx, p.id):
				farm_mgr.save_farm_data()
				_show_floating_text("🌱 Đã gieo %s vào Luống %d!" % [p.name, idx + 1], _plot_areas[idx].get_center())
				win.queue_free()
				queue_redraw()
				_open_luong_modal(idx)
		)
		row.add_child(plant_b)

		list_vbox.add_child(row)

	var footer := HBoxContainer.new()
	var back_btn := Button.new()
	back_btn.text = "⬅️ Quay Lại Bảng Luống %d" % (idx + 1)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.custom_minimum_size = Vector2(0, 32)
	back_btn.focus_mode = Control.FOCUS_NONE
	_apply_prominent_button_style(back_btn)
	back_btn.pressed.connect(func():
		win.queue_free()
		_open_luong_modal(idx)
	)
	footer.add_child(back_btn)
	vbox.add_child(footer)

	_attach_modal(win, Vector2(440, 400))

func _harvest(idx: int) -> void:
	var res = farm_mgr.plot_mgr.harvest_plot(idx)
	if res.get("success", false):
		var exp_reward: int = res.get("exp", 50)
		var plant_name: String = str(res.get("plant_name", "Nông Sản"))
		var plant_id: String = str(res.get("plant_id", ""))

		farm_mgr.add_to_chest(plant_id, 1, false)
		farm_mgr.add_farm_exp(exp_reward)
		farm_mgr.save_farm_data()
		queue_redraw()

		_show_floating_text("✨ Thu hoạch %s thành công!\n(+%d Exp nông trại)" % [plant_name, exp_reward], _plot_areas[idx].get_center())

func _has_any_modal_open() -> bool:
	return _get_active_modal() != null

func _show_floating_text(text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos - Vector2(100, 30)
	lbl.custom_minimum_size = Vector2(200, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 20
	add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 35, 1.5)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.tween_callback(lbl.queue_free)

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
