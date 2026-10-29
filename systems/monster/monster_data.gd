extends RefCounted
class_name MonsterData
## Dữ liệu quái VLTK gốc do tools/import_vltk_monsters.py xuất (data/monsters/*.json + assets/monster/*.png).
## Chỉ đọc, dùng chung mọi quái/người chơi (state runtime nằm trên VltkMonster, không ở đây).

const DATA_DIR := "res://data/monsters/"
const PNG_DIR := "res://assets/monster/"
## Bản online: ảnh tải theo nhu cầu lưu ở đây, được ưu tiên trước ảnh đóng gói (giống AvatarData/VltkSkillData).
const USER_CACHE_DIR := "user://monster/"

## Động tác logic -> thứ tự các động tác trong bộ tài nguyên để lấy (bộ nào thiếu động tác thì dùng cái gần nhất,
## giống KNpcRes gốc: ô trống trong bảng tài nguyên = dùng lại ảnh khác).
const FALLBACK := {
	"stand": ["fight_stand", "stand1", "stand2"],
	"walk": ["fight_walk", "walk", "fight_run", "run"],
	"run": ["fight_run", "run", "fight_walk", "walk"],
	"hurt": ["hurt", "fight_stand"],
	"die": ["die", "hurt", "fight_stand"],
	"attack1": ["attack1", "attack2", "magic"],
	"attack2": ["attack2", "attack1", "magic"],
	"magic": ["magic", "attack1", "attack2"],
}

static var _monsters: Dictionary = {}
static var _resources: Dictionary = {}
static var _anims: Dictionary = {}
static var _list: Array = []
static var _textures: Dictionary = {}
static var _loaded := false

static func reload() -> void:
	_loaded = false
	_monsters.clear()
	_resources.clear()
	_anims.clear()
	_list.clear()
	_textures.clear()
	_level_max = 0
	_ensure()

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_monsters = _load_json("monsters.json")
	_resources = _load_json("resources.json")
	_anims = _load_json("anims.json")
	for id in _monsters:
		var m: Dictionary = _monsters[id]
		_list.append({"id": int(id), "name": str(m["name"]), "res": str(m["res"])})
	_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])

static func _load_json(file: String) -> Dictionary:
	var path := DATA_DIR + file
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## Danh sách mọi quái [{id, name, res}] theo STT gốc trong Npcs.txt.
static func all() -> Array:
	_ensure()
	return _list

static func monster(id: int) -> Dictionary:
	_ensure()
	return _monsters.get(str(id), {})

## Kiểm tra quái id có phải là Boss không.
static func is_boss(id: int) -> bool:
	return bool(monster(id).get("is_boss", false))

## Lấy phân loại Boss: "gold", "small_gold", "killer", "challenge", "songjin", "world", "general"
static func boss_type(id: int) -> String:
	return str(monster(id).get("boss_type", ""))

## Danh sách tất cả Boss trong dữ liệu [{id, name, res, boss_type, sect, title}]
static func all_bosses() -> Array:
	_ensure()
	var out: Array = []
	for item in _list:
		var m: Dictionary = monster(item["id"])
		if m.get("is_boss", false):
			out.append({
				"id": item["id"],
				"name": m.get("name", item["name"]),
				"res": item["res"],
				"boss_type": m.get("boss_type", "general"),
				"sect": m.get("sect", ""),
				"title": m.get("title", ""),
				"series": int(m.get("series", 0))
			})
	return out

## ---- Script cấp gốc (npclevelscript, xuất bởi tools/import_vltk_npc_levels.py -> npc_levels.json) ----
## Mỗi quái: hệ 0-4 -> trường (Skill1..4, Level1..4, kháng, sát thương cơ bản, AIParam, Life/AttackRating/Defense/MinDamage/
## MaxDamage/Exp) -> giá trị cấp 1..levels. Engine gốc gọi script này mỗi lần sinh quái với hệ + cấp của điểm sinh.
static var _levels: Dictionary = {}
static var _level_pool: Array = []
static var _level_max := 0

