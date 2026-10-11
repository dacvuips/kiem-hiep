extends RefCounted
class_name DropTable
## Bảng RỚT ĐỒ khi quái chết — chép từ script server gốc `script/global/droprate/droprate<N>x.lua` (hàm DropRate(NpcIndex), được
## KNpc::DoDeath gọi khi quái chết). Engine C++ KHÔNG đọc các file .ini tỉ lệ rớt (npcdroprate*.ini) — mọi việc do script quyết.
##
## Mỗi lần quái thường chết (không phải boss xanh): nSel = ngẫu_nhiên(0..15)
##   nSel > 6          : không rớt gì
##   nSel < 2          : rớt TIỀN (cấp 0x-6x) / nSel == 2 (cấp 7x-10x)
##   nSel == 5         : 50% rớt vật phẩm tiêu hao (thần bí lộ chí / thịt tươi — CHƯA có trong game, bỏ qua)
##   nSel == 4         : 1/30 rớt TRANG BỊ XANH (số dòng magic ngẫu nhiên theo cấp)
## Cấp của bảng (0x..10x) chọn theo cấp quái / 10. CHÚ Ý: script gốc gắn bảng cho từng quái qua SetNpcDropScript trong script
## map — chưa nhập — nên đây là SUY RA từ cấp quái, không phải dữ liệu gốc. Boss xanh (rớt 5 lần) chưa làm.

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
const BLUE_BOSS_CHANCE := 0.02        ## script: RANDOM(150) < 2 — chú thích gốc ghi "xác suất 2%" (mỗi lần quái sinh / sinh lại)
const BLUE_ITEM_ONE_IN := 30
## Nhân thêm tỉ lệ rớt TIỀN và ĐỒ (1.0 = đúng server gốc). Đồ xanh gốc rất hiếm (~0,2% mỗi quái) nên đặt >1 khi muốn thử nhanh.
const MONEY_RATE_MULT := 1.0
const ITEM_RATE_MULT := 1.0

static func tier_of(monster_level: int) -> int:
	return clampi(monster_level / 10, 0, 10)

## Kết quả: mảng [{"type": "money", "amount": int} | {"type": "item", "item": ItemInstance}]. Rỗng = không rớt gì.
static func roll(monster_level: int, series: int) -> Array:
	var t: Array = TIERS[tier_of(monster_level)]
	var out: Array = []
	var sel := randi_range(0, 15)
	if sel > 6:
		return out
	var money_hit := (sel == 2) if tier_of(monster_level) >= 7 else (sel < 2)
	if money_hit or (MONEY_RATE_MULT > 1.0 and randf() < (MONEY_RATE_MULT - 1.0) / MONEY_RATE_MULT):
		out.append({"type": "money", "amount": randi_range(t[0], t[1])})
	elif sel == 4 or (ITEM_RATE_MULT > 1.0 and randf() < (ITEM_RATE_MULT - 1.0) / ITEM_RATE_MULT):
		if randi_range(1, BLUE_ITEM_ONE_IN) == 5 or ITEM_RATE_MULT > 1.0:
			var item := _roll_blue_item(t, series)
			if item != null:
				out.append({"type": "item", "item": item})
	return out

## Boss xanh rớt 5 lần (dropnum): mỗi lần nSel = ngẫu_nhiên(0..20) (cấp 6x+: 0..50) — nSel < 5 (6x+: > 40) rớt TIỀN; nSel > 5 rớt
## 1 TRANG BỊ XANH nhiều dòng magic; nSel == 8 là mật chí (6x+: thêm 9 bí kíp, 10 chìa khoá nhiệm vụ) — không có trong game -> bỏ qua.
static func roll_blue_boss(monster_level: int, series: int) -> Array:
	var tier := tier_of(monster_level)
	var t: Array = TIERS[tier]
	var out: Array = []
	for i in BOSS_DROPS:
		var sel := randi_range(0, 50) if tier >= 6 else randi_range(0, 20)
		var money := sel > 40 if tier >= 6 else sel < 5
		if money:
			out.append({"type": "money", "amount": randi_range(t[0], t[1])})
		elif sel == 8 or sel <= 5 or (tier >= 6 and sel in [9, 10]):
			continue   ## 8 = mật chí; (6x+) 9 = bí kíp, 10 = chìa khoá nhiệm vụ — không có trong game
		else:
			var lines: Array = BOSS_LINES[tier]
			var item := _roll_blue_item(t, series, randi_range(lines[0], lines[1]))
			if item != null:
				out.append({"type": "item", "item": item})
	return out

static func _roll_blue_item(t: Array, series: int, lines: int = -1) -> ItemInstance:
	var level := randi_range(t[2], t[3])
	if lines < 0:
		lines = randi_range(t[5], t[6])
	var magic_levels := []
	for i in lines:
		magic_levels.append(level)
	## Một số loại cụ thể trong KindItem không có món ở cấp này trong bảng đồ của game -> thử vài lần.
	for attempt in 12:
		var kind: Array = KIND_ITEM[randi_range(0, KIND_ITEM.size() - 1)]
		var particular := randi_range(kind[1], kind[2])
		var item := ItemGenerator.generate(kind[0], particular, level, series, magic_levels, t[4])
		if item != null:
			return item
	return null
