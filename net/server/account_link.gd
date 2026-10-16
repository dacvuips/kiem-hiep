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

## Trạng thái khoá / cấm chat của nhiều tài khoản: {"statuses": {"id": {banned, ban_message, muted_until}}}.
func status(account_ids: Array, character_ids: Array = []) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/internal/game/status", {"account_ids": account_ids, "character_ids": character_ids})

func list_guilds() -> Dictionary:
	return await _call(HTTPClient.METHOD_GET, "/internal/game/guilds?server_id=%d" % server_id, {})

func save_guild(guild_name: String, data: Dictionary, old_name := "") -> Dictionary:
	return await _call(HTTPClient.METHOD_PUT, "/internal/game/guilds",
		{"server_id": server_id, "name": guild_name, "old_name": old_name, "data": data})

func delete_guild(guild_name: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_DELETE, "/internal/game/guilds?server_id=%d&name=%s" % [server_id, guild_name.uri_encode()], {})

## grant_ids: quà chờ (Xu -> Nguyên bảo) đã cộng vào `data` — server tài khoản đánh dấu đã nhận cùng lúc lưu.
## Chợ Giao Thương: mỗi món treo 1 dòng (id do game server sinh), data = listing MarketBook.
func list_market() -> Dictionary:
	return await _call(HTTPClient.METHOD_GET, "/internal/game/market?server_id=%d" % server_id, {})

func save_market(id: String, data: Dictionary) -> Dictionary:
	return await _call(HTTPClient.METHOD_PUT, "/internal/game/market", {"server_id": server_id, "id": id, "data": data})

func delete_market(id: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_DELETE, "/internal/game/market?server_id=%d&id=%s" % [server_id, id.uri_encode()], {})

func save_character(character_id: int, version: int, data: Dictionary, grant_ids: Array = []) -> Dictionary:
	return await _call(HTTPClient.METHOD_PUT, "/internal/game/characters/%d" % character_id,
		{"version": version, "data": data, "grant_ids": grant_ids})

## Chiến trường Tống Kim: báo trạng thái trận (số người, điểm, giai đoạn, địa chỉ) — game đọc qua GET /v1/battle.
func report_battle(state: Dictionary) -> void:
	var r: Dictionary = await _call(HTTPClient.METHOD_POST, "/internal/game/battle", state)
	if not r.ok:
		push_warning("Báo trạng thái chiến trường lỗi: %s" % r.get("message", ""))

## Đấu trường PK: báo danh sách phòng + địa chỉ server đấu trường — popup PK đọc qua GET /v1/arena.
func report_arena(state: Dictionary) -> void:
	var r: Dictionary = await _call(HTTPClient.METHOD_POST, "/internal/game/arena", state)
	if not r.ok:
		push_warning("Báo trạng thái đấu trường lỗi: %s" % r.get("message", ""))

## Phòng train chung Vượt Ải: báo danh sách phòng + địa chỉ field server — màn Vượt Ải đọc qua GET /v1/field (tìm phòng theo ID).
func report_field(state: Dictionary) -> void:
	var r: Dictionary = await _call(HTTPClient.METHOD_POST, "/internal/game/field", state)
	if not r.ok:
		push_warning("Báo trạng thái phòng train chung lỗi: %s" % r.get("message", ""))

## Nhịp tim vận hành (web Admin › Máy chủ): báo trạng thái tiến trình; trả {ok, settings: {exp_mult, drop_item_mult, drop_money_mult},
## command: {id, action: "restart", seconds, message} | không có}.
func heartbeat(state: Dictionary) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/internal/game/heartbeat", state)

func _call(method: HTTPClient.Method, path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	var err := http.request(base_url + path, ["Content-Type: application/json", "X-Service-Key: " + service_key], method, payload)
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
