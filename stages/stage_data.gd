extends Resource
class_name StageData

## Tên hiển thị, VD "Màn 1 - Thanh Phong Thôn"
@export var stage_name: String = ""

## Scene world/map riêng cho màn này (vật cản, background, ranh giới)
@export var world_scene: PackedScene

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
@export var stage_duration: float = 300.0
