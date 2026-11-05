extends Node
## TutorialManager (Autoload) - Quản lý chức năng Introduce / Hướng dẫn tân thủ
## 2 Chế độ hoạt động:
## - Dạng 1 (INITIAL / Đầu game): Khi mới vào là hướng dẫn ngay lập tức, không cho người dùng nhấp ra ngoài hoặc ấn nút khác, bắt buộc trải nghiệm.
## - Dạng 2 (EXPLORE / Bấm nút Hướng dẫn): Giới thiệu hết toàn bộ các nút trên giao diện, cho phép chuyển bước và tắt bất cứ lúc nào.

const SAVE_PATH := "user://tutorial_state.json"
const TUTORIAL_OVERLAY_SCENE := preload("res://ui/tutorial/TutorialOverlay.tscn")

enum Mode {
	INITIAL = 0, # Dạng đầu game
	EXPLORE = 1, # Dạng 2: Bấm nút Hướng Dẫn
}

signal tutorial_started(mode: int)
signal tutorial_completed()
signal tutorial_skipped()

var _completed: bool = false
var _active_overlay: CanvasLayer = null
var _is_in_intro_flow: bool = false
var force_intro: bool = false
var last_learned_skill_id: String = ""
var current_menu_anchor: Control = null
var current_menu_popup: PopupMenu = null
var current_menu_options: Array = []

func notify_character_created() -> void:
	force_intro = true
	_completed = false
	_is_in_intro_flow = false
	_save_state()

func set_last_learned_skill(id: String) -> void:
	last_learned_skill_id = id

func notify_skill_menu_opened(anchor: Control, menu: Variant = null, options: Array = []) -> void:
	current_menu_anchor = anchor
	current_menu_popup = menu
	current_menu_options = options
	if is_instance_valid(_active_overlay):
		if _active_overlay.has_method("advance_to_skill_select_step"):
			_active_overlay.advance_to_skill_select_step()

func notify_auto_skill_selected() -> void:
	current_menu_popup = null
	if is_instance_valid(_active_overlay):
		if _active_overlay.has_method("advance_to_toggle_auto_step"):
			_active_overlay.advance_to_toggle_auto_step()

func _ready() -> void:
	_load_state()

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_completed = false
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text := file.get_as_text()
		var json = JSON.parse_string(text)
		if json is Dictionary:
			_completed = bool(json.get("completed", false))
		file.close()

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data := {
			"completed": _completed,
			"updated_at": Time.get_datetime_string_from_system()
		}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func is_completed() -> bool:
	return _completed

func set_completed(val: bool) -> void:
	_completed = val
	if val:
		force_intro = false
		if GameManager.local_profile != null:
			GameManager.local_profile.intro_completed = true
			SaveManager.save_profile(GameManager.local_profile)
	_save_state()
	if _completed:
		tutorial_completed.emit()

func reset_tutorial() -> void:
	_completed = false
	force_intro = true
	if GameManager.local_profile != null:
		GameManager.local_profile.intro_completed = false
		SaveManager.save_profile(GameManager.local_profile)
	_save_state()

func is_in_intro_flow() -> bool:
	return _is_in_intro_flow

func get_active_overlay() -> CanvasLayer:
	return _active_overlay

func advance_to_field_step() -> void:
	_is_in_intro_flow = true

func cancel_intro_flow() -> void:
	_is_in_intro_flow = false

func complete_intro() -> void:
	_is_in_intro_flow = false
	force_intro = false
	if GameManager.local_profile != null:
		GameManager.local_profile.intro_completed = true
		SaveManager.save_profile(GameManager.local_profile)
		SaveManager.flush_online()
	set_completed(true)
	if is_instance_valid(_active_overlay):
		_active_overlay.queue_free()
		_active_overlay = null

func should_show_intro() -> bool:
	# Nếu đang chạy lệnh test tự động thì không tự hiện
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-") or arg == "--capture-screenshot":
			return false
	if force_intro:
		return true
	if GameManager.local_profile != null:
		# Nhân vật đã có cấp độ (level > 1) hoặc đã hoàn thành intro thì không bao giờ ép intro
		if GameManager.local_profile.level > 1 or GameManager.local_profile.intro_completed:
			return false
		return true
	return not _completed

