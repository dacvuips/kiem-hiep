# Trang bị VLTK gốc — tham chiếu từ source & dữ liệu server

Tổng hợp từ mã nguồn C++ (`Sources/Core/Src`: `GameDataDef.h`, `KItem.h/.cpp`, `KItemList.cpp`,
`KItemGenerator.CPP`, `KPlayer.cpp`, `KNpcAttribModify.cpp`, `KMagicAttrib.h`) và dữ liệu server
(`server/settings/item/*.txt`, mã TCVN5712-1; dòng tiêu đề mã GBK). Đường dẫn gốc: xem memory
`reference_vltk_cpp_lua_source`.

---

## 1. Ô trang bị (`enum ITEM_PART`) — 17 ô

| # | Ô | # | Ô |
|---|---|---|---|
| 0 | Đầu (mũ) | 9 | Ngọc bội (pendant) |
| 1 | Thân (áo) | 10 | Ngựa |
| 2 | Thắt lưng | 11 | Mặt nạ |
| 3 | Vũ khí | 12 | Phi phong (mantle) |
| 4 | Giày | 13 | Ấn (signet) |
| 5 | Bao tay (cuff) | 14 | Trang sức (shipin) |
| 6 | Dây chuyền (amulet) | 15 | Mũ trùm (hoods) |
| 7 | Nhẫn 1 | 16 | Áo choàng (cloak) |
| 8 | Nhẫn 2 | | |

Ô 0–9 là 10 món "chính" (tham gia kích hoạt ngũ hành, mục 6). Ô 10–16 (ngựa trở đi) **luôn mở hết**
thuộc tính ẩn.

## 2. Phân loại đồ

- **Loại vật phẩm** (`ITEMGENRE`): 0 trang bị, 1 thuốc, 2 sự kiện, 3 nguyên liệu, 4 nhiệm vụ, 5 thổ địa
  phù (về thành), 6 bí kíp (magic script).
- **Loại trang bị chi tiết** (`EQUIPDETAILTYPE`): 0 vũ khí cận chiến, 1 vũ khí tầm xa (ám khí), 2 áo,
  3 nhẫn, 4 dây chuyền, 5 giày, 6 thắt lưng, 7 mũ, 8 bao tay, 9 ngọc bội, 10 ngựa, 11 mặt nạ, 12 phi
  phong, 13 ấn, 14 trang sức, 15 mũ trùm, 16 áo choàng.
- **Loại cụ thể** của vũ khí (`ParticularType`):
  - Cận chiến: 0 Kiếm, 1 Đao, 2 Côn, 3 Thương, 4 Chùy, 5 Song đao (Nga Mi Thích), 6 Triền thủ (tay).
  - Tầm xa: 0 Phi tiêu, 1 Phi đao, 2 Tụ tiễn (nỏ).
- **Phẩm chất** (`EQUIPLEVEL` / `EQUIPNATURE`): thường → magic (xanh) → … → tím (violet) → **hoàng kim
  (gold)** → **bạch kim (platina)**.
- **Cấp đồ**: 1–10 (`MAX_ITEM_LEVEL`). Mỗi loại cụ thể có đúng 10 cấp: dòng trong bảng =
  `loại cụ thể × 10 + cấp − 1` (`Gen_Equipment`).

Số dòng dữ liệu: vũ khí cận chiến 70, tầm xa 30, áo 290, mũ 140, giày 40, thắt lưng/bao tay/dây
chuyền/ngọc bội 20 mỗi loại, nhẫn 9, ngựa 330, mặt nạ 839, hoàng kim 5628, bạch kim 4365 (2 bảng cuối
nhiều dòng do server tư nhân thêm).

## 3. Cấu trúc 1 món đồ (`KItem`)

Bảng `meleeweapon.txt`, `armor.txt`... (cột theo thứ tự):
`Tên | Loại | Loại chi tiết | Loại cụ thể | Ảnh | Vật thể rơi | Rộng | Cao | Mô tả | Ngũ hành | Giá |
Cấp | 7 × (mã thuộc tính gốc, min, max) | 6 × (mã yêu cầu, giá trị)`

