extends Node2D
class_name VltkWorld
## MAP CHÍNH của game (map VLTK gốc xuất từ tool map: VltkMap) — chỉ có 1 map duy nhất, nằm trong Main.tscn (node "World").
## Mỗi MÀN CHƠI (StageData) chỉ là 1 Ô VUÔNG trên map này (arena_center + arena_size, toạ độ pixel map):
##   - nhân vật và quái bị giới hạn trong ô vuông (VltkWorld.slide_velocity), rìa ô có hào quang sáng (ArenaBorder);
##   - quái sinh ở rìa TRONG của ô (random_edge_spawn); nhân vật xuất hiện ở ô trống gần tâm ô;
##   - vật cản của map (nhà, cây) bên trong ô vẫn chặn như bình thường.
## Map chỉ nạp các vùng quanh nhân vật (map có hàng trăm ô 512px) và nhân vật/quái nằm chung lớp vật thể của map
## để sắp độ sâu cùng nhà/cây (đi ra sau nhà thì bị che).
##
## Chỉ có 1 VltkWorld trong cây tại 1 thời điểm (biến tĩnh `current`). Main.load_stage() gọi setup_stage().

@export_dir var map_dir: String = "res://world/maps/map_321"

## Khoảng từ tâm node (Player/Enemy) xuống chân — Avatar đặt ở y = 30 trong player.tscn.
const FEET_OFFSET := 30.0
const SPAWN_SEARCH_RADIUS := 80
const EDGE_SPAWN_INSET := 70.0       ## quái sinh cách rìa trong ô vuông chừng này
const EDGE_SPAWN_TRIES := 12

static var current: VltkWorld
## Online: quái do game server điều khiển (NetWorldSync tạo) -> map KHÔNG tự sinh quái theo vùng.
static var net_monsters := false
## find_path() lần gần nhất chỉ tới được điểm gần đích (đích bị vật cản chia cắt).
static var last_path_partial := false

var map: VltkMap
## Ô vuông màn chơi hiện tại (toạ độ pixel map). size = 0 nghĩa là chưa có màn.
var arena_rect := Rect2()
var arena_border: ArenaBorder
## Điểm hồi sinh "Về thành dưỡng sức" (chiến trường: hậu doanh phe mình). INF = giữa ô màn chơi / điểm xuất phát của map.
var respawn_point := Vector2.INF
var _nav: AStarGrid2D   ## lưới tìm đường CHỈ trong ô vuông (sao từ lưới vật cản của map)
var _graph: NavGraph    ## map chính chia khối: tìm đường dài toàn map (tầng thô), null = không có

