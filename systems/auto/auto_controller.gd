extends Node
class_name AutoController
## BỘ MÁY AUTO ĐÁNH của 1 nhân vật — con của Player, chạy theo bộ AutoSettings đang chọn (PlayerProfile.get_auto_settings()).
## Mọi trạng thái lúc chạy (mục tiêu, điểm đang tới, đồ đang nhặt...) nằm TRÊN node này (mỗi người chơi 1 cái), AutoSettings chỉ là dữ liệu.
## Auto chỉ "bấm hộ" người chơi: ra chiêu qua SectSkillController như bấm tay, đi bằng walk_to_feet / vector chạy như phím, nhặt qua
## GroundDrop như nhấp chuột — nên khi chơi online server vẫn kiểm tra mọi thứ y như người thật bấm.
##
## Mỗi THINK_INTERVAL giây quyết định 1 lần, theo thứ tự ưu tiên:
##   1. Hồi phục: điều kiện Thổ Địa Phù (độ bền thấp / hành trang đầy) -> phù về thành; máu dưới Mức 1 -> uống
##      thuốc hồi sinh lực trong túi (Mức 2: nhiều bình liền); hết thuốc -> ngồi thiền hồi máu khi không có địch gần.
##   2. Giữ vòng sáng + buff hỗ trợ (ra lại khi trạng thái đã hết).
##   3. Vừa hạ mục tiêu / đang đi nhặt: nhặt đồ trong phạm vi nhặt theo bộ lọc.
##   4. Chọn mục tiêu (lọc người/quái, ngũ hành, môn phái; ưu tiên Boss / thấp máu) rồi đánh; ngoài tầm thì tiếp cận (Truy đuổi)
##      THEO ĐƯỜNG TÌM ĐƯỢC (vòng qua vật cản, như bấm điểm trên bản đồ) — không có đường tới thì bỏ qua mục tiêu đó.
##   5. Rảnh: theo sau đội trưởng / về điểm đánh quanh / sang toạ độ kế tiếp.

const THINK_INTERVAL := 0.15
## Người chơi tự bấm di chuyển: auto nhường tay trong chừng này giây.
const MANUAL_PAUSE := 1.5
## Đồ nhặt không được (đầy túi, luật nhặt tổ đội, kẹt đường) bỏ qua chừng này.
const LOOT_SKIP_MS := 8000
## Đuổi 1 mục tiêu quá lâu mà không vào được tầm (kẹt vật cản) -> bỏ qua nó chừng này.
const CHASE_GIVE_UP := 12.0
## Đang đuổi / đi theo đội trưởng: tìm lại đường mỗi chừng này giây (mục tiêu di chuyển).
const REPLAN_SEC := 0.5
const TARGET_SKIP_MS := 6000
## Đánh mục tiêu mà liên tiếp chừng này lần ra chiêu không làm nó mất máu (trượt, kẹt sau vật cản, đạn không tới...) -> bỏ qua
## TARGET_SKIP_MS, tìm quái khác.
const NO_DAMAGE_GIVE_UP := 4
## Đứng ở 1 toạ độ (Chạy toạ độ) mà quanh đó hết quái chừng này giây -> sang toạ độ kế.
const ROUTE_IDLE_TIME := 3.0
const ARRIVE_DISTANCE := 40.0
## Chọn lại mục tiêu tốt hơn (Boss mới xuất hiện...) mỗi chừng này giây dù mục tiêu cũ còn sống.
const RESCORE_INTERVAL := 1.0
## Ngồi thiền hồi máu tới tỉ lệ này thì đứng dậy đánh tiếp.
const REST_UNTIL := 0.95
const CHASE_STOP_RATIO := 0.85

var player  ## Player (player.gd)
var target: Node2D = null
var running := false

var _think := 0.0
var _paused_until_ms := 0
var _chasing := false
var _chase_time := 0.0
var _rescore := 0.0
var _target_skip := {}       ## instance_id -> hết bỏ qua lúc (ms)
var _no_damage := 0          ## số lần ra chiêu liên tiếp vào mục tiêu hiện tại mà nó không mất máu
var _last_hp := INF          ## máu mục tiêu lúc ra chiêu lần trước (INF = chưa ra chiêu nào)
var _loot: GroundDrop = null
var _loot_skip := {}
var _route_index := 0
var _route_idle := 0.0
var _resting := false
var _leader: Node2D = null
var _leader_scan := 0.0
var _replan := 0.0
var _potion_ready_ms := 0

