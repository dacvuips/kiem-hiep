extends Node

const AuraDatabase = preload("res://systems/auras/aura_database.gd")

## SINGLETON HỆ THỐNG GAME MASTER (GM MANAGER)
## Cung cấp toàn bộ API quản trị, phân quyền, can thiệp thế giới, điều khiển người chơi và boss.

signal gm_state_changed()
signal audit_log_added(entry: Dictionary)
signal possession_changed(is_possessing: bool, target_name: String)
signal profile_modified(target_profile: PlayerProfile)

## Trạng thái quyền năng của GM
var is_invisible: bool = false:
	set(v):
		is_invisible = v
		_apply_invisibility()
		gm_state_changed.emit()

var is_god_mode: bool = false:
	set(v):
		is_god_mode = v
		gm_state_changed.emit()

var is_noclip: bool = false:
	set(v):
		is_noclip = v
		gm_state_changed.emit()

var speed_mult: float = 1.0:
	set(v):
		speed_mult = maxf(0.5, v)
		gm_state_changed.emit()

## Vòng sáng GM & Ngoại hình GM (tương ứng HaloGM & ChangeMask trong source 15 phái)
var is_gm_halo: bool = false:
	set(v):
		is_gm_halo = v
		_apply_gm_halo()
		gm_state_changed.emit()

var is_gm_mask: bool = false:
	set(v):
		is_gm_mask = v
		_apply_gm_mask()
		gm_state_changed.emit()

## Danh sách địa danh dịch chuyển trọng yếu (khớp bản đồ Võ Lâm 15 phái)
const LOCATIONS := {
	"Ba Lăng Huyện": Vector2(0, 0),
	"Biện Kinh": Vector2(1000, 1000),
	"Lâm An": Vector2(-1000, 1000),
	"Tương Dương": Vector2(1000, -1000),
	"Phượng Tường": Vector2(-1000, -1000),
	"Đại Lý": Vector2(-500, 1500),
	"Thành Đô": Vector2(-1500, 500),
	"Dương Châu": Vector2(1500, 500),
	"Chiến Trường Tống Kim": Vector2(2500, 2500),
	"Đấu Trường PK": Vector2(3000, 3000),
	"Phong Lăng Độ": Vector2(2000, -2000),
}

## Bảng mã trang bị Hoàng Kim danh tiếng
const AN_BANG_INDICES := [215, 216, 217, 218]
const DINH_QUOC_INDICES := [152, 153, 154, 155, 156, 157]
const KIM_PHONG_ROWS := [176, 177, 178, 179, 180, 181, 182, 183, 184, 513]

## Cấu hình Boss thời gian thực
var boss_hp_mult: float = 1.0:
	set(v):
		boss_hp_mult = clampf(v, 0.1, 50.0)
		gm_state_changed.emit()

var boss_damage_mult: float = 1.0:
	set(v):
		boss_damage_mult = clampf(v, 0.1, 50.0)
		gm_state_changed.emit()

var boss_drop_mult: float = 1.0:
	set(v):
		boss_drop_mult = clampf(v, 1.0, 50.0)
		DropTable.item_rate_mult = boss_drop_mult
		gm_state_changed.emit()

## Quản lý boss đã triệu hồi
var spawned_bosses: Array[Node] = []

## Trạng thái chiếm quyền / điều khiển nhân vật khác
var original_profile: PlayerProfile = null
var possessed_profile: PlayerProfile = null
var is_possessing: bool = false

## Danh sách cấm ngôn / khóa nick cục bộ (đối với chế độ offline / local server)
var muted_players: Dictionary = {}   ## user_id/name -> unblock_timestamp
var banned_players: Dictionary = {}  ## user_id/name -> {until: timestamp, reason: String}

## Nhật ký thao tác GM (Audit Logs)
var audit_logs: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Kiểm tra người dùng hiện tại có quyền GM không
func is_gm() -> bool:
	return AccountApi.is_gm()

## Ghi nhận thao tác GM vào Audit Log
func log_action(action: String, target: String, detail: String = "") -> void:
	var entry := {
		"time": Time.get_datetime_string_from_system(),
		"gm": AccountApi.username() if AccountApi.is_logged_in() else "Admin_Local",
		"action": action,
		"target": target,
		"detail": detail
	}
	audit_logs.append(entry)
	audit_log_added.emit(entry)
	print("[GM AUDIT] [%s] GM '%s' thực hiện: %s -> Mục tiêu: '%s'. Chi tiết: %s" % [
		entry["time"], entry["gm"], action, target, detail
	])

# ==============================================================================
# 1. QUYỀN NĂNG BẢN THÂN GM
# ==============================================================================

func _apply_invisibility() -> void:
	var player := get_player_node()
	if player == null:
		return
	if is_invisible:
		player.modulate = Color(1.0, 1.0, 1.0, 0.4)
		_ensure_gm_badge(player, true)
	else:
		player.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_ensure_gm_badge(player, false)

