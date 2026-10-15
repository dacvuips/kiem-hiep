extends RefCounted
class_name UiPopups
## Sổ đăng ký popup/khung đang mở trên màn chơi — để thế giới (lăn chuột zoom camera...) biết có giao diện đang mở mà nhường.
## Popup tự ghi danh: `add_to_group(UiPopups.GROUP)` trong _ready. Mọi DraggableWindow (hành trang, nhân vật, khung xã hội,
## cài đặt...) đã tự ghi danh qua nhóm DraggableWindow.GROUP.

const GROUP := "ui_popups"

## Có popup nào đang HIỆN không (popup ẩn bằng visible = false không tính).
static func any_open(tree: SceneTree) -> bool:
	for group in [GROUP, DraggableWindow.GROUP]:
		for n in tree.get_nodes_in_group(group):
			if n.is_queued_for_deletion():
				continue
			if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
				return true
			if n is CanvasLayer and (n as CanvasLayer).visible:
				return true
	return false
