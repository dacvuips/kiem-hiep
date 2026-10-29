extends RefCounted
class_name Compound
## CHẾ TẠO (nút "Chế tạo" trong Hành trang) — làm đúng script Thợ rèn / Nhiếp Thí Trần gốc (bản 15 phái):
##   KILLER  Hợp thành Sát thủ giản  task/tollgate/killer/nieshichen.lua exchange_token: đúng 5 Sát Thủ lệnh CÙNG CẤP -> 1 Sát thủ
##           giản cùng cấp, hệ = hệ của 1 trong 5 lệnh (ngẫu nhiên); không tốn tiền, không thất bại.
##   REFINE  Luyện Huyền Tinh       item/compound/xuanjing_compound.lua (1.000 lượng): Nhẫn + Dây chuyền/Hộ thân phù + Ngọc bội/Hương
##           nang (đồ trắng/xanh) -> Huyền Tinh cấp 1-10 theo GIÁ TRỊ (equip_normal_magic: theo số dòng magic).
##   UPGRADE Nâng cấp khoáng thạch  ore_upgrade.lua (5.000): 3 Huyền Tinh / 3 khoáng thuộc tính giống hệt (cùng cấp, cùng thuộc tính,
##           khoáng ẩn cùng hệ) -> 1 viên cấp +1; tỉ lệ = (S/3) / (giá_cấp_mới − 2S/3); thất bại chỉ mất viên ĐẦU.
##   DISTILL Tách khoáng thuộc tính magic_distill.lua (5.000): đồ trắng/xanh + Huyền Tinh + Nguyên khoáng/Nguyên thạch (149-154 ->
##           dòng 1-6; dòng chẵn = ẩn, nguyên thạch phải cùng hệ món đồ) -> khoáng thuộc tính 6_1_(199+dòng) cấp 1-10 mang
##           thuộc tính của dòng đó. Mất món đồ.
##   FORGE   Chế tạo đồ tím          equip_compound.lua (10.000): đồ trắng/xanh KHÔNG phải trang sức + Huyền Tinh -> chính món đó thành
##           đồ tím (quality 2) với 1-5 Ô KHẢM TRỐNG (mất hết dòng magic cũ); số ô theo giá trị Huyền Tinh.
##   ENCHASE Khảm đồ tím             equip_enchase.lua (10.000): đồ tím + Huyền Tinh + khoáng thuộc tính đúng vị trí ô trống đầu tiên
##           (khoáng 200 -> ô 1 ... 205 -> ô 6; ô chẵn khoáng cùng hệ) -> ô đó thành dòng magic cấp theo giá trị.
##           Thất bại: GIỮ đồ tím, mất Huyền Tinh + khoáng + vật phẩm phụ.
## Vật phẩm phụ (tách khoáng, khảm): Thần bí khoáng thạch, Thủy Tinh, Phúc Duyên Lộ — cộng giá trị giảm dần (calcAltItemFinalVal).
## Chọn kết quả theo giá trị: TransItemVal (itemvalue_header.lua, cách 2). Bảng giá trị: data/items/compound.json
## (tools/export_compound_data.py). Bỏ giới hạn tổng giá trị mỗi ngày toàn máy chủ của gốc.
## Dùng chung offline (máy mình) và game server (gói C_CRAFT -> run() trên hồ sơ của server) — luật giống hệt nhau.

enum Op { KILLER, REFINE, UPGRADE, DISTILL, FORGE, ENCHASE, DOPHO }
const OP_NAMES := ["Sát thủ giản", "Luyện Huyền Tinh", "Nâng cấp khoáng", "Tách khoáng", "Chế đồ tím", "Khảm đồ tím", "Hoàng kim đồ phổ"]
const COST := [0, 1000, 5000, 5000, 10000, 10000, 100000]
## Số vật phẩm phụ tối đa (ô vật phẩm phụ gốc 55×111 = 2 cột × 4 ô).
const MAX_ALT := 8

const PATH := "res://data/items/compound.json"
const XUANJING := "6_1_147"
const KILLER_TOKEN := "6_1_399"
const KILLER_SWORD := "6_1_400"
const RAW_ORES := ["6_1_149", "6_1_150", "6_1_151", "6_1_152", "6_1_153", "6_1_154"]   ## Nguyên khoáng / nguyên thạch -> dòng 1-6
const PROP_ORES := ["6_1_200", "6_1_201", "6_1_202", "6_1_203", "6_1_204", "6_1_205"]  ## khoáng thuộc tính ô 1-6
const JEWELRY := [3, 4, 9]   ## nhẫn, dây chuyền / hộ thân phù, ngọc bội / hương nang
## Cột giá trị trong magicattriblevel theo (loại chi tiết, loại cụ thể) — EQUIP_COLUMNS của magicattriblevel.lua.
const EQUIP_COL_START := [0, 6, 9, 10, 11, 13, 14, 15, 16, 17]
const EQUIP_COL_COUNT := [6, 3, 1, 1, 2, 1, 1, 1, 1, 2]
## Thuộc tính sát thương nội công (168-172): hệ số cấp đồ dùng cột VALUE%_2.
const INNER_DAMAGE_IDS := [168, 169, 170, 171, 172]

