extends SocialWindow
class_name StallBrowseWindow
## XEM QUẦY CỦA NGƯỜI KHÁC và MUA (c2s_playertradeview / c2s_playertradebuy gốc). Luật mua: StallService.buy (không mua khi bị khoá bảo vệ,
## đang chiến đấu, thiếu tiền, hết chỗ, quầy đã đóng hoặc món đã bán).

var _hub: SocialHub
var _profile: PlayerProfile
var _seller: MockPlayer
var _list: VBoxContainer
var _gold: HBoxContainer
var _msg: PanelContainer

static func open(host: Node, hub: SocialHub, seller: MockPlayer) -> StallBrowseWindow:
	return SocialWindow.present(host, StallBrowseWindow.new(hub, seller), &"stall_browse") as StallBrowseWindow

func _init(hub: SocialHub = null, seller: MockPlayer = null) -> void:
	super._init("Quầy của %s" % (seller.name if seller else ""), seller.stall_title if seller else "", 560.0)
	_hub = hub
	_seller = seller
	if _hub == null or _seller == null:
		return
	_profile = _hub.profile
	var info := SocialUi.info_box()
	_gold = SocialUi.kv("Tiền của bạn:", "", SocialUi.LABEL_BLUE, SocialUi.GOLD)
	info[1].add_child(_gold)
	body.add_child(info[0])
	var sec := SocialUi.section("🏷 Hàng đang bán", SocialUi.SECTION_ACCENT, SocialUi.SECTION_BG)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(520, 300)
	scroll.add_child(_list)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec[1].add_child(scroll)
	body.add_child(sec[0])
	_msg = SocialUi.banner("", true)
	_msg.visible = false
	body.add_child(_msg)
	var close := SocialUi.stone_button("Đóng")
	body.add_child(close)
	close.pressed.connect(func() -> void: close_requested.emit())
	_refresh()

func _refresh() -> void:
	SocialUi.set_kv(_gold, "%s lượng" % InventoryPopup.format_money(_profile.gold), SocialUi.GOLD)
	for c in _list.get_children():
		c.queue_free()
	var goods := StallService.browse(_seller)
	if goods.is_empty():
		_list.add_child(SocialUi.label("Quầy đã hết hàng.", SocialUi.MUTED, 14))
	for it in goods:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = it.get_icon(true)
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var name_l := SocialUi.label(it.get_display_name(), it.get_quality_color(), 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		row.add_child(SocialUi.label("%s lượng" % InventoryPopup.format_money(it.trade_price), SocialUi.GOLD, 14))
		var look := SocialUi.small_button("Xem")
		look.pressed.connect(func() -> void:
			ItemDetailPopup.open(get_tree().current_scene, ItemText.build(it, _profile, -1, -1, false), [], it))
		var buy := SocialUi.small_button("Mua")
		buy.pressed.connect(func() -> void: _buy(it))
		row.add_child(look)
		row.add_child(buy)
		_list.add_child(row)

func _buy(it: ItemInstance) -> void:
	var err := StallService.buy(TradeParty.of_profile(_profile), TradeParty.of_mock(_seller), it, false, _seller.stall_open)
	SocialUi.set_banner(_msg, err if err != "" else "Mua %s thành công!" % it.get_display_name(), err == "")
	_msg.visible = true
	if err == "":
		SaveManager.save_profile(_profile)
	_refresh()
