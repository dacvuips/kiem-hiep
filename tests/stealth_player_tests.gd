extends Node
## Ẩn thân trên NHÂN VẬT THẬT (player.tscn): Ngự Tuyết Ẩn bấm ra chiêu, Huyền Băng Vô Tắc tự kích hoạt khi trúng đòn
## -> thân người mờ alpha 128/255, quái/bot coi là ẩn; ra chiêu khác -> hiện hình.

var _passes := 0
var _fails := 0

func check(desc: String, ok: bool) -> void:
	if ok:
		_passes += 1
		print("PASS ", desc)
	else:
		_fails += 1
		print("FAIL ", desc)

func _body_alpha(p: Node) -> float:
	var av: CharacterAvatar = p.avatar
	return av._body.modulate.a if av._body else -1.0

func _ready() -> void:
	var profile := PlayerProfile.new()
	profile.display_name = "Thúy Yên"
	profile.set_sect(SectRegistry.get_by_id("thuy_yen_mon"))
	profile.level = 180
	profile.skill_levels["thuy_yen_cuiyan120"] = 20
	profile.skill_levels[HideSkill.HUYEN_BANG_VO_TAC_ID] = 20
	GameManager.local_profile = profile
	var p: Node2D = load("res://player/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(400, 400)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ctrl: SectSkillController = p.skill_controller
	var ngu: SkillDefinition = ctrl._find_sect_skill("thuy_yen_cuiyan120")
	check("Chưa ẩn: thân rõ (alpha 1)", is_equal_approx(_body_alpha(p), 1.0) and not p.is_hidden())

	## 1. Ngự Tuyết Ẩn: bấm ra chiêu.
	var ok: bool = ctrl._try_cast(ngu, p, null)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("Ngự Tuyết Ẩn thi triển được", ok)
	check("Ngự Tuyết Ẩn -> đang ẩn", p.is_hidden() and PlayerStealth.local_hidden())
	check("Ngự Tuyết Ẩn -> thân mờ 50%% (alpha=%.2f)" % _body_alpha(p), absf(_body_alpha(p) - 128.0 / 255.0) < 0.01)
	var st: StatusEffectController = p.status_controller
	var left := 0.0
	for s in st.get_state_display_list():
		left = maxf(left, float(s["time"]))
	check("Ẩn ~30 giây (còn %.1f)" % left, left > 29.0 and left <= 30.0)

	## Ra chiêu khác -> hiện hình (gỡ trực tiếp như _try_cast làm với skill không mang "hide").
	st.break_hide()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("Ra chiêu khác -> hiện hình, alpha 1", not p.is_hidden() and is_equal_approx(_body_alpha(p), 1.0) and not PlayerStealth.local_hidden())

	## 2. Huyền Băng Vô Tắc: bị đánh trúng, 10% mỗi lần -> đánh nhiều lần cho chắc dính.
	var hit := false
	for i in 400:
		ctrl.trigger_auto_reply_skills(p, null)
		if p.is_hidden():
			hit = true
			break
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("Huyền Băng Vô Tắc tự kích hoạt khi trúng đòn", hit)
	check("Dung Tuyết Vô Tung -> thân mờ 50%% (alpha=%.2f)" % _body_alpha(p), absf(_body_alpha(p) - 128.0 / 255.0) < 0.01)
	check("Có trạng thái Dung Tuyết Vô Tung 5 giây", st.has_state("thuy_yen_dung_tuyet_vo_tung")
			and absf(float(st._states["thuy_yen_dung_tuyet_vo_tung"]["time"]) - 5.0) < 0.2)
	## Giãn cách 10 giây: bị đánh tiếp không kích hoạt lại.
	st.break_hide()
	for i in 200:
		ctrl.trigger_auto_reply_skills(p, null)
	check("Trong 10 giây hồi không kích hoạt lại", not p.is_hidden())

	print("RESULT %d/%d" % [_passes, _passes + _fails])
	get_tree().quit(0 if _fails == 0 else 1)
