extends RefCounted
class_name ItemGenerator
## Sinh trang bị — NGUYÊN VĂN KItemGenerator::Gen_Equipment + Gen_MagicAttrib gốc VLTK:
##   1. Đồ gốc theo (loại chi tiết, loại cụ thể, cấp 1-10); thuộc tính gốc roll trong [min, max].
##   2. Mỗi dòng magic i có 1 "cấp magic" (magic_levels[i], 0 = dừng). Dòng chẵn = TIỀN TỐ, lẻ = HẬU TỐ.
##      Ứng viên = thuộc tính đúng tiền/hậu tố, có tỷ lệ rơi cho loại đồ này, ngũ hành khớp món đồ (-1 =
##      mọi hệ), CẤP thuộc tính <= cấp magic của dòng, chưa trùng loại với dòng trước.
##   3. Ngưỡng = ngẫu_nhiên(0..99) / (1 + may_mắn × 20 / 100) — chỉ giữ ứng viên có tỷ lệ rơi > ngưỡng;
##      chọn ngẫu nhiên 1, giá trị 3 tham số ngẫu nhiên trong khoảng.
## Dùng RandomNumberGenerator với seed riêng -> cùng seed + tham số ra cùng món đồ (server/client khớp).

static func generate(detail: int, particular: int, level: int, series: int, magic_levels: Array,
		luck: int = 0, gen_seed: int = -1) -> ItemInstance:
	var base_index := ItemDatabase.find_base(detail, particular, clampi(level, 1, 10))
	if base_index < 0:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = gen_seed if gen_seed >= 0 else randi()
	var item := ItemInstance.new()
	item.base_index = base_index
	item.series = series
	item.gen_seed = rng.seed
	item.luck = luck
	for entry in item.get_base().get("base", []):
		item.base_values.append([entry[0], rng.randi_range(int(entry[1]), int(entry[2]))])
	item.durability = item.get_max_durability()
	item.magic = _gen_magic(detail, series, magic_levels, luck, rng)
	return item

static func _gen_magic(detail: int, series: int, magic_levels: Array, luck: int, rng: RandomNumberGenerator) -> Array:
	var lines := []
	var used_kinds := {}
	for i in mini(magic_levels.size(), ItemInstance.MAX_MAGIC):
		var magic_level := int(magic_levels[i])
		if magic_level <= 0:
			break
		var want_prefix := 1 if i % 2 == 0 else 0
		var decide := int(rng.randi_range(0, 99) / (1.0 + luck * 20.0 / 100.0))
		var candidates := []
		for rec in ItemDatabase.get_magic_records():
			if int(rec["prefix"]) != want_prefix or used_kinds.has(rec["attrib"]):
				continue
			var rec_series := int(rec["series"])
			if rec_series != -1 and rec_series != series:
				continue
			if int(rec["level"]) > magic_level:
				continue
			var drop: Array = rec["drop"]
			if detail >= drop.size() or int(drop[detail]) <= decide:
				continue
			candidates.append(rec)
		if candidates.is_empty():
			break
		var pick: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		used_kinds[pick["attrib"]] = true
		var ranges: Array = pick["range"]
		var value := []
		for k in 3:
			value.append(rng.randi_range(int(ranges[k][0]), int(ranges[k][1])))
		lines.append({"attrib": pick["attrib"], "value": value, "name": pick["name"], "prefix": want_prefix == 1})
	return lines

## Sinh đồ HOÀNG KIM — KItemGenerator::Gen_GoldEquipment gốc: thuộc tính gốc + 6 dòng cố định (DefMagic) +
## 2 dòng mở rộng (ExpandMagic); mỗi dòng = min + (max - min) × độ_hoàn_mỹ / 10 (nGeneratorLevel/
## MAX_ITEM_LUCK). Ngũ hành cố định theo bảng hoàng kim.
static func generate_gold(gold_index: int, perfection: int = 10, gen_seed: int = -1) -> ItemInstance:
	var record := ItemDatabase.get_gold(gold_index)
	if record.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = gen_seed if gen_seed >= 0 else randi()
	var lv := clampi(perfection, 0, 10)
	var item := ItemInstance.new()
	item.gold_index = gold_index
	item.series = clampi(int(record["series"]), 0, 4)
	item.gen_seed = rng.seed
	item.luck = lv
	for entry in record["base"]:
		item.base_values.append([entry[0], rng.randi_range(int(entry[1]), int(entry[2]))])
	item.durability = item.get_max_durability()
	var lines: Array = record["magic"]
	for i in lines.size():
		var line = lines[i]
		if line == null:
			## Giữ chỗ trống để dòng sau không lệch chẵn/lẻ (tiền tố/ẩn) — gốc cũng giữ vị trí.
			if i < ItemInstance.MAX_MAGIC:
				item.magic.append({"attrib": "", "value": [0, 0, 0], "name": "", "prefix": i % 2 == 0})
			continue
		var value := []
		for k in 3:
			var lo := int(line["range"][k][0])
			var hi := int(line["range"][k][1])
			value.append(lo + (hi - lo) * lv / 10)
		var entry := {"attrib": line["attrib"], "value": value, "name": line["name"], "prefix": i % 2 == 0}
		if i < ItemInstance.MAX_MAGIC:
			item.magic.append(entry)
		else:
			item.expand_magic.append(entry)
	return item

## Vật phẩm KHÔNG phải trang bị (AddItem(genre, detail, particular, cấp, hệ) gốc): `misc_id` trong misc_items.json,
## `level` = cấp vật phẩm (0 = theo bảng), `series` = hệ (chỉ món có hệ: Sát Thủ lệnh/giản, Nguyên thạch), `amount` =
## số lượng chồng — tối đa cột Stack gốc (0/1 = không chồng được). null nếu mã không có.
static func generate_misc(misc_id: String, level: int = 0, series: int = 0, amount: int = 1) -> ItemInstance:
	var record := ItemDatabase.get_misc(misc_id)
	if record.is_empty():
		return null
	var item := ItemInstance.new()
	item.misc_id = misc_id
	item.item_level = level
	item.series = clampi(series, 0, 4)
	item.count = clampi(amount, 1, maxi(int(record.get("stack", 0)), 1))
	return item

## Đồ ngẫu nhiên cho nút TEST / rơi đồ thử: loại + loại cụ thể ngẫu nhiên, cấp đồ theo cấp nhân vật
## (cấp 10 nhân vật = đồ cấp 1, tối đa cấp 10), ngũ hành ngẫu nhiên, 0-6 dòng magic cùng cấp đồ.
static func random_equipment(character_level: int, luck: int = 0) -> ItemInstance:
	var details := ItemDatabase.Detail.values()
	var detail: int = details[randi_range(0, details.size() - 1)]
	var particulars := ItemDatabase.get_particulars(detail)
	if particulars.is_empty():
		return null
	var particular: int = particulars[randi_range(0, particulars.size() - 1)]
	var level := clampi(ceili(character_level / 10.0), 1, 10)
	var magic_levels := []
	for i in randi_range(0, ItemInstance.MAX_MAGIC):
		magic_levels.append(level)
	return generate(detail, particular, level, randi_range(0, 4), magic_levels, luck)
