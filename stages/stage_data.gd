extends Resource
class_name StageData

## Tên hiển thị, VD "Màn 1 - Thanh Phong Thôn"
@export var stage_name: String = ""

## Ảnh thu nhỏ xem trước của bàn chơi (nếu null, tự động lấy từ minimap của vltk_map_id)
@export var preview_texture: Texture2D

## true = map cho nhân vật tự di chuyển -> hiện joystick kéo góc dưới-trái (MoveJoystick). Tắt với
## map không cần đi lại (VD đứng yên đánh boss) để joystick không chiếm chỗ màn hình.
@export var show_move_joystick: bool = true

## Danh sách quái xuất hiện trong màn này — mỗi entry gắn 1 EnemyTierData (loại quái) kèm hệ số
## nhân + thời điểm/tần suất RIÊNG cho map này (xem EnemySpawnEntry) — cho phép cùng 1 loại quái
## mạnh/yếu khác nhau tuỳ map. Thêm màn mới chỉ cần tạo StageData mới với danh sách riêng, không
## sửa code.
@export var enemy_tiers: Array[EnemySpawnEntry] = []

## Boss xuất hiện cuối màn (để trống nếu màn này chưa có boss)
@export var boss_tier: EnemySpawnEntry

## Thời gian màn kéo dài (giây) trước khi boss xuất hiện / màn kết thúc
@export var stage_duration: float = 180.0

## Thời điểm boss xuất hiện (giây). 0.0 = tự động tính bằng 2/3 stage_duration (VD màn 180s -> boss ra lúc 120s, tương ứng chặng 3/3).
@export var boss_spawn_time: float = 0.0

## Lấy thời điểm boss xuất hiện (giây).
func get_boss_spawn_time() -> float:
	if boss_spawn_time > 0.0:
		return boss_spawn_time
	return stage_duration * (2.0 / 3.0)

@export_group("Ô vuông màn chơi trên map chính")
## Toàn bộ game dùng 1 MAP CHÍNH duy nhất (Main.tscn/World = VltkWorld). Mỗi màn chơi chỉ là 1 ô vuông trên map đó: nhân vật
## và quái bị giới hạn trong ô, rìa ô có hào quang sáng. Toạ độ tính bằng PIXEL MAP (cùng hệ toạ độ Node2D của map;
## mỗi vùng 512px, ô lưới 32x16px). Bấm F8 khi đang chạy (bản debug) để chép toạ độ nhân vật hiện tại, dán vào `arena_center`.
## (0, 0) = tự chọn: tâm khu chơi của map.
@export var arena_center: Vector2 = Vector2.ZERO
## Kích thước ô vuông (pixel map). Quái sinh quanh rìa TRONG của ô.
@export var arena_size: Vector2 = Vector2(4000, 4000)
## Màu hào quang ở rìa ô.
@export var arena_color: Color = Color(1.0, 0.82, 0.35)

@export_group("Âm thanh / khác")
## Map VLTK gốc (STT trong maplist.ini) dùng để lấy NHẠC NỀN của màn này (MusicSet.txt). 0 = dùng nhạc mặc định.
@export var vltk_map_id: int = 0

## Lấy ảnh xem trước của bàn: nếu có preview_texture thì dùng; nếu không thì lấy minimap của map_id.
func get_preview_texture() -> Texture2D:
	if preview_texture != null:
		return preview_texture
	var mid := vltk_map_id if vltk_map_id > 0 else 20
	var path := "res://world/maps/map_%d/minimap.jpg" % mid
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null
