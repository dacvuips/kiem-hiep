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

## Chống vét cạn (brute-force) mật mã khoá bảo vệ: tạm khoá nếu nhập sai quá 5 lần
static var _failed_attempts: int = 0
static var _lockout_until: float = 0.0
const MAX_FAILED_ATTEMPTS: int = 5
const LOCKOUT_DURATION_SEC: float = 600.0  ## Khoá 10 phút

static func is_locked_out() -> bool:
	return (Time.get_ticks_msec() / 1000.0) < _lockout_until

static func remaining_lockout_seconds() -> int:
	return maxi(0, int(_lockout_until - (Time.get_ticks_msec() / 1000.0)))

static func reset_lockout_for_test() -> void:
	_failed_attempts = 0
	_lockout_until = 0.0

static func _record_failure() -> void:
	_failed_attempts += 1
	if _failed_attempts >= MAX_FAILED_ATTEMPTS:
		_lockout_until = (Time.get_ticks_msec() / 1000.0) + LOCKOUT_DURATION_SEC

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

const _SALT_PREFIX_OBF: PackedByteArray = [44, 13, 28, 4, 91, 17, 235, 232, 249, 229]

static func _hash(password: String) -> String:
	return (Obfuscator.deobfuscate(_SALT_PREFIX_OBF) + password).sha256_text()

## Mật mã nhập vào có đúng không (không đổi trạng thái khoá).
static func unlock_check(p: PlayerProfile, password: String) -> bool:
	if is_locked_out():
		return false
	var ok := has_password(p) and _hash(password) == p.security_hash
	if ok:
		_failed_attempts = 0
		_lockout_until = 0.0
	else:
		_record_failure()
	return ok

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
	if has_password(p):
		if is_locked_out():
			var rem := remaining_lockout_seconds()
			return "Đang bị tạm khoá chức năng mật khẩu (%d phút %02d giây)." % [rem / 60, rem % 60]
		if _hash(old_password) != p.security_hash:
			_record_failure()
			return "Mật khẩu cũ không chính xác!"
	_failed_attempts = 0
	_lockout_until = 0.0
	var err := validate_password(new_password)
	if err != "":
		return err
	var old_hash := p.security_hash
	p.security_hash = _hash(new_password)
	p.security_locked = true      ## gốc: đặt xong mật khẩu là khoá luôn (SetLockState(bLock = có mật khẩu))
	_tell_server(SocialServer.SEC_SET, p.security_hash, old_hash if old_hash != "" else "")
	return ""

## Online: trạng thái khoá nằm ở game server — gửi cùng thao tác (mã băm) để server kiểm tra lại; sai thì server gửi bản chuẩn về.
static func _tell_server(op: int, hash1 := "", hash2 := "") -> void:
	if NetClient.is_in_world():
		NetClient.send_security(op, hash1, hash2)

## Xoá mật khẩu (phải nhập đúng) — hết khoá bảo vệ.
static func clear_password(p: PlayerProfile, password: String) -> String:
	if not has_password(p):
		return "Bạn chưa đặt mật khẩu bảo vệ."
	if is_locked_out():
		var rem := remaining_lockout_seconds()
		return "Đang bị tạm khoá chức năng mật khẩu (%d phút %02d giây)." % [rem / 60, rem % 60]
	if _hash(password) != p.security_hash:
		_record_failure()
		return "Mật mã kiểm chứng không chính xác!"
	_failed_attempts = 0
	_lockout_until = 0.0
	p.security_hash = ""
	p.security_locked = false
	_tell_server(SocialServer.SEC_CLEAR, _hash(password))
	return ""

## Bật khoá (không cần mật khẩu, nhưng phải đã đặt mật khẩu — đúng SetLockState gốc).
static func lock(p: PlayerProfile) -> String:
	if not has_password(p):
		return "Bạn chưa đặt mật khẩu bảo vệ nên không thể khoá."
	p.security_locked = true
	_tell_server(SocialServer.SEC_LOCK)
	return ""

## Mở khoá bằng mật khẩu — "" nếu đúng.
static func unlock(p: PlayerProfile, password: String) -> String:
	if not has_password(p):
		return ""
	if is_locked_out():
		var rem := remaining_lockout_seconds()
		return "Bạn đã nhập sai quá %d lần! Vui lòng thử lại sau %d phút %02d giây." % [MAX_FAILED_ATTEMPTS, rem / 60, rem % 60]
	if _hash(password) != p.security_hash:
		_record_failure()
		if is_locked_out():
			return "Nhập sai quá %d lần! Chức năng nhập mật mã đã bị tạm khoá 10 phút." % MAX_FAILED_ATTEMPTS
		return "Giải mã khoá bảo vệ thất bại: mật mã kiểm chứng không chính xác! (Còn %d lần thử)" % (MAX_FAILED_ATTEMPTS - _failed_attempts)
	_failed_attempts = 0
	_lockout_until = 0.0
	p.security_locked = false
	_tell_server(SocialServer.SEC_UNLOCK, _hash(password))
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
