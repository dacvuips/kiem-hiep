extends RefCounted
class_name GuildEmblem
## Biểu tượng Bang Hội (16x16 pixel-art có viền tối, tương tự Guild Mark MU / huy hiệu bang VLTK).
## Dùng chung cho tên trên đầu nhân vật (Player, RemotePlayer) và giao diện Bang Hội (GuildWindow, GuildListWindow).

const ICON_SIZE := 16

## Mỗi mẫu: {name, colors: {char: Color}, rows: Array[String]} (16 dòng x 16 ký tự).
## Ký tự '.' = trong suốt, 'O' = viền đen đậm.
const PRESETS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Hoàng Thuẫn",
		"colors": {"B": Color8(165, 34, 34), "C": Color8(225, 58, 48), "H": Color8(255, 212, 74), "G": Color8(245, 178, 36)},
		"rows": [
			"....OOOOOOOO....",
			"..OOGGGGGGGGOO..",
			".OGHHHHHHHHHHGO.",
			".OGBBCCCCCCBBGO.",
			".OGBCCHHHHCCBGO.",
			".OGBCHHHHHHCBGO.",
			".OGBCHHBBHHCBGO.",
			".OGBCHHHHHHCBGO.",
			".OGBCCHHHHCCBGO.",
			"..OGBCCBBCCBGO..",
			"..OGBCCCCCCBGO..",
			"...OGBBCCBBGO...",
			"...OOGBBBBGOO...",
			"....OOGBBGOO....",
			".....OOGGOO.....",
			"......OOOO......",
		],
	},
	{
		"id": 2,
		"name": "Thanh Long",
		"colors": {"B": Color8(18, 92, 64), "C": Color8(42, 198, 128), "H": Color8(168, 255, 206), "G": Color8(255, 216, 72)},
		"rows": [
			".....OOOOOO.....",
			"...OOCCHHCCO....",
			"..OCCHGGGGHCO...",
			".OCCHGG..GGHCO..",
			".OCCHG.OO.GHCO..",
			".OCCBOOOOOOBCO..",
			"..OOBCCHHCCBOO..",
			"...OBCHHHHCBO...",
			"..OBCHHGGHHCBO..",
			".OBCHGG..GGHCBO.",
			".OCCHGO..OGHCCO.",
			".OCCHCOOOCCHCCO.",
			"..OCCHHHHHHCCO..",
			"...OOCCHHCCOO...",
			".....OOOOOO.....",
			"................",
		],
	},
	{
		"id": 3,
		"name": "Huyễn Kiếm",
		"colors": {"B": Color8(36, 78, 148), "C": Color8(92, 182, 255), "H": Color8(225, 246, 255), "G": Color8(255, 202, 56)},
		"rows": [
			".......OO.......",
			"......OHHO......",
			"......OCHO......",
			".....OCBHCO.....",
			".....OCBHCO.....",
			".....OCBHCO.....",
			".....OCBHCO.....",
			".....OCBHCO.....",
			".....OCBHCO.....",
			"..OOOOCBHCOOOO..",
			".OGGGGGHHGGGGGO.",
			"..OOOOGBBGOOOO..",
			"......OGGO......",
			"......OGGO......",
			".....OGHHGO.....",
			".....OOOOOO.....",
		],
	},
	{
		"id": 4,
		"name": "Hỏa Diễm",
		"colors": {"B": Color8(168, 36, 18), "C": Color8(255, 112, 32), "H": Color8(255, 234, 96), "G": Color8(255, 174, 48)},
		"rows": [
			".......OO.......",
			"......OCCO......",
			".....OCCHCO.....",
			"....OCCHHHCO....",
			"...OBCCHHHCCO...",
			"..OBCCHHHHHCCO..",
			"..OBCHHHHHHCBO..",
			".OBCHHGGGGHHCBO.",
			".OBCHGGHHGGHCBO.",
			".OBCHGH..HGHCBO.",
			".OBBCHHGGHHCBBO.",
			"..OBBCHHHHCBBO..",
			"..OOBBCCCCBBOO..",
			"...OOBBBBBBOO...",
			"....OOOOOOOO....",
			"................",
		],
	},
	{
		"id": 5,
		"name": "Thái Cực",
		"colors": {"B": Color8(24, 34, 58), "C": Color8(72, 138, 224), "H": Color8(244, 244, 248), "G": Color8(242, 194, 62)},
		"rows": [
			"....OOOOOOOO....",
			"..OOGGGGGGGGOO..",
			".OGHHHHHHHHBBGO.",
			".OGHHHHHHHBBBGO.",
			".OGHHHBBHHBBBGO.",
			".OGHHHBBHHBBBGO.",
			".OGHHHHHHHHBBGO.",
			".OGHHHHHBBBBGBO.",
			".OGHHHHBBBBBBGO.",
			".OGHHHBBBBBBBGO.",
			".OGHHBBBHHBBBGO.",
			".OGHHBBBHHBBBGO.",
			".OGHHBBBBBBBBGO.",
			"..OOGGGGGGGGOO..",
			"....OOOOOOOO....",
			"................",
		],
	},
	{
		"id": 6,
		"name": "Vương Miện",
		"colors": {"B": Color8(122, 68, 14), "C": Color8(240, 178, 38), "H": Color8(255, 238, 128), "G": Color8(232, 48, 64)},
		"rows": [
			"................",
			".OO....OO....OO.",
			"OHHO..OGGO..OHHO",
			"OCCHO.OCCHO.OCCO",
			"OCCHCOCCHHCOCCHO",
			"OBCCHCCGGCCCHBCO",
			"OBCCHCCCCCCCHBCO",
			"OBCCCCCCCCCCCCBO",
			"OBCHHHHHHHHHHCBO",
			"OBCGGGGGGGGGGCBO",
			"OBBBBBBBBBBBBBBO",
			".OOGGGGGGGGGGOO.",
			"..OOOOOOOOOOOO..",
			"................",
			"................",
			"................",
		],
	},
	{
		"id": 7,
		"name": "Bạch Liên",
		"colors": {"B": Color8(128, 38, 92), "C": Color8(246, 132, 198), "H": Color8(255, 228, 245), "G": Color8(255, 212, 74)},
		"rows": [
			".......OO.......",
			"......OHHO......",
			".....OCHHCO.....",
			"..OO.OCHHCO.OO..",
			".OCHOOCHHCOOHCO.",
			".OCCHCHHHHCHCCO.",
			"..OCCHHHHHHCCO..",
			".OOBCHHHHHHCBOO.",
			"OCHHHGGGGGGHHHCO",
			"OCCHHGGGGGGHHCCO",
			".OBCCHHHHHHCCBO.",
			"..OOBCCCCCCBOO..",
			"....OOBBBBBOO...",
			"....OOGGGGOO....",
			".....OOOOOO.....",
			"................",
		],
	},
	{
		"id": 8,
		"name": "Lôi Đình",
		"colors": {"B": Color8(48, 36, 128), "C": Color8(124, 96, 245), "H": Color8(255, 236, 76), "G": Color8(120, 232, 255)},
		"rows": [
			"....OOOOOOOO....",
			"..OOBBBBBBBBOO..",
			".OBBBCCGGCCBBBO.",
			".OBBCCHHHGCCBBO.",
			".OBBCHHHGGCCBBO.",
			".OBCHHHGGCCBBBO.",
			".OBCHHHHHHGGBBO.",
			".OBBGGGGHHHCBBO.",
			".OBBBBCHHHCCBBO.",
			".OBBBCHHHGCCBBO.",
			".OBBCHHHGCCBBBO.",
			".OBBCHHGGCCBBBO.",
			"..OBBCHGCCBBBO..",
			"...OOBBBBBBOO...",
			"....OOOOOOOO....",
			"................",
		],
	},
	{
		"id": 9,
		"name": "Chu Tước",
		"colors": {"B": Color8(152, 24, 42), "C": Color8(242, 72, 72), "H": Color8(255, 206, 84), "G": Color8(255, 136, 44)},
		"rows": [
			"......OOOO......",
			".OO..OHHHHO..OO.",
			"OCHOOCHGGHCOOHCO",
			"OCCHHCHGGHCHHCCO",
			".OCCHHGGGGHHCCO.",
			".OBCCCHHHHCCCBO.",
			"..OBCCHHHHCCBO..",
			"...OBCHHHHCBO...",
			"..OOBCHGGHCBOO..",
			".OCCHHG..GHHCCO.",
			".OCCHGO..OGHCCO.",
			"..OBBCO..OCBBO..",
			"...OOBO..OBOO...",
			"....OO....OO....",
			"................",
			"................",
		],
	},
	{
		"id": 10,
		"name": "Bạch Hổ",
		"colors": {"B": Color8(58, 66, 82), "C": Color8(192, 206, 224), "H": Color8(248, 252, 255), "G": Color8(255, 190, 56)},
		"rows": [
			"..OO........OO..",
			".OHHO..OO..OHHO.",
			".OCCHOHHHHOCHCO.",
			".OCHHHHHHHHHHCO.",
			".OCHBBHHHHBBHCO.",
			".OCHGGHHHHGGHCO.",
			".OHHHHHHHHHHHHO.",
			".OCHBHHHHHHBHCO.",
			"..OCHHHHHHHHCO..",
			"..OCHHGHHGHHCO..",
			"...OCHHHHHHCO...",
			"...OOCCHHCCOO...",
			"....OOHHHHOO....",
			".....OOOOOO.....",
			"................",
			"................",
		],
	},
	{
		"id": 11,
		"name": "Nguyệt Ảnh",
		"colors": {"B": Color8(36, 24, 78), "C": Color8(146, 98, 228), "H": Color8(246, 224, 128), "G": Color8(186, 152, 255)},
		"rows": [
			"....OOOOOOOO....",
			"..OOBBBBBBBBOO..",
			".OBBBBBHHBBBBBO.",
			".OBBBHHHHHBBBBO.",
			".OBBHHHHHBBBBBO.",
			".OBBHHHHBBBGBBO.",
			".OBBHHHBBGGGBBO.",
			".OBBHHHBBBBBBBO.",
			".OBBHHHHBBBBGBO.",
			".OBBHHHHHBBBBBO.",
			".OBBBHHHHHBBBBO.",
			".OBBBBBHHBBBBBO.",
			"..OOBBBBBBBBOO..",
			"....OOOOOOOO....",
			"................",
			"................",
		],
	},
	{
		"id": 12,
		"name": "Thiên Tinh",
		"colors": {"B": Color8(18, 86, 108), "C": Color8(52, 198, 218), "H": Color8(255, 238, 124), "G": Color8(248, 184, 48)},
		"rows": [
			".......OO.......",
			"......OHHO......",
			"......OHHO......",
			".....OGHHGO.....",
			".OOOOOGHHGOOOOO.",
			"OHHHHHHGGHHHHHHO",
			".OHHHHHHHHHHHHO.",
			"..OOHHHHHHHHOO..",
			"...OHHGGGGHHO...",
			"...OHHGOOGHHO...",
			"..OGHHO..OHHGO..",
			"..OHHO....OHHO..",
			"..OOO......OOO..",
			"................",
			"................",
			"................",
		],
	},
]

