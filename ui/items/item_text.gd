extends RefCounted
class_name ItemText
## Mô tả 1 món trang bị (BBCode) — NGUYÊN VĂN thứ tự + màu của KItem::GetDesc gốc VLTK:
##   1. Tên [Cấp N] — trắng (thường) / xanh 100,100,255 (đồ xanh) / vàng 255,255,0 (hoàng kim)
##   2. "Thuộc tính ngũ hành: <hệ>" (GameSetting.ini [Elements]) + lời mô tả của món
##   3. Thuộc tính gốc (Sát thương nhỏ/lớn nhất, Độ chính xác, Độ bền x / y...)
##   4. Yêu cầu — trắng nếu đạt, ĐỎ nếu chưa đạt
##   5. Dòng magic: tiền tố xanh 99,101,255 (hoàng kim vàng); dòng ẩn đã bật cùng màu; dòng ẩn chưa bật
##      xám 120,120,120 (hoàng kim xám ô liu 123,125,90); 2 dòng mở rộng hoàng kim sau 1 dòng trống
##   6. Đang mặc mà còn dòng ẩn chưa bật: "Cần hệ X của <ô> để kích hoạt thuộc tính ẩn" (vàng)
##   7. Hoàng kim: danh sách món cùng bộ — đang mặc cam 247,195,90 / có trong túi xanh lá / chưa có xanh đậm
## Câu chữ từng thuộc tính lấy từ settings/MagicDesc.ini gốc (format_attrib).

const C_WHITE := "ffffff"
const C_NAME_MAGIC := "6464ff"
const C_NAME_PURPLE := "cc80ff"   ## đồ tím (ItemInstance.is_purple)
const C_GOLD := "ffff00"
const C_PURPLE := "cc80ff"
const C_MAGIC := "6365ff"
const C_MAGIC_HIDDEN := "6464ff"
const C_PURPLE_HIDDEN := "cc80ff"
const C_INACTIVE := "787878"
const C_GOLD_INACTIVE := "7b7d5a"
const C_RED := "ff0000"
const C_SET_WORN := "f7c35a"
const C_SET_OWNED := "00ff00"
const C_SET_MISSING := "004b00"
const C_ATTR_MAX := "1e90ff"       ## Chữ [Max] khi thuộc tính đạt mốc tối đa (Xanh đậm)
## Màu tên hệ (<color=Metal/Wood/Water/Fire/Earth> trong GameSetting.ini).
const ELEMENT_COLORS := {0: "ffe65a", 1: "5ae63c", 2: "5aaaff", 3: "ff5032", 4: "e6963c"}
## [ActiveEquip] GameSetting.ini gốc: hệ cần để kích hoạt món hệ X (NeedSr), và tên 2 ô kích hoạt theo
## loại đồ (NeedEq; nhẫn: 1 = Nhẫn 1, 2 = Nhẫn 2).
const NEED_SERIES := {0: 4, 1: 2, 2: 0, 3: 1, 4: 3}
const NEED_SLOTS := {
	0: "Dây chuyền và Y phục", 1: "Dây chuyền và Y phục", 2: "Nhẫn trái (dưới) và Thắt lưng",
	31: "Vũ khí và Nón", 32: "Ngọc bội và Hộ uyển", 4: "Nhẫn trái (dưới) và Thắt lưng", 5: "Nón và Vũ khí",
	6: "Ngọc bội và Hộ uyển", 7: "Dây chuyền và Y phục", 8: "Nhẫn phải (trên) và Giày", 9: "Nhẫn phải (trên) và Giày",
}

const COLOR_NAME_MAP := {
	"yellow": "ffff00",
	"blue": "6464ff",
	"green": "5ae63c",
	"greeen": "5ae63c",
	"red": "ff0000",
	"orange": "ff9600",
	"white": "ffffff",
	"gold": "ffff00",
	"purple": "cc80ff",
	"water": "5aaaff",
	"metal": "ffe65a",
	"wood": "5ae63c",
	"fire": "ff5032",
	"earth": "e6963c",
}