- **7 thuộc tính gốc** (`m_aryBaseAttrib`) — cố định theo loại đồ, VD:
  - Vũ khí: `weapondamagemin_v` (28), `weapondamagemax_v` (29), `durability_v` (31), có khi
    `attackratingenhance_p` (167).
  - Áo/mũ/...: `armordefense_v` (30) = phòng thủ, `durability_v` (31) = độ bền.
- **6 yêu cầu** (`m_aryRequireAttrib`): `requirelevel` (36) cấp nhân vật, `requirestr` (32) Sức mạnh,
  `requiredex` (33) Thân pháp, `requirevit` (34), `requireeng` (35), `requireseries` (37) ngũ hành,
  `requiresex` (38) giới tính, `requiremenpai` (39) môn phái. `requirementreduce_p` (42) giảm % yêu cầu.
- **Tối đa 8 dòng thuộc tính magic** (`m_aryMagicAttrib`, `MAX_ITEM_MAGICATTRIB = 8`), xem mục 5–6.
- Ngũ hành của món đồ (`nSeries`), độ bền hiện tại, giá, bộ (`nGroup`, `nSetID`), số món cần để kích
  hoạt bộ (`nNeedToActive1/2`), cấp cường hoá (`nUpgradeLvl`)...

Ví dụ: **Thiết Trủy thủ** (Kiếm cấp 1): damage 4–7, độ bền 20, yêu cầu Sức mạnh 20. **Sa Di phục**
(áo cấp 1): phòng thủ 50, độ bền 15, yêu cầu cấp 1, Sức mạnh 30, nam.

## 4. Trang bị cộng chỉ số thế nào

- **Mọi thuộc tính** (gốc + magic) đi qua `KNpc::ModifyAttrib` → bảng `KNpcAttribModify::ProcessFunc`
  — **cùng bảng với buff/nội tại**. Game này đã có bảng tương đương: `systems/combat/magic_attrib_table.gd`.
- **Damage vật lý khi cầm vũ khí** (`KItemList::GetWeaponDamage` + `KPlayer::SetNpcPhysicsDamage`):
  ```
  vũ khí = (damage gốc min/max + dòng weapondamagemin/max_v) × (100% + weapondamageenhance_p%)
  cận chiến: + Sức mạnh / 5      tầm xa (ám khí): + Thân pháp / 5      tay không: Sức mạnh / 5
  ```
  Kết quả là `m_PhysicsDamage` — chính là phần "damage tay không/vũ khí" mà skill ngoại công nhân
  `physicsenhance_p` (game đang thiếu phần vũ khí này, nên skill ngoại công yếu).
- `weapondamage*`/`weapondamageenhance_p` chỉ tính trong `GetWeaponDamage`, không có trong `ProcessFunc`.

## 5. Thuộc tính magic ngẫu nhiên (đồ xanh)

Bảng `magicattriblevel.txt` (480 dòng, tên tiếng Việt) / `magicattrib.txt`: mỗi dòng là 1 tiền tố hoặc
hậu tố ở 1 cấp (1–10): `Tên | Tiền tố? | Ngũ hành yêu cầu | Cấp | Mã thuộc tính | min/max × 3 | tỷ lệ
rơi cho từng loại đồ (Kiếm, Đao, Côn, Thương, Chùy, Song đao, Tay, Phi tiêu, Phi đao, Nỏ, Áo, Nhẫn, Dây
chuyền, Bùa, Giày, Thắt lưng, Mũ, Bao tay, Túi thơm, Ngọc bội) | tỷ lệ theo ngũ hành`.

