extends Resource
class_name UpgradeData

enum StatType {
	PROJECTILE_COUNT,
	DAMAGE,
	ATTACK_SPEED,
	RANGE,
}

## ID duy nhất để tránh trùng/nhận diện — VD "damage_up", "double_shot"
@export var id: String = ""

@export var title: String = ""
@export var description: String = ""
@export var icon: Texture2D

@export var stat_type: StatType = StatType.DAMAGE

## Giá trị cộng thêm. Với DAMAGE/ATTACK_SPEED/RANGE là % (VD 0.3 = +30%), với PROJECTILE_COUNT là số nguyên (VD 1, 2)
@export var value: float = 0.0

## Nếu true, nâng cấp này chỉ xuất hiện 1 lần rồi biến mất khỏi vòng chọn (VD x2 số đạn)
@export var is_unique: bool = false
