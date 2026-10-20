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

	var is_boss_monster := bool(data.get("is_boss", false)) or is_boss(id) or str(data.get("boss_type", "")) != "" or "Boss" in str(data.get("name", ""))

	# Kiểm tra xem quái có phải quái tầm xa hay cận chiến
	var base_skills: Array = data.get("skills", [])
	var is_ranged_monster := false
	var has_unique_animal_skill := false

	for sk in base_skills:
		if sk is Array and sk.size() > 0:
			var sid := int(sk[0])
			if sid in [153, 424, 425, 426, 427, 428, 196, 201]:
				is_ranged_monster = true
			elif sid in [197, 198, 200]:
				has_unique_animal_skill = true
			elif sid > 0:
				var s_info := VltkSkillData.skill(sid, 1)
				if not s_info.is_empty():
					var is_melee := int(s_info.get("melee", 1)) == 1
					var radius := float(s_info.get("attack_radius", 0))
					if not is_melee and radius > 150.0:
						is_ranged_monster = true

	# Nếu không phải Boss: gán chiêu thức chuẩn ngũ hành (Kim, Mộc, Thủy, Hỏa, Thổ) theo đúng hệ của quái
	if not is_boss_monster:
		var slv := clampi(maxi(1, level / 3), 1, 30)
		if not table.is_empty():
			var t_lv := level_value(table, "Level4" if is_ranged_monster else "Level2", level)
			if t_lv > 0:
				slv = t_lv

		if is_ranged_monster:
			# Quái đánh xa (như Ngân Nha, Cung Thủ...): dùng chiêu ngũ hành tầm xa theo đúng hệ (Series)
			# Hệ Kim (0): 424, Hệ Mộc (1): 425, Hệ Thủy (2): 426, Hệ Hỏa (3): 427, Hệ Thổ (4): 428
			var ranged_skill: int = RANGED_SERIES_SKILLS[series]
			d["skills"] = [
				[ranged_skill, slv],
				[ranged_skill, slv],
				[ranged_skill, slv],
				[ranged_skill, slv]
			]
			d["skill_levels_exact"] = true
			d["ai_mode"] = 1
			d["ai_params"] = [50, 25, 25, 25, 25, 25, 25, 0, 0]
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
				[melee_skill, slv],
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
	match action_name:
		"stand": return maxi(1, int(f.get("stand", 16)))
		"walk": return maxi(1, int(f.get("walk", 12)))
		"run": return maxi(1, int(f.get("run", 12)))
		"hurt": return maxi(1, int(f.get("hurt", 10)))
		"die": return maxi(1, int(f.get("death", 20)))
		"attack1", "attack2": return maxi(4, int(m.get("attack_speed", 18)))
		"magic": return maxi(4, int(m.get("cast_speed", 18)))
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
## sát thương cơ bản theo cấp + sát thương cộng thêm của chính skill (physicsdamage_v / physicsenhance_p).
## Quái chưa có dữ liệu gốc -> (-1, -1).
static func melee_damage(m: Dictionary, level: int, skill_id: int, skill_level: int) -> Vector2i:
	var lo := stat_at_level(m, "min_damage", level)
	var hi := stat_at_level(m, "max_damage", level)
	if lo < 0 or hi < 0:
		return Vector2i(-1, -1)
	hi = maxi(lo, hi)
	var lv := clampi(skill_level + level / 5, 1, 30)
	var flat := VltkSkillData.hit_attrib(skill_id, "physicsdamage_v", lv)
	if not flat.is_empty():
		lo += int(flat[0])
		hi += int(flat[2] if flat.size() > 2 else flat[0])
	var enhance := VltkSkillData.hit_attrib(skill_id, "physicsenhance_p", lv)
	if not enhance.is_empty():
		lo = lo * (100 + int(enhance[0])) / 100
		hi = hi * (100 + int(enhance[0])) / 100
	return Vector2i(lo, hi)