## Chuyển các thẻ định dạng cũ của VLTK (<color=...>, <color>, </color>, <bclr...>, <enter>) sang BBCode của Godot.
## Đồng thời loại bỏ triệt để các thẻ thừa/lỗi cú pháp để không bao giờ lộ mã thẻ thô lên giao diện UI.
static func clean_vltk_tags(text: String, default_hex: String = "") -> String:
	if text.is_empty():
		return ""
	var re_enter := RegEx.create_from_string("(?i)<enter>")
	var s := re_enter.sub(text, "\n", true)

	var re_bclr := RegEx.create_from_string("(?i)</?bclr(?:=[^>]+)?>")
	s = re_bclr.sub(s, "", true)

	s = s.replace("[lb]", "\u0001").replace("[rb]", "\u0002")
	s = s.replace("[", "[lb]").replace("]", "[rb]")
	s = s.replace("\u0001", "[lb]").replace("\u0002", "[rb]")

	var re_color := RegEx.create_from_string("(?i)<(?:/color|color\\s*=\\s*([a-zA-Z]+)|color)>")
	var out := ""
	var open := false
	var pos := 0
	for m in re_color.search_all(s):
		out += s.substr(pos, m.get_start() - pos)
		var cname := m.get_string(1).to_lower().strip_edges()
		if open:
			out += "[/color]"
			open = false
		if cname != "":
			var hex: String = str(COLOR_NAME_MAP.get(cname, cname))
			if hex.begins_with("#"):
				out += "[color=%s]" % hex
			else:
				out += "[color=#%s]" % hex
			open = true
		pos = m.get_end()
	out += s.substr(pos)
	if open:
		out += "[/color]"

	out = out.strip_edges()
	if default_hex != "" and out != "":
		return _c(default_hex, out)
	return out

## `active` = số dòng ẩn đang bật (Equipment.get_active_counts) — -1 nếu CHƯA MẶC (dòng ẩn xám).
## `part` = ô đang mặc (Equipment.Part) — để chọn đúng gợi ý kích hoạt của nhẫn 1/nhẫn 2.
## `with_name` = false: bỏ dòng tên (khung chi tiết ItemDetailPopup tự vẽ tên + cấp ở phần đầu).
static func build(item: ItemInstance, profile: PlayerProfile, active: int = -1, part: int = -1,
		with_name: bool = true) -> String:
	if item.is_misc():
		return _build_misc(item, with_name)
	var base := item.get_base()
	var gold := item.is_gold()
	var out := []
	if with_name:
		## [lb]/[rb] = dấu [ ] trong BBCode (viết thẳng "[Cấp 5]" sẽ bị hiểu là thẻ).
		out.append(_c(name_color_of(item), "%s [lb]Cấp %d[rb]" % [base.get("name", "?"), item.get_level()]))
	out.append("%s %s" % [_c(C_WHITE, "Thuộc tính ngũ hành:"),
		_c(ELEMENT_COLORS.get(item.series, C_WHITE), ElementTypes.ELEMENT_NAME.get(item.series, ""))])
	var intro: String = "Trang bị Hoàng Kim" if gold and str(base.get("intro", "")) == "" else str(base.get("intro", ""))
	if item.is_purple():
		intro = "Trang bị Huyền Tinh (đồ tím)"
	if intro != "":
		out.append(clean_vltk_tags(intro, C_PURPLE if item.is_purple() else (C_GOLD if gold else C_WHITE)))
	out.append("")

	for entry in item.base_values:
		if entry[0] == "durability_v":
			out.append(_c(C_WHITE, "Độ bền: %d / %d" % [item.durability, item.get_max_durability()]))
		else:
			var text := format_attrib(entry[0], [int(entry[1]), 0, 0])
			if text != "":
				var bracket := _format_bracket_base(item, entry[0], int(entry[1]))
				out.append("%s%s" % [_c(C_WHITE, text), bracket])
	var ctx := Equipment.get_requirement_context(profile) if profile else {}
	for req in item.get_requirements():
		if int(req[1]) <= 0 and req[0] in ["requirelevel", "requirestr", "requiredex", "requirevit", "requireeng"]:
			continue  ## yêu cầu 0 luôn đạt — không hiện cho gọn
		var text := format_attrib(req[0], [int(req[1]), 0, 0])
		if text != "":
			var ok := ctx.is_empty() or Equipment.is_requirement_met(req, ctx)
			out.append(_c(C_WHITE if ok else C_RED, text))

	var remaining := maxi(active, 0)
	var all_active := true
	var purple := item.is_purple()
	for i in item.magic.size():
		var line: Dictionary = item.magic[i]
		if line["attrib"] == "":
			continue
		var text := format_attrib(line["attrib"], line["value"])
		if text == "":
			continue
		var color := C_GOLD if gold else (C_PURPLE if purple else C_MAGIC)
		if i % 2 == 1:
			if remaining > 0:
				remaining -= 1
				color = C_GOLD if gold else (C_PURPLE_HIDDEN if purple else C_MAGIC_HIDDEN)
			else:
				color = C_GOLD_INACTIVE if gold else C_INACTIVE
				all_active = false
		var bracket := _format_bracket_magic(item, line, i, false)
		out.append("%s%s" % [_c(color, text), bracket])
	## Đồ tím: các ô khảm còn trống (Compound — Khảm đồ tím, khoáng thuộc tính đúng thứ tự ô).
	for k in item.sockets:
		out.append(_c(C_INACTIVE, "◇ Ô khảm %d — còn trống" % (item.magic.size() + k + 1)))
	if gold and not item.expand_magic.is_empty():
		out.append("")
		var worn := profile.equipment if profile and active >= 0 else {}
		var expand_active := Equipment.get_expand_active(item, worn) if active >= 0 else 0
		for i in item.expand_magic.size():
			var line: Dictionary = item.expand_magic[i]
			var text := format_attrib(line["attrib"], line["value"])
			if text == "":
				continue
			var color := C_GOLD if i < expand_active else C_GOLD_INACTIVE
			var bracket := _format_bracket_magic(item, line, i, true)
			out.append("%s%s" % [_c(color, text), bracket])

	if active >= 0 and not all_active and not item.magic.is_empty() and item.get_detail() < ItemDatabase.Detail.HORSE:
		out.append("")
		var hint_color := C_PURPLE if purple else C_GOLD
		out.append(_c(hint_color, "Cần hệ %s của %s để kích hoạt thuộc tính ẩn" % [
			_element_name_colored(NEED_SERIES.get(item.series, 0)), _need_slots(item, part)]))
	if gold:
		_append_gold_set(out, item, profile)
	if with_name:
		if item.can_sell():
			var sale_str := InventoryPopup.format_money(item.get_sale_price())
			out.append(_c(C_GOLD, "Giá cả: %s Lượng" % sale_str))
		elif item.is_locked():
			out.append(_c(C_RED, "Vật phẩm đã khóa bảo hiểm"))
	return "[center]%s[/center]" % "\n".join(out)

