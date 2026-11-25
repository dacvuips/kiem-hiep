extends Node

## Sát thương quái đánh người còn 1/3 (MONSTER_DAMAGE_RATE_PERCENT) + quái khắc hệ giảm tương khắc (MONSTER_FIVE_ELEMENTS_RATE_PERCENT).
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/test_monster_damage_rate.tscn

var _fails := 0

func _ready() -> void:
	_check(CombatFormulas.MONSTER_DAMAGE_RATE_PERCENT == 33, "quái đánh người còn 33% sát thương")
	_check(CombatFormulas.MONSTER_FIVE_ELEMENTS_RATE_PERCENT == 50, "tương khắc của quái còn 50%")

	## Tìm 1 cặp hệ: hệ quái khắc hệ người.
	var atk_el := ElementTypes.ElementType.values()[0] as ElementTypes.ElementType
	var def_el := atk_el
	for a in ElementTypes.ElementType.values():
		for d in ElementTypes.ElementType.values():
			if ElementTypes.does_beat(a, d):
				atk_el = a
				def_el = d
	_check(ElementTypes.does_beat(atk_el, def_el), "có cặp hệ khắc")

	var attacker := CombatantStats.new()
	attacker.element = atk_el
	var defender := CombatantStats.new()
	defender.element = def_el
	defender.resist_percent[CombatFormulas.DamageType.PHYSICS] = 60
	var parts := {CombatFormulas.DamageType.PHYSICS: Vector2i(1000, 1000)}

	var mods := CombatFormulas.HitModifiers.new()
	mods.five_elements_damage_p = 40
	var full := CombatFormulas.resolve_multi_damage(attacker, defender, 100000, parts, atk_el, mods)
	mods.five_elements_rate_percent = CombatFormulas.MONSTER_FIVE_ELEMENTS_RATE_PERCENT
	var half := CombatFormulas.resolve_multi_damage(attacker, defender, 100000, parts, atk_el, mods)
	mods.five_elements_damage_p = 0
	var none := CombatFormulas.resolve_multi_damage(attacker, defender, 100000, parts, atk_el, mods)
	print("kháng 60%%, tương khắc 40%%: đủ=%d, giảm nửa=%d, không khắc=%d" % [full, half, none])
	_check(full > half and half > none, "tương khắc giảm nửa nằm giữa đủ và không khắc")

	print("MONSTER DAMAGE RATE: %s" % ("PASS" if _fails == 0 else "FAIL %d" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_fails += 1
		printerr("FAIL: ", msg)
