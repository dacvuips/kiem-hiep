extends RefCounted
class_name EscortManager
## Quản lý danh sách các Tiêu Xa đang vận chuyển trên giang hồ (Long Môn Tiêu Cục).
## Hỗ trợ:
##   - Lưu trữ danh sách các chuyến tiêu đang chạy (active_escorts).
##   - Cho phép người chơi khác nhìn thấy và nhảy vào cùng map thực địa để bảo vệ (hoặc cướp tiêu).
##   - Xóa chuyến tiêu khỏi danh sách ngay khi cập bến hoặc bị đánh vỡ.

const ACTIVE_LIST_PATH := "user://escort_active_list.json"
const MAX_ACTIVE_CARTS := 20
const MAX_TEAM_MEMBERS := 5

static var _cached_carts: Array[Dictionary] = []
static var _loaded := false

## Đọc danh sách các tiêu xa đang hoạt động
static func get_active_carts() -> Array[Dictionary]:
	_load_if_needed()
	_prune_expired()
	if _cached_carts.is_empty():
		_seed_giang_ho_carts()
	return _cached_carts

## Tạo chuyến tiêu xa mới đưa lên danh sách công khai
static func create_cart(owner_profile: PlayerProfile, cart_cfg: Dictionary) -> Dictionary:
	_load_if_needed()
	var now := int(Time.get_unix_time_from_system())
	var cart_uid := "cart_%d_%d" % [now, randi_range(100, 999)]
	var owner_name := owner_profile.display_name if owner_profile else "Hiệp Khách"
	
	# Tính máu tiêu xa theo cấp độ xe
	var hp_table := {
		"wood": 60000,
		"bronze": 120000,
		"silver": 250000,
		"gold": 600000
	}
	var cart_hp: int = hp_table.get(str(cart_cfg.get("id", "wood")), 60000)

	var cart := {
		"id": cart_uid,
		"owner_name": owner_name,
		"cart_id": str(cart_cfg.get("id", "wood")),
		"cart_name": str(cart_cfg.get("name", "📦 Tiêu Xa Gỗ")),
		"route": str(cart_cfg.get("route", "Tây Môn ➔ Đông Môn (Biện Kinh)")),
		"map_id": int(cart_cfg.get("map_id", 37)),
		"map_name": str(cart_cfg.get("map_name", "Biện Kinh Đô Thành")),
		"start_unix": now,
		"duration_sec": int(cart_cfg.get("duration_sec", 600)),
		"hp": cart_hp,
		"max_hp": cart_hp,
		"progress_pct": 0,
		"status": "traveling",   # "traveling", "arrived", "destroyed"
		"members": [owner_name],
		"defenders": [owner_name],
		"raiders": [],
		"reward_gold": int(cart_cfg.get("reward_gold", 0)),
		"reward_exp": int(cart_cfg.get("reward_exp", 0)),
		"reward_contrib": int(cart_cfg.get("reward_contrib", 0)),
		"deposit_gold": int(cart_cfg.get("deposit_gold", 0)),
		"deposit_jade": int(cart_cfg.get("deposit_jade", 0))
	}

	_cached_carts.append(cart)
	_save()
	return cart

