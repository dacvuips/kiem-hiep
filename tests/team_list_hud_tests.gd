extends Node
## Kiểm thử KHUNG DANH SÁCH TỔ ĐỘI góc trái (TeamListHud): ẩn khi không có đội, đồng đội (trừ mình) có tên + máu, cờ đội trưởng,
## đổi đội trưởng / máu online (S_TEAM_HP) / rời đội thì khung cập nhật. Chạy:
##   KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/team_list_hud_tests.tscn

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	SocialDirectory.reset()
	var p := PlayerProfile.new()
	p.display_name = "DoiTruongThu"
	p.level = 60
	p.lead_level = 60
	GameManager.local_profile = p
	var team := SocialHub.of(p).team
	var ui := CanvasLayer.new()
	add_child(ui)
	var hud := TeamListHud.new()
	ui.add_child(hud)
	await frames()
	check("không có đội: khung ẩn", not hud.visible)

	## Offline: lập đội + mời 2 người chơi giả.
	team.create_team()
	await frames()
	check("đội 1 người (chỉ mình): vẫn ẩn", not hud.visible)
	for i in 2:
		var m := MockPlayer.new()
		m.id = 1000 + i
		m.name = ["Lý Hạo Nhiên", "Kim Miêu"][i]
		m.level = 10
		m.lead_level = 30
		m.camp = p.get_current_camp()
		m.invite_accept_rate = 1.0
		var err := team.invite(m)
		check("mời người chơi giả %d" % i, err == "", err)
	await frames()
	var snap := hud.snapshot()
	check("đội 3 người: khung hiện 2 đồng đội (không gồm mình)", hud.visible and snap.size() == 2, snap)
	check("offline: đồng đội đầy máu, không có cờ (mình là đội trưởng)", snap.all(func(r: Dictionary) -> bool: return r.hp == 100 and not r.captain), snap)
	check("khung nằm dưới hàng nút PK (y >= 104)", hud.position.y >= 104.0, hud.position)
	var frame: StyleBox = hud.get_theme_stylebox("panel")
	check("1 khung lớn chung, nền bán trong suốt", frame is StyleBoxFlat and (frame as StyleBoxFlat).bg_color.a > 0.0
		and (frame as StyleBoxFlat).bg_color.a < 0.8, frame)
	var rows_ok := true
	for r in hud._rows:
		var b: Button = r.button
		rows_ok = rows_ok and b.get_parent() == hud._list and b.get_theme_stylebox("normal") is StyleBoxEmpty
	check("mỗi dòng nằm trong khung lớn, không khung / nền riêng", rows_ok and hud._rows.size() == 2)

	## Đổi đội trưởng sang đồng đội đầu: dòng của họ có cờ, nằm đầu.
	if team.members.is_empty():
		print("RESULT %d đạt, %d hỏng" % [_pass, _fail + 1])
		get_tree().quit(1)
		return
	var new_cap: TeamService.Member = team.members[0]
	team.change_captain(new_cap)
	await frames()
	snap = hud.snapshot()
	check("đổi đội trưởng: dòng đầu là đội trưởng mới có cờ", snap.size() == 2 and snap[0].name == new_cap.name and snap[0].captain, snap)

	## Máu online (S_TEAM_HP): 35%, ở khác phòng -> tô mờ.
	team.apply_net_hp([{"eid": new_cap.id, "hp": 35, "near": false}])
	await frames()
	snap = hud.snapshot()
	check("máu đồng đội cập nhật 35% + ở xa", snap[0].hp == 35 and not snap[0].near, snap)

	## Trạng thái đội từ server: mình (eid 5) là thành viên, đội trưởng eid 7, thêm eid 9.
	NetClient.my_eid = 5
	team.apply_net_state({"in_team": true, "captain": 7, "open": true, "pick": 1, "turn": 0, "applicants": [], "members": [
		{"eid": 7, "name": "Nguyễn Minh Nguy", "level": 10, "camp": Camp.Type.BALANCE, "lead": 10, "sect": ""},
		{"eid": 5, "name": "DoiTruongThu", "level": 60, "camp": 0, "lead": 60, "sect": ""},
		{"eid": 9, "name": "Lý Hạo Nhiên", "level": 10, "camp": 0, "lead": 0, "sect": ""}]})
	team.apply_net_hp([{"eid": 7, "hp": 80, "near": true}, {"eid": 5, "hp": 100, "near": true}, {"eid": 9, "hp": 0, "near": true}])
	await frames()
	snap = hud.snapshot()
	check("online: 2 dòng, đội trưởng có cờ đứng đầu",
		snap.size() == 2 and snap[0].name == "Nguyễn Minh Nguy" and snap[0].captain and not snap[1].captain, snap)
	check("online: máu 80% / 0% (trọng thương)", snap.size() == 2 and snap[0].hp == 80 and snap[1].hp == 0, snap)

	## Người chơi khác trên map: đồng đội eid 9 (phe Tà) tô màu phe đội trưởng (Trung lập), có thanh máu dưới tên theo snapshot.
	var rp := RemotePlayer.new()
	add_child(rp)
	rp.setup({"eid": 9, "name": "Lý Hạo Nhiên", "level": 10, "camp": Camp.Type.EVIL, "pos": Vector2(500, 500), "look": {},
		"flags": 0, "dir": 0, "action": 0, "z": 0, "hp": 40})
	var outsider := RemotePlayer.new()
	add_child(outsider)
	outsider.setup({"eid": 11, "name": "Người Lạ", "level": 10, "camp": Camp.Type.EVIL, "pos": Vector2(600, 500), "look": {},
		"flags": 0, "dir": 0, "action": 0, "z": 0, "hp": 100})
	await frames()
	var name_col := func(r: RemotePlayer) -> Color: return r._label.get_theme_color("font_color")
	check("đồng đội: tên màu phe đội trưởng", name_col.call(rp) == Camp.get_color(Camp.Type.BALANCE), name_col.call(rp))
	check("người ngoài đội: tên màu phe của họ", name_col.call(outsider) == Camp.get_color(Camp.Type.EVIL), name_col.call(outsider))
	rp._apply({"flags": 0, "dir": 0, "action": 0, "z": 0, "hp": 40})
	await frames()
	check("RemotePlayer: thanh máu dưới tên 40%", rp._hp_bar != null and is_equal_approx(rp._hp_bar.bar.value, 40.0)
		and rp._hp_bar.position.y > rp._label.position.y, [rp._hp_bar.bar.value if rp._hp_bar else -1])

	## Rời đội -> khung ẩn, tên đồng đội cũ về màu phe của họ.
	team.apply_net_state({"in_team": false})
	await frames()
	check("rời đội: khung ẩn", not hud.visible and hud.snapshot().is_empty())
	check("rời đội: tên người cũ về màu phe của họ", name_col.call(rp) == Camp.get_color(Camp.Type.EVIL), name_col.call(rp))
	NetClient.my_eid = 0

	## Nối server mới (Sảnh -> map / sang phòng train ở tiến trình khác): server không mang đội theo -> client xoá đội cũ.
	var social := NetSocial.create(func(_t: String) -> void: pass)
	add_child(social)
	team.apply_net_state({"in_team": true, "captain": 7, "open": true, "pick": 1, "turn": 0, "applicants": [], "members": [
		{"eid": 7, "name": "Nguyễn Minh Nguy", "level": 10, "camp": 0, "lead": 10, "sect": ""},
		{"eid": 9, "name": "Lý Hạo Nhiên", "level": 10, "camp": 0, "lead": 0, "sect": ""}]})
	await frames()
	check("trước khi nối lại: đang có đội", team.in_team() and hud.visible)
	NetClient.connected_to_world.emit(21, Vector2.ZERO, "DoiTruongThu")
	await frames()
	check("nối server mới: xoá đội cũ, khung ẩn", not team.in_team() and not hud.visible)
	social.queue_free()
	NetClient.my_eid = 0

	print("RESULT %d đạt, %d hỏng" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
