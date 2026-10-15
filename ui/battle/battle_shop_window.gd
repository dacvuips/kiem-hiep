extends SocialWindow
class_name BattleShopWindow
## Quân nhu quan trong hậu doanh chiến trường Tống Kim: mua thuốc hồi sinh lực (BattleServer.SHOP_ITEMS, giá gốc). Server trừ tiền +
## thêm thuốc vào túi (gói C_BATTLE OP_BUY) rồi gửi bản nhân vật mới — cửa sổ chỉ vẽ lại số tiền.

var _gold_label: Label

static func open(host: Node) -> BattleShopWindow:
	var win := BattleShopWindow.new()
	return SocialWindow.present(host, win, &"battle_shop") as BattleShopWindow

func _init() -> void:
	super._init("Quân Nhu Quan", "Thuốc cho tráng sĩ trước khi ra trận", 460.0)
	_gold_label = SocialUi.label("", SocialUi.GOLD, 14)
	body.add_child(_gold_label)
	for mid in BattleServer.SHOP_ITEMS:
		var rec := ItemDatabase.get_misc(mid)
		if rec.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(SocialUi.label(str(rec["name"]), SocialUi.TEXT, 14))
		info.add_child(SocialUi.label("%s · %s lượng" % [_effect_text(rec), InventoryPopup.format_money(int(rec["price"]))], SocialUi.MUTED, 12))
		row.add_child(info)
		for n in [1, 5]:
			var b := SocialUi.small_button("Mua %d" % n)
			b.pressed.connect(func() -> void: NetClient.send_battle(BattleServer.OP_BUY, {"mid": mid, "count": n}))
			row.add_child(b)
		body.add_child(row)
	var close := SocialUi.stone_button("Đóng")
	close.pressed.connect(func() -> void: close_requested.emit())
	body.add_child(close)

## "Hồi 100 sinh lực trong 5,6 giây" — theo magic_lifepotion_v [giá trị mỗi nhịp, số frame] (xem PotionEffect).
static func _effect_text(rec: Dictionary) -> String:
	for e in rec.get("effects", []):
		if str(e[0]) == "lifepotion_v":
			var ticks := int(e[2]) / PotionEffect.UPDATE_FRAMES
			return "Hồi %d sinh lực trong %.1f giây" % [int(e[1]) * ticks, float(e[2]) / PotionEffect.GAME_FPS]
	return str(rec.get("intro", ""))

func _process(_d: float) -> void:
	var p := GameManager.local_profile
	_gold_label.text = "Ngân lượng: %s" % (InventoryPopup.format_money(p.gold) if p else "?")
