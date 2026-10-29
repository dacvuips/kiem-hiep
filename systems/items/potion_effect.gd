extends Node
class_name PotionEffect
## Thuốc hồi sinh lực đang tác dụng trên 1 nhân vật (node con của Player) — đúng engine VLTK gốc:
##   - magic_lifepotion_v [giá trị, số frame]: mỗi GAME_UPDATE_TIME (10) frame (18 frame/giây) cộng "giá trị" sinh lực, trong "số frame"
##     (KNpc.cpp 1051-1061). VD Kim Sáng Dược (tiểu) [10, 100]: +10 mỗi ~0,56 giây, 10 lần = 100 sinh lực trong ~5,6 giây.
##   - Uống chồng (KNpcAttribModify.cpp 747-760): thời gian mới = max(còn lại, mới), giá trị mỗi nhịp = (v1·t1 + v2·t2) / thời gian mới
##     -> tổng lượng hồi giữ nguyên, hồi NHANH hơn chứ không kéo dài.
## Ngoài hồi sinh lực, mọi THUỐC DÙNG ĐƯỢC đều đi qua đây (usable / drink / consume):
##   - Thuốc buff có thời hạn (Trường Mệnh, Gia Bào, Đại Lực, Cao Thiểm, Cao Trung, Phi Tốc, các loại Phòng hoàn — loại 1_5 / 1_6):
##     [thuộc tính, giá trị, số frame] -> StatusEffectController.apply_state (cộng vào chỉ số, hiện biểu tượng buff). Uống lại cùng
##     loại = làm mới thời gian (không cộng dồn).
##   - Đan / hoàn loại 6 (magicscript: Viêm Đế…, thưởng Tống Kim) chỉ ghi skill trạng thái gốc (256-265); chú thích gốc trùng với hoàn
##     loại 1 tương ứng ("Nội 5 phút, sinh lực tăng tối đa 500"...) -> dùng hiệu ứng của món đó trong STATE_SKILL_SECONDS giây.
##   - Tiên Thảo Lộ (1h, 8h, hoàn) & May Mắn (Thiên Sơn Bảo Lộ 1h, Bánh chưng may mắn 30m): nhân đôi EXP / +may mắn, gắn hình
##     trạng thái StateSpecialId 67 (lucky.spr) trên đầu nhân vật.
##   - Phúc Duyên Lộ (Tiểu 10, Trung 20, Đại 50): cộng trực tiếp điểm Phúc Duyên vào PlayerProfile.fuyuan.
##   - Nội lực (manapotion_v), thể lực (stamina_v), giảm độc (poisondamagereduce_v): game chưa có nội lực tiêu hao / thể lực chạy /
##     giảm sát thương độc -> uống được (mất bình) nhưng chưa có tác dụng.

const GAME_FPS := 18.0
## Hiệu ứng chỉ là hồi phục theo nhịp / chưa có tác dụng (không phải buff thuộc tính).
const TICK_ATTRIBS := ["lifepotion_v", "manapotion_v", "manareplenish_v", "stamina_v", "poisondamagereduce_v"]
## Skill trạng thái của đan loại 6 -> hoàn loại 1 cùng hiệu ứng (chú thích gốc từng món).
const STATE_SKILL_ITEM := {256: "1_5_0_1", 257: "1_5_0_2", 258: "1_5_0_3", 259: "1_5_0_4", 260: "1_5_0_5",
	261: "1_6_0_1", 262: "1_6_0_2", 263: "1_6_0_3", 264: "1_6_0_4", 265: "1_6_0_5"}
const STATE_SKILL_SECONDS := 300.0
const UPDATE_FRAMES := 10

## Cấu hình các bình đặc biệt (Tiên Thảo Lộ, Thiên Sơn Bảo Lộ, Phúc Duyên Lộ)
const SPECIAL_ITEM_EFFECTS := {
	"6_1_71": {"effects": [["expenhance_p", 100, 64800]], "state_id": 67},           ## Tiên Thảo Lộ (1h, exp x2, skill 440)
	"6_1_1181": {"effects": [["expenhance_p", 100, 518400]], "state_id": 67},        ## Tiên Thảo Lộ đặc biệt (8h, exp x2)
	"6_1_1765": {"effects": [["expenhance_p", 100, 518400]], "state_id": 67},        ## Tiên Thảo Lộ đặc biệt (8h, exp x2)
	"6_1_113": {"effects": [["expenhance_p", 50, 64800]], "state_id": 67},           ## Tiên Thảo hoàn (1h, exp +50%)
	"6_1_72": {"effects": [["lucky_v", 10, 64800]], "state_id": 67},                 ## Thiên Sơn Bảo Lộ (1h, may mắn +10, skill 441)
	"6_0_70": {"effects": [["lucky_v", 30, 32400]], "state_id": 67},                 ## Bánh chưng May mắn (30m, may mắn +30, skill 410)
	"6_1_122": {"fuyuan": 10},                                                        ## Phúc Duyên Lộ (Tiểu)
	"6_1_123": {"fuyuan": 20},                                                        ## Phúc Duyên Lộ (Trung)
	"6_1_124": {"fuyuan": 50},                                                        ## Phúc Duyên Lộ (Đại)
}

