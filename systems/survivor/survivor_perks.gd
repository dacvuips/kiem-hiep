class_name SurvivorPerks
extends RefCounted
## HỆ THỐNG KỸ NĂNG BỔ TRỢ & PERKS OFFLINE SURVIVOR (12 KỸ NĂNG 5 TẦNG)
##
## Quản lý 12 kỹ năng đặc trưng nâng tối đa 5 tầng (cấp sao 1..5):
## 1. x2 Đạn (Bách Phát Tề Phi)
## 2. Đánh nối tiếp (Liên Hoàn Kích)
## 3. Đạn sau lưng (Hồi Mã Thương)
## 4. Tăng bán kính / phạm vi đánh (Khai Thiên Tích Địa)
## 5. Tăng tốc độ chạy (Lăng Ba Vi Bộ)
## 6. Khiên phòng vệ chặn đòn - Aura Quán Quân Tinh Anh Sái (Kim Chung Quán Quân)
## 7. Hút máu +0.5% dựa trên sát thương (Hút Huyết Ma Công)
## 8. Đạn dội sang quái khác (Đạn Nẩy Bát Phương)
## 9. Đạn xuyên lớp quái (Xuyên Tâm Thần Tiễn)
## 10. Kích thước viên đạn (Cự Kiếm Cuồng Tiêu)
## 11. Tăng máu người chơi +20% (Kim Cang Bất Hoại)
## 12. Tăng sát thương kỹ năng (Tu La Sát Ý)

const MAX_PERK_LEVEL := 5
const STATE_ID_SHIELD_AURA := 142 # Quán Quân Tinh Anh Sái

## Lưu trữ cấp độ perk hiện tại trong trận: perk_id -> int (1..5)
static var active_perks: Dictionary = {}

