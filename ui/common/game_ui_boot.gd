extends Node
## Autoload: gộp theme giao diện chung (GameUi) vào theme project ngay khi khởi động — trước mọi màn/popup — và đổi font theo màn:
## màn đăng nhập / đăng ký / chọn server / nhân vật giữ font cũ, vào game (Hub, bản đồ...) dùng font trong game (GameUi.game_font).

var _keyboard_bar: Node = null

func _enter_tree() -> void:
	GameUi.apply()
	get_tree().scene_changed.connect(_sync_font)
	_sync_font.call_deferred()
	_init_keyboard_bar.call_deferred()

func _init_keyboard_bar() -> void:
	if _keyboard_bar == null:
		var script: GDScript = load("res://ui/common/virtual_keyboard_bar.gd")
		if script != null:
			_keyboard_bar = script.new()
			add_child(_keyboard_bar)

func _sync_font() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene != null:
		GameUi.use_game_font(not GameUi.is_pregame_scene(scene))
