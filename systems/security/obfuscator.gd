class_name Obfuscator
extends RefCounted
## Tiện ích mã hóa & giải mã chuỗi nhạy cảm (String Obfuscation)
## Ngăn chặn việc phân tích tĩnh (Static Analysis) bằng các lệnh 'strings', Hex Editor
## hoặc dịch ngược bytecode GDScript (gdsdecomp / GodotRETools) để tìm salt, API endpoint, hoặc cấu trúc mật mã.

const DEFAULT_KEY: int = 0x5A

## Giải mã mảng byte đã làm mờ thành chuỗi UTF-8
static func deobfuscate(bytes: PackedByteArray, key: int = DEFAULT_KEY) -> String:
	var result := PackedByteArray()
	result.resize(bytes.size())
	for i in bytes.size():
		result[i] = bytes[i] ^ ((key + (i * 7)) & 0xFF)
	return result.get_string_from_utf8()

## Mã hóa chuỗi UTF-8 thành mảng byte làm mờ (dùng khi chuẩn bị hằng số)
static func obfuscate(text: String, key: int = DEFAULT_KEY) -> PackedByteArray:
	var raw := text.to_utf8_buffer()
	var result := PackedByteArray()
	result.resize(raw.size())
	for i in raw.size():
		result[i] = raw[i] ^ ((key + (i * 7)) & 0xFF)
	return result