## VltkMap của game: bản gốc (world/VltkMap.gd, do tool map xuất — bị ghi đè mỗi lần cập nhật map) cộng thêm 3 việc, đặt ở ĐÂY
## để không mất khi cập nhật map:
##  1. Dời đường sắp độ sâu của vật thể (nhà, cây...) lên FEET_OFFSET: thực thể dùng gốc ở TÂM thân (chân thấp hơn FEET_OFFSET)
##     nên phải coi nó "đứng ở chân" khi so với đường sắp của nhà/cây. Hình vẽ không đổi (dời ngược lại cho sprite).
##  2. NẠP VÙNG KHÔNG GIẬT: bản gốc đọc ảnh nền + hàng chục ảnh vật thể ĐỒNG BỘ ngay khi nhân vật sang vùng mới (khựng ~70ms).
##     Ở đây ảnh được nạp ở LUỒNG PHỤ (ResourceLoader.load_threaded_*), xong mới dựng node, tối đa 1 vùng mỗi khung hình.
##  3. Số vùng nạp theo ĐỘ PHÓNG CAMERA (thu nhỏ thì thấy nhiều map hơn -> nạp xa hơn, không bị đen ở rìa) + dọn bộ nhớ ảnh không dùng.
class SortedMap extends VltkMap:
	const MARGIN_REGIONS := 1            ## nạp dư ra ngoài khung nhìn chừng này vùng
	const UNLOAD_EXTRA := 1              ## chỉ dỡ vùng cách khung nhìn quá MARGIN + chừng này (tránh nạp/dỡ liên tục ở mép)
	const SHOW_PER_FRAME := 1
	const PRUNE_INTERVAL := 4.0
	## NẠP TRƯỚC theo ý định đi: nhân vật đang chạy về hướng nào / vừa chọn đích ở đâu thì nạp sẵn các vùng ở hướng đó (dải 3 vùng rộng),
	## để tới nơi là có hình ngay, không khựng. Vùng nạp trước đi qua cùng hàng đợi (mỗi khung 1 vùng) nên không gây giật.
	const LOOKAHEAD_SECONDS := 3.0        ## nạp trước quãng đường chạy trong chừng này giây
	const LOOKAHEAD_MAX_REGIONS := 5      ## ... nhưng không quá chừng này vùng tính từ nhân vật (khung nhìn thường đã nạp sẵn ~3 vùng quanh nhân vật)
	const LOOKAHEAD_MIN_SPEED := 40.0     ## px/giây: chậm hơn coi như đứng yên
	const INTENT_MAX_REGIONS := 5         ## đích đã chọn: nạp trước tới chừng này vùng dọc đường tới đó
	const INTENT_TIMEOUT := 20.0

	var _region_index := {}               ## Vector2i(rx, ry) -> info [rx, ry, có_nền, có_vật_thể]
	var _done := {}                       ## "rx,ry" -> Vector2i: vùng đã dựng xong (kể cả vùng trống)
	var _pending := {}                    ## "rx,ry" -> {v, info, need: [đường dẫn ảnh đang nạp]}
	var _prune_time := 0.0
	var _region_scan_time := 0.0
	var _last_pos := Vector2.ZERO
	var _vel := Vector2.ZERO              ## vận tốc nhân vật đã làm mượt (px/giây)
	var _intent := Vector2.INF            ## điểm đích người chơi vừa chọn (toạ độ map), INF = không có
	var _intent_time := 0.0
	var lookahead_enabled := true         ## tắt để so sánh / máy rất yếu

	## Khối map nạp xong ở luồng phụ: bản gốc đánh dấu phải dựng lại CẢ lưới tìm đường (vài chục ms, chạy nhanh thì liên tục). Khối nằm
	## trong lưới đã được đọc đồng bộ lúc dựng lưới (_chunk_regions) nên khối đến sau luôn ở ngoài lưới -> không cần dựng lại.
	func _install_chunk(k: String, regs: Dictionary) -> void:
		var was_dirty := _nav_dirty
		super(k, regs)
		_nav_dirty = was_dirty

	## Dựng lưới tìm đường quanh vùng `c` — như bản gốc nhưng tô cả ĐOẠN ô bị chặn liền nhau (fill_solid_region theo cột) thay vì từng
	## ô một: ít lệnh gọi hơn nhiều, bớt khựng khi chạy nhanh qua nhiều vùng.
	func _update_nav(c: Vector2i) -> void:
		if not chunk_mode:
			return
		var half := maxi(1, nav_radius_regions / 2)
		if not _nav_dirty and absi(c.x - _nav_center.x) <= half and absi(c.y - _nav_center.y) <= half:
			return
		_nav_dirty = false
		_nav_center = c
		var r := nav_radius_regions
		grid.region = Rect2i((c.x - r) * 16, (c.y - r) * 32, (2 * r + 1) * 16, (2 * r + 1) * 32)
		grid.update()
		for ry in range(c.y - r, c.y + r + 1):
			for rx in range(c.x - r, c.x + r + 1):
				var regs := _chunk_regions(chunk_of(rx, ry))
				var d = regs.get("%d,%d" % [rx, ry])
				if d == null:                  ## không có vùng: không ai đi vào
					grid.fill_solid_region(Rect2i(rx * 16, ry * 32, 16, 32), true)
					continue
				var runs: Array = (d as Dictionary).get("ob", [])
				var i := 0
				var j := 0
				while j + 1 < runs.size():
					var n := int(runs[j + 1])
					if (int(runs[j]) >> 4) != 0:
						var q := i
						var end := mini(i + n, 512)
						while q < end:               ## ô q = (q / 32, q % 32): đoạn liền nhau nằm dọc 1 cột
							var y := q % 32
							var length := mini(end - q, 32 - y)
							grid.fill_solid_region(Rect2i(rx * 16 + q / 32, ry * 32 + y, 1, length), true)
							q += length
					i += n
					j += 2
		_nav_dirty = false

	## Dời lưới tìm đường gần về đúng vùng của `world_pos` ngay (đã đúng thì thôi) — đường dài tìm tiếp đoạn sau từ đây.
	func recenter_nav(world_pos: Vector2) -> void:
		if not chunk_mode:
			return
		var c := world_to_region(world_pos - global_position)
		if c != _nav_center:
			_nav_dirty = true
			_update_nav(c)

	## Báo cho map biết người chơi định đi tới `world_pos` (chạm/bấm đích, mini map...) để nạp trước các vùng dọc đường tới đó.
	func set_intent(world_pos: Vector2) -> void:
		_intent = world_pos
		_intent_time = INTENT_TIMEOUT

	## Các vùng cần nạp TRƯỚC (ngoài khung nhìn hiện tại): dải 3 vùng rộng dọc hướng chạy và dọc đường tới đích đã chọn.
	func _lookahead_cells(from_pos: Vector2) -> Dictionary:
		var out := {}
		if not lookahead_enabled:
			return out
		var targets: Array = []
		var speed := _vel.length()
		if speed > LOOKAHEAD_MIN_SPEED:
			var dist := minf(speed * LOOKAHEAD_SECONDS, LOOKAHEAD_MAX_REGIONS * 512.0)
			targets.append([from_pos + _vel.normalized() * dist, dist])
		if _intent != Vector2.INF:
			var to := _intent - from_pos
			var d := minf(to.length(), INTENT_MAX_REGIONS * 512.0)
			if d > 256.0:
				targets.append([from_pos + to.normalized() * d, d])
		for t in targets:
			var end: Vector2 = t[0]
			var steps := maxi(1, ceili(float(t[1]) / 256.0))
			for i in range(1, steps + 1):
				var rc := world_to_region(from_pos.lerp(end, float(i) / float(steps)) - global_position)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var v := Vector2i(rc.x + dx, rc.y + dy)
						out["%d,%d" % [v.x, v.y]] = v
		return out

	## Thông tin vùng lấy qua VltkMap.region_info() (map chia khối không còn danh sách mọi vùng trong map.json).
	func _index_regions() -> void:
		pass

	## Nạp ĐỒNG BỘ các vùng quanh `world_pos` ngay lúc vào màn (đang là lúc "tải") để khung đầu tiên không bị đen.
	func warm_up(world_pos: Vector2, radius: int = 2) -> void:
		if data.is_empty():
			return
		_index_regions()
		var c := world_to_region(world_pos - global_position)
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var v := Vector2i(c.x + dx, c.y + dy)
				var key := "%d,%d" % [v.x, v.y]
				if _done.has(key):
					continue
				var inf := region_info(v)
				if not inf.is_empty():
					_show_region(v.x, v.y, inf)
				_done[key] = v

	func _process(delta: float) -> void:
		if focus == null or data.is_empty():
			return
		_update_actors(delta)       ## NPC / sinh vật nền đi lại (bản gốc làm ở _process mà override này đã thay)
		_tick_respawns()
		_index_regions()
		var vp := focus.get_viewport()
		var cam := vp.get_camera_2d()
		var view := vp.get_visible_rect().size / (cam.zoom if cam else Vector2.ONE)
		var c := world_to_region(focus.global_position - global_position)
		stream_tick(c)              ## map chia khối: nạp khối quanh nhân vật ở luồng phụ + lưới tìm đường đi theo nhân vật
		var rx := ceili(view.x * 0.5 / 512.0) + MARGIN_REGIONS
		var ry := ceili(view.y * 0.5 / 512.0) + MARGIN_REGIONS
		## Vận tốc làm mượt (nhảy vị trí > 3000px/giây = dịch chuyển, bỏ qua) + hết hạn / tới nơi thì bỏ ý định.
		var pos := focus.global_position
		if delta > 0.0:
			var inst := (pos - _last_pos) / delta
			_vel = Vector2.ZERO if inst.length() > 3000.0 else _vel.lerp(inst, clampf(delta * 4.0, 0.0, 1.0))
		_last_pos = pos
		if _intent != Vector2.INF:
			_intent_time -= delta
			if _intent_time <= 0.0 or pos.distance_to(_intent) < 384.0:
				_intent = Vector2.INF
		_region_scan_time -= delta
		if _region_scan_time <= 0.0 or not _pending.is_empty():
			_region_scan_time = 0.15   ## quét nạp/dỡ vùng ~7 lần/giây thay vì mỗi khung hình (tạo chuỗi key + sort rất tốn)
			var ahead := _lookahead_cells(pos)
			## Dỡ vùng đã đi xa (trừ vùng đang nạp trước).
			for key in _done.keys():
				var v: Vector2i = _done[key]
				if (absi(v.x - c.x) > rx + UNLOAD_EXTRA or absi(v.y - c.y) > ry + UNLOAD_EXTRA) and not ahead.has(key):
					_hide_region(key)
					_done.erase(key)
			for key in _pending.keys():
				var v: Vector2i = _pending[key]["v"]
				if (absi(v.x - c.x) > rx + UNLOAD_EXTRA or absi(v.y - c.y) > ry + UNLOAD_EXTRA) and not ahead.has(key):
					_pending.erase(key)
			## Yêu cầu nạp vùng mới, gần nhân vật trước.
			var todo := []
			for y in range(c.y - ry, c.y + ry + 1):
				for x in range(c.x - rx, c.x + rx + 1):
					var key := "%d,%d" % [x, y]
					if _done.has(key) or _pending.has(key):
						continue
					var v := Vector2i(x, y)
					if region_info(v).is_empty():
						_done[key] = v          ## ngoài map / vùng trống
						continue
					todo.append([(x - c.x) * (x - c.x) + (y - c.y) * (y - c.y), v])
			for key in ahead:                       ## vùng nạp trước xếp SAU các vùng đang cần ngay (khoảng cách + 1000)
				var av: Vector2i = ahead[key]
				if _done.has(key) or _pending.has(key):
					continue
				if region_info(av).is_empty():
					continue
				todo.append([1000 + (av.x - c.x) * (av.x - c.x) + (av.y - c.y) * (av.y - c.y), av])
			todo.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			for item in todo:
				_request(item[1])
		_poll()
		_prune_time += delta
		if _prune_time >= PRUNE_INTERVAL:
			_prune_time = 0.0
			_prune_textures()

	## Gửi yêu cầu nạp nền + mọi ảnh vật thể của vùng sang luồng phụ.
	func _request(v: Vector2i) -> void:
		var info: Array = region_info(v)
		var paths: Array[String] = []
		if ground_mode == "tiles" and int(info[2]) == 1:
			paths.append(map_dir.path_join("tiles/%d_%d.%s" % [v.x, v.y, tile_ext]))
		if int(info[3]) == 1:
			var parsed := region_doc(v.x, v.y)              ## regions/X_Y.json hoặc mục của vùng trong file khối
			for o in parsed.get("objects", []):
				var p := map_dir.path_join(str(o["img"]))
				if not paths.has(p):
					paths.append(p)
			for c in parsed.get("covers", []):         ## nền dạng atlas: cover là sprite rời
				var cp := map_dir.path_join(str(c[0]))
				if not paths.has(cp):
					paths.append(cp)
		var need: Array[String] = []
		for p in paths:
			if _tex_cache.has(p):
				continue
			if ResourceLoader.exists(p):
				ResourceLoader.load_threaded_request(p)
				need.append(p)
			else:
				_tex_cache[p] = null
		_pending["%d,%d" % [v.x, v.y]] = {"v": v, "info": info, "need": need}

	## Vùng nào nạp xong hết ảnh thì dựng node (tối đa SHOW_PER_FRAME vùng/khung).
	func _poll() -> void:
		var shown := 0
		for key in _pending.keys():
			var entry: Dictionary = _pending[key]
			var need: Array = entry["need"]
			for p in need.duplicate():
				if _tex_cache.has(p):
					need.erase(p)
					continue
				var st := ResourceLoader.load_threaded_get_status(p)
				if st == ResourceLoader.THREAD_LOAD_LOADED:
					_tex_cache[p] = ResourceLoader.load_threaded_get(p)
					need.erase(p)
				elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					_tex_cache[p] = load(p) if ResourceLoader.exists(p) else null
					need.erase(p)
			if need.is_empty() and shown < SHOW_PER_FRAME:
				var v: Vector2i = entry["v"]
				_show_region(v.x, v.y, entry["info"])   ## ảnh đã có trong _tex_cache -> không đọc đĩa
				_done[key] = v
				_pending.erase(key)
				shown += 1

	## Bản gốc giữ MỌI ảnh đã từng nạp trong _tex_cache mãi mãi (đi khắp map = hàng trăm MB). Bỏ ảnh không còn vùng nào dùng.
	func _prune_textures() -> void:
		for p in _tex_cache.keys():
			var tex: Variant = _tex_cache[p]
			if tex is RefCounted and (tex as RefCounted).get_reference_count() <= 1:
				_tex_cache.erase(p)

	## QUÁI THẬT thay cho hình tĩnh của bản gốc: mỗi điểm đặt quái role="monster" có mẫu trong MonsterData được sinh thành VltkMonster
	## (đi tuần, đuổi, đánh bằng skill gốc, máu/dame theo cấp). Điểm không có dữ liệu mẫu giữ hình tĩnh của bản gốc.
	var _respawns: Array = []         ## [{n, at}] quái đã chết chờ sinh lại
	var _live_monsters := {}          ## uid -> VltkMonster đang sống

	## Bản gốc chỉ vẽ ảnh NPC (không có bóng) -> thêm bóng elip mờ dưới chân (gốc node holder = chân), vẽ trước ảnh.
	func _add_shadow(holder: Node2D) -> void:
		var sprite := holder.get_child(0) as Sprite2D if holder.get_child_count() > 0 else null
		var half_w := 20.0
		if sprite != null and sprite.texture != null:
			half_w = clampf(float(sprite.texture.get_width()) * 0.28, 12.0, 60.0)
		var shadow := NpcShadow.new()
		shadow.half_width = half_w
		holder.add_child(shadow)
		holder.move_child(shadow, 0)

	## Dỡ vùng: quái đã chết (đã queue_free) vẫn nằm trong danh sách vùng — bản gốc gọi queue_free() lên node đã giải phóng nên báo lỗi.
	## Ở đây bỏ qua node không còn hợp lệ, và quái còn sống bị dỡ cùng vùng (sinh lại khi nhân vật quay lại, máu đầy).
	func _hide_region(key: String) -> void:
		if _tiles.has(key):
			_tiles[key].queue_free()
			_tiles.erase(key)
		if _objects.has(key):
			for node in _objects[key]:
				if not is_instance_valid(node):
					continue
				if node is VltkMonster:
					var uid := str((node.get_meta("npc", {}) as Dictionary).get("uid", ""))
					if _live_monsters.get(uid) == node:
						_live_monsters.erase(uid)
				node.queue_free()
			_objects.erase(key)

	func _is_real_monster(n: Dictionary) -> bool:
		return str(n.get("role", "")) == "monster" and not MonsterData.monster(int(n.get("t", -1))).is_empty()

	## Quái thật do override này sinh -> bản gốc bỏ qua chúng.
	func _spawn_filter(n: Dictionary) -> bool:
		return not _is_real_monster(n)

	func _spawn_npcs(rx: int, ry: int, made: Array) -> void:
		var before := made.size()
		super._spawn_npcs(rx, ry, made)      ## NPC, sinh vật nền, quái không có dữ liệu mẫu
		for i in range(before, made.size()):
			_add_shadow(made[i])
		for n in region_npcs(rx, ry):
			if _is_real_monster(n):
				var m := _spawn_monster(n)
				if m != null:
					made.append(m)

	func _spawn_monster(n: Dictionary) -> VltkMonster:
		if VltkWorld.net_monsters:
			return null
		var uid := str(n.get("uid", ""))
		if _live_monsters.has(uid) and is_instance_valid(_live_monsters[uid]):
			return null
		if _dead_until.has(uid) and Time.get_ticks_msec() / 1000.0 < float(_dead_until[uid]):
			return null
		var m := VltkMonster.new()
		m.monster_id = int(n["t"])
		m.data = MonsterData.monster(m.monster_id).duplicate()
		m.data["series"] = clampi(int(n.get("series", m.data.get("series", 0))), 0, 4)   ## hệ do map đặt
		m.level = maxi(1, int(n.get("lv", 1)))
		## Map Địa Ngục (Vượt Ải): quái cấp 110 / 120, máu - sát thương - rơi đồ nhân số sao.
		var hell: Dictionary = GameManager.field_map.get("hell", {})
		if not hell.is_empty():
			m.level = int(hell.get("level", m.level))
			m.hell_stars = clampi(int(hell.get("stars", 1)), 1, MapCatalog.HELL_MAX_STARS)
		m.ai_enabled = true
		m.blue_boss = randf() < DropTable.BLUE_BOSS_CHANCE   ## như script Revive gốc: mỗi lần sinh / sinh lại có ~2% thành boss xanh
		m.position = Vector2(float(n["px"]), float(n["py"]))
		m.set_meta("npc", n)
		m.died.connect(_on_monster_died.bind(n))
		objects_root.add_child(m)
		_live_monsters[uid] = m
		return m

	func _on_monster_died(_m: VltkMonster, n: Dictionary) -> void:
		var uid := str(n.get("uid", ""))
		_live_monsters.erase(uid)
		var wait := float(n.get("respawn", 40))
		_dead_until[uid] = Time.get_ticks_msec() / 1000.0 + (wait if wait > 0.0 else 1.0e12)
		_respawns.append({"n": n, "at": float(_dead_until[uid])})

	## Quái đã chết: hết thời gian chờ thì sinh lại tại chỗ cũ (nếu vùng của nó đang được nạp).
	func _tick_respawns() -> void:
		if _respawns.is_empty():
			return
		var now := Time.get_ticks_msec() / 1000.0
		for r in _respawns.duplicate():
			if now < float(r["at"]):
				continue
			_respawns.erase(r)
			var n: Dictionary = r["n"]
			if _done.has("%d,%d" % [int(n["rx"]), int(n["ry"])]):
				_dead_until.erase(str(n.get("uid", "")))
				var m := _spawn_monster(n)
				if m != null and _objects.has("%d,%d" % [int(n["rx"]), int(n["ry"])]):
					_objects["%d,%d" % [int(n["rx"]), int(n["ry"])]].append(m)

	func _show_region(rx: int, ry: int, info: Array = []) -> void:
		var key := "%d,%d" % [rx, ry]
		var had := _objects.has(key)
		super._show_region(rx, ry, info)
		if had or not _objects.has(key):
			return
		for holder in _objects[key]:
			if holder.get_parent() != objects_root or holder is VltkMonster:
				continue   ## quái VltkMonster có gốc ở CHÂN, không cần dời đường sắp như vật thể
			holder.position.y -= FEET_OFFSET
			for child in holder.get_children():
				if child is Node2D:
					child.position.y += FEET_OFFSET

