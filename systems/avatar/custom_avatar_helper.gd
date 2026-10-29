extends RefCounted
class_name CustomAvatarHelper
## Hỗ trợ xử lý ảnh đại diện tùy chỉnh (Custom Avatar):
## - Tải ảnh từ Web (HTML5 input file qua JavaScriptBridge) hoặc Native (Windows/Android/Mobile qua FileDialog).
## - Nạp các định dạng JPG, PNG, WEBP thành Godot Image.
## - Cắt và chuyển đổi mọi định dạng ảnh thành chuẩn 200x200 JPG.
## - Mã hóa / giải mã Base64 để lưu trữ trực tiếp vào PlayerProfile (data JSONB) và đồng bộ qua mạng khi xem "Tin tức".

const AVATAR_SIZE := Vector2i(200, 200)
const JPG_QUALITY := 0.85
const AVATAR_DIR := "user://avatars"

static func _safe_name(p_name: String) -> String:
	var s := p_name.strip_edges().replace(" ", "_")
	var out := ""
	for c in s:
		if c.is_valid_filename():
			out += c
	return out if out != "" else "default"

## Lưu ảnh đại diện vào thư mục cache cục bộ user://avatars/ để không bao giờ bị mất khi thoát game/vào lại
static func save_avatar_cache(char_name: String, char_id: int, jpg_bytes: PackedByteArray) -> void:
	if jpg_bytes.is_empty():
		return
	if not DirAccess.dir_exists_absolute(AVATAR_DIR):
		DirAccess.make_dir_recursive_absolute(AVATAR_DIR)
	if char_name != "":
		var path1 := AVATAR_DIR + "/avatar_" + _safe_name(char_name) + ".jpg"
		var f1 := FileAccess.open(path1, FileAccess.WRITE)
		if f1:
			f1.store_buffer(jpg_bytes)
			f1.close()
	if char_id > 0:
		var path2 := AVATAR_DIR + "/avatar_id_" + str(char_id) + ".jpg"
		var f2 := FileAccess.open(path2, FileAccess.WRITE)
		if f2:
			f2.store_buffer(jpg_bytes)
			f2.close()

## Lấy dữ liệu ảnh đại diện đã cache từ đĩa cục bộ
static func get_avatar_cache(char_name: String, char_id := 0) -> PackedByteArray:
	if char_name != "":
		var path1 := AVATAR_DIR + "/avatar_" + _safe_name(char_name) + ".jpg"
		if FileAccess.file_exists(path1):
			var b1 := FileAccess.get_file_as_bytes(path1)
			if not b1.is_empty():
				return b1
	if char_id > 0:
		var path2 := AVATAR_DIR + "/avatar_id_" + str(char_id) + ".jpg"
		if FileAccess.file_exists(path2):
			var b2 := FileAccess.get_file_as_bytes(path2)
			if not b2.is_empty():
				return b2
	return PackedByteArray()

## Lấy chuỗi Base64 từ cache cục bộ (nếu có)
static func get_avatar_base64_cache(char_name: String, char_id := 0) -> String:
	var bytes := get_avatar_cache(char_name, char_id)
	if bytes.is_empty():
		return ""
	return bytes_to_base64(bytes)

## Xóa cache ảnh đại diện cục bộ khi người dùng chủ động bấm xóa
static func delete_avatar_cache(char_name: String, char_id := 0) -> void:
	if char_name != "":
		var path1 := AVATAR_DIR + "/avatar_" + _safe_name(char_name) + ".jpg"
		if FileAccess.file_exists(path1):
			DirAccess.remove_absolute(path1)
	if char_id > 0:
		var path2 := AVATAR_DIR + "/avatar_id_" + str(char_id) + ".jpg"
		if FileAccess.file_exists(path2):
			DirAccess.remove_absolute(path2)

## Nạp PackedByteArray thành Godot Image (hỗ trợ JPG, PNG, WEBP)
static func load_image_from_bytes(bytes: PackedByteArray) -> Image:
	if bytes.is_empty():
		return null
	var img := Image.new()
	# Nhận diện định dạng theo magic header bytes để tránh báo lỗi parser ở console
	if bytes.size() >= 4:
		if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
			if img.load_png_from_buffer(bytes) == OK:
				return img
		elif bytes[0] == 0xFF and bytes[1] == 0xD8:
			if img.load_jpg_from_buffer(bytes) == OK:
				return img
		elif bytes.size() >= 12 and bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46:
			if img.load_webp_from_buffer(bytes) == OK:
				return img

	# Fallback thử lần lượt
	if img.load_jpg_from_buffer(bytes) == OK:
		return img
	if img.load_png_from_buffer(bytes) == OK:
		return img
	if img.load_webp_from_buffer(bytes) == OK:
		return img
	return null

