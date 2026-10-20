extends RefCounted
class_name Equipment
## Logic trang bị đang mặc — NGUYÊN VĂN KItemList gốc VLTK, dùng chung cho player/quái/người chơi khác
## (chỉ nhận dữ liệu thuần: {ô: ItemInstance} + ngũ hành nhân vật). Kết quả đi vào CombatantStats.build()
## qua CombatantBuild — không cộng chỉ số ở nơi nào khác.

## Ô trang bị (ITEM_PART gốc) — 10 ô chính + ngựa.
enum Part { HEAD, BODY, BELT, WEAPON, FOOT, CUFF, AMULET, RING1, RING2, PENDANT, HORSE, MASK, MANTLE }
const PART_NAMES := {
	Part.HEAD: "Mũ", Part.BODY: "Áo", Part.BELT: "Thắt lưng", Part.WEAPON: "Vũ khí", Part.FOOT: "Giày",
	Part.CUFF: "Bao tay", Part.AMULET: "Dây chuyền", Part.RING1: "Nhẫn 1", Part.RING2: "Nhẫn 2",
	Part.PENDANT: "Ngọc bội", Part.HORSE: "Ngựa", Part.MASK: "Mặt nạ", Part.MANTLE: "Phi phong",
}

## Ô đeo theo loại đồ (nhẫn có 2 ô).
const DETAIL_TO_PARTS := {
	ItemDatabase.Detail.MELEE: [Part.WEAPON], ItemDatabase.Detail.RANGE: [Part.WEAPON],
	ItemDatabase.Detail.ARMOR: [Part.BODY], ItemDatabase.Detail.RING: [Part.RING1, Part.RING2],
	ItemDatabase.Detail.AMULET: [Part.AMULET], ItemDatabase.Detail.BOOT: [Part.FOOT],
	ItemDatabase.Detail.BELT: [Part.BELT], ItemDatabase.Detail.HELM: [Part.HEAD],
	ItemDatabase.Detail.CUFF: [Part.CUFF], ItemDatabase.Detail.PENDANT: [Part.PENDANT],
	ItemDatabase.Detail.HORSE: [Part.HORSE],
	ItemDatabase.Detail.MASK: [Part.MASK],
	ItemDatabase.Detail.MANTLE: [Part.MANTLE],
}

## Số dòng ẩn tối đa (MAX_ITEM_MAGICATTRIB / 2 gốc, trừ đi dòng chẵn — thực tế 3 dòng ẩn).
const MAX_ACTIVE := 3

## ms_ActivedEquip gốc: ô X được KÍCH HOẠT bởi 2 ô này (món ở đó tương sinh món ở X thì +1 dòng ẩn).
const ACTIVATED_BY := {
	Part.HEAD: [Part.BODY, Part.AMULET], Part.BODY: [Part.RING2, Part.BELT],
	Part.BELT: [Part.PENDANT, Part.CUFF], Part.WEAPON: [Part.AMULET, Part.BODY],
	Part.FOOT: [Part.WEAPON, Part.HEAD], Part.CUFF: [Part.FOOT, Part.RING1],
	Part.AMULET: [Part.BELT, Part.RING2], Part.RING1: [Part.WEAPON, Part.HEAD],
	Part.RING2: [Part.CUFF, Part.PENDANT], Part.PENDANT: [Part.FOOT, Part.RING1],
	Part.HORSE: [], Part.MASK: [], Part.MANTLE: [],
}

## g_nAccrueSeries gốc (KMath.cpp): Kim sinh Thủy, Mộc sinh Hỏa, Thủy sinh Mộc, Hỏa sinh Thổ, Thổ sinh Kim.
const ACCRUE := {
	ElementTypes.ElementType.KIM: ElementTypes.ElementType.THUY,
	ElementTypes.ElementType.MOC: ElementTypes.ElementType.HOA,
	ElementTypes.ElementType.THUY: ElementTypes.ElementType.MOC,
	ElementTypes.ElementType.HOA: ElementTypes.ElementType.THO,
	ElementTypes.ElementType.THO: ElementTypes.ElementType.KIM,
}

