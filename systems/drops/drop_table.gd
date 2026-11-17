extends RefCounted
class_name DropTable
## Bảng RỚT ĐỒ khi quái chết — chép từ script server gốc `script/global/droprate/droprate<N>x.lua` (hàm DropRate(NpcIndex), được
## KNpc::DoDeath gọi khi quái chết). Engine C++ KHÔNG đọc các file .ini tỉ lệ rớt (npcdroprate*.ini) — mọi việc do script quyết.
##
## Mỗi lần quái thường chết (không phải boss xanh): nSel = ngẫu_nhiên(0..15)
##   nSel > 6          : không rớt gì
##   nSel < 2          : rớt TIỀN (cấp 0x-6x) / nSel == 2 (cấp 7x-10x)
##   nSel == 5         : 50% rớt Thần bí đồ chí / Địa đồ chí (6_1_206; cấp 0x-1x: 25% do RANDOMC(205, 391))
##   nSel == 4         : 1/30 rớt TRANG BỊ XANH (số dòng magic ngẫu nhiên theo cấp)
##   Mật đồ thần bí (6_1_196): rớt theo bảng npcdroprate*.ini gốc (10: 2000/330000, 20-90: 2000/1000000, 110+: 3500/2000000).
## Cấp của bảng (0x..10x) chọn theo cấp quái / 10. CHÚ Ý: script gốc gắn bảng cho từng quái qua SetNpcDropScript trong script
## map — chưa nhập — nên đây là SUY RA từ cấp quái, không phải dữ liệu gốc.

## [tiền_min, tiền_max, cấp_đồ_min, cấp_đồ_max, may_mắn, dòng_magic_min, dòng_magic_max, nSel_rớt_tiền (<, hoặc == khi >= 7x)]
const TIERS := [
	[30, 70, 1, 2, 0, 1, 2],     # 0x
	[30, 170, 1, 3, 0, 1, 2],    # 1x
	[70, 200, 2, 3, 0, 1, 2],    # 2x
	[100, 230, 2, 4, 0, 1, 2],   # 3x
	[130, 250, 3, 5, 0, 1, 2],   # 4x
	[150, 280, 4, 6, 1, 1, 2],   # 5x
	[180, 290, 5, 7, 1, 1, 2],   # 6x
	[210, 340, 6, 8, 0, 1, 2],   # 7x
	[240, 400, 7, 9, 0, 1, 2],   # 8x
	[500, 750, 8, 10, 0, 1, 2],  # 9x
	[500, 750, 8, 10, 0, 1, 2],  # 10x
]
## KindItem trong SourceDrop.lua: {loại chi tiết, loại cụ thể nhỏ nhất, lớn nhất} — loại chi tiết khớp ItemDatabase.Detail.
const KIND_ITEM := [
	[ItemDatabase.Detail.ARMOR, 0, 27], [ItemDatabase.Detail.AMULET, 0, 1], [ItemDatabase.Detail.BELT, 0, 1],
	[ItemDatabase.Detail.BOOT, 0, 3], [ItemDatabase.Detail.HELM, 0, 13], [ItemDatabase.Detail.CUFF, 0, 1],
	[ItemDatabase.Detail.PENDANT, 0, 1], [ItemDatabase.Detail.RING, 0, 0],
	[ItemDatabase.Detail.MELEE, 0, 5], [ItemDatabase.Detail.RANGE, 0, 2],
]
## Số dòng magic của đồ do BOSS XANH rớt theo cấp bảng 0x..10x: [min, max] (nNumLine trong khối "boss xanh" của droprate<N>x.lua; 1x = 0 dòng).
const BOSS_LINES := [[1, 2], [0, 0], [2, 3], [2, 3], [2, 3], [2, 4], [2, 4], [2, 5], [2, 5], [3, 6], [3, 6]]
const BOSS_DROPS := 5                 ## dropnum: boss xanh rớt 5 lần
const BLUE_BOSS_CHANCE := 0.005       ## 0,5% mỗi lần quái sinh / sinh lại (gốc: RANDOM(150) < 2, chú thích "xác suất 2%" — giảm theo yêu cầu)
const BLUE_ITEM_ONE_IN := 30
## Mã vật phẩm Dã Tẩu / Mật đồ trong misc_items.json (magicscript.txt gốc):
const MISC_MAT_DO := "6_1_196"        ## Mật đồ thần bí
const MISC_DIA_DO_CHI := "6_1_206"    ## Thần bí đồ chí (Địa đồ chí — tasklink_goods.lua)
const MISC_MAT_CHI := "6_1_213"       ## Thần Bí Lộ Chí (Mật chí / Địa chí — tasklink_goods_secret.lua)
## Hệ số (1.0 = đúng server gốc) — game server online đặt theo "Thông số game" ở web Admin (set_rates, qua nhịp tim):
##   item_rate_mult: tỉ lệ rơi trang bị xanh ×N (gốc 1/30 khi nSel == 4 -> N/30); money_rate_mult: SỐ TIỀN rơi ra ×N (tần suất giữ nguyên).
static var item_rate_mult := 1.0
static var money_rate_mult := 1.0
const ITEM_RATE_MAX := 20.0
const MONEY_RATE_MAX := 10.0