## Bóng elip mờ dưới chân NPC / sinh vật nền của map.
class NpcShadow extends Node2D:
	var half_width := 20.0
	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(cos(a) * half_width, sin(a) * half_width * 0.4))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.32))

func _ready() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

## Dựng map (lần đầu) + đặt ô vuông của màn `stage` + đưa nhân vật vào giữa ô. Gọi 1 lần lúc vào màn.
func setup_stage(stage: StageData) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_ensure_map(player)
	var center := stage.arena_center if stage.arena_center != Vector2.ZERO else _default_center()
	arena_rect = Rect2(center - stage.arena_size * 0.5, stage.arena_size)
	if arena_border == null:
		arena_border = ArenaBorder.new()
		arena_border.name = "ArenaBorder"
		add_child(arena_border)
	arena_border.position = center
	arena_border.setup(stage.arena_size, stage.arena_color)
	_build_nav()
	if player != null:
		player.global_position = _free_position_near(center) - Vector2(0, FEET_OFFSET)
		(map as SortedMap).warm_up(player.global_position)
		_adopt.call_deferred(player)

## Lưới A* nhỏ phủ đúng ô vuông (vài chục nghìn ô) — đường đi không bao giờ vòng ra ngoài ô.
func _build_nav() -> void:
	var tl := map.world_to_cell(arena_rect.position)
	var br := map.world_to_cell(arena_rect.end)
	var reg := Rect2i(tl, br - tl + Vector2i.ONE)
	_nav = AStarGrid2D.new()
	_nav.region = reg
	_nav.cell_size = map.cell
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav.update()
	for x in range(reg.position.x, reg.end.x):
		for y in range(reg.position.y, reg.end.y):
			var c := Vector2i(x, y)
			if map.grid.is_in_boundsv(c) and map.grid.is_point_solid(c):
				_nav.set_point_solid(c, true)

