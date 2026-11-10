class_name MapVoiceManager

## Quản lý phát âm thanh & hiển thị câu thoại khi chuyển bản đồ.
## Toàn bộ file audio được lưu trữ tập trung tại: res://audio/voice_transitions/
## Danh mục mapping chi tiết lưu tại: res://audio/voice_transitions/map_voices.json

const VOICE_DIR := "res://audio/voice_transitions"
const INDEX_PATH := "res://audio/voice_transitions/map_voices.json"
const DEFAULT_AUDIO := "res://audio/voice_transitions/default_transition.mp3"
const DEFAULT_TEXT := "Huynh đài hãy nắm chặt yên cương, ta cùng lên đường xuất chinh!"

static var _index: Dictionary = {}
static var _variants_to_slug: Dictionary = {}
static var _stream_cache: Dictionary = {}
static var _is_initialized: bool = false

static func _ensure_initialized() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_load_index()

static func _load_index() -> void:
	_index.clear()
	_variants_to_slug.clear()

	var json_str := ""
	if FileAccess.file_exists(INDEX_PATH):
		json_str = FileAccess.get_file_as_string(INDEX_PATH)
	if json_str.is_empty():
		return

	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Dictionary:
		_index = parsed
		for slug: String in _index.keys():
			var entry: Dictionary = _index[slug]
			_variants_to_slug[slug.to_lower()] = slug
			var v_name: String = str(entry.get("name", "")).strip_edges().to_lower()
			if not v_name.is_empty():
				_variants_to_slug[v_name] = slug
			var variants: Array = entry.get("variants", [])
			for v: Variant in variants:
				var v_str: String = str(v).strip_edges().to_lower()
				if not v_str.is_empty():
					_variants_to_slug[v_str] = slug

## Chuẩn hóa tên map để tra cứu
static func clean_map_name(raw_name: String) -> String:
	var s := raw_name.strip_edges()
	# Xóa tiền tố "Ải X · "
	var regex_ai := RegEx.new()
	regex_ai.compile("^Ải\\s+\\d+\\s*·\\s*")
	s = regex_ai.sub(s, "")
	# Xóa hậu tố " · Tinh Anh..."
	var dot_pos := s.find("·")
	if dot_pos != -1:
		s = s.substr(0, dot_pos).strip_edges()
	# Xóa hậu tố nhóm cấp "(12x)", "(11x)", v.v.
	var regex_tier := RegEx.new()
	regex_tier.compile("\\s*\\(\\d+x?\\)$")
	s = regex_tier.sub(s, "")
	# Xóa hậu tố "(1)" nếu có
	var regex_num := RegEx.new()
	regex_num.compile("\\s*\\(\\d+\\)$")
	s = regex_num.sub(s, "")
	return s.strip_edges()

## Lấy thông tin âm thanh và câu thoại theo tên map
## Trả về: { "file": String, "text": String, "clean_name": String }
static func get_voice_info(raw_map_name: String) -> Dictionary:
	_ensure_initialized()

	var raw_lower := raw_map_name.strip_edges().to_lower()
	var clean := clean_map_name(raw_map_name)
	var clean_lower := clean.to_lower()

	# 1. Tra cứu trực tiếp từ biến thể nguyên bản
	var target_slug := ""
	if _variants_to_slug.has(raw_lower):
		target_slug = _variants_to_slug[raw_lower]
	elif _variants_to_slug.has(clean_lower):
		target_slug = _variants_to_slug[clean_lower]
	else:
		# Tìm kiếm mờ nếu có chứa tên sạch
		for k: String in _variants_to_slug.keys():
			if not clean_lower.is_empty() and (clean_lower == k or clean_lower.contains(k) or k.contains(clean_lower)):
				target_slug = _variants_to_slug[k]
				break

	if not target_slug.is_empty() and _index.has(target_slug):
		var entry: Dictionary = _index[target_slug]
		return {
			"file": str(entry.get("file", "")),
			"text": str(entry.get("text", "")),
			"clean_name": str(entry.get("name", clean))
		}

	# 2. Xử lý trường hợp đặc biệt
	if clean_lower.contains("về thành") or clean_lower.contains("dưỡng sức"):
		return {
			"file": VOICE_DIR + "/ve_thanh_duong_suc.mp3",
			"text": "Huynh đài hãy nắm chặt yên cương, ta cùng về thành dưỡng sức!",
			"clean_name": "Về Thành Dưỡng Sức"
		}

	# 3. Fallback mặc định
	var fallback_text := "Huynh đài hãy nắm chặt yên cương, ta cùng tiến vào %s!" % (clean if not clean.is_empty() else "giang hồ")
	return {
		"file": DEFAULT_AUDIO,
		"text": fallback_text,
		"clean_name": clean if not clean.is_empty() else "Bản Đồ Mới"
	}

## Nạp AudioStream (Hỗ trợ nạp động bằng FileAccess nếu editor chưa re-import)
static func load_stream(path: String) -> AudioStreamMP3:
	if path.is_empty():
		return null
	if _stream_cache.has(path):
		return _stream_cache[path]

	var stream: AudioStreamMP3 = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStreamMP3

	if stream == null and FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			stream = AudioStreamMP3.new()
			stream.data = bytes

	if stream != null:
		_stream_cache[path] = stream

	return stream