## Kết quả kiểm tra (RESULT_* của compound_header.lua).
const ERR_TEXT := {
	"money": "Không đủ ngân lượng.",
	"lack": "Thiếu nguyên liệu hoặc nguyên liệu không đúng.",
	"level_full": "Nguyên liệu đã đạt cấp cao nhất.",
	"level": "Nguyên liệu không cùng cấp.",
	"magic": "Thuộc tính không phù hợp.",
	"series": "Ngũ hành không phù hợp.",
	"rule": "Khoáng thạch không đúng vị trí ô khảm trống đầu tiên.",
	"count": "Số lượng nguyên liệu không đúng.",
	"bag": "Hành trang đã đầy.",
}

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			_data = JSON.parse_string(f.get_as_text())
	return _data

# ---------------------------------------------------------------- ô nguyên liệu

## Ô của từng loại chế tạo: [{"label", "kind"}]. kind: token / ring / necklace / pendant / stone / equip_normal / equip_forge /
## equip_purple / xuanjing / raw_ore / prop_ore.
static func slots_of(op: int) -> Array:
	match op:
		Op.KILLER:
			var s := []
			for i in 5:
				s.append({"label": "Sát Thủ lệnh", "kind": "token"})
			return s
		Op.REFINE:
			return [{"label": "Nhẫn", "kind": "ring"}, {"label": "Dây chuyền / Hộ thân phù", "kind": "necklace"},
				{"label": "Ngọc bội / Hương nang", "kind": "pendant"}]
		Op.UPGRADE:
			return [{"label": "Khoáng thạch 1", "kind": "stone"}, {"label": "Khoáng thạch 2", "kind": "stone"},
				{"label": "Khoáng thạch 3", "kind": "stone"}]
		Op.DISTILL:
			return [{"label": "Trang bị", "kind": "equip_normal"}, {"label": "Huyền Tinh", "kind": "xuanjing"},
				{"label": "Nguyên khoáng", "kind": "raw_ore"}]
		Op.FORGE:
			return [{"label": "Trang bị", "kind": "equip_forge"}, {"label": "Huyền Tinh", "kind": "xuanjing"}]
		Op.ENCHASE:
			return [{"label": "Đồ tím", "kind": "equip_purple"}, {"label": "Huyền Tinh", "kind": "xuanjing"},
				{"label": "Khoáng thuộc tính", "kind": "prop_ore"}]
		Op.DOPHO:
			return [{"label": "Đồ phổ", "kind": "blueprint"}, {"label": "Khoáng thạch 1", "kind": "prop_ore"},
				{"label": "Khoáng thạch 2", "kind": "prop_ore"}, {"label": "Sách kỹ năng", "kind": "skill_book"},
				{"label": "Khoáng thạch 3", "kind": "prop_ore"}, {"label": "Khoáng thạch 4", "kind": "prop_ore"}]
	return []

static func uses_alt(op: int) -> bool:
	return op == Op.DISTILL or op == Op.ENCHASE or op == Op.DOPHO

## Món đặt được vào ô loại `kind` (chưa xét luật giữa các ô).
static func fits(item: ItemInstance, kind: String) -> bool:
	if item == null or item.lock_state != ItemInstance.LOCK_NORMAL or item.trade_price > 0:
		return false
	var normal := not item.is_misc() and not item.is_gold() and not item.is_purple()
	match kind:
		"token":
			return item.misc_id == KILLER_TOKEN
		"ring":
			return normal and item.get_detail() == 3
		"necklace":
			return normal and item.get_detail() == 4
		"pendant":
			return normal and item.get_detail() == 9
		"stone":
			return item.misc_id == XUANJING or item.misc_id in PROP_ORES
		"equip_normal":
			return normal and item.magic.size() > 0 and item.get_detail() >= 0 and item.get_detail() <= 9
		"equip_forge":
			return normal and item.get_detail() >= 0 and item.get_detail() <= 8 and not item.get_detail() in JEWELRY
		"equip_purple":
			return item.is_purple() and item.sockets > 0
		"xuanjing":
			return item.misc_id == XUANJING
		"raw_ore":
			return item.misc_id in RAW_ORES
		"prop_ore":
			return item.misc_id in PROP_ORES
		"blueprint":
			return item.is_misc() and ("đồ phổ" in item.get_display_name().to_lower() or item.misc_id.begins_with("6_1_2") or item.misc_id == "4_412_1")
		"skill_book":
			return item.is_misc() and ("bí kíp" in item.get_display_name().to_lower() or "thư tịch" in item.get_display_name().to_lower() or item.misc_id.begins_with("6_1_45"))
		"alt":
			return item.misc_id == XUANJING or data().get("alt", {}).has(item.misc_id)
	return false