## Kiểm tra điều kiện tham gia 2 phe (cân bằng chênh lệch tối đa 1 người, mỗi phe tối đa 5 người)
static func can_join_team(cart: Dictionary, team: String, player_name: String) -> Dictionary:
	var defs: Array = cart.get("defenders", [])
	var raiders: Array = cart.get("raiders", [])

	# Nếu đã ở trong phe đó rồi thì cho phép vào lại map
	if team == "defender" and defs.has(player_name):
		return {"ok": true, "reason": ""}
	if team == "raider" and raiders.has(player_name):
		return {"ok": true, "reason": ""}

	# Nếu đã thuộc phe kia thì không được đổi phe giữa chừng
	if team == "defender" and raiders.has(player_name):
		return {"ok": false, "reason": "Bạn đã gia nhập Phe Cướp Tiêu của chuyến tiêu này!"}
	if team == "raider" and defs.has(player_name):
		return {"ok": false, "reason": "Bạn đã gia nhập Phe Hộ Tiêu của chuyến tiêu này!"}

	if team == "defender":
		if defs.size() >= MAX_TEAM_MEMBERS:
			return {"ok": false, "reason": "Phe Hộ Tiêu đã đủ %d/%d người!" % [MAX_TEAM_MEMBERS, MAX_TEAM_MEMBERS]}
		# Chênh lệch sau khi gia nhập không quá 1 người so với phe kia
		if (defs.size() + 1) - raiders.size() > 1:
			return {"ok": false, "reason": "2 phe phải cân bằng (chênh lệch tối đa 1 người). Hãy chọn Phe Cướp Tiêu!"}

	elif team == "raider":
		if raiders.size() >= MAX_TEAM_MEMBERS:
			return {"ok": false, "reason": "Phe Cướp Tiêu đã đủ %d/%d người!" % [MAX_TEAM_MEMBERS, MAX_TEAM_MEMBERS]}
		if (raiders.size() + 1) - defs.size() > 1:
			return {"ok": false, "reason": "2 phe phải cân bằng (chênh lệch tối đa 1 người). Hãy chọn Phe Hộ Tiêu!"}

	return {"ok": true, "reason": ""}

## Gia nhập phe Hộ Tiêu hoặc Cướp Tiêu
static func join_cart_team(cart_uid: String, player_name: String, team: String) -> Dictionary:
	_load_if_needed()
	for c in _cached_carts:
		if str(c.get("id", "")) == cart_uid:
			var chk := can_join_team(c, team, player_name)
			if not chk.get("ok", false):
				return chk

			var defs: Array = c.get("defenders", [])
			var raiders: Array = c.get("raiders", [])
			var members: Array = c.get("members", [])

			if team == "defender" and not defs.has(player_name):
				defs.append(player_name)
				c["defenders"] = defs
			elif team == "raider" and not raiders.has(player_name):
				raiders.append(player_name)
				c["raiders"] = raiders

			if not members.has(player_name):
				members.append(player_name)
				c["members"] = members

			_save()
			return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "Không tìm thấy tiêu xa!"}

## Tìm chuyến tiêu theo ID
static func get_cart(cart_uid: String) -> Dictionary:
	_load_if_needed()
	for c in _cached_carts:
		if str(c.get("id", "")) == cart_uid:
			return c
	return {}

## Tìm chuyến tiêu đang có của chính mình
static func get_my_cart(player_name: String) -> Dictionary:
	_load_if_needed()
	for c in _cached_carts:
		if str(c.get("owner_name", "")) == player_name and str(c.get("status", "")) == "traveling":
			return c
	return {}

## Tự động khởi tạo 2 chuyến tiêu giang hồ mẫu nếu danh sách trống để luôn có chuyến tiêu tham gia PK
static func _seed_giang_ho_carts() -> void:
	var now := int(Time.get_unix_time_from_system())
	var cart1 := {
		"id": "cart_gh_101",
		"owner_name": "Tiêu Cục Phúc Uy",
		"cart_id": "silver",
		"cart_name": "⚔️ Tiêu Xa Bạc",
		"route": "Quan Lộ Ngoại Thành (Biện Kinh)",
		"map_id": 37,
		"map_name": "Biện Kinh Đô Thành",
		"start_unix": now - 120,
		"duration_sec": 1800,
		"hp": 220000,
		"max_hp": 250000,
		"progress_pct": 25,
		"status": "traveling",
		"members": ["Tiêu Cục Phúc Uy", "Hắc Phong Trại"],
		"defenders": ["Tiêu Cục Phúc Uy"],
		"raiders": ["Hắc Phong Trại"],
		"reward_gold": 800000,
		"reward_exp": 700000,
		"reward_contrib": 300,
		"deposit_gold": 300000,
		"deposit_jade": 0
	}
	var cart2 := {
		"id": "cart_gh_102",
		"owner_name": "Long Môn Thương Hội",
		"cart_id": "bronze",
		"cart_name": "🛡️ Tiêu Xa Đồng",
		"route": "Quan Lộ Ngoại Thành (Biện Kinh)",
		"map_id": 37,
		"map_name": "Biện Kinh Đô Thành",
		"start_unix": now - 60,
		"duration_sec": 1200,
		"hp": 120000,
		"max_hp": 120000,
		"progress_pct": 10,
		"status": "traveling",
		"members": ["Long Môn Thương Hội"],
		"defenders": ["Long Môn Thương Hội"],
		"raiders": [],
		"reward_gold": 380000,
		"reward_exp": 350000,
		"reward_contrib": 150,
		"deposit_gold": 150000,
		"deposit_jade": 0
	}
	_cached_carts = [cart1, cart2]
	_save()

