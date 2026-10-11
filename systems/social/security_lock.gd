extends RefCounted
class_name SecurityLock
## KHOÁ BẢO VỆ (mật khẩu) + KHOÁ MÓN ĐỒ — đúng KPlayer::SetLockState/CheckSavePw/ResetPw và KItemList::Lock của VLTK gốc.
##
## Khoá bảo vệ: mật khẩu 1..16 ký tự (MAX_PASSWORD_LENGTH). Chỉ BẬT khoá được khi đã đặt mật khẩu; đang khoá thì server gốc chặn
## (KProtocolProcess::ProcessData) các lệnh: mở bày bán/giao dịch, bắt đầu giao dịch, mua/bán với NPC, gửi/rút tiền rương, mua đồ
## bày bán, vứt đồ. Mở khoá = nhập đúng mật khẩu. Ở game này mật khẩu chỉ lưu dạng băm SHA-256 (không lưu chữ thường).
##
## Khoá món đồ (KLockItem): khoá được tức thì; MỞ khoá phải CHỜ 259200 giây (3 ngày) mới có hiệu lực; món khoá vĩnh viễn/gắn nhân vật
## không đổi được. Món đang khoá/đang chờ mở không được bán, giao dịch, đặt giá bày bán.

const MAX_PASSWORD_LENGTH := 16
const MIN_PASSWORD_LENGTH := 1
const ITEM_UNLOCK_SECONDS := 259200

## Lệnh bị chặn khi đang khoá bảo vệ.
const A_OPEN_STALL := &"open_stall"
const A_TRADE_START := &"trade_start"
const A_STALL_BUY := &"stall_buy"
const A_NPC_BUY := &"npc_buy"
const A_NPC_SELL := &"npc_sell"
const A_STORE_MONEY := &"store_money"
const A_DROP_ITEM := &"drop_item"
## Mở rộng của game này: khoá bảo vệ cũng KHOÁ RƯƠNG CHỨA ĐỒ — đang khoá thì không mở được rương, không cất/lấy đồ, không mở thêm rương.
const A_STORAGE := &"storage"
const BLOCKED_WHEN_LOCKED := [A_OPEN_STALL, A_TRADE_START, A_STALL_BUY, A_NPC_BUY, A_NPC_SELL, A_STORE_MONEY, A_DROP_ITEM, A_STORAGE]

const MSG_LOCKED := "Chức năng này đang bị khoá bảo vệ, hãy mở khoá bằng mật khẩu trước!"
const MSG_STORAGE_LOCKED := "Rương đang bị khoá bảo vệ, hãy nhập mật khẩu để mở khoá rương!"

static func _hash(password: String) -> String:
	return ("vltk-lock|" + password).sha256_text()

## Mật mã nhập vào có đúng không (không đổi trạng thái khoá).
static func unlock_check(p: PlayerProfile, password: String) -> bool:
	return has_password(p) and _hash(password) == p.security_hash

static func has_password(p: PlayerProfile) -> bool:
	return p.security_hash != ""

static func is_locked(p: PlayerProfile) -> bool:
	return p.security_locked and has_password(p)

## Lệnh `action` có được làm lúc này không. Trả về "" nếu được, hoặc lời báo lỗi.
static func check(p: PlayerProfile, action: StringName) -> String:
	if is_locked(p) and action in BLOCKED_WHEN_LOCKED:
		return MSG_STORAGE_LOCKED if action == A_STORAGE else MSG_LOCKED
	return ""

static func validate_password(password: String) -> String:
	if password.length() < MIN_PASSWORD_LENGTH or password.length() > MAX_PASSWORD_LENGTH:
		return "Mật khẩu phải dài từ %d đến %d ký tự." % [MIN_PASSWORD_LENGTH, MAX_PASSWORD_LENGTH]
	return ""

## Đặt mật khẩu mới (nếu đã có mật khẩu phải nhập đúng mật khẩu cũ). Trả về "" nếu thành công, hoặc lời báo lỗi.
static func set_password(p: PlayerProfile, new_password: String, old_password := "") -> String:
	if has_password(p) and _hash(old_password) != p.security_hash:
		return "Mật khẩu cũ không chính xác!"
	var err := validate_password(new_password)
	if err != "":
		return err
	p.security_hash = _hash(new_password)
	p.security_locked = true      ## gốc: đặt xong mật khẩu là khoá luôn (SetLockState(bLock = có mật khẩu))
	return ""