func _ensure_gm_badge(player: Node2D, show_badge: bool) -> void:
	var badge := player.get_node_or_null("GmOverheadBadge") as Label
	if show_badge:
		if badge == null:
			badge = Label.new()
			badge.name = "GmOverheadBadge"
			badge.text = "★ [GM TÀNG HÌNH] ★"
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			badge.add_theme_color_override("font_outline_color", Color.BLACK)
			badge.add_theme_constant_override("outline_size", 4)
			badge.size = Vector2(160, 16)
			badge.position = Vector2(-80, -82)
			player.add_child(badge)
		badge.visible = true
	else:
		if badge != null:
			badge.visible = false

func _apply_gm_halo() -> void:
	var player := get_player_node()
	if player == null:
		return
	var halo := player.get_node_or_null("GmHaloTitle") as Label
	if is_gm_halo:
		if halo == null:
			halo = Label.new()
			halo.name = "GmHaloTitle"
			halo.text = "✦ BẬC THẦY VÕ LÂM (GM) ✦"
			halo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			halo.add_theme_font_size_override("font_size", 12)
			halo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.9)) # Màu tím hồng danh hiệu GM
			halo.add_theme_color_override("font_outline_color", Color.BLACK)
			halo.add_theme_constant_override("outline_size", 4)
			halo.size = Vector2(200, 20)
			halo.position = Vector2(-100, -100)
			player.add_child(halo)
		halo.visible = true
	else:
		if halo != null:
			halo.visible = false

func _apply_gm_mask() -> void:
	var player := get_player_node()
	if player == null:
		return
	if is_gm_mask:
		player.modulate = Color(1.2, 1.1, 0.85, 1.0) # Bạch y tôn quý
	else:
		if not is_invisible:
			player.modulate = Color(1.0, 1.0, 1.0, 1.0)

## Gán Hào Quang (Aura) cho bản thân hoặc cho người chơi khác
func set_player_aura(target_data: Dictionary, state_id: int) -> bool:
	var aura_info := AuraDatabase.get_by_state(state_id)
	var aura_name: String = str(aura_info.get("name", "State #%d" % state_id)) if state_id > 0 else "Không Có"
	var target_name: String = str(target_data.get("name", "Người chơi"))
	var is_self: bool = bool(target_data.get("is_self", false))

	# 1. Nếu là bản thân hoặc profile cục bộ
	if is_self or (target_data.get("profile") != null and target_data.get("profile") == GameManager.local_profile):
		var prof: PlayerProfile = target_data.get("profile") if target_data.has("profile") else GameManager.local_profile
		if prof == null:
			prof = GameManager.local_profile
		if prof != null:
			prof.gm_aura_state = state_id
			SaveManager.save_profile(prof)
			SaveManager.flush_online.call_deferred()
			profile_modified.emit(prof)
		var player := get_player_node()
		if player and player.has_method("set_gm_aura"):
			player.set_gm_aura(state_id)
		elif player and player.has_method("_refresh_aura_sprite"):
			player._refresh_aura_sprite()
		if NetClient.is_in_world():
			NetClient.send_chat(ChatServer.NEAR, "", "/aura %d" % state_id)
			if player and player.has_method("get_current_look"):
				NetClient.send_look(player.get_current_look())
			if prof != null:
				NetClient.send_profile(prof.to_dict())
		log_action("SET_AURA", "Bản Thân", "Gắn hào quang %s (ID %d)" % [aura_name, state_id])
		gm_state_changed.emit()
		return true

	# 2. Nếu là người chơi khác (RemotePlayer hoặc Bot)
	var remote: Node = target_data.get("remote_node")
	if remote == null and NetWorldSync.current != null:
		var tid: String = str(target_data.get("id", ""))
		if NetWorldSync.current._remotes.has(tid):
			remote = NetWorldSync.current._remotes[tid]

	if remote != null and is_instance_valid(remote):
		if remote.has_method("_refresh_aura_sprite"):
			remote._refresh_aura_sprite(state_id)
		if "_look" in remote and remote._look is Dictionary:
			remote._look["aura_state"] = state_id

	if target_data.has("profile") and target_data["profile"] is PlayerProfile:
		var prof: PlayerProfile = target_data["profile"]
		prof.gm_aura_state = state_id
		SaveManager.save_profile(prof)
		profile_modified.emit(prof)

	if NetClient.is_in_world() and target_name != "":
		NetClient.send_chat(ChatServer.NEAR, "", "/aura %d %s" % [state_id, target_name])

	log_action("SET_AURA", target_name, "Gắn hào quang %s (ID %d) cho %s" % [aura_name, state_id, target_name])
	gm_state_changed.emit()
	return true

func clear_player_aura(target_data: Dictionary) -> bool:
	return set_player_aura(target_data, 0)

