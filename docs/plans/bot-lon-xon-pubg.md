# Bot chơi cùng người thật — "Lộn Xộn" và "PUBG" (online)

Bot do **server thế giới** điều khiển, vào host Lộn Xộn / trận PUBG như một người chơi: có tên, môn phái, trang bị, máu, đi lại,
đánh quái, PK, nhặt đồ, chết / hồi sinh theo luật của màn. Người chơi thật thấy bot như người khác (RemotePlayer), không cần sửa máy người chơi.

## 1. Hiện trạng & điều phải làm mới

| Có sẵn | Thiếu cho bot online |
|---|---|
| `PkBot` (systems/pk) — bot PK **offline**, chạy trên máy người chơi bằng bộ máy chiêu thật | Không dùng được online: server không có node / bộ máy chiêu |
| Quái server (`ServerMonster`): đi trên `MapGrid`, chọn mục tiêu, báo `S_MATTACK` | Quái chỉ nhắm **kết nối** người thật (`gs.nearest_player`) |
| PvP online: máy người đánh tính đòn → `C_PVP_HIT` → server cắt trần → `S_PVP_HIT` → máy bị đánh tự trừ máu | Bot không có máy → **server phải tự tính đòn đánh vào bot** và **tự giữ máu bot** |
| Lộn Xộn / PUBG server: hồ sơ tạm, chết, rơi đồ, Lệnh Bài, vòng bo (seed) | Hook cho thực thể không phải `Conn` |

## 2. Kiến trúc

```
LonXonServer / PubgServer ── BotDirector (mỗi host / trận) ── ServerBot × N
                                   │  thêm / bớt bot theo số người thật          │ ServerEntity KIND_PLAYER (AOI như người)
                                   └── tick 5 lần/giây: Brain.think(bot)         │ PlayerProfile tạm + CombatantStats
                                                                                 │ hp / mana / thuốc / hồi chiêu
Đòn của người thật vào bot:  C_PVP_HIT(eid bot) → RelationServer → BotCombat.resolve(hit, bot) → trừ máu bot
Đòn của bot vào người thật:  BotCombat.encode(bot) → S_PVP_HIT tới máy người đó (máy họ tự né / kháng như PvP thường)
Đòn của bot vào quái:        ServerMonster.receive_damage (như C_DAMAGE)        Bot vào bot: BotCombat.resolve cả 2 phía
Hình ảnh ra chiêu:           S_CAST tới người đang thấy bot (như người thật ra chiêu)
```

- `net/server/bots/server_bot.gd` — thực thể + thân: di chuyển (tốc độ = người chơi, có ngựa), tìm đường trên `MapGrid`
  (dùng lại cách đi của `ServerMonster`), máu / nội lực / thuốc, ra chiêu (chọn đòn chính + 1–2 chiêu phụ theo phái, hồi chiêu
  như `PkBot`), nhặt đồ (`gs` nhặt hộ như `_on_pickup`).
- `net/server/bots/bot_combat.gd` — tính đòn **trên server** bằng đúng `CombatFormulas` / `HitResolver` (chính xác, né, kháng, giáp).
- `net/server/bots/bot_brain_lonxon.gd`, `bot_brain_pubg.gd` — kịch bản hành vi (mục 3, 4), thuần logic → test được bằng GameServer giả.
- `net/server/bots/bot_director.gd` — thêm / bớt bot, tên, phái, tính cách, độ khó.

## 2b. Bộ não chiến đấu chung — bot "như người thật"

Dùng chung cho cả 2 màn (`net/server/bots/bot_combat_brain.gd`). Kịch bản Lộn Xộn / PUBG (mục 3, 4) quyết định *đánh ai, đi đâu*;
phần này quyết định *đánh thế nào*: chạy, né, bay, bơm máu, đòn đánh, bùa — sao cho trông như một người đang cầm chuột.

### A. Giác quan (không "hack")
- Chỉ thấy những gì một người thấy trên màn hình: thực thể trong tầm nhìn AOI; người khuất tầm thì nhớ vị trí cuối 6 giây rồi quên.
- Biết đòn sắp tới **qua tin ra chiêu thật** (S_CAST: ai, chiêu gì, nhắm ai / hướng nào) giống người thấy hoạt ảnh ra chiêu — không đọc trước.
- **Phản xạ trễ** 0,18–0,45 giây (theo độ khó) giữa "thấy" và "làm".
- Chú ý có hạn: 1 mục tiêu chính + để ý 2–3 mối nguy gần nhất.

