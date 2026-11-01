extends Node2D
## Demo scene logic: click to walk with A* over the obstacle grid, depth sorting with buildings, trap detection.
## Scene tree:   MapDemo (this script)
##                 |- Map     (Node2D + VltkMap.gd)   -> set Map Dir, set Focus = Player
##                 |- Player  (Node2D + Player.gd)

@onready var map: VltkMap = $Map
@onready var player: Node2D = $Player

const SPEED := 220.0               # scene units per second (y counts double, see VltkMap.walk_step)
var path := PackedVector2Array()
var _last_trap := 0
var _mini: TextureRect
var _dot: ColorRect


func _ready() -> void:
	# start in the middle of the playable area, on a walkable cell
	var r = map.data.get("rect")
	if r == null:
		r = [map.data["min_x"], map.data["min_y"], map.data["max_x"], map.data["max_y"]]
	var p := Vector2((float(r[0]) + float(r[2]) + 1.0) * 256.0, (float(r[1]) + float(r[3]) + 1.0) * 256.0)
	var c := map.world_to_cell(p)
	var found := false
	for ring in 40:
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				var cc := c + Vector2i(dx, dy)
				if map.grid.is_in_boundsv(cc) and not map.grid.is_point_solid(cc):
					p = map.cell_to_world(cc)
					found = true
					break
			if found:
				break
		if found:
			break
	player.reparent(map.objects_root)      # children of objects_root are depth-sorted with houses and trees
	player.global_position = p
	_make_minimap()


func _make_minimap() -> void:
	var tex := map.get_minimap_texture()
	if tex == null:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	_mini = TextureRect.new()
	_mini.texture = tex
	_mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini.stretch_mode = TextureRect.STRETCH_SCALE
	_mini.position = Vector2(12, 12)
	_mini.size = Vector2(260, 260.0 * tex.get_height() / tex.get_width())
	layer.add_child(_mini)
	# one yellow dot per NPC (hover it to read the name); the player is the red dot
	var k := _mini.size.x / float(tex.get_width())
	for n in map.minimap_npcs():
		var d := ColorRect.new()
		d.color = Color(1.0, 0.86, 0.15)
		d.size = Vector2(5, 5)
		d.position = n["mini"] * k - Vector2(2.5, 2.5)
		d.tooltip_text = "%s (npc %d)" % [n["name"], n["template"]]
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		_mini.add_child(d)
	_dot = ColorRect.new()
	_dot.color = Color.RED
	_dot.size = Vector2(6, 6)
	_mini.add_child(_dot)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			path = map.find_path(player.global_position, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:        # demo: right-click kills the monster under the cursor, it respawns later
			var m := map.monster_at(get_global_mouse_position())
			if m:
				map.kill_npc(m)
				print("Killed ", m.name, " - it comes back after its respawn time")


func _process(delta: float) -> void:
	if path.size() > 0:
		var r := map.walk_step(player.global_position, path, SPEED * delta)
		player.global_position = r[0]
		path = r[1]
	if _dot:
		var k := _mini.size.x / float(_mini.texture.get_width())
		_dot.position = map.world_to_minimap(player.global_position) * k - Vector2(3, 3)
	var trap := map.trap_at(player.global_position)
	if trap != 0 and trap != _last_trap:
		print("Trap id: 0x%X" % trap)
	_last_trap = trap