# ---------------------------------------------------------------- giá trị (itemvalue/*.lua)

static func ore_value(level: int) -> float:
	var t: Array = data().get("ore", [])
	return float(t[level - 1]) if level >= 1 and level <= t.size() else 0.0

static func alt_value(item: ItemInstance) -> float:
	return float(data().get("alt", {}).get(item.misc_id, 0))

## Dòng của bảng cấp thuộc tính (MagAttrLvl `j`, từ 1).
static func row(j: int) -> Dictionary:
	var rows: Array = data().get("rows", [])
	return rows[j] if j >= 1 and j < rows.size() and rows[j] != null else {}

## Khoảng MagAttrLvl của mã thuộc tính (getMagAttrLvlRange). `both_signs` = tra cả mã âm (bDiffOpera = 0).
static func ranges_of(magic_id: int, both_signs := false) -> Array:
	var out := []
	for r in data().get("index", []):
		if int(r[0]) == magic_id or (both_signs and int(r[0]) == -magic_id):
			out.append([int(r[1]), int(r[2])])
	return out

## Mã thuộc tính (MAGIC_ID) của 1 dòng magic: dòng đồ tím đã lưu "mid"; dòng đồ xanh tra theo tên thuộc tính.
static func magic_id_of(line: Dictionary) -> int:
	if line.has("mid"):
		return int(line["mid"])
	var attrib := str(line.get("attrib", ""))
	if attrib == "":
		return 0
	for r in data().get("index", []):
		var rr := row(int(r[1]))
		if str(rr.get("attrib", "")) == attrib:
			return absi(int(r[0]))
	return 0

## Cấp thuộc tính (MagAttrLvl) của 1 dòng magic — getMagAttrLvl: dòng có 3 tham số nằm trong khoảng; vượt trên thì lấy cấp cao
## nhất, còn lại lấy cấp thấp nhất.
static func mag_level_of(line: Dictionary) -> int:
	if line.has("mlv"):
		return int(line["mlv"])
	var mid := magic_id_of(line)
	if mid == 0:
		return 0
	var rs := ranges_of(mid, true)
	var v: Array = line.get("value", [0, 0, 0])
	var last := {}
	for r in rs:
		for j in range(r[0], r[1] + 1):
			var rr := row(j)
			if rr.is_empty():
				continue
			last = rr
			var ok := true
			for k in 3:
				var p: Array = rr["p"][k]
				if int(p[0]) >= 0 and int(p[1]) >= 0 and (int(v[k]) < int(p[0]) or int(v[k]) > int(p[1])):
					ok = false
			if ok:
				return j
	if rs.is_empty():
		return 0
	return rs[-1][1] if not last.is_empty() and int(v[0]) > int(last["p"][0][1]) else rs[0][0]

static func _equip_col(detail: int, particular: int) -> int:
	if detail < 0 or detail >= EQUIP_COL_START.size() or particular < 0:
		return -1
	return EQUIP_COL_START[detail] + (particular if particular < EQUIP_COL_COUNT[detail] else 0)

static func match_equip(magic_id: int, detail: int, particular: int) -> bool:
	var rs := ranges_of(magic_id)
	var c := _equip_col(detail, particular)
	return not rs.is_empty() and c >= 0 and int(row(rs[0][0]).get("equip", [])[c]) != 0

static func match_series(magic_id: int, series: int) -> bool:
	var rs := ranges_of(magic_id)
	return not rs.is_empty() and series >= 0 and series < 5 and int(row(rs[0][0]).get("series", [])[series]) != 0

## Giá trị đồ trắng/xanh khi luyện Huyền Tinh (equip_normal.lua XUANJING_COMPOUND): trang sức theo số dòng magic, đồ khác 0.
static func refine_value(item: ItemInstance) -> float:
	if not item.get_detail() in JEWELRY:
		return 0.0
	var n := 0
	for line in item.magic:
		if str(line.get("attrib", "")) != "":
			n += 1
	var t: Array = data().get("normal_magic", [])
	return float(t[mini(n, t.size() - 1)])

## Giá trị ĐỒ TÍM (equip_enchasable.lua): ô trống + hệ_số_cấp × hệ_số_loại × giá_trị_các_dòng.
static func purple_value(detail: int, particular: int, level: int, series: int, mlvs: Array, sockets: int) -> float:
	var d := data()
	var socket_val := 0.0
	if sockets >= 1 and sockets <= (d["socket"] as Array).size():
		socket_val = float(d["socket"][sockets - 1])
	var col := 0
	for j in mlvs:
		if absi(int(row(j).get("id", 0))) in INNER_DAMAGE_IDS:
			col = 1
	var lv: Array = d["level"]
	var level_val := float(lv[level - 1][col]) / 100.0 if level >= 1 and level <= lv.size() else 1.0
	var type_val := 1.0
	for t in d["type"]:
		if (int(t[2]) < 0 or particular == int(t[2])) and (int(t[1]) < 0 or detail == int(t[1])) and (int(t[0]) < 0 or int(t[0]) == 0):
			type_val = float(t[3]) / 100.0
			break
	return socket_val + level_val * type_val * _magic_array_value(detail, particular, series, mlvs)

