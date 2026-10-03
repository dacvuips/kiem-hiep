extends Area2D

@onready var sprite: Sprite2D = $Sprite

var pickup_data: PickupData

func _ready() -> void:
	z_index = -1
	body_entered.connect(_on_body_entered)

func setup(data: PickupData) -> void:
	pickup_data = data
	if data.texture:
		sprite.texture = data.texture

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	match pickup_data.pickup_type:
		PickupData.PickupType.HEAL:
			if body.has_method("heal"):
				body.heal(pickup_data.heal_amount)
		PickupData.PickupType.MAGNET:
			GameManager.notify_magnet_used()

	ObjectPool.release.call_deferred(self)
