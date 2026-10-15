extends SocialWindow
class_name RankingWindow
## Bảng xếp hạng (nút "BXH" ở Character Hub) — số liệu từ server (GET /v1/rankings, server giữ ~60 giây):
##   - Cao Thủ: cấp cao nhất toàn máy chủ (cùng cấp: nhiều kinh nghiệm hơn đứng trên).
##   - Phú Hộ: nhiều tiền nhất toàn máy chủ (tiền mang theo + tiền trong rương).
##   - Môn Phái: chọn 1 trong 15 phái -> cao thủ + phú hộ của phái đó; cột trái ghi sẵn đệ nhất cao thủ mỗi phái.
## Chơi offline (chưa đăng nhập máy chủ) thì không có bảng.

const TABS := ["Cao Thủ", "Phú Hộ", "Môn Phái"]
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
	super._init("Bảng Xếp Hạng", "", 760.0)
	_profile = profile
	_sect = profile.sect_id if profile and SECT_ORDER.has(profile.sect_id) else SECT_ORDER[0]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in TABS.size():
		var b := GameUi.button(TABS[i], GameUi.TAB)
		b.custom_minimum_size = Vector2(140, 38)
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
		_status.text = "Bảng xếp hạng chỉ có khi chơi trên máy chủ (đăng nhập tài khoản)."
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
	_select_tab(_tab)

func _select_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[k], k == i)
	for c in _content.get_children():
		c.queue_free()
	if _data.is_empty():
		return
	match i:
		0: _content.add_child(_board("Cao thủ toàn máy chủ", _data.get("level", []), false))
		1: _content.add_child(_board("Phú hộ toàn máy chủ", _data.get("money", []), true))
		2: _build_sects()

# ---------------------------------------------------------------- tab Môn Phái

func _build_sects() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(200, LIST_HEIGHT)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var sect_level: Dictionary = _data.get("sect_level", {})
	for id in SECT_ORDER:
		var top: Array = sect_level.get(id, [])
		var leader := "%s (%d)" % [top[0]["name"], int(top[0]["level"])] if not top.is_empty() else "—"
		var b := GameUi.button("%s\n%s" % [_sect_name(id), leader], GameUi.TAB)
		b.custom_minimum_size.y = 46
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		GameUi.set_active(b, id == _sect)
		b.pressed.connect(func() -> void:
			_sect = id
			_select_tab(2))
		list.add_child(b)
	_content.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_board("Cao thủ %s" % _sect_name(_sect), (_data.get("sect_level", {}) as Dictionary).get(_sect, []), false, true))
	cols.add_child(_board("Phú hộ %s" % _sect_name(_sect), (_data.get("sect_money", {}) as Dictionary).get(_sect, []), true, true))
	_content.add_child(cols)

# ---------------------------------------------------------------- bảng

## 1 bảng xếp hạng: hạng · tên · (phái) · cấp hoặc tiền. `compact` = bảng hẹp trong tab Môn Phái (bỏ cột phái).
func _board(header: String, rows: Array, by_money: bool, compact := false) -> Control:
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
		var value := InventoryPopup.format_money(int(e["money"])) if by_money else "Cấp %d" % int(e["level"])
		var value_l := SocialUi.label(value, SocialUi.LABEL_GREEN if by_money else SocialUi.LABEL_BLUE, 13, HORIZONTAL_ALIGNMENT_RIGHT)
		value_l.custom_minimum_size.x = 110 if by_money else 70
		row.add_child(value_l)
		list.add_child(row)
	return panel

static func _sect_name(id: String) -> String:
	if id == "":
		return "Vô môn phái"
	var sect := SectRegistry.get_by_id(id)
	return sect.sect_name if sect else id