func _init(owner_player: Node2D) -> void:
	player = owner_player
	name = "AutoController"

func settings() -> AutoSettings:
	var profile := GameManager.local_profile
	return profile.get_auto_settings() if profile else AutoSettings.new()

# ------------------------------------------------------------------ vòng chạy (Player._physics_process gọi)

func tick(delta: float, on: bool) -> void:
	if target != null and (not is_instance_valid(target) or not (target is Node2D) or (target is Node and target.is_queued_for_deletion())):
		_drop_target()
	if _leader != null and (not is_instance_valid(_leader) or not (_leader is Node2D) or (_leader is Node and _leader.is_queued_for_deletion())):
		_leader = null
	if _loot != null and (not is_instance_valid(_loot) or (_loot is Node and _loot.is_queued_for_deletion())):
		_loot = null
	if not on:
		if running:
			_stop()
		return
	if not running:
		_start()
	if _chasing:
		_chase_time += delta
	_rescore -= delta
	_leader_scan -= delta
	_replan -= delta
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK_INTERVAL
	if Time.get_ticks_msec() < _paused_until_ms or player.is_dead():
		return
	var s := settings()
	if _tick_recovery(s):
		return
	if _resting:
		return
	_update_leader(s)
	if _leader_far(s):
		_drop_target()
		_walk_towards(_leader)
		return
	if _keep_buffs(s):
		return
	## Nhặt đồ TRƯỚC khi chọn quái mới: vừa hạ xong mục tiêu (hoặc đang đi nhặt) thì nhặt hết đồ hợp thiết lập trong tầm nhặt
	## rồi mới đánh tiếp — không thì chỗ quái đông Auto luôn có mục tiêu mới và không bao giờ nhặt.
	if (_loot != null or not _target_alive(target)) and _tick_loot(s):
		_drop_target()
		return
	_update_target(s)
	if target != null:
		_attack(s)
		return
	_idle_move(s, THINK_INTERVAL)

## Hướng chạy mỗi frame (sau điểm bấm / đi theo của Player) — auto không còn chạy thẳng (xem _chase / _follow_leader).
func get_move_vector() -> Vector2:
	if not running or Time.get_ticks_msec() < _paused_until_ms or _resting:
		return Vector2.ZERO
	if player.is_attacking or player.is_casting or player.status_controller.is_stunned:
		return Vector2.ZERO
	## Đuổi mục tiêu / theo đội trưởng đi bằng lộ trình tìm đường (walk_to_feet ở _attack / tick) — không chạy thẳng.
	return Vector2.ZERO

## Người chơi tự bấm phím / điểm trên bản đồ: tạm nhường tay.
func on_manual_input() -> void:
	if running:
		_paused_until_ms = Time.get_ticks_msec() + int(MANUAL_PAUSE * 1000.0)
		_chasing = false

## Player.die() gọi trước khi tắt auto.
func on_player_died() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	var s := settings()
	profile.add_auto_log("Bị trọng thương khi đang auto", "death")
	if s.report_death_on:
		_report(profile, "death", s.report_death_count, s.report_death_minutes, s.report_death_notify,
				"Chết liên tiếp %d lần trong %d phút")
	if s.change_map_on_death and profile.count_auto_log("death", s.change_map_minutes) >= s.change_map_deaths:
		profile.add_auto_log("Chết %d lần trong %d phút — nên đổi bản đồ luyện công" % [s.change_map_deaths, s.change_map_minutes], "report")
	SaveManager.save_profile(profile)

## Cửa sổ thiết lập lưu xong: áp lại phần cần áp ngay (tổ đội).
func apply_settings() -> void:
	var profile := GameManager.local_profile
	if profile == null:
		return
	var s := settings()
	SocialHub.of(profile).team.auto_refuse_invite = s.team_on and s.accept_mode == 0

func _start() -> void:
	running = true
	_think = 0.0
	_route_index = 0
	_route_idle = 0.0
	_target_skip.clear()
	_loot_skip.clear()
	apply_settings()
	player.notify("Bắt đầu auto — %s" % ("PK" if GameManager.local_profile and GameManager.local_profile.auto_mode == AutoSettings.Mode.PK else "Luyện công"))

