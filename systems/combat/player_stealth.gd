class_name PlayerStealth
## ẨN THÂN với AI quái / bot (VLTK gốc: KNpcAI::CheckNpc coi người có m_HideState.nTime > 0 là mục tiêu hỏng -> bỏ;
## lúc tìm địch quanh mình cũng bỏ qua người đang ẩn). Người ẩn VẪN trúng đòn (đạn/vùng sát thương vẫn va chạm) —
## chỉ không bị chọn làm mục tiêu, không bị đạn đuổi theo.
## GM tàng hình cũng tính là ẩn (GM còn miễn sát thương — phần đó xử lý riêng ở Player).

## Người chơi của máy này đang ẩn thân bằng skill (Player cập nhật mỗi khi đổi; về false khi rời cây).
static var local_is_hidden := false

## Người chơi máy này có đang ẩn với quái / bot offline không (rẻ: gọi được mỗi frame cho từng con quái).
static func local_hidden() -> bool:
	return local_is_hidden or (GmManager != null and GmManager.is_invisible)

## `node` có đang ẩn không: người chơi máy này (skill / GM) hoặc người chơi khác online (RemotePlayer, cờ server).
static func is_hidden(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return false
	var n := node as Node
	if n.is_in_group("player"):
		return local_hidden()
	return n.has_method("is_hidden") and bool(n.call("is_hidden"))