var _value := 0.0       ## sinh lực mỗi nhịp
var _frames := 0        ## frame còn lại
var _mana_value := 0.0   ## nội lực mỗi nhịp
var _mana_frames := 0    ## frame còn lại
var _acc := 0.0

## Hiệu ứng thuốc của nhân vật `player` (tạo khi cần).
static func of(player: Node) -> PotionEffect:
	var e := player.get_node_or_null("PotionEffect") as PotionEffect
	if e == null:
		e = PotionEffect.new()
		e.name = "PotionEffect"
		player.add_child(e)
	return e

## Lượng điểm Phúc Duyên món này cộng trực tiếp (0 = không phải Phúc Duyên Lộ).
static func get_fuyuan_amount(item: ItemInstance) -> int:
	if item == null or not item.is_misc():
		return 0
	if SPECIAL_ITEM_EFFECTS.has(item.misc_id) and SPECIAL_ITEM_EFFECTS[item.misc_id].has("fuyuan"):
		return int(SPECIAL_ITEM_EFFECTS[item.misc_id]["fuyuan"])
	for e in item.get_base().get("effects", []):
		if str(e[0]) == "fuyuan_v":
			return int(e[1])
	return 0

static func is_fuyuan_potion(item: ItemInstance) -> bool:
	return get_fuyuan_amount(item) > 0

## Các hiệu ứng [thuộc tính, giá trị, số frame] của 1 món dùng được; [] nếu món không dùng được.
static func effects_of(item: ItemInstance) -> Array:
	if item == null or not item.is_misc():
		return []
	if SPECIAL_ITEM_EFFECTS.has(item.misc_id) and SPECIAL_ITEM_EFFECTS[item.misc_id].has("effects"):
		return SPECIAL_ITEM_EFFECTS[item.misc_id]["effects"]
	var base := item.get_base()
	var effects: Array = base.get("effects", [])
	if not effects.is_empty():
		return effects
	var mapped := str(STATE_SKILL_ITEM.get(int(base.get("skill_id", -1)), ""))
	if mapped == "":
		return []
	var out := []
	for e in ItemDatabase.get_misc(mapped).get("effects", []):
		out.append([e[0], e[1], int(STATE_SKILL_SECONDS * GAME_FPS)])
	return out

## Thuộc tính cộng được vào chỉ số (MagicAttribTable.apply nhận ra) — thử 1 lần trên bộ chỉ số trống, nhớ kết quả.
static var _known_cache := {}

static func _known(attrib: String) -> bool:
	if not _known_cache.has(attrib):
		_known_cache[attrib] = MagicAttribTable.apply(CombatantStats.new(), attrib, Vector3i(1, 0, 0))
	return bool(_known_cache[attrib])

## Món dùng được (thuốc hồi phục, thuốc buff, đan, phúc duyên) -> đặt vào ô thuốc nhanh / nút "Dùng".
static func usable(item: ItemInstance) -> bool:
	if is_fuyuan_potion(item):
		return true
	for e in effects_of(item):
		var attr := str(e[0])
		if TICK_ATTRIBS.has(attr) or attr == "heal_v" or _known(attr):
			return true
	return false

## Món này có hồi sinh lực không (thuốc hồi máu — auto đánh dùng để tự uống).
static func heals(item: ItemInstance) -> bool:
	if item == null or not item.is_misc():
		return false
	for e in item.get_base().get("effects", []):
		if str(e[0]) == "lifepotion_v":
			return true
	return false

## Món này có hồi nội lực không (thuốc hồi mana — auto đánh dùng để tự uống).
static func restores_mana(item: ItemInstance) -> bool:
	if item == null or not item.is_misc():
		return false
	for e in item.get_base().get("effects", []):
		var attr := str(e[0])
		if attr == "manapotion_v" or attr == "manareplenish_v":
			return true
	return false

## Uống 1 món: hồi sinh lực theo nhịp + buff thuộc tính có thời hạn. Trả false nếu món không dùng được.
static func drink(player: Node, item: ItemInstance) -> bool:
	if not usable(item):
		return false
	var buff := {}
	var seconds := 0.0
	for e in effects_of(item):
		var attrib := str(e[0])
		if attrib == "heal_v":
			if player.has_method("heal"):
				player.heal(float(e[1]))
		elif attrib == "lifepotion_v":
			PotionEffect.of(player).add(float(e[1]), int(e[2]))
		elif attrib == "manapotion_v" or attrib == "manareplenish_v":
			PotionEffect.of(player).add_mana(float(e[1]), int(e[2]))
		elif not TICK_ATTRIBS.has(attrib) and _known(attrib):
			buff[attrib] = Vector3i(int(e[1]), 0, 0)
			seconds = maxf(seconds, float(e[2]) / GAME_FPS)
	var status: StatusEffectController = player.get_node_or_null("StatusEffectController")
	if not buff.is_empty() and status != null:
		var key := buff.keys()
		key.sort()
		var state_id := 0
		if SPECIAL_ITEM_EFFECTS.has(item.misc_id):
			state_id = int(SPECIAL_ITEM_EFFECTS[item.misc_id].get("state_id", 0))
		status.apply_state("item:" + ",".join(key), buff, seconds, {
			"icon": ItemDatabase.get_icon(item.get_base()),
			"name": item.get_display_name(),
			"state_id": state_id
		})
	return true

