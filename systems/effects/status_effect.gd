extends RefCounted
class_name StatusEffect
## Base runtime object cho 1 trạng thái đang áp lên 1 target (Burn/Freeze/Shock/Poison/Bleed/
## Slow/Stun). KHÔNG phải Node — StatusEffectController (gắn trên Enemy/Player) sở hữu và tick
## các instance này mỗi frame, tránh overhead tạo Node cho từng hiệu ứng khi có hàng trăm quái.

var effect_id: String = ""          ## "burn" | "freeze" | "shock" | "poison" | "bleed" | "slow" | "stun"
var duration: float = 0.0
var time_remaining: float = 0.0
var tick_rate: float = 1.0
var time_since_last_tick: float = 0.0
var damage_per_tick: float = 0.0
var source_element: ElementTypes.ElementType = ElementTypes.ElementType.THO

## Dùng cho hiệu ứng non-damage: slow_percent, stun (không tick damage), v.v.
var magnitude: float = 0.0

var visual_effect_name: String = ""

func _init(p_effect_id: String = "", p_duration: float = 0.0, p_damage_per_tick: float = 0.0, p_tick_rate: float = 1.0, p_magnitude: float = 0.0) -> void:
	effect_id = p_effect_id
	duration = p_duration
	time_remaining = p_duration
	damage_per_tick = p_damage_per_tick
	tick_rate = p_tick_rate
	magnitude = p_magnitude

## Trả về true nếu effect đã hết hạn và nên bị xoá.
func tick(delta: float, target: Node) -> bool:
	time_remaining -= delta
	if damage_per_tick > 0.0:
		time_since_last_tick += delta
		if time_since_last_tick >= tick_rate:
			time_since_last_tick -= tick_rate
			if target and target.has_method("take_status_damage"):
				target.take_status_damage(damage_per_tick, effect_id)
	return time_remaining <= 0.0

## Refresh — khi trúng thêm 1 lần effect cùng loại, kéo dài lại duration thay vì cộng dồn stack
## (mặc định đơn giản, đủ cho scope hiện tại; stack riêng có thể mở rộng sau nếu cần).
func refresh(p_duration: float, p_damage_per_tick: float, p_magnitude: float = 0.0) -> void:
	duration = max(duration, p_duration)
	time_remaining = p_duration
	damage_per_tick = max(damage_per_tick, p_damage_per_tick)
	magnitude = max(magnitude, p_magnitude)
