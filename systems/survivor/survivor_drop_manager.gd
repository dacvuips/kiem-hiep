class_name SurvivorDropManager
extends RefCounted
## TRÌNH QUẢN LÝ RƠI NGỌC EXP & VẬT PHẨM CHẾ ĐỘ SURVIVOR (MỤC 6 GDD)
##
## Quản lý 3 loại ngọc EXP:
## - Nhỏ (Type 0): Quái thường
## - Trung (Type 1): Quái tinh anh
## - Lớn (Type 2): Boss và quái đặc biệt
##
## Tách biệt khỏi DropTable trang bị / ngân lượng của chế độ Online MMORPG.

const GemScene := preload("res://gems/Gem.tscn")

## Kiểm tra và sinh ngọc EXP cho quái bị hạ gục (chỉ gọi trong Offline Vượt Ải)
static func spawn_gem_for_enemy(enemy: Node2D) -> void:
	if not GameModeManager.is_offline() and not (GameManager.field_map.get("survivor_mode", false) == true):
		return
	if enemy == null or not is_instance_valid(enemy):
		return

	var is_boss: bool = (enemy.get("is_boss") == true) or (enemy.get("is_survivor_boss") == true) or (enemy.get("gold_boss") == true)
	var is_elite: bool = (enemy.get("is_elite") == true) or (enemy.get("blue_boss") == true)
	# Màn chơi luyện trong Offline: Thưởng EXP gấp 10 lần (x10)
	var is_offline_luyen: bool = GameModeManager.is_offline() or (GameManager.field_map.get("survivor_mode", false) == true)
	var exp_mult: float = 10.0 if is_offline_luyen else 1.0
	var exp_drop: float = (2000.0 if is_boss else (200.0 if is_elite else 20.0)) * exp_mult
	if "exp_drop" in enemy and enemy.get("exp_drop") != null:
		exp_drop = float(enemy.get("exp_drop")) * exp_mult
	var gem_tex: Texture2D = (enemy.get("gem_texture") as Texture2D) if ("gem_texture" in enemy and enemy.get("gem_texture") is Texture2D) else null

	var g_type: int = 0 # SMALL
	if is_boss:
		g_type = 2 # LARGE
	elif is_elite:
		g_type = 1 # MEDIUM

	var parent := enemy.get_parent()
	if parent == null:
		return

	ObjectPool.acquire_deferred(GemScene, parent, enemy.global_position, func(gem):
		if gem.has_method("setup_gem"):
			gem.setup_gem(g_type, exp_drop)
		elif "exp_value" in gem:
			gem.exp_value = exp_drop
		if gem_tex and gem.has_node("Sprite"):
			gem.get_node("Sprite").texture = gem_tex
	)
