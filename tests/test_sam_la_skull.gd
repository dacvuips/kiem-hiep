extends Node2D

func _ready() -> void:
	print("--- TEST SÂM LA ĐỘC HẢI 100% HIỆN ĐẦU LÂU ---")
	
	var world_node := Node2D.new()
	add_child(world_node)
	
	await get_tree().process_frame
	
	var ctx := VltkCastContext.new()
	ctx.launcher = self
	ctx.world = world_node
	var target := Node2D.new()
	world_node.add_child(target)
	target.global_position = Vector2(200, 150)
	
	var target_logic := VltkMath.logic_of(target)
	
	# Spawn 50 times in a row - every single one must have the skull!
	for i in 50:
		VltkSkillCaster.cast(ctx, 1222, 1, target_logic, target)
		var found: VltkMissile = null
		for child in world_node.get_children():
			if child is VltkMissile and child != target:
				found = child
				break
		assert(found != null, "Must spawn missile on iteration %d" % i)
		var fly: Variant = found._phase(VltkMissile.Phase.FLY)
		assert(fly != null, "Fly phase must not be null on iteration %d" % i)
		assert(fly["anim"] == "wd_youhunshiying_d_1cb2", "Anim must be skull on iteration %d" % i)
		assert(found._sprite.texture != null, "Sprite texture must not be null on iteration %d" % i)
		ObjectPool.release(found)
	
	print("SUCCESS: 50/50 lần xuất chiêu đều hiển thị ĐẦU LÂU 100% chuẩn xác, không còn lần nào bị mất hình!")
	get_tree().quit(0)
