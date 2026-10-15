extends Node
## Kiểm thử luồng tài khoản phía client (AccountApi + các màn tài khoản) với server tài khoản THẬT đang chạy
## (cd server && docker compose up -d). Chạy:
##   godot --headless --path . res://tests/account_tests.tscn
## Mã OTP quên mật khẩu đọc từ hộp thư giả Mailpit (http://127.0.0.1:8025).
## In "PASS/FAIL" từng ca, cuối cùng "RESULT x/y" và thoát mã 1 nếu có ca hỏng.

const MAILPIT := "http://127.0.0.1:8025"
const SCENES := [
	"res://ui/login/Login.tscn",
	"res://ui/account/Register.tscn",
	"res://ui/account/ForgotPassword.tscn",
	"res://ui/account/AccountDialog.tscn",
	"res://ui/server_select/ServerSelect.tscn",
	"res://ui/character_roster/CharacterRoster.tscn",
]

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, "  ", detail)

func _ready() -> void:
	test_validation()
	await test_session_lock()
	test_profile_guard()
	test_scenes_load()
	await test_api_flow()
	print("RESULT %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func test_validation() -> void:
	check("tên hợp lệ", AccountScreen.check_username("abc_123") == "")
	check("tên ngắn", AccountScreen.check_username("ab") != "")
	check("tên có dấu", AccountScreen.check_username("hiếu") != "")
	check("email hợp lệ", AccountScreen.check_email("a@b.vn") == "")
	check("email sai", AccountScreen.check_email("a@b") != "")
	check("mật khẩu hợp lệ", AccountScreen.check_new_password("matkhau1", "matkhau1", "abc") == "")
	check("mật khẩu ngắn", AccountScreen.check_new_password("12345", "12345", "abc") != "")
	check("mật khẩu chứa tên", AccountScreen.check_new_password("xxabcxx", "xxabcxx", "abc") != "")
	check("nhập lại không khớp", AccountScreen.check_new_password("matkhau1", "matkhau2", "abc").begins_with("Nhập lại"))

## 2 cửa sổ game trên 1 máy: cửa sổ đang chạy giữ file phiên, cửa sổ kia không được tự đăng nhập bằng phiên đó (sẽ bị server đá cả 2).
func test_session_lock() -> void:
	var lock := AccountApi.SESSION_LOCK_PATH
	var backup := FileAccess.get_file_as_string(lock) if FileAccess.file_exists(lock) else ""
	if FileAccess.file_exists(lock):
		DirAccess.remove_absolute(lock)
	check("phiên: chưa ai giữ thì cửa sổ này nhận giữ", AccountApi._own_session_file()
		and FileAccess.get_file_as_string(lock).to_int() == OS.get_process_id())
	var other := OS.create_process("ping", ["-n", "30", "127.0.0.1"] if OS.get_name() == "Windows" else ["-c", "30", "127.0.0.1"])
	var f := FileAccess.open(lock, FileAccess.WRITE)
	f.store_string(str(other))
	f.close()
	check("phiên: cửa sổ khác đang chạy giữ phiên thì không dùng được", other > 0 and not AccountApi._own_session_file())
	OS.kill(other)
	await get_tree().create_timer(0.5).timeout
	check("phiên: cửa sổ giữ phiên đã tắt thì nhận giữ lại", AccountApi._own_session_file())
	if backup != "":
		f = FileAccess.open(lock, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(lock)

func test_profile_guard() -> void:
	var server := PlayerProfile.new()
	server.set_sect(SectRegistry.get_by_element(ElementTypes.ElementType.MOC)[0])
	server.level = 10
	server.potential_points += PlayerProfile.POTENTIAL_POINTS_PER_LEVEL * 9
	server.skill_points += PlayerProfile.SKILL_POINTS_PER_LEVEL * 9
	var sd := server.to_dict()
	var cheat := sd.duplicate(true)
	cheat["level"] = 90
	cheat["strength"] = int(cheat["strength"]) + 500
	var m := ProfileGuard.merge(sd, cheat)
	check("ProfileGuard: không đổi được cấp", int(m.level) == 10)
	check("ProfileGuard: cộng lố điểm tiềm năng bị trả về", int(m.strength) == int(sd.strength))
	var legit := sd.duplicate(true)
	legit["strength"] = int(legit["strength"]) + 5
	legit["potential_points"] = int(legit["potential_points"]) - 5
	legit["hotbar_page"] = 1
	m = ProfileGuard.merge(sd, legit)
	check("ProfileGuard: cộng điểm đúng luật được nhận", int(m.strength) == int(sd.strength) + 5 and int(m.hotbar_page) == 1)
	## Đã bỏ phe Tống / Kim cố định: bản lưu gửi lên còn khoá "nation" thì bị xoá
	var n1 := sd.duplicate(true)
	n1["nation"] = Nation.Type.SONG
	check("ProfileGuard: bỏ khoá phe Tống / Kim cũ", not ProfileGuard.merge(sd, n1).has("nation"))
	var hit := ProfileGuard.max_hit(server)
	check("ProfileGuard: trần sát thương hợp lý", hit >= ProfileGuard.MIN_CAP and hit < 100000.0, hit)
	check("ProfileGuard: kinh nghiệm hạ quái", ProfileGuard.exp_for_kill(10, MonsterData.monster(1), 10, 100) >= 0)
	## Đồ + tiền (C1)
	var owner := PlayerProfile.new()
	owner.set_sect(SectRegistry.get_by_element(ElementTypes.ElementType.MOC)[0])
	owner.gold = 1000
	var sword := ItemGenerator.random_equipment(10)
	owner.add_item(sword)
	var od := owner.to_dict()
	var c1 := od.duplicate(true)
	(c1.inventory as Array).append({"base": 1, "uid": "fake0000fake0000"})
	(c1.inventory as Array).append((c1.inventory as Array)[0].duplicate(true))   ## nhân bản cùng uid
	(c1.inventory as Array)[0]["magic"] = [{"attrib": "damage_v", "value": [9999, 0, 0], "name": "x", "prefix": true}]
	(c1.inventory as Array)[0]["rx"] = 5
	c1["gold"] = 50000
	var g := ProfileGuard.merge(od, c1)
	check("ProfileGuard: bỏ món tự chế + bản nhân bản", (g.inventory as Array).size() == 1)
	check("ProfileGuard: chỉ số món đồ giữ bản server", (g.inventory as Array)[0].magic == (od.inventory as Array)[0].magic)
	check("ProfileGuard: vị trí món do chủ đổi được", int((g.inventory as Array)[0].rx) == 5)
	check("ProfileGuard: không tăng được tiền", int(g.gold) == 1000)
	var c2 := od.duplicate(true)
	c2["gold"] = 400
	c2["storage_gold"] = 600
	check("ProfileGuard: chuyển tiền vào rương được", int(ProfileGuard.merge(od, c2).storage_gold) == 600)
	## C5: rương, khoá bảo vệ, khoá món đồ
	var rich := owner.to_dict()
	rich["gold"] = 600000
	var c3 := rich.duplicate(true)
	c3["storage_extra"] = 1
	check("ProfileGuard: mở rương không trả tiền bị chặn", int(ProfileGuard.merge(rich, c3).storage_extra) == 0)
	c3["gold"] = 100000
	check("ProfileGuard: mở rương có trả tiền được nhận", int(ProfileGuard.merge(rich, c3).storage_extra) == 1)
	var locked := rich.duplicate(true)
	locked["security_hash"] = "x".repeat(64)
	locked["security_locked"] = true
	var c4 := locked.duplicate(true)
	c4["security_locked"] = false
	check("ProfileGuard: không tự mở khoá bảo vệ được", bool(ProfileGuard.merge(locked, c4).security_locked))
	var srv_item := rich.duplicate(true)
	(srv_item.inventory as Array)[0]["lock"] = ItemInstance.LOCK_LOCKED
	var c5 := srv_item.duplicate(true)
	(c5.inventory as Array)[0]["lock"] = ItemInstance.LOCK_NORMAL
	check("ProfileGuard: không bỏ khoá món đồ ngay được", int((ProfileGuard.merge(srv_item, c5).inventory as Array)[0].lock) == ItemInstance.LOCK_LOCKED)
	(c5.inventory as Array)[0]["lock"] = ItemInstance.LOCK_UNLOCKING
	(c5.inventory as Array)[0]["unlock_at"] = SecurityLock.now() + SecurityLock.ITEM_UNLOCK_SECONDS
	check("ProfileGuard: xin mở khoá (chờ 3 ngày) được nhận", int((ProfileGuard.merge(srv_item, c5).inventory as Array)[0].lock) == ItemInstance.LOCK_UNLOCKING)
	check("ItemInstance có uid riêng", sword.uid.length() == 16 and ItemGenerator.random_equipment(10).uid != sword.uid)

func test_scenes_load() -> void:
	for path in SCENES:
		var packed: PackedScene = load(path)
		check("nạp scene " + path.get_file(), packed != null and packed.can_instantiate())

func test_api_flow() -> void:
	var api: Node = get_node("/root/AccountApi")
	var user := "t%d" % (Time.get_unix_time_from_system() as int % 100000000)
	var email := user + "@example.com"

	var g: Dictionary = await api.google_login()
	check("Google chưa cấu hình thì báo rõ", g.code == "google_disabled" or g.code == "google_canceled" or g.ok == false, g)

	var r: Dictionary = await api.register(user, email, "matkhau1")
	if r.code == "network":
		check("server tài khoản đang chạy", false, "chạy: cd server && docker compose up -d")
		return
	check("đăng ký", r.ok and api.username() == user, r)
	check("đăng ký trùng tên", (await api.register(user, email, "matkhau1")).code == "username_taken")

	r = await api.servers()
	check("danh sách máy chủ", r.ok and r.data.servers.size() > 0, r)
	check("có access token", (await api.access_token()) != "")

	await test_characters(api, user)

	r = await api.change_password("sai_mat_khau", "matkhau2")
	check("đổi mật khẩu sai mk cũ", r.code == "wrong_password", r)
	r = await api.change_password("matkhau1", "matkhau2")
	check("đổi mật khẩu", r.ok, r)

	await api.logout()
	check("đăng xuất", not api.is_logged_in() and not api.has_saved_session())

	r = await api.login(user, "matkhau1", false)
	check("mật khẩu cũ hết tác dụng", r.code == "wrong_login", r)
	r = await api.login(user.to_upper(), "matkhau2", true)
	check("đăng nhập + ghi nhớ", r.ok and api.has_saved_session(), r)
	check("tên đã ghi nhớ", api.saved_username() == user)

	## Mô phỏng mở lại game: quên phiên trong RAM, đăng nhập lại bằng phiên đã ghi nhớ.
	api.account = {}
	api._access = ""
	r = await api.resume()
	check("tự đăng nhập lại", r.ok and api.username() == user, r)
	r = await api.servers()
	check("gọi API sau khi tự đăng nhập", r.ok, r)

	r = await api.forgot_password(user, email)
	check("quên mật khẩu", r.ok, r)
	await get_tree().create_timer(1.0).timeout
	var code := await _read_otp(email)
	check("nhận mã OTP", code.length() == 6, code)
	r = await api.reset_password(user, "000000" if code != "000000" else "111111", "matkhau3")
	check("mã sai", r.code == "bad_code", r)
	r = await api.reset_password(user, code, "matkhau3")
	check("đặt lại mật khẩu", r.ok, r)
	r = await api.servers()
	check("phiên cũ bị thu hồi sau đặt lại mật khẩu", not r.ok and not api.is_logged_in(), r)
	r = await api.login(user, "matkhau3", false)
	check("đăng nhập mật khẩu mới", r.ok, r)
	await api.logout()

func test_characters(api: Node, user: String) -> void:
	var sid := 1
	var r: Dictionary = await api.characters(sid)
	check("danh sách nhân vật trống", r.ok and r.data.characters.is_empty(), r)
	var p := PlayerProfile.new()
	p.set_sect(SectRegistry.get_by_element(ElementTypes.ElementType.MOC)[0])
	var cname := "Hiệp " + user.substr(user.length() - 6)
	r = await api.create_character(sid, 0, cname, p.to_dict())
	check("tạo nhân vật", r.ok and r.data.name == cname and r.data.level == 1, r)
	if not r.ok:
		return
	var cid := int(r.data.id)
	var ver := int(r.data.version)
	check("tên trùng", (await api.create_character(sid, 1, cname.to_upper(), p.to_dict())).code == "name_taken")
	check("ô đã có", (await api.create_character(sid, 0, cname + "x", p.to_dict())).code == "slot_taken")
	check("tên có ký tự lạ", (await api.create_character(sid, 1, "ab<script>", p.to_dict())).code == "bad_name")
	p.level = 7
	p.display_name = "Đổi Tên Lén"
	r = await api.save_character(cid, ver, p.to_dict())
	check("lưu tiến trình", r.ok and int(r.data.version) == ver + 1, r)
	check("lưu bằng version cũ bị chặn", (await api.save_character(cid, ver, p.to_dict())).code == "stale_save")
	r = await api.characters(sid)
	var c: Dictionary = r.data.characters[0] if r.ok and not r.data.characters.is_empty() else {}
	check("đọc lại cấp đã lưu", int(c.get("level", 0)) == 7, c)
	check("không đổi tên qua dữ liệu lưu", str(c.get("data", {}).get("name", "")) == cname, c)
	r = await api.servers()
	check("máy chủ đếm số nhân vật", r.ok and int(r.data.servers[0].characters) == 1, r)
	check("xóa sai mật khẩu", (await api.delete_character(cid, "sai")).code == "wrong_password")
	r = await api.delete_character(cid, "matkhau1")
	check("xóa nhân vật", r.ok, r)
	r = await api.characters(sid)
	check("đã xóa khỏi danh sách", r.ok and r.data.characters.is_empty(), r)

	## SaveManager online: gom lưu rồi gửi lên server.
	r = await api.create_character(sid, 2, cname, p.to_dict())
	check("tạo lại cùng tên sau khi xóa", r.ok, r)
	if r.ok:
		var prof := PlayerProfile.from_dict(r.data.data)
		SaveManager.set_online_character(int(r.data.id), int(r.data.version))
		prof.level = 9
		SaveManager.save_profile(prof)
		await SaveManager.flush_online()
		var r2: Dictionary = await api.characters(sid)
		check("SaveManager lưu lên server", r2.ok and int(r2.data.characters[0].level) == 9, r2)
		SaveManager.clear_online_character()

func _read_otp(email: String) -> String:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(MAILPIT + "/api/v1/search?query=to:" + email.uri_encode())
	var res: Array = await http.request_completed
	http.queue_free()
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary or data.get("messages", []).is_empty():
		return ""
	var m := RegEx.create_from_string("là: (\\d{6})").search(str(data.messages[0].get("Snippet", "")))
	return m.get_string(1) if m else ""
