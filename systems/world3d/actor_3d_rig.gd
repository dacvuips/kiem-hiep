extends Node3D
class_name Actor3DRig
## Nhân vật 3D GHÉP BỘ PHẬN — cùng cách với bản 2D (CharacterAvatar): mỗi bộ phận 1 khe riêng, đổi trang bị là đổi
## đúng khe đó. Tên khe trùng tên lớp 2D (data/avatar/<giới tính>.json "layer_ids"):
##   mũ  (helm):   head, hair
##   áo  (armor):  shoulder, body, left_hand, right_hand
##   vũ khí:       left_weapon, right_weapon
##   ngựa (horse): horse_front, horse_middle, horse_back
## Hiện mỗi khe là 1 KHỐI màu theo mã hình (đổi đồ -> đổi màu). SAU NÀY: set_part_model(khe, cảnh) gắn model bộ phận
## vào khe (model đầu, áo, vũ khí... theo mã hình như bản 2D chọn sheet theo mã hình).
## Đọc trang bị + hướng từ CharacterAvatar của nhân vật 2D (đã đồng bộ từ server như cũ) — rig không có logic riêng.

const GROUP_OF := {
	"head": "helm", "hair": "helm",
	"shoulder": "armor", "body": "armor", "left_hand": "armor", "right_hand": "armor",
	"left_weapon": "weapon", "right_weapon": "weapon",
	"horse_front": "horse", "horse_middle": "horse", "horse_back": "horse",
}
## Khối thử của từng khe: [tâm (m, mặt quay +Z, tay trái = +X), cỡ]
const BLOCKS := {
	"body": [Vector3(0, 0.34, 0), Vector3(0.30, 0.58, 0.20)],
	"shoulder": [Vector3(0, 0.60, 0), Vector3(0.40, 0.09, 0.23)],
	"head": [Vector3(0, 0.74, 0), Vector3(0.16, 0.17, 0.16)],
	"hair": [Vector3(0, 0.84, -0.01), Vector3(0.17, 0.05, 0.17)],
	"left_hand": [Vector3(0.22, 0.44, 0), Vector3(0.08, 0.30, 0.08)],
	"right_hand": [Vector3(-0.22, 0.44, 0), Vector3(0.08, 0.30, 0.08)],
	"left_weapon": [Vector3(0.22, 0.30, 0.16), Vector3(0.03, 0.03, 0.36)],
	"right_weapon": [Vector3(-0.22, 0.30, 0.22), Vector3(0.03, 0.03, 0.48)],
	"horse_middle": [Vector3(0, 0.42, 0), Vector3(0.34, 0.30, 0.80)],
	"horse_front": [Vector3(0, 0.66, 0.46), Vector3(0.18, 0.34, 0.22)],
	"horse_back": [Vector3(0, 0.52, -0.44), Vector3(0.10, 0.24, 0.12)],
}
const RIDE_LIFT := 0.42   ## cưỡi ngựa: người ngồi cao lên

var avatar: CharacterAvatar
var rider: Node3D            ## chứa các khe người (nâng lên khi cưỡi ngựa)
var slots := {}              ## tên khe -> Node3D
var _blocks := {}            ## tên khe -> MeshInstance3D (khối thử, ẩn khi đã gắn model)
var _models := {}            ## tên khe -> Node3D model đã gắn
var _res := {"helm": -99, "armor": -99, "weapon": -99, "horse": -99}
var _yaw := 0.0

static var _box := BoxMesh.new()
static var _mats := {}

func _init(p_avatar: CharacterAvatar = null) -> void:
	avatar = p_avatar
	rider = Node3D.new()
	rider.name = "Rider"
	add_child(rider)
	for part in GROUP_OF:
		var slot := Node3D.new()
		slot.name = part
		(self if GROUP_OF[part] == "horse" else rider).add_child(slot)
		slots[part] = slot
		var b := MeshInstance3D.new()
		b.mesh = _box
		b.position = BLOCKS[part][0]
		b.scale = BLOCKS[part][1]
		slot.add_child(b)
		_blocks[part] = b

## Gắn model cho 1 khe (null = bỏ, hiện lại khối thử). Model đặt gốc tại gốc nhân vật, mặt quay +Z.
func set_part_model(part: String, model: Node3D) -> void:
	if _models.has(part) and is_instance_valid(_models[part]):
		_models[part].queue_free()
	_models.erase(part)
	if model != null:
		slots[part].add_child(model)
		_models[part] = model
	_blocks[part].visible = model == null and _group_visible(GROUP_OF[part])

func _process(delta: float) -> void:
	if avatar == null or not is_instance_valid(avatar):
		return
	_sync_res()
	## Hướng 8 của avatar 2D (0 = xuống/+Z, theo chiều kim đồng hồ) -> góc quay quanh trục Y.
	var a := deg_to_rad(90.0 + 45.0 * avatar.direction)
	var target := atan2(cos(a), sin(a))
	_yaw = lerp_angle(_yaw, target, minf(1.0, delta * 14.0))
	rotation.y = _yaw
	rider.position.y = (RIDE_LIFT if avatar.is_riding() else 0.0) + avatar.get_height() * 0.01 / 0.866

func _sync_res() -> void:
	var data := AvatarData.get_for(avatar.gender)
	var now := {"helm": avatar.helm_res, "armor": avatar.armor_res, "weapon": avatar.weapon_res,
		"horse": avatar.horse_res if avatar.is_riding() else -1}
	for g in now:
		if now[g] == _res[g]:
			continue
		_res[g] = now[g]
		for part in GROUP_OF:
			if GROUP_OF[part] != g:
				continue
			var b: MeshInstance3D = _blocks[part]
			b.visible = not _models.has(part) and _group_visible(g, data)
			b.material_override = _mat(_color_for(part, int(now[g])))

## Tay không (mã vũ khí mặc định) thì không có khối vũ khí; không cưỡi thì không có ngựa. Vũ khí 1 tay chỉ hiện tay phải.
func _group_visible(g: String, data: AvatarData = null) -> bool:
	match g:
		"horse":
			return int(_res["horse"]) >= 0
		"weapon":
			if data == null:
				data = AvatarData.get_for(avatar.gender) if avatar != null else null
			return data != null and int(_res["weapon"]) >= 0 and int(_res["weapon"]) != data.default_res("weapon")
	return true

static func _color_for(part: String, res: int) -> Color:
	if part == "head":
		return Color(0.93, 0.76, 0.6)
	if part == "hair":
		return Color(0.12, 0.1, 0.1) if res <= 0 else Color.from_hsv(fposmod(res * 0.137, 1.0), 0.45, 0.45)
	if part == "left_weapon" or part == "right_weapon":
		return Color.from_hsv(fposmod(res * 0.091, 1.0), 0.25, 0.85)
	if part.begins_with("horse"):
		return Color.from_hsv(fposmod(res * 0.21 + 0.05, 1.0), 0.45, 0.55)
	## áo: màu theo mã hình áo, tay sáng hơn 1 chút
	var c := Color.from_hsv(fposmod(res * 0.173 + 0.58, 1.0), 0.6, 0.75)
	return c.lightened(0.15) if part.ends_with("hand") else c

static func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html(false)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]
