extends Control
class_name PolicyScreen
## Màn hình ĐIỀU KHOẢN & CHÍNH SÁCH DỊCH VỤ:
## Hiển thị trước khi vào màn hình đăng nhập (chỉ hiển thị 1 lần duy nhất).
## Sử dụng khung UI của màn hình Chọn Server (ServerSelect) đồng bộ mỹ thuật kiếm hiệp.
## Khi người chơi bấm "Đồng Ý & Tiếp Tục", lưu trạng thái vào user://policy_accepted.cfg
## và tự động chuyển sang Login. Các lần mở game tiếp theo sẽ bỏ qua màn này.

const CFG_PATH := "user://policy_accepted.cfg"
const LOGIN_SCENE := "res://ui/login/Login.tscn"

@onready var _check: CheckBox = %AgreeCheck
@onready var _enter_btn: TextureButton = %EnterButton
@onready var _back_btn: Button = %BackButton
@onready var _message: Label = %Message
@onready var _content: RichTextLabel = %PolicyContent

static func is_accepted() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		return bool(cfg.get_value("policy", "accepted", false))
	return false

static func set_accepted(val: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("policy", "accepted", val)
	cfg.set_value("policy", "accepted_time", Time.get_datetime_string_from_system())
	cfg.save(CFG_PATH)

static func reset() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("policy", "accepted", false)
	cfg.save(CFG_PATH)

func _ready() -> void:
	_enter_btn.pressed.connect(_on_agree_pressed)
	_back_btn.pressed.connect(_on_decline_pressed)

	_setup_policy_text()

	# Hiệu ứng mờ dần khi mở màn hình
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

	for arg in OS.get_cmdline_args():
		if arg == "--test-policy-screen":
			_test_capture_and_quit.call_deferred()
			break

func _setup_policy_text() -> void:
	var bb := ""
	bb += "[b][color=#FFD54F]KÍNH CHÀO QUÝ HIỆP KHÁCH BỐN PHƯƠNG,[/color][/b]\n"
	bb += "Chào mừng quý nhân sĩ đã gia nhập thế giới võ lâm [color=#FFD54F][b]JX1 Idle Origin[/b][/color]. Để xây dựng một môi trường giang hồ công bằng, an toàn và lành mạnh, xin vui lòng đọc kỹ và tuân thủ các điều khoản dịch vụ dưới đây trước khi đăng nhập trải nghiệm trò chơi.\n\n"

	bb += "[b][color=#81C784]I. ĐIỀU KHOẢN DỊCH VỤ & THỎA THUẬN NGƯỜI CHƠI[/color][/b]\n"
	bb += "1. [color=#FFE082]Tôn trọng sân chơi công bằng:[/color] Nghiêm cấm mọi hành vi sử dụng phần mềm thứ ba can thiệp vào game (hack, cheat, mod, auto can thiệp bộ nhớ máy chủ, thay đổi chỉ số nhân vật trái phép). Mọi tài khoản vi phạm sẽ bị khóa vĩnh viễn không cần báo trước.\n"
	bb += "2. [color=#FFE082]Bảo quản thông tin tài khoản:[/color] Quý hiệp khách có trách nhiệm tự bảo mật tài khoản và mật khẩu của mình. Không chia sẻ tài khoản cho người khác để tránh rủi ro mất mát trang bị, tiền tệ và tài sản ảo trong game.\n"
	bb += "3. [color=#FFE082]Quyền sở hữu tài sản số:[/color] Mọi vật phẩm, ngân lượng, trang bị trong trò chơi thuộc quyền quản lý của hệ sinh thái trò chơi. Nghiêm cấm hành vi lợi dụng lỗi game (bug/exploit) để trục lợi; nếu phát hiện cần báo ngay cho Bổn Trang.\n\n"

	bb += "[b][color=#81C784]II. CHÍNH SÁCH BẢO MẬT & BẢO VỆ DỮ LIỆU CÁ NHÂN[/color][/b]\n"
	bb += "1. [color=#FFE082]Mã hóa an toàn:[/color] Mọi thông tin tài khoản và mật khẩu đăng nhập đều được mã hóa một chiều chuẩn quốc tế an toàn cao nhất trước khi lưu trữ vào cơ sở dữ liệu.\n"
	bb += "2. [color=#FFE082]Bảo mật quyền riêng tư:[/color] Ban điều hành cam kết không thu thập dữ liệu trái phép, không tiết lộ, mua bán hay chia sẻ thông tin cá nhân của hiệp khách cho bất kỳ bên thứ ba nào khi chưa có sự chấp thuận của bạn.\n"
	bb += "3. [color=#FFE082]Bảo lưu nhật ký giao dịch:[/color] Hệ thống lưu trữ nhật ký giao dịch, chiến báo và lịch sử nạp/rút để bảo vệ quyền lợi chính đáng của người chơi khi có tranh chấp.\n\n"

	bb += "[b][color=#81C784]III. QUY TẮC ỨNG XỬ & VĂN HÓA VÕ LÂM[/color][/b]\n"
	bb += "1. [color=#FFE082]Văn minh trên các kênh tán gẫu:[/color] Không sử dụng từ ngữ xúc phạm, miệt thị vùng miền, tôn giáo, chính trị hoặc phát tán thông tin độc hại, văn hóa phẩm đồi trụy trên các kênh Thế giới, Bang hội, Mật.\n"
	bb += "2. [color=#FFE082]Giải quyết ân oán công minh:[/color] Mọi tranh chấp, ân oán giang hồ xin hãy phân định tài năng thông qua võ đài PK, Tống Kim Đại Chiến hoặc Đại Hội Võ Lâm.\n\n"

	bb += "[b][color=#81C784]IV. ĐỘ TUỔI QUY ĐỊNH & SỨC KHỎE NGƯỜI CHƠI[/color][/b]\n"
	bb += "1. [color=#FFE082]Độ tuổi tham gia:[/color] Trò chơi có yếu tố giao tranh kiếm hiệp, khuyến nghị dành cho người chơi từ [b]18 tuổi trở lên[/b].\n"
	bb += "2. [color=#FFE082]Khuyến cáo thời lượng:[/color] Chơi game quá 180 phút mỗi ngày có thể gây ảnh hưởng không tốt đến sức khỏe và sinh hoạt hàng ngày. Hãy rèn luyện và nghỉ ngơi điều độ.\n\n"

	bb += "[center][color=#88929A]Bằng việc đánh dấu vào ô bên dưới và bấm \"Đồng Ý & Tiếp Tục\", quý hiệp khách đã xác nhận đã đọc, hiểu rõ và cam kết tuân thủ toàn bộ các điều khoản trên.[/color][/center]"

	_content.text = bb

func _on_agree_pressed() -> void:
	if not _check.button_pressed:
		_show_message("Vui lòng tích chọn ô \"Tôi đã đọc và đồng ý...\" để tiếp tục!")
		# Hiệu ứng rung nhẹ / nháy đỏ để nhắc người dùng
		_highlight_check()
		return

	# Lưu trạng thái đã chấp nhận (chỉ cần 1 lần)
	set_accepted(true)

	_show_message("Đã chấp nhận điều khoản. Đang vào game...", Color(0.4, 0.95, 0.5))
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(LOGIN_SCENE)
	)

func _on_decline_pressed() -> void:
	_show_message("Hiệp khách cần đồng ý điều khoản dịch vụ để tiếp tục tham gia JX1 Idle Origin.")

func _show_message(msg: String, color: Color = Color(1.0, 0.85, 0.55)) -> void:
	_message.text = msg
	_message.add_theme_color_override("font_color", color)
	_message.visible = true

func _highlight_check() -> void:
	var tw := create_tween()
	tw.tween_property(_check, "modulate", Color(1.0, 0.4, 0.4), 0.15)
	tw.tween_property(_check, "modulate", Color(1.0, 1.0, 1.0), 0.15)
	tw.tween_property(_check, "modulate", Color(1.0, 0.4, 0.4), 0.15)
	tw.tween_property(_check, "modulate", Color(1.0, 1.0, 1.0), 0.15)

func _test_capture_and_quit() -> void:
	await get_tree().create_timer(0.4).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("C:/Users/Hieu Tran/.gemini/antigravity/brain/d6888eb9-bf62-47ed-a3a2-f742759dfa21/policy_screen_rendered.png")
		print("POLICY_SCREEN_CAPTURE_SUCCESS")
	get_tree().quit()