- **Tiền tố** (không phụ thuộc ngũ hành) — VD: Tăng hiệu quả sát thương (`addphysicsdamage_p` 5→100%,
  chỉ vũ khí), Tăng chính xác, Tăng tốc độ công kích, Bỏ qua phòng thủ, Tăng Sinh lực/Nội lực/Thể lực
  (5→200), Hồi phục Sinh lực, Tăng tốc độ chạy (giày, 10→40%), Phản đòn vật lý (áo), Hút sinh lực/nội
  lực (vũ khí, 1→10%), Kháng tất cả, Không thể phá huỷ...
- **Hậu tố** (gắn ngũ hành, 0 Kim 1 Mộc 2 Thủy 3 Hỏa 4 Thổ) — VD: Sức mạnh (Kim), Độc sát + kháng độc
  (Mộc), Băng sát + Sinh khí + chống choáng (Thủy), Hỏa sát + Thân pháp + giảm đóng băng (Hỏa), Lôi sát
  + kháng băng + giảm trúng độc (Thổ), Tăng sát thương theo hệ (`metalskill_v`...), tăng cấp kỹ năng
  theo hệ, May mắn...

**Cách sinh** (`KItemGenerator::Gen_MagicAttrib`):
1. Mỗi ô dòng i có 1 "cấp magic" (do nguồn rơi đồ quyết định). **Ô chẵn = tiền tố, ô lẻ = hậu tố**
   (hậu tố phải khớp ngũ hành món đồ).
2. Ngưỡng `= ngẫu_nhiên(0..99) / (1 + may_mắn × 20 / 100)` — **may mắn càng cao ngưỡng càng thấp**, thuộc
   tính hiếm lọt qua dễ hơn.
3. Lấy mọi thuộc tính có tỷ lệ rơi **cho đúng loại đồ** > ngưỡng và chưa trùng loại với dòng trước →
   chọn ngẫu nhiên 1 → giá trị ngẫu nhiên trong [min, max].
4. Đồ lưu `uRandomSeed` + cấp từng dòng + may mắn → client tái tạo đúng y hệt (deterministic, hợp online).

Server tư nhân này (script `script/global/droprate/*.lua`, tác giả Kinnox 2020) **ghi đè** bảng gốc
bằng danh sách "dòng hiện" (`KindOption_Show`: Sinh lực, Nội lực, kháng tất cả, tốc chạy, tốc đánh, hút
máu, % sát thương ngoại công, chính xác...) và "dòng ẩn" (`KindOption_Hide`: kháng từng hệ, giảm thời
gian choáng/chậm/độc, Sức mạnh/Thân pháp/Sinh khí, may mắn, sát thương ngoại công điểm...) theo cấp 1–10.

## 6. Kích hoạt thuộc tính ẩn bằng NGŨ HÀNH (`KItemList::GetEquipEnhance`)

`KItem::ApplyMagicAttribToNPC`: dòng **1, 3, 5 luôn có hiệu lực**; dòng **2, 4, 6 là ẩn**, chỉ bật lần
lượt theo số kích hoạt `nActive` (0–3); dòng 7, 8 là mở rộng (hoàng kim, mục 7).

Số kích hoạt của món ở ô X:
- **+1** nếu ngũ hành **nhân vật tương sinh** ngũ hành món đồ (`g_IsAccrue`).
- **+1** cho mỗi món ở 2 ô "kích hoạt" ô X (bảng `ms_ActivedEquip`) có ngũ hành tương sinh món đồ X:

| Ô X | Được kích hoạt bởi | Ô X | Được kích hoạt bởi |
|---|---|---|---|
| Mũ | Áo, Dây chuyền | Bao tay | Giày, Nhẫn 1 |
| Áo | Nhẫn 2, Thắt lưng | Dây chuyền | Thắt lưng, Nhẫn 2 |
| Thắt lưng | Ngọc bội, Bao tay | Nhẫn 1 | Vũ khí, Mũ |
| Vũ khí | Dây chuyền, Áo | Nhẫn 2 | Bao tay, Ngọc bội |
| Giày | Vũ khí, Mũ | Ngọc bội | Giày, Nhẫn 1 |

