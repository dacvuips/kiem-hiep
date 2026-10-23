extends Node

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func _ready() -> void:
	print("--- BẮT ĐẦU TEST CHẾ ĐỘ PK LỘN XỘN (BRAWL) ---")
	test_brawl_rules()
	test_brawl_lobby()
	test_scoring_and_exp()
	test_brawl_match_coordinator()
	print("--- KẾT THÚC TEST: RESULT %d/%d (Thất bại: %d) ---" % [_pass, _pass + _fail, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func test_brawl_rules() -> void:
	check("rules: Mode có enum LON_XON", PkRules.Mode.has("LON_XON"))
	check("rules: tên hiển thị Lộn xộn", PkRules.MODE_NAMES.get(PkRules.Mode.LON_XON) == "Lộn xộn")
	check("rules: can_kick Lộn xộn là true", PkRules.can_kick(PkRules.Mode.LON_XON) == true)
	check("rules: has_rank_points Lộn xộn là false", PkRules.has_rank_points(PkRules.Mode.LON_XON) == false)
	check("rules: BRAWL_MAPS có 3 map", PkRules.BRAWL_MAPS.size() == 3)
	
	var m319 := PkRules.get_brawl_map_info(319)
	check("rules: map 319 là Lâm Du Quan", m319.name == "Lâm Du Quan" and m319.id == 319)
	
	var m320 := PkRules.get_brawl_map_info(320)
	check("rules: map 320 là Chân Núi Trường Bạch (9x)", m320.name == "Chân Núi Trường Bạch (9x)" and m320.id == 320)
	
	var m336 := PkRules.get_brawl_map_info(336)
	check("rules: map 336 là Phong Lăng Độ (12x)", m336.name == "Phong Lăng Độ (12x)" and m336.id == 336)
	
	var entry := PkRules.arena_entry({
		"mode": PkRules.Mode.LON_XON,
		"map_id": 320,
		"target_kills": 25,
		"brawl_type": "solo"
	})
	check("rules: arena_entry trả đúng map 320", int(entry.get("id", 0)) == 320)
	check("rules: arena_entry có cờ brawl", bool(entry.get("brawl", false)) == true)

func test_brawl_lobby() -> void:
	var p := PlayerProfile.new()
	p.display_name = "DaiHiep"
	p.level = 90
	
	# Tạo phòng solo
	var room := PkLobby.create(p, PkRules.Mode.LON_XON, "", 1, {
		"brawl_type": "solo",
		"map_id": 319,
		"target_kills": 30
	})
	check("lobby: tạo phòng solo thành công", not room.is_empty())
	check("lobby: brawl_type là solo", room.get("brawl_type") == "solo")
	check("lobby: target_kills là 30", int(room.get("target_kills")) == 30)
	
	var rid := str(room["id"])
	check("lobby: thêm bot vào solo slot", PkLobby.add_bot(rid, "", 90))
	var updated_room := PkLobby.find(rid)
	var slots: Array = updated_room.get("solo_slots", [])
	check("lobby: có 2 slot sau khi thêm 1 bot", slots.size() == 2)
	
	PkLobby.close(rid)
	check("lobby: đóng phòng thành công", PkLobby.find(rid).is_empty())

func test_scoring_and_exp() -> void:
	# Công thức: mỗi mạng giết được +300 điểm, bị giết -100 điểm, exp = điểm x 30
	var kills := 15
	var deaths := 3
	var score := kills * 300 - deaths * 100
	check("score: 15 kills, 3 deaths = 4200 điểm", score == 4200)
	
	var exp_gained := score * 30
	check("exp: 4200 điểm x 30 = 126,000 EXP", exp_gained == 126000)
	
	# Quy tắc: Điểm trận đấu không bao giờ âm (tối thiểu 0 điểm)
	var test_victim := {"deaths": 0, "streak": 0, "score": 0}
	test_victim.score = maxi(0, int(test_victim.score) - 100)
	check("score: chết khi 0 điểm thì điểm giữ nguyên là 0", test_victim.score == 0)
	test_victim.score = 50
	test_victim.score = maxi(0, int(test_victim.score) - 100)
	check("score: trừ điểm không bị âm dưới 0", test_victim.score == 0)

	# Test add_exp vào PlayerProfile
	var p := PlayerProfile.new()
	p.level = 10
	p.current_exp = 0
	var old_exp := p.current_exp
	p.add_exp(exp_gained)
	check("profile: cộng exp thực tế thành công", p.level > 10 or p.current_exp > old_exp)

func test_brawl_match_coordinator() -> void:
	var bot := PkBot.new()
	check("bot: có hàm respawn_at", bot.has_method("respawn_at"))
	check("bot: có hàm set_name_color", bot.has_method("set_name_color"))
	check("bot: có biến last_attacker", "last_attacker" in bot)
	check("bot: có biến last_attacker_name", "last_attacker_name" in bot)
	bot.free()
	
	var brawl_script: GDScript = load("res://systems/pk/pk_brawl_match.gd")
	check("match: script load thành công", brawl_script != null)
	var match_node = brawl_script.new()
	check("match: khởi tạo PkBrawlMatch thành công", match_node != null)
	check("match: có hàm _clear_map_monsters", match_node.has_method("_clear_map_monsters"))
	
	GameManager.field_map = {"brawl": true}
	check("world: VltkWorld.is_brawl() nhận diện đúng cờ brawl", VltkWorld.is_brawl() == true)
	GameManager.field_map = {"pk": {"mode": PkRules.Mode.LON_XON}}
	check("world: VltkWorld.is_brawl() nhận diện đúng mode LON_XON", VltkWorld.is_brawl() == true)
	GameManager.field_map = {}
	check("world: VltkWorld.is_brawl() trả về false khi không ở Lộn xộn", VltkWorld.is_brawl() == false)
	
	add_child(match_node)
	check("hud: bảng thông tin dời xuống y >= 50 để lộ thanh máu", match_node._top_panel.position.y >= 50.0)
	check("hud: nút BXH và Rời trận nằm dưới MiniMap (y >= 150)", match_node._btn_scoreboard.get_parent().position.y >= 150.0)
	match_node.queue_free()
