extends Node
## Bóng mờ nhân vật (KNpcBlur gốc): bật -> có tối đa 7 bóng; tắt -> mờ dần rồi ẩn hết.

func _ready() -> void:
	var ok := true
	var av := CharacterAvatar.new()
	add_child(av)
	await get_tree().process_frame
	av.set_blur(true)
	for i in 30:
		av._tick_blur(1.0 / 60.0)
	var shown := 0
	for slot in av._blur_slots:
		if slot.visible:
			shown += 1
	print("blur on: ", shown, " ghosts")
	ok = ok and shown == 7
	ok = ok and av._blur_slots[0].get_child_count() > 0
	av.set_blur(false)
	for i in 60 * 3:
		av._tick_blur(1.0 / 60.0)
	shown = 0
	for slot in av._blur_slots:
		if slot.visible:
			shown += 1
	print("blur off after 3s: ", shown, " ghosts")
	ok = ok and shown == 0 and not av._blur_active
	var d := VltkSkillData.skill(40, 10)
	print("Doan Hon Thich need_shadow=", d.get("need_shadow"), " form=", d.get("form"), " melee=", VltkSkillRunner.is_melee_supported(d))
	ok = ok and VltkSkillRunner.needs_shadow(d) and VltkSkillRunner.is_melee_supported(d)
	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