## Đặt hệ số (kẹp trong khoảng cho phép — server tài khoản đã kiểm, đây kiểm lại phòng dữ liệu lạ).
static func set_rates(item: float, money: float) -> void:
	item_rate_mult = clampf(item, 1.0, ITEM_RATE_MAX)
	money_rate_mult = clampf(money, 1.0, MONEY_RATE_MAX)

static func _money(t: Array, k := 1) -> int:
	return int(randi_range(t[0], t[1]) * k * money_rate_mult)

## Rơi trang bị xanh với tỉ lệ gốc `base` (VD 1/30) nhân item_rate_mult.
static func _item_chance(base: float) -> bool:
	return randf() < minf(1.0, base * item_rate_mult)

static func tier_of(monster_level: int) -> int:
	return clampi(monster_level / 10, 0, 10)

static func _try_append_misc(out: Array, misc_id: String, chance: float) -> void:
	if chance <= 0.0 or randf() >= chance:
		return
	var item := ItemGenerator.generate_misc(misc_id, 1, 0, 1)
	if item != null:
		out.append({"type": "item", "item": item})

static func _mat_do_rate_for_tier(tier: int) -> float:
	if tier <= 1:
		return 2000.0 / 330000.0   ## npcdroprate10.ini (~0.606%)
	if tier <= 9:
		return 2000.0 / 1000000.0  ## npcdroprate20..90.ini (0.200%)
	return 3500.0 / 2000000.0      ## npcdroprate110..119.ini (0.175%)

## Sinh ngẫu nhiên 1 món trang bị Hoàng Kim Môn Phái
static func roll_sect_gold_item() -> ItemInstance:
	var indices := ItemDatabase.get_sect_gold_indices()
	if indices.is_empty():
		var total := ItemDatabase.get_gold_count()
		if total <= 0:
			return null
		return ItemGenerator.generate_gold_random(randi() % total)
	var g_idx: int = indices[randi() % indices.size()]
	return ItemGenerator.generate_gold_random(g_idx)

## Sinh ngẫu nhiên 1 con ngựa
static func roll_horse(series: int = -1) -> ItemInstance:
	var indices := ItemDatabase.get_horse_base_indices()
	if indices.is_empty():
		return null
	var base_idx: int = indices[randi() % indices.size()]
	var eq_rec: Dictionary = ItemDatabase.get_base(base_idx)
	if eq_rec.is_empty():
		return null
	var detail := int(eq_rec.get("detail", ItemDatabase.Detail.HORSE))
	var particular := int(eq_rec.get("particular", 0))
	var level := int(eq_rec.get("level", 1))
	var s := series if series >= 0 else randi_range(0, 4)
	return ItemGenerator.generate(detail, particular, level, s, [])

## Sinh ngẫu nhiên 1 vật phẩm trong Hiệu Thuốc (dược phẩm, thổ địa phù)
static func roll_pharmacy_item() -> ItemInstance:
	var shop_items := PotionShop.items()
	if shop_items.is_empty():
		return null
	var mid: String = shop_items[randi() % shop_items.size()]
	return ItemGenerator.generate_misc(mid)