func _stop() -> void:
	running = false
	_drop_target()
	_loot = null
	if _resting and player.is_sitting():
		player.toggle_sit()
	_resting = false

func _drop_target() -> void:
	target = null
	_chasing = false
	_chase_time = 0.0
	_no_damage = 0
	_last_hp = INF

# ------------------------------------------------------------------ 1. hồi phục

## true = đang bận hồi phục (bỏ qua phần còn lại của lượt này).
func _tick_recovery(s: AutoSettings) -> bool:
	var hp_pct: float = player.health / maxf(player.max_health, 1.0) * 100.0
	var reason := ""
	if s.tdp_low_dura_on and _lowest_durability_pct() < s.tdp_low_dura:
		reason = "Độ bền trang bị thấp"
	elif s.tdp_bag_full and _bag_full():
		reason = "Hành trang đầy"
	if reason != "":
		_use_tdp(s, reason)
		return true
	## Máu dưới Mức 1: uống thuốc (không chiếm lượt — vẫn đánh tiếp); hết thuốc thì ngồi thiền (dưới) khi quanh mình không có địch.
	if not _resting and s.hp_on and hp_pct < s.hp_lv1:
		_try_potion(s)
	if _resting:
		if not player.is_sitting():
			_resting = false        ## bị đánh -> đã đứng dậy, đánh trả
			return false
		if hp_pct >= REST_UNTIL * 100.0:
			player.toggle_sit()
			_resting = false
		return true
	if s.hp_on and hp_pct < s.hp_lv1 and not _has_potion(GameManager.local_profile) and _find_target(s, true) == null:
		_drop_target()
		if not player.is_sitting():
			player.toggle_sit()
		_resting = player.is_sitting()
		return _resting
	return false

## Thuốc hồi sinh lực trong túi (như bấm "Dùng" ở Hành trang): máu dưới Mức 1 -> 1 bình mỗi hp_ms1 mili giây; dưới Mức 2 ->
## hp_count2 bình liền mỗi hp_ms2. true = đang dùng thuốc (vừa uống / đang chờ tới lượt uống tiếp), false = không còn thuốc.
## Thuốc nội lực (Mức nội lực): game chưa có nội lực tiêu hao (PotionEffect bỏ qua manapotion_v) nên chưa dùng.
func _try_potion(s: AutoSettings) -> bool:
	if not s.hp_on:
		return false
	var profile := GameManager.local_profile
	if profile == null:
		return false
	var now := Time.get_ticks_msec()
	if now < _potion_ready_ms:
		return _has_potion(profile)
	var hp_pct: float = player.health / maxf(player.max_health, 1.0) * 100.0
	var urgent := hp_pct < s.hp_lv2
	var used := 0
	for i in (maxi(1, s.hp_count2) if urgent else 1):
		if _drink_one(profile):
			used += 1
	if used == 0:
		return false
	_potion_ready_ms = now + (s.hp_ms2 if urgent else s.hp_ms1)
	SaveManager.save_profile(profile)
	return true

func _has_potion(profile: PlayerProfile) -> bool:
	for it in profile.inventory:
		if PotionEffect.heals(it):
			return true
	return false

## Uống 1 bình (bình hồi nhiều sinh lực nhất trong túi) — bỏ bình khỏi túi như InventoryPopup._use.
func _drink_one(profile: PlayerProfile) -> bool:
	var best := -1
	var best_total := 0.0
	for i in profile.inventory.size():
		var it: ItemInstance = profile.inventory[i]
		if not PotionEffect.heals(it):
			continue
		var total := 0.0
		for e in it.get_base().get("effects", []):
			if str(e[0]) == "lifepotion_v":
				total += float(e[1]) * float(e[2])
		if best < 0 or total > best_total:
			best = i
			best_total = total
	if best < 0:
		return false
	var item: ItemInstance = profile.inventory[best]
	if item.count > 1:
		item.count -= 1
	else:
		profile.inventory.remove_at(best)
	PotionEffect.drink(player, item)
	return true

