extends Node
## Kiểm thử file lưu: ghi an toàn (tmp -> bak -> chính), chống sửa byte, chống thay bằng JSON bản rõ,
## và nhân vật offline giữ nguyên đồ hành trang / rương / đồ đang mặc sau khi lưu rồi đọc lại.
## Chỉ dùng file thử user://_savetest_*.json — không đụng file lưu thật.

const P := "user://_savetest_profile.json"
var _fail := 0
var _marker_existed := false

func _ready() -> void:
	_marker_existed = FileAccess.file_exists(SaveManager.SECURE_MARKER_PATH)
	_cleanup()
	_test_roundtrip_keeps_items()
	_test_tampered_byte_rejected_uses_backup()
	_test_plaintext_rejected_after_secure()
	_test_online_never_touches_local_files()
	_test_offline_independent_of_account()
	_cleanup()
	print("SAVE SECURITY: %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + msg)
	if not cond:
		_fail += 1

func _cleanup() -> void:
	for ext in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(P + ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(P + ext))
	if not _marker_existed and FileAccess.file_exists(SaveManager.SECURE_MARKER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SECURE_MARKER_PATH))

func _make_profile() -> PlayerProfile:
	var p := PlayerProfile.new()
	p.display_name = "ThuLuu"
	p.level = 20
	p.gold = 12345
	p.storage_gold = 777
	return p

func _test_roundtrip_keeps_items() -> void:
	print("[1] Lưu rồi đọc lại giữ nguyên tiền/rương/hành trang/đồ mặc")
	var p := _make_profile()
	var d := p.to_dict()
	_check(SaveManager._write_secure(P, d), "ghi được")
	_check(SaveManager._is_encrypted_file(P), "file đã mã hoá (không đọc được bằng mắt)")
	var back := SaveManager._read_secure(P)
	_check(not back.is_empty(), "đọc lại được")
	var q := PlayerProfile.from_dict(back)
	_check(q.gold == 12345 and q.storage_gold == 777 and q.level == 20, "tiền / tiền rương / cấp giữ nguyên")
	_check(JSON.stringify(q.to_dict().get("inventory", [])) == JSON.stringify(d.get("inventory", [])), "hành trang giữ nguyên")
	_check(JSON.stringify(q.to_dict().get("storage", [])) == JSON.stringify(d.get("storage", [])), "rương giữ nguyên")
	_check(JSON.stringify(q.to_dict().get("equipment", {})) == JSON.stringify(d.get("equipment", {})), "đồ đang mặc giữ nguyên")

func _test_tampered_byte_rejected_uses_backup() -> void:
	print("[2] Sửa 1 byte file lưu -> bị từ chối, tự lấy bản .bak")
	var p := _make_profile()
	SaveManager._write_secure(P, p.to_dict())          ## lần 1 (gold 12345)
	p.gold = 99999
	SaveManager._write_secure(P, p.to_dict())          ## lần 2 -> lần 1 thành .bak
	_check(FileAccess.file_exists(P + ".bak"), "có bản dự phòng .bak")
	var f := FileAccess.open(P, FileAccess.READ_WRITE)
	var n := f.get_length()
	f.seek(n / 2)
	var b := f.get_8()
	f.seek(n / 2)
	f.store_8(b ^ 0xFF)
	f.close()
	var back := SaveManager._read_secure(P)
	_check(not back.is_empty() and int(back.get("gold", 0)) == 12345, "file sửa bị bỏ, dùng .bak (gold 12345)")

func _test_plaintext_rejected_after_secure() -> void:
	print("[3] Thay file bằng JSON bản rõ (cộng tiền) -> bị từ chối")
	_cleanup()
	var p := _make_profile()
	SaveManager._write_secure(P, p.to_dict())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P + ".bak")) if FileAccess.file_exists(P + ".bak") else 0
	var d := p.to_dict()
	d["gold"] = 999999999
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var back := SaveManager._read_secure(P)
	_check(back.is_empty(), "JSON bản rõ không được nạp")

func _test_online_never_touches_local_files() -> void:
	print("[4] Online: không ghi / không đọc hồ sơ trên máy, chỉ lấy từ server")
	GameModeManager.set_mode(GameModeManager.Mode.ONLINE)
	var p := _make_profile()
	SaveManager.save_online_profile(p)
	_check(not SaveManager._has_any_online_file(), "lưu online không tạo file nào trên máy")
	_check(SaveManager.load_profile() == null and SaveManager.load_online_profile() == null, "online không nạp hồ sơ từ máy")
	_check(not SaveManager.has_profile(), "online không thấy nhân vật offline")
	GameModeManager.set_mode(GameModeManager.Mode.OFFLINE)

func _test_offline_independent_of_account() -> void:
	print("[5] Offline: file không phụ thuộc tài khoản, bản cũ theo tài khoản được chuyển sang")
	_check(SaveManager.get_offline_profile_path(2) == "user://profile_offline_slot_2.json", "đường dẫn offline không chứa mã tài khoản")
	var slot := 3
	var target := SaveManager.get_offline_profile_path(slot)
	if FileAccess.file_exists(target) or FileAccess.file_exists(target + ".bak"):
		print("  SKIP máy đã có nhân vật offline slot %d — không đụng vào" % slot)
		return
	var legacy := "user://profile_offline_999999_slot_%d.json" % slot
	SaveManager._write_secure(legacy, _make_profile().to_dict())
	_check(SaveManager.has_offline_profile(slot), "nhận bản offline cũ theo tài khoản")
	var q := SaveManager.load_offline_profile(slot)
	_check(q != null and q.gold == 12345, "đọc được nhân vật đã chuyển")
	for f in [legacy, legacy + ".bak", target, target + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
