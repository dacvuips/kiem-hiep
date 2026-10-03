# Hướng dẫn: thêm quái mới / thêm map mới

## Cấu trúc hệ thống

```
enemies/
  enemy.gd, Enemy.tscn, EliteEnemy.tscn   ← code + scene quái (dùng CHUNG cho mọi loại quái)
  enemy_tier_data.gd                       ← định nghĩa "1 loại quái" — CHỈ SỐ GỐC dùng chung mọi map
  data/                                    ← TOÀN BỘ file .tres quái (mỗi file = 1 loại quái)
    tier_normal.tres
    tier_elite.tres
    ...

stages/
  stage_data.gd                            ← định nghĩa field của "1 map"
  enemy_spawn_entry.gd                      ← gắn 1 EnemyTierData vào 1 map, kèm hệ số nhân RIÊNG
                                              cho map đó (để cùng 1 quái mạnh/yếu khác nhau tuỳ map)
  stage_01/                                ← MỖI MAP 1 THƯ MỤC RIÊNG
    stage_01.tres
  stage_02/
    stage_02.tres
    ...

systems/combat/
  combat_formulas.gd     ← công thức combat CHUNG (Attack/Defense/Damage/tương khắc Ngũ Hành)
  combatant_stats.gd      ← tính HP/AttackRating/Defense/Damage từ 4 chỉ số gốc — DÙNG CHUNG cho
                            Player VÀ Enemy (quái = 1 "player" cấu hình sẵn, không có công thức
                            riêng biệt nào cho quái)
```

**Nguyên tắc cốt lõi:** mỗi loại quái (`EnemyTierData`) chỉ cần khai báo **4 chỉ số gốc**
(Strength/Dexterity/Vitality/Energy) + Level + Hệ Ngũ Hành — y hệt cách khai báo 1 player.
HP/AttackRating/Defense/Damage KHÔNG nhập tay, mà tự động tính ra từ
`CombatantStats.from_enemy_tier()` bằng đúng công thức VLTK gốc dùng chung với Player. Muốn cân
bằng lại toàn bộ quái trong game (VD tăng HP mọi quái lên 20%), chỉ sửa 1 chỗ trong
`combatant_stats.gd`/`combat_formulas.gd`, KHÔNG cần sửa từng file quái.

**2 lớp dữ liệu tách biệt:**
- **`EnemyTierData`** = "bản gốc" của 1 loại quái (tên, hình dáng, 4 chỉ số gốc, phần thưởng) —
  dùng CHUNG cho mọi map nó xuất hiện.
- **`EnemySpawnEntry`** = cách 1 `EnemyTierData` xuất hiện Ở 1 MAP CỤ THỂ — hệ số NHÂN riêng
  (mạnh/yếu hơn bản gốc bao nhiêu %) + thời điểm/tần suất xuất hiện RIÊNG cho map đó. Đây là thứ
  thật sự nằm trong `StageData.enemy_tiers`, không phải `EnemyTierData` trực tiếp.

---

## Cách thêm 1 loại quái mới (bản gốc, dùng chung mọi map)

1. Trong Godot Editor, chuột phải thư mục `enemies/data/` → **New Resource** → chọn `EnemyTierData`.
2. Đặt tên file rõ ràng, VD `tier_soi_rung.tres`.
3. Điền các field (xem chú thích trong `enemy_tier_data.gd` để biết ý nghĩa từng field):
   - **Nhận diện**: `tier_name`, `enemy_scene` (kéo `Enemy.tscn` hoặc `EliteEnemy.tscn` vào, hoặc
     tạo scene quái mới nếu cần hình dáng khác).
   - **4 chỉ số gốc**: `strength`, `dexterity`, `vitality`, `energy`, `level`, `element` — đây là
     chỗ quyết định độ mạnh/yếu GỐC của quái (trước khi nhân theo map). Vitality cao → nhiều máu;
     Strength cao → đánh đau; Dexterity cao → đánh trúng player dễ hơn VÀ né đòn player giỏi hơn
     (2 vai trò cùng lúc, đúng công thức gốc — xem cảnh báo "Dexterity < 32 → luôn Miss" trong file).
   - **Gameplay ngoài combat**: `speed`, `contact_damage` (sát thương va chạm kiểu bullet-heaven
     hiện tại), `scale_override`.
   - **Phần thưởng**: `exp_drop`, `gem_texture`, `possible_drops` (kéo `PickupData` vào).