## Đổi trạng thái PK / Phe (theo hàm GMChangeCamp của source 15 phái: 0: Luyện công, 1: Chính, 2: Tà, 3: Trung lập, 4: Sát thủ, 6: GM)
func change_player_camp(target_profile: PlayerProfile, camp_type: int) -> void:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return
	target_profile.camp = camp_type
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	var player := get_player_node()
	if player and player.has_method("refresh_appearance"):
		player.refresh_appearance()
	var camp_name := Camp.get_camp_name(camp_type)
	log_action("CHANGE_CAMP", target_profile.display_name, "Đổi sang phe/màu PK: %s (Camp %d)" % [camp_name, camp_type])
	profile_modified.emit(target_profile)
	gm_state_changed.emit()

## Học full kỹ năng môn phái hiện tại (theo hàm HocKyNangMonPhai / AddSkills của source 15 phái)
func learn_all_sect_skills(target_profile: PlayerProfile) -> int:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return 0
	var sect := SectRegistry.get_by_id(target_profile.sect_id)
	if sect == null:
		return 0
	var count := 0
	for skill in sect.skills:
		target_profile.skill_levels[skill.id] = skill.max_level
		count += 1
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	var player := get_player_node()
	if player and player.has_method("refresh_combat_stats"):
		player.refresh_combat_stats()
	log_action("LEARN_SECT_SKILLS", target_profile.display_name, "Lĩnh hội full %d tuyệt kỹ môn phái %s" % [count, sect.sect_name])
	profile_modified.emit(target_profile)
	return count

## Tẩy tủy nhanh toàn bộ điểm tiềm năng và kỹ năng (theo TayTuyNhanh gốc 15 phái)
func reset_skills_and_stats(target_profile: PlayerProfile) -> Dictionary:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return {}
	var res: Dictionary = target_profile.refund_all_points()
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	var player := get_player_node()
	if player and player.has_method("refresh_combat_stats"):
		player.refresh_combat_stats()
	log_action("RESET_POINTS", target_profile.display_name, "Tẩy tủy toàn bộ điểm tiềm năng và kỹ năng")
	profile_modified.emit(target_profile)
	return res

## Tặng điểm tiềm năng & kỹ năng tự do (theo pointtiemnang & pointkynang gốc 15 phái)
func add_free_points(target_profile: PlayerProfile, potential_pts: int, skill_pts: int) -> void:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return
	target_profile.potential_points = maxi(0, target_profile.potential_points + potential_pts)
	target_profile.skill_points = maxi(0, target_profile.skill_points + skill_pts)
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	log_action("ADD_POINTS", target_profile.display_name, "Cộng +%d điểm tiềm năng, +%d điểm kỹ năng" % [potential_pts, skill_pts])
	profile_modified.emit(target_profile)

## Tự tăng điểm tiềm năng theo số nhập vào (hỗ trợ nhập số tự do từ GM)
func add_potential_points(target_profile: PlayerProfile, points: int) -> void:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null or points == 0:
		return
	target_profile.potential_points = maxi(0, target_profile.potential_points + points)
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	log_action("ADD_POTENTIAL", target_profile.display_name, "Cộng %+d điểm tiềm năng tự do (Hiện có: %d)" % [points, target_profile.potential_points])
	profile_modified.emit(target_profile)

## Tự tăng trực tiếp vào 1 thuộc tính theo số nhập (Sức mạnh / Thân pháp / Sinh khí / Nội công)
func add_single_stat(target_profile: PlayerProfile, stat_type: String, points: int) -> void:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null or points == 0:
		return
	var stat_name := ""
	match stat_type.to_lower():
		"str", "strength", "suc_manh":
			target_profile.strength += points
			stat_name = "Sức mạnh"
		"dex", "dexterity", "than_phap":
			target_profile.dexterity += points
			stat_name = "Thân pháp"
		"vit", "vitality", "sinh_khi":
			target_profile.vitality += points
			stat_name = "Sinh khí"
		"eng", "energy", "noi_cong":
			target_profile.energy += points
			stat_name = "Nội công"
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	var player := get_player_node()
	if player and player.has_method("refresh_combat_stats"):
		player.refresh_combat_stats()
	log_action("ADD_STAT", target_profile.display_name, "Cộng %+d điểm %s" % [points, stat_name])
	profile_modified.emit(target_profile)

## Hồi phục 100% Sinh lực, Nội lực, Thể lực cho bản thân
func restore_self_full() -> void:
	var player := get_player_node()
	if player:
		if player.get("combat_stats"):
			player.health = float(player.combat_stats.max_hp)
			if "mana" in player:
				player.mana = float(player.combat_stats.max_mana)
		else:
			player.health = player.max_health
			if "mana" in player and "max_mana" in player:
				player.mana = player.max_mana
		if player.has_signal("health_changed"):
			player.health_changed.emit(player.health, player.max_health if player.get("max_health") else (float(player.combat_stats.max_hp) if player.get("combat_stats") else 100.0))
		if player.has_signal("mana_changed"):
			player.mana_changed.emit(player.mana, player.max_mana if player.get("max_mana") else (float(player.combat_stats.max_mana) if player.get("combat_stats") else 100.0))
	var p := GameManager.local_profile
	if p:
		p.stamina = p.max_stamina
		profile_modified.emit(p)
	log_action("RESTORE_SELF", "Bản thân", "Hồi phục toàn bộ HP/MP/SP")

