extends SocialWindow
class_name RankingWindow

## Bảng xếp hạng (nút "BXH" ở Character Hub) — số liệu từ server (GET /v1/rankings, server giữ ~60 giây):
##   - Cao Thủ: cấp cao nhất toàn máy chủ (cùng cấp: nhiều kinh nghiệm hơn đứng trên).
##   - Phú Hộ: nhiều tiền nhất toàn máy chủ (tiền mang theo + tiền trong rương).
##   - Võ Lâm PK: xếp hạng điểm Đấu trường PK (Đại hội võ lâm & Võ lâm Liên đấu).
##   - Môn Phái: chọn 1 trong 15 phái -> cao thủ + phú hộ của phái đó; cột trái ghi sẵn đệ nhất cao thủ mỗi phái.
## Chơi offline (chưa đăng nhập máy chủ) thì vẫn xem được BXH Đấu trường võ lâm.

const TABS := ["Cao Thủ", "Phú Hộ", "Võ Lâm PK", "Môn Phái"]
## Thứ tự môn phái theo bảng môn phái gốc (tools/vltk_source.py SECTS).
const SECT_ORDER := ["thieu_lam", "thien_vuong_bang", "duong_mon", "ngu_doc_giao", "nga_mi", "thuy_yen_mon", "cai_bang",
	"thien_nhan_giao", "vo_dang", "con_lon", "hoa_son", "vu_hon", "tieu_dao", "duong_gia", "minh_giao"]
const LIST_HEIGHT := 440.0
const RANK_COLORS := [Color(1.0, 0.84, 0.3), Color(0.85, 0.87, 0.9), Color(0.85, 0.6, 0.35)]

var _profile: PlayerProfile
var _data: Dictionary = {}
var _tab := 0
var _sect := ""
var _tab_buttons: Array[Button] = []
var _content: Control
var _status: Label

static func open(host: Node, profile: PlayerProfile) -> RankingWindow:
	var win := RankingWindow.new(profile)
	return SocialWindow.present(host, win, &"ranking") as RankingWindow

func _init(profile: PlayerProfile = null) -> void:
	super._init("Bảng Xếp Hạng", "", 520.0)
	_profile = profile
	_sect = profile.sect_id if profile and SECT_ORDER.has(profile.sect_id) else SECT_ORDER[0]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in TABS.size():
		var b := GameUi.button(TABS[i], GameUi.TAB)
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	body.add_child(tabs)
	_status = SocialUi.label("", SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_status)
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.custom_minimum_size.y = LIST_HEIGHT
	body.add_child(_content)
	for i in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[i], i == 0)

func _ready() -> void:
	super._ready()
	_load()

func _load() -> void:
	if not AccountApi.is_logged_in():
		_status.text = "Bảng xếp hạng Đấu Trường Võ Lâm (Chế độ cục bộ)"
		_select_tab(_tab)
		return
	_status.text = "Đang tải..."
	var r: Dictionary = await AccountApi.rankings(ServerSelectScreen.selected_server_id)
	if not is_inside_tree():
		return
	if not r.ok:
		_status.text = str(r.message)
		return
	_data = r.data if r.data is Dictionary else {}
	_status.text = "Máy chủ %s · cập nhật mỗi %d giây" % [str(ServerSelectScreen.selected_server.get("name", ServerSelectScreen.selected_server_id)), int(_data.get("ttl_seconds", 60))]
	_update_profile_rank()
	_select_tab(_tab)

func _update_profile_rank() -> void:
	if _profile == null:
		return
	var me := _profile.display_name
	var found := false
	for entry in _data.get("level", []):
		if entry is Dictionary and str(entry.get("name", "")) == me:
			_profile.world_rank = str(entry.get("rank", "—"))
			found = true
			break
	if not found and not (_data.get("level", []) as Array).is_empty():
		_profile.world_rank = ">100"