4. Xong — quái này giờ có thể gắn vào bất kỳ map nào qua `EnemySpawnEntry` (xem bên dưới).

## Cách gắn 1 quái vào 1 map (với độ mạnh riêng cho map đó)

Trong `StageData` của map, field `enemy_tiers` là mảng `EnemySpawnEntry` (không phải
`EnemyTierData` trực tiếp nữa). Mỗi entry:

1. Tạo 1 `EnemySpawnEntry` mới (trong Godot Editor: chuột phải → New Resource → `EnemySpawnEntry`,
   hoặc tạo trực tiếp như `SubResource` bên trong file `.tres` của map — xem `stage_01.tres` làm ví
   dụ nếu muốn viết tay).
2. Gán `tier` = kéo file `EnemyTierData` từ `enemies/data/` vào.
3. Để mặc định mọi hệ số nhân = `1.0` nếu muốn quái giữ ĐÚNG chỉ số gốc ở map này. Muốn map này
   quái mạnh/yếu hơn, chỉnh:
   - `strength_multiplier` — nhân vào Strength gốc (quái đánh đau hơn/ít hơn Ở MAP NÀY).
   - `dexterity_multiplier` — nhân vào Dexterity gốc (đánh trúng/né giỏi hơn Ở MAP NÀY).
   - `vitality_multiplier` — nhân vào Vitality gốc (nhiều máu hơn Ở MAP NÀY).
   - `energy_multiplier` — nhân vào Energy gốc.
   - `level_add` — cộng thêm vào Level gốc (map khó có thể cho quái cao level hơn vài bậc).
4. Điền thời điểm/tần suất RIÊNG cho map này: `unlock_time`, `spawn_weight`,
   `weight_change_per_second` — cùng 1 loại quái có thể xuất hiện sớm/muộn, nhiều/ít khác nhau
   hoàn toàn giữa các map, dù dùng chung 1 `EnemyTierData`.

**Ví dụ:** "Sói Rừng" (`tier_soi_rung.tres`, Vitality gốc = 20) xuất hiện ở:
- Map 1 (dễ): `EnemySpawnEntry` với `vitality_multiplier = 1.0` → Sói máu bình thường.
- Map 5 (khó): `EnemySpawnEntry` khác, CÙNG `tier = tier_soi_rung.tres`, nhưng
  `vitality_multiplier = 2.5`, `strength_multiplier = 1.8` → Sói máu trâu, đánh đau hơn hẳn — mà
  KHÔNG cần tạo file quái mới.

## Cách thêm 1 map mới

1. Tạo thư mục mới trong `stages/`, VD `stages/stage_02_rung_truc/`.
2. Trong thư mục đó, tạo Resource mới kiểu `StageData` (tương tự bước tạo quái ở trên).
3. Điền:
   - `stage_name`: tên hiển thị.
   - `world_scene`: scene world/map (background, vật cản, ranh giới) — tạo mới trong `world/` nếu
     map này có hình ảnh khác, hoặc dùng chung `world.tscn` nếu chỉ muốn đổi quái/tỉ lệ.
   - `enemy_tiers`: thêm các `EnemySpawnEntry` (xem mục trên) — CHỈ những loại quái xuất hiện ở
     map này, với độ mạnh/tần suất RIÊNG cho map này.
   - `boss_tier`: 1 `EnemySpawnEntry` cho quái boss cuối map (để trống nếu map này chưa có boss).
   - `stage_duration`: map kéo dài bao lâu (giây) trước khi boss xuất hiện.
4. Đăng ký map mới vào danh sách map chọn được — hiện tại xem
   `ui/character_hub/character_hub.gd` field `stages` (mảng `StageData`), thêm map mới vào đó.
   Người chơi chọn map qua nút "Chọn Ải" ở màn Hub (xem `ui/stage_select/stage_select_screen.gd`).

## Chỉnh sửa/cân bằng lại

- **Đổi chỉ số GỐC của 1 loại quái** (ảnh hưởng MỌI map nó xuất hiện): mở file `.tres` của nó
  trong `enemies/data/`, sửa 4 chỉ số gốc trực tiếp.