## Phù về thành. Chưa có vật phẩm Thổ Địa Phù / bản đồ thành thị: dừng auto tại chỗ + ghi chiến báo (an toàn hơn đứng chịu đòn).
func _use_tdp(s: AutoSettings, reason: String) -> void:
	var profile := GameManager.local_profile
	player.notify("Phù về thành: %s" % reason)
	if profile:
		profile.add_auto_log("Dùng Thổ Địa Phù — %s" % reason, "tdp")
		if s.report_tdp_on:
			_report(profile, "tdp", s.report_tdp_count, s.report_tdp_minutes, s.report_tdp_notify,
					"Phù về thành liên tiếp %d lần trong %d phút")
		SaveManager.save_profile(profile)
	player.is_auto_mode = false
	_stop()

func _lowest_durability_pct() -> float:
	var profile := GameManager.local_profile
	var lowest := 100.0
	if profile == null:
		return lowest
	for it in profile.equipment.values():
		var item := it as ItemInstance
		if item == null:
			continue
		var max_d := item.get_max_durability()
		if max_d > 0:
			lowest = minf(lowest, item.durability * 100.0 / max_d)
	return lowest

func _bag_full() -> bool:
	var profile := GameManager.local_profile
	return profile != null and profile.find_free_spot_any(Vector2i.ONE).x < 0

## Chiến báo: đủ `count` lần trong `minutes` phút thì báo (tối đa `notify` lần mỗi khoảng thời gian đó).
func _report(profile: PlayerProfile, kind: String, count: int, minutes: int, notify: int, fmt: String) -> void:
	if profile.count_auto_log(kind, minutes) < count:
		return
	if profile.count_auto_log("report_" + kind, minutes) >= notify:
		return
	var text := "Chiến báo: " + fmt % [count, minutes]
	profile.add_auto_log(text, "report_" + kind)
	player.notify(text)

# ------------------------------------------------------------------ 2. vòng sáng / buff

## Ra 1 chiêu buff/vòng sáng nếu cần — true = đã ra chiêu lượt này.
func _keep_buffs(s: AutoSettings) -> bool:
	if _busy():
		return false
	var controller: SectSkillController = player.skill_controller
	## VLTK chỉ bật 1 vòng sáng cùng lúc: chỉ giữ vòng sáng ĐẦU TIÊN (bấm lại vòng sáng đang bật là tắt nó).
	var aura_done := false
	for id in s.aura_skills:
		var skill := _usable(id)
		if skill == null:
			continue
		if skill.is_aura:
			if aura_done:
				continue
			aura_done = true
			if not controller.is_aura_active(skill) and controller.try_cast_loop(skill, player, null):
				player.play_cast()
				return true
		elif _cast_buff(skill):
			return true
	for id in s.support_skills:
		var skill := _usable(id)
		if skill != null and not skill.is_aura and _cast_buff(skill):
			return true
	return false

func _cast_buff(skill: SkillDefinition) -> bool:
	var controller: SectSkillController = player.skill_controller
	if controller.get_cooldown_ratio(skill.id) > 0.0 or player.status_controller.has_state(skill.id):
		return false
	var tgt: Node2D = null
	if skill.target_enemy:
		if not _target_alive(target) or _logic_dist(target) > player.get_skill_radius(skill):
			return false
		tgt = target
	if controller.try_cast_loop(skill, player, tgt):
		player.play_cast()
		return true
	return false

# ------------------------------------------------------------------ 3. mục tiêu + đánh

func _update_target(s: AutoSettings) -> void:
	if _target_alive(target) and _accepts(target, s) and _in_zone(target, s) and _rescore > 0.0:
		if _chasing and _chase_time > CHASE_GIVE_UP:
			if is_instance_valid(target):
				_target_skip[target.get_instance_id()] = Time.get_ticks_msec() + TARGET_SKIP_MS
		else:
			return
	_rescore = RESCORE_INTERVAL
	var best := _find_target(s, false)
	if best != target:
		_drop_target()
		target = best
		if target != null:
			player.stop_walking()   ## thôi đi tới toạ độ / đồ rơi, quay sang đánh

