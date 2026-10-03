extends Area2D

const MAGNET_SPEED = 600.0
const LIFETIME = 30.0
const BLINK_WARNING_TIME = 3.0

@export var exp_value: float = 1.0

var is_attracted: bool = false
var attract_target: Node2D
var time_alive: float = 0.0
var blink_tween: Tween
## Chặn cộng EXP 2 lần trong cùng 1 frame — ObjectPool.release() chỉ LÊN LỊCH release vào cuối
## frame (call_deferred), nên nếu cả body_entered VÀ check chồng lấn thủ công trong
## _physics_process() cùng trúng Player trong cùng frame, _collect() có thể bị gọi 2 lần trước
## khi node thực sự bị gỡ khỏi tree.
var _collected: bool = false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	z_index = -1
	body_entered.connect(_on_body_entered)
	GameManager.magnet_used.connect(_on_magnet_used)

func _on_pool_acquire() -> void:
	is_attracted = false
	time_alive = 0.0
	_collected = false
	sprite.modulate.a = 1.0
	if blink_tween:
		blink_tween.kill()
		blink_tween = null

## Dưới khoảng cách này coi như đã "tới nơi" — tự nhặt trực tiếp thay vì tiếp tục bám theo
## Player và chờ Area2D.body_entered tính toán va chạm vật lý. Cần thiết vì khi is_attracted,
## gem đuổi theo attract_target.global_position ĐANG DI CHUYỂN mỗi frame — nếu Player lượn hoặc
## đứng yên ở rìa CollisionShape2D, gem có thể dao động ngay sát Player mãi mà không bao giờ
## thực sự lọt vào để kích hoạt "enter" (đúng triệu chứng "gem dính lại phía sau, không nhặt
## được" khi bật Nam Châm — trước đây không rõ ràng vì chưa có logic hút, giờ mới lộ ra).
const COLLECT_DISTANCE := 12.0

func _physics_process(delta: float) -> void:
	if is_attracted and attract_target:
		var to_target := attract_target.global_position - global_position
		if to_target.length() <= COLLECT_DISTANCE:
			_collect(attract_target)
			return
		global_position += to_target.normalized() * MAGNET_SPEED * delta
		return

	## Area2D.body_entered chỉ bắn khi 2 vật thể BẮT ĐẦU chồng lấn từ trạng thái không chạm
	## trước đó — nếu quái chết ngay sát/tại vị trí Player đang đứng yên, gem exp spawn ra đã
	## CHỒNG LẤN SẴN với Player, signal không bao giờ bắn tự nhiên (Player phải nhúc nhích để
	## physics engine tính lại "enter" mới). Tự kiểm tra get_overlapping_bodies() mỗi frame để
	## không phụ thuộc việc Player có di chuyển hay không.
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_collect(body)
			return

	time_alive += delta

	var time_left := LIFETIME - time_alive
	if time_left <= BLINK_WARNING_TIME and blink_tween == null:
		start_blink_warning()

	if time_alive >= LIFETIME:
		ObjectPool.release.call_deferred(self)

func start_blink_warning() -> void:
	blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(sprite, "modulate:a", 0.2, 0.25)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.25)

func _on_magnet_used() -> void:
	if not is_inside_tree() or not visible:
		return
	is_attracted = true
	attract_target = get_tree().get_first_node_in_group("player")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect(body)

## Dùng chung cho cả body_entered (Player di chuyển vào gem) và check chồng lấn thủ công mỗi
## frame trong _physics_process() (Player đứng yên ngay chỗ gem xuất hiện). _collected chặn gọi
## trùng vì ObjectPool.release() chỉ LÊN LỊCH release vào cuối frame (call_deferred), nên cả 2
## đường có thể cùng trúng Player trong cùng 1 frame trước khi node thực sự bị gỡ khỏi tree.
func _collect(_body: Node) -> void:
	if _collected:
		return
	_collected = true
	PlayerStats.add_exp(exp_value)
	ObjectPool.release.call_deferred(self)