## Thuộc tính gốc KHÔNG cộng qua MagicAttribTable: damage vũ khí tính riêng (get_weapon_damage), độ bền
## và yêu cầu không phải chỉ số nhân vật.
const NON_STAT_ATTRIBS := ["weapondamagemin_v", "weapondamagemax_v", "weapondamageenhance_p", "durability_v"]

static func accrues(src_series: int, dst_series: int) -> bool:
	return ACCRUE.get(src_series, -1) == dst_series

## KItemList::GetEquipEnhance — số dòng ẩn được bật của món ở mỗi ô (0-3): +1 nếu ngũ hành nhân vật
## tương sinh món đồ, +1 cho mỗi món ở 2 ô kích hoạt (ACTIVATED_BY) tương sinh món đồ.
## Ô ngựa trở đi luôn mở hết (nPlace >= itempart_horse gốc). Hoàng kim mặc ĐỦ BỘ (>= need2 món cùng bộ)
## cũng mở hết (IsEnoughToActive gốc).
static func get_active_counts(equipped: Dictionary, character_series: int) -> Dictionary:
	var counts := {}
	var set_counts := get_set_counts(equipped)
	for part in equipped:
		var item: ItemInstance = equipped[part]
		if item == null:
			continue
		if part >= Part.HORSE:
			counts[part] = MAX_ACTIVE
			continue
		var group := item.get_set_group()
		if group > 0 and item.get_set_need("need2") > 0 and set_counts.get(group, 0) >= item.get_set_need("need2"):
			counts[part] = MAX_ACTIVE
			continue
		var n := 1 if accrues(character_series, item.series) else 0
		for other_part in ACTIVATED_BY.get(part, []):
			var other: ItemInstance = equipped.get(other_part)
			if other and accrues(other.series, item.series):
				n += 1
		counts[part] = n
	return counts

## Số món HOÀNG KIM đang mặc theo bộ (Group) — GetGoldEquipEnhance gốc: 2 nhẫn cùng bộ chỉ tính 1.
static func get_set_counts(equipped: Dictionary) -> Dictionary:
	var counts := {}
	for part in equipped:
		var item: ItemInstance = equipped[part]
		if item == null:
			continue
		var group := item.get_set_group()
		if group <= 0:
			continue
		if part == Part.RING1 and equipped.has(Part.RING2) and (equipped[Part.RING2] as ItemInstance) != null and (equipped[Part.RING2] as ItemInstance).get_set_group() == group:
			continue
		counts[group] = counts.get(group, 0) + 1
	return counts

## Số dòng mở rộng (2 dòng cuối hoàng kim) đang bật: số món cùng bộ / need1 (tối đa 2); đủ bộ thì bật hết.
static func get_expand_active(item: ItemInstance, equipped: Dictionary) -> int:
	if not item.is_gold() or item.expand_magic.is_empty():
		return 0
	var count: int = get_set_counts(equipped).get(item.get_set_group(), 0)
	var need2 := item.get_set_need("need2")
	if need2 > 0 and count >= need2:
		return item.expand_magic.size()
	return mini(count / maxi(item.get_set_need("need1"), 1), item.expand_magic.size())

## Các dòng magic CÓ HIỆU LỰC của 1 món với `active` dòng ẩn được bật — KItem::ApplyMagicAttribToNPC:
## dòng chẵn (tiền tố) luôn hiệu lực; dòng lẻ (hậu tố) bật lần lượt theo `active`.
static func get_effective_magic(item: ItemInstance, active: int) -> Array:
	var out := []
	var remaining := active
	for i in item.magic.size():
		if item.magic[i]["attrib"] == "":
			continue  ## ô trống (INVALID_ATTRIB gốc) — không tốn lượt kích hoạt
		if i % 2 == 0:
			out.append(item.magic[i])
		elif remaining > 0:
			out.append(item.magic[i])
			remaining -= 1
	return out

