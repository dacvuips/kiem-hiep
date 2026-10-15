extends SocialWindow
class_name MapSelectWindow
## Màn "Vượt Ải" (mở từ nút Vượt Ải ở Character Hub): 3 tab lớn Thường / Ải / Địa Ngục.
##   - Thường: cột trái là nhóm cấp 1x..12x, bên phải là các map luyện công thuộc nhóm đó (MapCatalog) — mỗi map có ảnh mini map,
##     tên map, cấp quái + tên quái, nút [Vào] đưa thẳng người chơi vào map (đi lại tự do, quái của map, như map chính).
##   - Ải: Thách Thức Thời Gian (NPC Nhiếp Thí Trần, script gốc VLTK 15 phái — TimeChallenge): 28 ải trong 30 phút.
##         Chiến Trường Tống Kim (BattleServer): số người / điểm mỗi phe + giai đoạn (server tài khoản /v1/battle, làm mới mỗi
##         BATTLE_POLL giây), chọn phe Tống / Kim — lệch quân thì không cho vào; bấm xong phải chờ BATTLE_COOLDOWN giây mới bấm lại.
##   - Địa Ngục: chưa làm.
## Vào map: gọi on_play(entry) — Character Hub lo đổi cảnh (đóng cửa sổ trước khi gọi).

const TABS := ["Thường", "Ải", "Địa Ngục"]
const THUMB_SIZE := Vector2(168, 104)
const LIST_SIZE := Vector2(620, 440)

var _profile: PlayerProfile
var _on_play: Callable
var _tab := 0
var _tier := 1
var _tab_buttons: Array[Button] = []
var _tier_buttons: Array[Button] = []
var _content: HBoxContainer

const BATTLE_POLL := 3.0
const BATTLE_COOLDOWN := 10.0
const BATTLE_NAME := "Chiến Trường Tống Kim"
const BATTLE_PHASES := {"signup": "Đang báo danh", "fight": "Đang khai chiến", "ended": "Vừa kết thúc — chờ trận mới"}
## Lần bấm chọn phe gần nhất (ms) — tĩnh để đóng/mở lại cửa sổ vẫn phải chờ đủ.
static var _battle_clicked_at := -100000
var _battle: Dictionary = {}
var _battle_status: Label
var _battle_sides: Label
var _battle_msg: Label
var _battle_buttons := {}           ## side -> Button
var _battle_timer: Timer
var _battle_poll_acc := 0.0

static func open(host: Node, profile: PlayerProfile, on_play: Callable) -> MapSelectWindow:
	var win := MapSelectWindow.new(profile, on_play)
	return SocialWindow.present(host, win, &"map_select") as MapSelectWindow

func _init(profile: PlayerProfile = null, on_play: Callable = Callable()) -> void:
	super._init("Vượt Ải", "Chọn bản đồ luyện công theo cấp", 800.0)
	_profile = profile
	_on_play = on_play
	_tier = MapCatalog.tier_of_level(profile.level if profile else 1)

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

	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.custom_minimum_size.y = LIST_SIZE.y
	body.add_child(_content)
	_select_tab(0)

func _select_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		GameUi.set_active(_tab_buttons[k], k == i)
	for c in _content.get_children():
		c.queue_free()
	_tier_buttons.clear()
	if i == 0:
		_build_normal()
		return
	if i == 1:
		_build_ai()
		return
	var wip := SocialUi.label("%s: đang phát triển" % TABS[i], SocialUi.MUTED, 16, HORIZONTAL_ALIGNMENT_CENTER)
	wip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content.add_child(wip)

# ---------------------------------------------------------------- tab Ải (Thách Thức Thời Gian)

## Tab Ải: danh sách cuộn các chế độ (Thách Thức Thời Gian, Chiến Trường Tống Kim).
func _build_ai() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = LIST_SIZE
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_build_time_challenge(list)
	_build_battle(list)

