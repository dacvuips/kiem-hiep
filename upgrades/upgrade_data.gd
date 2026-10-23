extends Resource
class_name UpgradeData

enum StatType {
	PROJECTILE_COUNT,    ## Tương thích cũ
	DAMAGE,              ## Tăng % sát thương
	ATTACK_SPEED,        ## Tăng % tốc độ đánh
	RANGE,               ## Tăng % tầm xa
	MOVE_SPEED,          ## Tăng % tốc chạy (Lăng Ba Vi Bộ)
	HP_REGEN,            ## Hồi % máu tối đa mỗi giây (Dịch Cân Kinh)
	CRIT_CHANCE,         ## Tăng % tỉ lệ bạo kích (Bạo Kích Quyết)
	SHIELD,              ## Khiên chân khí hấp thụ sát thương (Kim Chung Tráo)
	PICKUP_RADIUS,       ## Bán kính hút ngọc / ngân lượng (Thâu Thiên Hoán Nhật)
	FREEZE_ON_HIT,       ## Đòn đánh làm chậm quái (Băng Sương Toái Kích)
	STUN_ON_HIT,         ## Đòn đánh gây choáng (Lôi Đình Tê Liệt)
	POISON_ON_HIT,       ## Độc sát rút máu theo thời gian (Vạn Độc Xâm Cốt)
	EXPLODE_ON_KILL,     ## Quái chết phát nổ lan sát thương (Liệt Hỏa Bộc Phá)
	EMERGENCY_HEAL,      ## Cứu nguy khẩn cấp: hồi 50% HP + đẩy lùi quái
}

enum Rarity {
	COMMON,      ## Phổ thông (Lục)
	RARE,        ## Tinh anh (Lam)
	EPIC,        ## Sử thi (Tím)
	LEGENDARY,   ## Hoàng Kim (Vàng)
}

## ID duy nhất để tránh trùng/nhận diện — VD "damage_up", "double_shot"
@export var id: String = ""

@export var title: String = ""
@export var description: String = ""
@export var icon: Texture2D

@export var stat_type: StatType = StatType.DAMAGE

## Giá trị cộng thêm (% hoặc số thực)
@export var value: float = 0.0

## Nếu true, nâng cấp này chỉ xuất hiện 1 lần rồi biến mất khỏi vòng chọn
@export var is_unique: bool = false

## Phẩm chất nâng cấp
@export var rarity: Rarity = Rarity.COMMON
