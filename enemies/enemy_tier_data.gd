extends Resource
class_name EnemyTierData
## Định nghĩa 1 LOẠI quái (VD "Quái Thường", "Sói Rừng Phía Bắc") — mỗi con quái thực chất là 1
## "người chơi" được cấu hình sẵn, CHÍNH XÁC theo cùng công thức CombatFormulas dùng cho Player
## (xem CombatantStats.from_enemy_tier()) — không phải hệ số rời rạc tự chế riêng cho quái.
##
## ĐÂY LÀ CHỈ SỐ GỐC (base) dùng chung mọi map — muốn CÙNG 1 loại quái mạnh/yếu khác nhau tuỳ map
## (VD "Sói Rừng" ở map dễ yếu hơn map khó), KHÔNG sửa file này, mà tạo 1 EnemySpawnEntry cho từng
## map với hệ số nhân riêng (xem stages/enemy_spawn_entry.gd) — giữ tier_name/enemy_scene/4 chỉ số
## gốc/drop TẠI ĐÂY làm "bản gốc" chung, còn độ mạnh + thời điểm/tần suất xuất hiện thì khai báo
## RIÊNG theo từng map trong EnemySpawnEntry.
##
## ĐỂ TẠO 1 CON QUÁI MỚI: chỉ cần tạo file .tres mới kế thừa script này trong Godot Editor (chuột
## phải thư mục enemies/data/ → New Resource → EnemyTierData), điền 4 chỉ số gốc + Level + Hệ Ngũ
## Hành + vài field hiển thị/gameplay bên dưới — KHÔNG cần sửa code. Muốn cân bằng lại toàn bộ quái
## cùng lúc (VD đổi công thức HP), chỉ sửa CombatFormulas/CombatantStats 1 chỗ, mọi quái tự động
## nhận giá trị mới vì đều tính lại từ 4 chỉ số gốc mỗi lần spawn.
##
## GẮN QUÁI VÀO MAP: tạo 1 EnemySpawnEntry trong StageData, gán `tier` = file EnemyTierData này —
## 1 quái có thể dùng lại ở nhiều map khác nhau (VD "Quái Thường" xuất hiện ở cả Màn 1 và Màn 2,
## mỗi map chỉnh độ mạnh riêng qua EnemySpawnEntry), không cần tạo bản sao EnemyTierData.

@export_group("Nhận diện")
## Tên hiển thị, VD "Quái Thường", "Sói Rừng Phía Bắc", "Boss Hắc Điểu"
@export var tier_name: String = ""
## Scene Enemy dùng cho tier này — mỗi tier có scene riêng, đã setup sẵn SpriteFrames/animation
## trong Editor (không cắt frame bằng code). Nhiều tier có thể DÙNG CHUNG 1 scene (chỉ khác chỉ số).
@export var enemy_scene: PackedScene
## Quái VLTK gốc (STT trong Npcs.txt, xem MonsterData) dùng làm HÌNH ẢNH cho tier này — đi/đứng/chết bằng sprite VLTK
## thay cho AnimatedSprite của scene. -1 = giữ hình cũ trong scene. Chỉ số/hành vi vẫn theo EnemyTierData.
@export var vltk_monster_id: int = -1