## Món có HỆ (Sát Thủ lệnh/giản, Nguyên thạch, khoáng thuộc tính ẩn...) — script gốc (killer_token/killer_sword.lua GetDesc) ghi
## "Thuộc tính ngũ hành".
const MISC_WITH_SERIES := ["6_1_150", "6_1_152", "6_1_154", "6_1_399", "6_1_400", "6_1_201", "6_1_203", "6_1_205"]
## Món có CẤP riêng trên tên: lệnh bài Sát thủ (killer_token.lua). Huyền Tinh & khoáng thạch dùng dòng "Phẩm chất thuộc tính: <cấp>".
const MISC_WITH_LEVEL := ["6_1_399", "6_1_400"]

## Thuốc / khoáng thạch / lệnh bài: tên [Cấp], hệ, lời mô tả gốc, tác dụng thuốc (mỗi nửa giây × số frame / 18), số lượng.
static func _build_misc(item: ItemInstance, with_name: bool) -> String:
	var base := item.get_base()
	var out := []
	if with_name:
		var title := str(base.get("name", "?"))
		if item.misc_id in MISC_WITH_LEVEL:
			title += " [lb]Cấp %d[rb]" % item.get_level()
		out.append(_c(C_WHITE, title))
	if item.misc_id in MISC_WITH_SERIES:
		out.append("%s %s" % [_c(C_WHITE, "Thuộc tính ngũ hành:"), _element_name_colored(item.series)])
	var intro := _misc_intro(str(base.get("intro", "")))
	if intro != "":
		out.append(intro)
	## Khoáng thuộc tính (prop_ore.lua): Thuộc tính, Phẩm chất thuộc tính, Loại trang bị có thể khảm nạm.
	if item.ore_magic > 0 or item.misc_id in Compound.PROP_ORES:
		out.append("")
		if item.ore_magic > 0:
			out.append(_c(C_NAME_MAGIC, "Thuộc tính: %s" % Compound.ore_magic_name(item.ore_magic)))
		out.append("%s%s" % [_c(C_NAME_MAGIC, "Phẩm chất thuộc tính: "), _c(C_GOLD, str(item.get_level()))])
		if item.ore_magic > 0:
			var fit := Compound.ore_magic_fit_equip(item.ore_magic)
			if fit != "":
				out.append("%s%s" % [_c("ff9600", "Loại trang bị có thể khảm nạm: "), _c(C_GOLD, fit)])
	## Huyền Tinh Khoáng Thạch (xuanjing_kuangshi.lua): Phẩm chất thuộc tính.
	elif item.misc_id == Compound.XUANJING or item.misc_id == "6_1_147":
		out.append("")
		out.append("%s%s" % [_c(C_NAME_MAGIC, "Phẩm chất thuộc tính: "), _c(C_GOLD, str(item.get_level()))])
	var effects: Array = base.get("effects", [])
	if not effects.is_empty():
		out.append("")
		for e in effects:
			var text := format_attrib(str(e[0]), [int(e[1]), 0, 0])
			if text != "":
				out.append(_c(C_MAGIC, "%s (%d giây)" % [text, ceili(int(e[2]) / 18.0)]))
	if item.count > 1:
		out.append(_c(C_WHITE, "Số lượng: %d" % item.count))
	if with_name:
		if item.can_sell():
			var sale_str := InventoryPopup.format_money(item.get_sale_price())
			out.append(_c(C_GOLD, "Giá cả: %s Lượng" % sale_str))
		elif item.is_locked():
			out.append(_c(C_RED, "Vật phẩm đã khóa bảo hiểm"))
	return "[center]%s[/center]" % "\n".join(out)