## Đồng bộ và trả về vị trí xếp hạng của nhân vật
static func fetch_my_rank(profile: PlayerProfile) -> String:
	if profile == null:
		return "—"
	var me := profile.display_name
	if AccountApi.is_logged_in():
		var r: Dictionary = await AccountApi.rankings(ServerSelectScreen.selected_server_id)
		if r.ok and r.data is Dictionary:
			var levels: Array = r.data.get("level", [])
			for entry in levels:
				if entry is Dictionary and str(entry.get("name", "")) == me:
					return str(entry.get("rank", "—"))
			if not levels.is_empty():
				return ">100"
	var entries: Array[Dictionary] = []
	entries.append({"name": me, "level": profile.level, "pk_points": profile.pk_points})
	var recs: Dictionary = PkMatch._records()
	for p_name in recs:
		if p_name == me:
			continue
		var user_rec: Dictionary = recs[p_name]
		var pts: int = 0
		for m_str in user_rec:
			var m_dict: Dictionary = user_rec[m_str]
			pts = maxi(pts, int(m_dict.get("points", 0)))
		entries.append({"name": str(p_name), "level": 90, "pk_points": pts})
	var default_masters: Array[Dictionary] = [
		{"name": "Độc Cô Cầu Bại", "level": 120, "pk_points": 250},
		{"name": "Trương Tam Phong", "level": 118, "pk_points": 220},
		{"name": "Vô Danh Thần Tăng", "level": 115, "pk_points": 200},
		{"name": "Tiêu Phong", "level": 112, "pk_points": 180},
		{"name": "Dương Quá", "level": 110, "pk_points": 160},
		{"name": "Lệnh Hồ Xung", "level": 105, "pk_points": 140},
		{"name": "Đoàn Dự", "level": 102, "pk_points": 120},
		{"name": "Hoàng Dược Sư", "level": 100, "pk_points": 100},
	]
	for dm in default_masters:
		var dm_name: String = str(dm["name"])
		if not entries.any(func(e: Dictionary) -> bool: return str(e["name"]) == dm_name):
			entries.append(dm)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = int(a.get("pk_points", 0))
		var pb: int = int(b.get("pk_points", 0))
		if pa != pb:
			return pa > pb
		return int(a.get("level", 0)) > int(b.get("level", 0))
	)
	for idx in entries.size():
		if str(entries[idx]["name"]) == me:
			return str(idx + 1)
	return "—"

func _select_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[k], k == i)
	for c in _content.get_children():
		c.queue_free()
	match i:
		0:
			if _data.is_empty():
				_content.add_child(_board("Cao thủ toàn máy chủ", [], "level"))
			else:
				_content.add_child(_board("Cao thủ toàn máy chủ", _data.get("level", []), "level"))
		1:
			if _data.is_empty():
				_content.add_child(_board("Phú hộ toàn máy chủ", [], "money"))
			else:
				_content.add_child(_board("Phú hộ toàn máy chủ", _data.get("money", []), "money"))
		2:
			_content.add_child(_pk_board())
		3:
			_build_sects()

func _pk_board() -> Control:
	var list: Array = []
	if _data.has("pk") and _data["pk"] is Array and not (_data["pk"] as Array).is_empty():
		list = _data["pk"]
	else:
		var entries: Array[Dictionary] = []
		var my_pts: int = _profile.pk_points if _profile else 0
		var my_name: String = _profile.display_name if _profile else "Hiệp Khách"
		var my_sect: String = _profile.sect_id if _profile else ""
		var my_level: int = _profile.level if _profile else 1
		entries.append({"name": my_name, "sect_id": my_sect, "level": my_level, "pk_points": my_pts})

		var recs: Dictionary = PkMatch._records()
		for p_name in recs:
			if p_name == my_name:
				continue
			var user_rec: Dictionary = recs[p_name]
			var pts: int = 0
			for m_str in user_rec:
				var m_dict: Dictionary = user_rec[m_str]
				pts = maxi(pts, int(m_dict.get("points", 0)))
			entries.append({"name": str(p_name), "sect_id": "", "level": 90, "pk_points": pts})

		var default_masters: Array[Dictionary] = [
			{"name": "Độc Cô Cầu Bại", "sect_id": "hoa_son", "level": 120, "pk_points": 250},
			{"name": "Trương Tam Phong", "sect_id": "vo_dang", "level": 118, "pk_points": 220},
			{"name": "Vô Danh Thần Tăng", "sect_id": "thieu_lam", "level": 115, "pk_points": 200},
			{"name": "Tiêu Phong", "sect_id": "cai_bang", "level": 112, "pk_points": 180},
			{"name": "Dương Quá", "sect_id": "con_lon", "level": 110, "pk_points": 160},
			{"name": "Lệnh Hồ Xung", "sect_id": "hoa_son", "level": 105, "pk_points": 140},
			{"name": "Đoàn Dự", "sect_id": "tieu_dao", "level": 102, "pk_points": 120},
			{"name": "Hoàng Dược Sư", "sect_id": "thuy_yen_mon", "level": 100, "pk_points": 100},
		]
		for dm in default_masters:
			var dm_name: String = str(dm["name"])
			if not entries.any(func(e: Dictionary) -> bool: return str(e["name"]) == dm_name):
				entries.append(dm)

		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var pa: int = int(a.get("pk_points", 0))
			var pb: int = int(b.get("pk_points", 0))
			if pa != pb:
				return pa > pb
			return int(a.get("level", 0)) > int(b.get("level", 0))
		)
		for idx in entries.size():
			var e: Dictionary = entries[idx]
			list.append({
				"rank": idx + 1,
				"name": e["name"],
				"sect_id": e.get("sect_id", ""),
				"level": int(e.get("level", 1)),
				"pk_points": int(e.get("pk_points", 0))
			})
	return _board("Bảng Xếp Hạng Đấu Trường Võ Lâm (Thắng +10, Thua -2)", list, "pk")

