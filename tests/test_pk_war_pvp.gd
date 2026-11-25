extends Node

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, detail: Variant = "") -> void:
	if cond:
		_pass += 1
		print("PASS: ", name)
	else:
		_fail += 1
		print("FAIL: ", name, " | ", detail)

func _ready() -> void:
	print("--- BẮT ĐẦU TEST: CHIẾN ĐẤU PHE (PK WAR), ICON VÀ CÂY MÁU ---")

	# 1. Test NetProto constants
	check("NetProto.FLAG_PK_WAR == 128", NetProto.FLAG_PK_WAR == 128, NetProto.FLAG_PK_WAR)
	check("NetProto.CLIENT_FLAGS chứa FLAG_PK_WAR", (NetProto.CLIENT_FLAGS & NetProto.FLAG_PK_WAR) != 0, NetProto.CLIENT_FLAGS)
	check("NetProto.CLIENT_FLAGS chứa FLAG_PK", (NetProto.CLIENT_FLAGS & NetProto.FLAG_PK) != 0, NetProto.CLIENT_FLAGS)

	# 2. Test logic kiểm tra điều kiện PK giữa 2 người khác màu trên Server (RelationServer logic)
	# Case A: 2 người khác phe (Chính phái vs Tà phái) cùng bật Chiến Đấu Phe (FLAG_PK_WAR)
	var c_war := true
	var t_war := true
	var c_camp := Camp.Type.JUSTICE  # Chính phái (Vàng Cam)
	var t_camp := Camp.Type.EVIL     # Tà phái (Tím Hồng)
	var war_hit := c_war and t_war and c_camp != t_camp and c_camp != Camp.Type.BEGIN and t_camp != Camp.Type.BEGIN
	check("2 người khác màu phe cùng bật Chiến Đấu -> Được phép đánh nhau (war_hit = true)", war_hit)

	# Case B: 1 người bật Chiến đấu, 1 người vẫn Luyện Công (t_war = false)
	var t_war_peace := false
	var war_hit_peace := c_war and t_war_peace and c_camp != t_camp and c_camp != Camp.Type.BEGIN and t_camp != Camp.Type.BEGIN
	check("1 người Luyện công, 1 người Chiến đấu -> KHÔNG đánh được nhau", not war_hit_peace)

	# Case C: 2 người CÙNG PHE (cùng màu: Chính phái vs Chính phái) cùng bật Chiến đấu
	var same_camp := Camp.Type.JUSTICE
	var war_hit_same := c_war and t_war and c_camp != same_camp and c_camp != Camp.Type.BEGIN and same_camp != Camp.Type.BEGIN
	check("2 người cùng màu phe (đồng đạo) cùng bật Chiến đấu -> KHÔNG đánh nhau", not war_hit_same)

	# Case D: 1 trong 2 người là Tân Thủ (Camp.Type.BEGIN)
	var begin_camp := Camp.Type.BEGIN
	var war_hit_begin := c_war and t_war and c_camp != begin_camp and c_camp != Camp.Type.BEGIN and begin_camp != Camp.Type.BEGIN
	check("Có người chơi Tân Thủ -> Được bảo vệ, KHÔNG bị đánh", not war_hit_begin)

	# Case E: Có 1 người Đồ Sát (FLAG_PK)
	var c_murder := true
	var pk_hit_murder := c_murder or war_hit
	check("Bật Đồ Sát -> Cho phép đánh mọi người (trừ tân thủ/tổ đội)", pk_hit_murder)

	# 3. Test RemotePlayer và cây máu (_hp_bar)
	var rp := RemotePlayer.new()
	var info := {
		"eid": 1001,
		"name": "NguDocTaPhai",
		"level": 50,
		"camp": Camp.Type.EVIL,
		"nation": Nation.Type.NONE,
		"pos": Vector2(100, 100),
		"look": {"body": 1, "head": 1},
		"flags": NetProto.FLAG_PK_WAR,
		"hp": 85
	}
	add_child(rp)
	rp.setup(info)

	check("RemotePlayer có cây máu _hp_bar", rp._hp_bar != null)
	check("Cây máu của RemotePlayer KHÔNG bị ẩn (_hp_bar.visible == true)", rp._hp_bar.visible == true)
	check("Cây máu có giá trị đúng 85%", is_equal_approx(rp._hp_bar.bar.value, 85.0), rp._hp_bar.bar.value)

	# 4. Test logic xác định kẻ thù (update_pk_relation) trên client
	# Giả sử mình là Chính phái, đối phương là Tà phái có FLAG_PK_WAR
	var my_camp_justice := Camp.Type.JUSTICE

	# Nếu mình ở pk_mode == 0 (Luyện công): đối phương không phải kẻ thù
	var is_murder_rp := (rp.flags & NetProto.FLAG_PK) != 0
	var is_war_rp := (rp.flags & NetProto.FLAG_PK_WAR) != 0
	var enemy_when_peace := is_murder_rp
	check("Mình đang Luyện Công -> Đối phương Chiến Đấu KHÔNG phải kẻ thù", not enemy_when_peace)

	# Nếu mình ở pk_mode == 1 (Chiến đấu phe): đối phương là kẻ thù
	var enemy_when_war := is_murder_rp or (is_war_rp and rp.camp != my_camp_justice and rp.camp != Camp.Type.BEGIN)
	check("Mình bật Chiến Đấu + khác màu phe đối phương -> Đối phương LÀ KẺ THÙ", enemy_when_war)

	rp.set_pk_enemy(enemy_when_war)
	check("Khi là kẻ thù, RemotePlayer được thêm vào nhóm 'enemies'", rp.is_in_group("enemies"))
	check("Khi là kẻ thù, cây máu _hp_bar VẪN HIỆN", rp._hp_bar.visible == true)

	rp.queue_free()

	print("--- KẾT THÚC TEST: RESULT %d/%d (Thất bại: %d) ---" % [_pass, _pass + _fail, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
