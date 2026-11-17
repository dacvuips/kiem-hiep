class_name SurvivorManager
extends RefCounted
## BỘ ĐIỀU HÀNH CHẾ ĐỘ OFFLINE – VƯỢT ẢI LUYỆN CÔNG (SURVIVOR ACTION)
##
## Quản lý toàn bộ cơ chế đặc tả theo GDD:
## - Nhóm tối đa 6 kỹ năng môn phái xuất hiện trong lượt chơi (Mục 5.2)
## - Cơ chế nâng cấp kỹ năng theo sao từ 1⭐ đến 5⭐ (Mục 5.3)
## - Công thức nhân số lượng chiêu thức phóng ra theo sao: N = N_gốc * Sao (Mục 5.4)
## - Đánh giá thành tích 3 sao theo Thời gian, Điểm số, Số quái hạ gục (Mục 4)
##
## Tách biệt hoàn toàn khỏi chế độ Online MMORPG.

const MAX_SURVIVOR_SKILLS := 15
const MAX_SKILL_STARS := 5

## Dữ liệu lượt chơi hiện tại
static var current_sect_id: String = ""
static var pool_skills: Array[SkillDefinition] = []
static var active_skills: Dictionary = {} # skill_id (String) -> star_level (int 1..5)
static var enemies_killed: int = 0
static var current_score: int = 0

## Signal thông báo cập nhật
static var skills_updated: Callable

## Khởi tạo toàn bộ kỹ năng tấn công gây dame từ 1x đến 15x cho môn phái, lọc đúng theo vũ khí đang trang bị
static func init_pool(sect_id: String, weapon_class: int = -1) -> void:
	current_sect_id = sect_id
	pool_skills.clear()
	active_skills.clear()
	enemies_killed = 0
	current_score = 0
	SurvivorPerks.reset()
	
	var sect_def := SectRegistry.get_by_id(sect_id)
	if sect_def == null:
		push_warning("SurvivorManager: Không tìm thấy môn phái %s" % sect_id)
		return

	var matching_skills: Array[SkillDefinition] = []
	for sk in sect_def.skills:
		if sk == null or sk.is_hidden or sk.is_basic_attack:
			continue

		# 1. ẨN TẤT CẢ SKILL HỖ TRỢ, CHỈ GIỮ LẠI CÁC SKILL ĐÁNH GÂY DAME
		if sk.is_aura or sk.category != SkillDefinition.SkillCategory.ACTIVE or SectSkillController.is_self_buff(sk):
			continue
		var is_attack: bool = sk.target_enemy or sk.is_main_attack or sk.base_damage > 0.0 or not sk.damage_types.is_empty()
		if not is_attack:
			continue

		# 2. LỌC ĐÚNG VŨ KHÍ NHÂN VẬT ĐANG CẦM (ví dụ Cái Bang không cầm bổng thì tuyệt đối không ra skill bổng)
		# sk.weapon_limit: -2 là không hạn chế; nếu != -2 thì bắt buộc phải đúng weapon_class
		if sk.weapon_limit != -2 and sk.weapon_limit != weapon_class:
			continue

		matching_skills.append(sk)

	# Hiển thị hết toàn bộ các skill đánh từ 1x đến 15x tương thích với vũ khí đang cầm
	pool_skills = matching_skills

	# Đồng bộ sang PlayerStats
	var pool_ids: Array[String] = []
	for s in pool_skills:
		pool_ids.append(s.id)
	PlayerStats.survivor_pool = pool_ids
	PlayerStats.survivor_sect_id = sect_id
	
	print("SurvivorManager: Đã nạp %d kỹ năng đánh môn phái [%s] (vũ khí %d) vào danh sách Vượt Ải" % [pool_skills.size(), sect_id, weapon_class])

## Lấy cấp sao hiện tại của kỹ năng (0 nếu chưa học)
static func get_skill_star(skill_id: String) -> int:
	if not GameModeManager.is_offline() or (GameManager.game_mode != GameManager.GameMode.STAGE and not GameManager.field_map.get("survivor_mode", false)):
		return 1
	return int(active_skills.get(skill_id, 0))

## Học kỹ năng mới (1 sao) hoặc nâng thêm 1 sao (tối đa 5 sao)
static func add_or_upgrade_skill(skill_id: String) -> int:
	var cur: int = int(active_skills.get(skill_id, 0))
	if cur >= MAX_SKILL_STARS:
		return cur
	if cur == 0 and active_skills.size() >= MAX_SURVIVOR_SKILLS:
		return 0 # Đã đạt trần số lượng kỹ năng
	
	var next_star := cur + 1
	active_skills[skill_id] = next_star
	
	# Đồng bộ sang PlayerStats để tương thích ngược
	PlayerStats.survivor_skills[skill_id] = next_star
	PlayerStats.survivor_skills_changed.emit(PlayerStats.survivor_skills)
	
	if skills_updated.is_valid():
		skills_updated.call()
	return next_star

## Kiểm tra kỹ năng đã đạt trần 5 sao chưa
static func is_skill_maxed(skill_id: String) -> bool:
	return int(active_skills.get(skill_id, 0)) >= MAX_SKILL_STARS

## Tính số chiêu thức phóng thêm theo công thức GDD: N_tổng = N_gốc * Sao
static func get_extra_projectiles(skill_id: String, base_num: int = 1) -> int:
	var star := get_skill_star(skill_id)
	if star <= 1:
		return 0
	return base_num * (star - 1)

## Ghi nhận tiêu diệt quái và cộng điểm
static func add_kill(score_gain: int = 10) -> void:
	enemies_killed += 1
	current_score += score_gain
	PlayerStats.enemies_killed = enemies_killed
	PlayerStats.current_score = current_score

## Reset toàn bộ trạng thái Survivor khi kết thúc trận hoặc chuyển chế độ
static func reset() -> void:
	current_sect_id = ""
	pool_skills.clear()
	active_skills.clear()
	enemies_killed = 0
	current_score = 0
	SurvivorPerks.reset()