### B. Bộ chiêu — tự phân loại từ dữ liệu skill của phái lúc tạo bot
| Nhóm | Nhận biết (SkillDefinition) | Cách dùng |
|---|---|---|
| Đòn chính | `is_main_attack`, đạn thẳng / cận chiến | Dồn sát thương, đánh liên tục khi trong tầm |
| Đòn vùng | dạng đạn toả / vòng / vùng (`vltk_missle_form` 2, 3, 5), đạn có vùng nổ | Khi ≥ 3 địch / quái đứng cụm trong vùng; mở màn vào đám đông |
| Khống chế | thuộc tính trạng thái làm chậm / choáng / đóng băng / bất động (`vltk_attribs`) | Mở giao tranh hoặc giữ chân kẻ đang chạy trốn, rồi dồn đòn |
| **Bùa lên địch** | `target_enemy`, có trạng thái + thời gian, ít / không sát thương | Thả lên mục tiêu **trước khi** dồn sát thương; làm mới khi còn < 2 giây |
| **Buff bản thân / đồng đội** | `target_self` / `target_ally`, có thời gian hiệu lực | Luôn duy trì; buff đủ **trước** khi lao vào; làm mới khi còn < 3 giây; PUBG buff cả đồng đội |
| Hào quang | `is_aura` | Bật ngay khi vào trận / hồi sinh |
| Hồi máu | thuộc tính hồi sinh lực | Bản thân máu thấp, hoặc đồng đội (PUBG) |

**Combo 1 lần giao tranh:** buff đủ → (nhảy) áp sát / vào tầm → bùa lên mục tiêu → khống chế → dồn đòn chính (đòn vùng nếu cụm)
→ mục tiêu chạy: khống chế / nhảy chặn đầu → kết liễu. Nội lực < 25% thì uống thuốc nội lực, không phí chiêu tốn nội lực.
Tôn trọng hồi chiêu, giãn cách ra chiêu và khoá động tác như người chơi (`reference_vltk_cast_timing`).

### C. Chạy — giữ khoảng cách như người
- **Phái cận chiến:** áp sát rồi **vòng quanh** mục tiêu (không đứng thẳng hàng để tránh đòn đường thẳng), lùi nửa bước khi đối phương ra đòn mạnh.
- **Phái đánh xa:** **thả diều** — giữ 70–90% tầm chiêu, địch áp sát thì lùi / chạy chéo rồi quay lại đánh.
- Trong giao tranh không đứng yên quá ~1,2 giây; bước ngắn đổi hướng ngẫu nhiên.
- Biết lợi dụng vật cản che đạn, không chạy vào góc cụt, tránh mép khung / ngoài bo.
- Đường đi hơi cong, không thẳng tắp như máy.

### D. Né đòn
| Đòn của đối phương | Bot làm |
|---|---|
| Đạn thẳng nhắm mình | bước **vuông góc** hướng bay, đủ ra khỏi bề rộng đạn |
| Đòn nổ tại mục tiêu / vùng | chạy ra khỏi bán kính trước lúc nổ (nếu kịp theo thời gian ra chiêu) |
| Đòn cận chiến | lùi / vòng sang bên, hoặc nhảy qua |
| Bị khống chế sắp hết | chuẩn bị nhảy / chạy ngay khi hết hiệu ứng |

Tỉ lệ né theo độ khó (Dễ ~20%, Thường ~50%, Khó ~80%) — **không né 100%**, để vẫn bị trúng như người thật.

### E. Bay (nhảy / khinh công)
- **Áp sát:** kẻ địch đang chạy, cách 200–450px → nhảy thẳng tới chặn đầu.
- **Thoát thân:** máu thấp + bị áp sát → nhảy ngược hướng, ưu tiên **qua vật cản nhảy được** (ô `is_jumpable`: rào, tường thấp, rạch nhỏ) để cắt đuôi.
- **Né:** nhảy ngang khỏi đòn vùng lớn sắp nổ.
- **Vượt địa hình:** đường bị chặn mà bên kia gần → nhảy qua thay vì đi vòng.
- Có hồi nhảy, chỉ nhảy khi có lý do (người thật không nhảy loạn). Server phát cờ `FLAG_JUMPING` + độ cao như gói di chuyển người
  chơi -> người thật thấy bot bay đúng hoạt ảnh nhảy.

