extends RefCounted
class_name CombatFormulas
## Công thức combat CHÍNH XÁC 100% theo server Võ Lâm Truyền Kỳ gốc — trích dẫn nguyên văn từ mã
## nguồn C++ thật (KPlayer.cpp, KNpc.cpp, GameDataDef.h), xem docs/vltk_player_stats_reference.md
## mục 11 để đối chiếu từng dòng code gốc + số dòng file.
##
## THIẾT KẾ: mọi hàm ở đây THUẦN TÚY (static, không đọc/ghi state ngoài tham số truyền vào) — đây
## là điều kiện bắt buộc để dùng chung được cho combat local (chơi 1 mình) VÀ combat online sau
## này (server tính bằng CHÍNH hàm này, client chỉ hiển thị lại kết quả server trả về, không tự
## tính khác server — tránh cheat/desync). KHÔNG thêm biến instance, KHÔNG gọi RNG toàn cục ở đây
## ngoại trừ 2 hàm roll_* (được tách riêng, dễ thay bằng RNG có seed đồng bộ server/client khi cần
## replay/kiểm chứng).
##
## PHẠM VI: dùng cho MỌI cặp "bên tấn công vs bên bị đánh" trong game (player-vs-enemy hiện tại,
## và player-vs-player PvP sau này) — cả 2 phía đều mô tả bằng CombatantStats (xem file cùng thư
## mục), không phân biệt Player hay NPC như code gốc tách KPlayer/KNpc.

## ---- Hằng số gốc VLTK — NGUYÊN VĂN từ GameDataDef.h, KHÔNG suy đoán ----
## Xem docs/vltk_player_stats_reference.md mục 11.7 để đối chiếu số dòng file gốc.
const MAX_PERCENT := 100          ## GameDataDef.h:47 — mẫu số % dùng khắp công thức
const MAX_RESIST := 95            ## GameDataDef.h:382 — trần % kháng tối đa (không thể kháng 100%)
const MIN_HIT_PERCENT := 40       ## Cap dưới % trúng đòn — số cứng trong CheckHitTarget gốc (KHÔNG
                                   ## phải hằng số MIN_HIT_PERCENT=5 của GameDataDef.h, hằng số đó
                                   ## định nghĩa nhưng KHÔNG được dùng trong hàm gốc — xem mục 11.6)
const MAX_HIT_PERCENT := 95       ## GameDataDef.h:386 — trần % trúng đòn
const DEADLY_STRIKE_MULTIPLIER := 2.0   ## MAX_DEATLY_STRIKE_ENHANCEP=200 / MAX_PERCENT=100
const FATALLY_STRIKE_MIN_PERCENT := 30  ## GameDataDef.h:66 — Fatally Strike: %HP tối thiểu của mục tiêu
const FATALLY_STRIKE_MAX_PERCENT := 50  ## GameDataDef.h:67 — Fatally Strike: %HP tối đa của mục tiêu
const STRENGTH_SET_DAMAGE_VALUE := 5    ## KPlayer.h:29 — chia Strength ra Min/Max damage tay không

## ==============================================================================================
## BƯỚC 1 — AttackRating & Defense (từ Dexterity, KPlayer.cpp:7164-7172)
## ==============================================================================================

## AttackRating = Dexterity × 4 − 28 — NGUYÊN VĂN KPlayer::SetBaseAttackRating() (KPlayer.cpp:7166).
## Quyết định TỈ LỆ TRÚNG ĐÒN (xem roll_hit), KHÔNG ảnh hưởng lượng damage.
static func calc_base_attack_rating(dexterity: int) -> int:
	return dexterity * 4 - 28

## Defense = Dexterity ÷ 4 (chia nguyên) — NGUYÊN VĂN KPlayer::SetBaseDefence() (KPlayer.cpp:7171).
## Cũng chỉ phụ thuộc Dexterity, giống AttackRating — VLTK gốc dùng Dexterity cho CẢ 2 vai trò
## "đánh trúng" lẫn "né tránh", không tách riêng 2 chỉ số như nhiều RPG khác.
static func calc_base_defense(dexterity: int) -> int:
	return int(dexterity / 4.0)  ## >> 2 trong code gốc = chia nguyên cho 4, tương đương floor division

