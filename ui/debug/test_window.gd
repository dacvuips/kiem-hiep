extends SocialWindow
class_name TestWindow
## Bảng TEST trên MÀN CHƠI (nút "TEST", chỉ bản debug — bản release không có nút): thử nhanh nhân vật ngay trong map.
##  - Nhân vật: lên cấp, điểm kỹ năng, đồ ngẫu nhiên, tiền / danh vọng / lãnh đạo, tẩy điểm, về cấp 1.
##  - Chỉ số cộng thêm (PlayerProfile.test_attribs, tên thuộc tính VLTK): máu, nội lực, sát thương, chính xác, phòng thủ, kháng,
##    chí mạng, tốc chạy, hồi máu, hút máu, 4 chỉ số gốc... cộng vào như 1 món trang bị (đi qua đúng công thức CombatantStats).
## Mọi thay đổi lưu ngay (online: server chỉ nhận khi bật chế độ dev — xem docs/.env.example) rồi dựng lại chỉ số nhân vật.

signal profile_changed

## [tên hiện, [thuộc tính VLTK...], bước +/-]. Nhiều thuộc tính = cùng cộng 1 lượng (VD sát thương 4 hệ).
const STATS := [
	["Sinh lực (máu)", ["lifemax_v"], 1000],
	["Nội lực (mana)", ["manamax_v"], 1000],
	["Sát thương vật lý", ["addphysicsdamage_v"], 100],
	["Sát thương vật lý %", ["addphysicsdamage_p"], 50],
	["Sát thương Băng/Hỏa/Lôi/Độc", ["addcolddamage_v", "addfiredamage_v", "addlightingdamage_v", "addpoisondamage_v"], 100],
	["Chính xác", ["attackrating_v"], 500],
	["Phòng thủ", ["armordefense_v"], 500],
	["Kháng tất cả %", ["allres_p"], 10],
	["Chí mạng %", ["deadlystrikeenhance_p"], 10],
	["Tốc chạy %", ["fastwalkrun_p"], 25],
	["Hồi máu (mỗi nhịp)", ["lifereplenish_v"], 50],
	["Hút máu %", ["steallife_p"], 5],
	["Sức mạnh", ["strength_v"], 50],
	["Thân pháp", ["dexterity_v"], 50],
	["Sinh khí", ["vitality_v"], 50],
	["Nội công", ["energy_v"], 50],
]

var _profile: PlayerProfile
var _values := {}          ## tên hiện -> Label giá trị
var _summary: Label
var _result: Label

static func open(host: Node, profile: PlayerProfile) -> TestWindow:
	return SocialWindow.present(host, TestWindow.new(profile), &"test_window") as TestWindow

func _init(profile: PlayerProfile = null) -> void:
	super._init("TEST", "Chỉ để thử — lưu ngay, online cần bật chế độ dev ở server", 560.0)
	_profile = profile
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	_build_character(v)
	_build_stats(v)
	_result = SocialUi.label("", SocialUi.MUTED, 13)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_result)
	_refresh()

# ---------------------------------------------------------------- nhân vật

func _build_character(parent: VBoxContainer) -> void:
	var sec := SocialUi.section("Nhân vật")
	parent.add_child(sec[0])
	var box: VBoxContainer = sec[1]
	_row(box, [
		["Cấp +1", func() -> void: _levels(1)],
		["Cấp +10", func() -> void: _levels(10)],
		["Cấp +50", func() -> void: _levels(50)],
		["Về cấp 1", func() -> void: SocialWindow.confirm(get_parent(), "Về cấp 1", "Đưa nhân vật về cấp 1?", func() -> void:
			_profile.reset_to_level_1()
			_commit("Đã đưa nhân vật về cấp 1."))],
	])
	_row(box, [
		["Điểm kỹ năng +10", func() -> void:
			_profile.skill_points += 10
			_commit("+10 điểm kỹ năng.")],
		["Điểm tiềm năng +50", func() -> void:
			_profile.potential_points += 50
			_commit("+50 điểm tiềm năng.")],
		["Tẩy điểm", func() -> void: SocialWindow.confirm(get_parent(), "Tẩy điểm", "Hoàn lại toàn bộ điểm tiềm năng + kỹ năng đã cộng?", func() -> void:
			var r := _profile.refund_all_points()
			_commit("Đã tẩy: hoàn %d điểm tiềm năng, %d điểm kỹ năng." % [r["potential"], r["skill"]]))],
	])
	_row(box, [
		["Đồ ngẫu nhiên +1", func() -> void: _items(1)],
		["Đồ ngẫu nhiên +10", func() -> void: _items(10)],
		["+20tr lượng", func() -> void:
			_profile.gold += 20_000_000
			_commit("+20.000.000 lượng.")],
	])
	_row(box, [
		["+Danh vọng/Phúc duyên", func() -> void:
			_profile.prestige += 100
			_profile.fuyuan += 100
			_commit("+100 danh vọng, +100 phúc duyên.")],
		["+Lãnh đạo", func() -> void:
			_profile.lead_level = mini(_profile.lead_level + 5, 100)
			_commit("Cấp lãnh đạo %d." % _profile.lead_level)],
	])
	_row(box, [
		["Gia nhập / Đổi phái", func() -> void: _choose_sect()],
	])

