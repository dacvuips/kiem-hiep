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

@export_group("Đặc tả Vượt Ải & Đánh Giá 3 Sao (GDD)")
## Cấp độ nhân vật tối thiểu để được tham gia ải (1x = 10, 2x = 20, 3x = 30, 4x = 40...)
@export var required_level: int = 10

## Tiêu chí 1: Thời gian hoàn thành tối đa (giây) để đạt ⭐ Thời Gian (mặc định bằng stage_duration)
@export var target_time: float = 180.0

## Tiêu chí 2: Điểm thành tích tối thiểu để đạt ⭐ Điểm Số
@export var target_score: int = 2500

## Tiêu chí 3: Số lượng quái tiêu diệt tối thiểu để đạt ⭐ Số Quái Hạ Gục
@export var target_kills: int = 100

func evaluate_stars(time_taken: float, score: int, kills: int) -> Dictionary:
	var t_max := target_time if target_time > 0.0 else stage_duration
	var star_time := time_taken <= t_max
	var star_score := score >= target_score
	var star_kills := kills >= target_kills
	var total_stars := 0
	if star_time: total_stars += 1
	if star_score: total_stars += 1
	if star_kills: total_stars += 1
	return {
		"total_stars": total_stars,
		"star_time": star_time,
		"star_score": star_score,
		"star_kills": star_kills,
		"target_time": t_max,
		"target_score": target_score,
		"target_kills": target_kills,
		"time_taken": time_taken,
		"score": score,
		"kills": kills
	}

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

@export_group("Cân bằng chiến đấu màn chơi")
## Hệ số sát thương quái riêng cho màn chơi này (1.0 = giữ nguyên sát thương gốc).
## Giúp cân bằng độ đau của quái trong màn chơi đông quái mà giữ nguyên vẹn dữ liệu quái cốt lõi.
@export var stage_monster_damage_multiplier: float = 1.0

## Bật thời gian miễn thương chớp nhoáng (I-Frame) khi người chơi trúng đòn trong màn chơi này
## (bảo vệ người chơi khi bị đàn quái đông bao vây, tránh bị cắn dồn dập shock sát thương trong 1 khung hình).
@export var enable_hit_invincibility: bool = true

## Thời gian miễn thương chớp nhoáng sau khi trúng đòn (giây). Mặc định 0.35s.
@export var hit_invincibility_duration: float = 0.35

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
