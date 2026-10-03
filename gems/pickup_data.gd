extends Resource
class_name PickupData

enum PickupType {
	HEAL,
	MAGNET,
}

@export var pickup_type: PickupType = PickupType.HEAL

## Tỷ lệ rớt ra khi quái chết, từ 0.0 (không bao giờ) tới 1.0 (luôn luôn)
@export_range(0.0, 1.0) var drop_chance: float = 0.05

@export var texture: Texture2D

## Dùng cho HEAL: lượng máu hồi phục
@export var heal_amount: float = 20.0
