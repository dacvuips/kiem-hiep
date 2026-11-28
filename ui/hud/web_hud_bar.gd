extends Control

class_name WebHudBar

## THANH DƯỚI bản WEB (chuột + bàn phím) = nguyên thanh công cụ giao diện 1024x768 của client VLTK gốc:
## \Ui\Ui3\UiPlayerBar.ini trong data/1024.pak, ảnh \spr\Ui3\thanhcongcu\jx1024.spr (xuất bằng tools/import_vltk_web_bar.py
## ra assets/ui/web_bar/). Toạ độ dưới đây lấy thẳng từ ini, trừ gốc cắt ảnh (0, CROP_TOP):
##   - [InputBack] ô nhập chat + [ChannelBtn] kênh + [InputEdit] ô gõ + [Face] biểu cảm + [SendBtn] gửi — dựng thành 1 dải
##     (ChatInputStrip — dùng chung với bản mobile) đặt NGOÀI khung chat bên trái, ngay dưới khung (ChatBox.dock_input_strip).
##     Chỗ cũ trên thanh để trống (ảnh gốc trong suốt) -> khung chat hạ sát phần có hình của thanh (chat_floor_height).
##   - 9 ô vật phẩm [Item_0..8] số 1..9 (PlayerProfile.quick_items): phím 1-9 (ShortcutUseItem) hoặc bấm CHUỘT PHẢI vào ô
##     = dùng (gốc WND_N_RIGHT_CLICK_ITEM -> OnUseItem); bấm trái / giữ = chọn vật phẩm cho ô; kéo thuốc từ hành trang thả vào.
##   - [ImediaLeftSkill] T = skill chuột trái (bấm trái vào địch = đánh liên tục), [ImediaRightSkill] P = skill chuột phải
##     (giữ chuột phải = ra chiêu về con trỏ). Bấm T / P mở bảng chọn (WebSkillPicker); phím Q E R Y U H = phím tắt đổi skill.
##     Cơ chế xem WebMouseSkills.
##   - Thanh công cụ bên phải (工具控制条.ini): hàng nút tròn (Ngồi, Chạy, Ngựa, Giao dịch, Ghi hình, PK) + hàng nút vuông
##     (Nhân vật, Đồ dùng, Túi mở rộng, Võ công, Nhiệm vụ, Hảo hữu, Tổ đội, Bang phái, Phòng chat, Tùy chọn) + Kỳ Trân Các.
##     Main gắn việc cho từng nút qua set_action / set_state; nút game chưa có chức năng thì mờ đi.
## Trên web cụm nút skill tròn bên phải (SkillBarUI), 4 ô thuốc bên phải, hàng nút menu cũ và joystick ảo bị ẩn — thanh này
## dùng chung dữ liệu / thao tác của chúng (QuickItemBar.use_slot, PlayerProfile.main_skill_id ...).

