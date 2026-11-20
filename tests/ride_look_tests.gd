extends Node
## Lên / xuống ngựa: trạng thái cưỡi được lưu trong hồ sơ, server tính ngoại hình người khác thấy đúng theo đó.
## Lỗi cũ: `riding` không nằm trong to_dict -> server dựng lại hồ sơ thì luôn "đang cưỡi" -> vài giây sau người khác thấy
## mình nhảy lên ngựa dù đang đi bộ.  godot --headless --path . res://tests/ride_look_tests.tscn

var _passes := 0
var _fails := 0

func _ready() -> void:
	print("\n--- TEST LÊN/XUỐNG NGỰA ONLINE ---")
	var p := PlayerProfile.new()
	var horse := ItemGenerator.generate(ItemDatabase.Detail.HORSE, 2, 9, p.get_element(), [])
	check("Có ngựa để thử", horse != null)
	if horse != null:
		p.equipment[Equipment.Part.HORSE] = horse
	p.riding = false
	var back := PlayerProfile.from_dict(p.to_dict())
	check("Lưu/đọc giữ 'đã xuống ngựa'", not back.riding)
	check("Server tính ngoại hình: đi bộ (không ngựa)", int(GameServer.look_from_profile(p.to_dict()).get("horse", -1)) < 0)
	p.riding = true
	check("Lưu/đọc giữ 'đang cưỡi'", PlayerProfile.from_dict(p.to_dict()).riding)
	check("Server tính ngoại hình: có ngựa", int(GameServer.look_from_profile(p.to_dict()).get("horse", -1)) >= 0)
	var old := p.to_dict()
	old.erase("riding")
	check("Bản lưu cũ (chưa có khoá riding): như trước = cưỡi", PlayerProfile.from_dict(old).riding)
	print("RESULT %d/%d" % [_passes, _passes + _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func check(name: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("PASS ", name)
	else:
		_fails += 1
		print("FAIL ", name)
