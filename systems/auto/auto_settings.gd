extends RefCounted
class_name AutoSettings
## 1 bộ "Thiết lập auto đánh" (dữ liệu THUẦN, lưu theo nhân vật) — theo bảng auto của kiemhieptinh1.vn: 5 mục Hồi phục / Tấn công /
## Di chuyển / Hậu cần & Chiến báo / Nhặt đồ & Tổ đội. Mỗi nhân vật có 2 bộ: AUTO - Luyện công và AUTO - PK (PlayerProfile.auto_presets).
## Bộ máy chạy auto là AutoController (gắn trên Player) — trạng thái lúc chạy nằm ở đó, không nằm ở đây.
## Khoảng cách (phạm vi, tiếp cận, bán kính...) tính theo đơn vị logic VLTK = pixel ngang, dọc nhân đôi (như Player.get_nearest_enemy).

enum Mode { TRAIN, PK }
const SLOTS := 3                     ## mỗi nhóm kỹ năng 3 ô (Tấn công / Hỗ trợ / Vòng sáng & Buff máu)

# ---- Hồi phục: Sử dụng Dược Phẩm (Mức 1 = dùng 1 bình mỗi `ms1`; Mức 2 = dùng `count2` bình liền mỗi `ms2`) ----
var hp_on := true
var hp_lv1 := 60
var hp_ms1 := 1000
var hp_lv2 := 30
var hp_count2 := 2
var hp_ms2 := 1000
var mp_on := true
var mp_lv1 := 10
var mp_ms1 := 1000
var mp_lv2 := 2
var mp_count2 := 2
var mp_ms2 := 1000
# ---- Hồi phục: Dùng Thổ Địa Phù (phù về thành) ----
var tdp_low_hp_on := true
var tdp_low_hp := 35
var tdp_low_dura_on := true
var tdp_low_dura := 5
var tdp_no_hp_potion := true
var tdp_no_mp_potion := true
var tdp_bag_full := true
# ---- Hồi phục: Vật phẩm hỗ trợ ----
var use_double_exp := true
var use_skill_speed := true
var use_luck := true
var use_pk_clear := true
var use_tonic := true

# ---- Tấn công ----
var attack_skills: Array = ["", "", ""]
var support_skills: Array = ["", "", ""]
var aura_skills: Array = ["", "", ""]
var scan_range := 1500               ## Phạm vi: vùng tìm quái/người
var approach := 1000                 ## Tiếp cận: chạy tới gần mục tiêu tới khoảng này (không vượt tầm skill)
var target_players := true
var target_monsters := true
var prefer_boss := true
var chase := true                    ## Truy đuổi: mục tiêu ngoài tầm skill thì chạy theo
var prefer_low_hp := false
var element_filter_on := true        ## Ngũ hành: chỉ đánh quái thuộc các hệ đang tích
var elements: Array = [true, true, true, true, true]
var sect_filter_on := false          ## Môn phái: chỉ đánh người chơi thuộc các phái đang tích (PK)
var sects: Array = []                ## id môn phái

# ---- Di chuyển ----
var anchor_on := false               ## Đánh quanh điểm
var anchor_radius := 1000
var has_anchor := false
var anchor := Vector2.ZERO           ## toạ độ chân (world) đã lưu
var route_on := false                ## Chạy toạ độ: đánh lần lượt từng điểm
var route_radius := 500
var route: Array = []                ## Array[Vector2] toạ độ chân
var follow_leader_on := false        ## Theo sau đội trưởng
var follow_leader_dist := 200
var change_map_on_death := true
var change_map_deaths := 3
var change_map_minutes := 5

# ---- Hậu cần ----
var withdraw_money := true
var sell_junk := true
var store_equip := true
var repair_equip := true
## Mua dược: [bật, tên thuốc, số lượng] × 3
var potion_buys: Array = [[true, "Hồi Thiên Đan", 20], [true, "Đại Bổ Tán", 40], [false, "Ngũ Hoa Ngọc Lộ Hoàn", 0]]
var buy_tuyco := false
var buy_tdp := true
var return_to_spot := true
var train_map_on := true
var train_map := ""
# ---- Chiến báo ----
var report_tdp_on := true
var report_tdp_count := 3
var report_tdp_minutes := 5
var report_tdp_notify := 1
var report_death_on := true
var report_death_count := 3
var report_death_minutes := 5
var report_death_notify := 1