## Lý do KHÔNG dùng được món này lúc này ("" = dùng được):
##   - Thuốc Tống Kim (songjin_only) chỉ dùng trong Chiến trường Tống Kim.
##   - Đang có Tiên Thảo Lộ (nhân đôi EXP) không uống chồng để tránh lãng phí.
static func block_reason(item: ItemInstance) -> String:
	if item == null or not item.is_misc():
		return ""
	if bool(item.get_base().get("songjin_only", false)) \
			and (GameManager.field_map.get("battle", {}) as Dictionary).is_empty() \
			and not bool(GameManager.field_map.get("tong_kim_lol", false)):
		return "%s chỉ dùng được trong Chiến trường Tống Kim." % item.get_display_name()
	var loop := Engine.get_main_loop()
	var player: Node = (loop as SceneTree).get_first_node_in_group("player") if loop is SceneTree else null
	if player != null:
		var status: StatusEffectController = player.get_node_or_null("StatusEffectController")
		if status != null:
			for e in effects_of(item):
				if str(e[0]) == "expenhance_p" and status.has_state("item:expenhance_p"):
					return "Các hạ đang còn thời gian nhân đôi kinh nghiệm."
	return ""

## Uống 1 bình `item` trong túi của `profile`: bớt 1 (hết thì bỏ khỏi túi) + thêm hiệu ứng. Thuốc không chồng (mỗi bình 1 ô) -> online
## server nhận việc bỏ món (ProfileGuard chỉ giữ món server biết). Người gọi tự lưu (SaveManager) / vẽ lại.
static func consume(profile: PlayerProfile, player: Node, item: ItemInstance) -> bool:
	if profile == null or not usable(item):
		return false
	var blocked := block_reason(item)
	if blocked != "":
		return false
	var index := profile.inventory.find(item)
	if index < 0:
		return false
	var fy := get_fuyuan_amount(item)
	if fy > 0:
		if item.count > 1:
			item.count -= 1
		else:
			profile.inventory.remove_at(index)
		profile.fuyuan += fy
		ChatBox.push_system("[color=#ffff00][Phúc Duyên][/color] Nhận được %d điểm Phúc Duyên (Hiện có: %d điểm)." % [fy, profile.fuyuan])
		if player != null and player.has_method("notify"):
			player.notify("+%d Phúc Duyên" % fy)
		return true
	if player == null:
		return false
	if not drink(player, item):
		return false
	if item.count > 1:
		item.count -= 1
	else:
		profile.inventory.remove_at(index)
	return true

## Bình đầu tiên mã `misc_id` trong túi (null nếu hết).
static func first_in_inventory(profile: PlayerProfile, misc_id: String) -> ItemInstance:
	if profile == null or misc_id == "":
		return null
	for it in profile.inventory:
		if it.misc_id == misc_id:
			return it
	return null

## Số bình mã `misc_id` trong túi.
static func count_in_inventory(profile: PlayerProfile, misc_id: String) -> int:
	var n := 0
	if profile == null or misc_id == "":
		return n
	for it in profile.inventory:
		if it.misc_id == misc_id:
			n += maxi(1, it.count)
	return n

func add(value: float, frames: int) -> void:
	if frames <= 0:
		return
	var new_frames := maxi(_frames, frames)
	_value = (_value * _frames + value * frames) / float(new_frames)
	_frames = new_frames

func add_mana(value: float, frames: int) -> void:
	if frames <= 0:
		return
	var new_frames := maxi(_mana_frames, frames)
	_mana_value = (_mana_value * _mana_frames + value * frames) / float(new_frames)
	_mana_frames = new_frames

func is_active() -> bool:
	return _frames > 0 or _mana_frames > 0

func _process(delta: float) -> void:
	if _frames <= 0 and _mana_frames <= 0:
		return
	var parent := get_parent()
	if parent == null or (parent.has_method("is_dead") and parent.call("is_dead")):
		_frames = 0
		_mana_frames = 0
		return
	_acc += delta * GAME_FPS
	while _acc >= 1.0 and (_frames > 0 or _mana_frames > 0):
		_acc -= 1.0
		if _frames > 0:
			_frames -= 1
			if _frames % UPDATE_FRAMES == 0 and parent.has_method("heal"):
				parent.heal(_value)
		if _mana_frames > 0:
			_mana_frames -= 1
			if _mana_frames % UPDATE_FRAMES == 0 and parent.has_method("restore_mana"):
				parent.restore_mana(_mana_value)
