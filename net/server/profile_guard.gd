class_name ProfileGuard
extends RefCounted
## Luật server cho dữ liệu nhân vật khi chơi online (B3):
##   - CẤP + KINH NGHIỆM do server tính (giết quái) — game gửi gì cũng không đổi được.
##   - ĐIỂM TIỀM NĂNG / ĐIỂM KỸ NĂNG: game được cộng điểm, nhưng tổng điểm đã dùng + điểm còn lại không được vượt số điểm cấp
##     hiện tại cho phép; sai thì giữ bản của server.
##   - Trần sát thương 1 đòn = sát thương tối đa của skill mạnh nhất nhân vật đã học (tính bằng đúng công thức chiêu của game)
##     x chí mạng x dư 20% — số báo lên vượt trần bị cắt.
## Phần còn lại (túi đồ, trang bị, tiền, thanh skill, cài đặt) tạm tin game; bước C chuyển túi đồ / tiền lên server.

## Chí mạng VLTK x2; để dư thêm cho các hệ số chưa tính (đòn chí tử, cộng dồn hiệu ứng).
const CRIT_MULT := 3.0
const TOLERANCE := 1.2
const MIN_CAP := 300.0

## Gộp dữ liệu game gửi lên vào bản của server.
static func merge(server_data: Dictionary, client_data: Dictionary) -> Dictionary:
	var merged := client_data.duplicate(true)
	for k in ["level", "exp", "name", "sect_id", "sect_name", "gender"]:
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
	return merged

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