const ART_DIR := "res://assets/ui/web_bar/"
## Ảnh gốc vẽ cho màn 1024 ngang; màn game 1280 -> phóng 1.25 (giữ đúng tỉ lệ so với màn).
const ART_SCALE := 1.25
const CROP_TOP := 672.0
const ART_H := 97.0
## [Item_0..8] Left (Top = 719, 36x36).
const ITEM_X := [136, 174, 212, 250, 288, 326, 366, 402, 440]
const ITEM_Y := 719.0
const SLOT_SIZE := 36.0
const SKILL_POS := [Vector2(492, 697), Vector2(529, 697)]   ## [ImediaLeftSkill] / [ImediaRightSkill]
const INPUT_BACK := Rect2(134, 688, 329, 28)
const CHANNEL_BTN := Rect2(134, 687, 20, 20)
## Ô vuông đặt ảnh kênh trong ảnh nền [InputBack] (đo trên input_back_0.png: lòng ô 20x20 tại (2, 2)) — ini [ChannelBtn]
## (134, 687) là chỗ chữ nhúng của gốc, đặt ảnh theo đó bị lệch lên / sang trái 2-3 px.
const CHANNEL_SOCKET := Rect2(136, 690, 20, 20)
const INPUT_EDIT := Rect2(163, 693, 248, 15)
const FACE_BTN := Rect2(416, 690, 20, 20)
const SEND_BTN := Rect2(439, 690, 21, 20)
const INPUT_COLOR := Color8(254, 255, 160)          ## [InputEdit] Color
const CHANNEL_COLOR := Color8(255, 217, 78)         ## [ChannelBtn] Color / OverColor / SelColor
const CHANNEL_OVER := Color8(0, 255, 0)
const CHANNEL_SEL := Color8(205, 167, 28)
const MARGIN := 0.0
## Hàng ảnh (trong bar.png, tính từ CROP_TOP) nơi phần có hình bắt đầu ở cột trái (x < 470) — phía trên trong suốt (chỗ ô nhập
## gốc, nay dời xuống khung chat).
const CHAT_FLOOR_ROW := 30.0
## Nút thanh công cụ: id (ảnh btn_<id>_N.png), ô theo ini, lời nhắc, check = nút bật/tắt (Up / Down theo ini; Ngựa ngược: Up=1 Down=0).
const TOOL_BUTTONS := [
	{"id": "sit", "rect": Rect2(656, 675, 31, 31), "tip": "Ngồi (phím V)"},
	{"id": "run", "rect": Rect2(687, 675, 31, 31), "tip": "Chạy bộ / đi bộ"},
	{"id": "horse", "rect": Rect2(719, 675, 31, 31), "tip": "Lên / xuống ngựa (phím M)", "reverse": true},
	{"id": "exchange", "rect": Rect2(750, 675, 31, 31), "tip": "Đóng / mở giao dịch (phím F7 / T)"},
	{"id": "rec", "rect": Rect2(783, 675, 31, 31), "tip": "Ghi hình"},
	{"id": "pk", "rect": Rect2(815, 675, 31, 31), "tip": "Chế độ PK (phím F9)"},
	{"id": "status", "rect": Rect2(580, 728, 28, 28), "tip": "Nhân vật (phím F3 / C)"},
	{"id": "items", "rect": Rect2(611, 728, 28, 28), "tip": "Đồ dùng (phím F4 / B)"},
	{"id": "itemex", "rect": Rect2(642, 728, 28, 28), "tip": "Túi hành trang"},
	{"id": "skills", "rect": Rect2(673, 728, 28, 28), "tip": "Võ công (phím F5 / K)"},
	{"id": "task", "rect": Rect2(704, 728, 28, 28), "tip": "Nhiệm vụ"},
	{"id": "friend", "rect": Rect2(735, 728, 28, 28), "tip": "Hảo hữu (phím F8)"},
	{"id": "team", "rect": Rect2(766, 728, 28, 28), "tip": "Quản lý đội ngũ (phím P)"},
	{"id": "faction", "rect": Rect2(797, 728, 28, 28), "tip": "Bang phái (phím F6)"},
	{"id": "chatroom", "rect": Rect2(828, 728, 28, 28), "tip": "Phòng chat"},
	{"id": "options", "rect": Rect2(859, 728, 28, 28), "tip": "Tùy chỉnh (phím F2)"},
	{"id": "market", "rect": Rect2(876, 680, 74, 61), "tip": "Kỳ Trân Các (phím F11)"},
]

static var _forced := -1

## Bản web dùng thanh này. Thử trên máy: biến môi trường KIEMHIEP_WEB_HUD=1 hoặc tham số dòng lệnh --web-hud.
static func enabled() -> bool:
	if _forced == -1:
		_forced = 1 if (OS.has_feature("web") or OS.get_environment("KIEMHIEP_WEB_HUD") == "1"
				or OS.get_cmdline_user_args().has("--web-hud") or OS.get_cmdline_args().has("--web-hud")) else 0
	return _forced == 1

## Chiều cao toàn thanh (px màn hình) — ChatBox đặt khung tin ngay trên.
static func total_height() -> float:
	return ART_H * ART_SCALE

