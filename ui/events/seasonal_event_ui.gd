class_name SeasonalEventUi
extends RefCounted
## Mảnh UI dùng chung cho SỰ KIỆN NĂM (tab "Sự kiện Năm" của EventScheduleWindow, cửa sổ Hướng dẫn, EventCraftWindow):
## ô ảnh vật phẩm (kiểu ô hành trang, có số lượng + tooltip tên), dòng công thức "A×n + B×n (+ tiền) → thành phẩm",
## và cửa sổ Hướng dẫn liệt kê công thức, vật phẩm dùng được, phần thưởng, nguồn nguyên liệu.

const CELL := 40
const MAX_PICK_LINES := 12
## Màu bậc hiếm nguyên liệu trong Hộp sự kiện ("tier" do tools/export_seasonal_events.py ghi).
const TIER_COLORS := {"Thường": Color(0.82, 0.82, 0.78), "Hơi hiếm": Color(0.35, 0.9, 0.45), "Hiếm": Color(0.4, 0.7, 1.0),
	"Rất hiếm": Color(0.85, 0.5, 1.0)}

## Ô ảnh 1 vật phẩm (nền xanh như ô hành trang) — count > 0 thì hiện số lượng góc dưới phải.
static func icon_cell(mid: String, count := 0, size := CELL) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = ItemRoomView.ITEM_BG
	st.border_color = Color(0.1, 0.35, 0.22)
	st.set_border_width_all(1)
	st.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(size, size)
	var rec := ItemDatabase.get_misc(mid)
	var tip := str(rec.get("name", mid))
	var intro := str(rec.get("intro", "")).replace("<enter>", "\n")
	if intro != "":
		tip += "\n" + intro
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var tex := TextureRect.new()
	tex.texture = SeasonalEvents.item_icon(mid)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tex)
	if count > 0:
		var l := Label.new()
		l.text = _short(count)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color(1, 1, 1))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
	return p

static func _short(n: int) -> String:
	if n >= 1_000_000:
		return "%dtr" % (n / 1_000_000)
	if n >= 10_000:
		return "%dk" % (n / 1000)
	return str(n)

static func flow(sep := 4) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f