### F. Bơm máu / thuốc
- Đang giao tranh: máu < 55% → uống (thuốc hồi dần nên uống sớm khi bị dồn); lúc rảnh: < 75%.
- Không uống chồng khi hiệu ứng thuốc còn chạy (trừ lúc nguy); giữ 2 bình cuối cho lúc nguy kịch.
- Nội lực < 25% → thuốc nội lực; trúng độc → thuốc giải (nếu có).
- Rảnh, không địch gần → **ngồi thiền hồi** như người thật.

### G. Quyết định đánh / rút
- **Điểm lợi thế** = (máu còn × sát thương ước tính / giây) của mình (+ đồng đội gần) so với địch → đánh tiếp / giằng co / rút.
- **Kẻ thứ ba:** 2 người đang đánh nhau → chờ 1 bên yếu máu rồi lao vào kết liễu (Lộn Xộn: cướp Lệnh Bài).
- Không đuổi theo vào chỗ đông địch; đuổi quá 8 giây không trúng thì bỏ.
- **Đội (PUBG):** cùng nhắm 1 mục tiêu, quay lại cứu đồng đội đang bị đánh, rút cùng nhau.

### H. Chất "người" — tránh trông như máy
- Trễ phản xạ ngẫu nhiên, thỉnh thoảng "phân tâm" 0,5–1,5 giây.
- Ngắm lệch vài độ (giảm dần ở độ khó cao); giới hạn 3–6 thao tác / giây.
- Lúc rảnh: đứng nhìn quanh, đổi hướng, ngồi, đi lòng vòng, lên / xuống ngựa, đứng chỉnh đồ (dừng vài giây sau khi nhặt đồ).
- Thỉnh thoảng sai như người: phí 1 chiêu, đuổi nhầm hướng, uống thuốc chậm (ít hơn ở độ khó Khó).
- Mỗi bot 1 "tay": tốc độ phản xạ, kiểu di chuyển, chiêu ưa dùng hơi khác nhau, giữ suốt trận.

### Độ khó
| | Dễ | Thường | Khó |
|---|---|---|---|
| Phản xạ | 0,35–0,6 giây | 0,25–0,45 giây | 0,15–0,3 giây |
| Né đạn thẳng | 20% | 50% | 80% |
| Dùng bùa / khống chế | ít | theo combo | đúng lúc, giữ khống chế cho lúc địch chạy |
| Nhảy chiến thuật | hiếm | có | thường xuyên, chặn đầu / cắt đuôi |
| Thả diều / vòng quanh | không | có | tốt |
| Sai sót | nhiều | vừa | hiếm |

### Việc server phải thêm cho phần này
- Báo cho bộ não bot các **tin ra chiêu** quanh bot (chỗ GameServer chuyển S_CAST) để né.
- **Trạng thái trên bot** (buff / bùa / khống chế): server áp vào chỉ số bot và đếm thời gian; bùa của bot lên người thật đi qua
  `PvpHit` (đã mang HitModifiers) như người đánh người.
- Di chuyển bot có nhảy: kiểm tra `grid.is_jumpable` như khi kiểm gói di chuyển của người chơi.

## 3. Kịch bản bot — LỘN XỘN

**Vào host:** cấp 50 (`LonXonRules.apply_start`), chọn thẻ 5x hợp phái (vũ khí đúng loại phái, ngựa ngẫu nhiên), tự cộng điểm tiềm năng
theo hướng phái (sức / thân / ngoại / nội như build mặc định).

**Ưu tiên mỗi lượt suy nghĩ (5 lần/giây), trên xuống:**