## Cộng chỉ số trực tiếp cho nhân vật đang chọn hoặc bản thân
func adjust_stats(target_profile: PlayerProfile, str_add: int, dex_add: int, vit_add: int, eng_add: int) -> void:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return
	target_profile.strength += str_add
	target_profile.dexterity += dex_add
	target_profile.vitality += vit_add
	target_profile.energy += eng_add
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	var player := get_player_node()
	if player and player.has_method("refresh_combat_stats"):
		player.refresh_combat_stats()
	log_action("ADJUST_STATS", target_profile.display_name, "Sức mạnh: %+d, Thân pháp: %+d, Sinh khí: %+d, Nội công: %+d" % [
		str_add, dex_add, vit_add, eng_add
	])
	profile_modified.emit(target_profile)

## Đặt cấp độ nhân vật
func set_player_level(target_profile: PlayerProfile, target_level: int) -> void:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return
	var old_lv := target_profile.level
	target_profile.level = clampi(target_level, 1, 200)
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	var player := get_player_node()
	if player and player.get("refresh_appearance"):
		player.refresh_appearance()
	if player and player.has_method("refresh_combat_stats"):
		player.refresh_combat_stats()
	log_action("SET_LEVEL", target_profile.display_name, "Cấp cũ: %d -> Cấp mới: %d" % [old_lv, target_level])
	profile_modified.emit(target_profile)

# ==============================================================================
# 2. QUẢN TRỊ NGƯỜI CHƠI & TÌM KIẾM
# ==============================================================================

## Lấy node nhân vật người chơi chính
func get_player_node() -> CharacterBody2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as CharacterBody2D

func _sect_name(sect_id: String) -> String:
	if sect_id == "":
		return "Vô môn phái"
	var s := SectRegistry.get_by_id(sect_id)
	return s.sect_name if s else "Vô môn phái"

## Danh sách người chơi online / giả lập đang có
func get_player_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var local_p := GameManager.local_profile
	if local_p:
		var acc_id: String = str(AccountApi.account.get("id", "LOCAL_01"))
		list.append({
			"id": acc_id if acc_id != "" else "LOCAL_01",
			"name": local_p.display_name,
			"level": local_p.level,
			"sect": _sect_name(local_p.sect_id),
			"camp": local_p.get_current_camp(),
			"map": VltkWorld.current.map_dir.get_file() if VltkWorld.current else "Ba Lăng Huyện",
			"pos": get_player_node().global_position if get_player_node() else Vector2.ZERO,
			"is_self": true,
			"profile": local_p
		})

	## Nếu có danh sách người chơi từ server
	if NetClient.is_in_world() and NetWorldSync.current != null:
		for r in NetWorldSync.current._remotes.values():
			if not is_instance_valid(r):
				continue
			if local_p and r.display_name == local_p.display_name:
				continue
			list.append({
				"id": str(r.eid),
				"name": r.display_name,
				"level": r.level,
				"sect": "Võ Lâm Cao Thủ",
				"camp": r.camp,
				"map": VltkWorld.current.map_dir.get_file() if VltkWorld.current else "Map chung",
				"pos": r.global_position,
				"is_self": false,
				"profile": null,
				"remote_node": r
			})
	elif local_p != null:
		## Chế độ offline: lấy danh sách người chơi giả lập từ SocialDirectory
		for m in SocialDirectory.players(local_p):
			list.append({
				"id": "BOT_%s" % m.name,
				"name": m.name,
				"level": m.level,
				"sect": _sect_name(m.sect_id),
				"camp": m.camp,
				"map": "Ba Lăng Huyện",
				"pos": Vector2(200, 200),
				"is_self": false,
				"profile": null
			})
	return list

## Tìm kiếm người chơi theo Tên hoặc ID
func search_players(keyword: String) -> Array[Dictionary]:
	var q := keyword.strip_edges().to_lower()
	var all_players := get_player_list()
	if q == "":
		return all_players
	var result: Array[Dictionary] = []
	for p in all_players:
		if q in str(p["name"]).to_lower() or q in str(p["id"]).to_lower():
			result.append(p)
	return result

## Kích kẹt nhân vật về thành Ba Lăng Huyện
func kick_stuck(player_info: Dictionary) -> void:
	var name_target: String = player_info.get("name", "Người chơi")
	if player_info.get("is_self", false):
		var p_node := get_player_node()
		if p_node:
			p_node.global_position = Vector2(0, 0)
			if p_node.get("status_controller"):
				p_node.status_controller.clear_all_effects()
		log_action("KICK_STUCK", name_target, "Giải phóng kẹt map, đưa về tọa độ an toàn (0, 0)")
	else:
		if NetClient.is_in_world():
			NetClient.send_chat(ChatServer.WORLD, "", "/gm kick_stuck %s" % player_info.get("id", name_target))
		log_action("KICK_STUCK", name_target, "Gửi lệnh giải cứu kích kẹt người chơi")

