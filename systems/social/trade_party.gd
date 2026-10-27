extends RefCounted
class_name TradeParty
## Một BÊN của giao dịch/bày bán: bọc PlayerProfile (người chơi thật) hoặc MockPlayer (người chơi giả) để TradeSession/StallService
## không cần biết đó là ai — online chỉ việc thêm 1 loại bọc nữa (người chơi từ xa). Mọi thao tác trả về bool, không lỗi.

var profile: PlayerProfile = null
var mock: MockPlayer = null

static func of_profile(p: PlayerProfile) -> TradeParty:
	var t := TradeParty.new()
	t.profile = p
	return t

static func of_mock(m: MockPlayer) -> TradeParty:
	var t := TradeParty.new()
	t.mock = m
	return t

func is_local() -> bool:
	return profile != null

func party_name() -> String:
	return profile.display_name if profile else mock.name

func gold() -> int:
	return profile.gold if profile else mock.gold

func add_gold(amount: int) -> void:
	if profile:
		if amount > 0:
			var space_in_pocket := maxi(0, PlayerProfile.MAX_GOLD - profile.gold)
			if amount <= space_in_pocket:
				profile.gold += amount
			else:
				profile.gold = PlayerProfile.MAX_GOLD
				var overflow := amount - space_in_pocket
				profile.storage_gold = clampi(profile.storage_gold + overflow, 0, PlayerProfile.MAX_STORAGE_GOLD)
		else:
			profile.gold = maxi(0, profile.gold + amount)
	else:
		mock.gold += amount

## Các món đang nằm trong túi đồ (hành trang) của bên này.
func items() -> Array[ItemInstance]:
	return profile.inventory if profile else mock.bag.inventory

func owns(item: ItemInstance) -> bool:
	return items().has(item)

## Gỡ món khỏi túi (để đưa vào phòng giao dịch/quầy). Không đổi toạ độ.
func detach(item: ItemInstance) -> bool:
	if profile:
		var idx := profile.inventory.find(item)
		if idx < 0:
			return false
		profile.inventory.remove_at(idx)
		return true
	return mock.bag.remove_item(item)

## Nhận 1 món vào túi (vào chỗ trống đầu tiên) — false nếu hết chỗ.
func receive(item: ItemInstance) -> bool:
	return profile.add_item(item) if profile else mock.bag.add_item(item)

## Bên này có nhận đủ `list` món vào túi không (thử xếp rồi trả lại — không đổi trạng thái).
func can_receive(list: Array) -> bool:
	var placed: Array[ItemInstance] = []
	var ok := true
	for it in list:
		if receive(it):
			placed.append(it)
		else:
			ok = false
			break
	for it in placed:
		detach(it)
	return ok
