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
## đa thức mà theo BẬC cấp — cấp <= 70 lấy số 1, <= 90 số 2, còn lại số 3 (npclevelscript/soldier6.lua SetKeyData).
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
		value = floorf(float(p[1] if level <= 70 else (p[2] if level <= 90 else p[3])))
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
