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
var attacker_node: Node = null

func _init(p_effect_id: String = "", p_duration: float = 0.0, p_damage_per_tick: float = 0.0, p_tick_rate: float = 1.0, p_magnitude: float = 0.0) -> void:
	effect_id = p_effect_id
	duration = p_duration
	time_remaining = p_duration
	damage_per_tick = p_damage_per_tick
	tick_rate = p_tick_rate
	magnitude = p_magnitude

## Chế độ ĐỘC VLTK (KNpc::Activate gốc, m_PoisonState): đếm theo NHỊP GAME (18/giây) thay vì giây. Mỗi nhịp: nTime--, nếu
## nTime chia hết cho nhịp-độc thì rút `damage_per_tick`, nTime về 0 thì hết độc. (Tick theo "mỗi N giây" sai: độc ngắn hơn nhịp
## như {thời gian 20, nhịp 25} gốc vẫn rút 1 lần ở nhịp cuối, còn kiểu cũ thì không bao giờ rút.)
var frame_mode: bool = false
var frames_left: int = 0
var interval_frames: int = 1
var _frame_acc: float = 0.0
const FRAME_FPS := 18.0

## Trả về true nếu effect đã hết hạn và nên bị xoá.
func tick(delta: float, target: Node) -> bool:
	if frame_mode:
		return _tick_frames(delta, target)
	time_remaining -= delta
	if damage_per_tick > 0.0:
		time_since_last_tick += delta
		if time_since_last_tick >= tick_rate:
			time_since_last_tick -= tick_rate
			_apply_tick_damage(target)
	return time_remaining <= 0.0

func _apply_tick_damage(target: Node) -> void:
	if not target or not target.has_method("take_status_damage"):
		return
	if attacker_node != null:
		var count: int = -1
		for m in target.get_method_list():
			if m.name == "take_status_damage":
				count = m.get("args", []).size()
				break
		if count >= 3 or count == -1:
			target.take_status_damage(damage_per_tick, effect_id, attacker_node)
			return
	target.take_status_damage(damage_per_tick, effect_id)

## Refresh — khi trúng thêm 1 lần effect cùng loại, kéo dài lại duration thay vì cộng dồn stack
## (mặc định đơn giản, đủ cho scope hiện tại; stack riêng có thể mở rộng sau nếu cần).
func refresh(p_duration: float, p_damage_per_tick: float, p_magnitude: float = 0.0) -> void:
	duration = max(duration, p_duration)
	time_remaining = p_duration
	damage_per_tick = max(damage_per_tick, p_damage_per_tick)
	magnitude = max(magnitude, p_magnitude)

func _tick_frames(delta: float, target: Node) -> bool:
	_frame_acc += delta * FRAME_FPS
	while _frame_acc >= 1.0 and frames_left > 0:
		_frame_acc -= 1.0
		frames_left -= 1
		if frames_left % maxi(1, interval_frames) == 0 and damage_per_tick > 0.0:
			_apply_tick_damage(target)
	time_remaining = float(frames_left) / FRAME_FPS
	return frames_left <= 0