## Nguồn thuộc tính của toàn bộ đồ đang mặc — mỗi món 1 {tên: Vector3i}, đưa vào CombatantStats.build().
static func get_attrib_sources(equipped: Dictionary, character_series: int) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	var counts := get_active_counts(equipped, character_series)
	for part in equipped:
		var item: ItemInstance = equipped[part]
		if item == null:
			continue
		var source := {}
		for entry in item.base_values:
			if entry[0] in NON_STAT_ATTRIBS:
				continue
			_add(source, entry[0], Vector3i(int(entry[1]), 0, 0))
		var lines := get_effective_magic(item, counts.get(part, 0))
		lines.append_array(item.expand_magic.slice(0, get_expand_active(item, equipped)))
		for line in lines:
			if line["attrib"] in NON_STAT_ATTRIBS:
				continue
			var v: Array = line["value"]
			_add(source, line["attrib"], Vector3i(int(v[0]), int(v[1]), int(v[2])))
		sources.append(source)
	return sources

static func _add(source: Dictionary, attrib_name: String, v: Vector3i) -> void:
	source[attrib_name] = source.get(attrib_name, Vector3i.ZERO) + v

## KItemList::GetWeaponDamage — {"kind": "melee"/"range"/"", "min", "max"}:
##   (damage gốc + dòng weapondamagemin/max_v) × (100% + weapondamageenhance_p%) — gốc cộng dòng magic
##   vũ khí của CẢ 6 dòng, không xét kích hoạt. Không cầm vũ khí -> kind "" (tay không).
static func get_weapon_damage(equipped: Dictionary) -> Dictionary:
	var weapon: ItemInstance = equipped.get(Part.WEAPON)
	if weapon == null:
		return {"kind": "", "min": 0, "max": 0}
	var add_min := 0
	var add_max := 0
	var enhance := 0
	for line in weapon.magic:
		match line["attrib"]:
			"weapondamagemin_v": add_min += int(line["value"][0])
			"weapondamagemax_v": add_max += int(line["value"][0])
			"weapondamageenhance_p": enhance += int(line["value"][0])
	return {
		"kind": "melee" if weapon.get_detail() == ItemDatabase.Detail.MELEE else "range",
		"min": (weapon.get_base_value("weapondamagemin_v") + add_min) * (100 + enhance) / 100,
		"max": (weapon.get_base_value("weapondamagemax_v") + add_max) * (100 + enhance) / 100,
	}

## Thứ tự môn phái trong requiremenpai = settings/faction/门派设定.ini gốc.
## Bản 15 phái thêm 10 Hoa Sơn, 11 Vũ Hồn, 12 Tiêu Dao, 13 Dương Gia, 14 Minh Giáo (= tools/vltk_source.SECTS).
const MENPAI_ORDER := ["thieu_lam", "thien_vuong_bang", "duong_mon", "ngu_doc_giao", "nga_mi",
	"thuy_yen_mon", "cai_bang", "thien_nhan_giao", "vo_dang", "con_lon",
	"hoa_son", "vu_hon", "tieu_dao", "duong_gia", "minh_giao"]

## Chỉ số nhân vật để xét yêu cầu — KItemList::EnoughAttrib gốc so với chỉ số HIỆN TẠI (m_nCurStrength...,
## ĐÃ CỘNG đồ đang mặc/nội tại, VD nhẫn +20 Sức mạnh giúp mặc được vũ khí yêu cầu cao hơn), không phải
## điểm gốc. Tính 1 lần rồi dùng cho nhiều món (Hành trang 60 ô) để khỏi dựng lại chỉ số mỗi món.
## `exclude_part` = bỏ món ở ô đó (khi thay đồ vào ô đang có đồ).
static func get_requirement_context(profile: PlayerProfile, exclude_part: int = -1) -> Dictionary:
	if exclude_part < 0:
		return context_from_stats(profile, profile.get_combat_stats())
	var b := profile.to_build()
	b.equipment.erase(exclude_part)
	return context_from_stats(profile, CombatantStats.build(b))