## Kết quả: mảng [{"type": "money", "amount": int} | {"type": "item", "item": ItemInstance}]. Rỗng = không rớt gì.
## Quy định mới: quái chỉ rớt Đồ Hoàng Kim Môn Phái ngẫu nhiên, Ngựa ngẫu nhiên, và vật phẩm trong Hiệu Thuốc!
static func roll(monster_level: int, series: int, extra_luck: int = 0) -> Array:
	var tier := tier_of(monster_level)
	var t: Array = TIERS[tier]
	var out: Array = []

	# 1. Rơi vật phẩm trong "Hiệu Thuốc" (máu, nội lực, song hồi, giải độc, thổ địa phù)
	# Tỉ lệ 35% mỗi quái thường để người chơi luôn có thuốc nhặt dùng
	var potion_chance := minf(1.0, 0.35 * item_rate_mult)
	if randf() < potion_chance:
		var pot := roll_pharmacy_item()
		if pot != null:
			out.append({"type": "item", "item": pot})

	# 2. Rơi Trang Bị Hoàng Kim Môn Phái ngẫu nhiên (thay thế đồ xanh)
	# Tỉ lệ cơ bản 15% (tăng theo may mắn & item_rate_mult)
	var gold_chance := minf(1.0, (0.15 + float(extra_luck) * 0.01) * item_rate_mult)
	if randf() < gold_chance:
		var gold_item := roll_sect_gold_item()
		if gold_item != null:
			out.append({"type": "item", "item": gold_item})

	# 3. Rơi Ngựa ngẫu nhiên
	# Tỉ lệ 5% mỗi quái thường
	var horse_chance := minf(1.0, 0.05 * item_rate_mult)
	if randf() < horse_chance:
		var horse := roll_horse(series)
		if horse != null:
			out.append({"type": "item", "item": horse})

	# 4. Rơi tiền vạn
	var money_chance := 0.25
	if randf() < money_chance:
		out.append({"type": "money", "amount": _money(t)})

	# 5. Dã Tẩu (Địa đồ chí / Mật đồ thần bí) - giữ tỉ lệ nhiệm vụ
	var scroll_chance := 0.25 if tier <= 1 else (1.0 if tier == 9 else 0.50)
	var sel := randi_range(0, 15)
	if sel == 5:
		_try_append_misc(out, MISC_DIA_DO_CHI, scroll_chance)
	_try_append_misc(out, MISC_MAT_DO, _mat_do_rate_for_tier(tier))

	return out

## Boss xanh rớt 5 lần (dropnum): rơi Đồ Hoàng Kim Môn Phái, Ngựa và Dược phẩm Hiệu Thuốc!
static func roll_blue_boss(monster_level: int, series: int, extra_luck: int = 0) -> Array:
	var tier := tier_of(monster_level)
	var t: Array = TIERS[tier]
	var out: Array = []
	for i in BOSS_DROPS:
		var sel := randi_range(0, 50) if tier >= 6 else randi_range(0, 20)
		var money := sel > 40 if tier >= 6 else sel < 5
		if money:
			out.append({"type": "money", "amount": _money(t)})
		elif sel == 8:
			## droprate0x..10x.lua: boss xanh nSel == 8 -> Thần Bí Lộ Chí / Mật chí (6_1_213)
			_try_append_misc(out, MISC_MAT_CHI, 1.0)
		elif sel <= 5 or (tier >= 6 and sel in [9, 10]):
			continue   ## (6x+) 9 = bí kíp, 10 = chìa khoá nhiệm vụ — không có trong game
		else:
			if randf() < 0.25:
				var horse := roll_horse(series)
				if horse != null:
					out.append({"type": "item", "item": horse})
			else:
				var gold_item := roll_sect_gold_item()
				if gold_item != null:
					out.append({"type": "item", "item": gold_item})

	# Boss xanh luôn rớt thêm 1-2 bình thuốc từ Hiệu Thuốc
	for k in randi_range(1, 2):
		var pot := roll_pharmacy_item()
		if pot != null:
			out.append({"type": "item", "item": pot})

	return out

