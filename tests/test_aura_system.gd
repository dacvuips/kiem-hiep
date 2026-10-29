extends Node

const AuraDatabase = preload("res://systems/auras/aura_database.gd")

func _ready() -> void:
	print("=== BẮT ĐẦU KIỂM THỬ HỆ THỐNG AURA & GM AURA GRID ===")
	test_aura_database()
	test_player_aura_hidden_and_gm_attach()
	test_remote_player_gm_aura()
	test_gm_control_window_aura_tab()
	test_server_persistence_and_look()
	print("=== TẤT CẢ KIỂM THỬ AURA HOÀN TOÀN THÀNH CÔNG! ===")
	get_tree().quit()

func check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)
		print("FAIL: %s" % label)
		assert(condition, label)

func test_aura_database() -> void:
	var auras := AuraDatabase.get_all()
	check("AuraDatabase có dữ liệu hào quang", not auras.is_empty())
	check("Tổng số hào quang đã nhập >= 100", auras.size() >= 100)

	var cats := AuraDatabase.get_categories()
	check("Có danh mục Vòng Sáng", cats.has("Vòng Sáng"))
	check("Có danh mục Phi Phong & Danh Hiệu", cats.has("Phi Phong & Danh Hiệu"))
	check("Có danh mục Môn Phái", cats.has("Môn Phái"))
	check("Có danh mục VIP & Sự Kiện", cats.has("VIP & Sự Kiện"))

	# Kiểm tra một số aura tiêu biểu
	var red_aura := AuraDatabase.get_by_state(146)
	check("State 146 là Hồng Quang Hoàn", red_aura.get("name") == "Hồng Quang Hoàn")

	var gold_aura := AuraDatabase.get_by_state(149)
	check("State 149 là Kim Quang Hoàn", gold_aura.get("name") == "Kim Quang Hoàn")

	var lohan := AuraDatabase.get_by_state(45)
	check("State 45 là La Hán Trận", lohan.get("name") == "La Hán Trận")

	# Kiểm tra thumbnail
	var thumb := AuraDatabase.get_thumb(str(red_aura.get("thumb", "")))
	check("Thumbnail của Hồng Quang Hoàn tải được thành công", thumb != null)

func test_player_aura_hidden_and_gm_attach() -> void:
	if GameManager.local_profile == null:
		GameManager.local_profile = PlayerProfile.new()
		GameManager.local_profile.display_name = "GM_TestUser"

	var player_scene = preload("res://player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)

	# 1. Aura mặc định phải bị ẩn
	var old_aura: AnimatedSprite2D = player.get_node_or_null("Aura")
	check("Aura mặc định bị ẩn (visible = false)", old_aura != null and old_aura.visible == false)

	# 2. GM gắn aura cho bản thân (State 146 - Hồng Quang Hoàn)
	var local_target := {
		"id": "LOCAL_01",
		"name": "Bản Thân",
		"is_self": true,
		"profile": GameManager.local_profile
	}
	GmManager.set_player_aura(local_target, 146)
	player._refresh_aura_sprite()

	check("Player có _aura_sprite sau khi GM gắn", player._aura_sprite != null)
	check("Player _aura_sprite_state khớp 146", player._aura_sprite_state == 146)

	# 3. GM tháo aura
	GmManager.clear_player_aura(local_target)
	player._refresh_aura_sprite()
	check("Player gỡ bỏ aura thành công (_aura_sprite == null)", player._aura_sprite == null)
	check("Player _aura_sprite_state == 0", player._aura_sprite_state == 0)

	player.queue_free()

func test_remote_player_gm_aura() -> void:
	var remote = Node2D.new()
	remote.set_script(load("res://net/client/remote_player.gd"))
	add_child(remote)

	var remote_target := {
		"id": "REMOTE_99",
		"name": "Người Chơi Khác",
		"is_self": false,
		"remote_node": remote
	}

	# GM gắn aura cho người chơi khác (State 149 - Kim Quang Hoàn)
	GmManager.set_player_aura(remote_target, 149)
	check("RemotePlayer nhận hào quang State 149", remote._aura_sprite_state == 149)
	check("RemotePlayer tạo _aura_sprite", remote._aura_sprite != null)

	# GM tháo aura người chơi khác
	GmManager.clear_player_aura(remote_target)
	check("RemotePlayer đã tháo hào quang", remote._aura_sprite_state == 0 and remote._aura_sprite == null)

	remote.queue_free()

func test_gm_control_window_aura_tab() -> void:
	AccountApi.account = {"is_gm": true, "name": "Admin_Test"}
	var win = GmControlWindow.new()
	add_child(win)

	# Chuyển sang Tab 7 (Hào Quang Aura)
	win._current_tab = GmControlWindow.Tab.AURA
	win._render_tab()

	check("GmControlWindow render Tab 7 (Hào Quang Aura) không lỗi", win._content_area.get_child_count() > 0)
	win.queue_free()

func test_server_persistence_and_look() -> void:
	print("\n--- Test 5: Server Persistence & Look Generation ---")
	var p := PlayerProfile.new()
	p.display_name = "ServerAuraTester"
	p.gm_aura_state = 149 # Kim Quang Hoàn

	var p_dict := p.to_dict()
	check("to_dict() lưu gm_aura_state = 149", int(p_dict.get("gm_aura_state", 0)) == 149)

	# 1. GameServer.look_from_profile
	var look := GameServer.look_from_profile(p_dict)
	check("GameServer.look_from_profile nhận aura_state = 149 từ gm_aura_state", int(look.get("aura_state", 0)) == 149)

	# 2. ProfileGuard.sanitize_new
	var sanitized := ProfileGuard.sanitize_new(p_dict)
	check("ProfileGuard.sanitize_new giữ gm_aura_state", int(sanitized.get("gm_aura_state", 0)) == 149)

	# 3. ProfileGuard.merge
	var merged := ProfileGuard.merge({}, p_dict)
	check("ProfileGuard.merge giữ gm_aura_state", int(merged.get("gm_aura_state", 0)) == 149)

	# 4. Khi gm_aura_state = 0 nhưng có active_aura_id môn phái
	var p_sect := PlayerProfile.new()
	p_sect.sect_id = "thien_vuong"
	p_sect.active_aura_id = "thien_vuong_aura_1"
	var p_sect_dict := p_sect.to_dict()
	var look_sect := GameServer.look_from_profile(p_sect_dict)
	check("GameServer.look_from_profile fallback về môn phái khi gm_aura_state = 0", look_sect.has("aura_state"))

	# 5. Khi có cả gm_aura_state và active_aura_id môn phái -> GM aura ưu tiên cao nhất
	p_sect.gm_aura_state = 55 # Ma Diệm
	var look_override := GameServer.look_from_profile(p_sect.to_dict())
	check("GM Aura (55) được ưu tiên hơn môn phái", int(look_override.get("aura_state", 0)) == 55)

	# 6. Test chuyển map & nhận S_PROFILE cũ từ server: bảo vệ gm_aura_state không bị mất
	print("\n--- Test 6: Stale S_PROFILE protection during map transition ---")
	GameManager.local_profile.gm_aura_state = 146
	var net_social := NetSocial.new()
	add_child(net_social)
	var stale_server_data := {
		"name": GameManager.local_profile.display_name,
		"level": GameManager.local_profile.level,
		"gm_aura_state": 0 # Server gửi dữ liệu cũ chưa có aura
	}
	net_social._on_profile(stale_server_data)
	check("NetSocial bảo vệ gm_aura_state không bị ghi đè bởi profile cũ = 0", GameManager.local_profile.gm_aura_state == 146)
	net_social.queue_free()
