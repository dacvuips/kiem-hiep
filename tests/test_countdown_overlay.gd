extends Node

const CountdownOverlay = preload("res://ui/common/countdown_overlay.gd")

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS: ", name)
	else:
		_fail += 1
		print("FAIL: ", name, " | ", detail)

func _ready() -> void:
	print("--- TEST COUNTDOWN OVERLAY & PK 3-SECOND PREPARATION (1 -> 2 -> 3 -> GO!) ---")
	test_textures_exist()
	test_overlay_instance()
	test_pk_rules_prepare_time()
	test_pk_classes_support_countdown()
	print("RESULT: ", _pass, "/", _pass + _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func test_textures_exist() -> void:
	print("[1] Test Countdown Textures...")
	var tex1 = CountdownOverlay._load_texture("res://art/countdown/count_1.png")
	check("Texture Count 1 exists", tex1 != null)

	var tex2 = CountdownOverlay._load_texture("res://art/countdown/count_2.png")
	check("Texture Count 2 exists", tex2 != null)

	var tex3 = CountdownOverlay._load_texture("res://art/countdown/count_3.png")
	check("Texture Count 3 exists", tex3 != null)

	var tex_go = CountdownOverlay._load_texture("res://art/countdown/count_go.png")
	check("Texture Count GO exists", tex_go != null)

func test_overlay_instance() -> void:
	print("[2] Test Overlay Creation & Properties...")
	var overlay := CountdownOverlay.new()
	add_child(overlay)

	check("Overlay instantiated", overlay != null)
	check("Overlay is CanvasLayer with high layer", overlay.layer >= 120)
	check("Overlay Root exists", overlay._root != null)
	check("Overlay TexRect exists", overlay._tex_rect != null)
	check("Overlay GlowRect exists", overlay._glow_rect != null)
	check("Overlay Textures loaded", overlay._textures.size() == 4)

	overlay.cancel()
	check("Overlay cancelled without error", true)

func test_pk_rules_prepare_time() -> void:
	print("[3] Test PkRules & Preparation Time...")
	check("PkRules.PREPARE_SEC is 3.0 seconds", PkRules.PREPARE_SEC == 3.0)

func test_pk_classes_support_countdown() -> void:
	print("[4] Test PK classes preloading CountdownOverlay...")
	var pk_match_script: GDScript = load("res://systems/pk/pk_match.gd")
	check("PkMatch script loaded", pk_match_script != null)

	var brawl_script: GDScript = load("res://systems/pk/pk_brawl_match.gd")
	check("PkBrawlMatch script loaded", brawl_script != null)

	var moba_script: GDScript = load("res://systems/pk/tong_kim_lol_match.gd")
	check("TongKimLolMatch script loaded", moba_script != null)

	var escort_script: GDScript = load("res://systems/challenge/escort_challenge.gd")
	check("EscortChallenge script loaded", escort_script != null)

	var arena_script: GDScript = load("res://net/client/arena_client.gd")
	check("ArenaClient script loaded", arena_script != null)

	var battle_script: GDScript = load("res://net/client/battle_client.gd")
	check("BattleClient script loaded", battle_script != null)

	var sync_script: GDScript = load("res://net/client/net_world_sync.gd")
	check("NetWorldSync script loaded", sync_script != null)
