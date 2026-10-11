extends RefCounted
class_name VltkSound
## Tra cứu âm thanh VLTK gốc do tools/import_vltk_sounds.py nhập (data/sound/vltk_sounds.json + audio/vltk/).
## Chỉ đọc, dùng chung — phát tiếng thật qua SfxManager / MusicManager (đừng tự tạo AudioStreamPlayer).
## File thiếu trong pak gốc đã bị bỏ qua lúc nhập -> các hàm tra cứu trả "" / null, nơi gọi im lặng bỏ qua.

const DATA_PATH := "res://data/sound/vltk_sounds.json"
const SOUND_DIR := "res://audio/vltk/sound/"
const MUSIC_DIR := "res://audio/vltk/music/"
## Nhãn tiếng Việt cho SoundList.txt [Ui] (số = khoá gốc).
const UI_POPUP := 0        ## mở/đóng giao diện trong game
const UI_ENTER := 1        ## vào giao diện ngoài game
const UI_HOVER := 2        ## rê chuột lên nút
const UI_ITEM := 3         ## nhấc/đặt đồ vào ô hành trang
const UI_SELECT := 4       ## chọn nhân vật / chọn ngũ hành
const UI_SYSTEM_MSG := 7   ## tin hệ thống

const PHASE_NAMES: Array[String] = ["wait", "fly", "vanish", "collision"]
## Động tác logic của quái -> khoá trong bảng âm quái (bảng gốc không có âm đi/đứng cho hầu hết quái).
const NPC_ACTION_ALIAS := {
	"stand": ["stand1", "fight_stand"], "walk": ["walk", "fight_walk"], "run": ["run", "fight_run"],
	"hurt": ["hurt"], "die": ["die"], "attack1": ["attack1", "attack2"], "attack2": ["attack2", "attack1"],
	"magic": ["magic", "attack1"],
}

static var _data: Dictionary = {}
static var _loaded := false
static var _streams: Dictionary = {}  ## đường dẫn tương đối -> AudioStream (null = không tải được)

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("VltkSound: thiếu %s — chạy tools/import_vltk_sounds.py" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_data = parsed if parsed is Dictionary else {}

## Tiếng wav theo đường dẫn tương đối trong audio/vltk/sound (VD "skill/sound_k001.wav"); null nếu không có.
static func stream(rel: String) -> AudioStream:
	if rel == "":
		return null
	if _streams.has(rel):
		return _streams[rel]
	var path := SOUND_DIR + rel
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[rel] = s
	return s

## Âm UI/Game theo SoundList.txt: section "ui" hoặc "game", khoá gốc (UI_* ở trên).
static func ui(key: int, section: String = "ui") -> AudioStream:
	_ensure()
	return stream(str(_data.get(section, {}).get(str(key), "")))

## Tiếng ra chiêu của skill (KSkill::PlayPreCastSound): nam / nữ.
static func skill_cast(vltk_skill_id: int, female: bool) -> AudioStream:
	_ensure()
	var e: Dictionary = _data.get("skills", {}).get(str(vltk_skill_id), {})
	return stream(str(e.get("fm" if female else "man", "")))

## Tiếng đạn theo giai đoạn (Phase WAIT/FLY/VANISH/COLLISION = 0..3), variant B khi đạn dùng bộ ảnh B (MultiShow).
static func missile(missile_id: int, phase: int, variant_b: bool = false) -> AudioStream:
	_ensure()
	var e: Dictionary = _data.get("missiles", {}).get(str(missile_id), {})
	var phases: Dictionary = e.get("b" if variant_b else "a", {})
	if phases.is_empty() and variant_b:
		phases = e.get("a", {})
	return stream(str(phases.get(PHASE_NAMES[phase], "")))

## Tiếng nhân vật chính theo ĐỘNG TÁC GỐC của bảng 主角动作声音表 (FreeAttack = đánh tay không, MeleeWCut = chém bằng vũ khí,
## FreeRun/RideRun = chạy, FreeWound = bị đánh, FreeDie = chết, JumpFly = nhảy...) — giống CharacterAvatar._vltk_action.
static func player_action(vltk_action: String, female: bool) -> AudioStream:
	_ensure()
	var e: Dictionary = _data.get("player", {}).get(vltk_action, {})
	return stream(str(e.get("fm" if female else "man", "")))

## Tiếng quái (bộ tài nguyên `res`, vd "enemy003") khi bắt đầu động tác logic stand/walk/run/hurt/die/attack1/attack2/magic.
static func npc(res: String, action: String) -> AudioStream:
	_ensure()
	var acts: Dictionary = _data.get("npc", {}).get(res.to_lower(), {})
	for key in NPC_ACTION_ALIAS.get(action, [action]):
		if acts.has(key):
			return stream(str(acts[key]))
	return null

## Nhạc nền của map VLTK (MusicSet.txt): [{file, volume}] — rỗng nếu map không có nhạc.
static func map_music(map_id: int) -> Array:
	_ensure()
	return _data.get("music_map", {}).get(str(map_id), [])
