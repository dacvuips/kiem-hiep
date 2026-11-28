extends RefCounted
class_name ItemDurability
## ĐỘ BỀN TRANG BỊ — làm đúng VLTK gốc, dùng chung offline (Player) và online (game server tính trên hồ sơ của server):
##   KItem::Abrade / KItemList::Abrade (tụt), KNpc::DoSkill (ra chiêu), KNpc::DeathPunish (chết), đổi vùng bản đồ (di chuyển),
##   KItem::GetRepairPrice + KPlayer::RepairItem (sửa ở thợ rèn), thoren.lua RepairItem/RepairItem2 (sửa đồ đã hỏng hẳn),
##   settings/item/AbradeRate.ini, settings/npc/player/PKPunish.txt (cột "Tỉ lệ hư tổn").
##
## Giá trị `ItemInstance.durability`: -1 = không thể phá hủy (dòng indestructible_b), 0 = ĐÃ HỎNG, > 0 = còn lại.
## Món không có thuộc tính gốc durability_v (nhẫn, dây chuyền, ngọc bội, ngựa, mặt nạ...) không bao giờ tụt.

enum Kind { ATTACK, DEFEND, MOVE }

## AbradeRate.ini: mỗi lần (ra chiêu / chết / đổi vùng) món ở ô đó có 1/N cơ hội tụt 1 điểm. Ô không ghi = 0 = không tụt.
const RATE := {
	Kind.ATTACK: {Equipment.Part.WEAPON: 768},
	Kind.DEFEND: {Equipment.Part.HEAD: 960, Equipment.Part.BODY: 960, Equipment.Part.BELT: 960, Equipment.Part.CUFF: 960},
	Kind.MOVE: {Equipment.Part.FOOT: 7680, Equipment.Part.HORSE: 15360},
}

## PKPunish.txt cột 7 (theo trị PK 0..10): chết thì đồ phòng thủ mất thêm X% độ bền TỐI ĐA (chỉ các ô có tỉ lệ DEFEND ở trên).
const PK_ABRADE_P := [0, 0, 0, 0, 30, 40, 50, 60, 70, 80, 90]

## [Repair] của AbradeRate.ini.
const PRICE_SCALE := 50       ## ItemPriceScale (đồ thường / xanh)
const MAGIC_SCALE := 16       ## MagicPriceScale
const GOLD_SCALE := 30        ## GoldPriceScale (hoàng kim: theo từng điểm độ bền)
const WARNING_BASELINE := 10  ## còn <= tối đa / 10 thì nhắc "sắp hỏng"
const MAX_GENERATOR_LEVEL := 10

## thoren.lua: "Sửa trang bị hư tổn" — chỉ đồ xanh (không hoàng kim), 50 vạn lượng hoặc 10 xu.
const BROKEN_REPAIR_GOLD := 500_000
const BROKEN_REPAIR_XU := 10

## Vùng bản đồ (Region gốc 16 x 32 ô = 512 x 512 px trong toạ độ game, MapGrid.REGION): đi qua ranh giới vùng = 1 lần tụt MOVE.
const REGION_SIZE := 512.0

const MSG_DAMAGED := "Trang bị %s đã bị hỏng rồi"
const MSG_NEARLY := "Trang bị %s sắp hỏng hãy đến thợ rèn để sửa chữa lại"
const MSG_CANT_REPAIR := "Trang bị đã hư hỏng hoàn toàn không thể sửa chữa bằng phương pháp bình thường"
const MSG_REPAIRED := "Tiêu tốn %d lượng bạc để sửa chữa %s"

static func region_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / REGION_SIZE), floori(pos.y / REGION_SIZE))

## Món có độ bền (không phải món không thể phá hủy / món không có độ bền).
static func has_durability(item: ItemInstance) -> bool:
	return item != null and not item.is_misc() and item.durability >= 0 and item.get_max_durability() > 0 \
		and not is_indestructible(item)

static func is_indestructible(item: ItemInstance) -> bool:
	if item == null:
		return false
	if item.durability < 0:
		return true
	for line in item.magic:
		if str(line.get("attrib", "")) == "indestructible_b":
			return true
	return false