## Min = Max = Strength ÷ 5 (chia nguyên) — NGUYÊN VĂN KPlayer::SetFirstDamage() (KPlayer.cpp:7112-7118).
## Đây là damage TAY KHÔNG gốc (chưa cộng vũ khí/skill/buff) — vũ khí thật dùng bảng riêng
## (xem KItemList::GetWeaponDamage, không thuộc phạm vi file này vì đó là hệ thống Item/Equipment).
static func calc_base_unarmed_damage(strength: int) -> int:
	return int(strength / float(STRENGTH_SET_DAMAGE_VALUE))

## ==============================================================================================
## BƯỚC 2 — Roll trúng/né đòn (KNpc::CheckHitTarget, KNpc.cpp:5829-5853, TOÀN VĂN)
## ==============================================================================================

## Tính % tỉ lệ trúng đòn (chưa roll ngẫu nhiên) — tách riêng khỏi roll_hit() để dễ hiển thị UI
## ("Tỉ lệ trúng: 72%") và dễ unit-test (kết quả xác định, không random).
##
## attack_rating: AttackRating của bên tấn công.
## defense: Defense của bên bị đánh.
## ignore_defense_percent: % bỏ qua Defense của mục tiêu (0-100, từ skill/passive xuyên giáp).
static func calc_hit_percent(attack_rating: int, defense: int, ignore_defense_percent: int = 0) -> int:
	if attack_rating < 0:
		return 0  ## CheckHitTarget gốc: nAR < 0 → return FALSE (luôn trượt)

	var effective_defense := 0
	if ignore_defense_percent < MAX_PERCENT:
		effective_defense = int(defense * (MAX_PERCENT - ignore_defense_percent) / float(MAX_PERCENT))

	var percent: int
	if defense < 0:
		percent = MAX_HIT_PERCENT
	elif attack_rating + effective_defense == 0:
		percent = 50
	else:
		percent = int(attack_rating * MAX_PERCENT / float(attack_rating + effective_defense))

	## Cap gốc: chỉ hạ về MAX_HIT_PERCENT khi VƯỢT QUÁ MAX_HIT_PERCENT+4 (tức >99) — nghĩa là % trúng
	## thực tế có thể đạt 96-99 trước khi bị cắt, không cắt cứng ngay tại 95 (KNpc.cpp:5845-5846).
	if percent > MAX_HIT_PERCENT + 4:
		percent = MAX_HIT_PERCENT
	if percent < MIN_HIT_PERCENT:
		percent = MIN_HIT_PERCENT
	return percent

## Roll thật (có RNG) xem đòn này có trúng không — dùng calc_hit_percent ở trên.
static func roll_hit(attack_rating: int, defense: int, ignore_defense_percent: int = 0) -> bool:
	var percent := calc_hit_percent(attack_rating, defense, ignore_defense_percent)
	return randi_range(1, 100) <= percent

## ==============================================================================================
## BƯỚC 3 — Tương khắc Ngũ Hành (KNpc::CalcDamage, KNpc.cpp:2600-2617, TOÀN VĂN)
## ==============================================================================================

## Kết quả trung gian của bước tương khắc — tách riêng struct nhỏ để hàm chính (resolve_damage)
## đọc dễ hơn thay vì trả về Array/Dictionary không rõ ý nghĩa từng phần tử.
class FiveElementsResult:
	var resist_delta: int = 0   ## Cộng/trừ vào % kháng của bên phòng thủ trước khi trừ damage
	var damage_delta: int = 0   ## Cộng/trừ TRỰC TIẾP vào damage (số âm = giảm damage)

