extends Button
class_name HubEquipSlot
## Ô trang bị trong màn hình Nhân vật / Trang bị của CharacterHub.
## Hỗ trợ hiển thị tooltip thông tin chi tiết vật phẩm đầy đủ như trong hành trang.

var item_bbcode: String = ""

func _make_custom_tooltip(_for_text: String) -> Object:
	if item_bbcode.is_empty():
		return null
	return ItemSlotButton.create_tooltip(item_bbcode)