## BOSS HOÀNG KIM (Thập Đại Boss - source gốc VLTK): rơi cực nhiều bảo vật:
##   - 4-6 đống tiền lớn (20.000 - 50.000 lượng);
##   - 4-6 trang bị Hoàng Kim Môn Phái ngẫu nhiên;
##   - 1-2 Ngựa ngẫu nhiên;
##   - 3-5 vật phẩm Hiệu Thuốc (dược phẩm, thổ địa phù);
##   - 2-3 Huyền Tinh Khoáng Thạch (6_1_147);
##   - 1-2 Thủy Tinh (Lam/Tử/Lục) hoặc Tinh Hồng Bảo Thạch;
##   - 50% rơi Võ Lâm Mật Tịch / Tẩy Tủy Kinh / Tiên Thảo Lộ;
##   - 30% rơi Bí Kíp 90 Môn Phái.
static func roll_gold_boss(monster_level: int, series: int) -> Array:
	var out: Array = []
	var tier := 10
	var t: Array = (TIERS[tier] as Array).duplicate()
	t[2] = 9
	t[3] = 10

	for i in randi_range(4, 6):
		out.append({"type": "money", "amount": int(randi_range(20000, 50000) * money_rate_mult)})

	# Rơi 4-6 món Trang Bị Hoàng Kim Môn Phái
	for i in randi_range(4, 6):
		var gold_item := roll_sect_gold_item()
		if gold_item != null:
			out.append({"type": "item", "item": gold_item})

	# Rơi 1-2 Ngựa ngẫu nhiên
	for i in randi_range(1, 2):
		var horse := roll_horse(series)
		if horse != null:
			out.append({"type": "item", "item": horse})

	# Rơi 3-5 vật phẩm Hiệu Thuốc
	for i in randi_range(3, 5):
		var pot := roll_pharmacy_item()
		if pot != null:
			out.append({"type": "item", "item": pot})

	for i in randi_range(2, 3):
		var ht := ItemGenerator.generate_misc("6_1_147", randi_range(5, 8), 0, randi_range(1, 2))
		if ht != null:
			out.append({"type": "item", "item": ht})

	for i in randi_range(1, 2):
		var tt_keys := ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]
		var pick_key: String = tt_keys[randi() % tt_keys.size()]
		var tt := ItemGenerator.generate_misc(pick_key, 1, 0, 1)
		if tt != null:
			out.append({"type": "item", "item": tt})

	if randf() < 0.50:
		var book_keys := ["6_1_26", "6_1_22", "6_1_71"]
		var pick_book: String = book_keys[randi() % book_keys.size()]
		var bk := ItemGenerator.generate_misc(pick_book, 1, 0, 1)
		if bk != null:
			out.append({"type": "item", "item": bk})

	if randf() < 0.30:
		var sect_bk_id := "6_1_%d" % randi_range(3993, 4022)
		var sect_bk := ItemGenerator.generate_misc(sect_bk_id, 1, 0, 1)
		if sect_bk != null:
			out.append({"type": "item", "item": sect_bk})

	return out

## TIỂU HOÀNG KIM (Diệu Như, Liễu Thanh Thanh, Trương Tông Chính - drop_tieuhk.lua gốc):
##   - 2-4 đống tiền (10.000 - 25.000 lượng);
##   - 3-5 Trang Bị Hoàng Kim Môn Phái ngẫu nhiên;
##   - 1 Ngựa ngẫu nhiên;
##   - 2-4 vật phẩm Hiệu Thuốc;
##   - 1-2 Huyền Tinh (cấp 4-6);
##   - 1 Thủy Tinh (Lam/Tử/Lục) hoặc Tinh Hồng Bảo Thạch;
##   - 25% rơi Mật tịch / Tẩy tủy kinh / Tiên thảo lộ.
static func roll_small_gold_boss(monster_level: int, series: int) -> Array:
	var out: Array = []
	var tier := 10
	var t: Array = (TIERS[tier] as Array).duplicate()
	t[2] = 9
	t[3] = 10

	for i in randi_range(2, 4):
		out.append({"type": "money", "amount": int(randi_range(10000, 25000) * money_rate_mult)})

	# Rơi 3-5 Trang Bị Hoàng Kim Môn Phái ngẫu nhiên
	for i in randi_range(3, 5):
		var gold_item := roll_sect_gold_item()
		if gold_item != null:
			out.append({"type": "item", "item": gold_item})

	# Rơi 1 Ngựa ngẫu nhiên
	var horse := roll_horse(series)
	if horse != null:
		out.append({"type": "item", "item": horse})

	# Rơi 2-4 vật phẩm Hiệu Thuốc
	for i in randi_range(2, 4):
		var pot := roll_pharmacy_item()
		if pot != null:
			out.append({"type": "item", "item": pot})

	for i in randi_range(1, 2):
		var ht := ItemGenerator.generate_misc("6_1_147", randi_range(4, 6), 0, randi_range(1, 2))
		if ht != null:
			out.append({"type": "item", "item": ht})

	if randf() < 0.60:
		var tt_keys := ["4_238_1", "4_239_1", "4_240_1", "4_353_1"]
		var pick_key: String = tt_keys[randi() % tt_keys.size()]
		var tt := ItemGenerator.generate_misc(pick_key, 1, 0, 1)
		if tt != null:
			out.append({"type": "item", "item": tt})

	if randf() < 0.25:
		var book_keys := ["6_1_26", "6_1_22", "6_1_71"]
		var pick_book: String = book_keys[randi() % book_keys.size()]
		var bk := ItemGenerator.generate_misc(pick_book, 1, 0, 1)
		if bk != null:
			out.append({"type": "item", "item": bk})

	return out

