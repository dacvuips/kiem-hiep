extends Resource
class_name ProjectileAuraEffect
## Hiệu ứng phụ chạy song song trong lúc Projectile đang bay (VD "tia sét tự động" quanh đường
## bay) — gắn qua Projectile.set_aura_effects(). Subclass ghi đè tick(). Skill môn phái hiện tại
## không dùng aura nào (SectSkillCast chỉ bắn thẳng), giữ lại làm điểm mở rộng cho skill phức tạp
## hơn sau này mà không cần sửa Projectile.

func tick(_projectile: Projectile, _delta: float) -> void:
	pass