## Áp dụng tương khắc Ngũ Hành giữa hệ của đòn tấn công (VD hệ của skill/vũ khí) và hệ bản mệnh
## của bên phòng thủ — NGUYÊN VĂN logic 2 nhánh if/else if trong CalcDamage gốc:
##   - Attacker khắc Defender  → resist -= five_elements_damage_p; damage -= (AttackerEnhance - DefenderResist)
##   - Defender khắc lại Attacker (chiều ngược) → resist += five_elements_damage_p; damage -= (DefenderResist - AttackerEnhance)
##   - Không cùng cặp khắc nào → không có gì thay đổi (giữ nguyên resist_delta=0, damage_delta=0)
##
## attacker_element/defender_element: hệ Ngũ Hành của đòn đánh và của mục tiêu (ElementTypes.ElementType).
## five_elements_damage_p: tham số skill/vũ khí quyết định mức cộng/trừ kháng khi khắc chế (tương
## ứng nFiveElements_DamageP trong code gốc — mỗi skill có giá trị riêng, xem stat "Ngũ hành tương
## khắc: X%" trong SkillDefinition.stat_lines).
## attacker_enhance/defender_resist: m_CurrentFiveElementsEnhance/m_CurrentFiveElementsResist gốc —
## bonus Ngũ Hành từ trang bị/passive của 2 bên (0 nếu chưa có hệ trang bị/passive tương ứng).
static func apply_five_elements_clash(
	attacker_element: ElementTypes.ElementType,
	defender_element: ElementTypes.ElementType,
	five_elements_damage_p: int,
	attacker_enhance: int,
	defender_resist: int,
) -> FiveElementsResult:
	var result := FiveElementsResult.new()
	if ElementTypes.does_beat(attacker_element, defender_element):
		result.resist_delta = -five_elements_damage_p
		result.damage_delta = -(attacker_enhance - defender_resist)
	elif ElementTypes.is_beaten_by(attacker_element, defender_element):
		result.resist_delta = five_elements_damage_p
		result.damage_delta = -(defender_resist - attacker_enhance)
	return result

## ==============================================================================================
## BƯỚC 4 — Tổng hợp toàn bộ pipeline damage (KNpc::CalcDamage, KNpc.cpp:2445-2688)
## ==============================================================================================

## ==============================================================================================
## HỆ SỐ SÁT THƯƠNG CỦA SERVER THẬT (Coreserver.dll chạy trên máy ảo, KHÁC mã nguồn trong repo)
## Lấy từ bản giải mã Ghidra của KNpc::ReceiveDamage thật (tools/ghidra_output/real_damage_functions.txt, hàm @10010860): trước khi
## vào CalcDamage, mỗi loại damage của đòn bị NHÂN riêng:
##   - Vật lý        : x (500 + k) / 100  (k = 1, hoặc 2 với xác suất không rõ — dùng 1)  => khoảng x5
##   - Hỏa           : x (rand 0..4 + 5 + k) / 5 cho min; x (X + k) / 5 cho max, X = 7 nếu hệ đạn Kim/Mộc/Thổ, = rand 0..9 + 5 nếu Thủy/Hỏa
##   - Băng          : như Hỏa; X = 7 nếu hệ đạn Kim/Hỏa, = rand 0..9 + 5 nếu Thổ/Thủy, = 0 nếu Mộc
##   - Lôi           : như trên nhưng chia 10 (không phải 5); X = 7 nếu hệ đạn Kim/Thủy/Hỏa/Thổ, = rand 0..9 + 5 nếu Mộc
##   - Độc           : giữ nguyên (cú đánh đầu = roll giữa damage và nhịp)
## `false` để quay về công thức thuần của mã nguồn.
## ==============================================================================================
const SERVER_DAMAGE_SCALING := true
const SERVER_SCALE_K := 1

## Áp hệ số trên cho `parts` (DamageType -> Vector2i(min, max)); `series` = hệ của đạn (0 Kim, 1 Mộc, 2 Thủy, 3 Hỏa, 4 Thổ).
static func apply_server_damage_scaling(parts: Dictionary, series: int) -> Dictionary:
	if not SERVER_DAMAGE_SCALING:
		return parts
	var out := {}
	var k := SERVER_SCALE_K
	for t in parts:
		var v: Vector2i = parts[t]
		match t:
			DamageType.PHYSICS:
				out[t] = Vector2i(v.x * (500 + k) / 100, v.y * (500 + k) / 100)
			DamageType.FIRE:
				var x := 7 if series in [0, 1, 4] else (randi_range(0, 9) + 5 if series in [2, 3] else 0)
				out[t] = Vector2i((randi_range(0, 4) + 5 + k) * v.x / 5, (x + k) * v.y / 5)
			DamageType.COLD:
				var y := 7 if series in [0, 3] else (randi_range(0, 9) + 5 if series in [2, 4] else 0)
				out[t] = Vector2i((randi_range(0, 4) + 5 + k) * v.x / 5, (y + k) * v.y / 5)
			DamageType.LIGHT:
				var z := 7 if series in [0, 2, 3, 4] else (randi_range(0, 9) + 5 if series == 1 else 0)
				out[t] = Vector2i((k + randi_range(0, 4) + 5) * v.x / 10, (z + k) * v.y / 10)
			_:
				out[t] = v
	return out