## -------------------------------------------------------------
## DẠNG 1: CÁC BƯỚC HƯỚNG DẪN CỐT LÕI ĐẦU GAME (BẮT BUỘC 11 BƯỚC)
## -------------------------------------------------------------
func get_initial_steps(hub: Node) -> Array[Dictionary]:
	var steps: Array[Dictionary] = [
		{
			"id": "btn_challenge",
			"step_index": 1,
			"total_steps": 11,
			"target_node": hub.get_node_or_null("%ChallengeButton"),
			"title": "Xuất chinh vượt ải",
			"description": "Nhấp vào nút [Vượt Ải] để mở bản đồ luyện công và các tầng ải thử thách giang hồ.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "btn_enter_map",
			"step_index": 2,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(hub) or not hub.is_inside_tree():
					return null
				var btns = hub.get_tree().get_nodes_in_group("tutorial_enter_btn")
				for b in btns:
					# Chỉ nhận nút khi đã layout xong (toạ độ màn hình x > 100) để tránh lấy nhầm toạ độ rác (0,0)
					if is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_position().x > 100.0:
						return b as Control
				return null,
			"title": "Bản đồ luyện công",
			"description": "Chọn bản đồ dã ngoại phù hợp cấp độ và nhấp [Vào] để xuất chinh luyện công diệt quái!",
			"padding": Vector2(6, 6),
		},
	]
	return steps