## `threat_only` = chỉ hỏi "quanh đây có địch không" (khi định ngồi thiền) — bỏ qua bộ lọc vùng đánh.
func _find_target(s: AutoSettings, threat_only: bool) -> Node2D:
	var now := Time.get_ticks_msec()
	var best: Node2D = null
	var best_score := INF
	var scan_sq := float(s.scan_range) * s.scan_range
	var main_radius: float = player.get_skill_radius(_attack_skill(s))
	var chosen: Node2D = player.get_player_chosen_target()
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null or not _target_alive(e) or not _accepts(e, s):
			continue
		if int(_target_skip.get(e.get_instance_id(), 0)) > now:
			continue
		var d_sq := _logic_sq(e.global_position - player.global_position)
		if d_sq > scan_sq:
			continue
		if threat_only:
			return e
		if not s.chase and d_sq > main_radius * main_radius:
			continue
		if not _in_zone(e, s):
			continue
		var score := d_sq
		if s.prefer_low_hp and "health" in e and "max_health" in e:
			score += float(e.get("health")) / maxf(float(e.get("max_health")), 1.0) * 1e12
		if s.prefer_boss and e.get("blue_boss") == true:
			score -= 1e15
		if e == chosen:
			score -= 1e16       ## người chơi tự bấm chọn mục tiêu: đánh nó trước
		if score < best_score:
			best_score = score
			best = e
	return best

## Lọc người/quái, ngũ hành, môn phái.
func _accepts(e: Variant, s: AutoSettings) -> bool:
	if e == null or not is_instance_valid(e) or not (e is Node2D):
		return false
	var node := e as Node2D
	if node is RemotePlayer:
		if not s.target_players:
			return false
		if s.sect_filter_on and "sect_id" in node and not (str(node.get("sect_id")) in s.sects):
			return false     ## người chơi chưa gửi môn phái (online hiện chưa có) thì không lọc được -> vẫn đánh
		return true
	if not s.target_monsters:
		return false
	var data: Variant = node.get("data")
	if s.element_filter_on and data is Dictionary:
		var series := clampi(int(data.get("series", 0)), 0, 4)
		if not bool(s.elements[series]):
			return false
	return true

## Đánh quanh điểm / Chạy toạ độ: chỉ đánh địch trong vùng quanh điểm đó (không bị dụ chạy xa) — kiểm tra cả lúc chọn lẫn suốt lúc
## đánh/đuổi (quái chạy ra ngoài vùng thì thôi). Ngoại lệ tự vệ: con đang nhắm vào mình và đã ở trong tầm đòn chính thì vẫn đánh trả.
func _in_zone(e: Variant, s: AutoSettings) -> bool:
	if e == null or not is_instance_valid(e) or not (e is Node2D):
		return false
	var node := e as Node2D
	if not _point_in_zone(node.global_position + Vector2(0, VltkWorld.FEET_OFFSET), s):
		return node.has_method("is_engaging") and node.is_engaging(player) and _logic_dist(node) <= player.get_skill_radius(_attack_skill(s))
	return true

## Toạ độ chân `feet` có nằm trong vùng đánh (điểm Chạy toạ độ đang tới / điểm Đánh quanh điểm) không; không bật vùng nào = luôn có.
func _point_in_zone(feet: Vector2, s: AutoSettings) -> bool:
	if s.route_on and not s.route.is_empty():
		var p: Vector2 = s.route[_route_index % s.route.size()]
		return _logic_sq(feet - p) <= float(s.route_radius) * s.route_radius
	if s.anchor_on and s.has_anchor:
		return _logic_sq(feet - s.anchor) <= float(s.anchor_radius) * s.anchor_radius
	return true

func _attack(s: AutoSettings) -> void:
	if not _target_alive(target):
		_drop_target()
		return
	var skill := _attack_skill(s)
	var radius: float = player.get_skill_radius(skill)
	if _logic_dist(target) <= radius:
		if _chasing and player.is_moving_to_target():
			player.stop_walking()
		_chasing = false
		_chase_time = 0.0
		if not _busy() and player.skill_controller.try_cast_loop(skill, player, target):
			player.play_cast()
			_check_damage()
		return
	if not s.chase:
		_drop_target()
		return
	if not _chasing:
		_chasing = true
		_chase_time = 0.0
		_replan = 0.0
	## Tiếp cận theo lộ trình tìm đường (vòng qua vật cản); mục tiêu di chuyển -> tìm lại mỗi REPLAN_SEC. Không có đường tới
	## (sau tường kín, bên kia sông...) -> bỏ qua mục tiêu, chọn con khác ngay.
	if not _walk_towards(target):
		if is_instance_valid(target):
			_target_skip[target.get_instance_id()] = Time.get_ticks_msec() + TARGET_SKIP_MS
		_drop_target()
		_rescore = 0.0