| # | Trạng thái | Khi nào | Làm gì |
|---|---|---|---|
| 1 | CHẾT | đã bị hạ | chờ 5 giây → hồi sinh → chọn lại thẻ 5x |
| 2 | UỐNG THUỐC | máu < 50%, còn thuốc, hết hồi thuốc | uống (trễ phản xạ 0,3–0,8 giây theo độ khó) |
| 3 | CHẠY TRỐN | máu < 25% và không còn thuốc, hoặc đối thủ mạnh hơn hẳn (cấp hơn ≥ 30 / Lệnh Bài nhiều hơn ≥ 5) | chạy ngược hướng địch, ưu tiên về phía quái để đánh hồi máu… rồi quay lại FARM |
| 4 | NHẶT LỆNH BÀI | thấy Lệnh Bài trong 600px | chạy tới nhặt (kể cả đang đánh nhau nếu gần hơn địch) |
| 5 | SĂN NGƯỜI | có người / bot trong tầm nhìn và *đáng đánh*: máu họ < 40%, hoặc cấp mình ≥ cấp họ − 10, hoặc họ giữ ≥ 3 Lệnh Bài (top bảng) | đuổi + ra chiêu; mất dấu > 8 giây thì bỏ |
| 6 | NHẶT ĐỒ | có đồ rơi trong 300px tốt hơn đồ đang mặc (cấp / số dòng / Hoàng Kim) hoặc thuốc khi < 10 bình | nhặt, tự mặc nếu tốt hơn |
| 7 | ĐÁNH QUÁI | còn dưới cấp 200 | quái gần nhất trong 900px → đánh (mỗi con +5 cấp) |
| 8 | ĐI TUẦN | không có gì làm | đi tới 1 điểm ngẫu nhiên trong khung, tránh xa mép khung |

**Tính cách** (mỗi bot 1 kiểu, đổi trọng số mục 5–7): *Hiếu chiến* (săn người sớm, ít trốn) · *Cày cấp* (đánh quái tới ~120 mới săn) ·
*Nhặt nhạnh* (ưu tiên đồ / Lệnh Bài, tránh đánh nhau).
**Độ khó:** Dễ / Thường / Khó = trễ phản xạ, tỉ lệ né đòn kỹ năng (chạy ngang), chọn chiêu tối ưu.
**Số bot:** giữ mỗi host có ít nhất `LONXON_BOTS` (mặc định 8) người + bot; người thật vào thì bớt bot (bot rời như thoát — rớt đồ,
Lệnh Bài như luật); host đầy 50 thì không thêm bot. Bot có Lệnh Bài vẫn lên bảng Top 5 và có số hạng trên đầu.

## 4. Kịch bản bot — PUBG

**Ghép trận:** trận chờ quá thời gian tìm mà chưa đủ người → thêm bot (theo đội đúng kiểu Solo / Duo / Trio / Squad) tới
`PUBG_BOTS_FILL` (mặc định 30) người. Bot vào với hồ sơ tạm cấp 200 như người thật, tự chọn thẻ (ngựa 8x + vũ khí cấp 10 hợp phái).

**Ưu tiên mỗi lượt suy nghĩ:**

| # | Trạng thái | Khi nào | Làm gì |
|---|---|---|---|
| 1 | BỊ LOẠI | chết | đứng xem (không hồi sinh), như người thật |
| 2 | UỐNG THUỐC | máu < 50% | như Lộn Xộn |
| 3 | VÀO BO | đứng ngoài vòng an toàn hiện tại, hoặc bo sắp co (còn < 40 giây) mà đang ngoài vòng kế tiếp | chạy thẳng về tâm vòng kế tiếp, bỏ mọi việc khác (trừ uống thuốc); máu bot bị trừ theo `PubgManager.zone_damage_for` như người thật |
| 4 | BÁM ĐỘI | đồng đội cách > 500px | chạy về gần đồng đội còn sống gần nhất |
| 5 | GIAO TRANH | địch trong tầm nhìn, mình + đồng đội gần đủ mạnh (tổng máu đội ≥ 70% địch) | đuổi + đánh; đồng đội cùng nhắm 1 mục tiêu |
| 6 | NHẶT ĐỒ | đồ rơi gần (Hoàng Kim, thuốc, ngựa tốt hơn) | nhặt, tự mặc |
| 7 | ĐÁNH QUÁI | 5 phút đầu trận, hoặc thiếu thuốc / thiếu trang bị | đánh quái gần trong vòng an toàn |
| 8 | DI CHUYỂN | còn lại | tiến dần vào trong vòng an toàn, nấp gần vật cản |

**Tính cách:** *Lao lên* (đánh sớm) · *Rình* (đứng trong bo, chỉ đánh khi bị tới gần) · *Cân bằng*.
Bot không biết vị trí người ngoài tầm nhìn (không "hack map").

## 5. Các bước làm