func _build_time_challenge(parent: Control) -> void:
	var r := TimeChallenge.rules()
	var card := GameUi.panel(GameUi.PANEL)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	## Bố cục: tiêu đề + lời NPC trải ngang cả thẻ; giữa là luật chơi (trái) + mini map map ải 480 (phải, căn giữa dọc);
	## dưới cùng 2 nút căn giữa thẻ.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(SocialUi.label("Thách Thức Thời Gian", SocialUi.TITLE, 20, HORIZONTAL_ALIGNMENT_CENTER))
	var quote := SocialUi.label("Nhiếp Thí Trần: \"Hãy tiếp nhận nhiệm vụ thách thức thời gian để thể nghiệm sức mạnh đồng đội và khả năng sát thủ của mình.\"",
			SocialUi.MUTED, 13, HORIZONTAL_ALIGNMENT_CENTER)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(quote)
	box.add_child(SocialUi.divider())
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 16)
	box.add_child(middle)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(info)
	var map_frame := _minimap_frame(TimeChallenge.map_entry())
	map_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(map_frame)
	var lines := [
		"Vượt qua 28 ải trong %d phút: hết quái ải này mới ra ải sau; 12 ải có boss, ải 28 là đại boss Độc Cô Quỷ Kiếm." % int(int(r.get("time_limit_sec", 1800)) / 60.0),
		"Điều kiện: cấp từ %d · phí %s lượng + 1 %s · mỗi ngày %d lượt." % [int(r.get("min_level", 80)), TimeChallenge._money(int(r.get("cost", 150000))), TimeChallenge.ENTRY_ITEM_NAME, int(r.get("runs_per_day", 2))],
		"Hoàn thành: thưởng kinh nghiệm, ghi thời gian vượt ải.",
	]
	for t in lines:
		var l := SocialUi.label(t, SocialUi.TEXT, 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)
	var best := TimeChallenge.best_time(_profile)
	info.add_child(SocialUi.label("Kỷ lục của bạn: %s   ·   Hôm nay đã tham gia: %d/%d" % [
			TimeChallenge.format_time(best) if best > 0 else "chưa có", TimeChallenge.runs_today(_profile), int(r.get("runs_per_day", 2))],
			SocialUi.LABEL_BLUE, 14))
	var reason := TimeChallenge.check_entry(_profile)
	var status := SocialUi.label(reason if reason != "" else "Đủ điều kiện tham gia.", SocialUi.WARN if reason != "" else SocialUi.LABEL_BLUE, 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(status)
	box.add_child(SocialUi.divider())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var solo := SocialUi.stone_button("Khiêu chiến một mình", Vector2(220, 44))
	solo.disabled = reason != ""
	solo.pressed.connect(_start_time_challenge)
	row.add_child(solo)
	var team := SocialUi.stone_button("Chờ tổ đội", Vector2(160, 44))
	team.disabled = true
	team.tooltip_text = "Khiêu chiến cùng tổ đội online: đang phát triển"
	row.add_child(team)

func _start_time_challenge() -> void:
	var reason := TimeChallenge.check_entry(_profile)
	if reason != "":
		_select_tab(1)
		return
	SocialWindow.confirm(self, "Thách Thức Thời Gian",
			"Tham gia khiêu chiến? Tốn %s lượng, 1 %s và 1 lượt hôm nay." % [
				TimeChallenge._money(int(TimeChallenge.rules().get("cost", 150000))), TimeChallenge.ENTRY_ITEM_NAME],
			func() -> void:
				if not TimeChallenge.pay_entry(_profile):
					_select_tab(1)
					return
				_play(TimeChallenge.map_entry()))

# ---------------------------------------------------------------- tab Ải (Chiến Trường Tống Kim)

func _build_battle(parent: Control) -> void:
	_battle_buttons.clear()
	var card := GameUi.panel(GameUi.PANEL)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_minimap_frame({"dir": _battle_dir(int(_battle.get("map_id", 378)))}))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(SocialUi.label(BATTLE_NAME, SocialUi.TITLE, 18))
	var rules := SocialUi.label("Chọn phe Tống hoặc Kim. Báo danh xong chờ trong doanh trại (chuẩn bị) tới giờ khai chiến mới được ra trận. Hạ người phe kia được điểm; chết về hậu doanh phe mình. Hết giờ phe nhiều điểm hơn thắng.", SocialUi.MUTED, 13)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(rules)
	_battle_status = SocialUi.label("Đang tải…", SocialUi.LABEL_BLUE, 14)
	info.add_child(_battle_status)
	_battle_sides = SocialUi.label("", SocialUi.TEXT, 15)
	info.add_child(_battle_sides)
	_battle_msg = SocialUi.label("", SocialUi.WARN, 13)
	_battle_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_battle_msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	info.add_child(buttons)
	for side in BattleServer.SIDES:
		var b := SocialUi.stone_button("Vào phe %s" % BattleServer.SIDE_NAMES[side], Vector2(150, 40))
		b.pressed.connect(_join_battle.bind(side))
		buttons.add_child(b)
		_battle_buttons[side] = b
	if _battle_timer == null:
		_battle_timer = Timer.new()
		_battle_timer.wait_time = 1.0
		_battle_timer.timeout.connect(_battle_tick)
		add_child(_battle_timer)
		_battle_timer.start()
	_battle_poll_acc = BATTLE_POLL
	_battle_tick()

