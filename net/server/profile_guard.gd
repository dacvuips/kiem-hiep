class_name ProfileGuard
extends RefCounted
## Luật server cho dữ liệu nhân vật khi chơi online (B3):
##   - CẤP + KINH NGHIỆM do server tính (giết quái) — game gửi gì cũng không đổi được.
##   - ĐIỂM TIỀM NĂNG / ĐIỂM KỸ NĂNG: game được cộng điểm, nhưng tổng điểm đã dùng + điểm còn lại không được vượt số điểm cấp
##     hiện tại cho phép; sai thì giữ bản của server.
##   - Trần sát thương 1 đòn = sát thương tối đa của skill mạnh nhất nhân vật đã học (tính bằng đúng công thức chiêu của game)
##     x chí mạng x dư 20% — số báo lên vượt trần bị cắt.
##   - ĐỒ: mỗi món có uid; game chỉ được sắp xếp / mặc / tháo / cất rương / khoá / đặt giá những món server đã biết
##     (chỉ số món giữ đúng bản server), được bỏ bớt món, KHÔNG được thêm món lạ hay nhân bản (1 uid xuất hiện 2 lần).
##   - TIỀN: lượng + tiền rương không được nhiều hơn bản server; nguyên bảo không tăng. Tiền / đồ mới chỉ đến từ server
##     (nhặt đồ rơi, giao dịch, bày bán).
## Phần còn lại (thanh skill, cài đặt, khoá bảo vệ...) tin game.

## Chí mạng VLTK x2; để dư thêm cho các hệ số chưa tính (đòn chí tử, cộng dồn hiệu ứng).
const CRIT_MULT := 3.0
const TOLERANCE := 1.2
const MIN_CAP := 300.0

## Gộp dữ liệu game gửi lên vào bản của server.
## pending_gold = tiền server đã cho (nhặt...) mà game CHƯA xác nhận: game được phép có ít hơn server đúng phần đó.
## Kết quả có khoá "_money_from_server" = true nếu tiền của game bị bác (đã dùng tiền server — server đã gồm mọi khoản cho).
static func merge(server_data: Dictionary, client_data: Dictionary, pending_gold := 0) -> Dictionary:
	var merged := client_data.duplicate(true)
	for k in ["level", "exp", "name", "sect_id", "sect_name", "gender", "lead_level", "lead_exp", "server_seen",
			"guild", "guild_join_after", "camp", "security_hash", "security_locked"]:
		if server_data.has(k):
			merged[k] = server_data[k]
	var fresh := PlayerProfile.from_dict(merged)
	var level := int(server_data.get("level", 1))
	if not _potential_ok(fresh, level):
		for k in ["strength", "dexterity", "vitality", "energy", "potential_points"]:
			if server_data.has(k):
				merged[k] = server_data[k]
	if not _skills_ok(fresh, level):
		for k in ["skill_levels", "skill_points"]:
			if server_data.has(k):
				merged[k] = server_data[k]
	_guard_items(server_data, merged)
	merged["_money_from_server"] = _guard_money(server_data, merged, pending_gold)
	return merged

## Mọi món đồ trong hồ sơ (túi, trang bị, rương) theo uid.
static func items_by_uid(data: Dictionary) -> Dictionary:
	var out := {}
	for it in data.get("inventory", []):
		out[str(it.get("uid", ""))] = it
	var eq = data.get("equipment", {})
	if eq is Dictionary:
		for k in eq:
			out[str(eq[k].get("uid", ""))] = eq[k]
	for it in data.get("storage", []):
		out[str(it.get("uid", ""))] = it
	out.erase("")
	return out