## Dịch chuyển người chơi tới tọa độ chỉ định
func teleport_player(player_info: Dictionary, target_pos: Vector2) -> void:
	var name_target: String = player_info.get("name", "Người chơi")
	if player_info.get("is_self", false):
		var p_node := get_player_node()
		if p_node:
			p_node.global_position = target_pos
		log_action("TELEPORT", name_target, "Dịch chuyển tới tọa độ (%d, %d)" % [roundi(target_pos.x), roundi(target_pos.y)])
	else:
		if NetClient.is_in_world():
			NetClient.send_chat(ChatServer.WORLD, "", "/gm teleport %s %d %d" % [player_info.get("id", name_target), int(target_pos.x), int(target_pos.y)])
		log_action("TELEPORT", name_target, "Dịch chuyển người chơi tới (%d, %d)" % [roundi(target_pos.x), roundi(target_pos.y)])

## Dịch chuyển đến địa danh trọng yếu theo tên (khớp GM_dichuyen gốc 15 phái)
func teleport_to_location(player_info: Dictionary, loc_name: String) -> void:
	if not LOCATIONS.has(loc_name):
		return
	var pos: Vector2 = LOCATIONS[loc_name]
	teleport_player(player_info, pos)
	log_action("TELEPORT_LOC", player_info.get("name", "Người chơi"), "Dịch chuyển tức thời đến '%s' (%d, %d)" % [
		loc_name, roundi(pos.x), roundi(pos.y)
	])

## Dịch chuyển GM tới vị trí người chơi
func goto_player(player_info: Dictionary) -> void:
	var p_node := get_player_node()
	if p_node and player_info.has("pos"):
		p_node.global_position = player_info["pos"]
		log_action("GOTO_PLAYER", player_info.get("name", ""), "GM bay đến cạnh mục tiêu tại (%d, %d)" % [
			roundi(player_info["pos"].x), roundi(player_info["pos"].y)
		])

## Kéo người chơi về vị trí GM
func summon_player(player_info: Dictionary) -> void:
	var p_node := get_player_node()
	if p_node == null:
		return
	var gm_pos := p_node.global_position
	teleport_player(player_info, gm_pos)
	log_action("SUMMON_PLAYER", player_info.get("name", ""), "Kéo người chơi tới vị trí GM (%d, %d)" % [
		roundi(gm_pos.x), roundi(gm_pos.y)
	])

## Dịch chuyển HÀNG LOẠT toàn bộ người chơi về 1 điểm sự kiện
func teleport_all_players(target_pos: Vector2, current_map_only: bool = true) -> void:
	var p_node := get_player_node()
	if p_node:
		p_node.global_position = target_pos
	if NetClient.is_in_world():
		NetClient.send_chat(ChatServer.WORLD, "", "/gm teleport_all %d %d %s" % [
			int(target_pos.x), int(target_pos.y), "map" if current_map_only else "all"
		])
	log_action("MASS_TELEPORT", "TẤT CẢ NGƯỜI CHƠI", "Kéo toàn bộ người chơi (%s) về tọa độ (%d, %d)" % [
		"Chỉ map hiện tại" if current_map_only else "Toàn Server",
		roundi(target_pos.x), roundi(target_pos.y)
	])

## Đổi tên nhân vật
func rename_player(player_info: Dictionary, new_name: String) -> void:
	var clean_name := new_name.strip_edges()
	if clean_name == "":
		return
	var old_name: String = player_info.get("name", "")
	var p: PlayerProfile = player_info.get("profile") if player_info.get("profile") else (GameManager.local_profile if player_info.get("is_self", false) else null)
	if p:
		p.display_name = clean_name
		SaveManager.save_profile(p)
		SaveManager.flush_online.call_deferred()
		profile_modified.emit(p)
		var p_node := get_player_node()
		if p_node and p_node.has_node("Label"):
			(p_node.get_node("Label") as Label).text = clean_name
	log_action("RENAME_PLAYER", old_name, "Đổi tên thành: '%s'" % clean_name)

## Khóa tài khoản
func ban_player(player_info: Dictionary, duration_hours: int, reason: String) -> void:
	var id_target: String = player_info.get("id", player_info.get("name", ""))
	var until_time := Time.get_unix_time_from_system() + duration_hours * 3600
	banned_players[id_target] = {"until": until_time, "reason": reason}
	log_action("BAN_PLAYER", player_info.get("name", ""), "Khóa %d giờ. Lý do: %s" % [duration_hours, reason])

## Cấm ngôn / Khóa chat
func mute_player(player_info: Dictionary, duration_minutes: int, reason: String) -> void:
	var id_target: String = player_info.get("id", player_info.get("name", ""))
	var until_time := Time.get_unix_time_from_system() + duration_minutes * 60
	muted_players[id_target] = until_time
	log_action("MUTE_PLAYER", player_info.get("name", ""), "Cấm chat %d phút. Lý do: %s" % [duration_minutes, reason])