## Khoảng từ đáy màn tới mép trên phần có hình của thanh ở cột trái — ChatBox đặt khung (kèm dải ô nhập) ngay trên mức này.
static func chat_floor_height() -> float:
	return (ART_H - CHAT_FLOOR_ROW) * ART_SCALE

## Toạ độ ini (màn 1024x768) -> toạ độ trong thanh.
static func _p(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y - CROP_TOP) * ART_SCALE

static func _r(r: Rect2) -> Rect2:
	return Rect2(_p(r.position), r.size * ART_SCALE)

var _player: Node
var _skill_bar: SkillBarUI
var _items: QuickItemBar

var _chat_taken := false
var _strip: ChatInputStrip                ## dải ô nhập gốc ([InputBack]...) — đặt ngay dưới khung chat

var _slots: Array[Button] = []            ## 9 ô số
var _icons: Array[TextureRect] = []
var _cds: Array[ColorRect] = []            ## lớp tối hồi chiêu (phủ từ trên xuống theo tỉ lệ)
var _counts: Array[Label] = []
var _skill_slots: Array[Button] = []      ## T / P
var _skill_icons: Array[TextureRect] = []
var _skill_cds: Array[ColorRect] = []

var _tool_buttons: Dictionary = {}       ## id -> TextureButton
var _tool_frames: Dictionary = {}        ## id -> [khung 0, khung 1, khung 2 | null]
var _actions: Dictionary = {}            ## id -> Callable (không tham số)
var _states: Dictionary = {}             ## id -> Callable -> bool (nút bật/tắt)

var _item_down_at := -1.0
var _item_refresh := 0.0

func setup(player: Node, skill_bar: SkillBarUI, items: QuickItemBar) -> void:
	_player = player
	_skill_bar = skill_bar
	_items = items

## Gắn việc cho nút thanh công cụ `id` (VD "status", "items"...). Nút không có việc thì mờ đi, bấm không làm gì.
func set_action(id: String, action: Callable) -> void:
	_actions[id] = action
	_refresh_tool_button(id)

## Nút bật/tắt `id`: `getter` trả true khi đang bật (đang ngồi, đang cưỡi ngựa...).
func set_state(id: String, getter: Callable) -> void:
	_states[id] = getter

func get_tool_button(id: String) -> Control:
	return _tool_buttons.get(id) as Control

func _build_tool_buttons() -> void:
	for d in TOOL_BUTTONS:
		var id: String = d["id"]
		var frames: Array = []
		for i in 3:
			var path := ART_DIR + "btn_%s_%d.png" % [id, i]
			frames.append(load(path) if ResourceLoader.exists(path) else null)
		if d.get("reverse", false):
			frames = [frames[1], frames[0], frames[2]]
		_tool_frames[id] = frames
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		b.focus_mode = Control.FOCUS_NONE
		var r := _r(d["rect"])
		b.position = r.position
		b.size = r.size
		b.texture_normal = frames[0]
		b.texture_pressed = frames[1]
		b.texture_hover = frames[2]
		b.pressed.connect(func() -> void:
			var a: Callable = _actions.get(id, Callable())
			if a.is_valid():
				a.call())
		add_child(b)
		_tool_buttons[id] = b
		_refresh_tool_button(id)

func _refresh_tool_button(id: String) -> void:
	var b := _tool_buttons.get(id) as TextureButton
	if b == null:
		return
	var has_action: bool = (_actions.get(id, Callable()) as Callable).is_valid()
	b.disabled = not has_action
	b.modulate = Color.WHITE if has_action else Color(1, 1, 1, 0.45)
	var tip := ""
	for d in TOOL_BUTTONS:
		if d["id"] == id:
			tip = d["tip"]
	b.tooltip_text = tip if has_action else tip + " (chưa có)"