## Khung ảnh mini map của 1 map (entry có "dir") — dùng chung cho thẻ map luyện công, Thách Thức Thời Gian, Tống Kim.
static func _minimap_frame(entry: Dictionary) -> Control:
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = THUMB_SIZE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture = _crop_dark(MapCatalog.minimap_texture(entry))
	var frame := GameUi.panel(GameUi.PANEL)
	frame.add_child(thumb)
	return frame

## Ảnh mini map xuất từ tool có phần nền đen ngoài vùng map (map nhỏ chỉ chiếm 1 góc ảnh) — cắt theo khung bao vùng có
## hình (dò thưa mỗi 4 điểm ảnh) để thẻ không bị 1 mảng đen lớn. Lưu đệm theo ảnh gốc.
static var _cropped: Dictionary = {}

static func _crop_dark(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _cropped.has(tex):
		return _cropped[tex]
	var image := tex.get_image()
	if image == null:
		return tex
	if image.is_compressed():
		image.decompress()
	var lo := Vector2i(image.get_width(), image.get_height())
	var hi := Vector2i(-1, -1)
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).get_luminance() > 0.06:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var out: Texture2D = tex
	if hi.x >= 0:
		var rect := Rect2i(lo, hi - lo + Vector2i(4, 4)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		if rect.size != image.get_size():
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(rect)
			out = atlas
	_cropped[tex] = out
	return out

static func _battle_dir(map_id: int) -> String:
	return "res://world/maps/map_%d" % map_id

func _cooldown_left() -> float:
	return maxf(0.0, BATTLE_COOLDOWN - (Time.get_ticks_msec() - _battle_clicked_at) / 1000.0)

## Mỗi giây: cập nhật đếm ngược nút; mỗi BATTLE_POLL giây hỏi lại trạng thái trận.
func _battle_tick() -> void:
	if _tab != 1 or _battle_status == null or not is_instance_valid(_battle_status):
		return
	_battle_poll_acc += 1.0
	if _battle_poll_acc >= BATTLE_POLL:
		_battle_poll_acc = 0.0
		_fetch_battle()
	_render_battle()

func _fetch_battle() -> void:
	if not AccountApi.is_logged_in():
		_battle = {}
		return
	var r: Dictionary = await AccountApi.battle(ServerSelectScreen.selected_server_id)
	if not is_inside_tree():
		return
	_battle = r.data if r.ok and r.data is Dictionary else {}
	_render_battle()

func _render_battle() -> void:
	if _battle_status == null or not is_instance_valid(_battle_status):
		return
	var cd := _cooldown_left()
	var open := bool(_battle.get("open", false))
	if not AccountApi.is_logged_in():
		_battle_status.text = "Chiến trường chỉ có khi chơi trên máy chủ (đăng nhập tài khoản)."
		_battle_sides.text = ""
	elif not open:
		_battle_status.text = "Chiến trường chưa mở (máy chủ chiến trường không hoạt động)."
		_battle_sides.text = ""
	else:
		var left := int(_battle.get("phase_left", 0))
		@warning_ignore("integer_division")
		var minutes := left / 60
		_battle_status.text = "%s · còn %02d:%02d · cấp từ %d" % [BATTLE_PHASES.get(str(_battle.get("phase", "")), "?"), minutes, left % 60,
			int(_battle.get("min_level", 0))]
		_battle_sides.text = "Phe Tống: %d người · %d điểm        Phe Kim: %d người · %d điểm" % [int(_battle.get("song", 0)),
			int(_battle.get("song_points", 0)), int(_battle.get("jin", 0)), int(_battle.get("jin_points", 0))]
	for side in _battle_buttons:
		var b: Button = _battle_buttons[side]
		b.disabled = cd > 0.0 or not open
		b.text = "Chờ %ds" % ceili(cd) if cd > 0.0 else "Vào phe %s" % BattleServer.SIDE_NAMES[side]

## Bấm chọn phe: luôn tính lượt chờ BATTLE_COOLDOWN giây. Kiểm tra trước ở đây (lệch quân, cấp, trận kết thúc) — server kiểm tra lại khi vào.
func _join_battle(side: String) -> void:
	if _cooldown_left() > 0.0:
		return
	_battle_clicked_at = Time.get_ticks_msec()
	_battle_msg.text = ""
	if not bool(_battle.get("open", false)):
		_battle_msg.text = "Chiến trường chưa mở."
	elif str(_battle.get("phase", "")) == "ended":
		_battle_msg.text = "Trận này đã kết thúc, xin chờ trận sau."
	elif _profile and _profile.level < int(_battle.get("min_level", 0)):
		_battle_msg.text = "Cấp %d trở lên mới được vào chiến trường." % int(_battle.get("min_level", 0))
	else:
		var other := "jin" if side == "song" else "song"
		var mine := int(_battle.get(side, 0))
		var theirs := int(_battle.get(other, 0))
		var balance := int(_battle.get("balance", BattleServer.BALANCE))
		if mine - theirs >= balance:
			_battle_msg.text = "Phe %s đang đông hơn phe %s %d người — không thể vào lúc này, hãy chọn phe %s hoặc chờ thêm." % [
				BattleServer.SIDE_NAMES[side], BattleServer.SIDE_NAMES[other], mine - theirs, BattleServer.SIDE_NAMES[other]]
		else:
			var map_id := int(_battle.get("map_id", 378))
			_play({"id": map_id, "name": BATTLE_NAME, "dir": _battle_dir(map_id), "battle": {"side": side, "server": {
				"host": str(_battle.get("host", "127.0.0.1")), "port": int(_battle.get("port", 7787)),
				"ws_url": str(_battle.get("ws_url", "")), "name": BATTLE_NAME}}})
			return
	_render_battle()

# ---------------------------------------------------------------- tab Thường

func _build_normal() -> void:
	var tier_scroll := ScrollContainer.new()
	tier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tier_scroll.custom_minimum_size = Vector2(110, LIST_SIZE.y)
	var tiers := VBoxContainer.new()
	tiers.add_theme_constant_override("separation", 6)
	tiers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_scroll.add_child(tiers)
	for t in range(1, MapCatalog.TIER_COUNT + 1):
		var count := MapCatalog.in_tier(t).size()
		var b := GameUi.button("%dx" % t if count > 0 else "%dx  —" % t, GameUi.TAB)
		b.custom_minimum_size.y = 34
		b.pressed.connect(_select_tier.bind(t))
		tiers.add_child(b)
		_tier_buttons.append(b)
	_content.add_child(tier_scroll)

	var list_scroll := ScrollContainer.new()
	list_scroll.name = "MapList"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = LIST_SIZE
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(list_scroll)
	_select_tier(_tier)

func _select_tier(t: int) -> void:
	_tier = t
	for k in _tier_buttons.size():
		GameUi.set_active(_tier_buttons[k], k + 1 == t)
	var scroll := _content.get_node_or_null("MapList") as ScrollContainer
	if scroll == null:
		return
	for c in scroll.get_children():
		c.queue_free()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var maps := MapCatalog.in_tier(t)
	if maps.is_empty():
		list.add_child(SocialUi.label("Chưa có bản đồ %dx." % t, SocialUi.MUTED, 14))
		return
	for m in maps:
		list.add_child(_map_card(m))

func _map_card(m: Dictionary) -> Control:
	var card := GameUi.panel(GameUi.PANEL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	row.add_child(_minimap_frame(m))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(SocialUi.label(str(m["name"]), SocialUi.TITLE, 17))
	info.add_child(SocialUi.label("Cấp quái: %d  ·  %d quái" % [int(m["level"]), int(m.get("monster_count", 0))], SocialUi.LABEL_BLUE, 13))
	var names: Array[String] = []
	for mon in m.get("monsters", []):
		names.append("%s (Lv%d)" % [mon["name"], int(mon["level"])])
	var mons := SocialUi.label("Quái: " + ", ".join(names), SocialUi.TEXT, 13)
	mons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(mons)

	var playable := MapCatalog.is_playable(m)
	var play := SocialUi.stone_button("Vào" if playable else "Chưa có", Vector2(96, 40))
	play.disabled = not playable
	play.tooltip_text = "" if playable else "Bản đồ này chưa được xuất (tools/export_training_maps.py)"
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_play.bind(m))
	row.add_child(play)
	return card

func _play(m: Dictionary) -> void:
	close_requested.emit()
	if _on_play.is_valid():
		_on_play.call(m)
