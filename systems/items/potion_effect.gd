extends Node
class_name PotionEffect
## Thuốc hồi sinh lực đang tác dụng trên 1 nhân vật (node con của Player) — đúng engine VLTK gốc:
##   - magic_lifepotion_v [giá trị, số frame]: mỗi GAME_UPDATE_TIME (10) frame (18 frame/giây) cộng "giá trị" sinh lực, trong "số frame"
##     (KNpc.cpp 1051-1061). VD Kim Sáng Dược (tiểu) [10, 100]: +10 mỗi ~0,56 giây, 10 lần = 100 sinh lực trong ~5,6 giây.
##   - Uống chồng (KNpcAttribModify.cpp 747-760): thời gian mới = max(còn lại, mới), giá trị mỗi nhịp = (v1·t1 + v2·t2) / thời gian mới
##     -> tổng lượng hồi giữ nguyên, hồi NHANH hơn chứ không kéo dài.
## Nội lực (manapotion_v) chưa có trong game -> bỏ qua.

const GAME_FPS := 18.0
const UPDATE_FRAMES := 10

var _value := 0.0       ## sinh lực mỗi nhịp
var _frames := 0        ## frame còn lại
var _acc := 0.0

## Hiệu ứng thuốc của nhân vật `player` (tạo khi cần).
static func of(player: Node) -> PotionEffect:
	var e := player.get_node_or_null("PotionEffect") as PotionEffect
	if e == null:
		e = PotionEffect.new()
		e.name = "PotionEffect"
		player.add_child(e)
	return e

## Món này có hồi sinh lực không (thuốc dùng được).
static func heals(item: ItemInstance) -> bool:
	if item == null or not item.is_misc():
		return false
	for e in item.get_base().get("effects", []):
		if str(e[0]) == "lifepotion_v":
			return true
	return false

## Uống 1 món: thêm hiệu ứng hồi sinh lực. Trả false nếu món không phải thuốc hồi sinh lực.
static func drink(player: Node, item: ItemInstance) -> bool:
	if not heals(item):
		return false
	for e in item.get_base().get("effects", []):
		if str(e[0]) == "lifepotion_v":
			PotionEffect.of(player).add(float(e[1]), int(e[2]))
	return true

func add(value: float, frames: int) -> void:
	if frames <= 0:
		return
	var new_frames := maxi(_frames, frames)
	_value = (_value * _frames + value * frames) / float(new_frames)
	_frames = new_frames

func is_active() -> bool:
	return _frames > 0

func _process(delta: float) -> void:
	if _frames <= 0:
		return
	var parent := get_parent()
	if parent == null or (parent.has_method("is_dead") and parent.call("is_dead")):
		_frames = 0
		return
	_acc += delta * GAME_FPS
	while _acc >= 1.0 and _frames > 0:
		_acc -= 1.0
		_frames -= 1
		if _frames % UPDATE_FRAMES == 0 and parent.has_method("heal"):
			parent.heal(_value)