const PERK_DEFINITIONS := {
	"multishot": {
		"id": "multishot",
		"name": "Bách Phát Tề Phi",
		"subtitle": "X2 & Thêm Đạn",
		"icon_path": "res://upgrades/icon/perk_multishot.png",
		"desc_levels": [
			"Phóng thêm +1 tia đạn mỗi đợt chiêu thức",
			"Phóng thêm +2 tia đạn mỗi đợt chiêu thức",
			"Phóng thêm +3 tia đạn mỗi đợt chiêu thức",
			"Phóng thêm +4 tia đạn mỗi đợt chiêu thức",
			"Tối Đa: +5 tia đạn bao phủ toàn bộ chiến trường!"
		]
	},
	"combo_cast": {
		"id": "combo_cast",
		"name": "Liên Hoàn Kích",
		"subtitle": "Đánh Nối Tiếp",
		"icon_path": "res://upgrades/icon/perk_combo_cast.png",
		"desc_levels": [
			"20% cơ hội tung thêm 1 đòn đánh nối tiếp tức thì",
			"40% cơ hội tung thêm 1 đòn đánh nối tiếp tức thì",
			"60% cơ hội tung thêm 1 đòn đánh nối tiếp tức thì",
			"80% cơ hội tung thêm 1 đòn đánh nối tiếp tức thì",
			"100% chắc chắn kích hoạt thêm đòn đánh nối tiếp liên hoàn!"
		]
	},
	"rear_bullet": {
		"id": "rear_bullet",
		"name": "Hồi Mã Thương",
		"subtitle": "Đạn Sau Lưng",
		"icon_path": "res://upgrades/icon/perk_rear_bullet.png",
		"desc_levels": [
			"Bắn thêm 1 viên đạn phóng ngược 180° ra sau lưng",
			"Bắn thêm 2 viên đạn phóng ngược 180° ra sau lưng",
			"Bắn thêm 3 viên đạn phóng ngược 180° ra sau lưng",
			"Bắn thêm 4 viên đạn phóng ngược 180° ra sau lưng",
			"Tối Đa: 5 viên đạn cực mạnh quét sạch quái vật phía sau!"
		]
	},
	"range_up": {
		"id": "range_up",
		"name": "Khai Thiên Tích Địa",
		"subtitle": "Tăng Tầm Đánh",
		"icon_path": "res://upgrades/icon/perk_range_up.png",
		"desc_levels": [
			"Tăng +15% phạm vi và bán kính tấn công",
			"Tăng +30% phạm vi và bán kính tấn công",
			"Tăng +45% phạm vi và bán kính tấn công",
			"Tăng +60% phạm vi và bán kính tấn công",
			"Tăng +75% phạm vi và bán kính tấn công toàn màn hình!"
		]
	},
	"move_speed": {
		"id": "move_speed",
		"name": "Lăng Ba Vi Bộ",
		"subtitle": "Tốc Độ Chạy",
		"icon_path": "res://upgrades/icon/perk_move_speed.png",
		"desc_levels": [
			"Tăng +10% tốc độ di chuyển",
			"Tăng +20% tốc độ di chuyển",
			"Tăng +30% tốc độ di chuyển",
			"Tăng +40% tốc độ di chuyển",
			"Tăng +50% tốc độ di chuyển thoăn thoắt lướt gió!"
		]
	},
	"guardian_shield": {
		"id": "guardian_shield",
		"name": "Kim Chung Quán Quân",
		"subtitle": "Khiên Phòng Vệ",
		"icon_path": "res://upgrades/icon/perk_guardian_shield.png",
		"desc_levels": [
			"Hào quang Quán Quân hộ thể: Chặn 100% sát thương của 1 đòn đánh, hồi khiên sau 12s",
			"Khiên phòng vệ cường hóa: Hồi lại khiên sau 10s",
			"Khiên phòng vệ cường hóa: Hồi lại khiên sau 8s",
			"Khiên phòng vệ cường hóa: Hồi lại khiên sau 6s",
			"Tuyệt đỉnh hộ thể: Hồi phục khiên thần tốc chỉ sau 4s!"
		]
	},
	"life_leech": {
		"id": "life_leech",
		"name": "Hút Huyết Ma Công",
		"subtitle": "Hút Máu",
		"icon_path": "res://upgrades/icon/perk_life_leech.png",
		"desc_levels": [
			"Mỗi đòn đánh trúng chuyển hóa +0.5% sát thương thành máu",
			"Mỗi đòn đánh trúng chuyển hóa +1.0% sát thương thành máu",
			"Mỗi đòn đánh trúng chuyển hóa +1.5% sát thương thành máu",
			"Mỗi đòn đánh trúng chuyển hóa +2.0% sát thương thành máu",
			"Mỗi đòn đánh trúng chuyển hóa +2.5% sát thương thành sinh lực liên tục!"
		]
	},
	"bounce": {
		"id": "bounce",
		"name": "Đạn Nẩy Bát Phương",
		"subtitle": "Đạn Dội",
		"icon_path": "res://upgrades/icon/perk_bounce.png",
		"desc_levels": [
			"Đạn trúng quái sẽ bật dội sang 1 quái lân cận gần nhất",
			"Đạn trúng quái sẽ bật dội liên tiếp 2 lần sang các quái lân cận",
			"Đạn trúng quái sẽ bật dội liên tiếp 3 lần sang các quái lân cận",
			"Đạn trúng quái sẽ bật dội liên tiếp 4 lần sang các quái lân cận",
			"Tối Đa: Đạn bật dội 5 lần liên tục càn quét tan nát bầy quái!"
		]
	},
	"pierce": {
		"id": "pierce",
		"name": "Xuyên Tâm Thần Tiễn",
		"subtitle": "Đạn Xuyên Quái",
		"icon_path": "res://upgrades/icon/perk_pierce.png",
		"desc_levels": [
			"Đạn không dừng lại, bay xuyên qua 1 lớp quái vật",
			"Đạn không dừng lại, bay xuyên qua 2 lớp quái vật",
			"Đạn không dừng lại, bay xuyên qua 3 lớp quái vật",
			"Đạn không dừng lại, bay xuyên qua 4 lớp quái vật",
			"Xuyên Thấu Vô Cực: Đạn xuyên qua toàn bộ mọi quái trên đường bay!"
		]
	},
	"bullet_size": {
		"id": "bullet_size",
		"name": "Cự Kiếm Cuồng Tiêu",
		"subtitle": "Kích Thước Đạn",
		"icon_path": "res://upgrades/icon/perk_bullet_size.png",
		"desc_levels": [
			"Tăng +20% kích thước viên đạn và vùng quét sát thương",
			"Tăng +40% kích thước viên đạn và vùng quét sát thương",
			"Tăng +60% kích thước viên đạn và vùng quét sát thương",
			"Tăng +80% kích thước viên đạn và vùng quét sát thương",
			"Gấp đôi kích thước viên đạn (+100%) càn quét diện rộng cực đại!"
		]
	},
	"max_hp": {
		"id": "max_hp",
		"name": "Kim Cang Bất Hoại",
		"subtitle": "Tăng Máu 20%",
		"icon_path": "res://upgrades/icon/perk_max_hp.png",
		"desc_levels": [
			"Tăng +20% Sinh Lực tối đa của người chơi",
			"Tăng +40% Sinh Lực tối đa của người chơi",
			"Tăng +60% Sinh Lực tối đa của người chơi",
			"Tăng +80% Sinh Lực tối đa của người chơi",
			"Tối Đa: Tăng gấp đôi (+100%) Sinh Lực tối đa trường tồn bất diệt!"
		]
	},
	"damage_boost": {
		"id": "damage_boost",
		"name": "Tu La Sát Ý",
		"subtitle": "Tăng Sát Thương",
		"icon_path": "res://upgrades/icon/perk_damage_boost.png",
		"desc_levels": [
			"Tăng +20% sát thương cho tất cả chiêu thức",
			"Tăng +40% sát thương cho tất cả chiêu thức",
			"Tăng +60% sát thương cho tất cả chiêu thức",
			"Tăng +80% sát thương cho tất cả chiêu thức",
			"Tối Đa: Gấp đôi (+100%) toàn bộ uy lực sát thương kỹ năng!"
		]
	}
}