## Hướng dẫn tiếp tục trong map luyện công (Bước 3 đến Bước 11)
func continue_in_game_tutorial(main_scene: Node) -> void:
	if not _is_in_intro_flow:
		return
	if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
		return

	# Đợi scene và HUD khởi tạo ổn định
	await main_scene.get_tree().create_timer(0.4).timeout
	if not is_instance_valid(main_scene) or not _is_in_intro_flow:
		return

	# Đảm bảo có ít nhất 1 điểm kỹ năng để người chơi cộng điểm
	var profile := GameManager.local_profile
	if profile != null and profile.skill_points <= 0:
		profile.skill_points = 5

	var in_game_steps: Array[Dictionary] = [
		{
			"id": "skill_menu_btn",
			"step_index": 3,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return null
				var btns = main_scene.get_tree().get_nodes_in_group("tutorial_skill_menu_btn")
				for b in btns:
					if is_instance_valid(b) and b.is_visible_in_tree():
						return b as Control
				return null,
			"title": "Kỹ năng môn phái",
			"description": "Nhấp vào biểu tượng [Quyển Sách] trên thanh tiện ích để mở cây bí kíp võ công môn phái.",
			"padding": Vector2(6, 6),
		},
		{
			"id": "skill_learnable_slot",
			"step_index": 4,
			"total_steps": 11,
			"multi_target_getter": func() -> Array[Control]:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return []
				var slots = main_scene.get_tree().get_nodes_in_group("tutorial_1x_skill_slot")
				var res: Array[Control] = []
				for s in slots:
					if is_instance_valid(s) and s.is_visible_in_tree() and s.get_global_position().x > 100.0:
						res.append(s as Control)
				if res.is_empty():
					var fallback = main_scene.get_tree().get_nodes_in_group("tutorial_learnable_skill_slot")
					for f in fallback:
						if is_instance_valid(f) and f.is_visible_in_tree() and f.get_global_position().x > 100.0:
							res.append(f as Control)
				return res,
			"title": "Chọn kỹ năng tấn công",
			"description": "Nhấp chọn một chiêu thức tấn công môn phái chưa bị khoá để xem thông số và chuẩn bị học.",
			"padding": Vector2(4, 4),
		},
		{
			"id": "skill_learn_btn",
			"step_index": 5,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return null
				var btns = main_scene.get_tree().get_nodes_in_group("tutorial_learn_btn")
				for b in btns:
					if is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_position().x > 100.0:
						return b as Control
				return null,
			"title": "Học kỹ năng (+1)",
			"description": "Nhấp nút [Học / Nâng cấp (+1)] để cộng điểm kỹ năng và mở khoá chiêu thức này.",
			"padding": Vector2(6, 6),
		},
		{
			"id": "skill_close_btn",
			"step_index": 6,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return null
				var btns = main_scene.get_tree().get_nodes_in_group("tutorial_skill_close_btn")
				for b in btns:
					if is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_position().x > 100.0:
						return b as Control
				return null,
			"title": "Đóng bảng kỹ năng",
			"description": "Nhấp nút [X] ở góc trên bên phải để đóng bảng võ công và trở lại chiến trường.",
			"padding": Vector2(6, 6),
		},
		{
			"id": "auto_gear_btn",
			"step_index": 7,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return null
				var gears = main_scene.get_tree().get_nodes_in_group("tutorial_auto_gear")
				for g in gears:
					if is_instance_valid(g) and g.is_visible_in_tree():
						return g as Control
				return null,
			"title": "Cấu hình Auto",
			"description": "Nhấp vào biểu tượng bánh răng [⚙] để mở bảng thiết lập tự động chiến đấu.",
			"padding": Vector2(6, 6),
		},
		{
			"id": "auto_attack_tab",
			"step_index": 8,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return null
				var tabs = main_scene.get_tree().get_nodes_in_group("tutorial_auto_attack_tab")
				for t in tabs:
					if is_instance_valid(t) and t.is_visible_in_tree() and t.get_global_position().x > 100.0:
						return t as Control
				return null,
			"title": "Tab Tấn công",
			"description": "Nhấp vào mục [Tấn công] để thiết lập chiêu thức tự động xuất kích.",
			"padding": Vector2(6, 6),
		},
		{
			"id": "auto_attack_slot",
			"step_index": 9,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return null
				var slots = main_scene.get_tree().get_nodes_in_group("tutorial_attack_slot")
				for s in slots:
					if is_instance_valid(s) and s.is_visible_in_tree() and s.get_global_position().x > 100.0:
						return s as Control
				return null,
			"title": "Thêm kỹ năng tấn công",
			"description": "Nhấp vào ô tròn [+] để mở danh sách chiêu thức võ công vừa học.",
			"padding": Vector2(6, 6),
		},
		{
			"id": "auto_select_skill",
			"step_index": 10,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return null
				var items = main_scene.get_tree().get_nodes_in_group("tutorial_target_skill_item")
				for it in items:
					if is_instance_valid(it) and it.is_visible_in_tree():
						return it as Control
				return null,
			"multi_target_getter": func() -> Array[Control]:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return []
				var res: Array[Control] = []
				var items = main_scene.get_tree().get_nodes_in_group("tutorial_skill_dropdown_item")
				for it in items:
					if is_instance_valid(it) and it.is_visible_in_tree():
						res.append(it as Control)
				return res,
			"title": "Cài đặt kỹ năng tấn công",
			"description": "Nhấp chọn tuyệt kỹ võ công vừa học trong danh sách để cài vào hệ thống auto.",
			"padding": Vector2(4, 4),
		},
		{
			"id": "auto_toggle_btn",
			"step_index": 11,
			"total_steps": 11,
			"target_getter": func() -> Control:
				if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
					return null
				var btns = main_scene.get_tree().get_nodes_in_group("tutorial_toggle_auto")
				for b in btns:
					if is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_position().x > 100.0:
						return b as Control
				return null,
			"title": "Bật tự động luyện công",
			"description": "Nhấp [Bật auto] để nhân vật bắt đầu tự động tìm quái, xuất chiêu và thu thập chiến lợi phẩm!",
			"padding": Vector2(6, 6),
		},
	]

	if is_instance_valid(_active_overlay):
		_active_overlay.queue_free()
		_active_overlay = null

	var overlay = TUTORIAL_OVERLAY_SCENE.instantiate()
	main_scene.add_child(overlay)
	_active_overlay = overlay
	overlay.setup(in_game_steps, Mode.INITIAL)