## Kích đăng xuất cưỡng chế
func kick_player(player_info: Dictionary) -> void:
	var name_target: String = player_info.get("name", "")
	log_action("KICK_PLAYER", name_target, "Kích đăng xuất cưỡng chế khỏi máy chủ")

## Mở khóa rương bảo vệ khẩn cấp
func unlock_security_storage(target_profile: PlayerProfile) -> void:
	if target_profile:
		target_profile.security_hash = ""
		target_profile.security_locked = false
		SaveManager.save_profile(target_profile)
		SaveManager.flush_online.call_deferred()
		log_action("UNLOCK_STORAGE", target_profile.display_name, "Đã xóa mật mã rương bảo vệ khẩn cấp")
		profile_modified.emit(target_profile)

# ==============================================================================
# 3. CẤP ĐỒ, TIỀN & VẬT PHẨM
# ==============================================================================

## Cấp Tiền, Tiền Xu, KNB, Danh Vọng, Phúc Duyên
func give_resources(target_profile: PlayerProfile, gold: int, knb: int, repute: int, fuyuan: int, xu: int = 0) -> void:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return
	if gold != 0:
		target_profile.gold = maxi(0, target_profile.gold + gold)
	if knb != 0:
		target_profile.jade = maxi(0, target_profile.jade + knb)
	if xu != 0:
		target_profile.xu = maxi(0, target_profile.xu + xu)
	if repute != 0:
		target_profile.prestige = maxi(0, target_profile.prestige + repute)
	if fuyuan != 0:
		target_profile.fuyuan = maxi(0, target_profile.fuyuan + fuyuan)
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	log_action("GIVE_RESOURCES", target_profile.display_name, "Tiền: %+d, Xu: %+d, KNB: %+d, Danh vọng: %+d, Phúc duyên: %+d" % [
		gold, xu, knb, repute, fuyuan
	])
	profile_modified.emit(target_profile)

## Cấp vật phẩm trực tiếp vào hành trang
func give_item(target_profile: PlayerProfile, item: ItemInstance) -> bool:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null or item == null:
		return false
	var ok: bool = target_profile.add_item(item)
	if ok:
		SaveManager.save_profile(target_profile)
		SaveManager.flush_online.call_deferred()
		log_action("GIVE_ITEM", target_profile.display_name, "Cấp vật phẩm: %s" % item.get_display_name())
		profile_modified.emit(target_profile)
	return ok

## Tự suy nhóm đồ Hoàng Kim Môn Phái theo mã môn phái (chuẩn 15 phái VLTK)
func _get_default_gold_group_for_sect(sect_id: String) -> int:
	match sect_id:
		"shaolin": return 1    # Thiếu Lâm Mộng Long
		"tianwang": return 4   # Thiên Vương Hám Thiên
		"tangmen": return 12   # Đường Môn U Lung
		"wudu": return 25      # Ngũ Độc U Minh
		"emei": return 7       # Nga My Vô Gian
		"cuiyan": return 10    # Thúy Yên Tê Hoàng
		"gaibang": return 18   # Cái Bang Địch Khái
		"tianren": return 22   # Thiên Nhẫn Ma Viêm
		"wudang": return 29    # Võ Đang Lăng Nhược
		"kunlun": return 32    # Côn Lôn Sương Tinh
		"huashan": return 35   # Hoa Sơn
		"xiaoyao": return 38   # Tiêu Dao
		"mingjiao": return 40  # Minh Giáo
		_: return 1

## Cấp trọn bộ Trang Bị Hoàng Kim Môn Phái hoàn mỹ (tương ứng LayMenuHKMP của 15 phái)
func give_hkmp_set(target_profile: PlayerProfile, group_id: int = 0) -> int:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return 0
	var gid := group_id
	if gid <= 0:
		gid = _get_default_gold_group_for_sect(target_profile.sect_id)
	var members: Array[int] = ItemDatabase.get_gold_set_members(gid)
	if members.is_empty():
		members = ItemDatabase.get_gold_set_members(1)
	var count := 0
	for idx in members:
		var item := ItemGenerator.generate_gold(idx, 10)
		if item and target_profile.add_item(item):
			count += 1
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	log_action("GIVE_HKMP_SET", target_profile.display_name, "Cấp bộ Trang Bị Hoàng Kim Môn Phái (Nhóm %d, %d món)" % [gid, count])
	profile_modified.emit(target_profile)
	return count

## Cấp trọn bộ Hoàng Kim An Bang (Dây chuyền, Bội, 2 Nhẫn)
func give_an_bang_set(target_profile: PlayerProfile) -> int:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return 0
	var count := 0
	for idx in AN_BANG_INDICES:
		var it := ItemGenerator.generate_gold(idx, 10)
		if it and target_profile.add_item(it):
			count += 1
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	log_action("GIVE_SET", target_profile.display_name, "Cấp trọn bộ Hoàng Kim An Bang (%d món)" % count)
	profile_modified.emit(target_profile)
	return count

