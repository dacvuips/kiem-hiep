extends RefCounted
class_name StageRewards

## Hệ thống tính toán và trao phần thưởng theo Màn Vượt Ải ("Thập Đại Vượt Ải" 1x - 12x):
## - Màn cấp càng cao -> Thưởng càng xịn (Huyền Tinh cấp cao, Đồ xịn theo cấp, Ngân lượng lớn, Rương/Vật phẩm quý).
## - Cung cấp dữ liệu preview để hiển thị ô icon trực quan trên thẻ danh sách từng màn.
## - Trao phần thưởng thực tế vào túi đồ và ví ngân lượng khi Boss bị tiêu diệt.

const ICON_XUANJING := "res://assets/items/icons/item_xuanjingkuangshi.png"
const ICON_MONEY := "res://assets/items/icons/tongqian.png"
const ICON_EQUIP := "res://assets/items/icons/chuangguanbaoxiang.png"
const ICON_GOLD_BOX := "res://assets/items/icons/baoxiang_jin.png"
const ICON_EXP := "res://assets/items/icons/dahumaidan.png"

const XUANJING_ID := "6_1_147"
const XIANCAOLU_ID := "6_1_71"       ## Tiên Thảo Lộ
const KILLER_TOKEN_ID := "6_1_399"   ## Sát Thủ Lệnh
const GOLD_BOX_ID := "6_1_1476"      ## Bao Hoàng Kim

## Lấy bậc cấp độ màn (1 đến 12)
static func get_stage_tier(stage: StageData, stage_index: int = -1) -> int:
	if stage_index >= 0:
		return clampi(stage_index + 1, 1, 12)
	if stage != null and stage.stage_name != "":
		var regex := RegEx.new()
		if regex.compile(r"\((\d+)x\)") == OK:
			var res := regex.search(stage.stage_name)
			if res:
				return clampi(res.get_string(1).to_int(), 1, 12)
		if regex.compile(r"Ải\s*(\d+)") == OK:
			var res := regex.search(stage.stage_name)
			if res:
				return clampi(res.get_string(1).to_int(), 1, 12)
		if stage.boss_tier and stage.boss_tier.tier and stage.boss_tier.tier.level > 0:
			return clampi(roundi(stage.boss_tier.tier.level / 10.0), 1, 12)
	return 1

## Khoảng cấp của Huyền Tinh theo tier màn (1-12)
static func get_ht_range(tier: int) -> Vector2i:
	match clampi(tier, 1, 12):
		1: return Vector2i(1, 2)
		2: return Vector2i(2, 3)
		3: return Vector2i(3, 4)
		4: return Vector2i(3, 5)
		5: return Vector2i(4, 6)
		6: return Vector2i(5, 7)
		7: return Vector2i(6, 8)
		8: return Vector2i(7, 9)
		9: return Vector2i(7, 10)
		10: return Vector2i(8, 10)
		11: return Vector2i(9, 10)
		12: return Vector2i(9, 10)
	return Vector2i(1, 2)

## Khoảng ngân lượng theo tier màn (1-12)
static func get_gold_range(tier: int) -> Vector2i:
	match clampi(tier, 1, 12):
		1: return Vector2i(1000, 2500)
		2: return Vector2i(2500, 6000)
		3: return Vector2i(5000, 12000)
		4: return Vector2i(10000, 22000)
		5: return Vector2i(18000, 36000)
		6: return Vector2i(28000, 55000)
		7: return Vector2i(45000, 85000)
		8: return Vector2i(70000, 130000)
		9: return Vector2i(100000, 200000)
		10: return Vector2i(150000, 300000)
		11: return Vector2i(250000, 450000)
		12: return Vector2i(400000, 700000)
	return Vector2i(1000, 2500)

## Khoảng exp theo tier màn (1-12) — Nâng x20
static func get_exp_range(tier: int) -> Vector2i:
	match clampi(tier, 1, 12):
		1: return Vector2i(40000, 100000)
		2: return Vector2i(100000, 240000)
		3: return Vector2i(200000, 500000)
		4: return Vector2i(400000, 900000)
		5: return Vector2i(700000, 1500000)
		6: return Vector2i(1100000, 2200000)
		7: return Vector2i(1600000, 3200000)
		8: return Vector2i(2400000, 4800000)
		9: return Vector2i(3600000, 7000000)
		10: return Vector2i(5200000, 10000000)
		11: return Vector2i(7600000, 15000000)
		12: return Vector2i(11000000, 22000000)
	return Vector2i(40000, 100000)

## Định dạng hiển thị số
static func format_number(val: int) -> String:
	var s := str(abs(val))
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res

## Định dạng hiển thị tiền tệ
static func format_money(val: int) -> String:
	var s := str(abs(val))
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res + (" lượng" if val >= 0 else "")

static func format_money_short(val: int) -> String:
	if val >= 1000000:
		return "%.1fM" % (val / 1000000.0)
	if val >= 1000:
		return "%dK" % roundi(val / 1000.0)
	return str(val)