@export_group("4 chỉ số gốc — CHÍNH XÁC 100% VLTK, xem CombatantStats.from_enemy_tier()")
## Cấp của quái — ảnh hưởng HP/Mana theo đúng công thức VLTK (LifePerLevel × Level + ...).
@export var level: int = 1
## Hệ Ngũ Hành bản mệnh — quyết định tương khắc khi player dùng skill đúng/sai hệ (xem
## ElementTypes.BEATS) VÀ kháng cơ bản của chính quái này theo hệ (xem CombatantStats.ELEMENT_LEVEL_ADD).
@export var element: ElementTypes.ElementType = ElementTypes.ElementType.KIM
## Sức mạnh — quyết định Damage tay không/vũ khí (MinDamage=MaxDamage=Strength/5, xem
## CombatFormulas.calc_base_unarmed_damage). Quái đánh càng đau khi số này càng cao.
@export var strength: int = 35
## Nhanh nhẹn — quyết định CẢ AttackRating (quái đánh CÓ TRÚNG player không) LẪN Defense (player
## đánh quái NÀY có TRÚNG không) — đúng công thức VLTK gốc dùng chung 1 chỉ số cho cả 2 vai trò,
## xem CombatFormulas.calc_base_attack_rating/calc_base_defense. Dexterity < 32 → AttackRating âm
## → quái KHÔNG BAO GIỜ đánh trúng player (luôn Miss) — cẩn thận khi chỉnh số này xuống thấp.
@export var dexterity: int = 25
## Sinh khí — quyết định HP tối đa (Vitality × LifePerVitality theo hệ, xem ELEMENT_LEVEL_ADD).
@export var vitality: int = 25
## Nội công — quyết định Mana tối đa (ít ý nghĩa với quái thường vì quái chưa dùng skill tốn Mana,
## giữ lại để đúng "quái là 1 player" và sẵn sàng cho quái biết dùng skill sau này).
@export var energy: int = 15

@export_group("Scale theo cấp + thuộc tính thêm (dùng chung công thức với player)")
## Điểm cộng THÊM vào (Sức mạnh, Thân pháp, Sinh khí, Nội công) cho MỖI cấp vượt `level` gốc ở trên —
## scale quái chỉ cần tăng cấp (EnemySpawnEntry.level_add), không sửa từng chỉ số. Mặc định chia 5
## điểm/cấp giống điểm tiềm năng player (PlayerProfile.POTENTIAL_POINTS_PER_LEVEL).
@export var stat_growth_per_level: Vector4i = Vector4i(2, 1, 2, 0)
## Thuộc tính magic VLTK cố định — {tên: Vector3i(giá trị, 0, 0)}, VD {"fireres_p": (30,0,0)} = kháng
## Hỏa 30%, {"lifemax_p": (50,0,0)} = +50% máu. Bảng tên: MagicAttribTable.
@export var extra_attribs: Dictionary[String, Vector3i] = {}
## (Tuỳ chọn) quái thuộc 1 môn phái + cấp skill đã học -> skill NỘI TẠI cộng chỉ số y như player
## (VD quái "Đường Môn" có Tâm Nhãn cấp 10). Để trống nếu là quái thường.
@export var sect_id: String = ""
@export var skill_levels: Dictionary[String, int] = {}

@export_group("Gameplay ngoài combat")
@export var speed: float = 60.0
@export var scale_override: float = 1.0
## Sát thương quái gây khi CHẠM player trong gameplay "bắn sống sót" hiện tại (không roll trúng/né
## — chạm là dính, xem enemy.gd _on_hit_area_body_entered) — TÁCH BIỆT khỏi Strength/damage combat
## "thật" ở trên, vì thể loại bullet-heaven cần cảm giác khác PK 1-vs-1. Khi chuyển hẳn sang combat
## có roll trúng/né cho cả va chạm, field này có thể bỏ, dùng thẳng CombatFormulas.
@export var contact_damage: float = 10.0

@export_group("Phần thưởng khi chết")
@export var exp_drop: float = 1.0
@export var gem_texture: Texture2D
## Vật phẩm có thể rớt thêm khi quái chết (máu, nam châm...) — kéo PickupData vào đây. Mỗi vật
## phẩm tự có drop_chance riêng, có thể rớt 0, 1, hoặc nhiều loại cùng lúc (xem enemy.gd
## spawn_random_drops() — chỉ item ĐẦU TIÊN trúng trong danh sách được rớt, sắp xếp thứ tự ưu
## tiên hiếm/quý trước nếu muốn chúng được kiểm tra trước).
@export var possible_drops: Array[PickupData] = []