## Chuyển ảnh bất kỳ thành ảnh vuông 200x200 định dạng JPG buffer
static func convert_to_jpg_200(src_img: Image, image_offset: Vector2, zoom_scale: float, crop_frame_size := Vector2(200, 200)) -> PackedByteArray:
	if src_img == null:
		return PackedByteArray()
	
	var src_w := float(src_img.get_width())
	var src_h := float(src_img.get_height())
	if src_w <= 0.0 or src_h <= 0.0:
		return PackedByteArray()
	
	var display_w := int(round(src_w * zoom_scale))
	var display_h := int(round(src_h * zoom_scale))
	display_w = maxi(1, display_w)
	display_h = maxi(1, display_h)

	var scaled := src_img.duplicate()
	scaled.resize(display_w, display_h, Image.INTERPOLATE_LANCZOS)
	# Luôn đồng bộ định dạng FORMAT_RGBA8 cho cả hai ảnh để blit/blend tuyệt đối không bị lỗi định dạng
	scaled.convert(Image.FORMAT_RGBA8)

	var target := Image.create(int(crop_frame_size.x), int(crop_frame_size.y), false, Image.FORMAT_RGBA8)
	target.fill(Color(0.1, 0.1, 0.1, 1.0))

	# image_offset là vị trí góc trên-trái của ảnh so với góc trên-trái của khung 200x200
	var img_rect := Rect2i(int(round(image_offset.x)), int(round(image_offset.y)), display_w, display_h)
	var crop_rect := Rect2i(0, 0, int(crop_frame_size.x), int(crop_frame_size.y))
	var intersect := crop_rect.intersection(img_rect)

	if intersect.size.x > 0 and intersect.size.y > 0:
		var dst_pos := intersect.position
		var src_rect_pos := intersect.position - img_rect.position
		var src_rect := Rect2i(src_rect_pos.x, src_rect_pos.y, intersect.size.x, intersect.size.y)
		target.blend_rect(scaled, src_rect, dst_pos)

	if target.get_width() != AVATAR_SIZE.x or target.get_height() != AVATAR_SIZE.y:
		target.resize(AVATAR_SIZE.x, AVATAR_SIZE.y, Image.INTERPOLATE_LANCZOS)

	# Bắt buộc chuyển sang RGB8 (loại bỏ alpha) để lưu chuẩn JPG
	target.convert(Image.FORMAT_RGB8)
	return target.save_jpg_to_buffer(JPG_QUALITY)

## Chuyển PackedByteArray sang chuỗi Base64
static func bytes_to_base64(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""
	return Marshalls.raw_to_base64(bytes)

## Chuyển chuỗi Base64 sang ImageTexture hiển thị
static func base64_to_texture(b64: String) -> ImageTexture:
	if b64.strip_edges() == "":
		return null
	var bytes := Marshalls.base64_to_raw(b64)
	if bytes.is_empty():
		return null
	var img := load_image_from_bytes(bytes)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

## Mở hộp thoại chọn tệp hình ảnh từ điện thoại / web / máy tính
static func pick_image_file(host: Node, on_image_loaded: Callable) -> void:
	# 1. Trường hợp Web HTML5 (chạy trên trình duyệt Web điện thoại hoặc máy tính)
	if OS.has_feature("web") or (Engine.has_singleton("JavaScriptBridge") and OS.get_name() == "Web"):
		_pick_image_web(host, on_image_loaded)
		return

	# 2. Trường hợp Native (Desktop Windows/Mac/Linux hoặc Mobile Android)
	_pick_image_native(host, on_image_loaded)

static func _pick_image_web(host: Node, on_image_loaded: Callable) -> void:
	var js_code := """
	(function() {
		let input = document.getElementById('godot_avatar_input');
		if (!input) {
			input = document.createElement('input');
			input.id = 'godot_avatar_input';
			input.type = 'file';
			input.accept = 'image/png,image/jpeg,image/jpg,image/webp';
			input.style.display = 'none';
			document.body.appendChild(input);
		}
		input.value = '';
		input.onchange = function(e) {
			if (!input.files || input.files.length === 0) return;
			const file = input.files[0];
			const reader = new FileReader();
			reader.onload = function(evt) {
				const bytes = new Uint8Array(evt.target.result);
				let binary = '';
				const len = bytes.byteLength;
				for (let i = 0; i < len; i++) {
					binary += String.fromCharCode(bytes[i]);
				}
				window._godot_avatar_b64 = btoa(binary);
				window._godot_avatar_ready = true;
			};
			reader.readAsArrayBuffer(file);
		};
		window._godot_avatar_b64 = '';
		window._godot_avatar_ready = false;
		input.click();
	})();
	"""
	var js = Engine.get_singleton("JavaScriptBridge")
	if js:
		js.eval(js_code)

		# Tạo Timer nhỏ để kiểm tra khi nào người dùng chọn xong tệp trên Web
		var poll_timer := Timer.new()
		poll_timer.wait_time = 0.2
		host.add_child(poll_timer)
		var check_count := 0
		poll_timer.timeout.connect(func() -> void:
			check_count += 1
			if check_count > 300: # 60 giây timeout
				poll_timer.stop()
				poll_timer.queue_free()
				return
			var is_ready = js.eval("Boolean(window._godot_avatar_ready)")
			if is_ready:
				var b64: String = str(js.eval("window._godot_avatar_b64 || ''"))
				js.eval("window._godot_avatar_ready = false; window._godot_avatar_b64 = '';")
				poll_timer.stop()
				poll_timer.queue_free()
				if b64 != "":
					var bytes := Marshalls.base64_to_raw(b64)
					var img := load_image_from_bytes(bytes)
					if img:
						on_image_loaded.call(img)
		)
		poll_timer.start()

static func _pick_image_native(host: Node, on_image_loaded: Callable) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Định dạng ảnh"])
	dialog.title = "Chọn ảnh tải lên làm Avatar (200x200 px)"
	dialog.use_native_dialog = true

	dialog.file_selected.connect(func(path: String) -> void:
		var bytes := FileAccess.get_file_as_bytes(path)
		dialog.queue_free()
		if not bytes.is_empty():
			var img := load_image_from_bytes(bytes)
			if img:
				on_image_loaded.call(img)
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	host.add_child(dialog)
	dialog.popup_centered(Vector2i(720, 520))