## Xoá mật khẩu (phải nhập đúng) — hết khoá bảo vệ.
static func clear_password(p: PlayerProfile, password: String) -> String:
	if not has_password(p):
		return "Bạn chưa đặt mật khẩu bảo vệ."
	if _hash(password) != p.security_hash:
		return "Mật mã kiểm chứng không chính xác!"
	p.security_hash = ""
	p.security_locked = false
	return ""

## Bật khoá (không cần mật khẩu, nhưng phải đã đặt mật khẩu — đúng SetLockState gốc).
static func lock(p: PlayerProfile) -> String:
	if not has_password(p):
		return "Bạn chưa đặt mật khẩu bảo vệ nên không thể khoá."
	p.security_locked = true
	return ""

## Mở khoá bằng mật khẩu — "" nếu đúng.
static func unlock(p: PlayerProfile, password: String) -> String:
	if not has_password(p):
		return ""
	if _hash(password) != p.security_hash:
		return "Giải mã khoá bảo vệ thất bại: mật mã kiểm chứng không chính xác!"
	p.security_locked = false
	return ""

# ------------------------------------------------------------------ khoá món đồ
static func now() -> int:
	return int(Time.get_unix_time_from_system())

## Cập nhật trạng thái theo thời gian: đang chờ mở khoá mà hết hạn thì thành tự do.
static func refresh_item(item: ItemInstance, at: int = -1) -> void:
	if item.lock_state == ItemInstance.LOCK_UNLOCKING and (at if at >= 0 else now()) >= item.unlock_at:
		item.lock_state = ItemInstance.LOCK_NORMAL
		item.unlock_at = 0

## Món có đang bị khoá (gồm cả đang chờ mở khoá, khoá vĩnh viễn, gắn nhân vật) không.
static func is_item_locked(item: ItemInstance, at: int = -1) -> bool:
	refresh_item(item, at)
	return item.lock_state != ItemInstance.LOCK_NORMAL

## Khoá món đồ (tức thì). false nếu đã khoá/không đổi được.
static func lock_item(item: ItemInstance) -> bool:
	refresh_item(item)
	if item.lock_state == ItemInstance.LOCK_FOREVER or item.lock_state == ItemInstance.LOCK_CHARACTER:
		return false
	if item.lock_state == ItemInstance.LOCK_LOCKED:
		return false
	item.lock_state = ItemInstance.LOCK_LOCKED
	item.unlock_at = 0
	item.trade_price = 0           ## món khoá không được đặt giá bán
	return true

## Yêu cầu mở khoá: bắt đầu đếm 259200 giây. false nếu không khoá / đã đang đếm / không đổi được.
static func request_unlock(item: ItemInstance, at: int = -1) -> bool:
	refresh_item(item, at)
	if item.lock_state != ItemInstance.LOCK_LOCKED:
		return false
	item.lock_state = ItemInstance.LOCK_UNLOCKING
	item.unlock_at = (at if at >= 0 else now()) + ITEM_UNLOCK_SECONDS
	return true

static func seconds_to_unlock(item: ItemInstance, at: int = -1) -> int:
	refresh_item(item, at)
	if item.lock_state != ItemInstance.LOCK_UNLOCKING:
		return 0
	return maxi(0, item.unlock_at - (at if at >= 0 else now()))

static func describe_item_lock(item: ItemInstance) -> String:
	refresh_item(item)
	match item.lock_state:
		ItemInstance.LOCK_LOCKED:
			return "Đã khoá"
		ItemInstance.LOCK_UNLOCKING:
			var s := seconds_to_unlock(item)
			return "Đang chờ mở khoá (còn %dh %02dp)" % [s / 3600, (s % 3600) / 60]
		ItemInstance.LOCK_FOREVER:
			return "Khoá vĩnh viễn"
		ItemInstance.LOCK_CHARACTER:
			return "Gắn với nhân vật"
	return ""