## Ô trống gần `c` nhất trong lưới tìm đường (c đã bị chặn / nằm ngoài thì dịch tới ô trống gần nhất).
func _nav_free_cell(c: Vector2i) -> Vector2i:
	var reg := _nav.region
	c = Vector2i(clampi(c.x, reg.position.x, reg.end.x - 1), clampi(c.y, reg.position.y, reg.end.y - 1))
	if not _nav.is_point_solid(c):
		return c
	for radius in range(1, 40):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var n := c + Vector2i(dx, dy)
				if _nav.is_in_boundsv(n) and not _nav.is_point_solid(n):
					return n
	return c

## Đường đi (các điểm CHÂN, toạ độ pixel map) từ `from_feet` tới `to_feet`, vòng qua vật cản, ở trong ô vuông màn chơi.
## Đích nằm ngoài ô / trong vật cản thì dịch về ô trống gần nhất. Mảng rỗng nếu không có đường.
static func find_path(from_feet: Vector2, to_feet: Vector2) -> PackedVector2Array:
	var w := current
	if w == null or w._nav == null:
		return PackedVector2Array([to_feet])
	(w.map as SortedMap).set_intent(to_feet)     ## nạp trước các vùng dọc đường tới đích
	last_path_continues = false
	last_route_ahead = PackedVector2Array()
	var a := w._nav_free_cell(w.map.world_to_cell(from_feet))
	var goal_cell := w.map.world_to_cell(to_feet)
	## Map chính: đích ngoài lưới gần (hoặc lưới gần không có đường) -> lộ trình thô trên toàn map (NavGraph).
	if w._graph != null and w.arena_rect.size == Vector2.ZERO and w._graph.is_ready():
		if not w._nav.is_in_boundsv(goal_cell):
			return w._find_long_path(from_feet, to_feet, a)
	var b := w._nav_free_cell(goal_cell)
	last_path_partial = false
	var raw := w._nav.get_point_path(a, b)
	if raw.is_empty() and a != b and w._graph != null and w.arena_rect.size == Vector2.ZERO and w._graph.is_ready():
		return w._find_long_path(from_feet, to_feet, a)   ## bị chia cắt trong lưới gần: có thể phải vòng ra ngoài
	if raw.is_empty() and a != b:
		## Đích nằm ở vùng bị vật cản (sông, tường) chia cắt: đi tới ô GẦN đích nhất mà đi tới được.
		var near: Vector2i = w._nearest_reachable(a, b)
		if near != a:
			raw = w._nav.get_point_path(a, near)
			last_path_partial = not raw.is_empty()
	## Điểm cuối thật = tâm ô đích (đã dịch khỏi vật cản nếu cần). Bó đường: bỏ các điểm trung gian khi nhìn thẳng tới được —
	## đường ra ít góc, thẳng, nhân vật không đi zích-zắc theo ô lưới.
	if raw.is_empty():
		return PackedVector2Array()
	var pts: Array[Vector2] = [from_feet]
	for i in range(1, raw.size()):
		pts.append(raw[i] + w.map.cell * 0.5)
	if pts.size() == 1:
		return PackedVector2Array([to_feet] if not last_path_partial else [])
	if w._line_clear(from_feet, to_feet) and not last_path_partial and w._nav.is_in_boundsv(w.map.world_to_cell(to_feet)) 			and not w._blocked_at(to_feet):
		return PackedVector2Array([to_feet])
	pts[pts.size() - 1] = to_feet if (not last_path_partial and not w._blocked_at(to_feet)) else pts[pts.size() - 1]
	return w._smooth(pts)