# ---- Nhặt đồ ----
var pick_range := 500
var pick_all := true
var pick_filter := true              ## Tuỳ chọn lọc đồ khi nhặt (dùng các dòng lọc bên dưới)
var pick_money := true
var pick_blue := true
var pick_props := true               ## Đạo cụ (vật phẩm không phải trang bị)
var keep_jewelry := true             ## Không bán trang sức
## Dòng lọc thuộc tính: {"text": chữ cần có trong 1 dòng thuộc tính, "min": giá trị nhỏ nhất}
var filter_rows: Array = []
# ---- Tổ đội ----
var team_on := true
var invite_mode := 0                 ## 0 Không mời đội · 1 Mời tất cả · 2 Theo danh sách
var accept_mode := 1                 ## 0 Không nhận · 1 Nhận tất cả · 2 Theo danh sách
var team_list: Array = []            ## tên người chơi

const INVITE_NAMES := ["Không mời đội", "Mời tất cả", "Theo danh sách"]
const ACCEPT_NAMES := ["Không nhận", "Nhận tất cả", "Theo danh sách"]

## Bộ mặc định cho AUTO - PK: chỉ đánh người, không đánh quái, không lọc ngũ hành.
static func pk_default() -> AutoSettings:
	var s := AutoSettings.new()
	s.target_monsters = false
	s.target_players = true
	s.prefer_boss = false
	s.element_filter_on = false
	s.prefer_low_hp = true
	return s

## Các khoá lưu = tên biến (trừ toạ độ cần đổi Vector2 <-> mảng).
const _KEYS := ["hp_on", "hp_lv1", "hp_ms1", "hp_lv2", "hp_count2", "hp_ms2", "mp_on", "mp_lv1", "mp_ms1", "mp_lv2", "mp_count2",
	"mp_ms2", "tdp_low_hp_on", "tdp_low_hp", "tdp_low_dura_on", "tdp_low_dura", "tdp_no_hp_potion", "tdp_no_mp_potion",
	"tdp_bag_full", "use_double_exp", "use_skill_speed", "use_luck", "use_pk_clear", "use_tonic",
	"attack_skills", "support_skills", "aura_skills", "scan_range", "approach", "target_players", "target_monsters",
	"prefer_boss", "chase", "prefer_low_hp", "element_filter_on", "elements", "sect_filter_on", "sects",
	"anchor_on", "anchor_radius", "has_anchor", "route_on", "route_radius", "follow_leader_on", "follow_leader_dist",
	"change_map_on_death", "change_map_deaths", "change_map_minutes",
	"withdraw_money", "sell_junk", "store_equip", "repair_equip", "potion_buys", "buy_tuyco", "buy_tdp", "return_to_spot",
	"train_map_on", "train_map", "report_tdp_on", "report_tdp_count", "report_tdp_minutes", "report_tdp_notify",
	"report_death_on", "report_death_count", "report_death_minutes", "report_death_notify",
	"pick_range", "pick_all", "pick_filter", "pick_money", "pick_blue", "pick_props", "keep_jewelry", "filter_rows",
	"team_on", "invite_mode", "accept_mode", "team_list"]

func to_dict() -> Dictionary:
	var d := {}
	for k in _KEYS:
		var v: Variant = get(k)
		d[k] = v.duplicate(true) if v is Array else v
	d["anchor"] = [anchor.x, anchor.y]
	var pts := []
	for p in route:
		pts.append([p.x, p.y])
	d["route"] = pts
	return d

static func from_dict(d: Dictionary, base: AutoSettings = null) -> AutoSettings:
	var s := base if base != null else AutoSettings.new()
	for k in _KEYS:
		if not d.has(k):
			continue
		var cur: Variant = s.get(k)
		var v: Variant = d[k]
		## JSON trả số thực — ép lại đúng kiểu biến; mảng giữ độ dài mặc định nếu dữ liệu lưu bị thiếu.
		if cur is bool:
			s.set(k, bool(v))
		elif cur is int:
			s.set(k, int(v))
		elif cur is String:
			s.set(k, str(v))
		elif cur is Array and v is Array:
			s.set(k, _merge_array(cur, v))
	var a: Variant = d.get("anchor")
	if a is Array and a.size() >= 2:
		s.anchor = Vector2(float(a[0]), float(a[1]))
	s.route.clear()
	for p in d.get("route", []):
		if p is Array and p.size() >= 2:
			s.route.append(Vector2(float(p[0]), float(p[1])))
	return s

static func _merge_array(cur: Array, saved: Array) -> Array:
	var out := saved.duplicate(true)
	for i in out.size():
		if i < cur.size() and cur[i] is int and out[i] is float:
			out[i] = int(out[i])
	## Ô kỹ năng / ngũ hành có số phần tử cố định.
	if cur.size() in [SLOTS, 5] and not (cur.is_empty()):
		while out.size() < cur.size():
			out.append(cur[out.size()])
	return out

## Nhãn toạ độ như mini map (1 đơn vị = MiniMap.COORD_UNIT pixel).
static func coord_text(feet: Vector2) -> String:
	return "%d/%d" % [floori(feet.x / MiniMap.COORD_UNIT), floori(feet.y / MiniMap.COORD_UNIT)]
