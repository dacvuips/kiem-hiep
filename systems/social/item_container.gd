extends RefCounted
class_name ItemContainer
## Ô chứa đồ dạng LƯỚI dùng chung cho rương, phòng giao dịch, quầy bày bán — cùng cách xếp với hành trang (mỗi món chiếm rộng × cao ô,
## toạ độ room_x / room_y / room_bag nằm TRÊN ItemInstance). Giữ danh sách `items`, không biết gì về người chơi nên dùng lại được khi online.
## Có cùng tên hàm với PlayerProfile (inventory / ROOM_WIDTH / get_room_height / can_place / move_item) để ItemRoomView vẽ được cả hai.

signal changed

var inventory: Array[ItemInstance] = []   ## tên `inventory` để ItemRoomView dùng chung
var room_width: int = 6
var room_height: int = 10
var bag_count: int = 1                    ## số "túi" (rương mở rộng) đang mở — bag = 0..bag_count-1
var ROOM_WIDTH: int:
	get:
		return room_width
var ROOM_HEIGHT: int:
	get:
		return room_height

func _init(width := 6, height := 10, bags := 1) -> void:
	room_width = width
	room_height = height
	bag_count = bags

func get_room_height(_bag: int = 0) -> int:
	return room_height

func owns(item: ItemInstance) -> bool:
	return inventory.has(item)

func _cell_blocked(x: int, y: int, bag: int, except: ItemInstance) -> bool:
	for it in inventory:
		if it == except or it.room_x < 0 or it.room_bag != bag:
			continue
		var size := it.get_size()
		if x >= it.room_x and x < it.room_x + size.x and y >= it.room_y and y < it.room_y + size.y:
			return true
	return false

func can_place(item: ItemInstance, x: int, y: int, bag: int, rows: int = -1) -> bool:
	if rows < 0:
		rows = room_height
	if bag < 0 or bag >= bag_count:
		return false
	var size := item.get_size()
	if x < 0 or y < 0 or x + size.x > room_width or y + size.y > rows:
		return false
	for cy in range(y, y + size.y):
		for cx in range(x, x + size.x):
			if _cell_blocked(cx, cy, bag, item):
				return false
	return true

func find_free_spot(size: Vector2i, bag: int, except: ItemInstance = null) -> Vector2i:
	for y in range(0, room_height - size.y + 1):
		for x in range(0, room_width - size.x + 1):
			var free := true
			for cy in range(y, y + size.y):
				for cx in range(x, x + size.x):
					if _cell_blocked(cx, cy, bag, except):
						free = false
						break
				if not free:
					break
			if free:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

## Chỗ trống đầu tiên ở BẤT KỲ túi đang mở: Vector3i(x, y, túi); z = -1 nếu hết chỗ.
func find_free_spot_any(size: Vector2i, except: ItemInstance = null) -> Vector3i:
	for bag in bag_count:
		var spot := find_free_spot(size, bag, except)
		if spot.x >= 0:
			return Vector3i(spot.x, spot.y, bag)
	return Vector3i(-1, -1, -1)

func has_room_for(item: ItemInstance) -> bool:
	return find_free_spot_any(item.get_size(), item).z >= 0

## Thêm món vào chỗ trống đầu tiên — false nếu hết chỗ. (Món không được đang nằm trong container khác — người gọi tự gỡ trước.)
func add_item(item: ItemInstance) -> bool:
	if item == null:
		return false
	var spot := find_free_spot_any(item.get_size())
	if spot.z < 0:
		return false
	item.room_x = spot.x
	item.room_y = spot.y
	item.room_bag = spot.z
	inventory.append(item)
	changed.emit()
	return true

func remove_item(item: ItemInstance) -> bool:
	var idx := inventory.find(item)
	if idx < 0:
		return false
	inventory.remove_at(idx)
	changed.emit()
	return true

func move_item(item: ItemInstance, x: int, y: int, bag: int) -> bool:
	if not inventory.has(item) or not can_place(item, x, y, bag):
		return false
	item.room_x = x
	item.room_y = y
	item.room_bag = bag
	changed.emit()
	return true

## Đặt món (đang thuộc nơi khác, đã được người gọi gỡ ra) vào đúng ô (x, y, túi) — false nếu không vừa.
func place_item(item: ItemInstance, x: int, y: int, bag: int) -> bool:
	if inventory.has(item) or not can_place(item, x, y, bag):
		return false
	item.room_x = x
	item.room_y = y
	item.room_bag = bag
	inventory.append(item)
	changed.emit()
	return true

func clear() -> void:
	inventory.clear()
	changed.emit()

func to_array() -> Array:
	var out := []
	for it in inventory:
		out.append(it.to_dict())
	return out

func load_array(data: Array) -> void:
	inventory.clear()
	for d in data:
		inventory.append(ItemInstance.from_dict(d))
