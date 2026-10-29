extends Node2D
class_name ChatBubble

const ItemChatHelper = preload("res://systems/items/item_chat_helper.gd")
## Lời nói kênh Gần hiện NGAY CHỖ tên nhân vật (kiểu VLTK): "Tên: nội dung" — tên màu vàng, nội dung màu trắng, viền đen; trong lúc
## hiện, nhãn tên gốc tạm ẩn (set_name_label_visible) để không thấy 2 tên. Gắn làm con của nhân vật (Player / RemotePlayer); dòng cuối
## nằm đúng chỗ nhãn tên (chat_anchor_y() của nhân vật — đổi khi lên ngựa / nhảy), câu dài thì dòng trên đẩy lên.
## Tin mới thay tin cũ; tự ẩn sau SHOW_SECONDS giây.

const SHOW_SECONDS := 5.0
const WIDTH := 240.0
const NAME_LINE_H := 18.0   ## cao nhãn tên gốc (Player / RemotePlayer)
const NAME_COLOR := Color(1.0, 0.85, 0.2)

var _label: RichTextLabel
var _left := 0.0

## Hiện lời nói `text` của `speaker_name` trên đầu `character`.
static func show_on(character: Node2D, speaker_name: String, text: String) -> void:
	if character == null or not is_instance_valid(character):
		return
	var bubble := character.get_node_or_null("ChatBubble") as ChatBubble
	if bubble == null:
		bubble = ChatBubble.new()
		bubble.name = "ChatBubble"
		character.add_child(bubble)
	bubble.say(speaker_name, text)

func _init() -> void:
	z_index = 10
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(WIDTH, 0)
	_label.size = Vector2(WIDTH, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", 12)
	_label.add_theme_color_override("default_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	visible = false

func say(speaker_name: String, text: String) -> void:
	var clean_text := ItemChatHelper.clean_item_tags_for_plain_text(text)
	_label.text = "[center][color=#%s]%s:[/color] %s[/center]" % [NAME_COLOR.to_html(false), _esc(speaker_name), _esc(clean_text)]
	_left = SHOW_SECONDS
	visible = true
	_set_name_visible(false)

func _set_name_visible(on: bool) -> void:
	var parent := get_parent()
	if parent and parent.has_method("set_name_label_visible"):
		parent.call("set_name_label_visible", on)

func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
		_set_name_visible(true)
		return
	var parent := get_parent()
	var name_y: float = parent.call("chat_anchor_y") if parent and parent.has_method("chat_anchor_y") else -70.0
	var h := _label.get_content_height()
	_label.size = Vector2(WIDTH, h)
	_label.position = Vector2(-WIDTH * 0.5, name_y + NAME_LINE_H - h)

## Chặn mã định dạng trong lời nói.
static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")