## Nút bật/tắt: khung Down khi đang bật, Up khi tắt.
func _sync_tool_states() -> void:
	for id in _states:
		var b := _tool_buttons.get(id) as TextureButton
		var g: Callable = _states[id]
		if b == null or not g.is_valid():
			continue
		var frames: Array = _tool_frames[id]
		var on: bool = g.call()
		b.texture_normal = frames[1] if on else frames[0]
		if frames[2] == null:
			b.texture_hover = b.texture_normal

func _ready() -> void:
	name = "WebHudBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar: Texture2D = load(ART_DIR + "bar.png")
	var size_px := Vector2(bar.get_width(), bar.get_height()) * ART_SCALE
	_art(bar, Rect2(Vector2.ZERO, size_px))
	## Dải ô nhập chat gốc (ChatInputStrip) — gắn ngay dưới khung chat ở _dock_chat.
	_strip = ChatInputStrip.new()

	for i in ITEM_X.size():
		_make_slot(i, _p(Vector2(ITEM_X[i], ITEM_Y)), SLOT_SIZE * ART_SCALE)
	for k in 2:
		_make_skill_slot(k, _p(SKILL_POS[k]), SLOT_SIZE * ART_SCALE)

	_build_tool_buttons()
	tree_exiting.connect(func() -> void:   ## dải chưa gắn vào khung chat thì không có cha -> tự giải phóng
		if is_instance_valid(_strip) and _strip.get_parent() == null:
			_strip.queue_free())

	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = MARGIN
	offset_right = MARGIN + size_px.x
	offset_top = -size_px.y
	offset_bottom = 0.0

func _chat_ok() -> bool:
	return ChatBox.current != null and is_instance_valid(ChatBox.current)

func _art(tex: Texture2D, rect: Rect2, parent: Node = null) -> void:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(r)

## Nút trong suốt phủ đúng ô của ảnh gốc + ảnh / lớp hồi chiêu.
func _slot_button(pos: Vector2, side: float) -> Array:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(side, side)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.0)
	hover.border_color = Color(1.0, 0.85, 0.35, 0.9)
	hover.set_border_width_all(1)
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for st in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hover)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.position = Vector2(3, 3)
	icon.size = Vector2(side - 6, side - 6)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var cd := ColorRect.new()
	cd.color = Color(0, 0, 0, 0.6)
	cd.position = Vector2(3, 3)
	cd.size = Vector2(side - 6, 0)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cd)
	add_child(b)
	return [b, icon, cd]

func _make_slot(i: int, pos: Vector2, side: float) -> void:
	var parts := _slot_button(pos, side)
	var b: Button = parts[0]
	_slots.append(b)
	_icons.append(parts[1])
	_cds.append(parts[2])
	var count := GameUi.label("", Color.WHITE, 12, HORIZONTAL_ALIGNMENT_RIGHT)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 4)
	count.position = Vector2(0, side - 18)
	count.size = Vector2(side - 4, 16)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(count)
	_counts.append(count)
	b.button_down.connect(func() -> void: _item_down_at = QuickItemBar._now())
	b.button_up.connect(_on_item_up.bind(i))
	b.set_drag_forwarding(Callable(), func(at: Vector2, data: Variant) -> bool: return _items != null and _items._can_drop(at, data, i),
			func(at: Vector2, data: Variant) -> void: _items._drop(at, data, i))
	## Chuột phải = dùng (gốc KUiPlayerBar WND_N_RIGHT_CLICK_ITEM -> OnUseItem).
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and _items != null:
			b.accept_event()
			if _items._mid(i) != "":
				_items.use_slot(i))

func _make_skill_slot(k: int, pos: Vector2, side: float) -> void:
	var parts := _slot_button(pos, side)
	var b: Button = parts[0]
	_skill_slots.append(b)
	_skill_icons.append(parts[1])
	_skill_cds.append(parts[2])
	## Gốc: bấm trái ô T / P (WND_N_LEFT_CLICK_ITEM) = KUiSkillTree::OpenWindow(trái / phải).
	b.pressed.connect(func() -> void:
		if _player == null or not is_instance_valid(_player):
			return
		if WebSkillPicker.current != null and is_instance_valid(WebSkillPicker.current):
			WebSkillPicker.close_current()
			return
		WebSkillPicker.open(get_parent(), _player, k == 0, b.get_global_rect(), ART_SCALE, Callable()))