## Lời mô tả gốc có thẻ <color=yellow>...<color> và <enter> — đổi sang BBCode.
static func _misc_intro(intro: String) -> String:
	return clean_vltk_tags(intro, C_WHITE)

## Màu tên theo phẩm chất: hoàng kim vàng, đủ 6 dòng magic (đồ tím) tím, có dòng magic (đồ xanh) lam, đồ thường trắng.
static func name_color_of(item: ItemInstance) -> String:
	if item.is_gold():
		return C_GOLD
	if item.is_purple():
		return C_NAME_PURPLE
	return C_NAME_MAGIC if not item.magic.is_empty() else C_WHITE

## Tên phẩm chất: "Hoàng Kim" / "Đồ tím" / "Đồ xanh" / "Đồ thường".
static func quality_name_of(item: ItemInstance) -> String:
	if item.is_gold():
		return "Hoàng Kim"
	if item.is_purple():
		return "Đồ tím"
	return "Đồ xanh" if not item.magic.is_empty() else "Đồ thường"

static func _c(hex: String, text: String) -> String:
	return "[color=#%s]%s[/color]" % [hex, text]

static func _element_name_colored(series: int) -> String:
	return _c(ELEMENT_COLORS.get(series, C_WHITE), ElementTypes.ELEMENT_NAME.get(series, "?"))

static func _need_slots(item: ItemInstance, part: int) -> String:
	var detail := item.get_detail()
	if detail == ItemDatabase.Detail.RING:
		return NEED_SLOTS[32] if part == Equipment.Part.RING2 else NEED_SLOTS[31]
	return NEED_SLOTS.get(detail, "?")

## Danh sách món cùng bộ (KItem::GetDesc gốc): đang mặc cam, có trong túi xanh lá, chưa có xanh đậm.
static func _append_gold_set(out: Array, item: ItemInstance, profile: PlayerProfile) -> void:
	var group := item.get_set_group()
	if group <= 0:
		return
	## So theo LOẠI ĐỒ trong bộ (1 bộ có thể có vài biến thể cùng loại): đang mặc / có trong túi món cùng
	## bộ + cùng loại đó thì tô màu tương ứng. Ở vị trí loại của chính món đang xem thì hiện tên món này.
	var worn := {}
	var owned := {}
	if profile:
		for p in profile.equipment:
			var w: ItemInstance = profile.equipment[p]
			if w.get_set_group() == group:
				worn[w.get_detail()] = true
		for it in profile.inventory:
			if it.get_set_group() == group:
				owned[it.get_detail()] = true
	out.append("")
	for idx in ItemDatabase.get_gold_set_members(group):
		var member := ItemDatabase.get_gold(idx)
		var detail := int(member.get("detail", -1))
		var name: String = item.get_base().get("name", "?") if detail == item.get_detail() else member.get("name", "?")
		var color := C_SET_WORN if worn.has(detail) else (C_SET_OWNED if owned.has(detail) else C_SET_MISSING)
		out.append(_c(color, name))

## Định dạng phần [min - max] (trắng) hoặc [Max] (xanh đậm) ở cuối mỗi dòng thuộc tính trang bị.
## target_max: mốc tối đa toàn game của thuộc tính. Chỉ khi val >= target_max mới hiển thị [Max].
static func _format_bracket(val: int, lo: int, hi: int, target_max: int = -1) -> String:
	if lo >= hi and target_max <= 0:
		return ""
	var max_cap := target_max if target_max > 0 else hi
	if val >= max_cap:
		return " " + _c(C_ATTR_MAX, "[lb]Max[rb]")
	if lo < hi:
		return " " + _c(C_WHITE, "[lb]%d - %d[rb]" % [lo, hi])
	return ""

