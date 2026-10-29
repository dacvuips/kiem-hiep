extends RefCounted
class_name PkStakeSession
## QUẢN LÝ ĐẶT CƯỢC THÁCH ĐẤU (Vật phẩm, Tiền Vạn/Lượng, Xu, KNB).
## Dành cho chế độ Thách Đấu (PkRules.Mode.THACH_DAU):
##   - Trưởng nhóm 2 phe (Phe Xanh - Team A, Phe Đỏ - Team B) có thể đặt vật phẩm, tiền, xu, KNB vào khung cược.
##   - Mỗi bên xác nhận KHOÁ cược. Khi đã khoá thì không sửa được nữa trừ khi mở khoá lại.
##   - Khi vào trận, tiền/xu/KNB và vật phẩm được tạm giữ an toàn.
##   - Khi kết thúc trận, toàn bộ tiền, xu, KNB và vật phẩm cược của CẢ 2 BÊN sẽ được trao cho trưởng nhóm bên thắng!
##   - Bên thua sẽ mất toàn bộ tài sản đã cược. Nếu hoà hoặc huỷ trận: hoàn trả lại cho cả 2 bên.

signal changed

const ROOM_WIDTH := 6
const ROOM_HEIGHT := 4

class StakeSide:
	var team_code: String = "a" ## "a" hoặc "b"
	var leader_name: String = ""
	var room := ItemContainer.new(ROOM_WIDTH, ROOM_HEIGHT, 1)
	var gold: int = 0
	var xu: int = 0
	var jade: int = 0
	var locked: bool = false
	var is_bot: bool = false

	func has_any() -> bool:
		return gold > 0 or xu > 0 or jade > 0 or not room.inventory.is_empty()

	func summary_text() -> String:
		if not has_any():
			return "Chưa cược"
		var parts: Array[String] = []
		if gold > 0:
			parts.append("%s lượng" % InventoryPopup.format_money(gold))
		if xu > 0:
			parts.append("%d Xu" % xu)
		if jade > 0:
			parts.append("%d KNB" % jade)
		if not room.inventory.is_empty():
			parts.append("%d vật phẩm" % room.inventory.size())
		var txt := " · ".join(parts)
		if locked:
			txt += " [ĐÃ KHOÁ]"
		return txt

	func to_dict() -> Dictionary:
		var items_data: Array = []
		for it in room.inventory:
			if it != null and it.has_method("to_dict"):
				items_data.append(it.to_dict())
		return {
			"team_code": team_code,
			"leader_name": leader_name,
			"gold": gold,
			"xu": xu,
			"jade": jade,
			"locked": locked,
			"is_bot": is_bot,
			"items": items_data
		}

var side_a := StakeSide.new()
var side_b := StakeSide.new()
var escrow_deducted: bool = false ## Đã trừ tiền vào ký quỹ khi bắt đầu trận chưa

func _init() -> void:
	side_a.team_code = "a"
	side_b.team_code = "b"

func get_side(team_code: String) -> StakeSide:
	return side_a if team_code == "a" else side_b

func other_side(team_code: String) -> StakeSide:
	return side_b if team_code == "a" else side_a

func is_both_locked() -> bool:
	return side_a.locked and side_b.locked

func has_any_stake() -> bool:
	return side_a.has_any() or side_b.has_any()

## Đặt 1 món đồ từ hành trang vào khung cược
func offer_item(team_code: String, item: ItemInstance, profile: PlayerProfile) -> String:
	var side := get_side(team_code)
	if side.locked:
		return "Bạn đã khoá cược, không thể sửa đổi."
	if profile == null:
		return "Không tìm thấy hồ sơ nhân vật."
	if not profile.inventory.has(item):
		return "Vật phẩm không có trong hành trang."
	if SecurityLock.is_item_locked(item) or item.lock_state == ItemInstance.LOCK_CHARACTER:
		return "Vật phẩm đang bị khoá bảo vệ, không thể đem cược."
	var spot := side.room.find_free_spot_any(item.get_size())
	if spot.z < 0:
		return "Khung đặt cược của bên bạn đã đầy ô."
	var idx := profile.inventory.find(item)
	if idx >= 0:
		profile.inventory.remove_at(idx)
	side.room.place_item(item, spot.x, spot.y, spot.z)
	_reset_locks()
	changed.emit()
	return ""

## Lấy lại món đồ từ khung cược về hành trang
func take_back_item(team_code: String, item: ItemInstance, profile: PlayerProfile) -> String:
	var side := get_side(team_code)
	if side.locked:
		return "Bạn đã khoá cược, không thể sửa đổi."
	if profile == null:
		return "Không tìm thấy hồ sơ nhân vật."
	if not side.room.owns(item):
		return "Vật phẩm không có trong khung cược."
	if not profile.add_item(item):
		return "Hành trang của bạn đã đầy chỗ."
	side.room.remove_item(item)
	_reset_locks()
	changed.emit()
	return ""

## Đặt số tiền lượng cược
func set_gold(team_code: String, amount: int, profile: PlayerProfile) -> String:
	var side := get_side(team_code)
	if side.locked:
		return "Bạn đã khoá cược, không thể sửa đổi."
	if amount < 0:
		return "Số tiền không hợp lệ."
	var max_avail := profile.gold if profile else 0
	if amount > max_avail:
		return "Số tiền trong người không đủ (%s lượng)." % InventoryPopup.format_money(max_avail)
	side.gold = amount
	_reset_locks()
	changed.emit()
	return ""