static func _sym(text: String, color := GameUi.GOLD, size := 16) -> Label:
	var l := SocialUi.label(text, color, size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y = CELL
	return l

## Hàng ảnh các món (không trùng) — dùng cho "Nguyên liệu" / "Thành phẩm" trên thẻ sự kiện.
static func icon_row(mids: Array, size := 34) -> HFlowContainer:
	var f := flow(3)
	for mid in mids:
		f.add_child(icon_cell(str(mid), 0, size))
	return f

## Mọi nguyên liệu (không trùng, theo thứ tự công thức) và thành phẩm của 1 sự kiện.
static func event_materials(ev: Dictionary) -> Array:
	var out: Array = []
	for r in ev.get("recipes", []):
		for m in r.get("materials", []):
			for mid in SeasonalEvents.mat_items(m):
				if not out.has(mid):
					out.append(mid)
	return out

## Vật phẩm làm ảnh đại diện thẻ: "cover" trong dữ liệu, không có thì thành phẩm trực tiếp của công thức đầu tiên.
static func cover_item(ev: Dictionary) -> String:
	var c := str(ev.get("cover", ""))
	if c != "":
		return c
	for r in ev.get("recipes", []):
		var res: Variant = r.get("result", {})
		if res is Dictionary and res.has("item"):
			return str(res["item"])
	var all := event_results(ev)
	return str(all[0]) if not all.is_empty() else ""

static func event_results(ev: Dictionary) -> Array:
	var out: Array = []
	for r in ev.get("recipes", []):
		SeasonalEvents.result_items(r.get("result", {}), out)
	return out

## Dòng công thức: [ảnh nguyên liệu×n] + ... (+ tiền) → [thành phẩm] (ngẫu nhiên / kinh nghiệm).
static func recipe_row(r: Dictionary) -> HFlowContainer:
	var f := flow(4)
	var first := true
	for m in r.get("materials", []):
		if not first:
			f.add_child(_sym("+"))
		first = false
		if m.has("any"):
			f.add_child(_sym("%d món bất kỳ trong [" % int(m["count"]), SocialUi.SUBTITLE, 13))
			for mid in SeasonalEvents.mat_items(m):
				f.add_child(icon_cell(mid, 0, 30))
			f.add_child(_sym("]", SocialUi.SUBTITLE, 13))
		else:
			f.add_child(icon_cell(str(m["item"]), int(m["count"])))
	var money := int(r.get("money", 0))
	if money > 0:
		if not first:
			f.add_child(_sym("+"))
		f.add_child(_sym("%s lượng" % SeasonalEvents._fmt(money), GameUi.LABEL_GREEN, 14))
	f.add_child(_sym("→", GameUi.TITLE, 20))
	var res: Variant = r.get("result", {})
	var items := SeasonalEvents.result_items(res)
	if res is Dictionary and res.has("item"):
		f.add_child(icon_cell(str(res["item"]), int(res.get("count", 1))))
	else:
		for mid in items.slice(0, 8):
			f.add_child(icon_cell(str(mid)))
		if items.size() > 8:
			f.add_child(_sym("+%d món" % (items.size() - 8), SocialUi.SUBTITLE, 13))
		var lines := SeasonalEvents.describe(res)
		if items.is_empty() and not lines.is_empty():
			f.add_child(_sym(", ".join(lines), GameUi.LABEL_GREEN, 14))
		elif res is Dictionary and res.has("pick"):
			f.add_child(_sym("(ngẫu nhiên)", SocialUi.SUBTITLE, 13))
	if r.has("rate"):
		f.add_child(_sym("— tỷ lệ thành công %s%%" % SeasonalEvents.pct(float(r["rate"])), Color(1.0, 0.7, 0.35), 13))
	if r.has("fail_result"):
		var back := SeasonalEvents.result_items(r["fail_result"])
		f.add_child(_sym("· thất bại trả lại", SocialUi.SUBTITLE, 13))
		for mid in back:
			f.add_child(icon_cell(mid, 0, 30))
	if int(r.get("limit", 0)) > 0:
		f.add_child(_sym("· tối đa %d lần / đợt" % int(r["limit"]), SocialUi.SUBTITLE, 13))
	return f

static func calendar_text(ev: Dictionary) -> String:
	var a: Array = ev.get("anchor", [1, 1])
	if str(ev.get("calendar", "solar")) == "lunar":
		return "Âm lịch %d/%d" % [int(a[1]), int(a[0])]
	return "Dương lịch %d/%d" % [int(a[1]), int(a[0])]

## Trạng thái ngắn: {text, color}.
static func status_of(per: Dictionary, now: int = -1) -> Dictionary:
	if now < 0:
		now = SeasonalEvents.now_unix()
	if per.get("status", "") == "ongoing":
		var left := int(ceil((int(per["end"]) - now) / 86400.0))
		return {"text": "Đang diễn ra (còn %d ngày)" % maxi(left, 1), "color": Color(0.25, 0.95, 0.45)}
	var days := int(ceil((int(per.get("start", now)) - now) / 86400.0))
	if days <= 7:
		return {"text": "Sắp diễn ra (còn %d ngày)" % maxi(days, 1), "color": Color(1.0, 0.82, 0.25)}
	return {"text": "Còn %d ngày nữa" % days, "color": Color(0.75, 0.75, 0.72)}

static func _wrap_label(text: String, color: Color, size := 13) -> Label:
	var l := SocialUi.label(text, color, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 1
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## Các dòng mô tả thưởng, rút gọn danh sách quay ngẫu nhiên quá dài.
static func award_lines(node: Variant) -> Array:
	var lines := SeasonalEvents.describe(node)
	var out: Array = []
	var bullets := 0
	var hidden := 0
	for l in lines:
		if str(l).begins_with("   •"):
			bullets += 1
			if bullets > MAX_PICK_LINES:
				hidden += 1
				continue
		else:
			if hidden > 0:
				out.append("   … và %d phần thưởng hiếm khác" % hidden)
			bullets = 0
			hidden = 0
		out.append(str(l))
	if hidden > 0:
		out.append("   … và %d phần thưởng hiếm khác" % hidden)
	return out

## Cửa sổ HƯỚNG DẪN: thời gian, công thức ép (ảnh nguyên liệu + số lượng → thành phẩm), vật phẩm dùng được và phần thưởng
## (kể cả tỷ lệ quay, thưởng mốc, giới hạn), nguồn nguyên liệu theo source gốc.
static func open_guide(host: Node, ev: Dictionary) -> SocialWindow:
	var win := SocialWindow.new("Hướng dẫn — %s" % ev.get("name", ""), calendar_text(ev), 760.0)
	var per := SeasonalEvents.current_period(ev)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(1, 500)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.body.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = 1
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	box.add_child(SocialUi.kv("📅 Thời gian:", "%s — %s" % [SeasonalEvents.format_date(per["start"]), SeasonalEvents.format_date(per["end"])], GameUi.GOLD))
	box.add_child(_wrap_label(str(ev.get("desc", "")), SocialUi.TEXT, 13))
	box.add_child(_wrap_label("Cách ép: bấm \"Chế tạo\", kéo (hoặc bấm) nguyên liệu từ hành trang sang ô bên phải và nhập số lượng. Hệ thống tự tính số lần ép, phần dư giữ lại hành trang; thành phẩm vào hành trang (đầy thì vào rương). Ép thất bại vẫn mất nguyên liệu.", SocialUi.SUBTITLE, 12))

	var sec := SocialUi.section("Công thức ép")
	for r in ev.get("recipes", []):
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		card.add_child(SocialUi.label(str(r.get("name", "")), GameUi.TITLE, 14))
		card.add_child(recipe_row(r))
		var res: Variant = r.get("result", {})
		if not (res is Dictionary and res.has("item")):
			for l in award_lines(res):
				card.add_child(_wrap_label(str(l), Color(0.72, 0.9, 0.85), 12))
		var ms: Dictionary = r.get("milestones", {})
		if not ms.is_empty():
			card.add_child(_wrap_label(_milestone_text(ms, "ép"), Color(0.95, 0.78, 0.35), 12))
		sec[1].add_child(card)
		sec[1].add_child(SocialUi.divider())
	box.add_child(sec[0])

	var uses: Dictionary = ev.get("usables", {})
	if not uses.is_empty():
		var sec2 := SocialUi.section("Vật phẩm dùng được & phần thưởng")
		for mid in uses:
			var u: Dictionary = uses[mid]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(icon_cell(str(mid)))
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.custom_minimum_size.x = 1
			var head := SeasonalEvents.item_name(str(mid))
			var cond: Array = []
			if int(u.get("min_level", 0)) > 0:
				cond.append("cấp %d+" % int(u["min_level"]))
			if int(u.get("limit", 0)) > 0:
				cond.append("tối đa %d lần / đợt" % int(u["limit"]))
			if not cond.is_empty():
				head += "  (" + ", ".join(cond) + ")"
			col.add_child(SocialUi.label(head, GameUi.TITLE, 14))
			for l in award_lines(u.get("result", {})):
				col.add_child(_wrap_label(str(l), Color(0.72, 0.9, 0.85), 12))
			var ms2: Dictionary = u.get("milestones", {})
			if not ms2.is_empty():
				col.add_child(_wrap_label(_milestone_text(ms2, "dùng"), Color(0.95, 0.78, 0.35), 12))
			row.add_child(col)
			sec2[1].add_child(row)
			sec2[1].add_child(SocialUi.divider())
		box.add_child(sec2[0])

	var buffs: Dictionary = ev.get("buff_items", {})
	if not buffs.is_empty():
		var lamps := true
		for mid in buffs:
			lamps = lamps and buffs[mid].has("exp_x2_minutes")
		var sec4 := SocialUi.section("Thắp lồng đèn (bấm \"Thắp Đèn\" trong hành trang)" if lamps else "Ăn bánh tăng sức (bấm \"Dùng\" trong hành trang)")
		for mid in buffs:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(icon_cell(str(mid)))
			var txt := str(buffs[mid].get("text", ""))
			if txt == "":
				txt = "nhân đôi kinh nghiệm %d phút (không dùng chung với Tiên Thảo Lộ)" % int(buffs[mid].get("exp_x2_minutes", 0))
			row.add_child(_wrap_label("%s: %s" % [SeasonalEvents.item_name(str(mid)), txt], Color(0.72, 0.9, 0.85), 12))
			sec4[1].add_child(row)
		box.add_child(sec4[0])

	var box_id := SeasonalEvents.drop_box_of(ev)
	if box_id != "":
		var sec5 := SocialUi.section("Vật phẩm rớt từ quái (chỉ khi chơi online)")
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(icon_cell(box_id))
		head.add_child(_wrap_label("Trong thời gian sự kiện, mọi quái có %s%% rơi %s. Bấm \"Dùng\" trong hành trang để mở ra 1 nguyên liệu ngẫu nhiên:" % [
			SeasonalEvents.pct(SeasonalEvents.box_drop_rate() * 100.0), SeasonalEvents.item_name(box_id)], Color(0.72, 0.9, 0.85), 12))
		sec5[1].add_child(head)
		var picks: Array = (ev.get("usables", {}).get(box_id, {}).get("result", {}) as Dictionary).get("pick", []).duplicate()
		picks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("rate", 0)) > float(b.get("rate", 0)))
		var f := flow(6)
		for x in picks:
			var cell := VBoxContainer.new()
			cell.add_child(icon_cell(str(x.get("item", "")), 0, 36))
			var tier := str(x.get("tier", ""))
			var tc: Color = TIER_COLORS.get(tier, SocialUi.SUBTITLE)
			cell.add_child(SocialUi.label("%s%%" % SeasonalEvents.pct(float(x.get("rate", 0))), tc, 11, HORIZONTAL_ALIGNMENT_CENTER))
			if tier != "":
				cell.add_child(SocialUi.label(tier, tc, 10, HORIZONTAL_ALIGNMENT_CENTER))
			cell.tooltip_text = "%s — %s%% (%s)" % [SeasonalEvents.item_name(str(x.get("item", ""))), SeasonalEvents.pct(float(x.get("rate", 0))), tier]
			f.add_child(cell)
		sec5[1].add_child(f)
		box.add_child(sec5[0])

	var src: Dictionary = ev.get("material_sources", {})
	if not src.is_empty():
		var sec3 := SocialUi.section("Nguồn nguyên liệu (theo source gốc)")
		for mid in src:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(icon_cell(str(mid)))
			row.add_child(_wrap_label("%s: %s" % [SeasonalEvents.item_name(str(mid)), "; ".join(src[mid])], SocialUi.TEXT, 12))
			sec3[1].add_child(row)
		box.add_child(sec3[0])

	var btn_row := win.add_button_row()
	var close := SocialUi.stone_button("Đóng")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: win.close_requested.emit())
	btn_row.add_child(close)
	return SocialWindow.present(host, win, &"event_guide")

static func _milestone_text(ms: Dictionary, verb: String) -> String:
	var keys := ms.keys()
	keys.sort_custom(func(a, b) -> bool: return int(a) < int(b))
	var parts: Array = []
	for k in keys:
		parts.append("lần %s: %s" % [k, ", ".join(SeasonalEvents.describe(ms[k])).replace("   • ", "")])
	return "Thưởng mốc khi %s đủ — %s" % [verb, "; ".join(parts)]
