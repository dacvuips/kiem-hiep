extends RefCounted
class_name KillRewards
## Thưởng khi hạ quái: kinh nghiệm nhân vật (đã chia theo tổ đội + trừ chênh cấp — ExpRules/TeamService) và kinh nghiệm lãnh đạo của đội trưởng.
## Kinh nghiệm gốc của quái = bảng "exp" trong data/monsters (MonsterData.stat_at_level), như KNpc::m_CurrentExperience gốc.
## Tắt hẳn bằng ENABLED = false (khi muốn chỉ nhận kinh nghiệm theo cách cũ: cuối mỗi ải).

const ENABLED := true

## Cộng kinh nghiệm cho `profile` khi giết quái `monster_level` có kinh nghiệm gốc `base_exp`. Trả về số kinh nghiệm thực nhận (0 nếu tắt).
static func grant_exp(profile: PlayerProfile, base_exp: int, monster_level: int) -> int:
	if not ENABLED or profile == null or base_exp <= 0:
		return 0
	var team := SocialHub.of(profile).team
	var got := team.local_exp_for_kill(base_exp, monster_level)
	if got <= 0:
		return 0
	var loop := Engine.get_main_loop()
	var player: Node = (loop as SceneTree).get_first_node_in_group("player") if loop is SceneTree else null
	if player != null and "combat_stats" in player and player.combat_stats != null:
		if player.combat_stats.exp_enhance_p > 0:
			got = int(round(got * (1.0 + float(player.combat_stats.exp_enhance_p) / 100.0)))
	var before := profile.level
	profile.add_exp(got)
	if profile.level != before:
		SaveManager.save_profile(profile)
		if player != null and player.has_method("refresh_combat_stats"):
			player.refresh_combat_stats()
	return got

static func on_monster_killed(monster: VltkMonster) -> void:
	if not ENABLED or monster == null:
		return
	var base := MonsterData.stat_at_level(monster.data, "exp", monster.level)
	grant_exp(GameManager.local_profile, base, monster.level)
