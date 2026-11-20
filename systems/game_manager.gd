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

## Chế độ mạng kết nối:
##   OFFLINE = Chơi ngoại tuyến, không cần mạng, dữ liệu lưu cục bộ trên máy.
##   ONLINE  = Chơi với người chơi thật, bắt buộc có mạng Internet, KHÔNG có bot.
enum NetworkMode { OFFLINE, ONLINE }
var network_mode: NetworkMode = NetworkMode.OFFLINE:
	set(val):
		network_mode = val
		GameModeManager.current_mode = GameModeManager.Mode.ONLINE if val == NetworkMode.ONLINE else GameModeManager.Mode.OFFLINE

func is_online_mode() -> bool:
	return network_mode == NetworkMode.ONLINE

## Đồ hết hạn sử dụng (ItemInstance.expire_at) — OFFLINE: máy này tự thu hồi mỗi EXPIRE_CHECK_SEC giây.
## Online thì chỉ game server thu hồi (GameServer._check_expired_items) rồi gửi bản chuẩn xuống — máy người chơi không tự sửa.
const EXPIRE_CHECK_SEC := 30.0

func _ready() -> void:
	var t := Timer.new()
	t.wait_time = EXPIRE_CHECK_SEC
	t.autostart = true
	t.timeout.connect(check_expired_items)
	add_child(t)

func check_expired_items() -> void:
	if local_profile == null or is_online_mode():
		return
	var gone := local_profile.remove_expired_items()
	if gone.is_empty():
		return
	ChatBox.push_system("[color=#ff5a00][Hệ thống][/color] Vật phẩm hết hạn sử dụng đã bị thu hồi: %s" % ", ".join(gone))
	if OS.get_environment("KIEMHIEP_NO_SAVE") != "1":
		SaveManager.save_profile(local_profile)

func is_offline_mode() -> bool:
	return network_mode == NetworkMode.OFFLINE

func allows_bot() -> bool:
	return not is_online_mode()

func can_create_bot() -> bool:
	return not is_online_mode()

func can_add_bot() -> bool:
	return not is_online_mode()

func requires_internet() -> bool:
	return is_online_mode()


## 2 chế độ chơi HOÀN TOÀN KHÁC NHAU:
##   STAGE    = "Vượt Ải": màn chơi là 1 ô vuông có hào quang trên map chính, quái sinh theo đợt (kiểu sinh tồn) — dùng current_stage.
##   MAIN_MAP = nút "Chơi": đi lại tự do trên toàn map chính, KHÔNG ô vuông, KHÔNG sinh quái/vật phẩm kiểu sinh tồn
##              (cơ chế riêng của chế độ này sẽ xây dần) — current_stage = null.
enum GameMode { STAGE, MAIN_MAP }
var game_mode: GameMode = GameMode.STAGE
## Map luyện công đang vào ở chế độ MAIN_MAP (mục của MapCatalog, chọn ở màn "Vượt Ải") — {} = map chính.
var field_map: Dictionary = {}

func is_manor_mode() -> bool:
	return (field_map.get("manor", false) == true) or int(field_map.get("id", -1)) == 1041

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

## Kiểm tra bản đồ hiện tại có được MIỄN PHÍ nội lực (không mất mana khi đánh/ra chiêu) hay không:
## Chế độ Vượt Ải offline (Survivor / Stage) hoàn toàn MIỄN PHÍ nội lực (không mất mana).
func is_free_mana_stage(_player: Node = null) -> bool:
	if GameModeManager.is_offline() and (game_mode == GameMode.STAGE or field_map.get("survivor_mode", false) or current_stage != null):
		return true
	return false

## Kiểm tra bản đồ hiện tại có thuộc phần "Luyện" (tab Luyện - map luyện công dã ngoại thông thường) không.
func is_training_stage() -> bool:
	if current_stage != null:
		return false
	if field_map.is_empty() or not field_map.has("id"):
		return false
	if field_map.has("hell") or field_map.has("boss") or field_map.has("pk") or field_map.has("arena"):
		return false
	if field_map.get("challenge", false) or field_map.get("phong_lang_do", false) or field_map.has("battle") or field_map.get("escort", false) or field_map.get("viem_de", false) or field_map.get("brawl", false) or field_map.get("tong_kim_lol", false) or field_map.get("city_war", false) or field_map.get("linh_lung_thap", false) or field_map.get("linh_lung_prep", false):
		return false
	return true

## Xử lý sự kiện đóng game vật lý (Alt+F4 / tắt cửa sổ / nút X / đóng ứng dụng):
## Đảm bảo tự động dọn dẹp và xóa các phòng khi người cuối cùng rời đi.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		cleanup_rooms_on_game_closing()

## Dọn dẹp toàn bộ phòng khi đóng game hoặc rời phòng
static func cleanup_rooms_on_game_closing() -> void:
	var prof: PlayerProfile = null
	if GameManager and "local_profile" in GameManager:
		prof = GameManager.local_profile

	# 1. PUBG: Rời trận và tự động xóa phòng nếu hết người
	PubgManager.on_game_closing(prof)

	# 2. Các sảnh phòng PK, Thách Đấu Thời Gian, Viêm Đế: đóng phòng của mình
	if prof != null:
		PkLobby.close_own(prof)
		TimeChallengeLobby.close_own(prof)
		ViemDeLobby.close_own(prof)

	# 3. Mạng Online: Ngắt kết nối sạch sẽ để server lập tức trigger peer_disconnected và xóa phòng
	if NetClient != null and NetClient.has_method("disconnect_from_server") and NetClient.status != NetClient.Status.OFFLINE:
		NetClient.disconnect_from_server()