## Loại damage — quyết định dùng % kháng/giáp nào của bên phòng thủ (Physics/Cold/Fire/Light/
## Poison/Magic — đúng switch(nType) trong CalcDamage gốc, KNpc.cpp:2498-2587).
enum DamageType { PHYSICS, COLD, FIRE, LIGHT, POISON, MAGIC }

## Input đầy đủ cho 1 lần tính damage — gom mọi tham số CalcDamage gốc cần vào 1 struct để hàm
## resolve_damage() có chữ ký gọn, dễ đọc, dễ thêm field mới sau này (VD thêm hiệu ứng mới) mà
## không phải sửa signature ở mọi nơi gọi.
class DamageContext:
	var min_damage: int = 0
	var max_damage: int = 0
	var damage_type: DamageType = DamageType.PHYSICS
	var is_melee: bool = true

	## Ngũ Hành của đòn đánh (skill/vũ khí) và của bên phòng thủ (bản mệnh nhân vật/quái).
	var attacker_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM
	var defender_element: ElementTypes.ElementType = ElementTypes.ElementType.KIM
	var five_elements_damage_p: int = 0      ## nFiveElements_DamageP — từ skill đang dùng
	var attacker_five_elements_enhance: int = 0
	var defender_five_elements_resist: int = 0

	## % kháng theo LOẠI damage của bên phòng thủ (đã cap theo *ResistMax riêng — xem CombatantStats)
	## và giáp tuyệt đối tương ứng (m_PhysicsArmor/m_ColdArmor/...).
	var defender_resist_percent: int = 0
	var defender_flat_armor: int = 0

	## true nếu 2 bên là player-vs-player (PK) — nhân thêm pk_damage_rate.
	var is_pk: bool = false
	var pk_damage_rate_percent: int = 100  ## NpcSet.m_nPKDamageRate gốc — mặc định 100 = không đổi

	## Chí mạng — 2 loại TÁCH BIỆT theo đúng gốc (không gộp chung 1 "crit" như nhiều game khác):
	##   is_deadly_strike: đòn "chí mạng" thường — nhân DEADLY_STRIKE_MULTIPLIER (×2)
	##   is_fatally_strike: đòn "chí mạng chí tử" — gây sát thương = % HIỆN TẠI của mục tiêu, GHI ĐÈ
	##     hoàn toàn damage roll được (không cộng dồn với deadly strike, xem CalcDamage gốc dùng if
	##     riêng biệt không phải else-if, nhưng 2 cờ này về mặt thiết kế game gốc không bật đồng thời)
	var is_deadly_strike: bool = false
	var is_fatally_strike: bool = false
	var defender_current_hp: int = 0  ## Cần cho fatally strike (% HP hiện tại, không phải HP tối đa)

## Kết quả cuối 1 lần tính damage — tách struct riêng thay vì trả int trần, để chỗ gọi biết rõ
## đòn có trúng không (is_hit=false thì final_damage luôn 0, không phải "damage=0 do kháng hết").
class DamageResult:
	var is_hit: bool = true
	var final_damage: int = 0

## Phần "phụ" của 1 đòn skill ngoài damage chính — lấy từ stat_lines VLTK của skill (xem
## SkillDefinition.get_combat_damage_at_level) và truyền tới take_damage_from() của mục tiêu:
##   extra_damages: DamageType -> Vector2i(min, max) — Băng/Hỏa/Lôi/Độc sát cộng chung đòn.
##   is_deadly_strike: đòn này trúng "Tấn công chí mạng" (deadlystrike_p) — ×2 mọi loại damage.
##   five_elements_damage_p: "Ngũ hành tương khắc %" (seriesdamage_p) — trừ/cộng % kháng khi khắc.
##   freeze/poison/stun_*: hiệu ứng trúng đòn (frame VLTK, 18/giây) — đã gồm bonus của người đánh
##     (coldenhance/poisonenhance), CHƯA trừ giảm thời gian của bên bị trúng (StatusEffectController
##     .apply_vltk_hit tự trừ theo CombatantStats của chính nó, đúng ReceiveDamage gốc).
## Hệ số sát thương khi người chơi đánh người chơi: settings/npc/player/pkrate.ini gốc [PK] rate=20 (KNpcSet.cpp đọc vào
## m_nPKDamageRate, KNpc.cpp:2592 nhân vào damage khi cả 2 bên là kind_player).
const PK_DAMAGE_RATE_PERCENT := 20