## calcMagicArrayValue: tổng giá trị từng dòng + phần cộng thêm khi 2 dòng ghép hợp nhau (magicattrib_combine).
static func _magic_array_value(detail: int, particular: int, series: int, mlvs: Array) -> float:
	var vals := []
	var ids := []
	var lvls := []
	var c := _equip_col(detail, particular)
	var pos: Array = data()["pos"]
	for i in mlvs.size():
		var rr := row(int(mlvs[i]))
		var equip_val := float(rr["equip"][c]) if c >= 0 else 0.0
		var series_val := float(rr["series"][series]) / 100.0 if series >= 0 and series < 5 else 1.0
		vals.append(equip_val * series_val * float(pos[i]) / 100.0)
		ids.append(int(rr["id"]))
		lvls.append(int(rr["level"]))
	var sum := 0.0
	var combine: Dictionary = data()["combine"]
	for i in vals.size():
		for j in range(i + 1, vals.size()):
			var k: Variant = combine.get("%d,%d" % [ids[i], ids[j]], combine.get("%d,%d" % [ids[j], ids[i]], 100))
			sum += (vals[i] + vals[j]) * (float(k) / 100.0 - 1.0) * lvls[i] / 10.0 * lvls[j] / 10.0
	for v in vals:
		sum += v
	return sum

static func item_purple_value(item: ItemInstance) -> float:
	return purple_value(item.get_detail(), int(item.get_base().get("particular", 0)), item.get_level(), item.series,
		_mlvs(item), item.sockets)

static func _mlvs(item: ItemInstance) -> Array:
	var out := []
	for line in item.magic:
		out.append(mag_level_of(line))
	return out

## calcAltItemFinalVal: vật phẩm phụ cộng giảm dần theo bậc so với giá trị nguyên liệu chính.
static func alt_final(main_sum: float, alt_sum: float) -> float:
	var seg := [[0.0, 1.0], [0.5, 0.9], [1.0, 0.8], [1.5, 0.7], [2.0, 0.6]]
	var out := 0.0
	for i in range(seg.size() - 1, -1, -1):
		var diff: float = alt_sum - main_sum * seg[i][0]
		if diff > 0.0:
			out += diff * seg[i][1]
			alt_sum -= diff
	return out

## TransItemVal (cách 2, LOW/HI_NEAR_PERCENT 0.95): xác suất từng kết quả theo giá trị nguồn `src`. Trả mảng xác suất cùng thứ tự
## `values`; tổng < 1 thì phần còn lại là thất bại.
static func trans_probs(src: float, values: Array) -> Array:
	var n := values.size()
	var probs := []
	probs.resize(n)
	probs.fill(0.0)
	if src <= 0.0 or n == 0:
		return probs
	var order := range(n)
	order.sort_custom(func(a: int, b: int) -> bool: return float(values[a]) < float(values[b]) or (values[a] == values[b] and a < b))
	var sorted := []
	for i in order:
		sorted.append(float(values[i]))
	var ps := []
	ps.resize(n)
	ps.fill(0.0)
	var idx := -1
	for i in n:
		if sorted[i] > src:
			idx = i
			break
	if idx == -1:
		ps[n - 1] = 1.0
	elif idx > 0:
		var low: float = sorted[idx - 1] * 0.95 + sorted[idx - 2] * 0.05 if idx > 1 else sorted[0]
		var hi: float = sorted[idx] * 0.95 + sorted[idx + 1] * 0.05 if idx < n - 1 else sorted[n - 1]
		var lp := (hi - src) / (hi - low)
		if idx > 1:
			ps[idx - 1] = lp * 0.95
			ps[idx - 2] = lp * 0.05
		else:
			ps[0] = lp
		if idx < n - 1:
			ps[idx] = (1.0 - lp) * 0.95
			ps[idx + 1] = (1.0 - lp) * 0.05
		else:
			ps[n - 1] = 1.0 - lp
	for i in n:
		probs[order[i]] = ps[i]
	return probs

## Bốc 1 kết quả theo xác suất (-1 = thất bại).
static func pick(probs: Array, rng_value: float) -> int:
	var acc := 0.0
	for i in probs.size():
		acc += float(probs[i])
		if probs[i] > 0.0 and rng_value <= acc:
			return i
	return -1

# ---------------------------------------------------------------- tính toán 1 lần chế tạo

