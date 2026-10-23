extends Node
## Autoload: gộp theme giao diện chung (GameUi) vào theme project ngay khi khởi động — trước mọi màn/popup — và đổi font theo màn:
## màn đăng nhập / đăng ký / chọn server / nhân vật giữ font cũ, vào game (Hub, bản đồ...) dùng font trong game (GameUi.game_font).

func _enter_tree() -> void:
	GameUi.apply()
	get_tree().scene_changed.connect(_sync_font)
	_sync_font.call_deferred()

func _sync_font() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene != null:
		GameUi.use_game_font(not GameUi.is_pregame_scene(scene))
