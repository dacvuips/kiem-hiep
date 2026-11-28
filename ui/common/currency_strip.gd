extends HBoxContainer
class_name CurrencyStrip

## Dải tiền tệ (Lượng / Xu / Kim Nguyên Bảo) đặt ngay DƯỚI mọi khung Hành trang — 1 chỗ dùng chung cho Hub,
## Giao Dịch, Bày Bán... Bản offline chỉ hiện Lượng (Xu/KNB là tiền online).
## Tự cập nhật khi SaveManager.profile_changed và mỗi 0,5 giây lúc đang hiện (chỉ gán text khi số đổi → rẻ).
## Nút "+" mở Tiền Trang (Lượng, KNB) / Kỳ Trân Các (Xu).

const TEX_GOLD := preload("res://assets/ui/bo_icon_nhan_vat/tai_nguyen/dong_tien_vang_va_nut_cong.png")
const TEX_XU := preload("res://assets/ui/bo_icon_nhan_vat/tai_nguyen/xu_vang_va_nut_cong.png")
const TEX_JADE := preload("res://assets/ui/bo_icon_nhan_vat/tai_nguyen/ngoc_xanh_va_nut_cong.png")
const FONT := preload("res://assets/fonts/BeVietnamPro-Regular.ttf")
const PILL_SIZE := Vector2(140, 40)

## Trả về PlayerProfile hiện tại (cửa sổ có thể đổi profile khi nhận bản mới từ server).
var _get_profile: Callable
## Gọi sau khi nạp/mua xong ở Tiền Trang / Kỳ Trân Các (để cửa sổ chủ vẽ lại túi).
var on_changed: Callable

var _gold_lbl: Label
var _xu_lbl: Label
var _jade_lbl: Label
var _xu_pill: Control
var _jade_pill: Control
var _last := [-1, -1, -1]

var _k := 1.0

## scale < 1 cho khung hẹp (Giao Dịch / Bày Bán): 0.72 → 3 ô ≈ 320px.
func _init(get_profile: Callable = Callable(), changed: Callable = Callable(), scale_k := 1.0, with_plus := true) -> void:
	_k = scale_k
	_get_profile = get_profile
	on_changed = changed
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", roundi(8 * _k))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold := _make_pill(TEX_GOLD, with_plus, _open_tien_trang)
	_gold_lbl = gold[1]
	var xu := _make_pill(TEX_XU, with_plus, _open_ky_tran_cac)
	_xu_pill = xu[0]
	_xu_lbl = xu[1]
	var jade := _make_pill(TEX_JADE, with_plus, _open_tien_trang)
	_jade_pill = jade[0]
	_jade_lbl = jade[1]

func _ready() -> void:
	var online := GameModeManager == null or not GameModeManager.is_offline()
	_xu_pill.visible = online
	_jade_pill.visible = online
	if SaveManager != null and SaveManager.has_signal("profile_changed"):
		SaveManager.profile_changed.connect(func(_p: Variant) -> void: refresh())
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(func() -> void:
		if is_visible_in_tree():
			refresh())
	add_child(t)
	visibility_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var p := _profile()
	if p == null:
		return
	var vals := [p.gold, p.xu, maxi(p.jade, 0)]
	if vals == _last:
		return
	_last = vals
	_gold_lbl.text = _fmt(vals[0])
	_xu_lbl.text = _fmt(vals[1])
	_jade_lbl.text = _fmt(vals[2])

func _profile() -> PlayerProfile:
	if _get_profile.is_valid():
		var p: Variant = _get_profile.call()
		if p is PlayerProfile:
			return p
	return GameManager.local_profile if GameManager != null else null

func _make_pill(tex: Texture2D, with_plus: bool, on_plus: Callable) -> Array:
	var frame := TextureRect.new()
	frame.texture = tex
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.custom_minimum_size = (PILL_SIZE * _k).round()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var lbl := Label.new()
	var ls := LabelSettings.new()
	ls.font = FONT
	ls.font_size = maxi(10, roundi(13 * _k))
	ls.font_color = Color.WHITE
	ls.outline_size = 3
	ls.outline_color = Color(0, 0, 0, 0.85)
	lbl.label_settings = ls
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(36, 0) * _k
	lbl.size = Vector2(68, 40) * _k
	lbl.clip_text = true
	lbl.text = "0"
	frame.add_child(lbl)
	if with_plus:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.position = Vector2(104, 0) * _k
		b.size = Vector2(36, 40) * _k
		b.pressed.connect(on_plus)
		frame.add_child(b)
	return [frame, lbl]

func _after_shop() -> void:
	_last = [-1, -1, -1]
	refresh()
	if on_changed.is_valid():
		on_changed.call()

func _open_tien_trang() -> void:
	TienTrangWindow.open(_host(), _after_shop, _profile())

func _open_ky_tran_cac() -> void:
	KyTranCacWindow.open(_host(), _after_shop, _profile())

func _host() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root

static func _fmt(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = "." + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result
