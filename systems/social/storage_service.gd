extends RefCounted
class_name StorageService
## RƯƠNG CHỨA ĐỒ (room_repository gốc): 1 rương chính 6 x 10 ô + tối đa 5 rương mở rộng (room_repository1..5), có KHO TIỀN riêng
## (c2s_storemoney -> KItemList::ExchangeMoney). Tất cả hàm nhận PlayerProfile và trả về "" nếu thành công, hoặc lời báo lỗi (tiếng Việt) —
## sẵn để đổi sang gọi server khi online. Gửi/rút tiền bị chặn khi đang khoá bảo vệ (SecurityLock.A_STORE_MONEY).

const MAX_EXTRA_BOXES := 5
## Giá mở thêm rương: KHÔNG có trong dữ liệu gốc (gốc mở bằng script/đạo cụ) — đây là giá thiết kế của game này, đổi tại đây.
const EXPAND_COST_BASE := 500000

static func extra_box_cost(p: PlayerProfile) -> int:
	return EXPAND_COST_BASE * (p.storage_extra + 1)

static func box_count(p: PlayerProfile) -> int:
	return 1 + p.storage_extra

## Mở thêm 1 rương mở rộng (trả tiền bằng tiền hành trang).
static func buy_extra_box(p: PlayerProfile) -> String:
	var locked := SecurityLock.check(p, SecurityLock.A_STORAGE)
	if locked != "":
		return locked
	if p.storage_extra >= MAX_EXTRA_BOXES:
		return "Đã mở tối đa %d rương mở rộng." % MAX_EXTRA_BOXES
	var cost := extra_box_cost(p)
	if p.gold < cost:
		return "Không đủ %d lượng để mở thêm rương." % cost
	p.gold -= cost
	p.storage_extra += 1
	p.storage.bag_count = 1 + p.storage_extra
	return ""

## Cất món từ HÀNH TRANG vào rương (vào chỗ trống đầu tiên của rương đang mở).
static func store_item(p: PlayerProfile, item: ItemInstance, bag: int = -1) -> String:
	var locked := SecurityLock.check(p, SecurityLock.A_STORAGE)
	if locked != "":
		return locked
	if not p.inventory.has(item):
		return "Món đồ không có trong hành trang."
	var spot: Vector3i
	if bag >= 0:
		var s2 := p.storage.find_free_spot(item.get_size(), bag)
		spot = Vector3i(s2.x, s2.y, bag if s2.x >= 0 else -1)
	else:
		spot = p.storage.find_free_spot_any(item.get_size())
	if spot.z < 0:
		return "Rương đã đầy, không còn chỗ cho món này."
	p.inventory.erase(item)
	item.room_x = -1
	return "" if p.storage.place_item(item, spot.x, spot.y, spot.z) else _restore(p, item)

## Lấy món từ rương ra HÀNH TRANG.
static func take_item(p: PlayerProfile, item: ItemInstance) -> String:
	var locked := SecurityLock.check(p, SecurityLock.A_STORAGE)
	if locked != "":
		return locked
	if not p.storage.owns(item):
		return "Món đồ không có trong rương."
	if p.find_free_spot_any(item.get_size()).z < 0:
		return "Hành trang đã đầy."
	p.storage.remove_item(item)
	return "" if p.add_item(item) else _restore_to_storage(p, item)

static func _restore(p: PlayerProfile, item: ItemInstance) -> String:
	p.add_item(item)
	return "Không đặt được món vào rương."

static func _restore_to_storage(p: PlayerProfile, item: ItemInstance) -> String:
	p.storage.add_item(item)
	return "Không lấy được món ra hành trang."

## Gửi tiền từ hành trang vào kho tiền rương.
static func deposit_gold(p: PlayerProfile, amount: int) -> String:
	var blocked := SecurityLock.check(p, SecurityLock.A_STORE_MONEY)
	if blocked != "":
		return blocked
	if amount <= 0:
		return "Số tiền không hợp lệ."
	if p.gold < amount:
		return "Không đủ tiền trong hành trang."
	p.gold -= amount
	p.storage_gold += amount
	return ""

## Rút tiền từ kho tiền rương về hành trang.
static func withdraw_gold(p: PlayerProfile, amount: int) -> String:
	var blocked := SecurityLock.check(p, SecurityLock.A_STORE_MONEY)
	if blocked != "":
		return blocked
	if amount <= 0:
		return "Số tiền không hợp lệ."
	if p.storage_gold < amount:
		return "Không đủ tiền trong rương."
	p.storage_gold -= amount
	p.gold += amount
	return ""

## Kéo thả giữa HÀNH TRANG và RƯƠNG tại đúng ô (x, y, túi/rương) — ItemRoomView.transfer_handler. true nếu chuyển được.
static func transfer(p: PlayerProfile, item: ItemInstance, from: Object, to: Object, x: int, y: int, bag: int) -> bool:
	if SecurityLock.check(p, SecurityLock.A_STORAGE) != "":
		return false
	if from == p and to == p.storage:
		if not p.inventory.has(item) or not p.storage.can_place(item, x, y, bag):
			return false
		p.inventory.erase(item)
		return p.storage.place_item(item, x, y, bag)
	if from == p.storage and to == p:
		if not p.storage.owns(item) or not p.can_place(item, x, y, bag, p.get_room_height(bag)):
			return false
		p.storage.remove_item(item)
		item.room_x = x
		item.room_y = y
		item.room_bag = bag
		p.inventory.append(item)
		return true
	return false