class HitModifiers:
	var extra_damages: Dictionary = {}
	var is_deadly_strike: bool = false
	## IsUseAR của skill: false = KHÔNG roll trúng/trượt (KNpc::ReceiveDamage gốc chỉ CheckHitTarget khi bUseAR).
	var use_attack_rating: bool = true
	## DoHurt của skill: % khựng (DoHurt()) mục tiêu khi trúng; 100 = luôn (đòn không khai báo).
	var do_hurt_p: int = 100
	var five_elements_damage_p: int = 0
	var freeze_frames: int = 0           ## làm chậm nếu phần Băng sát gây được damage
	var poison_time_frames: int = 0      ## trúng độc nếu phần Độc sát gây được damage
	var poison_interval_frames: int = 0
	var poison_tick_damage: int = 0      ## lượng rút mỗi nhịp độc (0 = theo damage thực của đòn)
	var stun_chance_p: int = 0           ## % tỷ lệ choáng (độc lập với damage)
	var stun_frames: int = 0
	## Người đánh (node) — để phản đòn (damage return) và hút máu (steal life); null = bỏ qua 2 thứ đó.
	var attacker_node: Node = null
	## Đòn cận chiến (va chạm) hay tầm xa (đạn/skill bay) — chọn melee/range damage return của bên bị đánh.
	var is_melee: bool = false
	## Bùa (skill nhắm địch không gây damage, VD Mê Tung ảo ảnh): trúng thì áp trạng thái này lên mục tiêu.
	var state_source_id: String = ""
	var state_attribs: Dictionary = {}
	var state_seconds: float = 0.0
	## Hiển thị trạng thái (StateVisuals) và bán kính vùng ảnh hưởng tại chỗ trúng (0 = chỉ mục tiêu trúng).
	var state_meta: Dictionary = {}
	var state_radius: float = 0.0
	## true = đòn chỉ mang trạng thái, không tính damage/không hiện "trượt".
	var is_state_only: bool = false
	## Người chơi đánh người chơi (kể cả bot PK) — nhân PK_DAMAGE_RATE_PERCENT (HitResolver.receive đặt).
	var is_pk: bool = false

## 1 đòn gồm NHIỀU loại damage cùng lúc (VD skill Đường Môn: vật lý + Độc sát) — mỗi loại đi qua
## resolve_damage() RIÊNG với giáp/% kháng của đúng loại đó (đúng VLTK: m_DamageAttribs lưu từng
## loại ở slot riêng, CalcDamage tính theo từng loại), rồi cộng lại thành 1 con số. `parts` =
## DamageType -> Vector2i(min, max). Trả về tổng damage; -1 nếu KHÔNG loại nào gây được damage.
## Gọi SAU roll_hit() (1 lần trượt/trúng cho cả đòn, không roll lại từng loại). `mods` = null nếu
## đòn không có chí mạng/tương khắc (VD quái va chạm).
## `out_dealt` (nếu truyền) được điền DamageType -> damage thực gây ra của từng loại — dùng để biết
## Băng/Độc sát có "trúng" không (ReceiveDamage gốc chỉ làm chậm/trúng độc khi CalcDamage loại đó > 0).
static func resolve_multi_damage(attacker: CombatantStats, defender: CombatantStats, defender_hp: int,
		parts: Dictionary, attacker_element: ElementTypes.ElementType, mods: HitModifiers = null,
		out_dealt: Dictionary = {}) -> int:
	var total := 0
	var any_hit := false
	for damage_type in parts:
		var range_value: Vector2i = parts[damage_type]
		if range_value.y <= 0:
			continue
		var ctx := DamageContext.new()
		ctx.min_damage = range_value.x
		ctx.max_damage = range_value.y
		ctx.damage_type = damage_type
		ctx.attacker_element = attacker_element
		ctx.defender_element = defender.element
		if mods:
			ctx.five_elements_damage_p = mods.five_elements_damage_p
			ctx.is_deadly_strike = mods.is_deadly_strike
			ctx.is_pk = mods.is_pk
			ctx.pk_damage_rate_percent = PK_DAMAGE_RATE_PERCENT
		ctx.attacker_five_elements_enhance = attacker.five_elements_enhance
		ctx.defender_five_elements_resist = defender.five_elements_resist
		ctx.defender_resist_percent = defender.get_capped_resist(damage_type)
		ctx.defender_flat_armor = defender.flat_armor.get(damage_type, 0)
		ctx.defender_current_hp = defender_hp
		var result := resolve_damage(ctx)
		if result.is_hit:
			any_hit = true
			total += result.final_damage
			out_dealt[damage_type] = result.final_damage
	return total if any_hit else -1