## Giữ lại món server biết (lấy chỉ số từ bản server, chỉ nhận vị trí / khoá / giá từ game), bỏ món lạ / trùng uid.
static func _guard_items(server_data: Dictionary, merged: Dictionary) -> void:
	var known := items_by_uid(server_data)
	var seen := {}
	var fix := func(it: Variant) -> Variant:
		if not it is Dictionary:
			return null
		var uid := str(it.get("uid", ""))
		if uid == "" or not known.has(uid) or seen.has(uid):
			return null
		seen[uid] = true
		var out: Dictionary = (known[uid] as Dictionary).duplicate(true)
		for k in ItemInstance.OWNER_FIELDS:
			if it.has(k):
				out[k] = it[k]
		_guard_lock(known[uid], out)
		return out
	for key in ["inventory", "storage"]:
		var list := []
		for it in merged.get(key, []):
			var v = fix.call(it)
			if v != null:
				list.append(v)
		merged[key] = list
	var eq = merged.get("equipment", {})
	var new_eq := {}
	if eq is Dictionary:
		for k in eq:
			var v = fix.call(eq[k])
			if v != null:
				new_eq[k] = v
	merged["equipment"] = new_eq

## Khoá món đồ (KLockItem): khoá thì được ngay; mở khoá phải chờ đủ ITEM_UNLOCK_SECONDS rồi mới thành tự do; khoá vĩnh viễn /
## gắn nhân vật không đổi được. Game gửi chuyển trạng thái sai thì giữ trạng thái của server.
static func _guard_lock(server_item: Dictionary, out: Dictionary) -> void:
	var s_lock := int(server_item.get("lock", ItemInstance.LOCK_NORMAL))
	var s_at := int(server_item.get("unlock_at", 0))
	var c_lock := int(out.get("lock", s_lock))
	var c_at := int(out.get("unlock_at", 0))
	var now := SecurityLock.now()
	var ok := false
	match s_lock:
		ItemInstance.LOCK_NORMAL:
			ok = c_lock in [ItemInstance.LOCK_NORMAL, ItemInstance.LOCK_LOCKED]
		ItemInstance.LOCK_LOCKED:
			ok = c_lock == ItemInstance.LOCK_LOCKED \
				or (c_lock == ItemInstance.LOCK_UNLOCKING and c_at >= now + SecurityLock.ITEM_UNLOCK_SECONDS - 600)
		ItemInstance.LOCK_UNLOCKING:
			if c_lock == ItemInstance.LOCK_UNLOCKING:
				out["unlock_at"] = s_at       ## không rút ngắn thời gian chờ
				ok = true
			else:
				ok = c_lock == ItemInstance.LOCK_LOCKED or (c_lock == ItemInstance.LOCK_NORMAL and now >= s_at)
	if not ok:
		out["lock"] = s_lock
		out["unlock_at"] = s_at

## Tổng giá mở thêm rương từ `from_extra` lên `to_extra` (StorageService.extra_box_cost).
static func box_cost(from_extra: int, to_extra: int) -> int:
	var cost := 0
	for k in range(from_extra, to_extra):
		cost += StorageService.EXPAND_COST_BASE * (k + 1)
	return cost

static func _guard_money(server_data: Dictionary, merged: Dictionary, pending_gold: int) -> bool:
	var s_total := int(server_data.get("gold", 0)) + int(server_data.get("storage_gold", 0))
	var gold := int(merged.get("gold", 0))
	var bank := int(merged.get("storage_gold", 0))
	## Mở thêm rương phải trả tiền: số rương tăng thì tổng tiền phải giảm ít nhất bằng giá mở.
	var s_extra := int(server_data.get("storage_extra", 0))
	var c_extra := clampi(int(merged.get("storage_extra", s_extra)), 0, StorageService.MAX_EXTRA_BOXES)
	var cost := box_cost(s_extra, c_extra) if c_extra > s_extra else 0
	if c_extra < s_extra:
		c_extra = s_extra   ## không tự bớt rương (đồ trong rương có thể mất chỗ)
	if gold + bank > s_total - pending_gold - cost:
		c_extra = s_extra
		cost = 0
	merged["storage_extra"] = c_extra
	var rejected := gold < 0 or bank < 0 or gold + bank > s_total - pending_gold - cost
	if rejected:
		merged["gold"] = server_data.get("gold", 0)
		merged["storage_gold"] = server_data.get("storage_gold", 0)
	if int(merged.get("jade", 0)) > int(server_data.get("jade", 0)) or int(merged.get("jade", 0)) < 0:
		merged["jade"] = server_data.get("jade", 0)
	return rejected