static func reset() -> void:
	active_perks.clear()

static func get_perk_level(perk_id: String) -> int:
	return int(active_perks.get(perk_id, 0))

static func is_perk_maxed(perk_id: String) -> bool:
	return get_perk_level(perk_id) >= MAX_PERK_LEVEL

## Nâng 1 tầng cho perk (tối đa 5 tầng)
static func upgrade_perk(perk_id: String, player: CharacterBody2D = null) -> int:
	var cur := get_perk_level(perk_id)
	if cur >= MAX_PERK_LEVEL:
		return cur
	var nxt := cur + 1
	active_perks[perk_id] = nxt
	apply_perk_effects(perk_id, nxt, player)
	return nxt

## Áp dụng hiệu ứng tức thời và chỉ số khi perk lên cấp
static func apply_perk_effects(perk_id: String, level: int, player: CharacterBody2D = null) -> void:
	match perk_id:
		"multishot":
			PlayerStats.extra_projectile_count = level
		"range_up":
			PlayerStats.range_multiplier = 1.0 + float(level) * 0.15
		"move_speed":
			PlayerStats.move_speed_multiplier = 1.0 + float(level) * 0.10
			if player and "speed" in player and "base_speed" in player:
				player.speed = player.base_speed * PlayerStats.move_speed_multiplier
		"max_hp":
			if player and "max_health" in player and "health" in player:
				var base_hp: float = player.get("base_max_health") if player.get("base_max_health") != null else 1000.0
				var hp_mult: float = 1.0 + float(level) * 0.20
				var new_max: float = base_hp * hp_mult
				var diff: float = new_max - player.max_health
				player.max_health = new_max
				player.health = minf(player.max_health, player.health + maxf(0.0, diff))
				if player.has_signal("health_changed"):
					player.health_changed.emit(player.health, player.max_health)
		"damage_boost":
			PlayerStats.damage_multiplier = 1.0 + float(level) * 0.20
		"guardian_shield":
			if player:
				_ensure_guardian_shield(player)

## Đảm bảo component khiên phòng vệ gắn vào Player
static func _ensure_guardian_shield(player: CharacterBody2D) -> void:
	if player == null or not is_instance_valid(player):
		return
	var shield_comp = player.get_node_or_null("SurvivorShieldComponent")
	if shield_comp == null:
		var sc_cls = load("res://systems/survivor/survivor_shield_component.gd")
		if sc_cls:
			shield_comp = sc_cls.new()
			shield_comp.name = "SurvivorShieldComponent"
			player.add_child(shield_comp)
	if shield_comp and shield_comp.has_method("refresh_shield"):
		shield_comp.refresh_shield()

## Lưu trữ texture đã nạp để tối ưu hiệu năng
static var _cached_icons: Dictionary = {}

## Lấy thông tin texture icon cho perk
static func get_perk_icon(perk_id: String) -> Texture2D:
	if _cached_icons.has(perk_id) and _cached_icons[perk_id] != null:
		return _cached_icons[perk_id]
	var def: Dictionary = PERK_DEFINITIONS.get(perk_id, {})
	var path: String = str(def.get("icon_path", ""))
	if path == "":
		return null
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			tex = res
	# Fallback: Nạp trực tiếp file ảnh PNG qua ImageTexture nếu chưa qua pipeline import của Godot
	if tex == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_cached_icons[perk_id] = tex
	return tex

## Lấy số đạn dội (Bounce count)
static func get_bounce_count() -> int:
	return get_perk_level("bounce")

## Lấy số quái đạn có thể xuyên (Pierce count): cấp 5 xuyên vô hạn (999)
static func get_pierce_count() -> int:
	var lvl := get_perk_level("pierce")
	if lvl <= 0:
		return 0
	if lvl >= 5:
		return 999
	return lvl

## Lấy hệ số phóng to kích thước viên đạn
static func get_bullet_scale() -> float:
	var lvl := get_perk_level("bullet_size")
	return 1.0 + float(lvl) * 0.20

## Lấy tỉ lệ hút máu (0.005 mỗi cấp = 0.5%)
static func get_life_leech_ratio() -> float:
	var lvl := get_perk_level("life_leech")
	return float(lvl) * 0.005

## Lấy số đạn bắn sau lưng
static func get_rear_bullet_count() -> int:
	return get_perk_level("rear_bullet")

## Lấy tỉ lệ kích hoạt đòn đánh nối tiếp (0.20 mỗi cấp)
static func get_combo_cast_chance() -> float:
	var lvl := get_perk_level("combo_cast")
	return float(lvl) * 0.20
