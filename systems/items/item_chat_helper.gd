class_name ItemChatHelper
extends RefCounted
## Helper hỗ trợ gắn link vật phẩm vào khung chat và giải mã hiển thị thông tin vật phẩm khi click.
## Cấu trúc token trong tin nhắn: {item:BASE64_PAYLOAD}
## Khi hiển thị: biến đổi thành [url=item:BASE64_PAYLOAD][color=#hex][b][Tên Món][/b][/color][/url]

const TOKEN_PREFIX := "{item:"
const TOKEN_SUFFIX := "}"

## Chuyển ItemInstance thành payload Base64 gọn nhẹ
static func encode_item(item: ItemInstance) -> String:
	if item == null:
		return ""
	var d := {}
	var base := item.get_base()
	d["n"] = str(base.get("name", "Vật phẩm"))
	if item.base_index >= 0:
		d["b"] = item.base_index
	if item.gold_index >= 0:
		d["g"] = item.gold_index
	if item.series != 0:
		d["s"] = item.series
	if not item.base_values.is_empty():
		d["bv"] = item.base_values
	if not item.magic.is_empty():
		d["m"] = item.magic
	if not item.expand_magic.is_empty():
		d["em"] = item.expand_magic
	if item.durability > 0:
		d["dur"] = item.durability
	if item.misc_id != "":
		d["mid"] = item.misc_id
	if item.count > 1:
		d["c"] = item.count
	if item.item_level > 0:
		d["ilv"] = item.item_level
	if item.quality > 0:
		d["q"] = item.quality
	if item.sockets > 0:
		d["sk"] = item.sockets
	if item.ore_magic > 0:
		d["om"] = item.ore_magic
	if item.luck > 0:
		d["lk"] = item.luck
	d["col"] = item.get_quality_color().to_html(false)

	var json_str := JSON.stringify(d)
	return Marshalls.utf8_to_base64(json_str)

## Giải mã Base64 thành ItemInstance
static func decode_item(base64_str: String) -> ItemInstance:
	if base64_str.is_empty():
		return null
	var json_str := Marshalls.base64_to_utf8(base64_str)
	if json_str.is_empty():
		return null
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		return null

	var item := ItemInstance.new()
	item.base_index = int(parsed.get("b", -1))
	item.gold_index = int(parsed.get("g", -1))
	item.series = int(parsed.get("s", 0))
	item.base_values = parsed.get("bv", []).duplicate(true)
	for line in parsed.get("m", []):
		var v: Array = line.get("value", [0, 0, 0])
		var entry := {
			"attrib": str(line.get("attrib", "")),
			"value": [int(v[0]), int(v[1]), int(v[2])],
			"name": str(line.get("name", "")),
			"prefix": bool(line.get("prefix", true))
		}
		for k in ["mid", "mlv"]:
			if line.has(k):
				entry[k] = int(line[k])
		item.magic.append(entry)
	for line in parsed.get("em", []):
		var ev: Array = line.get("value", [0, 0, 0])
		item.expand_magic.append({
			"attrib": str(line.get("attrib", "")),
			"value": [int(ev[0]), int(ev[1]), int(ev[2])],
			"name": str(line.get("name", "")),
			"prefix": true
		})
	item.durability = int(parsed.get("dur", 0))
	item.misc_id = str(parsed.get("mid", ""))
	item.count = maxi(int(parsed.get("c", 1)), 1)
	item.item_level = int(parsed.get("ilv", 0))
	item.quality = int(parsed.get("q", 0))
	item.sockets = int(parsed.get("sk", 0))
	item.ore_magic = int(parsed.get("om", 0))
	item.luck = int(parsed.get("lk", 0))
	item.ensure_uid()
	return item

## Tạo token chuỗi truyền tin
static func create_token(item: ItemInstance) -> String:
	return TOKEN_PREFIX + encode_item(item) + TOKEN_SUFFIX

## Chuyển đổi chuỗi tin nhắn có token {item:...} thành BBCode hiển thị màu sắc và bấm được ([url=...])
static func format_chat_bbcode(raw_text: String) -> String:
	if raw_text.is_empty():
		return ""
	var result := ""
	var cur_pos := 0
	var text_len := raw_text.length()

	while cur_pos < text_len:
		var token_start := raw_text.find(TOKEN_PREFIX, cur_pos)
		if token_start == -1:
			result += _esc(raw_text.substr(cur_pos))
			break

		if token_start > cur_pos:
			result += _esc(raw_text.substr(cur_pos, token_start - cur_pos))

		var token_end := raw_text.find(TOKEN_SUFFIX, token_start + TOKEN_PREFIX.length())
		if token_end == -1:
			result += _esc(raw_text.substr(token_start))
			break

		var payload := raw_text.substr(token_start + TOKEN_PREFIX.length(), token_end - (token_start + TOKEN_PREFIX.length()))
		var link_bbcode := _format_single_item_link(payload)
		result += link_bbcode
		cur_pos = token_end + TOKEN_SUFFIX.length()

	return result

static func _format_single_item_link(payload: String) -> String:
	var json_str := Marshalls.base64_to_utf8(payload)
	var item_name := "Vật phẩm"
	var col_hex := "FFD700"
	if not json_str.is_empty():
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			item_name = str(parsed.get("n", "Vật phẩm"))
			col_hex = str(parsed.get("col", "FFD700"))
	return "[url=item:%s][color=#%s][b][%s][/b][/color][/url]" % [payload, col_hex, _esc(item_name)]

## Lọc bỏ token {item:...} thành text đơn giản [Tên Món] cho ChatBubble hoặc nhãn văn bản thuần
static func clean_item_tags_for_plain_text(raw_text: String) -> String:
	if raw_text.is_empty():
		return ""
	var result := ""
	var cur_pos := 0
	var text_len := raw_text.length()

	while cur_pos < text_len:
		var token_start := raw_text.find(TOKEN_PREFIX, cur_pos)
		if token_start == -1:
			result += raw_text.substr(cur_pos)
			break
		if token_start > cur_pos:
			result += raw_text.substr(cur_pos, token_start - cur_pos)
		var token_end := raw_text.find(TOKEN_SUFFIX, token_start + TOKEN_PREFIX.length())
		if token_end == -1:
			result += raw_text.substr(token_start)
			break
		var payload := raw_text.substr(token_start + TOKEN_PREFIX.length(), token_end - (token_start + TOKEN_PREFIX.length()))
		var json_str := Marshalls.base64_to_utf8(payload)
		var item_name := "Vật phẩm"
		if not json_str.is_empty():
			var parsed = JSON.parse_string(json_str)
			if parsed is Dictionary:
				item_name = str(parsed.get("n", "Vật phẩm"))
		result += "[%s]" % item_name
		cur_pos = token_end + TOKEN_SUFFIX.length()

	return result

static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

## Gắn vật phẩm vào khung chat và mở khung chat
static func attach_to_chat(item: ItemInstance, host: Node) -> void:
	if item == null:
		return
	var panel := ChatPanel.open(host)
	if panel != null:
		panel.insert_item(item)
