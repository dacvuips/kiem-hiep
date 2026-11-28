extends Node
## Vứt đồ khỏi hành trang: món vứt ra rơi dưới chân KHÔNG được tự nhặt lại (lỗi báo ở map PUBG — thật ra mọi map),
## đồ rơi thường vẫn tự nhặt khi đi ngang qua, bấm vào món đã vứt vẫn nhặt lại được.
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/discard_drop_tests.tscn
var _fail := 0
func check(n: String, c: bool) -> void:
	print("PASS " if c else "FAIL ", n)
	if not c: _fail += 1

func _ready() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "ThửVứt"
	GameManager.local_profile = profile

	var player := Node2D.new()
	player.add_to_group("player")
	add_child(player)
	var feet := player.global_position + Vector2(0, 30)

	var thrown := ItemGenerator.random_equipment(10)
	var normal := ItemGenerator.random_equipment(10)
	GroundDrop.spawn_drops(self, feet + Vector2(4, 6), [{"type": "item", "item": thrown, "discarded": true}])
	GroundDrop.spawn_drops(self, feet + Vector2(-4, 6), [{"type": "item", "item": normal}])
	for i in 5:
		await get_tree().process_frame

	check("Món vừa vứt nằm lại trên đất (không tự nhặt lại)", _drop_of(thrown) != null and not profile.inventory.has(thrown))
	check("Đồ rơi thường vẫn tự nhặt khi đứng gần", profile.inventory.has(normal))

	var g := _drop_of(thrown)
	g._pick_up(player)
	check("Bấm vào món đã vứt -> nhặt lại được", profile.inventory.has(thrown))

	# Online: đánh dấu uid trước khi server gửi vật rớt về
	var online_item := ItemGenerator.random_equipment(10)
	GroundDrop.mark_discarded(online_item.ensure_uid())
	var g2 := GroundDrop.new()
	g2.setup_item(ItemInstance.from_dict(online_item.to_dict()))
	check("Online: vật rớt có uid vừa vứt -> discarded", g2.discarded and online_item.uid != "")
	g2.free()

	# Đồ Hoàng Kim chỉ vứt được trong trận PUBG
	var gold := ItemGenerator.generate_gold(0)
	check("Tạo được đồ Hoàng Kim để thử", gold != null and gold.is_gold())
	check("Ngoài PUBG: chặn vứt đồ Hoàng Kim", PubgManager.discard_block_reason(gold, false) == PubgManager.GOLD_DISCARD_BLOCKED)
	check("Trong PUBG: vứt được đồ Hoàng Kim", PubgManager.discard_block_reason(gold, true) == "")
	check("Đồ thường vứt được ở mọi nơi", PubgManager.discard_block_reason(normal, false) == "")
	check("Hub ngoài trận -> không phải PUBG", not PubgManager.is_pubg_active())

	print("RESULT fail=", _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _drop_of(it: ItemInstance) -> GroundDrop:
	for n in get_tree().get_nodes_in_group(GroundDrop.GROUP):
		if n is GroundDrop and (n as GroundDrop).item == it and not n.is_queued_for_deletion():
			return n
	return null