## -------------------------------------------------------------
## DẠNG 2: GIỚI THIỆU HẾT CÁC NÚT TRÊN GIAO DIỆN (TỰ DO TẮT / CHUYỂN BƯỚC)
## -------------------------------------------------------------
func get_explore_steps(hub: Node) -> Array[Dictionary]:
	var currency_node: Control = hub.get_node_or_null("%FrameCurrencyXu")
	if currency_node == null:
		currency_node = hub.get_node_or_null("%FrameCurrencyGold")

	var steps: Array[Dictionary] = [
		{
			"id": "char_info",
			"target_node": hub.get_node_or_null("%InfoBox"),
			"title": "Bảng thông tin nhân vật",
			"description": "Hiển thị tên nhân vật, cấp bậc, môn phái, thuộc tính sinh lực, nội lực và điểm tiềm năng. Nhấp để nâng điểm tiềm năng khi thăng cấp.",
			"what_is_it": "Hiển thị tên nhân vật, cấp bậc, môn phái, thuộc tính sinh lực (HP), nội lực (MP) và điểm tiềm năng.",
			"what_to_do": "Xem chỉ số cơ bản và nâng điểm tiềm năng (Sức mạnh, Thân pháp, Sinh khí, Nội công) khi thăng cấp.",
			"where_to_go": "Cộng điểm tiềm năng thích hợp để tối ưu hoá lực chiến và hiệu quả xuất chiêu môn phái.",
			"padding": Vector2(10, 10),
		},
		{
			"id": "equip_box",
			"target_node": hub.get_node_or_null("%EquipBox"),
			"title": "12 ô trang bị Hoàng Kim",
			"description": "12 vị trí trang bị trên người gồm vũ khí, phòng cụ, trang sức và phi phong. Mặc đủ bộ để kích hoạt tối đa dòng thuộc tính ngũ hành môn phái.",
			"what_is_it": "12 vị trí trang bị trên người: Vũ khí, Áo giáp, Nón, Đai lưng, Giày, Hộ uyển, 2 Nhẫn, Dây chuyền, Ngọc bội, Mặt nạ và Phi phong.",
			"what_to_do": "Xem các món trang bị đang mặc, quan sát chỉ số kích hoạt dòng thuộc tính ngũ hành môn phái.",
			"where_to_go": "Săn tìm và cường hoá đủ bộ Hoàng Kim để mở khoá sức mạnh tối thượng.",
			"padding": Vector2(6, 6),
		},
		{
			"id": "char_button",
			"target_node": hub.get_node_or_null("%CharacterButton"),
			"title": "Nút Nhân Vật",
			"description": "Nút điều hướng chính trở về màn hình trung tâm nhân vật và 12 ô trang bị hiệp khách.",
			"what_is_it": "Nút điều hướng chính trở về màn hình trung tâm nhân vật và 12 ô trang bị.",
			"what_to_do": "Nhấp vào để quay về xem tổng quan trang bị và diện mạo hiệp khách.",
			"where_to_go": "Màn hình trung tâm để kiểm tra trang bị đang mặc bất cứ lúc nào.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_equipment",
			"target_node": hub.get_node_or_null("%NavButton0"),
			"title": "Trang bị & Rương đồ",
			"description": "Rương chứa đồ hành trang đa ngăn và kho cất giữ bảo vật. Nhấp để mở túi đồ, phân loại trang bị hoặc mặc đồ mới.",
			"what_is_it": "Rương chứa đồ hành trang đa ngăn (Túi 1, Túi 2, Túi 3) và kho cất giữ bảo vật giang hồ.",
			"what_to_do": "Nhấp để mở túi đồ, phân loại trang bị, mặc đồ mới hoặc bán/phân giải vật phẩm thừa.",
			"where_to_go": "Quản lý hành trang ngăn nắp, giữ lại trang bị ngũ hành quý hiếm.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_skills",
			"target_node": hub.get_node_or_null("%NavButton1"),
			"title": "Kỹ năng võ công",
			"description": "Cây bí kíp võ học độc môn của môn phái. Nhấp để mở bảng kỹ năng, phân phối điểm võ công khi lên cấp và cài đặt xuất chiêu.",
			"what_is_it": "Cây bí kíp võ học độc môn của 10 môn phái: Chiêu chủ động, Bị động và Tâm pháp trấn phái ngũ hành.",
			"what_to_do": "Nhấp để mở bảng kỹ năng, phân phối điểm võ công khi lên cấp và cài đặt xuất chiêu.",
			"where_to_go": "Nâng max tuyệt kỹ môn phái để gia tăng uy lực quét quái dã ngoại và đại chiến Tống Kim.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_events",
			"target_node": hub.get_node_or_null("%NavButton2"),
			"title": "Sự kiện & Hoạt động",
			"description": "Lịch trình các sự kiện giang hồ lớn: Đại chiến Tống Kim, Vận Tiêu Bang Hội và Boss Thế Giới. Nhấp để theo dõi thời gian và đăng ký tham gia.",
			"what_is_it": "Lịch trình các sự kiện giang hồ lớn: Đại chiến Tống Kim, Vận Tiêu Bang Hội, Khiêu chiến Boss Thế Giới.",
			"what_to_do": "Nhấp để theo dõi thời gian diễn ra, đăng ký tham gia và nhận các phần thưởng giá trị.",
			"where_to_go": "Nơi giao lưu võ học, so tài cùng ngàn người chơi khác và thu thập vô số bách bảo.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_guild",
			"target_node": hub.get_node_or_null("%NavButton3"),
			"title": "Bang hội đồng đạo",
			"description": "Hệ thống bang phái hội tụ anh em huynh đệ, bang chiến, kỹ năng bang và công thành chiến. Nhấp để gia nhập hoặc quản lý bang hội.",
			"what_is_it": "Hệ thống bang phái nơi hội tụ anh em huynh đệ, bang chiến, kỹ năng bang và phúc lợi bang.",
			"what_to_do": "Nhấp để thành lập bang hoặc xin gia nhập bang phái, cống hiến và tham gia công thành chiến.",
			"where_to_go": "Bang hội là chỗ dựa vững chắc nhất trên bước đường bôn tẩu giang hồ.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_social",
			"target_node": hub.get_node_or_null("%NavButton4"),
			"title": "Giao dịch & Thị trường",
			"description": "Khu vực giao dịch tự do giữa người chơi, bày sạp buôn bán và trao đổi trang bị quý lấy Ngân Lượng.",
			"what_is_it": "Khu vực giao dịch tự do giữa người chơi, bày sạp buôn bán và kết giao bằng hữu bốn phương.",
			"what_to_do": "Nhấp để tìm kiếm vật phẩm cần mua hoặc treo bán trang bị quý kiếm Ngân Lượng.",
			"where_to_go": "Làm giàu từ buôn bán trang bị và trao đổi dược phẩm cùng các đại hiệp khác.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_crafting",
			"target_node": hub.get_node_or_null("%NavButton5"),
			"title": "Chế tạo & Rèn đúc",
			"description": "Lò rèn thần binh: Cường hoá, Ghép đá, Khảm nạm Huyền Tinh và tẩy luyện để gia tăng uy lực vũ khí, trang bị.",
			"what_is_it": "Lò rèn thần binh: Cường hoá, Ghép đá, Khảm nạm Huyền Tinh và tẩy luyện thuộc tính trang bị.",
			"what_to_do": "Nhấp để nâng cấp cấp độ trang bị, đục lỗ và khảm bảo ngọc gia tăng thuộc tính cực hạn.",
			"where_to_go": "Biến trang bị bình thường thành thần binh bảo giáp vô song thiên hạ.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_ranking",
			"target_node": hub.get_node_or_null("%NavButton6"),
			"title": "Bảng xếp hạng",
			"description": "Bảng Phong Thần vinh danh các bậc cao thủ: Đua Top Cấp Độ, Top Lực Chiến và Top Bang Hội trên toàn máy chủ.",
			"what_is_it": "Bảng Phong Thần vinh danh các bậc cao thủ: Đua Top Cấp Độ, Top Lực Chiến và Top Bang Hội.",
			"what_to_do": "Nhấp để xem thứ hạng của bản thân và so tài vị thế cùng các anh tài toàn máy chủ.",
			"where_to_go": "Phấn đấu ghi danh vào Top đầu để nhận danh hiệu độc quyền và phúc lợi cao quý.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_settings",
			"target_node": hub.get_node_or_null("%NavButton7"),
			"title": "Cài đặt hệ thống",
			"description": "Menu tuỳ chỉnh âm lượng âm thanh, nhạc nền kiếm hiệp, hiệu ứng chiêu thức, đồ hoạ và thông tin tài khoản.",
			"what_is_it": "Menu cấu hình âm thanh, nhạc nền kiếm hiệp, hiệu ứng chiêu thức, đồ hoạ và tài khoản.",
			"what_to_do": "Nhấp để tuỳ biến âm lượng, tốc độ khung hình phù hợp cấu hình máy và lưu tài khoản.",
			"where_to_go": "Thiết lập trải nghiệm âm thanh võ lâm sống động và mượt mà nhất.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "ky_tran_cac",
			"target_node": hub.get_node_or_null("%KyTranCacTopButton"),
			"title": "Kỳ Trân Các",
			"description": "Thương điếm bách bảo cung cấp linh dược bổ huyết, thể lực, bí kíp võ học và nhiều bảo vật quý hiếm.",
			"what_is_it": "Thương điếm bách bảo cung cấp linh dược bổ huyết, thể lực, bí kíp, đá khảm nạm và bảo vật hiếm.",
			"what_to_do": "Nhấp để ghé thăm tiệm buôn và sắm sửa đan dược cho chuyến bôn tẩu.",
			"where_to_go": "Dự trữ đầy đủ dược phẩm và bảo ngọc trước khi dấn thân vào các vùng hiểm địa.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "currency_box",
			"target_node": currency_node,
			"title": "Tiền tệ & Tài phú",
			"description": "Hiển thị 3 loại tiền tệ quan trọng: Vàng, Ngân Lượng và Kim Nguyên Bảo dùng để mua đan dược, rèn đúc và giao dịch.",
			"what_is_it": "Hiển thị 3 loại tiền tệ quan trọng: Vàng (Gold), Ngân Lượng (Xu) và Kim Nguyên Bảo (Jade).",
			"what_to_do": "Nhấp vào các ô tiền tệ hoặc nút [+] để mở Tiền Trang hoặc nạp đổi đơn vị tiền tệ khi cần thiết.",
			"where_to_go": "Tiền tệ dùng để mua sắm đan dược, rèn đúc trang bị và giao dịch thương hội.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "btn_play",
			"target_node": hub.get_node_or_null("%PlayButton"),
			"title": "Tỷ thí đấu trường",
			"description": "Lôi đài tỷ võ phân tài cao thấp 1vs1 theo thể thức thời gian thực để khẳng định bản lĩnh cao thủ võ lâm.",
			"what_is_it": "Lôi đài tỷ võ phân tài cao thấp 1vs1 theo thể thức thời gian thực.",
			"what_to_do": "Nhấp để tìm kiếm đối thủ xứng tầm, bước lên lôi đài so tài chiêu thức tuyệt kỹ.",
			"where_to_go": "Khẳng định bản lĩnh cao thủ và nhận điểm danh vọng võ lâm.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "btn_challenge",
			"target_node": hub.get_node_or_null("%ChallengeButton"),
			"title": "Xuất chinh vượt ải",
			"description": "Bản đồ dã ngoại và khiêu chiến các tầng ải thử thách. Nhấp vào [VƯỢT ẢI] để quét sạch yêu ma quái thú và nhặt đồ!",
			"what_is_it": "Bản đồ dã ngoại và các tầng ải thử thách chiến đấu chống lại đàn ác tặc và thủ lĩnh Boss thế lực.",
			"what_to_do": "Nhấp vào nút [VƯỢT ẢI] để mở danh sách bản đồ và xuất chinh quét sạch yêu ma quái thú!",
			"where_to_go": "Đưa Đại Hiệp trực tiếp vào chiến trường thời gian thực để tung hoành giang hồ, diệt quái nhặt đồ!",
			"padding": Vector2(8, 6),
		},
		{
			"id": "chat_btn",
			"target_node": hub.get_node_or_null("%ChatButton"),
			"title": "Kênh trò chuyện",
			"description": "Khung chat trao đổi liên thông giữa Thế Giới, Bang Hội, Đội Nhóm và Mật Đàm để kết nối hảo hữu bốn phương.",
			"what_is_it": "Kênh chat trò chuyện liên thông: Kênh Thế Giới, Kênh Bang Hội, Kênh Đội Nhóm và Mật Đàm.",
			"what_to_do": "Nhấp để mở khung chat, gửi tin nhắn trao đổi, kết bạn và lập tổ đội bôn tẩu.",
			"where_to_go": "Kết nối hảo hữu, kêu gọi đồng đội cùng vượt ải săn boss.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "social_btn",
			"target_node": hub.get_node_or_null("%SocialButton"),
			"title": "Cộng đồng võ lâm",
			"description": "Liên kết trực tiếp tới nhóm thảo luận Telegram, cộng đồng người chơi và nhận Giftcode tân thủ.",
			"what_is_it": "Liên kết trực tiếp tới nhóm Telegram và cộng đồng người chơi JX1 Idle Origin.",
			"what_to_do": "Nhấp để mở thông tin cộng đồng, nhận Giftcode tân thủ và thảo luận cùng Admin.",
			"where_to_go": "Không bỏ lỡ các tin tức sự kiện nóng hổi và cập nhật mới nhất từ nhà phát triển.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "guide_btn",
			"target_node": hub.get_node_or_null("%GuideButton"),
			"title": "Hướng dẫn cẩm nang",
			"description": "Cẩm nang hướng dẫn toàn diện hệ thống tính năng. Nhấp vào bất cứ lúc nào để xem lại giới thiệu toàn bộ các nút trên màn hình.",
			"what_is_it": "Cẩm nang hướng dẫn toàn diện hệ thống tính năng trên giao diện sảnh chính.",
			"what_to_do": "Đại hiệp có thể nhấp vào đây bất cứ lúc nào để xem lại giới thiệu toàn bộ các nút trên màn hình!",
			"where_to_go": "Luôn đồng hành hỗ trợ Đại Hiệp trên bước đường bôn tẩu giang hồ.",
			"padding": Vector2(8, 6),
		},
	]
	return steps