## Cấp trọn bộ Hoàng Kim Định Quốc (Mão, Áo, Đai, Hộ uyển, Giày, Ban chỉ)
func give_dinh_quoc_set(target_profile: PlayerProfile) -> int:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return 0
	var count := 0
	for idx in DINH_QUOC_INDICES:
		var it := ItemGenerator.generate_gold(idx, 10)
		if it and target_profile.add_item(it):
			count += 1
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	log_action("GIVE_SET", target_profile.display_name, "Cấp trọn bộ Hoàng Kim Định Quốc (%d món)" % count)
	profile_modified.emit(target_profile)
	return count

## Cấp trọn bộ Kim Phong (9 món Kim Phong + Thuần Tịnh Chi Giới)
func give_kim_phong_set(target_profile: PlayerProfile) -> int:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return 0
	var count := 0
	for row in KIM_PHONG_ROWS:
		var idx := ItemDatabase.gold_index_of_row(row)
		if idx >= 0:
			var it := ItemGenerator.generate_gold(idx, 10)
			if it and target_profile.add_item(it):
				count += 1
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	log_action("GIVE_SET", target_profile.display_name, "Cấp trọn bộ Kim Phong (%d món)" % count)
	profile_modified.emit(target_profile)
	return count

## Cấp thần mã VIP (tương ứng LayMenuNgua gốc 15 phái: Phiên Vũ, Bôn Tiêu, Chiếu Dạ, Xích Thố)
func give_horse_vip(target_profile: PlayerProfile, horse_name: String = "Phiên Vũ") -> bool:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return false
	var particular := 7 # Phiên Vũ (particular = 7, level = 10)
	if horse_name == "Bôn Tiêu":
		particular = 6
	elif horse_name == "Chiếu Dạ" or horse_name == "Xích Thố":
		particular = 5
	var horse_item := ItemGenerator.generate(ItemDatabase.Detail.HORSE, particular, 10, target_profile.get_element(), [])
	if horse_item and target_profile.add_item(horse_item):
		SaveManager.save_profile(target_profile)
		SaveManager.flush_online.call_deferred()
		log_action("GIVE_HORSE", target_profile.display_name, "Cấp chiến mã VIP: %s" % horse_name)
		profile_modified.emit(target_profile)
		return true
	return false

## Cấp trọn gói Thủy Tinh, Tinh Hồng Bảo Thạch, Phúc Duyên & Huyền Tinh Cấp 10
func give_gem_pack(target_profile: PlayerProfile) -> int:
	if target_profile == null:
		target_profile = GameManager.local_profile
	if target_profile == null:
		return 0
	var count := 0
	for code in ["4_238_1", "4_239_1", "4_240_1"]: # Lam, Tử, Lục Thủy Tinh
		for i in 2:
			var it := ItemGenerator.generate_misc(code)
			if it and target_profile.add_item(it): count += 1
	for i in 2: # Tinh Hồng Bảo Thạch
		var it := ItemGenerator.generate_misc("4_353_1")
		if it and target_profile.add_item(it): count += 1
	for i in 5: # Phúc Duyên Lộ (Đại)
		var it := ItemGenerator.generate_misc("6_1_124")
		if it and target_profile.add_item(it): count += 1
	for i in 3: # Huyền Tinh Cấp 10
		var it := ItemGenerator.generate_misc(Compound.XUANJING, 10, 0, 1)
		if it and target_profile.add_item(it): count += 1
	SaveManager.save_profile(target_profile)
	SaveManager.flush_online.call_deferred()
	log_action("GIVE_GEMS", target_profile.display_name, "Cấp gói Nguyên Liệu Chế Tạo & Thủy Tinh (%d món)" % count)
	profile_modified.emit(target_profile)
	return count

# ==============================================================================
# 4. QUẢN LÝ BOSS, TỈ LỆ RƠI ĐỒ & THẢ BOSS
# ==============================================================================

## Triệu hồi một Boss tại tọa độ chỉ định
func spawn_boss(boss_name: String, boss_res: String, series: int, level: int, boss_type: String, pos: Vector2) -> VltkMonster:
	var data := {
		"name": boss_name,
		"res": boss_res if boss_res != "" else "boss001",
		"series": series,
		"level": level,
		"is_boss": true,
		"boss_type": boss_type,
		"ai_type": "boss",
		"exp": level * 1000
	}
	var monster := VltkMonster.new()
	monster.monster_id = 9999
	monster.data = data
	monster.level = level
	monster.global_position = pos
	## Áp dụng chỉnh sửa Max HP của GM
	if monster.get("combat_stats"):
		monster.combat_stats.max_hp = int(monster.combat_stats.max_hp * boss_hp_mult)
		monster.max_health = float(monster.combat_stats.max_hp)
		monster.health = monster.max_health
	var parent := VltkWorld.entity_parent()
	if parent:
		parent.add_child(monster)
	spawned_bosses.append(monster)
	log_action("SPAWN_BOSS", boss_name, "Triệu hồi Boss cấp %d tại (%d, %d). Máu x%.1f, Dame x%.1f" % [
		level, roundi(pos.x), roundi(pos.y), boss_hp_mult, boss_damage_mult
	])
	return monster