## Kiểm tra + tính trước 1 lần chế tạo. `items` = món trong từng ô (null = trống), `alts` = vật phẩm phụ.
## Trả {ok, error, cost, src, outcomes: [{text, prob, value, ...}], fail} — outcomes là các kết quả có thể; fail = tỉ lệ thất bại.
static func plan(profile: PlayerProfile, op: int, items: Array, alts: Array = []) -> Dictionary:
	var r := {"ok": false, "error": "", "cost": COST[op], "outcomes": [], "fail": 0.0}
	for it in items:
		if it == null:
			r["error"] = ERR_TEXT["lack"]
			return r
	var slots := slots_of(op)
	if items.size() != slots.size():
		r["error"] = ERR_TEXT["count"]
		return r
	for i in items.size():
		if not fits(items[i], slots[i]["kind"]):
			r["error"] = ERR_TEXT["lack"]
			return r
	if not uses_alt(op):
		alts = []
	for a in alts:
		if not fits(a, "alt"):
			r["error"] = ERR_TEXT["lack"]
			return r
	var alt_sum := 0.0
	for a in alts:
		alt_sum += alt_value(a)
	match op:
		Op.KILLER:
			_plan_killer(r, items)
		Op.REFINE:
			var src := 0.0
			for it in items:
				src += refine_value(it)
			_plan_levels(r, src, XUANJING, -1, 0)
		Op.UPGRADE:
			_plan_upgrade(r, items)
		Op.DISTILL:
			_plan_distill(r, items, alt_sum)
		Op.FORGE:
			_plan_forge(r, items)
		Op.ENCHASE:
			_plan_enchase(r, items, alt_sum)
		Op.DOPHO:
			_plan_dopho(r, items, alts)
	if r["error"] == "" and profile and profile.gold < int(r["cost"]):
		r["error"] = ERR_TEXT["money"]
	r["ok"] = r["error"] == ""
	return r

static func _plan_killer(r: Dictionary, items: Array) -> void:
	var lv := (items[0] as ItemInstance).get_level()
	var count := {}
	for it in items:
		if (it as ItemInstance).get_level() != lv:
			r["error"] = ERR_TEXT["level"]
			return
		count[it.series] = int(count.get(it.series, 0)) + 1
	for s in count:
		r["outcomes"].append({"text": "Sát thủ giản cấp %d hệ %s" % [lv, ElementTypes.ELEMENT_NAME.get(s, "?")],
			"prob": float(count[s]) / 5.0, "make": {"mid": KILLER_SWORD, "level": lv, "series": s}})

## Kết quả là khoáng `mid` cấp 1-10 chọn theo giá trị nguồn `src` (luyện Huyền Tinh / tách khoáng).
static func _plan_levels(r: Dictionary, src: float, mid: String, series: int, magic_id: int) -> void:
	var values := []
	for lv in range(1, 11):
		values.append(ore_value(lv))
	var probs := trans_probs(src, values)
	var total := 0.0
	var name := str(ItemDatabase.get_misc(mid).get("name", mid))
	for i in probs.size():
		if probs[i] > 0.0:
			total += probs[i]
			r["outcomes"].append({"text": "%s cấp %d" % [name, i + 1], "prob": probs[i],
				"make": {"mid": mid, "level": i + 1, "series": maxi(series, 0), "ore_magic": magic_id}})
	r["src"] = src
	r["fail"] = maxf(0.0, 1.0 - total)

static func _plan_upgrade(r: Dictionary, items: Array) -> void:
	var a: ItemInstance = items[0]
	var lv := a.get_level()
	if lv >= 10:
		r["error"] = ERR_TEXT["level_full"]
		return
	if a.misc_id != XUANJING and a.ore_magic <= 0:
		r["error"] = ERR_TEXT["lack"]
		return
	for i in range(1, 3):
		var b: ItemInstance = items[i]
		if b.misc_id != a.misc_id:
			r["error"] = ERR_TEXT["lack"]
			return
		if b.get_level() != lv:
			r["error"] = ERR_TEXT["level"]
			return
		if a.misc_id != XUANJING:
			if (PROP_ORES.find(a.misc_id) % 2 == 1) and b.series != a.series:
				r["error"] = ERR_TEXT["series"]
				return
			if b.ore_magic != a.ore_magic:
				r["error"] = ERR_TEXT["magic"]
				return
	var s := ore_value(lv) * 3.0
	var p := clampf((s / 3.0) / (ore_value(lv + 1) - s / 3.0 * 2.0), 0.0, 1.0)
	r["outcomes"].append({"text": "%s cấp %d" % [str(a.get_base().get("name", "")), lv + 1], "prob": p,
		"make": {"mid": a.misc_id, "level": lv + 1, "series": a.series, "ore_magic": a.ore_magic}})
	r["fail"] = 1.0 - p
	r["fail_note"] = "thất bại chỉ mất 1 viên"