## Bấm trái ô vật phẩm: ô trống / giữ lâu = chọn vật phẩm cho ô (gốc: nhấc / đặt vật phẩm vào ô).
func _on_item_up(i: int) -> void:
	if _items == null:
		return
	_item_down_at = -1.0
	_items._open_picker(i)

## Phím 1..9 = dùng vật phẩm ô 1..9 (ShortcutUseItem); Q E R Y U H = phím tắt skill (ShortcutSkill 0..5) khi bảng chọn
## đóng (bảng mở thì WebSkillPicker bắt phím để gán).
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f is LineEdit or f is TextEdit:
		return
	if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
		get_viewport().set_input_as_handled()
		var i := int(k.physical_keycode - KEY_1)
		if _items != null and i < _slots.size() and _items._mid(i) != "":
			_items.use_slot(i)
		return
	var idx := WebMouseSkills.SHORTCUT_KEYS.find(k.physical_keycode)
	if idx >= 0:
		get_viewport().set_input_as_handled()
		WebMouseSkills.apply_shortcut(idx, _player)

func _dock_chat() -> void:
	if _strip.attach(ChatBox.current):
		_chat_taken = true
		ChatBox.current.dock_input_strip(_strip)   ## dải ô nhập ngay dưới khung chat bên trái

func _process(delta: float) -> void:
	if not _chat_taken and _chat_ok():
		_dock_chat()
	_sync_tool_states()
	if _player == null or not is_instance_valid(_player) or GameManager.local_profile == null:
		return
	var controller: SectSkillController = _player.skill_controller
	var profile: PlayerProfile = GameManager.local_profile
	var survivor := _skill_bar != null and _skill_bar.is_survivor_mode()
	_show_skill(0, null if survivor else WebMouseSkills.left_skill(controller), controller, profile, "chuột trái: bấm vào địch = đánh liên tục; Shift + bấm = ra chiêu tại con trỏ")
	_show_skill(1, null if survivor else WebMouseSkills.right_skill(controller), controller, profile, "chuột phải: giữ = ra chiêu về phía con trỏ")
	_item_refresh -= delta
	if _item_refresh <= 0.0:
		_item_refresh = QuickItemBar.REFRESH_EVERY
		_refresh_items(profile)

func _show_skill(k: int, skill: SkillDefinition, controller: SectSkillController, profile: PlayerProfile, how: String) -> void:
	var b := _skill_slots[k]
	var icon := _skill_icons[k]
	var cd := _skill_cds[k]
	icon.texture = skill.icon if skill != null else null
	if skill == null:
		cd.size.y = 0.0
		b.modulate = Color.WHITE
		b.tooltip_text = ""
		return
	cd.size.y = icon.size.y * clampf(controller.get_cooldown_ratio(skill.id), 0.0, 1.0)
	b.modulate = SkillBarUI.AURA_ON_TINT if controller.is_aura_active(skill) else Color.WHITE
	b.tooltip_text = "%s — %s. Bấm ô để chọn skill." % [skill.skill_name, how]

func _refresh_items(profile: PlayerProfile) -> void:
	for i in _slots.size():
		var mid := _items._mid(i) if _items != null else ""
		var rec := ItemDatabase.get_misc(mid) if mid != "" else {}
		var n := PotionEffect.count_in_inventory(profile, mid) if mid != "" else 0
		_icons[i].texture = ItemDatabase.get_icon(rec) if not rec.is_empty() else null
		_icons[i].visible = n > 0
		_counts[i].text = str(n) if n > 0 else ""
		_slots[i].tooltip_text = ("%s — phím %d / chuột phải: dùng · bấm trái: đổi" % [str(rec.get("name", "")), i + 1]) if mid != "" \
				else "Ô vật phẩm trống — bấm để chọn"
