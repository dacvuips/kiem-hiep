extends Node2D
class_name FarmNPCController
## Quản lý 4 NPC Cửa Hàng Thật trên Nguyệt Ca Đảo (Map 1041):
## 1. NPC Mua Đồ Chăn Nuôi: Tọa độ 195/192 (passerby240 - Trương Bá)
## 2. NPC Mua Đồ Trồng Trọt: Tọa độ 191/186 (enemy110 - Thần Nông Tiên Sinh)
## 3. NPC Mua Đồ Nuôi Cá Nước Ngọt: Tọa độ 180/185 (passerby338 - Khê Hồ Ngư Nương)
## 4. NPC Mua Đồ Đánh Bắt & Nuôi Cá Biển: Tọa độ 196/197 (enemy149 - Hải Ngư Thuyền Trưởng)

# Công thức đổi tọa độ VLTK sang Pixel World: (coord + Vector2(0.5, 0.5)) * 256.0
const NPC_CONFIGS := [
	{
		"id": "npc_livestock",
		"name": "Trương Bá (Chăn Nuôi)",
		"title": "[Thương Nhân Chăn Nuôi]",
		"coord_name": "195/192",
		"world_pos": Vector2(50048.0, 49280.0),
		"res": "passerby240",
		"dir": 0,
		"category": "livestock",
		"title_color": Color(0.3, 0.9, 1.0),
		"name_color": Color(1.0, 0.88, 0.35)
	},
	{
		"id": "npc_agriculture",
		"name": "Thần Nông Tiên Sinh",
		"title": "[Điền Chủ Trồng Trọt]",
		"coord_name": "191/186",
		"world_pos": Vector2(49024.0, 47744.0),
		"res": "enemy110",
		"dir": 56,
		"category": "agriculture",
		"title_color": Color(0.4, 1.0, 0.4),
		"name_color": Color(1.0, 0.95, 0.4)
	},
	{
		"id": "npc_freshwater_fish",
		"name": "Khê Hồ Ngư Nương",
		"title": "[Ngư Nương Hồ Đầm]",
		"coord_name": "180/185",
		"world_pos": Vector2(46208.0, 47488.0),
		"res": "passerby338",
		"dir": 8,
		"category": "freshwater_fish",
		"title_color": Color(0.4, 0.85, 1.0),
		"name_color": Color(1.0, 0.85, 0.95)
	},
	{
		"id": "npc_ocean_fish",
		"name": "Hải Ngư Thuyền Trưởng",
		"title": "[Thuyền Trưởng Biển Sâu]",
		"coord_name": "196/197",
		"world_pos": Vector2(50304.0, 50560.0),
		"res": "enemy149",
		"dir": 0,
		"category": "ocean_fish",
		"title_color": Color(0.3, 0.7, 1.0),
		"name_color": Color(1.0, 0.82, 0.3)
	},
	{
		"id": "npc_meat_exchange",
		"name": "Trù Thần Sơn Trang",
		"title": "[Đổi Thịt Lấy Thưởng]",
		"coord_name": "194/191",
		"world_pos": Vector2(49792.0, 49024.0),
		"res": "passerby239",
		"dir": 0,
		"category": "meat_exchange",
		"title_color": Color(1.0, 0.65, 0.2),
		"name_color": Color(1.0, 0.9, 0.35)
	}
]

class SingleFarmNPC extends Node2D:
	var cfg: Dictionary
	var sprite: MonsterSprite
	var anim_time: float = 0.0
	var area: Area2D
	var name_label: Label
	var title_label: Label
	var sub_label: Label
	var is_hovered: bool = false
	var click_radius: float = 48.0

	func _init(config: Dictionary) -> void:
		cfg = config
		position = cfg["world_pos"]
		z_index = 10 # Vẽ theo trục Y hoặc đứng trên map

	func _ready() -> void:
		# 1. Khởi tạo MonsterSprite gốc VLTK
		sprite = MonsterSprite.new()
		sprite.set_resource(cfg["res"])
		add_child(sprite)

		# 2. Bảng tên & Danh hiệu phía trên đầu NPC
		var npc_h: float = sprite.get_height()
		if npc_h <= 10.0:
			npc_h = 95.0

		var label_y: float = -npc_h - 20.0

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 1)
		vbox.position = Vector2(-150, label_y - 28.0)
		vbox.custom_minimum_size = Vector2(300, 40)
		add_child(vbox)

		# Danh hiệu
		title_label = Label.new()
		title_label.text = cfg["title"]
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 12)
		title_label.add_theme_color_override("font_color", cfg["title_color"])
		title_label.add_theme_color_override("font_outline_color", Color.BLACK)
		title_label.add_theme_constant_override("outline_size", 3)
		vbox.add_child(title_label)

		# Tên NPC
		name_label = Label.new()
		name_label.text = cfg["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", cfg["name_color"])
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 4)
		vbox.add_child(name_label)

		# Gợi ý nhấp chuột
		sub_label = Label.new()
		sub_label.text = "💬 [%s] Nhấp để mua đồ" % cfg["coord_name"]
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 10)
		sub_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7, 0.85))
		sub_label.add_theme_color_override("font_outline_color", Color.BLACK)
		sub_label.add_theme_constant_override("outline_size", 2)
		vbox.add_child(sub_label)

		# 3. Vùng va chạm nhấp chuột (Area2D)
		area = Area2D.new()
		area.input_pickable = true
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = click_radius
		col.shape = shape
		col.position = Vector2(0, -npc_h * 0.45)
		area.add_child(col)
		area.input_event.connect(_on_area_input_event)
		area.mouse_entered.connect(_on_mouse_entered)
		area.mouse_exited.connect(_on_mouse_exited)
		add_child(area)

	func _process(delta: float) -> void:
		# Đứng thở động tác VLTK tự nhiên
		anim_time += delta * 0.8
		var prog := fmod(anim_time, 1.0)
		sprite.set_pose("stand", int(cfg.get("dir", 0)), prog)
		z_index = clampi(int(global_position.y / 20.0), -4000, 4000)

	func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			open_shop()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Kiểm tra khoảng cách chuột tới NPC để đảm bảo bấm trúng luôn nhận diện
			var mouse_world := get_global_mouse_position()
			var torso_center := global_position + Vector2(0, -40)
			if mouse_world.distance_to(torso_center) <= click_radius:
				get_viewport().set_input_as_handled()
				open_shop()

	func _on_mouse_entered() -> void:
		is_hovered = true
		sub_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1, 1.0))
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

	func _on_mouse_exited() -> void:
		is_hovered = false
		sub_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7, 0.85))
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	func open_shop() -> void:
		var root_ui: Node = get_tree().root
		var plyr = get_tree().get_first_node_in_group("player")
		if plyr:
			var main_node = plyr.get_node_or_null("/root/Main/UI")
			if main_node:
				root_ui = main_node
		var cat: String = str(cfg.get("category", ""))
		if cat == "meat_exchange":
			FarmWindows.open_meat_exchange(root_ui)
		else:
			FarmNPCShop.open_shop(root_ui, cat)

var npc_nodes: Array[SingleFarmNPC] = []

func _ready() -> void:
	name = "FarmNPCController"
	for cfg in NPC_CONFIGS:
		var npc := SingleFarmNPC.new(cfg)
		add_child(npc)
		npc_nodes.append(npc)

## Hỗ trợ dịch chuyển hoặc tìm vị trí NPC theo id hoặc category
func get_npc_position(category: String) -> Vector2:
	for cfg in NPC_CONFIGS:
		if cfg["category"] == category or cfg["id"] == category:
			return cfg["world_pos"]
	return Vector2.ZERO