static func context_from_stats(profile: PlayerProfile, stats: CombatantStats) -> Dictionary:
	return {"level": profile.level, "str": stats.strength, "dex": stats.dexterity, "vit": stats.vitality,
		"eng": stats.energy, "series": int(profile.get_element()), "sex": int(profile.gender),
		"sect": profile.sect_id, "translife": profile.get("translife") if "translife" in profile else 0}

## 1 yêu cầu ([tên requireXXX, giá trị]) đã đạt chưa — EnoughAttrib gốc. `ctx` = get_requirement_context.
static func is_requirement_met(req: Array, ctx: Dictionary) -> bool:
	var value := int(req[1])
	match req[0]:
		"requirelevel": return ctx["level"] >= value
		"requirestr": return ctx["str"] >= value
		"requiredex": return ctx["dex"] >= value
		"requirevit": return ctx["vit"] >= value
		"requireeng": return ctx["eng"] >= value
		"requireseries": return ctx["series"] == value
		"requiresex": return ctx["sex"] == value
		"requiremenpai":
			return value >= 0 and value < MENPAI_ORDER.size() and ctx["sect"] == MENPAI_ORDER[value]
		"require_translife":
			return ctx.get("translife", 0) >= value
	return true

## Các yêu cầu CHƯA đạt (rỗng = mặc được) — mỗi phần tử là câu yêu cầu (đúng chữ MagicDesc) để hiện.
static func get_unmet_requirements(item: ItemInstance, profile: PlayerProfile, ctx: Dictionary = {}) -> Array[String]:
	if ctx.is_empty():
		ctx = get_requirement_context(profile)
	var unmet: Array[String] = []
	for req in item.get_requirements():
		if not is_requirement_met(req, ctx):
			unmet.append(ItemText.format_attrib(req[0], [int(req[1]), 0, 0]))
	return unmet

## Loại vũ khí đang cầm theo cách KSkill::CanCastSkill gốc so với EqtLimit của skill: -1 = tay không / găng (Triền thủ,
## HAND_PARTICULAR = 6), 0 kiếm, 1 đao, 2 côn, 3 thương, 4 chùy, 5 song đao, 7 đao thuẫn, 8 thuẫn đao (bản 15 phái);
## ám khí = 100 + loại (100 tiêu, 101 đao, 102 tiễn, 103 cầm, 104 cung).
static func get_weapon_class(equipped: Dictionary) -> int:
	var weapon: ItemInstance = equipped.get(Part.WEAPON)
	if weapon == null:
		return -1
	var particular := int(weapon.get_base().get("particular", 0))
	if weapon.get_detail() == ItemDatabase.Detail.RANGE:
		return 100 + particular
	return -1 if particular == 6 else particular

static func can_use(item: ItemInstance, profile: PlayerProfile, ctx: Dictionary = {}) -> bool:
	return get_unmet_requirements(item, profile, ctx).is_empty()

# ---------------------------------------------------------------- ngoại hình