## Đã hỏng hẳn (độ bền 0) — gốc: không mặc được (CanEquip), không sửa thường được, mất hết chỉ số.
static func is_broken(item: ItemInstance) -> bool:
	return has_durability(item) and item.durability == 0

## KItem::Abrade — trả về độ bền mới, -1 nếu món không tụt (không độ bền / ô không có tỉ lệ).
static func abrade_item(item: ItemInstance, abrade_p: int, rate: int, rng: RandomNumberGenerator = null) -> int:
	if not has_durability(item) or rate <= 0:
		return -1
	var dur := item.durability
	if abrade_p > 0:
		dur -= item.get_max_durability() * abrade_p / 100
	if dur > 0:
		var roll := rng.randi_range(0, rate - 1) if rng != null else randi() % rate
		if roll == 0:
			dur -= 1
	item.durability = maxi(dur, 0)
	return item.durability

## KItemList::Abrade — tụt độ bền mọi món đang mặc theo `kind`. Món vừa hỏng được tháo về hành trang (InsertEquipment gốc;
## hết chỗ thì vẫn nằm trên người nhưng mất hết tác dụng — Equipment bỏ qua đồ hỏng).
## Trả về [{item, part, old, new, broke}] cho các món có đổi (để báo / gửi máy người chơi).
static func abrade(profile: PlayerProfile, kind: int, rng: RandomNumberGenerator = null) -> Array:
	var out := []
	if profile == null:
		return out
	var rates: Dictionary = RATE.get(kind, {})
	var pk_p := 0
	if kind == Kind.DEFEND:
		pk_p = PK_ABRADE_P[clampi(profile.pk_value, 0, PK_ABRADE_P.size() - 1)]
	var broke_any := false
	for part in profile.equipment.keys():
		var item: ItemInstance = profile.equipment[part]
		if item == null or item.durability == 0:
			continue
		var old := item.durability
		var dur := abrade_item(item, pk_p, int(rates.get(part, 0)), rng)
		if dur < 0 or dur == old:
			continue
		var broke := dur == 0
		out.append({"item": item, "part": part, "old": old, "new": dur, "broke": broke})
		if broke:
			broke_any = true
			_take_off_broken(profile, part)
	if broke_any:
		profile.equipment_changed.emit()
	return out

static func _take_off_broken(profile: PlayerProfile, part: int) -> void:
	var item: ItemInstance = profile.equipment.get(part)
	if item == null:
		return
	var spot := profile.find_free_spot_any(item.get_size())
	if spot.z < 0:
		return
	item.room_x = spot.x
	item.room_y = spot.y
	item.room_bag = spot.z
	profile.inventory.append(item)
	profile.equipment.erase(part)
	if part == Equipment.Part.HORSE:
		profile.riding = false

## Câu báo cho người chơi sau mỗi lần đổi độ bền (KProtocolProcess::ItemChangeDurability gốc) — "" = không báo.
static func change_message(change: Dictionary) -> String:
	var item: ItemInstance = change["item"]
	if int(change["new"]) == 0:
		return MSG_DAMAGED % item.get_display_name()
	if int(change["new"]) <= item.get_max_durability() / WARNING_BASELINE:
		return MSG_NEARLY % item.get_display_name()
	return ""

## Tổng cấp magic của món (GetTotalMagicLevel gốc). Game không giữ cấp sinh từng dòng -> mỗi dòng magic tính bằng cấp món
## (đồ rơi/đồ sinh thường dùng cấp magic = cấp đồ); dòng khảm của đồ tím có cấp riêng (mlv).
static func total_magic_level(item: ItemInstance) -> int:
	var total := 0
	for line in item.magic:
		total += clampi(int(line.get("mlv", item.get_level())), 0, MAX_GENERATOR_LEVEL)
	return total

## KItem::GetRepairPrice — 0 = không cần / không sửa được bằng cách thường.
static func repair_price(item: ItemInstance) -> int:
	if not has_durability(item):
		return 0
	var max_dur := item.get_max_durability()
	var lost := max_dur - item.durability
	if lost <= 0:
		return 0
	var price := item.get_base_price()
	if price <= 0:
		return 0
	var cost: int
	if item.is_gold():
		cost = price * GOLD_SCALE / 100 * lost
	else:
		cost = price * PRICE_SCALE / 100 * lost / max_dur * (MAGIC_SCALE + total_magic_level(item)) / MAGIC_SCALE
	return maxi(cost, 1)

