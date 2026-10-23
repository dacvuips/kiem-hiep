extends Node

## Đăng ký hiệu ứng ở đây — key là tên gọi khi play(), value là scene VFX tương ứng.
## Muốn thêm hiệu ứng mới, chỉ cần thêm 1 dòng vào đây, không cần sửa nơi nào khác gọi VfxManager.
const EFFECTS := {
	"hit": preload("res://vfx/HitExplosion.tscn"),
	"hit_explosion": preload("res://vfx/HitExplosion.tscn"),
	"enemy_death": preload("res://vfx/BandDie.tscn"),
}

## Scene VFX dạng "tia nối 2 điểm" — tách riêng khỏi EFFECTS (hiệu ứng tại 1 điểm) vì cần
## setup(from, to) thay vì chỉ global_position. Tái dùng cho mọi hiệu ứng dạng chuỗi/tia sau
## này (LightningAuraEffect, chain lightning, dây xích...), chỉ cần đổi màu qua tham số color.
const BeamScene := preload("res://vfx/LightningBeam.tscn")

func play(effect_name: String, world_position: Vector2, parent: Node = null) -> void:
	if not EFFECTS.has(effect_name):
		push_warning("VfxManager: hiệu ứng '%s' chưa được đăng ký." % effect_name)
		return

	var scene: PackedScene = EFFECTS[effect_name]
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var target_parent := parent if parent else (tree.current_scene if tree else null)
	if target_parent == null:
		return
	var effect: Node2D = ObjectPool.acquire(scene, target_parent)
	effect.global_position = world_position

## Vẽ 1 tia sáng nối 2 điểm world-space, tự fade và release. effect_name hiện chỉ ảnh hưởng
## màu mặc định (mở rộng thêm màu riêng theo tên khi cần nhiều biến thể "tia" khác nhau).
func play_beam(from: Vector2, to: Vector2, _effect_name: String = "lightning", parent: Node = null) -> void:
	var target_parent := parent if parent else get_tree().current_scene
	var beam: LightningBeam = ObjectPool.acquire(BeamScene, target_parent)
	beam.setup(from, to)