1. **Thân bot + chiến đấu server-side** (`ServerBot`, `BotCombat`): bot hiện ra với người thật, đi lại, ra chiêu (hình ảnh), đánh quái,
   đánh / nhận đòn người thật và bot khác, uống thuốc, chết. Test logic bằng GameServer giả + test online: bot thật hiện trong AOI của bot client.
2. **Bộ não chiến đấu (mục 2b):** phân loại bộ chiêu theo phái, combo buff → bùa → khống chế → dồn đòn, thả diều / vòng quanh, né
   theo tin ra chiêu, nhảy áp sát / thoát thân / vượt vật cản, bơm máu + nội lực, ngồi thiền, quyết định đánh / rút, chất "người",
   3 mức độ khó. Test: 2 bot đấu nhau đủ các phái; bot né được đạn thẳng theo tỉ lệ độ khó; bot nhảy qua ô nhảy được; bot không uống chồng thuốc.
3. **Kịch bản Lộn Xộn** + `BotDirector` thêm / bớt bot theo host. Test: bot tự đánh quái lên cấp, nhặt Lệnh Bài, PK, chết rớt đồ, hồi sinh.
4. **Kịch bản PUBG** + lấp trận bằng bot + bo trừ máu bot + phối hợp đội. Test: trận chỉ 1 người thật + bot vẫn chạy tới khi có kết quả.
5. **Cân chỉnh & hiệu năng:** đo tick với 5 host × 8 bot + 1 trận PUBG 30 bot; bot không có người thật ở gần thì nghĩ thưa hơn
   (1 lần / giây) và bỏ phần né / combo chi tiết; cho người chơi thử thật đánh với bot ở từng độ khó.

### Trạng thái
- [x] **Bước 1 (2026-11-18)** — `net/server/bots/`: `ServerBot` (thực thể KIND_PLAYER, chỉ số từ hồ sơ, đi 150 px/giây, nhảy 40 frame
  miễn sát thương lúc bay, thuốc hồi dần 30% / 3 giây không uống chồng, hồi chiêu + khoá động tác, chết / hồi sinh; đòn chính = chiêu
  tấn công mạnh nhất của phái), `BotCombat` (tính đòn trên server bằng CombatFormulas: người → bot qua C_PVP_HIT, bot → người qua
  S_PVP_HIT, bot ↔ bot, bot → quái, quái → bot), `BotManager` (sinh / bỏ, nhịp não 5 lần/giây, đòn bay có thời gian — mục tiêu chạy
  khỏi tầm thì trượt), `BotDuelBrain` (não tạm: bám 1 mục tiêu). GameServer: `broadcast_cast`, `send_pvp_hit`, `bot_damage_monster`,
  quái nhắm được bot; RelationServer chuyển đòn vào bot cho BotManager. Lệnh thử `/testbot [phái] [cấp]` (chỉ GAME_TEST_MODE).
  Test: `bot_body_tests` 37/37, `bot_online_tests` 10/10 (bot client thật), Lộn Xộn / PUBG online vẫn đạt.
  Lưu ý: quái chỉ "thức" quanh người thật — bot cày quái xa người thật thì quái không đánh lại (đỡ tốn CPU).
- [ ] Bước 2 — bộ não chiến đấu (mục 2b).

## 6. Cần chốt (đang theo mặc định bên phải)

1. **Số bot:** Lộn Xộn giữ ≥ 8 người / host; PUBG lấp tới 30 người / trận. (Nhiều hơn tốn CPU server.)
2. **Hiện là bot hay giấu?** → Tên như người thường, **không gắn nhãn [Bot]**; web Admin / GM thấy cờ bot. (Hoặc gắn nhãn cho minh bạch.)
3. **Quái có đánh bot không?** → **Có** (server tự tính đòn quái vào bot), để bot cày quái thật sự tốn máu.
4. **Bot có rơi đồ / Lệnh Bài khi chết như người thật?** → **Có** (người thật săn bot được thưởng như săn người).
5. **Độ khó mặc định:** Thường; chỉnh bằng biến môi trường / Thông số game trên web Admin sau.
6. **Bot có chat không?** → Mặc định **không** (có thể thêm câu mẫu sau).
7. **Trộn độ khó trong 1 host / trận** → **Có**: khoảng 30% Dễ, 50% Thường, 20% Khó, để có bot dễ ăn lẫn bot khó chơi như người thật.
8. **Bot có tự mặc đồ nhặt được và học bí kíp (Lộn Xộn)?** → **Có**, như người thật.