## Trang bị đang mặc -> mã hình nhân vật ghép bộ phận {helm, armor, weapon, horse} theo KItemChangeRes gốc: mũ đổi
## đầu/tóc, áo đổi vai/thân/tay, vũ khí đổi 2 lớp vũ khí + bộ động tác, ngựa (-1 = đi bộ) thêm 3 lớp ngựa + bộ
## động tác cưỡi. Ô trống -> hình mặc định. Đồ hoàng kim dùng hình riêng (GoldEquipRes) nếu đã có trong đợt hình,
## không thì theo loại/cấp của chính nó. Online chỉ cần gửi 4 số này.
## Hỗ trợ MẶT NẠ (Part.MASK): Dịch dung biến đổi giới tính, phong thái (Liễu Thanh Thanh -> mỹ nhân áo lụa tím,
## Đạo Thanh Chân Nhân -> đạo sĩ lam bào, Chiến Thần -> thiết khôi xích giáp, Hoàng Kim -> ánh hào quang kim sắc).
static func get_appearance(equipped: Dictionary, gender: String = "male", riding: bool = true) -> Dictionary:
	var mask_item: ItemInstance = equipped.get(Part.MASK)
	var is_masked: bool = (mask_item != null)
	var disguise_title := ""
	var mask_gender := gender
	var mask_modulate := Color.WHITE
	var mask_particular := -1

	if is_masked:
		var m_base := mask_item.get_base()
		mask_particular = int(m_base.get("particular", 0))
		match mask_particular:
			1: # Mặt Nạ - Liễu Thanh Thanh
				mask_gender = "female"
				disguise_title = "Liễu Thanh Thanh"
				mask_modulate = Color(1.08, 0.88, 1.08, 1.0)
			2: # Mặt Nạ - Đạo Thanh Chân Nhân
				mask_gender = "male"
				disguise_title = "Đạo Thanh Chân Nhân"
				mask_modulate = Color(0.92, 0.98, 1.15, 1.0)
			3: # Mặt Nạ Chiến Thần
				disguise_title = "Chiến Thần"
				mask_modulate = Color(1.25, 0.82, 0.78, 1.0)
			4: # Mặt Nạ Hoàng Kim
				disguise_title = "Hoàng Kim Chí Tôn"
				mask_modulate = Color(1.35, 1.25, 0.72, 1.0)
			0, _:
				disguise_title = "Vô Danh Hiệp Khách"
				mask_modulate = Color(0.88, 0.90, 0.98, 1.0)

	var target_gender := mask_gender if is_masked else gender
	var data := AvatarData.get_for(target_gender)
	var result := {
		"helm": data.default_res("helm"),
		"armor": data.default_res("armor"),
		"weapon": data.default_res("weapon"),
		"horse": data.default_res("horse"),
		"gender": target_gender,
		"is_masked": is_masked,
		"disguise_title": disguise_title,
		"modulate": mask_modulate,
		"mask_particular": mask_particular,
		"mask_name": mask_item.get_display_name() if mask_item else "",
		"mask_icon": mask_item.get_icon() if mask_item else null,
	}

	for part in [Part.HEAD, Part.BODY, Part.WEAPON, Part.HORSE]:
		var item: ItemInstance = equipped.get(part)
		if item == null:
			continue
		var base := item.get_base()
		var particular := int(base.get("particular", 0))
		var level := int(base.get("level", 1))
		var detail := int(base.get("detail", -1))
		if item.is_gold():
			var group: String = {ItemDatabase.Detail.HELM: "helm", ItemDatabase.Detail.ARMOR: "armor",
					ItemDatabase.Detail.MELEE: "weapon", ItemDatabase.Detail.RANGE: "weapon"}.get(detail, "")
			var gold_res := data.res_for_gold(int(base.get("row", -1)), group) if group != "" else -1
			if gold_res >= 0:
				result[group] = gold_res
				continue
		match detail:
			ItemDatabase.Detail.HELM:
				result["helm"] = data.res_for_item("helm", particular, level)
			ItemDatabase.Detail.ARMOR:
				result["armor"] = data.res_for_item("armor", particular, level)
			ItemDatabase.Detail.MELEE:
				result["weapon"] = data.res_for_item("melee", particular, level)
			ItemDatabase.Detail.RANGE:
				result["weapon"] = data.res_for_item("range", particular, level)
			ItemDatabase.Detail.HORSE:
				result["horse"] = data.res_for_item("horse", particular, level)

	# Nếu có mặt nạ dịch dung đặc thù, định hình ngoại hình đại diện theo nhân vật dịch dung:
	if is_masked:
		match mask_particular:
			1: # Liễu Thanh Thanh -> mỹ nhân áo lụa
				result["helm"] = data.res_for_item("helm", 1, 10)
				result["armor"] = data.res_for_item("armor", 1, 10)
			2: # Đạo Thanh Chân Nhân -> đạo bào uy nghiêm
				result["helm"] = data.res_for_item("helm", 0, 8)
				result["armor"] = data.res_for_item("armor", 0, 8)
			3: # Chiến Thần -> thiết khôi chiến giáp
				result["helm"] = data.res_for_item("helm", 2, 10)
				result["armor"] = data.res_for_item("armor", 2, 10)

	if not riding:
		result["horse"] = -1  ## xuống ngựa: đi bộ, bộ động tác thường
	return result