## Tương thích ngược
func get_character_hub_steps(hub: Node) -> Array[Dictionary]:
	return get_initial_steps(hub)

## -------------------------------------------------------------
## KHỞI CHẠY HƯỚNG DẪN
## -------------------------------------------------------------

## Khởi chạy Dạng 1: Hướng dẫn cốt lõi đầu game (Bắt buộc, không cho click chỗ khác)
func start_initial_tutorial(hub: Node) -> void:
	_is_in_intro_flow = true
	_start_tutorial_with_mode(hub, Mode.INITIAL)

## Khởi chạy Dạng 2: Khám phá giao diện khi bấm nút Hướng Dẫn (Toàn bộ nút, tự do chuyển/tắt)
func start_explore_tutorial(hub: Node) -> void:
	_is_in_intro_flow = false
	_start_tutorial_with_mode(hub, Mode.EXPLORE)

func _start_tutorial_with_mode(hub: Node, mode: int) -> void:
	if not is_instance_valid(hub):
		return
	if is_instance_valid(_active_overlay):
		_active_overlay.queue_free()
		_active_overlay = null

	var overlay = TUTORIAL_OVERLAY_SCENE.instantiate()
	hub.add_child(overlay)
	_active_overlay = overlay

	var steps := get_explore_steps(hub) if (mode == Mode.EXPLORE) else get_initial_steps(hub)
	overlay.setup(steps, mode)
	tutorial_started.emit(mode)

## Hàm chuẩn hỗ trợ tương thích ngược
func start_hub_tutorial(hub: Node, force_explore: bool = false) -> void:
	if force_explore:
		start_explore_tutorial(hub)
	else:
		start_initial_tutorial(hub)