## Điểm tiềm năng hợp lệ: đã cộng + còn lại <= điểm khởi đầu + 5 x (cấp - 1), không âm.
static func _potential_ok(p: PlayerProfile, level: int) -> bool:
	var start: Array = p.get_start_stats()
	var spent := (p.strength - int(start[0])) + (p.dexterity - int(start[1])) + (p.vitality - int(start[2])) + (p.energy - int(start[3]))
	var budget := PlayerProfile.new().potential_points + PlayerProfile.POTENTIAL_POINTS_PER_LEVEL * (level - 1)
	return p.potential_points >= 0 and spent >= 0 and spent + p.potential_points <= budget

## Điểm kỹ năng hợp lệ: tổng cấp skill mua bằng điểm + còn lại <= điểm khởi đầu + 1 x (cấp - 1), không vượt cấp tối đa từng skill.
static func _skills_ok(p: PlayerProfile, level: int) -> bool:
	var sect := SectRegistry.get_by_id(p.sect_id)
	if sect == null:
		return p.skill_levels.is_empty()
	var by_id := {}
	for s in sect.skills:
		by_id[s.id] = s
	var spent := 0
	for id in p.skill_levels:
		var skill: SkillDefinition = by_id.get(id)
		var lv := int(p.skill_levels[id])
		if skill == null or lv < 0 or lv > skill.max_level:
			return false
		if not skill.practice_only:
			spent += lv
	var budget := PlayerProfile.new().skill_points + PlayerProfile.SKILL_POINTS_PER_LEVEL * (level - 1)
	return p.skill_points >= 0 and spent + p.skill_points <= budget

## Nhân vật MỚI (chưa qua server lần nào): dữ liệu do game tạo lúc "Tạo nhân vật" — chỉ giữ phần ngoại hình / cài đặt,
## phần kinh tế về đúng khởi đầu (cấp 1, không tiền, không đồ, điểm mặc định). Chặn tạo nhân vật kèm sẵn tiền / đồ.
static func sanitize_new(data: Dictionary) -> Dictionary:
	var src := PlayerProfile.from_dict(data)
	var fresh := PlayerProfile.new()
	fresh.display_name = src.display_name
	fresh.gender = src.gender
	var sect := SectRegistry.get_by_id(src.sect_id)
	if sect:
		fresh.set_sect(sect)
	fresh.camp = src.camp
	fresh.riding = src.riding
	fresh.skill_settings = src.skill_settings
	fresh.server_seen = 1
	return fresh.to_dict()

class _Caster extends Node2D:
	var combat_stats: CombatantStats

## Sát thương tối đa 1 đòn (đã nhân chí mạng + dư) của nhân vật — dùng làm trần cho C_DAMAGE.
static func max_hit(profile: PlayerProfile) -> float:
	var sect := SectRegistry.get_by_id(profile.sect_id)
	if sect == null:
		return MIN_CAP
	## _resolve_stats đọc hồ sơ qua GameManager.local_profile -> đặt tạm hồ sơ của người này (server chạy 1 luồng).
	var prev := GameManager.local_profile
	GameManager.local_profile = profile
	var ctrl := SectSkillController.new()
	ctrl.setup(sect)
	var caster := _Caster.new()
	caster.combat_stats = profile.get_combat_stats()
	var best := 0.0
	for skill in sect.skills:
		if not ctrl.is_skill_usable(skill):
			continue
		var st: ResolvedSkillStats = ctrl._resolve_stats(skill, caster)
		var hit := maxf(st.damage, st.damage_max)
		for v in st.extra_damage_ranges.values():
			hit += float((v as Vector2i).y)
		best = maxf(best, hit)
	GameManager.local_profile = prev
	ctrl.free()
	caster.free()
	return maxf(MIN_CAP, best * CRIT_MULT * TOLERANCE)

## Kinh nghiệm nhận được khi góp `share_percent` sát thương hạ quái (luật KPlayer::AddSelfExp gốc).
static func exp_for_kill(player_level: int, monster_data: Dictionary, monster_level: int, share_percent: int) -> int:
	var base := MonsterData.stat_at_level(monster_data, "exp", monster_level)
	if base <= 0:
		return 0
	var shared := maxi(1, base * clampi(share_percent, 1, 100) / 100)
	return ExpRules.self_exp(player_level, monster_level, shared)