## Đặt số Xu cược
func set_xu(team_code: String, amount: int, profile: PlayerProfile) -> String:
	var side := get_side(team_code)
	if side.locked:
		return "Bạn đã khoá cược, không thể sửa đổi."
	if amount < 0:
		return "Số xu không hợp lệ."
	var max_avail := profile.xu if profile else 0
	if amount > max_avail:
		return "Số xu trong người không đủ (%d xu)." % max_avail
	side.xu = amount
	_reset_locks()
	changed.emit()
	return ""

## Đặt số KNB cược
func set_jade(team_code: String, amount: int, profile: PlayerProfile) -> String:
	var side := get_side(team_code)
	if side.locked:
		return "Bạn đã khoá cược, không thể sửa đổi."
	if amount < 0:
		return "Số KNB không hợp lệ."
	var max_avail := profile.jade if profile else 0
	if amount > max_avail:
		return "Số KNB trong người không đủ (%d KNB)." % max_avail
	side.jade = amount
	_reset_locks()
	changed.emit()
	return ""

## Bấm xác nhận khoá cược hoặc mở khoá
func toggle_lock(team_code: String) -> String:
	var side := get_side(team_code)
	side.locked = not side.locked
	# Nếu phe đối diện là Bot và bên người chơi khoá, Bot tự động hưởng ứng khoá cược
	var other := other_side(team_code)
	if side.locked and other.is_bot:
		other.locked = true
	changed.emit()
	return "Đã khoá cược." if side.locked else "Đã mở khoá cược."

func _reset_locks() -> void:
	side_a.locked = false
	side_b.locked = false

## Khấu trừ tiền, xu, knb đưa vào ký quỹ bảo chứng khi BẮT ĐẦU TRẬN ĐẤU
func deduct_escrow(local_profile: PlayerProfile, local_team_code: String) -> void:
	if escrow_deducted:
		return
	var my_side := get_side(local_team_code)
	if local_profile:
		if my_side.gold > 0:
			local_profile.gold = maxi(0, local_profile.gold - my_side.gold)
		if my_side.xu > 0:
			local_profile.xu = maxi(0, local_profile.xu - my_side.xu)
		if my_side.jade > 0:
			local_profile.jade = maxi(0, local_profile.jade - my_side.jade)
	escrow_deducted = true

## Hoàn trả toàn bộ tài sản cược về cho người chơi (khi huỷ phòng, rời phòng, từ chối đối thủ, hoặc trận hoà)
func refund_all(local_profile: PlayerProfile, local_team_code: String) -> void:
	var my_side := get_side(local_team_code)
	if local_profile:
		# Hoàn trả vật phẩm trong khung cược
		for it in my_side.room.inventory.duplicate():
			my_side.room.remove_item(it)
			if not local_profile.add_item(it):
				MarketBook.return_item_to_player(local_profile, it)
		# Nếu đã trừ tiền ký quỹ thì hoàn trả lại tiền, xu, knb
		if escrow_deducted:
			if my_side.gold > 0:
				local_profile.gold = mini(PlayerProfile.MAX_GOLD, local_profile.gold + my_side.gold)
			if my_side.xu > 0:
				local_profile.xu += my_side.xu
			if my_side.jade > 0:
				local_profile.jade = mini(PlayerProfile.MAX_JADE, local_profile.jade + my_side.jade)
	escrow_deducted = false
	my_side.gold = 0
	my_side.xu = 0
	my_side.jade = 0
	my_side.locked = false
	changed.emit()

## Trao toàn bộ tiền, xu, KNB và vật phẩm cược cho trưởng nhóm bên THẮNG
func payout_to_winner(winner_team_code: String, local_profile: PlayerProfile, local_team_code: String) -> Dictionary:
	var is_local_winner := (winner_team_code == local_team_code)
	var win_side := get_side(winner_team_code)
	var lose_side := other_side(winner_team_code)

	var total_gold: int = side_a.gold + side_b.gold
	var total_xu: int = side_a.xu + side_b.xu
	var total_jade: int = side_a.jade + side_b.jade
	var all_items: Array[ItemInstance] = []
	all_items.append_array(side_a.room.inventory.duplicate())
	all_items.append_array(side_b.room.inventory.duplicate())

	var result := {
		"is_winner": is_local_winner,
		"winner_team": winner_team_code,
		"total_gold": total_gold,
		"total_xu": total_xu,
		"total_jade": total_jade,
		"items_count": all_items.size(),
		"items": all_items
	}

	if is_local_winner and local_profile:
		# Người chơi là trưởng nhóm bên thắng: Nhận toàn bộ giải thưởng!
		if total_gold > 0:
			local_profile.gold = mini(PlayerProfile.MAX_GOLD, local_profile.gold + total_gold)
		if total_xu > 0:
			local_profile.xu += total_xu
		if total_jade > 0:
			local_profile.jade = mini(PlayerProfile.MAX_JADE, local_profile.jade + total_jade)
		for it in all_items:
			if not local_profile.add_item(it):
				MarketBook.return_item_to_player(local_profile, it)
	else:
		# Người chơi bên thua: Đã bị mất tiền cược và đồ cược trong khung
		pass

	# Xoá trắng cược sau khi phát thưởng
	side_a.room.inventory.clear()
	side_b.room.inventory.clear()
	side_a.gold = 0
	side_b.gold = 0
	side_a.xu = 0
	side_b.xu = 0
	side_a.jade = 0
	side_b.jade = 0
	escrow_deducted = false
	changed.emit()
	return result