## Bó đường: bỏ các điểm trung gian khi nhìn thẳng tới được (pts[0] = điểm xuất phát, không có trong kết quả).
func _smooth(all_pts: Array[Vector2]) -> PackedVector2Array:
	## Bỏ trước các điểm nằm thẳng hàng (đường ô lưới dài hàng trăm điểm, chỉ chỗ RẼ mới cần xét) — bớt hẳn số lần _line_clear.
	var pts: Array[Vector2] = [all_pts[0]]
	for k in range(1, all_pts.size() - 1):
		var d1 := (all_pts[k] - pts[pts.size() - 1]).normalized()
		var d2 := (all_pts[k + 1] - all_pts[k]).normalized()
		if d1.dot(d2) < 0.999:
			pts.append(all_pts[k])
	if all_pts.size() > 1:
		pts.append(all_pts[all_pts.size() - 1])
	var out := PackedVector2Array()
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _line_clear(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out

## true = find_path() lần gần nhất chỉ trả ĐOẠN ĐẦU của đường dài (tới mép lưới gần): đi hết đoạn thì gọi lại find_path() tới cùng đích.
static var last_path_continues := false
## Phần lộ trình thô còn lại sau đoạn đầu (điểm CHÂN, cuối = đích) — chỉ để vẽ đường chấm trên bản đồ.
static var last_route_ahead := PackedVector2Array()

const LONG_PATH_MAX_TRIES := 4
const LONG_PATH_MARGIN_REGIONS := 1   ## chỉ nhắm nút thô cách mép lưới gần >= chừng này vùng (mép lưới có thể chưa đúng)

## Đường dài: A* trên đồ thị toàn map (NavGraph) tìm lộ trình thô — vòng khắp map, không chỉ nhắm thẳng hướng đích — rồi A* ô lưới tới nút
## thô cuối cùng của phần lộ trình còn nằm liền trong lưới gần. Nhân vật đi hết đoạn này thì tìm tiếp (lưới gần đã dời theo nhân vật).
func _find_long_path(from_feet: Vector2, to_feet: Vector2, a: Vector2i) -> PackedVector2Array:
	var goal_cell := map.world_to_cell(to_feet)
	var goal_near := _nav.is_in_boundsv(goal_cell)
	var start_node := _graph.node_at(a, _region_reach(a))
	var goal_node := _graph.node_at(_nav_free_cell(goal_cell) if goal_near else goal_cell,
			_region_reach(_nav_free_cell(goal_cell)) if goal_near else {})
	var ids := _graph.route(start_node, goal_node)
	if ids.size() < 2:
		return PackedVector2Array()
	last_path_partial = ids[ids.size() - 1] != goal_node
	var reg := _nav.region.grow_individual(-LONG_PATH_MARGIN_REGIONS * 16, -LONG_PATH_MARGIN_REGIONS * 32,
			-LONG_PATH_MARGIN_REGIONS * 16, -LONG_PATH_MARGIN_REGIONS * 32)
	## Chỉ xét PHẦN ĐẦU LIỀN MẠCH của lộ trình trong lưới gần: lộ trình có thể ra khỏi lưới, vòng xa rồi quay lại — nút ở đoạn quay lại
	## không tới được nếu chỉ đi trong lưới. Nhắm nút cuối của phần đầu đó (thử lùi vài nút nếu A* ô lưới không tới được).
	var last_in := 0
	while last_in + 1 < ids.size() and reg.has_point(_graph.node_cell(ids[last_in + 1])):
		last_in += 1
	if last_in == 0:
		last_in = 1   ## nút kế đã ngoài vùng an toàn (sát mép lưới): vẫn thử đi tới nó
	var tries := 0
	for k in range(last_in, 0, -1):
		var c := _graph.node_cell(ids[k])
		if not _nav.is_in_boundsv(c) or _nav.is_point_solid(c):
			continue
		tries += 1
		if tries > LONG_PATH_MAX_TRIES:
			break
		var at_goal := k == ids.size() - 1 and not last_path_partial and goal_near
		var target := _nav_free_cell(goal_cell) if at_goal else c
		var raw := _nav.get_point_path(a, target)
		if raw.is_empty():
			continue
		var pts: Array[Vector2] = [from_feet]
		for i in range(1, raw.size()):
			pts.append(raw[i] + map.cell * 0.5)
		if at_goal and not _blocked_at(to_feet):
			pts.append(to_feet)
		if pts.size() < 2:
			continue
		last_path_continues = not at_goal
		for j in range(k + 1, ids.size()):
			last_route_ahead.append(_graph.node_position(ids[j]))
		if last_path_continues and not last_path_partial:
			last_route_ahead.append(to_feet)
		return _smooth(pts)
	return PackedVector2Array()

## Các ô (Vector2i) đi tới được từ `c` (loang 4 hướng trên lưới gần) mà vẫn trong vùng 512x512 chứa `c` — để biết `c` thuộc mảng đất nào.
func _region_reach(c: Vector2i) -> Dictionary:
	var r0 := Vector2i(floori(float(c.x) / 16.0) * 16, floori(float(c.y) / 32.0) * 32)
	var box := Rect2i(r0, Vector2i(16, 32))
	var seen := {c: true}
	var stack: Array[Vector2i] = [c]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + step
			if box.has_point(n) and not seen.has(n) and _nav.is_in_boundsv(n) and not _nav.is_point_solid(n):
				seen[n] = true
				stack.append(n)
	return seen

const LOS_STEP := 8.0
const LOS_CLEARANCE := 7.0   ## nhân vật "dày" chừng này pixel mỗi bên khi đi sát tường

## Đi thẳng từ a tới b có bị vật cản / ngoài ô chặn không (kiểm tra dọc đoạn và 2 bên theo bề rộng thân).
func _line_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return true
	var dir := d / length
	var side := Vector2(-dir.y, dir.x) * LOS_CLEARANCE
	var n := int(ceilf(length / LOS_STEP))
	for k in range(n + 1):
		var p := a + dir * minf(float(k) * LOS_STEP, length)
		if _blocked_at(p) or _blocked_at(p + side) or _blocked_at(p - side):
			return false
	return true

## Ô đi tới được từ `a` (loang theo 4 hướng trong lưới tìm đường) mà gần `b` nhất. Chỉ chạy khi không có đường thẳng tới đích.
func _nearest_reachable(a: Vector2i, b: Vector2i) -> Vector2i:
	var seen := {a: true}
	var queue: Array[Vector2i] = [a]
	var best := a
	var best_d := (a - b).length_squared()
	var head := 0
	while head < queue.size() and head < 150000:   ## giới hạn để map lớn (hàng trăm nghìn ô) không treo máy
		var c := queue[head]
		head += 1
		var d := (c - b).length_squared()
		if d < best_d:
			best_d = d
			best = c
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + step
			if not seen.has(n) and _nav.is_in_boundsv(n) and not _nav.is_point_solid(n):
				seen[n] = true
				queue.append(n)
	return best

## Kéo điểm CHÂN `feet` vào trong ô vuông màn chơi.
static func clamp_to_arena(feet: Vector2) -> Vector2:
	if not has_arena():
		return feet
	var r := current.arena_rect
	return Vector2(clampf(feet.x, r.position.x, r.end.x), clampf(feet.y, r.position.y, r.end.y))

## Chế độ "Chơi" (map chính, đi lại tự do): dựng map, KHÔNG có ô vuông / hào quang, nhân vật đứng ở ô trống gần tâm khu chơi.
func setup_main_map() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_ensure_map(player)
	arena_rect = Rect2()
	if arena_border != null:
		arena_border.queue_free()
		arena_border = null
	_nav = map.grid   ## tìm đường trên cả map (lưới vật cản gốc; map chia khối: lưới đi theo nhân vật)
	if _graph == null and map.chunk_mode:
		_graph = NavGraph.load_for(map_dir, map.cell)   ## đường dài toàn map (dựng ở luồng phụ)
	## Tìm kiểu "nhảy cóc" (JPS): lưới gần ~225 nghìn ô, nhanh hơn ~3 lần, đường gần như y hệt (đã bó thẳng sau đó).
	_nav.jumping_enabled = true
	map.prepare_around(_default_center())   ## map chia khối: nạp khối + lưới tìm đường ở chỗ xuất hiện trước khi tìm ô trống
	if player != null:
		player.global_position = _free_position_near(_default_center()) - Vector2(0, FEET_OFFSET)
		(map as SortedMap).warm_up(player.global_position)
		_adopt.call_deferred(player)

## Giữ nhân vật trong `rect` (toạ độ pixel map, rìa sáng như ô màn chơi) — chiến trường: doanh trại lúc chưa khai chiến.
## Rect2() = bỏ giới hạn. Không dựng lại lưới tìm đường: chỉ chặn ở rìa (clamp_to_arena).
func set_confine(rect: Rect2) -> void:
	if rect == arena_rect:
		return
	arena_rect = rect
	if not rect.has_area():
		if arena_border != null:
			arena_border.queue_free()
			arena_border = null
		return
	if arena_border == null:
		arena_border = ArenaBorder.new()
		arena_border.name = "ArenaBorder"
		add_child(arena_border)
	arena_border.position = rect.get_center()
	arena_border.setup(rect.size, Color(0.98, 0.62, 0.30))

## Đưa nhân vật về điểm xuất phát (hồi sinh "Về thành dưỡng sức"): giữa ô vuông màn chơi nếu có, không thì điểm xuất phát của map.
func place_at_start(node: Node2D) -> void:
	var center := respawn_point if respawn_point != Vector2.INF else (arena_rect.get_center() if arena_rect.has_area() else _default_center())
	map.prepare_around(center)
	node.global_position = _free_position_near(center) - Vector2(0, FEET_OFFSET)
	(map as SortedMap).warm_up(node.global_position)

## Dựng VltkMap lần đầu: phải có `focus` TRƯỚC khi vào cây, nếu không nạp cả nghìn vùng.
func _ensure_map(player: Node2D) -> void:
	if map != null:
		return
	map = SortedMap.new()
	map.name = "Map"
	map.map_dir = map_dir
	map.focus = player
	add_child(map)  ## _ready của VltkMap nạp map.json + dựng lưới vật cản; vùng hiển thị nạp theo `focus` ở _process

## Đưa 1 thực thể (Player/quái) vào lớp vật thể của map để sắp độ sâu cùng nhà/cây.
func _adopt(node: Node2D) -> void:
	if not is_instance_valid(node) or map == null or node.get_parent() == map.objects_root:
		return
	node.reparent(map.objects_root, true)

## Nơi sinh quái/đặt thực thể mới: lớp vật thể của map (null nếu không có map -> dùng cha mặc định).
static func entity_parent() -> Node:
	if current != null and current.map != null:
		return current.map.objects_root
	return null

## Có ô vuông màn chơi đang hoạt động không.
static func has_arena() -> bool:
	return current != null and current.arena_rect.size != Vector2.ZERO

## Vị trí TÂM thân (không phải chân) để sinh quái: dọc rìa TRONG của ô vuông, ô không vật cản. Hết lượt thử thì lấy điểm cuối.
static func random_edge_spawn() -> Vector2:
	var w := current
	var r := w.arena_rect.grow(-EDGE_SPAWN_INSET)
	var feet := r.position
	for i in EDGE_SPAWN_TRIES:
		match randi() % 4:
			0: feet = Vector2(randf_range(r.position.x, r.end.x), r.position.y)
			1: feet = Vector2(randf_range(r.position.x, r.end.x), r.end.y)
			2: feet = Vector2(r.position.x, randf_range(r.position.y, r.end.y))
			_: feet = Vector2(r.end.x, randf_range(r.position.y, r.end.y))
		if w.map == null or not w.map.is_blocked(feet):
			break
	return feet - Vector2(0, FEET_OFFSET)

## Tâm khu chơi của map: tâm vùng có nền gần tâm hình chữ nhật các vùng nhất.
func _default_center() -> Vector2:
	var data := map.data
	if data.has("start"):                   ## map chia khối: vùng xuất hiện do tool map chọn sẵn
		return (Vector2(float(data["start"][0]), float(data["start"][1])) + Vector2(0.5, 0.5)) * 512.0
	var rect: Array = data.get("rect", [0, 0, 1, 1])
	var center := Vector2((float(rect[0]) + float(rect[2]) + 1.0) * 0.5, (float(rect[1]) + float(rect[3]) + 1.0) * 0.5) * 512.0
	var best := center
	var best_d := INF
	for r in data["regions"]:
		if int(r[2]) != 1:
			continue
		var c := Vector2(int(r[0]) + 0.5, int(r[1]) + 0.5) * 512.0
		var d := c.distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = c
	return best

## Ô trống (xung quanh 2 ô cũng trống) gần `point` nhất, duyệt xoắn ốc — vị trí CHÂN nhân vật.
func _free_position_near(point: Vector2) -> Vector2:
	var start := map.world_to_cell(point)
	for radius in SPAWN_SEARCH_RADIUS:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := start + Vector2i(dx, dy)
				if _clear_around(c):
					return map.cell_to_world(c)
	return point

func _clear_around(c: Vector2i) -> bool:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var cc := c + Vector2i(dx, dy)
			if not map.grid.is_in_boundsv(cc) or map.grid.is_point_solid(cc):
				return false
	return true

## Chân đứng tại `feet` có bị chặn không: ô vật cản của map HOẶC ngoài ô vuông màn chơi (khi đã có ô).
func _blocked_at(feet: Vector2) -> bool:
	if map.is_blocked(feet):
		return true
	return arena_rect.size != Vector2.ZERO and not arena_rect.has_point(feet)

## Giảm vận tốc để thực thể có chân tại `feet` không bước vào ô vật cản của map và không ra khỏi ô vuông màn chơi
## (trượt dọc tường theo từng trục). Đang đứng sẵn trong chỗ bị chặn (vd quái sinh ra trong nhà) thì không giữ lại.
static func slide_velocity(feet: Vector2, velocity: Vector2, delta: float) -> Vector2:
	var w := current
	if w == null or w.map == null or w.map.grid == null or velocity == Vector2.ZERO:
		return velocity
	if w._blocked_at(feet):
		return velocity
	var step := velocity * delta
	if not w._blocked_at(feet + step):
		return velocity
	if step.x != 0.0 and not w._blocked_at(feet + Vector2(step.x, 0.0)):
		return Vector2(velocity.x, 0.0)
	if step.y != 0.0 and not w._blocked_at(feet + Vector2(0.0, step.y)):
		return Vector2(0.0, velocity.y)
	return Vector2.ZERO