## Người chơi khác nhảy vào bảo vệ tiêu xa
static func join_cart(cart_uid: String, player_name: String) -> bool:
	_load_if_needed()
	for c in _cached_carts:
		if str(c.get("id", "")) == cart_uid:
			var members: Array = c.get("members", [])
			if not members.has(player_name):
				members.append(player_name)
				c["members"] = members
				_save()
			return true
	return false

## Cập nhật tiến độ / HP tiêu xa
static func update_cart(cart_uid: String, hp: int, progress_pct: int) -> void:
	_load_if_needed()
	for c in _cached_carts:
		if str(c.get("id", "")) == cart_uid:
			c["hp"] = hp
			c["progress_pct"] = progress_pct
			_save()
			return

## Tiêu xa cập bến thành công -> XÓA khỏi danh sách tiêu xa đang vận chuyển
static func finish_cart(cart_uid: String) -> void:
	_load_if_needed()
	for i in range(_cached_carts.size() - 1, -1, -1):
		if str(_cached_carts[i].get("id", "")) == cart_uid:
			_cached_carts.remove_at(i)
			_save()
			print("[EscortManager] Tiêu xa %s đã hoàn thành và được XÓA khỏi danh sách!" % cart_uid)
			return

## Tiêu xa bị phá hủy -> XÓA khỏi danh sách tiêu xa đang vận chuyển
static func destroy_cart(cart_uid: String) -> void:
	_load_if_needed()
	for i in range(_cached_carts.size() - 1, -1, -1):
		if str(_cached_carts[i].get("id", "")) == cart_uid:
			_cached_carts.remove_at(i)
			_save()
			print("[EscortManager] Tiêu xa %s bị cướp phá và được XÓA khỏi danh sách!" % cart_uid)
			return

## Xóa thủ công
static func remove_cart(cart_uid: String) -> void:
	_load_if_needed()
	for i in range(_cached_carts.size() - 1, -1, -1):
		if str(_cached_carts[i].get("id", "")) == cart_uid:
			_cached_carts.remove_at(i)
			_save()
			return

# ---------------------------------------------------------------- Nội bộ
static func _load_if_needed() -> void:
	if _loaded:
		return
	_loaded = true
	_cached_carts.clear()
	if not FileAccess.file_exists(ACTIVE_LIST_PATH):
		return
	var content := FileAccess.get_file_as_string(ACTIVE_LIST_PATH)
	var parsed: Variant = JSON.parse_string(content)
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				_cached_carts.append(item)

static func _save() -> void:
	var f := FileAccess.open(ACTIVE_LIST_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_cached_carts, " "))

static func _prune_expired() -> void:
	var now := int(Time.get_unix_time_from_system())
	var changed := false
	for i in range(_cached_carts.size() - 1, -1, -1):
		var c := _cached_carts[i]
		var start := int(c.get("start_unix", 0))
		var dur := int(c.get("duration_sec", 600))
		# Hết hạn quá 30 phút mà chưa nhận thưởng -> tự dọn
		if now - start > dur + 1800:
			_cached_carts.remove_at(i)
			changed = true
	if changed:
		_save()