const OUTLINE_COLOR := Color(0.06, 0.04, 0.04, 0.98)

static var _cache: Dictionary = {}   ## "id|size" -> ImageTexture

static func count() -> int:
	return PRESETS.size()

static func clamp_id(emblem_id: int) -> int:
	if emblem_id <= 0:
		return 1
	return clampi(emblem_id, 1, PRESETS.size())

static func emblem_name(emblem_id: int) -> String:
	var idx := clamp_id(emblem_id) - 1
	return str(PRESETS[idx]["name"])

## Lấy ID biểu tượng từ Dictionary bang hội; nếu bang cũ chưa lưu "emblem", suy ra cố định từ tên bang.
static func resolve_id(guild_dict: Dictionary) -> int:
	if guild_dict.is_empty():
		return 0
	var raw := int(guild_dict.get("emblem", 0))
	if raw >= 1 and raw <= PRESETS.size():
		return raw
	var gname := str(guild_dict.get("name", ""))
	if gname == "":
		return 0
	return 1 + (absi(gname.hash()) % PRESETS.size())

static func get_texture(emblem_id: int, size_px: int = ICON_SIZE) -> Texture2D:
	if emblem_id <= 0:
		return null
	var id := clamp_id(emblem_id)
	var px := maxi(8, size_px)
	var key := "%d|%d" % [id, px]
	if _cache.has(key):
		return _cache[key]
	var preset: Dictionary = PRESETS[id - 1]
	var colors: Dictionary = preset["colors"]
	var rows: Array = preset["rows"]
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in mini(rows.size(), ICON_SIZE):
		var line: String = str(rows[y])
		for x in mini(line.length(), ICON_SIZE):
			var ch := line.substr(x, 1)
			if ch == ".":
				continue
			elif ch == "O":
				img.set_pixel(x, y, OUTLINE_COLOR)
			elif colors.has(ch):
				img.set_pixel(x, y, colors[ch])
	if px != ICON_SIZE:
		img.resize(px, px, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func create_icon_rect(emblem_id: int, display_size := Vector2(18, 18)) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = get_texture(emblem_id, ICON_SIZE)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = display_size
	tr.size = display_size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if emblem_id > 0:
		tr.tooltip_text = "Biểu tượng: %s" % emblem_name(emblem_id)
	return tr

## Tạo hàng/lưới nút chọn biểu tượng bang hội. Trả về {node: GridContainer, get_selected: Callable}.
static func create_picker(initial_id: int, on_pick: Callable = Callable(), columns: int = 6) -> Dictionary:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var state := {"id": clamp_id(initial_id)}
	var buttons: Array[Button] = []
	var refresh := func() -> void:
		for i in buttons.size():
			var btn := buttons[i]
			var active := (i + 1) == int(state["id"])
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.22, 0.17, 0.07, 0.95) if active else Color(0.08, 0.09, 0.12, 0.85)
			sb.set_border_width_all(2 if active else 1)
			sb.border_color = Color(0.96, 0.80, 0.28, 1.0) if active else Color(0.30, 0.34, 0.42, 0.85)
			sb.set_corner_radius_all(4)
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_stylebox_override("pressed", sb)
	for idx in PRESETS.size():
		var eid := idx + 1
		var b := Button.new()
		b.custom_minimum_size = Vector2(34, 34)
		b.tooltip_text = emblem_name(eid)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := create_icon_rect(eid, Vector2(22, 22))
		cc.add_child(icon)
		b.add_child(cc)
		b.pressed.connect(func() -> void:
			state["id"] = eid
			refresh.call()
			if on_pick.is_valid():
				on_pick.call(eid))
		buttons.append(b)
		grid.add_child(b)
	refresh.call()
	return {"node": grid, "get_selected": func() -> int: return int(state["id"])}

