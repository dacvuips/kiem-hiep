extends RefCounted
class_name VltkSkillData
## Dữ liệu chiêu VLTK gốc do tools/import_vltk_skill_fx.py xuất ra (data/skill_fx/*.json + assets/skill_fx/*.png).
## Chỉ đọc — dùng chung cho mọi người chơi (state runtime nằm trên VltkMissile/VltkEffect, không ở đây).

const DATA_DIR := "res://data/skill_fx/"
const PNG_DIR := "res://assets/skill_fx/"
## Bản online: ảnh tải theo nhu cầu lưu ở đây, được ưu tiên trước ảnh đóng gói (giống AvatarData).
const USER_CACHE_DIR := "user://skill_fx/"

## Trạng thái đạn (eMissleStatus gốc) = chỉ số ảnh AnimFile1..4.
enum Phase { WAIT, FLY, VANISH, COLLISION }

static var _skills: Dictionary = {}
static var _missiles: Dictionary = {}
static var _anims: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}
static var _level_cache: Dictionary = {}  ## "id:level" -> skill đã áp thuộc tính theo cấp

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_skills = _load_json("skills.json")
	_missiles = _load_json("missiles.json")
	_anims = _load_json("anims.json")

static func _load_json(file: String) -> Dictionary:
	var path := DATA_DIR + file
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func has_skill(skill_id: int) -> bool:
	_ensure()
	return _skills.has(str(skill_id))

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

## Skill ở `level` — đã áp các thuộc tính theo cấp skill_* (KSkill::ParseString2MagicAttrib nhánh magic_skill_*),
## kèm "missile_override" = thuộc tính missle_* (KSkill::CreateMissle ghi đè lên đạn). {} nếu không có dữ liệu.
static func skill(skill_id: int, level: int) -> Dictionary:
	_ensure()
	var key := "%d:%d" % [skill_id, level]
	if _level_cache.has(key):
		return _level_cache[key]
	var base: Dictionary = _skills.get(str(skill_id), {})
	if base.is_empty():
		return {}
	var s := base.duplicate()
	s["id"] = skill_id
	s["level"] = level
	var overrides := {}
	var levels: Dictionary = base.get("levels", {})
	for attr in levels:
		var values: Array = levels[attr]
		var v: Array = values[clampi(level, 1, values.size()) - 1]
		match attr:
			"skill_misslenum_v": s["child_num"] = int(v[0])
			"skill_misslesform_v": s["form"] = int(v[0])
			"skill_param1_v": s["param1"] = int(v[0])
			"skill_param2_v": s["param2"] = int(v[1])  ## gốc đọc nValue2 (khác param1)
			"skill_eventskilllevel": s["event_level"] = int(v[0])
			"skill_attackradius": s["attack_radius"] = int(v[0])
			"skill_mintimepercast_v": s["time_per_cast"] = int(v[0])
			"skill_bymissle": s["by_missle"] = int(v[0])
			"skill_startevent":
				s["start_event"] = int(v[0])
				s["start_skill"] = int(v[2])
			"skill_flyevent":
				s["fly_event"] = int(v[0])
				s["fly_time"] = int(v[1])
				s["fly_skill"] = int(v[2])
			"skill_collideevent":
				s["collide_event"] = int(v[0])
				s["collide_skill"] = int(v[2])
			"skill_vanishedevent":
				s["vanish_event"] = int(v[0])
				s["vanish_skill"] = int(v[2])
			"missle_movekind_v": overrides["move_kind"] = int(v[0])
			"missle_speed_v": overrides["speed"] = int(v[0])
			"missle_lifetime_v": overrides["life"] = int(v[0])
			"missle_height_v": overrides["height_raw"] = int(v[0])
			"missle_damagerange_v": overrides["dmg_range"] = int(v[0])
			"missle_missrate": overrides["miss_rate"] = int(v[0])
			"missle_hitcount": overrides["hit_count"] = int(v[0])
			"missle_dmginterval": overrides["dmg_interval"] = int(v[0])
			"missle_zspeed": overrides["zspeed"] = int(v[0])
	s["missile_override"] = overrides
	_level_cache[key] = s
	return s

## Đạn con của skill (đã ghi đè thuộc tính theo cấp của skill). {} nếu không có.
static func missile_for(skill_lv: Dictionary) -> Dictionary:
	_ensure()
	var base: Dictionary = _missiles.get(str(int(skill_lv.get("child", 0))), {})
	if base.is_empty():
		return {}
	var m := base.duplicate()
	m.merge(skill_lv.get("missile_override", {}), true)
	return m