func _levels(count: int) -> void:
	for i in count:
		_profile.level_up()
	_commit("Lên %d cấp — hiện cấp %d." % [count, _profile.level])

func _items(count: int) -> void:
	var added := 0
	for i in count:
		if _profile.add_item(ItemGenerator.random_equipment(_profile.level)):
			added += 1
	_commit("Đã nhận %d món đồ (Hành trang %d/%d)." % [added, _profile.inventory.size(), PlayerProfile.INVENTORY_CAPACITY])

func _choose_sect() -> void:
	if _profile == null:
		return
	if _profile.needs_sect():
		var win := SectChoiceWindow.open(get_parent(), _profile)
		win.chosen.connect(func(sect: SectDefinition) -> void:
			_commit("Đã gia nhập môn phái: %s." % sect.sect_name))
		return
	var popup := PopupMenu.new()
	var sects := SectRegistry.load_all()
	for i in sects.size():
		var s := sects[i]
		var elem_str: String = ElementTypes.ELEMENT_NAME.get(s.element, "")
		popup.add_item("%s (%s)" % [s.sect_name, elem_str], i)
	popup.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < sects.size():
			_profile.set_sect(sects[id])
			_commit("Đã đổi môn phái sang: %s." % sects[id].sect_name)
		popup.queue_free()
	)
	popup.popup_hide.connect(func() -> void: popup.queue_free())
	add_child(popup)
	popup.popup_centered(Vector2i(200, 300))

# ---------------------------------------------------------------- chỉ số cộng thêm

func _build_stats(parent: VBoxContainer) -> void:
	var sec := SocialUi.section("Chỉ số cộng thêm")
	parent.add_child(sec[0])
	var box: VBoxContainer = sec[1]
	_summary = SocialUi.label("", SocialUi.TEXT, 13)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for st in STATS:
		var title_label := SocialUi.label(st[0], SocialUi.TEXT, 13)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(title_label)
		var value_label := SocialUi.label("0", Color(0.55, 0.95, 0.55), 13, HORIZONTAL_ALIGNMENT_RIGHT)
		value_label.custom_minimum_size.x = 70
		grid.add_child(value_label)
		_values[st[0]] = value_label
		for step_mul in [-1, 1, 10]:
			var step: int = int(st[2]) * step_mul
			var b := SocialUi.small_button(("%+d" % step) if step_mul != 1 else "+%d" % step)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_add_stat.bind(st[1], step))
			grid.add_child(b)
	var clear := SocialUi.small_button("Xoá hết chỉ số cộng thêm")
	clear.pressed.connect(func() -> void:
		_profile.test_attribs.clear()
		_commit("Đã xoá hết chỉ số cộng thêm."))
	box.add_child(clear)

func _add_stat(attribs: Array, step: int) -> void:
	for a in attribs:
		var v: int = maxi(0, int(_profile.test_attribs.get(a, 0)) + step)
		if v == 0:
			_profile.test_attribs.erase(a)
		else:
			_profile.test_attribs[a] = v
	_commit("")

# ---------------------------------------------------------------- chung

func _row(parent: VBoxContainer, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for spec in buttons:
		var b := SocialUi.small_button(spec[0])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
	parent.add_child(row)

## Lưu + dựng lại chỉ số nhân vật đang chơi + vẽ lại bảng.
func _commit(message: String) -> void:
	SaveManager.save_profile(_profile)
	SaveManager.flush_online()
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player != null and player.has_method("refresh_combat_stats"):
		player.refresh_combat_stats()
	if message != "":
		_result.text = message
	_refresh()
	profile_changed.emit()

func _refresh() -> void:
	if _profile == null:
		return
	for st in STATS:
		var label: Label = _values.get(st[0])
		if label != null:
			label.text = str(int(_profile.test_attribs.get(st[1][0], 0)))
	var s := _profile.get_combat_stats()
	_summary.text = "Cấp %d · Máu %d · Nội lực %d · Chính xác %d · Phòng thủ %d · Tốc chạy +%d%% · Đánh tay %d-%d" % [
		_profile.level, s.max_hp, s.max_mana, s.attack_rating, s.defense, s.move_speed_p, s.unarmed_min_damage, s.unarmed_max_damage]