## Trả về danh sách preview phần thưởng để hiển thị trên thẻ chọn ải
static func get_previews_for_stage(stage: StageData, stage_index: int = -1) -> Array[Dictionary]:
	var tier := get_stage_tier(stage, stage_index)
	var ht_range := get_ht_range(tier)
	var gold_range := get_gold_range(tier)

	var list: Array[Dictionary] = []

	# 1. Điểm Kinh Nghiệm (cộng trực tiếp vào cấp thật của nhân vật)
	var exp_range := get_exp_range(tier)
	list.append({
		"id": "exp",
		"title": "Kinh Nghiệm",
		"badge": format_money_short(exp_range.x) + "~" + format_money_short(exp_range.y),
		"icon_path": ICON_EXP,
		"border_color": Color(0.35, 0.85, 0.45),
		"tooltip": "Kinh nghiệm vượt ải: %s ~ %s EXP\nĐược cộng trực tiếp vào cấp độ thật của nhân vật sau khi hoàn thành ải." % [
			format_number(exp_range.x), format_number(exp_range.y)
		]
	})

	# 2. Viên Huyền Tinh
	var ht_color := Color(1.0, 0.78, 0.25) if ht_range.y >= 8 else (Color(0.82, 0.48, 1.0) if ht_range.y >= 5 else Color(0.45, 0.75, 1.0))
	list.append({
		"id": "huyen_tinh",
		"title": "Huyền Tinh",
		"badge": "C%d~%d" % [ht_range.x, ht_range.y],
		"icon_path": ICON_XUANJING,
		"border_color": ht_color,
		"tooltip": "Huyền Tinh Khoáng Thạch (Cấp %d - %d)\nNguyên liệu quý dùng để luyện chế, tách khoáng và khảm nạm trang bị Tím/Hoàng Kim." % [ht_range.x, ht_range.y]
	})

	# 2. Trang Bị theo cấp
	list.append({
		"id": "equip",
		"title": "Trang Bị",
		"badge": "%dx" % tier,
		"icon_path": ICON_EQUIP,
		"border_color": Color(0.4, 0.8, 1.0),
		"tooltip": "Trang Bị Cấp %dx (Ngẫu nhiên)\nTrang bị trắng hoặc xanh với từ 1 đến 6 dòng thuộc tính ngũ hành nguyên bản VLTK." % tier
	})

	# 3. Ngân Lượng
	list.append({
		"id": "gold",
		"title": "Ngân Lượng",
		"badge": format_money_short(gold_range.x) + "~" + format_money_short(gold_range.y),
		"icon_path": ICON_MONEY,
		"border_color": Color(0.96, 0.82, 0.38),
		"tooltip": "Ngân lượng nhận được: %s ~ %s" % [format_money(gold_range.x), format_money(gold_range.y)]
	})

	# 4. Vật Phẩm Hiếm (Cho ải từ 6x trở lên)
	if tier >= 6:
		list.append({
			"id": "rare",
			"title": "Bảo Rương",
			"badge": "Hiếm",
			"icon_path": ICON_GOLD_BOX,
			"border_color": Color(1.0, 0.6, 0.2),
			"tooltip": "Tỉ lệ nhận thêm vật phẩm quý:\nTiên Thảo Lộ, Sát Thủ Lệnh, hoặc Bao Hoàng Kim giá trị cao."
		})

	return list

## Thực hiện quay phần thưởng ngẫu nhiên và trao vào túi/ví của profile
static func roll_stage_rewards(stage: StageData, profile: PlayerProfile, stage_index: int = -1) -> Dictionary:
	var tier := get_stage_tier(stage, stage_index)
	var ht_range := get_ht_range(tier)
	var gold_range := get_gold_range(tier)

	# 0. Roll Kinh nghiệm:
	var exp_range := get_exp_range(tier)
	var exp_amount := randi_range(exp_range.x, exp_range.y)
	exp_amount = maxi(500, (exp_amount / 500) * 500)

	# 1. Roll Huyền Tinh:
	var ht_lv := randi_range(ht_range.x, ht_range.y)
	if tier == 12 and randf() < 0.75:
		ht_lv = 10
	elif tier >= 10 and randf() < 0.50:
		ht_lv = maxi(ht_lv, 9)

	var ht_item := ItemGenerator.generate_misc(XUANJING_ID, ht_lv, 0, 1)

	# 2. Roll Ngân lượng:
	var gold_amount := randi_range(gold_range.x, gold_range.y)
	gold_amount = maxi(100, (gold_amount / 100) * 100)

	# 3. Roll Trang bị:
	var luck: int = profile.luck if profile and "luck" in profile else 0
	var equip_item := ItemGenerator.random_equipment(tier * 10, luck)

	# 4. Roll Vật phẩm quý (tuỳ may mắn theo bậc):
	var extra_item: ItemInstance = null
	var roll_val := randf()
	if tier >= 10 and roll_val < 0.50:
		extra_item = ItemGenerator.generate_misc(GOLD_BOX_ID, 1, 0, 1)
	elif tier >= 7 and roll_val < 0.40:
		extra_item = ItemGenerator.generate_misc(KILLER_TOKEN_ID, tier * 10, randi_range(0, 4), 1)
	elif tier >= 4 and roll_val < 0.35:
		extra_item = ItemGenerator.generate_misc(XIANCAOLU_ID, 1, 0, 1)

	# 5. Trao vào Profile nhân vật:
	var bag_full := false
	var old_level := profile.level if profile != null else 1
	if profile != null:
		profile.gold += gold_amount
		profile.add_exp(exp_amount)
		if ht_item != null:
			if not profile.add_item(ht_item):
				bag_full = true
		if equip_item != null:
			if not profile.add_item(equip_item):
				bag_full = true
		if extra_item != null:
			if not profile.add_item(extra_item):
				bag_full = true

		SaveManager.save_profile(profile)
		SaveManager.flush_online()

	return {
		"tier": tier,
		"stage_name": stage.stage_name if stage else "Ải %d" % tier,
		"exp": exp_amount,
		"old_level": old_level,
		"new_level": profile.level if profile else 1,
		"levels_gained": (profile.level - old_level) if profile else 0,
		"huyen_tinh": ht_item,
		"gold": gold_amount,
		"equipment": equip_item,
		"extra_item": extra_item,
		"bag_full": bag_full
	}