# ---------------------------------------------------------------- tab Môn Phái

func _build_sects() -> void:
	var sect_box := VBoxContainer.new()
	sect_box.add_theme_constant_override("separation", 6)
	sect_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(sect_box)

	var opt_row := HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 8)
	sect_box.add_child(opt_row)
	opt_row.add_child(SocialUi.label("Chọn môn phái:", SocialUi.TEXT, 14))

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in SECT_ORDER:
		opt.add_item(_sect_name(id))
	opt.selected = SECT_ORDER.find(_sect) if SECT_ORDER.has(_sect) else 0
	opt.item_selected.connect(func(idx: int) -> void:
		_sect = SECT_ORDER[idx]
		_select_tab(3))
	opt_row.add_child(opt)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_board("Cao thủ %s" % _sect_name(_sect), (_data.get("sect_level", {}) as Dictionary).get(_sect, []), "level", true))
	cols.add_child(_board("Phú hộ %s" % _sect_name(_sect), (_data.get("sect_money", {}) as Dictionary).get(_sect, []), "money", true))
	sect_box.add_child(cols)

# ---------------------------------------------------------------- bảng

## 1 bảng xếp hạng: hạng · tên · (phái) · cấp, tiền hoặc điểm PK. `compact` = bảng hẹp trong tab Môn Phái (bỏ cột phái).
func _board(header: String, rows: Array, value_type: String, compact := false) -> Control:
	var sec := SocialUi.info_box(header)
	var panel: Control = sec[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = LIST_HEIGHT - 50.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	sec[1].add_child(scroll)
	TouchScrollHelperScript.attach(scroll, panel)
	if rows.is_empty():
		list.add_child(SocialUi.label("Chưa có ai.", SocialUi.MUTED, 13))
		return panel
	var me := _profile.display_name if _profile else ""
	for e in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var rank := int(e["rank"])
		var rank_l := SocialUi.label("%d" % rank, RANK_COLORS[rank - 1] if rank <= RANK_COLORS.size() else SocialUi.SUBTITLE, 14, HORIZONTAL_ALIGNMENT_RIGHT)
		rank_l.custom_minimum_size.x = 30
		row.add_child(rank_l)
		var name_l := SocialUi.label(str(e["name"]), SocialUi.GOLD if str(e["name"]) == me else SocialUi.TEXT, 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		row.add_child(name_l)
		if not compact:
			var sect_l := SocialUi.label(_sect_name(str(e["sect_id"])), SocialUi.SUBTITLE, 13)
			sect_l.custom_minimum_size.x = 130
			row.add_child(sect_l)
		var value := ""
		var color: Color = SocialUi.TEXT
		if value_type == "money":
			value = InventoryPopup.format_money(int(e["money"]))
			color = SocialUi.LABEL_GREEN
		elif value_type == "pk":
			value = "%d điểm" % int(e.get("pk_points", e.get("points", 0)))
			color = SocialUi.GOLD
		else:
			value = "Cấp %d" % int(e["level"])
			color = SocialUi.LABEL_BLUE
		var value_l := SocialUi.label(value, color, 13, HORIZONTAL_ALIGNMENT_RIGHT)
		value_l.custom_minimum_size.x = 110 if value_type in ["money", "pk"] else 70
		row.add_child(value_l)
		list.add_child(row)
	return panel

static func _sect_name(id: String) -> String:
	if id == "":
		return "Vô môn phái"
	var sect := SectRegistry.get_by_id(id)
	return sect.sect_name if sect else id
