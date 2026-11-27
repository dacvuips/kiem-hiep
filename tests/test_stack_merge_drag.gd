extends Node
## Kéo thả chồng vật phẩm lên chồng cùng loại = gộp (PlayerProfile.merge_stack + ItemRoomView).
## Chạy: KIEMHIEP_NO_SAVE=1 godot --headless --path . res://tests/test_stack_merge_drag.tscn

const MID := "6_1_215"   ## Càn Khôn Tạo Hóa Đan (đại), chồng tối đa 10

var _fails := 0

func _check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + msg)
	if not ok:
		_fails += 1

func _misc(count: int, x: int) -> ItemInstance:
	var it := ItemInstance.new()
	it.misc_id = MID
	it.count = count
	it.uid = ItemInstance.new_uid()
	it.room_x = x
	it.room_y = 0
	it.room_bag = 0
	return it

func _ready() -> void:
	var p := PlayerProfile.new()
	p.inventory.clear()
	var a := _misc(4, 0)
	var b := _misc(3, 2)
	p.inventory.append(a)
	p.inventory.append(b)

	## 1. Gộp thẳng trên hồ sơ: hết chồng nguồn thì bỏ khỏi túi.
	_check(p.merge_stack(a.uid, b.uid) == "", "gộp 4 vào 3")
	_check(b.count == 7 and not p.inventory.has(a), "chồng đích 7, chồng nguồn biến mất")

	## 2. Vượt trần: chỉ chuyển tới 10, phần dư giữ lại.
	var c := _misc(6, 0)
	p.inventory.append(c)
	_check(p.merge_stack(c.uid, b.uid) == "", "gộp 6 vào 7")
	_check(b.count == 10 and c.count == 3 and p.inventory.has(c), "đích đầy 10, nguồn còn 3")
	_check(p.merge_stack(c.uid, b.uid) != "", "chồng đầy thì báo lỗi")

	## 3. Khác khoá -> không gộp.
	var d := _misc(1, 4)
	d.lock_trade = true
	p.inventory.append(d)
	_check(p.merge_stack(d.uid, c.uid) != "" and c.count == 3, "khác trạng thái khoá không gộp")

	## 4. Kéo thả qua ItemRoomView (offline).
	var room := ItemRoomView.new()
	room.cell = 37
	add_child(room)
	room.setup(p)
	var changed := [0]
	room.changed.connect(func() -> void: changed[0] += 1)
	var e := _misc(2, 6)
	p.inventory.append(e)
	var data := {"type": ItemRoomView.DRAG_TYPE, "item": e, "source": p, "grab": Vector2i.ZERO}
	var on_c := Vector2(c.room_x + 0.5, 0.5) * room.cell
	_check(room._can_drop_data(on_c, data), "thả lên chồng cùng loại được phép")
	room._drop_data(on_c, data)
	_check(c.count == 5 and not p.inventory.has(e) and changed[0] == 1, "kéo thả gộp 2 vào 3 = 5")
	var on_full := Vector2(b.room_x + 0.5, 0.5) * room.cell
	var f := _misc(1, 7)
	p.inventory.append(f)
	var data_f := {"type": ItemRoomView.DRAG_TYPE, "item": f, "source": p, "grab": Vector2i.ZERO}
	_check(not room._can_drop_data(on_full, data_f), "chồng đầy: không cho thả (ô đã có món)")

	print("KẾT QUẢ: %s" % ("ĐẠT" if _fails == 0 else "%d LỖI" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