## Dọn sạch toàn bộ boss do GM triệu hồi
func clear_spawned_bosses() -> void:
	var count := 0
	for m in spawned_bosses:
		if is_instance_valid(m):
			m.queue_free()
			count += 1
	spawned_bosses.clear()
	log_action("CLEAR_BOSSES", "Toàn Map", "Dọn sạch %d Boss đã triệu hồi" % count)

## Tìm và định vị các Boss đang hoạt động trên map (khớp tính năng GMHelp / findgoldboss gốc 15 phái)
func find_bosses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return result
	var gm_pos := Vector2.ZERO
	var p_node := get_player_node()
	if p_node:
		gm_pos = p_node.global_position

	for node in tree.get_nodes_in_group("monsters"):
		if node is VltkMonster:
			var is_b: bool = node.gold_boss or node.small_gold_boss or bool(node.data.get("is_boss", false))
			if is_b:
				var b_pos: Vector2 = node.global_position
				result.append({
					"name": str(node.data.get("name", "Boss")),
					"level": node.level,
					"pos": b_pos,
					"dist": gm_pos.distance_to(b_pos),
					"hp": node.health,
					"max_hp": node.max_health,
					"node": node
				})
	for b in spawned_bosses:
		if is_instance_valid(b) and b is VltkMonster:
			var already := false
			for r in result:
				if r.get("node") == b:
					already = true
					break
			if not already:
				var b_pos: Vector2 = b.global_position
				result.append({
					"name": str(b.data.get("name", "Boss GM")),
					"level": b.level,
					"pos": b_pos,
					"dist": gm_pos.distance_to(b_pos),
					"hp": b.health,
					"max_hp": b.max_health,
					"node": b
				})
	log_action("FIND_BOSSES", "Toàn Map", "Quét tìm thấy %d Boss đang hoạt động" % result.size())
	return result

# ==============================================================================
# 5. CHIẾM QUYỀN / ĐIỀU KHIỂN NHÂN VẬT KHÁC (IMPERSONATE)
# ==============================================================================

## Tiếp quản và điều khiển một nhân vật khác theo ID / Profile
func possess_player(target_profile: PlayerProfile) -> bool:
	if target_profile == null or is_possessing:
		return false
	original_profile = GameManager.local_profile
	possessed_profile = target_profile
	GameManager.local_profile = possessed_profile
	is_possessing = true
	var player_node := get_player_node()
	if player_node:
		if player_node.get("refresh_appearance"):
			player_node.refresh_appearance()
		if player_node.get("refresh_combat_stats"):
			player_node.refresh_combat_stats()
	possession_changed.emit(true, possessed_profile.display_name)
	profile_modified.emit(possessed_profile)
	log_action("POSSESS_PLAYER", possessed_profile.display_name, "GM chiếm quyền điều khiển trực tiếp nhân vật")
	return true

## Trả lại quyền kiểm soát nhân vật ban đầu cho GM
func release_possession() -> void:
	if not is_possessing or original_profile == null:
		return
	var target_name := possessed_profile.display_name if possessed_profile else ""
	var orig_p := original_profile
	GameManager.local_profile = original_profile
	possessed_profile = null
	original_profile = null
	is_possessing = false
	var player_node := get_player_node()
	if player_node:
		if player_node.get("refresh_appearance"):
			player_node.refresh_appearance()
		if player_node.get("refresh_combat_stats"):
			player_node.refresh_combat_stats()
	possession_changed.emit(false, "")
	profile_modified.emit(orig_p)
	log_action("RELEASE_POSSESSION", target_name, "GM hoàn trả quyền điều khiển về nhân vật gốc")

# ==============================================================================
# 6. THÔNG BÁO & SỰ KIỆN TOÀN SERVER
# ==============================================================================

## Phát thông báo toàn server (chạy chữ vàng Marquee)
func broadcast_announcement(text: String) -> void:
	if text.strip_edges() == "":
		return
	if NetClient.is_in_world():
		NetClient.send_chat(ChatServer.WORLD, "", "[HỆ THỐNG GM]: %s" % text)
	log_action("BROADCAST", "Toàn Server", text)

## Lưu toàn bộ dữ liệu & Kick an toàn chống Rollback (tương ứng kickroll / kickall của GM 15 phái)
func kick_all_save_data() -> void:
	if GameManager.local_profile:
		SaveManager.save_profile(GameManager.local_profile)
	SaveManager.flush_online()
	if NetClient.is_in_world():
		NetClient.send_chat(ChatServer.WORLD, "", "[HỆ THỐNG]: GM đã lưu toàn bộ tiến trình người chơi và kích hoạt bảo trì.")
	log_action("KICK_ALL_SAVE", "Toàn Server", "Đã lưu toàn bộ tiến trình nhân vật & kích hoạt bảo vệ chống Rollback")