## Tính damage cuối cùng — NGUYÊN VĂN pipeline 9 bước của KNpc::CalcDamage gốc (xem
## docs/vltk_player_stats_reference.md mục 11.9 để đối chiếu). Hàm này KHÔNG tự roll hit/miss —
## gọi roll_hit() riêng TRƯỚC khi gọi hàm này (đúng thứ tự code gốc: CheckHitTarget ở ngoài,
## CalcDamage chỉ lo phần lượng damage sau khi đã xác định là trúng).
static func resolve_damage(ctx: DamageContext) -> DamageResult:
	var result := DamageResult.new()

	## Bước 1 — roll damage thô trong khoảng [min, max]. Code gốc còn xử lý case max<min bằng cách
	## roll quanh max thay vì min — giữ đúng để không lệch khi data skill nhập ngược (hiếm khi xảy
	## ra nhưng giữ để khớp 100% hành vi gốc).
	var damage: int
	var damage_range := ctx.max_damage - ctx.min_damage
	if damage_range < 0:
		damage = ctx.max_damage + randi_range(0, -damage_range)
	else:
		damage = ctx.min_damage + randi_range(0, damage_range)

	## Bước 2 — Chí mạng (2 loại tách biệt, không cộng dồn — xem ghi chú tại DamageContext ở trên).
	if ctx.is_deadly_strike:
		damage = int(damage * DEADLY_STRIKE_MULTIPLIER)
	if ctx.is_fatally_strike:
		var strike_percent := randi_range(FATALLY_STRIKE_MIN_PERCENT, FATALLY_STRIKE_MAX_PERCENT)
		damage = int(ctx.defender_current_hp * strike_percent / float(MAX_PERCENT))

	## Bước 3 — trừ giáp tuyệt đối theo loại damage (m_PhysicsArmor/m_ColdArmor/...).
	damage -= ctx.defender_flat_armor
	var resist := ctx.defender_resist_percent

	## Bước 4 — hệ số PK giữa 2 người chơi (KNpc.cpp:2588-2596) — áp TRƯỚC tương khắc ngũ hành,
	## đúng thứ tự dòng lệnh trong code gốc.
	if ctx.is_pk:
		damage = int(damage * ctx.pk_damage_rate_percent / float(MAX_PERCENT))
	if damage <= 0:
		result.is_hit = false
		return result

	## Bước 5 — Tương khắc Ngũ Hành (xem apply_five_elements_clash ở trên).
	var clash := apply_five_elements_clash(
		ctx.attacker_element, ctx.defender_element, ctx.five_elements_damage_p,
		ctx.attacker_five_elements_enhance, ctx.defender_five_elements_resist,
	)
	resist += clash.resist_delta
	damage += clash.damage_delta

	## Bước 6 — cap trần % kháng.
	if resist > MAX_RESIST:
		resist = MAX_RESIST

	## Bước 7 — (Mana Shield của game gốc CHƯA áp dụng ở đây — game này chưa có hệ thống khiên nội
	## lực hấp thụ damage; khi thiết kế xong, chèn logic vào đây đúng vị trí gốc, KHÔNG chèn trước
	## bước tương khắc hay sau bước trừ % kháng, để giữ đúng thứ tự pipeline VLTK.)

	## Bước 8 — trừ % kháng cuối cùng.
	damage -= int(damage * resist / float(MAX_PERCENT))

	## Bước 9 — damage <= 0 coi như không gây sát thương (return FALSE trong code gốc).
	if damage <= 0:
		result.is_hit = false
		return result

	result.final_damage = damage
	return result
