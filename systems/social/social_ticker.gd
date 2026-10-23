extends Node
class_name SocialTicker
## Node nhẹ đặt trong cảnh chơi: mỗi frame đẩy nhịp cho SocialHub của nhân vật hiện tại (khách mua hàng bày bán, người xin vào đội/bang...)
## và hiện thông báo lên nhân vật (Player._notice) khi có sự kiện. Không làm gì nếu chưa có nhân vật.

var _hub: SocialHub = null

func _ready() -> void:
	add_to_group("social_ticker")

func _process(delta: float) -> void:
	var p := GameManager.local_profile
	if p == null:
		return
	if _hub == null or _hub.profile != p:
		_hub = SocialHub.of(p)
		if not _hub.notice.is_connected(_on_notice):
			_hub.notice.connect(_on_notice)
	_hub.tick(delta)

func _on_notice(text: String, good: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player != null and player.has_method("_notice"):
		player._notice(text)
