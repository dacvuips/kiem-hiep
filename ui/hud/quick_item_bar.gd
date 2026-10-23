extends Control
class_name QuickItemBar
## 4 ô thuốc nhanh trên màn chơi (kiểu VLTK mobile: hàng ô tròn ngay trên cụm nút skill, góc dưới phải). Mỗi ô gán 1 loại thuốc
## (PlayerProfile.quick_items = mã misc_items), hiện ảnh + số bình còn trong túi.
##   - Bấm: uống 1 bình loại đó (PotionEffect.consume). Ô trống: mở bảng chọn.
##   - Giữ lâu / chuột phải: mở bảng chọn loại thuốc trong túi để gán vào ô (hoặc bỏ trống).
##   - Bấm thuốc trong Hành trang -> "Gắn vào ô 1..4"; hoặc kéo thuốc dùng được từ Hành trang (ItemRoomView) thả vào ô: gán loại thuốc đó vào ô.

const GROUP := &"quick_item_bar"
const SLOT_SIZE := 56.0
const GAP := 10.0
const RIGHT := 14.0
const BOTTOM := 306.0          ## mép dưới hàng ô, tính từ đáy màn hình — cách nút skill cao nhất đang hiện (SkillBarUI Sub4) 10px
const CORNER := 10             ## ô vuông bo góc
const HOLD_SECONDS := 0.45
const USE_COOLDOWN := 0.3
const REFRESH_EVERY := 0.5

var _slots: Array[Button] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _down_at := -1.0
var _last_use := -10.0
var _refresh_acc := 0.0

func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := 4
	var width := n * SLOT_SIZE + (n - 1) * GAP
	offset_right = -RIGHT
	offset_left = -RIGHT - width
	offset_bottom = -BOTTOM
	offset_top = -BOTTOM - SLOT_SIZE
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	for i in n:
		_slots.append(_make_slot(i, Vector2(i * (SLOT_SIZE + GAP), 0)))
	refresh()

func _make_slot(i: int, pos: Vector2) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Bấm: dùng · Giữ / chuột phải: chọn thuốc"
	var normal := GameUi.box(Color(0.05, 0.12, 0.08, 0.85), Color(0.55, 0.62, 0.42), CORNER, 2, 4)
	var pressed := GameUi.box(Color(0.10, 0.22, 0.14, 0.95), GameUi.BORDER_ACTIVE, CORNER, 2, 4)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", pressed)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.position = Vector2(10, 10)
	icon.size = Vector2(SLOT_SIZE - 20, SLOT_SIZE - 20)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	_icons.append(icon)
	var count := GameUi.label("", Color.WHITE, 15, HORIZONTAL_ALIGNMENT_CENTER)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 5)
	count.position = Vector2(0, SLOT_SIZE - 24)
	count.size = Vector2(SLOT_SIZE, 20)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(count)
	_counts.append(count)
	b.button_down.connect(func() -> void: _down_at = _now())
	b.button_up.connect(_on_slot_up.bind(i))
	b.set_drag_forwarding(Callable(), _can_drop.bind(i), _drop.bind(i))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			_open_picker(i))
	add_child(b)
	return b

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _on_slot_up(i: int) -> void:
	var held := _now() - _down_at if _down_at >= 0.0 else 0.0
	_down_at = -1.0
	var mid := _mid(i)
	if held >= HOLD_SECONDS or mid == "":
		_open_picker(i)
		return
	use_slot(i)

func _mid(i: int) -> String:
	var p := GameManager.local_profile
	return str(p.quick_items[i]) if p and i < p.quick_items.size() else ""