static func _plan_distill(r: Dictionary, items: Array, alt_sum: float) -> void:
	var equip: ItemInstance = items[0]
	var xj: ItemInstance = items[1]
	var ore: ItemInstance = items[2]
	var pos := RAW_ORES.find(ore.misc_id) + 1
	if pos % 2 == 0 and equip.series != ore.series:
		r["error"] = ERR_TEXT["series"]
		return
	var line: Dictionary = equip.magic[pos - 1] if pos - 1 < equip.magic.size() else {}
	var mid := magic_id_of(line) if not line.is_empty() else 0
	if mid <= 0 or ranges_of(mid).is_empty() or not match_series(mid, ore.series):
		r["error"] = ERR_TEXT["magic"] if mid > 0 else "Món đồ không có dòng thuộc tính thứ %d." % pos
		return
	var mlv := mag_level_of(line)
	var main := float(row(mlv).get("base", 0)) + ore_value(xj.get_level())
	_plan_levels(r, main + alt_final(main, alt_sum), PROP_ORES[pos - 1], ore.series, mid)
	r["note"] = "Tách dòng %d: %s" % [pos, ItemText.format_attrib(str(line["attrib"]), line["value"])]

static func _plan_forge(r: Dictionary, items: Array) -> void:
	var equip: ItemInstance = items[0]
	var xj: ItemInstance = items[1]
	var src := ore_value(xj.get_level())
	var values := []
	for n in range(1, 6):
		values.append(purple_value(equip.get_detail(), int(equip.get_base().get("particular", 0)), equip.get_level(), equip.series, [], n))
	var probs := trans_probs(src, values)
	var total := 0.0
	for i in probs.size():
		if probs[i] > 0.0:
			total += probs[i]
			r["outcomes"].append({"text": "Đồ tím %d ô khảm" % (i + 1), "prob": probs[i], "make": {"sockets": i + 1}})
	r["src"] = src
	r["fail"] = maxf(0.0, 1.0 - total)
	r["note"] = "Món đồ mất hết dòng thuộc tính cũ."

static func _plan_enchase(r: Dictionary, items: Array, alt_sum: float) -> void:
	var equip: ItemInstance = items[0]
	var xj: ItemInstance = items[1]
	var ore: ItemInstance = items[2]
	var pos := equip.magic.size() + 1
	if pos != PROP_ORES.find(ore.misc_id) + 1:
		r["error"] = "%s Ô trống đầu tiên là ô %d — cần %s." % [ERR_TEXT["rule"], pos,
			str(ItemDatabase.get_misc(PROP_ORES[pos - 1]).get("name", "")) if pos <= PROP_ORES.size() else "?"]
		return
	if pos % 2 == 0 and equip.series != ore.series:
		r["error"] = ERR_TEXT["series"]
		return
	var mid := ore.ore_magic
	var detail := equip.get_detail()
	var particular := int(equip.get_base().get("particular", 0))
	if mid <= 0 or not match_equip(mid, detail, particular) or not match_series(mid, equip.series):
		r["error"] = ERR_TEXT["magic"]
		return
	for line in equip.magic:
		if magic_id_of(line) == mid:
			r["error"] = "Món đồ đã có thuộc tính này."
			return
	var cur := _mlvs(equip)
	var equip_val := item_purple_value(equip)
	var values := []
	var levels := []
	for rg in ranges_of(mid):
		for j in range(rg[0], rg[1] + 1):
			if j > 0:
				var m := cur.duplicate()
				m.append(j)
				values.append(purple_value(detail, particular, equip.get_level(), equip.series, m, equip.sockets - 1))
				levels.append(j)
	var n := values.size()
	for v in values:
		if equip_val < float(v):
			values.append(equip_val)   ## ứng viên "thất bại" = giữ nguyên đồ
			break
	var main := ore_value(xj.get_level()) + ore_value(ore.get_level())
	var src := equip_val + main + alt_final(main, alt_sum)
	var probs := trans_probs(src, values)
	var total := 0.0
	for i in n:
		if probs[i] > 0.0:
			total += probs[i]
			var rr := row(levels[i])
			r["outcomes"].append({"text": "%s (cấp %d)" % [str(rr.get("name", "")), int(rr.get("level", 0))], "prob": probs[i],
				"make": {"mlv": levels[i]}})
	r["src"] = src
	r["fail"] = maxf(0.0, 1.0 - total)
	r["fail_note"] = "thất bại vẫn giữ đồ tím"

