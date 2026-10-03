extends Resource
class_name StoneData

## Tên hiển thị của viên đá, VD: "Đá Lửa"
@export var stone_name: String = ""

## Icon hiển thị trong UI
@export var icon: Texture2D

## Màu chủ đạo — dùng để tint projectile/hiệu ứng
@export var color: Color = Color.WHITE

@export_group("Chỉ số")
@export var damage: float = 10.0
@export var speed: float = 300.0
@export var mana_cost: float = 5.0
@export var cooldown: float = 0.5

@export_group("Hệ (dùng để kết hợp sau này)")
## VD: "fire", "ice", "lightning" — dùng để ghép công thức combo
@export var element_id: String = ""