## Bảng {trường: [giá trị theo cấp]} của quái `id` ở hệ `series` — {} nếu quái không có script cấp.
static func level_table(id: int, series: int) -> Dictionary:
	if _level_max == 0:
		_level_max = -1
		var parsed := _load_json("npc_levels.json")
		_levels = parsed.get("npcs", {})
		_level_pool = parsed.get("pool", [])
		_level_max = int(parsed.get("levels", 0))
	var per: Dictionary = _levels.get(str(id), {}).get(str(clampi(series, 0, 4)), {})
	var out := {}
	for field in per:
		out[field] = _level_pool[int(per[field])]
	return out

const MELEE_SERIES_SKILLS: Array[int] = [419, 420, 421, 422, 423]   # Kim (0), Mộc (1), Thủy (2), Hỏa (3), Thổ (4)
const RANGED_SERIES_SKILLS: Array[int] = [424, 425, 426, 427, 428] # Kim (0), Mộc (1), Thủy (2), Hỏa (3), Thổ (4)

## Áp SCRIPT CẤP GỐC lên dữ liệu quái `data` (mẫu quái `id`, hệ = data.series) ở cấp `level`: gắn level_table (máu / kinh nghiệm /
## chính xác / phòng thủ / sát thương theo đúng script — stat_at_level đọc), chiêu Skill1-4 + cấp chiêu, tham số AI. Trả bản sao mới
## (không ghi vào bảng quái dùng chung); quái không có script -> trả nguyên `data`. DÙNG CHUNG cho quái offline (VltkMonster) và quái
## game server (ServerMonster) — 2 bên phải ra cùng chỉ số.
static func apply_level_script(data: Dictionary, id: int, level: int) -> Dictionary:
	var series := clampi(int(data.get("series", 0)), 0, 4)
	var table := level_table(id, series)
	var d := data.duplicate()
	if not table.is_empty():
		d["level_table"] = table

	var is_boss_monster := bool(data.get("is_boss", false)) or is_boss(id) or str(data.get("boss_type", "")) != "" or "Boss" in str(data.get("name", "")) or bool(data.get("keep_skills", false)) or (id >= 1289 and id <= 1320)

	# Kiểm tra xem quái có phải quái tầm xa hay cận chiến
	var base_skills: Array = data.get("skills", [])
	var is_ranged_monster := false
	var has_unique_animal_skill := false
	var specific_ranged_id := 0

	for sk in base_skills:
		if sk is Array and sk.size() > 0:
			var sid := int(sk[0])
			if sid in [101, 53, 418, 419, 420, 421, 422, 423]:
				# 101 là hỗ trợ/trị liệu; 418-423 là cận chiến chuẩn
				continue
			if sid in [424, 425, 426, 427, 428, 196, 201, 153]:
				is_ranged_monster = true
			elif sid in [197, 198, 200]:
				has_unique_animal_skill = true
			elif sid > 0:
				var s_info := VltkSkillData.skill(sid, 1)
				if not s_info.is_empty():
					var is_melee := int(s_info.get("melee", 1)) == 1
					var radius := float(s_info.get("attack_radius", 0))
					var has_missile := int(s_info.get("child", 0)) > 0 or int(s_info.get("by_missle", 0)) == 1
					if not is_melee and radius > 150.0 and has_missile:
						is_ranged_monster = true

	# Nếu không phải Boss: gán chiêu thức chuẩn ngũ hành (Kim, Mộc, Thủy, Hỏa, Thổ) theo đúng hệ của quái
	if not is_boss_monster:
		var slv := clampi(maxi(1, level / 3), 1, 30)
		if not table.is_empty():
			var t_lv := level_value(table, "Level4" if is_ranged_monster else "Level2", level)
			if t_lv > 0:
				slv = t_lv

		var is_pure_ranged := bool(data.get("pure_ranged", false)) or id == 635
		if is_pure_ranged:
			# Cung thủ thuần tầm xa (như Cung binh MOBA)
			var ranged_skill: int = RANGED_SERIES_SKILLS[series]
			d["skills"] = [
				[ranged_skill, slv],
				[ranged_skill, slv],
				[ranged_skill, slv],
				[ranged_skill, slv]
			]
			d["skill_levels_exact"] = true
			d["ai_mode"] = 1
			d["ai_params"] = [50, 25, 25, 25, 25, 30, 50, 0, 0]
		elif is_ranged_monster:
			# Quái dã ngoại VLTK gốc (Bôn Lôi, Ngân Nha...): quái hệ nào thì dùng skill đánh xa ngũ hành theo đúng hệ đó
			# Cấu hình 75% đứng xa đánh chiêu tầm xa, 25% áp sát đánh cận chiến (khi vào gần <= 75px thì 100% cận chiến):
			# - Slot 0 (38%): Chiêu tầm xa ngũ hành (424-428 theo hệ của quái)
			# - Slot 1 (12%): Chiêu cận chiến ngũ hành (419-423 theo hệ của quái, cự ly <= 75px)
			# - Slot 2 (37%): Chiêu tầm xa ngũ hành (424-428 theo hệ của quái)
			# - Slot 3 (13%): Đòn đánh thường vật lý cận chiến (418, cự ly <= 75px)
			# => Tổng tỷ lệ khi ở xa: 75% đánh xa (Slot 0 + 2 = 75%), 25% đánh gần (Slot 1 + 3 = 25%)
			var ranged_skill: int = RANGED_SERIES_SKILLS[series]
			var melee_skill: int = MELEE_SERIES_SKILLS[series]
			d["skills"] = [
				[ranged_skill, slv],
				[melee_skill, slv],
				[ranged_skill, slv],
				[418, slv]
			]
			d["skill_levels_exact"] = true
			d["ai_mode"] = 1
			d["ai_params"] = [50, 38, 12, 37, 13, 30, 50, 0, 0]
		elif has_unique_animal_skill:
			# Động vật có chiêu riêng (Hồ ly, Cóc...)
			var skills := []
			for sk in base_skills:
				var sid := int(sk[0])
				skills.append([sid, slv])
			d["skills"] = skills
			d["skill_levels_exact"] = true
		else:
			# Quái cận chiến thường: dùng chiêu ngũ hành cận chiến theo đúng hệ
			# Hệ Kim (0): 419, Hệ Mộc (1): 420, Hệ Thủy (2): 421, Hệ Hỏa (3): 422, Hệ Thổ (4): 423
			var melee_skill: int = MELEE_SERIES_SKILLS[series]
			d["skills"] = [
				[melee_skill, slv],
				[melee_skill, slv],
				[418, slv],
				[melee_skill, slv]
			]
			d["skill_levels_exact"] = true
	else:
		# Boss giữ nguyên chiêu thức võ công môn phái đặc trưng
		var skills := []
		for i in range(mini(4, base_skills.size())):
			var sk: Array = base_skills[i]
			var sid := int(sk[0])
			var slv := int(sk[1]) if sk.size() > 1 else 1
			if not table.is_empty():
				var t_lv := level_value(table, "Level%d" % (i + 1), level)
				if t_lv > 0:
					slv = t_lv
			skills.append([sid, slv])
		d["skills"] = skills
		if not table.is_empty() and level_value(table, "Level1", level) > 0:
			d["skill_levels_exact"] = true

	# Chỉ lấy AI mode/params từ table nếu quái chưa có AI riêng trong monsters.json
	if int(d.get("ai_mode", 0)) <= 0 and not table.is_empty():
		var ai_mode := level_value(table, "AIMode", level)
		if ai_mode > 0:
			d["ai_mode"] = ai_mode
			var params := []
			for i in range(1, 10):
				params.append(maxi(0, level_value(table, "AIParam%d" % i, level)))
			d["ai_params"] = params
	return d