static func _plan_dopho(r: Dictionary, items: Array, alts: Array) -> void:
	var bp: ItemInstance = items[0]
	var bp_name := bp.get_display_name()
	var clean_name := bp_name.replace("Đồ phổ Hoàng Kim - ", "").replace("Đồ phổ - ", "").replace(" đồ phổ", "").strip_edges()
	var gold_idx := ItemDatabase.find_gold_by_name(clean_name)
	if gold_idx < 0:
		gold_idx = 0
	var gold_record := ItemDatabase.get_gold(gold_idx)
	var gold_name := str(gold_record.get("name", clean_name))

	var alt_sum := 0.0
	for a in alts:
		if (a as ItemInstance).misc_id == XUANJING:
			alt_sum += ore_value(a.get_level())
		else:
			alt_sum += alt_value(a)

	var base_prob := 0.35
	var bonus := clampf(alt_sum / 250000.0, 0.0, 0.65)
	var p := clampf(base_prob + bonus, 0.2, 1.0)

	r["outcomes"].append({
		"text": "Hoàng Kim - %s" % gold_name,
		"prob": p,
		"make": {"gold_index": gold_idx, "perfection": 8 + randi() % 3}
	})
	r["fail"] = maxf(0.0, 1.0 - p)
	r["fail_note"] = "thất bại giữ Đồ phổ, mất nguyên liệu khác"
	r["note"] = "Kết hợp Đồ phổ chế tạo thành trang bị Hoàng Kim môn phái."

# ---------------------------------------------------------------- thực hiện

## Chế tạo trên `profile` với ô theo uid (`uids` theo thứ tự ô; 1 uid được dùng nhiều lần nếu là chồng đủ số lượng) + vật phẩm phụ.
## Trả {ok, success, message}.
static func run(profile: PlayerProfile, op: int, uids: Array, alt_uids: Array = [], rng: RandomNumberGenerator = null) -> Dictionary:
	if profile == null or op < 0 or op >= COST.size():
		return {"ok": false, "success": false, "message": ERR_TEXT["lack"]}
	if profile.stall_open:
		return {"ok": false, "success": false, "message": "Đang bày bán quầy hàng, không thể chế tạo."}
	var blocked := SecurityLock.check(profile, SecurityLock.A_OPEN_STALL)
	if blocked != "":
		return {"ok": false, "success": false, "message": blocked}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var need := {}
	for u in uids + alt_uids:
		need[str(u)] = int(need.get(str(u), 0)) + 1
	var by_uid := {}
	for it in profile.inventory:
		by_uid[it.ensure_uid()] = it
	for u in need:
		if not by_uid.has(u) or (by_uid[u] as ItemInstance).count < int(need[u]):
			return {"ok": false, "success": false, "message": ERR_TEXT["lack"]}
		var it: ItemInstance = by_uid[u]
		if it.trade_price > 0:
			return {"ok": false, "success": false, "message": "Vật phẩm đang đặt giá bán, không thể chế tạo."}
		if SecurityLock.is_item_locked(it):
			return {"ok": false, "success": false, "message": "Vật phẩm đang bị khóa bảo vệ, không thể chế tạo."}
	var items := []
	for u in uids:
		items.append(by_uid.get(str(u)))
	var alts := []
	for u in alt_uids.slice(0, MAX_ALT):
		alts.append(by_uid.get(str(u)))
	var p := plan(profile, op, items, alts)
	if not p["ok"]:
		return {"ok": false, "success": false, "message": p["error"]}
	profile.gold -= int(p["cost"])
	var roll := rng.randf()
	var chosen := pick(p["outcomes"].map(func(o: Dictionary) -> float: return o["prob"]), roll)
	match op:
		Op.UPGRADE:
			if chosen < 0:   ## ore_upgrade.lua: thất bại chỉ mất viên đầu
				_take(profile, items[0], 1)
				return {"ok": true, "success": false, "message": "Nâng cấp thất bại — mất 1 %s." % items[0].get_base().get("name", "")}
		Op.ENCHASE:
			if chosen < 0:   ## equip_enchase.lua: thất bại giữ đồ tím, mất phần còn lại
				for i in range(1, items.size()):
					_take(profile, items[i], 1)
				for a in alts:
					_take(profile, a, 1)
				return {"ok": true, "success": false, "message": "Khảm thất bại — đồ tím vẫn còn, mất Huyền Tinh và khoáng thạch."}
		Op.DOPHO:
			if chosen < 0:
				for i in range(1, items.size()):
					_take(profile, items[i], 1)
				for a in alts:
					_take(profile, a, 1)
				return {"ok": true, "success": false, "message": "Ghép Đồ phổ thất bại — Đồ phổ vẫn còn, mất các nguyên liệu phụ."}
	if chosen < 0:
		for it in items:
			_take(profile, it, 1)
		for a in alts:
			_take(profile, a, 1)
		return {"ok": true, "success": false, "message": "%s thất bại — mất nguyên liệu." % OP_NAMES[op]}
	var make: Dictionary = p["outcomes"][chosen]["make"]
	var result := _make_result(op, items, make, rng)
	var durability := (items[0] as ItemInstance).durability
	for it in items:
		_take(profile, it, 1)
	for a in alts:
		_take(profile, a, 1)
	if op == Op.ENCHASE:
		result.durability = durability
	if not profile.add_item(result):
		## Hết chỗ: gốc vẫn tạo vật phẩm — ở đây trả về túi chắc chắn có chỗ vì vừa bỏ nguyên liệu ra.
		return {"ok": true, "success": false, "message": ERR_TEXT["bag"]}
	return {"ok": true, "success": true, "message": "%s thành công: %s." % [OP_NAMES[op], p["outcomes"][chosen]["text"]],
		"uid": result.uid}

