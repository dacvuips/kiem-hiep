class_name AccountLink
extends Node
## Game server gọi API nội bộ của server tài khoản (/internal/*) bằng khóa dịch vụ GAME_SERVICE_KEY.
## Khóa đọc từ biến môi trường của tiến trình game server — không nằm trong project / game.

var base_url := "http://127.0.0.1:8080"
var service_key := ""
var server_id := 1

## Xác minh người chơi vào map: trả {"ok", "code", "message", "account", "character"}.
func join(access_token: String, character_id: int) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/internal/game/join",
		{"access_token": access_token, "character_id": character_id, "server_id": server_id})

func save_character(character_id: int, version: int, data: Dictionary) -> Dictionary:
	return await _call(HTTPClient.METHOD_PUT, "/internal/game/characters/%d" % character_id, {"version": version, "data": data})

func _call(method: HTTPClient.Method, path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	var err := http.request(base_url + path, ["Content-Type: application/json", "X-Service-Key: " + service_key], method, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": "account_unreachable", "message": "Máy chủ tài khoản không phản hồi"}
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": "account_unreachable", "message": "Máy chủ tài khoản không phản hồi"}
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary:
		data = {}
	if int(res[1]) >= 200 and int(res[1]) < 300:
		data["ok"] = true
		return data
	return {"ok": false, "code": str(data.get("code", "error")), "message": str(data.get("message", "Lỗi máy chủ tài khoản"))}