## KItem::CanBeRepaired + chưa hỏng hẳn.
static func can_repair(item: ItemInstance) -> bool:
	return has_durability(item) and item.durability > 0 and item.durability < item.get_max_durability()

## KPlayer::RepairItem — sửa ở thợ rèn bằng lượng bạc. {ok, message}.
static func repair(profile: PlayerProfile, item: ItemInstance) -> Dictionary:
	if profile == null or item == null or not _owns(profile, item):
		return {"ok": false, "message": "Không tìm thấy trang bị."}
	if is_broken(item):
		return {"ok": false, "message": MSG_CANT_REPAIR}
	if not can_repair(item):
		return {"ok": false, "message": "Trang bị này không cần sửa."}
	var cost := repair_price(item)
	if profile.gold < cost:
		return {"ok": false, "message": "Không đủ %d lượng bạc để sửa %s." % [cost, item.get_display_name()]}
	profile.gold -= cost
	item.durability = item.get_max_durability()
	return {"ok": true, "message": MSG_REPAIRED % [cost, item.get_display_name()], "cost": cost}

## Sửa hết đồ đang mặc + trong hành trang còn sửa được (theo thứ tự, dừng khi hết tiền).
static func repair_all(profile: PlayerProfile) -> Dictionary:
	var total := 0
	var n := 0
	var short := false
	for item in _all_items(profile):
		if not can_repair(item):
			continue
		var r := repair(profile, item)
		if r["ok"]:
			total += int(r["cost"])
			n += 1
		else:
			short = true
	if n == 0:
		return {"ok": false, "message": "Không đủ lượng bạc để sửa trang bị." if short else "Không có trang bị nào cần sửa."}
	var msg := "Đã sửa %d món, tiêu tốn %d lượng bạc." % [n, total]
	if short:
		msg += " Còn món chưa sửa vì không đủ tiền."
	return {"ok": true, "message": msg, "cost": total}

static func repair_all_price(profile: PlayerProfile) -> int:
	var total := 0
	for item in _all_items(profile):
		if can_repair(item):
			total += repair_price(item)
	return total

## thoren.lua RepairItem / RepairItem2 — "Sửa trang bị hỏng nặng": món đã hỏng (độ bền 0), chỉ đồ xanh/trắng (không hoàng kim),
## trả 50 vạn lượng hoặc 10 xu, món trở lại đầy độ bền và giữ nguyên các dòng thuộc tính.
static func repair_broken(profile: PlayerProfile, item: ItemInstance, pay_xu: bool) -> Dictionary:
	if profile == null or item == null or not _owns(profile, item):
		return {"ok": false, "message": "Không tìm thấy trang bị."}
	if not is_broken(item):
		return {"ok": false, "message": "Trang bị này chưa hỏng hẳn, hãy sửa bình thường."}
	if item.is_gold():
		return {"ok": false, "message": "Tính năng chỉ sửa trang bị xanh!"}
	if pay_xu:
		if profile.xu < BROKEN_REPAIR_XU:
			return {"ok": false, "message": "Các hạ không có đủ %d xu" % BROKEN_REPAIR_XU}
		profile.xu -= BROKEN_REPAIR_XU
	else:
		if profile.gold < BROKEN_REPAIR_GOLD:
			return {"ok": false, "message": "Các hạ không có đủ 50 vạn lượng"}
		profile.gold -= BROKEN_REPAIR_GOLD
	item.durability = item.get_max_durability()
	return {"ok": true, "message": "Sửa trang bị thành công"}

static func find_by_uid(profile: PlayerProfile, uid: String) -> ItemInstance:
	if profile == null or uid == "":
		return null
	for item in _all_items(profile):
		if item.uid == uid:
			return item
	return null

static func _owns(profile: PlayerProfile, item: ItemInstance) -> bool:
	return item in profile.inventory or profile.equipment.values().has(item)

static func _all_items(profile: PlayerProfile) -> Array:
	var out := []
	for part in profile.equipment:
		if profile.equipment[part] != null:
			out.append(profile.equipment[part])
	for item in profile.inventory:
		if item != null and not item.is_misc():
			out.append(item)
	return out