static func _make_result(op: int, items: Array, make: Dictionary, rng: RandomNumberGenerator) -> ItemInstance:
	match op:
		Op.DOPHO:
			var gold_idx := int(make.get("gold_index", 0))
			var perf := int(make.get("perfection", 10))
			var it := ItemGenerator.generate_gold(gold_idx, perf, rng.randi())
			if it:
				it.ensure_uid()
				return it
		Op.FORGE:
			var src: ItemInstance = items[0]
			var it := ItemInstance.from_dict(src.to_dict())
			it.uid = ItemInstance.new_uid()
			it.quality = ItemInstance.QUALITY_PURPLE
			it.magic = []
			it.sockets = int(make["sockets"])
			it.lock_state = ItemInstance.LOCK_NORMAL
			it.trade_price = 0
			return it
		Op.ENCHASE:
			var src: ItemInstance = items[0]
			var it := ItemInstance.from_dict(src.to_dict())
			it.uid = ItemInstance.new_uid()
			var j := int(make["mlv"])
			var rr := row(j)
			var v := []
			for k in 3:
				var pr: Array = rr["p"][k]
				v.append(rng.randi_range(int(pr[0]), int(pr[1])) if int(pr[0]) >= 0 and int(pr[1]) >= 0 else 0)
			var pos := it.magic.size()
			it.magic.append({"attrib": str(rr["attrib"]), "value": v, "name": str(rr["name"]), "prefix": pos % 2 == 0,
				"mid": absi(int(rr["id"])), "mlv": j})
			it.sockets -= 1
			return it
	var out := ItemGenerator.generate_misc(str(make["mid"]), int(make.get("level", 0)), int(make.get("series", 0)))
	out.ore_magic = int(make.get("ore_magic", 0))
	out.ensure_uid()
	return out

## Bỏ `n` đơn vị của món khỏi hành trang (chồng thì trừ số lượng).
static func _take(profile: PlayerProfile, item: ItemInstance, n: int) -> void:
	if item.count > n:
		item.count -= n
	else:
		profile.inventory.erase(item)

## Tên thuộc tính của khoáng thuộc tính (mã MAGIC_ID).
static func ore_magic_name(magic_id: int) -> String:
	var rs := ranges_of(magic_id)
	return str(row(rs[0][0]).get("name", "")) if not rs.is_empty() else ""

## Loại trang bị có thể khảm nạm theo MAGIC_ID (settings/item/004/magicattriblevel_index.txt gốc).
const ORE_FIT_EQUIP := {
	126: "Vũ khí", 166: "Vũ khí", 115: "Vũ khí", 58: "Vũ khí", 43: "Không thể khảm nạm",
	150: "Không thể khảm nạm", 111: "Hài", 117: "Y phục", 113: "Y phục", 112: "Không thể khảm nạm",
	139: "Nhẫn, Vũ khí", 114: "Dây chuyền", 136: "Vũ khí", 137: "Vũ khí", 85: "Tất cả các trang bị",
	89: "Tất cả các trang bị", 93: "Tất cả các trang bị", 88: "Y phục, Hài, Yêu đái, Mão, Hộ uyển",
	92: "Đai thắt", 96: "Nhẫn, Dây chuyền", 97: "Nhẫn, Dây chuyền, Đai thắt", 121: "Vũ khí",
	125: "Vũ khí", 123: "Vũ khí", 122: "Vũ khí", 124: "Vũ khí", 134: "Y phục, Hài, Yêu đái, Mão, Hộ uyển",
	104: "Y phục, Hài, Yêu đái, Mão, Hộ uyển", 101: "Tất cả các trang bị", 105: "Tất cả các trang bị",
	102: "Tất cả các trang bị", 103: "Tất cả các trang bị", 99: "Tất cả các trang bị", 110: "Tất cả các trang bị",
	135: "Nhẫn, Đai thắt, Dây chuyền", 106: "Tất cả các trang bị",
	98: "Y phục, Hài, Yêu đái, Mão, Hộ uyển, Nhẫn, Dây chuyền, Đai thắt", 108: "Tất cả các trang bị",
	140: "Không thể khảm nạm", 142: "Không thể khảm nạm", 141: "Không thể khảm nạm",
	143: "Không thể khảm nạm", 144: "Không thể khảm nạm", 168: "Vũ khí", 169: "Vũ khí",
	170: "Vũ khí", 171: "Vũ khí", 172: "Vũ khí",
}

## Loại trang bị có thể khảm nạm của khoáng thuộc tính (mã MAGIC_ID).
static func ore_magic_fit_equip(magic_id: int) -> String:
	return ORE_FIT_EQUIP.get(magic_id, "")