## Uống 1 bình của ô `i`.
func use_slot(i: int) -> void:
	var p := GameManager.local_profile
	var player := get_tree().get_first_node_in_group("player")
	if p == null or player == null or _now() - _last_use < USE_COOLDOWN:
		return
	if player.has_method("is_dead") and player.call("is_dead"):
		return
	var item := PotionEffect.first_in_inventory(p, _mid(i))
	if item == null:
		if player.has_method("notify"):
			player.notify("Đã hết %s" % str(ItemDatabase.get_misc(_mid(i)).get("name", "thuốc")))
		return
	var blocked := PotionEffect.block_reason(item)
	if blocked != "":
		if player.has_method("notify"):
			player.notify(blocked)
		return
	if not PotionEffect.consume(p, player, item):
		return
	_last_use = _now()
	SaveManager.save_profile(p)
	var inv := InventoryPopup.find_open(get_tree())
	if is_instance_valid(inv) and inv.has_method("_refresh"):
		inv.call("_refresh")
	refresh()

## Vẽ lại ảnh + số bình của 4 ô.
func refresh() -> void:
	var p := GameManager.local_profile
	for i in _slots.size():
		var mid := _mid(i)
		var rec := ItemDatabase.get_misc(mid) if mid != "" else {}
		_icons[i].texture = ItemDatabase.get_icon(rec) if not rec.is_empty() else null
		var n := PotionEffect.count_in_inventory(p, mid)
		_counts[i].text = str(n) if mid != "" else ""
		_icons[i].modulate = Color.WHITE if n > 0 or mid == "" else Color(0.45, 0.45, 0.45)
		_slots[i].tooltip_text = ("%s — bấm: dùng · giữ / chuột phải: đổi" % str(rec.get("name", ""))) if mid != "" else "Ô trống — bấm để chọn thuốc"

func _process(delta: float) -> void:
	_refresh_acc += delta
	if _refresh_acc >= REFRESH_EVERY:
		_refresh_acc = 0.0
		refresh()

## Bảng chọn thuốc (mọi loại thuốc / đan dùng được đang có trong túi) cho ô `i`.
func _open_picker(i: int) -> void:
	var p := GameManager.local_profile
	if p == null:
		return
	var win := SocialWindow.new("Ô thuốc %d" % (i + 1), "Chọn thuốc trong hành trang", 380.0)
	var seen := {}
	for it in p.inventory:
		if not PotionEffect.usable(it) or seen.has(it.misc_id):
			continue
		seen[it.misc_id] = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ItemDatabase.get_icon(it.get_base())
		row.add_child(icon)
		var name_l := SocialUi.label("%s  ×%d" % [it.get_display_name(), PotionEffect.count_in_inventory(p, it.misc_id)], SocialUi.TEXT, 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var pick := SocialUi.small_button("Chọn")
		var mid := it.misc_id
		pick.pressed.connect(func() -> void:
			_assign(i, mid)
			win.close_requested.emit())
		row.add_child(pick)
		win.body.add_child(row)
	if seen.is_empty():
		win.body.add_child(SocialUi.label("Hành trang chưa có thuốc / đan dùng được.", SocialUi.MUTED, 14))
	var buttons := win.add_button_row()
	var clear := SocialUi.stone_button("Bỏ trống")
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(func() -> void:
		_assign(i, "")
		win.close_requested.emit())
	buttons.add_child(clear)
	var close := SocialUi.stone_button("Đóng")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: win.close_requested.emit())
	buttons.add_child(close)
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var host := tree.current_scene if tree != null else null
	if host != null:
		SocialWindow.present(host, win, &"quick_item_picker")

## Thả món kéo từ hành trang: chỉ nhận thuốc / đan dùng được (PotionEffect.usable).
func _can_drop(_at: Vector2, data: Variant, _i: int) -> bool:
	return data is Dictionary and data.get("type") == ItemRoomView.DRAG_TYPE and PotionEffect.usable(data.get("item") as ItemInstance)

func _drop(_at: Vector2, data: Variant, i: int) -> void:
	_assign(i, (data["item"] as ItemInstance).misc_id)

func _assign(i: int, mid: String) -> void:
	var p := GameManager.local_profile
	if p == null:
		return
	p.quick_items[i] = mid
	SaveManager.save_profile(p)
	refresh()