- Ô ngựa trở đi, hoặc đủ điều kiện bộ (`IsEnoughToActive`) → mở hết (4 dòng).
- Vì vậy chọn đồ đúng ngũ hành theo vòng tương sinh là cốt lõi của trang bị VLTK.

## 7. Hoàng kim (bộ) & bạch kim

- `GoldEquip.txt`: thuộc tính gốc + yêu cầu như đồ thường, **6 dòng magic cố định** (`DefMagic1–6` trỏ
  vào `magicattrib_ge.txt`), **bộ** (`Group`, `SetId`), `NeedToActive1/2`, 2 dòng mở rộng.
- Dòng mở rộng (7–8) bật theo `số món cùng Group đang mặc / NeedToActive1` (`GetGoldEquipEnhance`;
  2 nhẫn cùng bộ chỉ tính 1).
- VD bộ **Mộng Long** (Thiếu Lâm): Tăng Mão, Cà Sa, Phát Đái... yêu cầu cấp 90+, Sức mạnh 135–260, môn
  phái Thiếu Lâm, bộ 5 món.
- Bạch kim (`platinaequip.txt`, `platina_magicattr.txt`, `platina_magicrate.txt`,
  `platina_durability.txt`): tầng trên hoàng kim, có độ bền và tỷ lệ magic riêng.

## 8. Độ bền & sửa chữa (`AbradeRate.ini`, `KItem::Abrade`)

- Mỗi lần **đánh**: vũ khí có xác suất **1/768** mất 1 độ bền. Mỗi lần **bị đánh**: mũ, áo, thắt lưng,
  bao tay xác suất **1/960** mất 1. Một số hiệu ứng trừ theo % độ bền tối đa.
- Sửa đồ: giá theo hệ số `ItemPriceScale 50`, `MagicPriceScale 16`, `GoldPriceScale 30`,
  `PlatinaPriceScale 30`; cảnh báo khi độ bền dưới 10. Thuộc tính `indestructible_b` = không hỏng.

## 9. Đã áp dụng vào game

- Dữ liệu: `tools/import_vltk_items.py` -> `data/items/equipment.json` (660 đồ gốc, 10 loại) +
  `data/items/magic_attribs.json` (305 tiền/hậu tố); đọc qua `systems/items/item_database.gd`.
- `systems/items/item_instance.gd` (1 món đồ, to_dict/from_dict), `item_generator.gd` (mục 5),
  `equipment.gd` (ô đeo, yêu cầu, kích hoạt ngũ hành mục 6, damage vũ khí mục 4).
- `PlayerProfile.inventory/equipment` (lưu save), `CombatantBuild.equipment` -> `CombatantStats.build()`.
- UI: ô trang bị + nút Hành trang trong `CharacterStatusScreen.tscn`, `ui/items/*`; nút "+1/+10 đồ"
  trong bảng TEST.
- CHƯA làm: ô phụ (ngựa, mặt nạ, phi phong...), hoàng kim/bạch kim, độ bền/sửa đồ, rơi đồ từ quái,
  cửa hàng, cường hoá/khảm.

## 10. Gợi ý áp dụng tiếp

1. Dữ liệu đồ: nhập `meleeweapon/rangeweapon/armor/...txt` thành Resource (giống
   `tools/import_vltk_hit_effects.py`), thuộc tính dùng **tên VLTK** để đi thẳng vào
   `MagicAttribTable` (đã có) qua `CombatantBuild.extra_attribs` — không cần bảng mới.
2. Thêm `GetWeaponDamage` vào `CombatantStats.build()`: damage vũ khí + Sức mạnh/5 (cận chiến) hoặc
   Thân pháp/5 (tầm xa) — sửa luôn vấn đề skill ngoại công yếu hơn nội công.
3. Kích hoạt ẩn theo ngũ hành (mục 6) và bộ hoàng kim (mục 7) tính trong `PlayerProfile.to_build()`.
4. Sinh đồ ngẫu nhiên dùng seed (mục 5.4) để server/client cho cùng kết quả khi online.