## Giá trị trường `field` ở cấp `level` trong bảng level_table (cấp ngoài khoảng -> cấp gần nhất); -1 nếu không có.
static func level_value(table: Dictionary, field: String, level: int) -> int:
	var arr: Array = table.get(field, [])
	if arr.is_empty():
		return -1
	return int(arr[clampi(level, 1, arr.size()) - 1])

static func has_data() -> bool:
	_ensure()
	return not _monsters.is_empty()

## Hình của động tác logic `action` (stand/walk/run/hurt/die/attack1/attack2/magic) của bộ tài nguyên `res`:
## {anim, frames, dirs, interval}. {} nếu bộ này không có hình nào cho động tác đó.
static func action(res: String, action_name: String) -> Dictionary:
	_ensure()
	var acts: Dictionary = _resources.get(res, {})
	for candidate in FALLBACK.get(action_name, [action_name]):
		if acts.has(candidate):
			return acts[candidate]
	return {}

static func anim(key: String) -> Dictionary:
	_ensure()
	return _anims.get(key, {})

static func texture(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var tex: Texture2D = null
	for dir in [USER_CACHE_DIR, PNG_DIR]:
		var path: String = dir + key + ".png"
		if not FileAccess.file_exists(path):
			continue
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			tex = ImageTexture.create_from_image(image)
			break
	_textures[key] = tex
	return tex

## Ảnh thu nhỏ của bộ hình (tools/make_monster_thumbs.py) cho lưới danh sách quái; null nếu chưa có.
static var _thumbs: Dictionary = {}
const THUMB_DIR := "res://assets/monster_thumbs/"

static func thumb(res: String) -> Texture2D:
	if _thumbs.has(res):
		return _thumbs[res]
	var tex: Texture2D = null
	var path := THUMB_DIR + res + ".png"
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			tex = ImageTexture.create_from_image(image)
	_thumbs[res] = tex
	return tex

## Số game frame (18/giây) của 1 vòng động tác theo dữ liệu quái (StandFrame/WalkFrame/RunFrame/DeathFrame/HurtFrame,
## AttackSpeed/CastSpeed trong Npcs.txt gốc) — hoạt ảnh được kéo giãn cho vừa đúng số frame này.
static func action_frames(m: Dictionary, action_name: String) -> int:
	var f: Dictionary = m.get("frames", {})
	var count := 0
	match action_name:
		"stand": count = int(f.get("stand", 0))
		"walk": count = int(f.get("walk", 0))
		"run": count = int(f.get("run", 0))
		"hurt": count = int(f.get("hurt", 0))
		"die": count = int(f.get("death", 0))
		"attack1", "attack2":
			var spd := int(m.get("attack_speed", 20))
			if spd <= 0: spd = 20
			return maxi(2, spd - (spd % 2))
		"magic":
			var spd := int(m.get("cast_speed", 20))
			if spd <= 0: spd = 20
			return maxi(2, spd - (spd % 2))

	if count > 0:
		return count

	# Nếu trong monsters.json không ghi số frame (bằng 0 hoặc thiếu):
	# Lấy trực tiếp từ số frame trên mỗi hướng của resource hình gốc (resources.json)
	var res := str(m.get("res", ""))
	if res != "":
		var act := action(res, action_name)
		if not act.is_empty():
			var dirs := maxi(1, int(act.get("dirs", 1)))
			var total_frames := int(act.get("frames", 0))
			if total_frames > 0:
				return maxi(1, total_frames / dirs)

	# Fallback mặc định nếu resource cũng không có
	match action_name:
		"stand": return 16
		"walk", "run": return 15
		"hurt": return 10
		"die": return 20
	return 16

## Chỉ số gốc của quái theo cấp — công thức script gốc npclevelscript (data/monsters/monsters.json, "stats"):
## floor(a*cấp² + b*cấp + c) nhân hệ số % (cột <Tên>Param, thường 100).
## stat: "life" | "exp" | "attack_rating" | "defense" | "min_damage" | "max_damage". Quái chưa có dữ liệu -> -1.
## Script cấp "soldier5" / "soldier6" (lính chiến trường: Đại tướng, Nguyên Soái): sinh lực / chính xác / phòng thủ / sát thương KHÔNG theo
## đa thức mà theo BẬC cấp — cấp <= 75 lấy số 1, <= 95 số 2, còn lại số 3 (npclevelscript/soldier6.lua SetKeyData). Chỉ dùng khi quái
## không có bảng script cấp (level_table — thường đã có, chạy chính script gốc).
const BAND_LEVEL_SCRIPTS := ["soldier5", "soldier6"]
const BAND_STATS := ["life", "attack_rating", "defense", "min_damage", "max_damage"]
const LIFE_CAP_MAX_LEVEL := 10
const LIFE_CAP_LEVEL_10 := 200

## Quái đã gắn bảng script cấp (m["level_table"], VltkMonster lúc sinh) dùng đúng số của script gốc.
const LEVEL_KEYS := {"life": "Life", "exp": "Exp", "attack_rating": "AttackRating", "defense": "Defense",
	"min_damage": "MinDamage", "max_damage": "MaxDamage"}

static func stat_at_level(m: Dictionary, stat: String, level: int) -> int:
	var table: Dictionary = m.get("level_table", {})
	if not table.is_empty() and LEVEL_KEYS.has(stat):
		var v := level_value(table, LEVEL_KEYS[stat], level)
		if v >= 0:
			return v
	var s: Dictionary = m.get("stats", {})
	if not s.has(stat):
		return -1
	var p: Array = s[stat]
	var lv := float(maxi(1, level))
	var value := floorf(float(p[1]) * lv * lv + float(p[2]) * lv + float(p[3]))
	if BAND_STATS.has(stat) and BAND_LEVEL_SCRIPTS.has(str(m.get("level_script", ""))):
		value = floorf(float(p[1] if level <= 75 else (p[2] if level <= 95 else p[3])))
	var result := int(floorf(value * float(p[0]) / 100.0))
	## TẠM THỜI (theo số đo trên server thật: Heo rừng/Nhím cấp 10 ở Hoa Sơn chết sau đúng 200 sát thương): quái từ cấp 10
	## trở xuống tối đa LIFE_CAP_LEVEL_10 máu; trên cấp 10 theo công thức gốc. Bỏ khi tìm ra công thức máu của server.
	if stat == "life" and level <= LIFE_CAP_MAX_LEVEL:
		result = mini(result, LIFE_CAP_LEVEL_10)
	return result

## Sát thương đòn cận chiến [nhỏ nhất, lớn nhất] của quái ở cấp `level` khi ra skill (skill_id, skill_level):
## sát thương cơ bản theo cấp + PhysicalDamageBase + sát thương cộng thêm của skill (đúng KNpc::AppendSkillEffect gốc).
## Quái chưa có dữ liệu gốc -> (-1, -1).
static func melee_damage(m: Dictionary, level: int, skill_id: int, skill_level: int) -> Vector2i:
	var lo := stat_at_level(m, "min_damage", level)
	var hi := stat_at_level(m, "max_damage", level)
	if lo < 0 or hi < 0:
		return Vector2i(-1, -1)
	hi = maxi(lo, hi)

	## KNpc::AppendSkillEffect gốc: cộng PhysicalDamageBase (m_CurrentAddPhysicsDamage) vào lực tay
	var add_phys := 0
	var table: Dictionary = m.get("level_table", {})
	if not table.is_empty():
		add_phys = maxi(0, level_value(table, "PhysicalDamageBase", level))
	elif m.has("damage_base") and m["damage_base"].has("physical"):
		var p: Array = m["damage_base"]["physical"]
		if p.size() >= 2:
			add_phys = maxi(0, int(floorf(float(p[0]) * level + float(p[1]))))
	lo += add_phys
	hi += add_phys

	var lv := skill_level if m.get("skill_levels_exact", false) else clampi(skill_level + level / 5, 1, 30)
	var enhance := VltkSkillData.hit_attrib(skill_id, "physicsenhance_p", lv)
	if not enhance.is_empty():
		lo = lo * (100 + int(enhance[0])) / 100
		hi = hi * (100 + int(enhance[0])) / 100
	var flat := VltkSkillData.hit_attrib(skill_id, "physicsdamage_v", lv)
	if not flat.is_empty():
		lo += int(flat[0])
		hi += int(flat[2] if flat.size() > 2 else flat[0])
	return Vector2i(lo, hi)