## BOSS SÁT THỦ (Nhiếp Thí Trần - dropsatthu.lua gốc):
##   - 2-3 đống tiền (5.000 - 15.000 lượng);
##   - 2-3 Trang Bị Hoàng Kim Môn Phái ngẫu nhiên;
##   - 50% rơi 1 Ngựa ngẫu nhiên;
##   - 2-3 vật phẩm Hiệu Thuốc.
static func roll_killer_boss(monster_level: int, series: int) -> Array:
	var out: Array = []
	for i in randi_range(2, 3):
		out.append({"type": "money", "amount": int(randi_range(5000, 15000) * money_rate_mult)})

	# Rơi 2-3 Trang Bị Hoàng Kim Môn Phái ngẫu nhiên
	for i in randi_range(2, 3):
		var gold_item := roll_sect_gold_item()
		if gold_item != null:
			out.append({"type": "item", "item": gold_item})

	# 50% rơi 1 Ngựa ngẫu nhiên
	if randf() < 0.50:
		var horse := roll_horse(series)
		if horse != null:
			out.append({"type": "item", "item": horse})

	# Rơi 2-3 vật phẩm Hiệu Thuốc
	for i in randi_range(2, 3):
		var pot := roll_pharmacy_item()
		if pot != null:
			out.append({"type": "item", "item": pot})

	return out

## ĐỊA NGỤC (map 11x / 12x của Vượt Ải, độ khó `stars` 1-5):
##   - Rơi Trang Bị Hoàng Kim Môn Phái, Ngựa và Dược phẩm Hiệu Thuốc
static func roll_hell(monster_level: int, series: int, stars: int, blue_boss := false) -> Array:
	stars = clampi(stars, 1, 5)
	var t: Array = (TIERS[10] as Array).duplicate()
	var out: Array = []
	if blue_boss:
		for i in BOSS_DROPS * stars:
			if randf() < 0.3:
				out.append({"type": "money", "amount": _money(t, stars)})
			elif randf() < (1.0 / 51.0):
				_try_append_misc(out, MISC_MAT_CHI, 1.0)
			elif randf() < 0.6:
				if randf() < 0.25:
					var horse := roll_horse(series)
					if horse != null:
						out.append({"type": "item", "item": horse})
				else:
					var gold_item := roll_sect_gold_item()
					if gold_item != null:
						out.append({"type": "item", "item": gold_item})
		for k in randi_range(2, 4) * stars:
			var pot := roll_pharmacy_item()
			if pot != null:
				out.append({"type": "item", "item": pot})
		return out

	var sel := randi_range(0, 15)
	if sel <= 6:
		if sel == 2:
			out.append({"type": "money", "amount": _money(t, stars)})
		elif sel == 4:
			if randf() < 0.20:
				var horse := roll_horse(series)
				if horse != null:
					out.append({"type": "item", "item": horse})
			else:
				var gold_item := roll_sect_gold_item()
				if gold_item != null:
					out.append({"type": "item", "item": gold_item})
		elif sel == 5:
			_try_append_misc(out, MISC_DIA_DO_CHI, 0.50)

	if randf() < 0.40 * stars:
		var pot := roll_pharmacy_item()
		if pot != null:
			out.append({"type": "item", "item": pot})

	_try_append_misc(out, MISC_MAT_DO, _mat_do_rate_for_tier(10))
	return out

## Số dòng magic của đồ Địa Ngục: stars/5 cơ hội đủ ItemInstance.MAX_MAGIC dòng, còn lại ngẫu nhiên trong `normal` [min, max].
static func _hell_lines(stars: int, normal: Array) -> int:
	if randf() < float(stars) / 5.0:
		return ItemInstance.MAX_MAGIC
	return randi_range(int(normal[0]), int(normal[1]))

static func _roll_blue_item(t: Array, series: int, lines: int = -1, extra_luck: int = 0) -> ItemInstance:
	var level := randi_range(t[2], t[3])
	if lines < 0:
		lines = randi_range(t[5], t[6])
	var magic_levels := []
	for i in lines:
		magic_levels.append(level)
	## Một số loại cụ thể trong KindItem không có món ở cấp này trong bảng đồ của game -> thử vài lần. Đòi ĐỦ dòng (Địa Ngục):
	## bộ sinh có thể dừng sớm khi không bốc được dòng hợp lệ -> sinh lại tới khi đủ (giữ món nhiều dòng nhất phòng khi không được).
	var full := lines >= ItemInstance.MAX_MAGIC
	var best: ItemInstance = null
	for attempt in (60 if full else 12):
		var kind: Array = KIND_ITEM[randi_range(0, KIND_ITEM.size() - 1)]
		var particular := randi_range(kind[1], kind[2])
		var item := ItemGenerator.generate(kind[0], particular, level, series, magic_levels, t[4] + extra_luck)
		if item == null:
			continue
		if not full or item.magic.size() >= lines:
			return item
		if best == null or item.magic.size() > best.magic.size():
			best = item
	return best
