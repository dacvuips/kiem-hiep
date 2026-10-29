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
	_save_state()
	if _completed:
		tutorial_completed.emit()

func reset_tutorial() -> void:
	_completed = false
	_save_state()

func should_show_intro() -> bool:
	# Nếu đang chạy lệnh test tự động thì không tự hiện
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-") or arg == "--capture-screenshot":
			return false
	return not _completed

## -------------------------------------------------------------
## DẠNG 1: CÁC BƯỚC HƯỚNG DẪN CỐT LÕI ĐẦU GAME (BẮT BUỘC)
## -------------------------------------------------------------
func get_initial_steps(hub: Node) -> Array[Dictionary]:
	var steps: Array[Dictionary] = [
		{
			"id": "char_info",
			"target_node": hub.get_node_or_null("%InfoBox"),
			"title": "BẢNG THÔNG TIN NHÂN VẬT",
			"what_is_it": "Bảng hiển thị tên nhân vật, cấp bậc, môn phái, thuộc tính sinh lực (HP), nội lực (MP) và điểm tiềm năng.",
			"what_to_do": "Nhấp vào Bảng Thông Tin để xem chi tiết chỉ số võ công và phân bổ điểm tiềm năng.",
			"where_to_go": "Nắm vững thể chất nhân vật, tăng Sức mạnh/Thân pháp để gia tăng uy lực chiến đấu.",
			"padding": Vector2(10, 10),
		},
		{
			"id": "nav_equipment",
			"target_node": hub.get_node_or_null("%NavButton0"),
			"title": "HÀNH TRANG & TRANG BỊ",
			"what_is_it": "Khu vực quản lý 12 món trang bị Hoàng Kim (Vũ khí, Giáp, Nón, Nhẫn, Phi phong...) và rương chứa vật phẩm.",
			"what_to_do": "Nhấp vào nút [Trang Bị] để mở rương hành trang, kiểm tra và mặc trang bị thu thập được.",
			"where_to_go": "Mặc và cường hoá trang bị giúp gia tăng vượt trội Lực Chiến, Công kích và Phòng thủ.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_skills",
			"target_node": hub.get_node_or_null("%NavButton1"),
			"title": "VÕ CÔNG MÔN PHÁI",
			"what_is_it": "Hệ thống bí kíp võ học độc môn của môn phái: chiêu thức chủ động, bị động và tâm pháp trấn phái.",
			"what_to_do": "Nhấp vào nút [Kỹ Năng] để mở bảng tuyệt kỹ võ học và phân bổ điểm kỹ năng khi lên cấp.",
			"where_to_go": "Tuyệt kỹ môn phái là nguồn sát thương uy lực nhất khi dã ngoại và đại chiến Tống Kim.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "ky_tran_cac",
			"target_node": hub.get_node_or_null("%KyTranCacTopButton"),
			"title": "KỲ TRÂN CÁC & TÀI PHÚ",
			"what_is_it": "Thương điếm bách bảo cung cấp linh dược bổ huyết, thể lực, bí kíp, đá khảm nạm và bảo vật hiếm.",
			"what_to_do": "Nhấp vào nút [Kỳ Trân Các] để ghé thăm tiệm buôn và sắm sửa đan dược cho chuyến bôn tẩu.",
			"where_to_go": "Dự trữ đầy đủ dược phẩm và bảo ngọc trước khi dấn thân vào các vùng hiểm địa.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "btn_challenge",
			"target_node": hub.get_node_or_null("%ChallengeButton"),
			"title": "XUẤT CHINH VƯỢT ẢI",
			"what_is_it": "Bản đồ dã ngoại và các tầng ải thử thách chiến đấu chống lại đàn ác tặc và thủ lĩnh Boss thế lực.",
			"what_to_do": "Nhấp vào nút [VƯỢT ẢI] để mở danh sách bản đồ và xuất chinh quét sạch yêu ma quái thú!",
			"where_to_go": "Đưa Đại Hiệp trực tiếp vào chiến trường thời gian thực để tung hoành giang hồ, diệt quái nhặt đồ!",
			"padding": Vector2(8, 6),
		},
	]
	return steps

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
			"title": "BẢNG THÔNG TIN NHÂN VẬT",
			"what_is_it": "Hiển thị tên nhân vật, cấp bậc, môn phái, thuộc tính sinh lực (HP), nội lực (MP) và điểm tiềm năng.",
			"what_to_do": "Xem chỉ số cơ bản và nâng điểm tiềm năng (Sức mạnh, Thân pháp, Sinh khí, Nội công) khi thăng cấp.",
			"where_to_go": "Cộng điểm tiềm năng thích hợp để tối ưu hoá lực chiến và hiệu quả xuất chiêu môn phái.",
			"padding": Vector2(10, 10),
		},
		{
			"id": "equip_box",
			"target_node": hub.get_node_or_null("%EquipBox"),
			"title": "12 Ô TRANG BỊ HOÀNG KIM",
			"what_is_it": "12 vị trí trang bị trên người: Vũ khí, Áo giáp, Nón, Đai lưng, Giày, Hộ uyển, 2 Nhẫn, Dây chuyền, Ngọc bội, Mặt nạ và Phi phong.",
			"what_to_do": "Xem các món trang bị đang mặc, quan sát chỉ số kích hoạt dòng thuộc tính ngũ hành môn phái.",
			"where_to_go": "Săn tìm và cường hoá đủ bộ Hoàng Kim để mở khoá sức mạnh tối thượng.",
			"padding": Vector2(6, 6),
		},
		{
			"id": "char_button",
			"target_node": hub.get_node_or_null("%CharacterButton"),
			"title": "NÚT [NHÂN VẬT]",
			"what_is_it": "Nút điều hướng chính trở về màn hình trung tâm nhân vật và 12 ô trang bị.",
			"what_to_do": "Nhấp vào để quay về xem tổng quan trang bị và diện mạo hiệp khách.",
			"where_to_go": "Màn hình trung tâm để kiểm tra trang bị đang mặc bất cứ lúc nào.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_equipment",
			"target_node": hub.get_node_or_null("%NavButton0"),
			"title": "NÚT [TRANG BỊ & RƯƠNG ĐỒ]",
			"what_is_it": "Rương chứa đồ hành trang đa ngăn (Túi 1, Túi 2, Túi 3) và kho cất giữ bảo vật giang hồ.",
			"what_to_do": "Nhấp để mở túi đồ, phân loại trang bị, mặc đồ mới hoặc bán/phân giải vật phẩm thừa.",
			"where_to_go": "Quản lý hành trang ngăn nắp, giữ lại trang bị ngũ hành quý hiếm.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_skills",
			"target_node": hub.get_node_or_null("%NavButton1"),
			"title": "NÚT [KỸ NĂNG VÕ CÔNG]",
			"what_is_it": "Cây bí kíp võ học độc môn của 10 môn phái: Chiêu chủ động, Bị động và Tâm pháp trấn phái ngũ hành.",
			"what_to_do": "Nhấp để mở bảng kỹ năng, phân phối điểm võ công khi lên cấp và cài đặt xuất chiêu.",
			"where_to_go": "Nâng max tuyệt kỹ môn phái để gia tăng uy lực quét quái dã ngoại và đại chiến Tống Kim.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_events",
			"target_node": hub.get_node_or_null("%NavButton2"),
			"title": "NÚT [SỰ KIỆN & HOẠT ĐỘNG]",
			"what_is_it": "Lịch trình các sự kiện giang hồ lớn: Đại chiến Tống Kim, Vận Tiêu Bang Hội, Khiêu chiến Boss Thế Giới.",
			"what_to_do": "Nhấp để theo dõi thời gian diễn ra, đăng ký tham gia và nhận các phần thưởng giá trị.",
			"where_to_go": "Nơi giao lưu võ học, so tài cùng ngàn người chơi khác và thu thập vô số bách bảo.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_guild",
			"target_node": hub.get_node_or_null("%NavButton3"),
			"title": "NÚT [BANG HỘI ĐỒNG ĐẠO]",
			"what_is_it": "Hệ thống bang phái nơi hội tụ anh em huynh đệ, bang chiến, kỹ năng bang và phúc lợi bang.",
			"what_to_do": "Nhấp để thành lập bang hoặc xin gia nhập bang phái, cống hiến và tham gia công thành chiến.",
			"where_to_go": "Bang hội là chỗ dựa vững chắc nhất trên bước đường bôn tẩu giang hồ.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_social",
			"target_node": hub.get_node_or_null("%NavButton4"),
			"title": "NÚT [GIAO DỊCH & THỊ TRƯỜNG]",
			"what_is_it": "Khu vực giao dịch tự do giữa người chơi, bày sạp buôn bán và kết giao bằng hữu bốn phương.",
			"what_to_do": "Nhấp để tìm kiếm vật phẩm cần mua hoặc treo bán trang bị quý kiếm Ngân Lượng.",
			"where_to_go": "Làm giàu từ buôn bán trang bị và trao đổi dược phẩm cùng các đại hiệp khác.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_crafting",
			"target_node": hub.get_node_or_null("%NavButton5"),
			"title": "NÚT [CHẾ TẠO & RÈN ĐÚC]",
			"what_is_it": "Lò rèn thần binh: Cường hoá, Ghép đá, Khảm nạm Huyền Tinh và tẩy luyện thuộc tính trang bị.",
			"what_to_do": "Nhấp để nâng cấp cấp độ trang bị, đục lỗ và khảm bảo ngọc gia tăng thuộc tính cực hạn.",
			"where_to_go": "Biến trang bị bình thường thành thần binh bảo giáp vô song thiên hạ.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_ranking",
			"target_node": hub.get_node_or_null("%NavButton6"),
			"title": "NÚT [BẢNG XẾP HẠNG]",
			"what_is_it": "Bảng Phong Thần vinh danh các bậc cao thủ: Đua Top Cấp Độ, Top Lực Chiến và Top Bang Hội.",
			"what_to_do": "Nhấp để xem thứ hạng của bản thân và so tài vị thế cùng các anh tài toàn máy chủ.",
			"where_to_go": "Phấn đấu ghi danh vào Top đầu để nhận danh hiệu độc quyền và phúc lợi cao quý.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "nav_settings",
			"target_node": hub.get_node_or_null("%NavButton7"),
			"title": "NÚT [CÀI ĐẶT HỆ THỐNG]",
			"what_is_it": "Menu cấu hình âm thanh, nhạc nền kiếm hiệp, hiệu ứng chiêu thức, đồ hoạ và tài khoản.",
			"what_to_do": "Nhấp để tuỳ biến âm lượng, tốc độ khung hình phù hợp cấu hình máy và lưu tài khoản.",
			"where_to_go": "Thiết lập trải nghiệm âm thanh võ lâm sống động và mượt mà nhất.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "ky_tran_cac",
			"target_node": hub.get_node_or_null("%KyTranCacTopButton"),
			"title": "NÚT [KỲ TRÂN CÁC]",
			"what_is_it": "Thương điếm bách bảo cung cấp linh dược bổ huyết, thể lực, bí kíp, đá khảm nạm và bảo vật hiếm.",
			"what_to_do": "Nhấp để ghé thăm tiệm buôn và sắm sửa đan dược cho chuyến bôn tẩu.",
			"where_to_go": "Dự trữ đầy đủ dược phẩm và bảo ngọc trước khi dấn thân vào các vùng hiểm địa.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "currency_box",
			"target_node": currency_node,
			"title": "KHUNG [TIỀN TỆ & TÀI PHÚ]",
			"what_is_it": "Hiển thị 3 loại tiền tệ quan trọng: Vàng (Gold), Ngân Lượng (Xu) và Kim Nguyên Bảo (Jade).",
			"what_to_do": "Nhấp vào các ô tiền tệ hoặc nút [+] để mở Tiền Trang hoặc nạp đổi đơn vị tiền tệ khi cần thiết.",
			"where_to_go": "Tiền tệ dùng để mua sắm đan dược, rèn đúc trang bị và giao dịch thương hội.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "btn_play",
			"target_node": hub.get_node_or_null("%PlayButton"),
			"title": "NÚT [TỶ THÍ ĐẤU TRƯỜNG]",
			"what_is_it": "Lôi đài tỷ võ phân tài cao thấp 1vs1 theo thể thức thời gian thực.",
			"what_to_do": "Nhấp để tìm kiếm đối thủ xứng tầm, bước lên lôi đài so tài chiêu thức tuyệt kỹ.",
			"where_to_go": "Khẳng định bản lĩnh cao thủ và nhận điểm danh vọng võ lâm.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "btn_challenge",
			"target_node": hub.get_node_or_null("%ChallengeButton"),
			"title": "NÚT [XUẤT CHINH VƯỢT ẢI]",
			"what_is_it": "Bản đồ dã ngoại và các tầng ải thử thách chiến đấu chống lại đàn ác tặc và thủ lĩnh Boss thế lực.",
			"what_to_do": "Nhấp vào nút [VƯỢT ẢI] để mở danh sách bản đồ và xuất chinh quét sạch yêu ma quái thú!",
			"where_to_go": "Đưa Đại Hiệp trực tiếp vào chiến trường thời gian thực để tung hoành giang hồ, diệt quái nhặt đồ!",
			"padding": Vector2(8, 6),
		},
		{
			"id": "chat_btn",
			"target_node": hub.get_node_or_null("%ChatButton"),
			"title": "NÚT [KÊNH TRÒ CHUYỆN]",
			"what_is_it": "Kênh chat trò chuyện liên thông: Kênh Thế Giới, Kênh Bang Hội, Kênh Đội Nhóm và Mật Đàm.",
			"what_to_do": "Nhấp để mở khung chat, gửi tin nhắn trao đổi, kết bạn và lập tổ đội bôn tẩu.",
			"where_to_go": "Kết nối hảo hữu, kêu gọi đồng đội cùng vượt ải săn boss.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "social_btn",
			"target_node": hub.get_node_or_null("%SocialButton"),
			"title": "NÚT [CỘNG ĐỒNG VÕ LÂM]",
			"what_is_it": "Liên kết trực tiếp tới nhóm Telegram và cộng đồng người chơi JX1 Idle Origin.",
			"what_to_do": "Nhấp để mở thông tin cộng đồng, nhận Giftcode tân thủ và thảo luận cùng Admin.",
			"where_to_go": "Không bỏ lỡ các tin tức sự kiện nóng hổi và cập nhật mới nhất từ nhà phát triển.",
			"padding": Vector2(8, 6),
		},
		{
			"id": "guide_btn",
			"target_node": hub.get_node_or_null("%GuideButton"),
			"title": "NÚT [HƯỚNG DẪN CẨM NANG]",
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
	_start_tutorial_with_mode(hub, Mode.INITIAL)

## Khởi chạy Dạng 2: Khám phá giao diện khi bấm nút Hướng Dẫn (Toàn bộ nút, tự do chuyển/tắt)
func start_explore_tutorial(hub: Node) -> void:
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
