extends Node

const StageRewards = preload("res://systems/stage_rewards.gd")

signal stage_started(stage: StageData)
signal boss_spawned(boss_entry: EnemySpawnEntry)
signal stage_completed(stage: StageData)
signal magnet_used
## Bắn khi Player chết — Spawner/Enemy lắng nghe để dừng sinh quái mới/dừng di chuyển, tránh
## quái tiếp tục hoạt động sau khi Player đã bị queue_free() khỏi scene.
signal game_over

const ALL_STAGES_PATHS: Array[String] = [
	"res://stages/stage_01/stage_01.tres",
	"res://stages/stage_02/stage_02.tres",
	"res://stages/stage_03/stage_03.tres",
	"res://stages/stage_04/stage_04.tres",
	"res://stages/stage_05/stage_05.tres",
	"res://stages/stage_06/stage_06.tres",
	"res://stages/stage_07/stage_07.tres",
	"res://stages/stage_08/stage_08.tres",
	"res://stages/stage_09/stage_09.tres",
	"res://stages/stage_10/stage_10.tres",
	"res://stages/stage_11/stage_11.tres",
	"res://stages/stage_12/stage_12.tres",
]

var all_stages: Array[StageData] = []

var current_stage: StageData
## 2 chế độ chơi HOÀN TOÀN KHÁC NHAU:
##   STAGE    = "Vượt Ải": màn chơi là 1 ô vuông có hào quang trên map chính, quái sinh theo đợt (kiểu sinh tồn) — dùng current_stage.
##   MAIN_MAP = nút "Chơi": đi lại tự do trên toàn map chính, KHÔNG ô vuông, KHÔNG sinh quái/vật phẩm kiểu sinh tồn
##              (cơ chế riêng của chế độ này sẽ xây dần) — current_stage = null.
enum GameMode { STAGE, MAIN_MAP }
var game_mode: GameMode = GameMode.STAGE
## Map luyện công đang vào ở chế độ MAIN_MAP (mục của MapCatalog, chọn ở màn "Vượt Ải") — {} = map chính.
var field_map: Dictionary = {}
## true sau khi Player chết — Spawner kiểm tra cờ này trước khi tick sinh quái tiếp, không chỉ
## dựa vào signal (phòng trường hợp 1 Spawner được tạo SAU khi game_over đã bắn, VD debug/hot
## reload) để không bao giờ lỡ mất trạng thái game đã kết thúc.
var is_game_over: bool = false
## Nhân vật của người chơi TRÊN MÁY NÀY (do màn Chọn Nhân Vật tạo) — null nếu chạy thẳng
## Main.tscn để test mà không qua màn chọn.
var local_profile: PlayerProfile = null

## PlayerStats.level đạt được ở lượt chơi vừa kết thúc — CharacterHub đọc 1 lần lúc _ready() để
## quy đổi thành EXP nhân vật (PlayerProfile.add_exp()) rồi reset về -1, tránh cộng lặp lại mỗi
## khi mở Hub. -1 = chưa có trận nào vừa kết thúc để cộng.
var last_run_stats_level: int = -1

func notify_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	last_run_stats_level = PlayerStats.level
	game_over.emit()
	PlayerStats.reset()

func start_stage(stage: StageData) -> void:
	current_stage = stage
	is_game_over = false
	PlayerStats.reset()
	stage_started.emit(stage)

func notify_boss_spawned() -> void:
	if current_stage and current_stage.boss_tier:
		boss_spawned.emit(current_stage.boss_tier)

func notify_stage_completed() -> void:
	last_run_stats_level = PlayerStats.level
	stage_completed.emit(current_stage)
	PlayerStats.reset()

func notify_magnet_used() -> void:
	magnet_used.emit()

func _load_all_stages() -> void:
	if not all_stages.is_empty():
		return
	for path in ALL_STAGES_PATHS:
		if ResourceLoader.exists(path):
			var res := load(path) as StageData
			if res != null:
				all_stages.append(res)

func get_all_stages() -> Array[StageData]:
	if all_stages.is_empty():
		_load_all_stages()
	return all_stages

func get_stage_index(stage: StageData) -> int:
	if stage == null:
		return -1
	var list := get_all_stages()
	for i in range(list.size()):
		if list[i] == stage or list[i].resource_path == stage.resource_path:
			return i
	# Fallback qua tên màn hoặc tier
	var tier := StageRewards.get_stage_tier(stage)
	return maxi(0, tier - 1)