## Đi tới chỗ đứng của `node` theo lộ trình tìm đường của map (như bấm điểm trên bản đồ). false = không có đường.
func _walk_towards(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return false
	if _replan > 0.0 and player.is_moving_to_target():
		return true
	_replan = REPLAN_SEC
	return player.walk_to_feet(VltkMath.ground_of(node as Node2D))

## Mỗi lần ra chiêu: so máu mục tiêu với lần ra chiêu trước (đòn trước đã kịp trúng hay chưa). Không giảm thì đếm 1 lần
## "không lên dame"; đủ NO_DAMAGE_GIVE_UP lần liên tiếp -> bỏ qua mục tiêu này, tìm con khác. Mục tiêu không có máu để đọc: bỏ qua.
func _check_damage() -> void:
	if not _target_alive(target) or not ("health" in target):
		return
	var hp := float(target.health)
	if _last_hp != INF:
		_no_damage = 0 if hp < _last_hp else _no_damage + 1
	_last_hp = hp
	if _no_damage >= NO_DAMAGE_GIVE_UP:
		if is_instance_valid(target):
			_target_skip[target.get_instance_id()] = Time.get_ticks_msec() + TARGET_SKIP_MS
		_drop_target()
		_rescore = 0.0   ## chọn mục tiêu mới ngay lượt sau

## Chiêu đánh: ô Tấn công đầu tiên đã hồi xong; chưa ô nào hồi thì ô đầu; không đặt ô nào thì đòn chính (nút lớn).
func _attack_skill(s: AutoSettings) -> SkillDefinition:
	var first: SkillDefinition = null
	for id in s.attack_skills:
		var skill := _usable(id)
		if skill == null:
			continue
		if first == null:
			first = skill
		if player.skill_controller.get_cooldown_ratio(skill.id) <= 0.0:
			return skill
	return first if first != null else player.skill_controller.get_main_skill()

func _stop_distance(s: AutoSettings) -> float:
	return minf(float(s.approach), player.get_skill_radius(_attack_skill(s)) * CHASE_STOP_RATIO)

# ------------------------------------------------------------------ 4. nhặt đồ

func _tick_loot(s: AutoSettings) -> bool:
	var now := Time.get_ticks_msec()
	if _loot != null and is_instance_valid(_loot) and not _loot.is_queued_for_deletion():
		if _loot.try_auto_pick(player):
			_loot_skip[_loot.get_instance_id()] = now + LOOT_SKIP_MS   ## còn nằm đó = không nhặt được (túi đầy...)
			_loot = null
			return true
		if player.is_moving_to_target():
			return true
		_loot_skip[_loot.get_instance_id()] = now + LOOT_SKIP_MS       ## không đi tới được
	_loot = null
	var feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
	var best_sq := float(s.pick_range) * s.pick_range
	for node in get_tree().get_nodes_in_group(GroundDrop.GROUP):
		var drop := node as GroundDrop
		if drop == null or int(_loot_skip.get(drop.get_instance_id(), 0)) > now or not _wants(drop, s):
			continue
		if not _point_in_zone(drop.global_position, s):
			continue       ## Đánh quanh điểm / Chạy toạ độ: đồ rơi ngoài vùng không nhặt (không bị kéo ra xa)
		var d_sq := _logic_sq(drop.global_position - feet)
		if d_sq <= best_sq:
			best_sq = d_sq
			_loot = drop
	if _loot == null:
		return false
	if _loot.try_auto_pick(player):
		_loot_skip[_loot.get_instance_id()] = now + LOOT_SKIP_MS
		_loot = null
	elif not player.walk_to_feet(_loot.global_position):
		_loot_skip[_loot.get_instance_id()] = now + LOOT_SKIP_MS
		_loot = null
	return true

## Bộ lọc nhặt: tiền theo "Nhặt tiền vạn"; đồ: "Nhặt tất cả" lấy hết, không thì đạo cụ (thuốc, khoáng thạch, lệnh bài... — không
## phải trang bị) theo "Nhặt đạo cụ", đồ xanh/hoàng kim (Nhặt trang bị xanh) và đồ khớp 1 dòng lọc thuộc tính (Tuỳ chọn lọc đồ khi nhặt).
func _wants(drop: GroundDrop, s: AutoSettings) -> bool:
	if drop.amount > 0:
		return s.pick_money
	var item := drop.item
	if item == null:
		return false
	if s.pick_all:
		return true
	if item.is_misc():
		return s.pick_props
	if s.pick_blue and (item.is_gold() or not item.magic.is_empty()):
		return true
	return s.pick_filter and matches_filter(item, s.filter_rows)

## Đồ có ít nhất 1 dòng thuộc tính chứa chữ của 1 dòng lọc và giá trị >= mức tối thiểu của dòng đó.
static func matches_filter(item: ItemInstance, rows: Array) -> bool:
	for row in rows:
		var key := str(row.get("text", "")).strip_edges().to_lower()
		if key == "":
			continue
		for line in item.magic + item.expand_magic:
			if str(line.get("attrib", "")) == "":
				continue
			var values: Array = line.get("value", [0, 0, 0])
			var text := ItemText.format_attrib(line["attrib"], values).to_lower()
			if text.contains(key) and (values.is_empty() or int(values[0]) >= int(row.get("min", 0))):
				return true
	return false

# ------------------------------------------------------------------ 5. di chuyển lúc rảnh

func _idle_move(s: AutoSettings, delta: float) -> void:
	if player.is_moving_to_target():
		return
	var feet: Vector2 = player.global_position + Vector2(0, VltkWorld.FEET_OFFSET)
	if s.route_on and not s.route.is_empty():
		_route_index %= s.route.size()
		var p: Vector2 = s.route[_route_index]
		if feet.distance_to(p) > ARRIVE_DISTANCE:
			_route_idle = 0.0
			if not player.walk_to_feet(p):
				_route_index += 1     ## điểm không tới được: bỏ qua
			return
		_route_idle += delta
		if _route_idle >= ROUTE_IDLE_TIME:
			_route_idle = 0.0
			_route_index += 1
		return
	if s.anchor_on and s.has_anchor and feet.distance_to(s.anchor) > ARRIVE_DISTANCE:
		player.walk_to_feet(s.anchor)

## Theo sau đội trưởng: tìm node người chơi (nhóm "followable") trùng tên đội trưởng — offline đội trưởng là người giả lập nên không có.
func _update_leader(s: AutoSettings) -> void:
	if not s.follow_leader_on:
		_leader = null
		return
	if _leader != null and is_instance_valid(_leader) and _leader_scan > 0.0:
		return
	_leader_scan = 1.0
	_leader = null
	var profile := GameManager.local_profile
	if profile == null:
		return
	var team := SocialHub.of(profile).team
	if not team.in_team() or team.is_captain() or team.captain == null:
		return
	for node in get_tree().get_nodes_in_group("followable"):
		if node != player and "display_name" in node and str(node.get("display_name")) == team.captain.name:
			_leader = node
			return

func _leader_far(s: AutoSettings) -> bool:
	return _leader != null and is_instance_valid(_leader) and (_leader is Node2D) \
			and _logic_dist(_leader) > float(s.follow_leader_dist)

# ------------------------------------------------------------------ tiện ích

func _usable(id: String) -> SkillDefinition:
	if id == "":
		return null
	var controller: SectSkillController = player.skill_controller
	var skill := controller.get_skill(id)
	return skill if skill != null and controller.is_skill_usable(skill) else null

func _busy() -> bool:
	return player.is_attacking or player.is_casting or not player.can_cast() or player.status_controller.is_stunned

func _target_alive(e: Variant) -> bool:
	if e == null or not is_instance_valid(e) or not (e is Node2D):
		return false
	var node := e as Node2D
	if node.is_queued_for_deletion() or not node.is_in_group("enemies"):
		return false
	return not (node.has_method("is_dead") and node.is_dead())

## Khoảng cách logic VLTK (dọc nhân đôi) — giống Player.get_nearest_enemy.
static func _logic_sq(d: Vector2) -> float:
	return d.x * d.x + d.y * d.y * 4.0

static func _logic_len(d: Vector2) -> float:
	return sqrt(_logic_sq(d))

func _logic_dist(e: Variant) -> float:
	if e == null or not is_instance_valid(e) or not (e is Node2D):
		return INF
	var node := e as Node2D
	return _logic_len(node.global_position - player.global_position)
