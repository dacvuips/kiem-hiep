extends CanvasLayer
class_name CharacterStatusWindow
## Khung "Nhân vật" (Trang bị + Thuộc tính) nổi — dùng ở map đánh quái. Bọc CharacterStatusScreen (bản
## nhúng thường trực của màn Hub) trong DraggableWindow KHÔNG viền (ảnh khung của panel đã là khung), không
## nền tối, để mở cùng lúc với khung Hành trang. Kéo bằng cách nắm chỗ trống trên ảnh khung.

## Kích thước vùng chứa panel = ĐÚNG kích thước panel ở màn Hub (Frame 733x550 ở 1280x720). Vị trí chữ trong
## scene theo anchor (co giãn theo khung) nhưng cỡ chữ cố định px — thu nhỏ khung là chữ tràn/lệch ô.
const CONTENT_SIZE := Vector2(733, 550)

var screen: CharacterStatusScreen
var _profile: PlayerProfile
var _inventory_opener: Callable

static func open(parent: Node, profile: PlayerProfile, inventory_opener: Callable) -> CharacterStatusWindow:
	var w := CharacterStatusWindow.new()
	w._profile = profile
	w._inventory_opener = inventory_opener
	parent.add_child(w)
	return w

func _ready() -> void:
	layer = DraggableWindow.WINDOW_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var window := DraggableWindow.new("Nhân vật", true)
	window.close_requested.connect(queue_free)
	## Dời nút X vào trong thanh tiêu đề gỗ của ảnh khung (góc phải, trước tua rua đỏ).
	window.close_button.offset_left = -88
	window.close_button.offset_right = -56
	window.close_button.offset_top = 46
	window.close_button.offset_bottom = 76
	add_child(window)
	var holder := Control.new()
	holder.custom_minimum_size = CONTENT_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	window.body.add_child(holder)
	screen = CharacterStatusScreen.attach(holder, _profile)
	screen.inventory_opener = _inventory_opener
