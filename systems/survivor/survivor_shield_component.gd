class_name SurvivorShieldComponent
extends Node
## COMPONENT QUẢN LÝ KHIÊN PHÒNG VỆ HÀO QUANG QUÁN QUÂN TINH ANH SÁI
##
## Chặn 100% sát thương của 1 đòn đánh, hiển thị hiệu ứng hào quang Quán Quân (state_142).
## Tự động hồi phục sau thời gian hồi chiêu theo cấp độ perk.

const SHIELD_STATE_ID := 142 # Quán Quân Tinh Anh Sái

var _player: CharacterBody2D
var _aura_node: Node2D = null
var has_shield: bool = true
var _cooldown_timer: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	refresh_shield()

func _process(delta: float) -> void:
	if not has_shield:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_restore_shield()

func refresh_shield() -> void:
	var lvl := SurvivorPerks.get_perk_level("guardian_shield")
	if lvl <= 0:
		_remove_aura()
		has_shield = false
		return
	if has_shield and _aura_node == null:
		_attach_aura()

func get_recharge_time() -> float:
	var lvl := SurvivorPerks.get_perk_level("guardian_shield")
	# Cấp 1: 12s, Cấp 2: 10s, Cấp 3: 8s, Cấp 4: 6s, Cấp 5: 4s
	return maxf(4.0, 14.0 - float(lvl) * 2.0)

## Gọi khi Player bị trúng đòn. Trả về true nếu khiên đã đỡ đòn này (miễn nhiễm sát thương).
func try_absorb_hit() -> bool:
	var lvl := SurvivorPerks.get_perk_level("guardian_shield")
	if lvl <= 0 or not has_shield:
		return false

	# Khiên đỡ đòn thành công
	has_shield = false
	_remove_aura()
	_cooldown_timer = get_recharge_time()

	if _player and _player.has_method("notify"):
		_player.notify("★ HÀO QUANG QUÁN QUÂN ĐÃ ĐỠ TRỌN ĐÒN ĐÁNH! ★")
	
	# Hiệu ứng nổ khiên / âm thanh nếu có
	var tree := get_tree()
	if tree != null and _player != null:
		var effect_cls = load("res://systems/skill_fx/vltk_effect.gd")
		if effect_cls:
			effect_cls.spawn(tree.current_scene, "shield_break", _player.global_position)

	return true

func _restore_shield() -> void:
	has_shield = true
	_cooldown_timer = 0.0
	_attach_aura()
	if _player and _player.has_method("notify"):
		_player.notify("✦ Hào Quang Quán Quân đã hồi phục! ✦")

func _attach_aura() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _aura_node != null and is_instance_valid(_aura_node):
		return
	var v_sprite_cls = load("res://systems/skill_fx/vltk_state_sprite.gd")
	if v_sprite_cls != null:
		_aura_node = v_sprite_cls.attach(_player, SHIELD_STATE_ID)

func _remove_aura() -> void:
	if _aura_node != null and is_instance_valid(_aura_node):
		_aura_node.queue_free()
		_aura_node = null

func _exit_tree() -> void:
	_remove_aura()
