extends Area2D

enum GemType {
	SMALL = 0,   ## Ngọc EXP Nhỏ - Rơi từ quái thường
	MEDIUM = 1,  ## Ngọc EXP Trung - Rơi từ quái tinh anh
	LARGE = 2    ## Ngọc EXP Lớn - Rơi từ Boss & quái đặc biệt
}

const MAGNET_SPEED = 650.0
const LIFETIME = 35.0
const BLINK_WARNING_TIME = 3.5

@export var exp_value: float = 15.0
@export var gem_type: GemType = GemType.SMALL

var is_attracted: bool = false
var attract_target: Node2D
var time_alive: float = 0.0
var blink_tween: Tween
var glow_tween: Tween
## Chặn cộng EXP 2 lần trong cùng 1 frame — ObjectPool.release() chỉ LÊN LỊCH release vào cuối
## frame (call_deferred), nên nếu cả body_entered VÀ check chồng lấn thủ công trong
## _physics_process() cùng trúng Player trong cùng frame, _collect() có thể bị gọi 2 lần trước
## khi node thực sự bị gỡ khỏi tree.
var _collected: bool = false
var _base_scale: Vector2 = Vector2(0.35, 0.35)
var _base_color: Color = Color(0.85, 1.0, 0.4, 1.0)

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	z_index = -1
	body_entered.connect(_on_body_entered)
	GameManager.magnet_used.connect(_on_magnet_used)
	_apply_visual_type()

func setup_gem(type: int, custom_exp: float = -1.0) -> void:
	gem_type = type as GemType
	match gem_type:
		GemType.SMALL:
			_base_scale = Vector2(0.32, 0.32)
			_base_color = Color(0.85, 1.0, 0.42, 1.0) # Ngọc Lục Vàng phát sáng nhẹ
			exp_value = custom_exp if custom_exp > 0.0 else 15.0
		GemType.MEDIUM:
			_base_scale = Vector2(0.52, 0.52)
			_base_color = Color(0.35, 0.75, 1.0, 1.0) # Ngọc Lam Tinh Anh lấp lánh
			exp_value = custom_exp if custom_exp > 0.0 else 150.0
		GemType.LARGE:
			_base_scale = Vector2(0.80, 0.80)
			_base_color = Color(1.0, 0.30, 0.25, 1.0) # Ngọc Đỏ/Hoàng Kim Thủ Quan rực rỡ
			exp_value = custom_exp if custom_exp > 0.0 else 1500.0
	_apply_visual_type()

func _apply_visual_type() -> void:
	if sprite == null:
		return
	sprite.scale = _base_scale
	sprite.modulate = _base_color
	_start_glow_pulse()

func _start_glow_pulse() -> void:
	if glow_tween:
		glow_tween.kill()
	glow_tween = create_tween()
	glow_tween.set_loops()
	var pulse_scale := _base_scale * (1.18 if gem_type == GemType.LARGE else (1.12 if gem_type == GemType.MEDIUM else 1.06))
	var pulse_duration := 0.45 if gem_type == GemType.LARGE else (0.65 if gem_type == GemType.MEDIUM else 0.85)
	glow_tween.tween_property(sprite, "scale", pulse_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(sprite, "scale", _base_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_pool_acquire() -> void:
	is_attracted = false
	time_alive = 0.0
	_collected = false
	if blink_tween:
		blink_tween.kill()
		blink_tween = null
	if glow_tween:
		glow_tween.kill()
		glow_tween = null
	_apply_visual_type()

## Dưới khoảng cách này coi như đã "tới nơi" — tự nhặt trực tiếp thay vì tiếp tục bám theo
## Player và chờ Area2D.body_entered tính toán va chạm vật lý. Cần thiết vì khi is_attracted,
## gem đuổi theo attract_target.global_position ĐANG DI CHUYỂN mỗi frame — nếu Player lượn hoặc
## đứng yên ở rìa CollisionShape2D, gem có thể dao động ngay sát Player mãi mà không bao giờ
## thực sự lọt vào để kích hoạt "enter".
const COLLECT_DISTANCE := 14.0

func _physics_process(delta: float) -> void:
	if is_attracted and attract_target:
		var to_target := attract_target.global_position - global_position
		if to_target.length() <= COLLECT_DISTANCE:
			_collect(attract_target)
			return
		# Tăng tốc độ hút khi ngọc lớn hơn hoặc khi gần tới đích
		var current_speed := MAGNET_SPEED * (1.2 if gem_type == GemType.LARGE else 1.0)
		global_position += to_target.normalized() * current_speed * delta
		return

	# Hút ngọc theo bán kính nhặt Thâu Thiên Hoán Nhật
	if not is_attracted:
		var p := get_tree().get_first_node_in_group("player")
		if p != null and is_instance_valid(p):
			var rad: float = PlayerStats.pickup_radius if "pickup_radius" in PlayerStats else 80.0
			if global_position.distance_to(p.global_position) <= rad:
				is_attracted = true
				attract_target = p
				return

	## Area2D.body_entered chỉ bắn khi 2 vật thể BẮT ĐẦU chồng lấn từ trạng thái không chạm
	## trước đó — nếu quái chết ngay sát/tại vị trí Player đang đứng yên, gem exp spawn ra đã
	## CHỒNG LẤN SẴN với Player, signal không bao giờ bắn tự nhiên. Tự kiểm tra get_overlapping_bodies().
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_collect(body)
			return

	time_alive += delta

	var time_left := LIFETIME - time_alive
	if time_left <= BLINK_WARNING_TIME and blink_tween == null:
		start_blink_warning()

	if time_alive >= LIFETIME:
		_cleanup_and_release()

func start_blink_warning() -> void:
	if glow_tween:
		glow_tween.kill()
		glow_tween = null
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

func _collect(_body: Node) -> void:
	if _collected:
		return
	_collected = true
	PlayerStats.add_exp(exp_value)
	_cleanup_and_release()

func _cleanup_and_release() -> void:
	if glow_tween:
		glow_tween.kill()
		glow_tween = null
	if blink_tween:
		blink_tween.kill()
		blink_tween = null
	ObjectPool.release.call_deferred(self)