- **Đổi độ mạnh của 1 quái CHỈ Ở 1 MAP CỤ THỂ** (không ảnh hưởng map khác): mở `StageData` của map
  đó, tìm `EnemySpawnEntry` ứng với quái này, chỉnh các multiplier.
- **Đổi công thức chung cho MỌI quái + player** (VD thay đổi cách HP tính từ Vitality): sửa
  `systems/combat/combatant_stats.gd` (bảng `ELEMENT_LEVEL_ADD`) hoặc
  `systems/combat/combat_formulas.gd` (công thức AttackRating/Defense/Damage/roll trúng-né).
- **Xem nhanh chỉ số THẬT (đã áp multiplier) của từng quái ở từng map**: nhấn phím **F10** trong
  game (debug build) để mở màn liệt kê — mục "MAP" hiện HP/AttackRating/Defense đã tính sẵn cho
  từng `EnemySpawnEntry`, không cần tự nhân tay.

## Scale quái mạnh lên (không cần viết bảng riêng cho từng con)

Quái và player dùng **chung 1 đường tính chỉ số**: `CombatantBuild` (bản dựng) →
`CombatantStats.build()`. Muốn quái mạnh hơn, chỉnh bản dựng của nó bằng 1 trong các cách sau:

1. **Tăng cấp** (cách chính): trong `EnemySpawnEntry` của map, tăng `level_add`. Mỗi cấp tăng thêm
   cộng `stat_growth_per_level` của `EnemyTierData` vào (Sức mạnh, Thân pháp, Sinh khí, Nội công) —
   mặc định (2, 1, 2, 0) = 5 điểm/cấp giống điểm tiềm năng player. Máu/damage/chính xác tự tăng
   theo đúng công thức VLTK. VD Quái Thường +20 cấp: máu 300 → 700, damage 7 → 15.
2. **Hệ số map**: các `*_multiplier` trong `EnemySpawnEntry` nhân vào chỉ số SAU khi cộng tăng trưởng.
3. **Thuộc tính thêm** (`extra_attribs`, có ở cả `EnemyTierData` lẫn `EnemySpawnEntry`): khai báo
   `{tên thuộc tính VLTK: (giá trị, 0, 0)}` — VD `fireres_p = (30,0,0)` kháng Hỏa 30%,
   `lifemax_p = (50,0,0)` +50% máu, `addcolddamage_v`, `meleedamagereturn_p`... Bảng tên đầy đủ:
   `systems/combat/magic_attrib_table.gd` (cùng bảng dùng cho skill nội tại/buff/trang bị).
4. **Quái có môn phái**: gán `sect_id` + `skill_levels` trong `EnemyTierData` → skill NỘI TẠI đã
   "học" cộng chỉ số y như player (VD quái Đường Môn có Tâm Nhãn cấp 10). Quái chưa biết TỰ THI
   TRIỂN skill môn phái (chưa có AI ra chiêu).

## Người chơi khác khi online

Dùng đúng cơ chế trên: `PlayerProfile.to_build().to_dict()` gửi lên server, phía nhận dựng lại bằng
`CombatantStats.build(CombatantBuild.from_dict(data))` — ra chỉ số giống hệt (đã kiểm tra). Buff/bùa
đang dính nằm ở `StatusEffectController` của từng nhân vật, đưa vào `build()` qua
`get_state_attrib_sources()`. Mọi đòn nhận vào đi qua `HitResolver.receive()` (chung cho player,
quái, người chơi khác).

## Hạn chế đã biết (chưa hỗ trợ)

- Hệ thống rớt đồ (`PickupData`) mới chỉ có 2 loại (Hồi máu, Nam châm) — chưa có hệ Trang Bị/Vật
  Phẩm thật để quái rớt vũ khí/giáp.
- `contact_damage`/`speed`/`scale_override` (gameplay ngoài combat, kiểu bullet-heaven) vẫn lấy
  nguyên từ `EnemyTierData` gốc, CHƯA nhân theo map như 4 chỉ số gốc — nếu cần map có tốc độ/sát
  thương chạm khác nhau cho cùng 1 quái, báo lại để bổ sung multiplier tương ứng vào
  `EnemySpawnEntry`.
