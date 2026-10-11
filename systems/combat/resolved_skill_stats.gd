extends RefCounted
class_name ResolvedSkillStats
## Kết quả cuối cùng sau khi SkillResolver tổng hợp Skill Gem + mọi Support/Element/Fusion Gem
## đang linked. Đây là "snapshot" số liệu dùng để bắn 1 phát skill — tính lại mỗi khi socket
## thay đổi (không tính lại mỗi frame) để tránh tốn CPU.

var damage: float = 0.0
## Khoảng damage vật lý (nMinDamage..nMaxDamage gốc) — mỗi đòn ra ngẫu nhiên trong khoảng này; < 0 = không có, dùng `damage`.
var damage_min: float = -1.0
var damage_max: float = -1.0
var element: ElementTypes.ElementType = ElementTypes.ElementType.THO
## Tỷ lệ "Tấn công chí mạng" (deadlystrike_p VLTK, 0..1) — trúng thì CombatFormulas nhân ×2
## (DEADLY_STRIKE_MULTIPLIER) cho MỌI loại damage của đòn, xem Projectile.setup_from_resolved().
var crit_chance: float = 0.0
## Loại damage của phần `damage` chính — -1 = suy từ `element` (cách cũ). Skill môn phái đặt
## PHYSICS vì phần này là damage vật lý (Sức mạnh × physicsenhance_p) đúng VLTK; `element` vẫn dùng
## cho tương khắc Ngũ Hành.
var main_damage_type: int = -1
## "Ngũ hành tương khắc %" của skill (seriesdamage_p VLTK).
var five_elements_damage_p: int = 0

var hit_count: int = 1
var projectile_count: int = 1
var cooldown: float = 0.5
var mana_cost: float = 5.0
var projectile_speed: float = 300.0
var range_multiplier: float = 1.0

var explosion_radius: float = 0.0
var pierce_count: int = 0
var chain_count: int = 0
var knockback: float = 0.0
var lifesteal_percent: float = 0.0
var duration_multiplier: float = 1.0

## ---- Cờ hành vi bay — quyết định CÁCH mỗi viên đạn di chuyển, không chỉ số liệu ----
## Bật khi có Support Gem "Tự Dẫn" (Homing) — viên đạn tự xoay hướng bám theo mục tiêu riêng
## của nó mỗi frame, thay vì bay thẳng theo hướng bắn ban đầu.
var is_homing: bool = false
## Tốc độ xoay bám mục tiêu (radian/giây) — cao hơn = bẻ lái gấp hơn.
var homing_turn_speed: float = 6.0

## Khi bắn nhiều viên (projectile_count > 1): true = mỗi viên tự chọn 1 mục tiêu khác nhau
## (Tách Đạn thật sự "tỏa ra nhiều hướng độc lập"); false = mọi viên lệch góc quanh 1 hướng
## chung tới cùng 1 mục tiêu (shotgun spread mặc định).
var independent_targeting: bool = false

## Mỗi entry: {effect_id, chance, duration, magnitude} — thông số RIÊNG của từng status effect
## do gem khai báo (không còn dùng chung 1 status_chance/duration cho mọi hiệu ứng).
var on_hit_status_effects: Array[Dictionary] = []

## Bonus sát thương riêng theo hệ, cộng thêm SAU damage tổng — khớp cách ảnh gốc ghi
## "ST +180%" và "Hỏa +60%" là hai con số tách biệt cộng dồn lên nhau.
var element_damage_add_percent: Dictionary = {}  ## ElementTypes.ElementType (int) -> float

## Damage tuyệt đối THÊM theo hệ của skill môn phái (Băng/Hỏa/Lôi/Độc sát trong stat_lines) —
## CombatFormulas.DamageType -> Vector2i(min, max). Đi cùng `damage` (phần vật lý) trong CÙNG 1 đòn,
## mỗi loại bị kháng riêng của mục tiêu trừ, xem CombatFormulas.resolve_multi_damage().
var extra_damage_ranges: Dictionary = {}

## Hiệu ứng trúng đòn của skill môn phái (frame VLTK, đã gồm bonus người đánh) — chép sang
## CombatFormulas.HitModifiers lúc bắn, xem SectSkillController._resolve_stats().
var freeze_frames: int = 0
var poison_time_frames: int = 0
var poison_interval_frames: int = 0
## Lượng độc rút MỖI NHỊP (m_PoisonState.nValue[0] gốc = damage của skill, không phải số vừa roll lúc trúng đòn). 0 = lấy theo damage thực của đòn.
var poison_tick_damage: int = 0
var stun_chance_p: int = 0
var stun_frames: int = 0
## Bùa (skill nhắm địch chỉ mang trạng thái): đạn trúng thì áp trạng thái này lên mục tiêu, không damage.
var is_state_only: bool = false
var state_source_id: String = ""
var state_attribs: Dictionary = {}
var state_seconds: float = 0.0
var state_meta: Dictionary = {}
var state_radius: float = 0.0

var vfx_hit_name: String = "hit_explosion"
var color: Color = Color.WHITE

## null = dùng âm mặc định theo element (SfxManager tự chọn lúc phát, nên Element Gem đổi hệ
## cũng tự đổi tiếng theo mà không cần resolve lại gì thêm).
var cast_sfx: AudioStream = null
var hit_sfx: AudioStream = null
var sfx_volume_db: float = 0.0

func roll_is_critical() -> bool:
	return randf() < crit_chance

## Phần phụ của 1 đòn gửi kèm khi trúng (damage hệ, chí mạng roll 1 lần cho cả đòn, ngũ hành tương khắc, hiệu ứng
## trúng đòn, bùa) — dùng chung cho Projectile và đạn VLTK (VltkMissile).
func make_hit_mods(attacker_node: Node, is_melee: bool = false) -> CombatFormulas.HitModifiers:
	var mods := CombatFormulas.HitModifiers.new()
	mods.extra_damages = extra_damage_ranges
	mods.is_deadly_strike = roll_is_critical()
	mods.five_elements_damage_p = five_elements_damage_p
	mods.freeze_frames = freeze_frames
	mods.poison_time_frames = poison_time_frames
	mods.poison_interval_frames = poison_interval_frames
	mods.poison_tick_damage = poison_tick_damage
	mods.stun_chance_p = stun_chance_p
	mods.stun_frames = stun_frames
	mods.is_state_only = is_state_only
	mods.state_source_id = state_source_id
	mods.state_attribs = state_attribs
	mods.state_seconds = state_seconds
	mods.state_meta = state_meta
	mods.state_radius = state_radius
	mods.attacker_node = attacker_node
	mods.is_melee = is_melee
	return mods