static func _format_bracket_base(item: ItemInstance, attrib: String, val: int) -> String:
	var base_rec := item.get_base()
	var base_entries: Array = base_rec.get("base", [])
	for b in base_entries:
		if b[0] == attrib:
			var lo := int(b[1])
			var hi := int(b[2])
			if lo < hi:
				return " " + _c(C_WHITE, "[lb]%d - %d[rb]" % [lo, hi])
			break
	return ""

static func _format_bracket_magic(item: ItemInstance, line: Dictionary, line_idx: int, is_expand: bool) -> String:
	var attrib: String = str(line.get("attrib", ""))
	if attrib == "":
		return ""
	var values: Array = line.get("value", [])
	var val: int = int(values[0]) if not values.is_empty() else 0

	var lo: int = 0
	var hi: int = 0

	if item.is_gold() and item.gold_index >= 0:
		var gold_rec := ItemDatabase.get_gold(item.gold_index)
		var g_lines: Array = gold_rec.get("magic", [])
		var target_idx := (ItemInstance.MAX_MAGIC + line_idx) if is_expand else line_idx
		if target_idx >= 0 and target_idx < g_lines.size() and g_lines[target_idx] != null:
			var g_line = g_lines[target_idx]
			if g_line is Dictionary:
				var g_ranges: Array = g_line.get("range", [])
				if not g_ranges.is_empty() and g_ranges[0].size() >= 2:
					lo = int(g_ranges[0][0])
					hi = int(g_ranges[0][1])

	var global_r: Vector2i = ItemDatabase.get_magic_range(attrib, item.series)
	if lo >= hi:
		lo = global_r.x
		hi = global_r.y

	var target_max: int = global_r.y if global_r.y > 0 else hi
	return _format_bracket(val, lo, hi, target_max)

## KMagicDesc::GetDesc gốc — thay giá trị vào mẫu câu MagicDesc.ini:
##   #<loại><chỉ số giá trị><kiểu dấu>: loại d số, s hệ, x giới tính, m môn phái, f frame->giây, l kỹ năng;
##   chỉ số 1/2/3 = nValue[0/1/2]; kiểu dấu '+' luôn ghi dấu +/-, '~' ghi '-' khi dương (dạng giảm).
static func format_attrib(attrib_name: String, values: Array) -> String:
	var template := ItemDatabase.get_desc_template(attrib_name)
	if template == "":
		return ""
	var out := ""
	var i := 0
	while i < template.length():
		var ch := template[i]
		if ch == "#" and i + 2 < template.length():
			var kind := template[i + 1]
			var idx := template[i + 2]
			var sign := template[i + 3] if i + 3 < template.length() else ""
			var value := int(values[0])
			match idx:
				"2": value = int(values[1]) if values.size() > 1 else 0
				"3": value = int(values[2]) if values.size() > 2 else 0
			match kind:
				"d":
					if sign == "+":
						out += ("+%d" % value) if value > 0 else ("-%d" % absi(value))
					elif sign == "~":
						out += ("-%d" % value) if value > 0 else str(value)
					else:
						out += str(value)
				"s":
					out += "Hệ %s" % ElementTypes.ELEMENT_NAME.get(value, "?")
				"x":
					out += "Nữ" if value else "Nam"
				"m":
					var sect := SectRegistry.get_by_id(Equipment.MENPAI_ORDER[value]) if value >= 0 and value < Equipment.MENPAI_ORDER.size() else null
					out += sect.sect_name if sect else "?"
				"f":
					out += str(value / 18)
				"l":
					var skill_name := ItemDatabase.get_vltk_skill_name(value) if value > 0 else ""
					out += "[lb] %s [rb]" % skill_name if skill_name != "" else "Võ công vốn có"
				_:
					out += str(value)
			i += 4 if sign in ["+", "-", "~"] else 3
			continue
		out += ch
		i += 1
	return clean_vltk_tags(out)

## Bỏ thẻ BBCode và các mã thẻ VLTK cũ — cho chỗ chỉ hiện chữ trơn.
static func plain(bbcode: String) -> String:
	var text := bbcode.replace("[lb]", "\u0001").replace("[rb]", "\u0002")
	var re := RegEx.create_from_string("\\[/?[^\\]]+\\]")
	text = re.sub(text, "", true).replace("\u0001", "[").replace("\u0002", "]")
	var re_tag := RegEx.create_from_string("(?i)<(?:/?[a-z_]+(?:=[^>]+)?|/?)>")
	return re_tag.sub(text, "", true).strip_edges()
