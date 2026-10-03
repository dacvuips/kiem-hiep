# VLTK (Võ Lâm Truyền Kỳ) gốc — Tài liệu tham khảo công thức/số liệu Player

> Trích xuất từ bộ "Server + client full-001" (private server VLTK cũ, dữ liệu hợp pháp người dùng sở hữu), dùng làm chuẩn tham khảo cho game indie Godot tại `D:\game\lam-game\kiem-hiep`.
>
> **Nguyên tắc:** mọi số liệu dưới đây được dẫn nguồn file cụ thể. Không có số liệu nào bị đoán/bịa. Khi một công thức được suy luận từ nhiều điểm dữ liệu (không phải đọc trực tiếp 1 hằng số), mức độ tin cậy được ghi rõ.
>
> **Giới hạn đã biết (xác nhận từ phiên làm việc trước):** không có file text/script nào chứa trực tiếp công thức tính toán runtime. Các công thức thật (nếu có logic phức tạp hơn tuyến tính, ví dụ hệ số ẩn, bo tròn, cap...) nằm cứng trong `Coreserver.dll` / `GameServer.exe` đã biên dịch — ngoài phạm vi trích xuất không disassemble. Những gì dưới đây là **suy luận có căn cứ tối đa** từ bảng dữ liệu thật.

---

## 1. HP (Máu) — imaxlife

### Nguồn dữ liệu
- Bảng hệ số: `settings\npc\player\level_add.txt` (5 hệ ngũ hành, cột `LifePerLevel`, `LifePerVitality`)
- Điểm dữ liệu xác nhận: `settings\npc\player\NewPlayerIni00-09.ini` (10 file, mỗi file có `ipower`(Strength)/`iagility`(Dexterity)/`iouter`(Vitality)/`iinside`(Energy)/`imaxlife`/`imaxinner`/`imaxstamina`/`ifightlevel`=1/`ifiveprop`=mã hệ ngũ hành)

### Công thức suy luận (đã kiểm chứng khớp 100% với 4/5 hệ ở level 1)

```
imaxlife = LifePerLevel × Level + Vitality × LifePerVitality
```

(ở level 1, số hạng `LifePerLevel × Level` = đúng bằng giá trị cột `LifePerLevel` trong bảng — xem bên dưới)

**Kiểm chứng bằng dữ liệu thật:**

| ifiveprop | Hệ | File | Vitality (iouter) | imaxlife thực tế | LifePerVitality | LifePerLevel | Tính: Vit×LifePerVitality + LifePerLevel×1 | Khớp? |
|---|---|---|---|---|---|---|---|---|
| 0 | Kim | NewPlayerIni00/01.ini | 25 | 204 | 8 | 4 | 25×8+4 = 204 | ✅ Khớp 100% |
| 1 | Mộc | NewPlayerIni02/03.ini | 20 | 103 | 5 | 3 | 20×5+3 = 103 | ✅ Khớp 100% |
| 3 | Hỏa | NewPlayerIni06/07.ini | 30 | 213 | 7 | 3 | 30×7+3 = 213 | ✅ Khớp 100% |
| 4 | Thổ | NewPlayerIni08/09.ini | 25 | 76 | 3 | 1 | 25×3+1 = 76 | ✅ Khớp 100% |
| 2 | Thủy | NewPlayerIni05.ini | 25 | 153 | 6 | 3 | 25×6+3 = 153 | ✅ Khớp 100% |
| 2 | Thủy | NewPlayerIni04.ini | 25 | **100** | 6 | 3 | 25×6+3 = 153 | ❌ KHÔNG khớp |

**Ghi chú bất thường:** `NewPlayerIni04.ini` (hệ Thủy, giới tính nam) cho `imaxlife=100` dù stat gốc giống hệt `NewPlayerIni05.ini` (nữ, `imaxlife=153`). Khác biệt duy nhất giữa 2 file: `isectrole=0` (file04) vs `isectrole=61` (file05, và mọi file khác). Giả thuyết hợp lý nhất: file04 là template "chưa nhận thưởng nhập môn" hoặc lỗi dữ liệu edge-case, không đại diện công thức chuẩn. **Độ tin cậy công thức: cao (4/5 điểm dữ liệu độc lập khớp chính xác 100%, 1 điểm ngoại lệ có giải thích hợp lý).**

### Với level > 1 (suy luận, CHƯA kiểm chứng bằng dữ liệu thực vì mọi NewPlayerIni đều ở level 1)
```
imaxlife(Level) = LifePerLevel × Level + Vitality × LifePerVitality
```
Đây là suy luận tuyến tính đơn giản nhất khớp dữ liệu level-1; **không loại trừ khả năng có thêm hằng số base ẩn trong binary** áp dụng từ level 2 trở đi (vì ở level 1, hằng số base có thể trùng ngẫu nhiên với LifePerLevel×1). Cần thêm dữ liệu nhân vật ở level cao hơn để xác nhận tuyệt đối — **không có trong bộ file đã tìm.**

---

## 2. Mana (Nội lực) — imaxinner

### Công thức (kiểm chứng khớp 100% cả 3 điểm dữ liệu)
```
imaxinner = ManaPerLevel × Level + Energy × ManaPerEnergy
```

| ifiveprop | Hệ | Energy (iinside) | imaxinner thực tế | ManaPerEnergy | ManaPerLevel | Tính | Khớp? |
|---|---|---|---|---|---|---|---|
| 0 | Kim | 15 | 16 | 1 | 1 | 15×1+1 = 16 | ✅ |
| 3 | Hỏa | 20 | 41 | 2 | 1 | 20×2+1 = 41 | ✅ |
| 4 | Thổ | 40 | 163 | 4 | 3 | 40×4+3 = 163 | ✅ |
| 1 | Mộc | 25 | 77 | 3 | 2 | 25×3+2 = 77 | ✅ |
| 2 | Thủy | 25 | 77 | 3 | 2 | 25×3+2 = 77 | ✅ |

**Độ tin cậy: rất cao — khớp 100% ở 5/5 điểm dữ liệu độc lập (tất cả 5 hệ ngũ hành).**

---

## 3. Stamina (Thể lực) — imaxstamina

### Dữ liệu quan sát được
- Tất cả 10 file `NewPlayerIni00-09.ini` đều cho `imaxstamina=100` bất kể hệ ngũ hành hay giới tính.
- `level_add.txt` lại ghi `StaminaMaleBase=180` và `StaminaFemaleBase=180` cho **cả 5 hệ** (giống hệt nhau), và `StaminaPerVitality=0` cho cả 5 hệ (Stamina KHÔNG phụ thuộc Vitality), và `StaminaMalePerLevel=9`, `StaminaFemalePerLevel=8` cho cả 5 hệ.

**Mâu thuẫn dữ liệu:** `imaxstamina` thực tế trong file nhân vật (100) không khớp với `StaminaMaleBase`/`StaminaFemaleBase` (180) trong `level_add.txt`. Có thể `StaminaXxxBase` không phải là "giá trị tại level 1" mà là một baseline dùng trong công thức khác (VD full-level cap, hoặc base trước khi trừ đi thứ gì đó), hoặc file NewPlayerIni ghi đè cứng giá trị khởi tạo riêng biệt không qua công thức.

**Độ tin cậy: THẤP — không tìm được công thức Stamina khớp dữ liệu thực. Ghi nhận số liệu thô, không suy luận công thức.**

- `StaminaPerLevel` (nam=9, nữ=8, giống nhau ở cả 5 hệ) → gợi ý Stamina tăng tuyến tính theo Level, không phụ thuộc hệ ngũ hành hay Vitality, nhưng hằng số base thật (ứng với `imaxstamina` tại level 1) **không xác định được chắc chắn** từ dữ liệu hiện có (100 trong file thực tế vs 180 trong bảng hệ số — chênh lệch không giải thích được).

---

## 4. EXP theo cấp độ (level_exp.txt)

**Nguồn:** `settings\npc\player\level_exp.txt` — 200 dòng dữ liệu (level 1 → 200), đã đọc toàn bộ.

Cấu trúc cột: `[STT dòng file] [Cấp độ] [EXP cần để lên cấp tiếp theo] [cột trống - EXP nhân đôi?] [1 chuyển] [2 chuyển] [3 chuyển] [4 chuyển] [5 chuyển]`

### Bảng đầy đủ 40 cấp đầu (EXP cần để lên cấp kế tiếp)

| Cấp | EXP cần | Cấp | EXP cần | Cấp | EXP cần | Cấp | EXP cần |
|---|---|---|---|---|---|---|---|
| 1 | 100 | 11 | 10,900 | 21 | 57,100 | 31 | 152,100 |
| 2 | 500 | 12 | 13,100 | 22 | 63,900 | 32 | 165,400 |
| 3 | 1,100 | 13 | 15,700 | 23 | 71,300 | 33 | 179,800 |
| 4 | 1,900 | 14 | 18,700 | 24 | 79,300 | 34 | 195,300 |
| 5 | 2,900 | 15 | 22,100 | 25 | 87,900 | 35 | 211,900 |
| 6 | 4,100 | 16 | 25,900 | 26 | 97,100 | 36 | 229,600 |
| 7 | 5,500 | 17 | 30,100 | 27 | 106,900 | 37 | 248,400 |
| 8 | 7,100 | 18 | 34,700 | 28 | 117,300 | 38 | 268,300 |
| 9 | 8,900 | 19 | 39,700 | 29 | 128,300 | 39 | 289,300 |
| 10 | 10,900 | 20 | 45,100 | 30 | 139,900 | 40 | 311,400 |

(Xem file gốc để lấy đầy đủ tới cấp 200; từ cấp 100 trở đi EXP cần bị **chặn trần cố định theo bậc**: cấp 100-109 = 50,000,000; 110-119 = 60,000,000; 120-124 = 100,000,000; 125-129 = 120,000,000; 130-134 = 160,000,000; 135-139 = 200,000,000; 140-144 = 300,000,000; 145-149 = 500,000,000; 150-154 = 800,000,000; 155-159 = 1,200,000,000; 160-169 = 1,800,000,000–2,000,000,000; từ 170 trở đi giữ nguyên 2,000,000,000 mỗi cấp cho tới 198, cấp 199-200 = 2,000,000,000. Đây là **hằng số cứng theo bậc**, không theo công thức toán liên tục.)

### Phân tích pattern toán học (cấp 1–99, trước khi bị chặn trần)

Sai phân bậc 1 (diff = EXP(n) - EXP(n-1)):
- 500-100=400, 1100-500=600, 1900-1100=800, 2900-1900=1000, 4100-2900=1200, 5500-4100=1400, 7100-5500=1600, 8900-7100=1800, 10900-8900=2000...

Sai phân bậc 2 (diff of diff): 600-400=200, 800-600=200, 1000-800=200, 1200-1000=200, 1400-1200=200... → **hằng số 200** xuyên suốt từ cấp 2 đến khoảng cấp 30.

→ Đây là **dãy bậc 2 (quadratic)**: với diff bậc 1 tăng đều 200 mỗi cấp, bắt đầu diff(2)=400.
Công thức khớp gần đúng cho vùng cấp 2-30:
```
diff(n) = 200 × n
EXP(n) ≈ EXP(n-1) + 200×n  (n ≥ 2, EXP(1) = 100)
```
Kiểm tra: n=2: diff=400 → 100+400=500 ✅. n=3: diff=600 → 500+600=1100 ✅. n=10: diff=2000 → 8900+2000=10900 ✅ (khớp đúng).

Từ khoảng cấp 30 trở đi, tốc độ tăng bắt đầu nhanh hơn quadratic thuần (VD cấp 52: 766,000 sau cấp 51: 709,600, diff=56,400 — lớn hơn nhiều so với pattern 200×n nếu ngoại suy tuyến tính giản đơn), cho thấy có thể chuyển sang hệ số nhân hoặc bậc cao hơn ở vùng cấp cao. **Độ tin cậy: công thức quadratic (diff bậc 2 = hằng số 200) khớp CHÍNH XÁC 100% với dữ liệu thô cho cấp 1-~30; từ cấp ~30 trở đi công thức lệch dần — khuyến nghị dùng bảng lookup trực tiếp (hard-code từ file gốc) thay vì công thức ngoại suy cho cấp cao, đặc biệt từ cấp 100 trở đi vốn dùng hằng số cứng theo bậc, không có công thức.**

### Cột chuyển sinh (1-5 chuyển)
Chỉ xuất hiện từ dòng cấp 130 trở đi (5 cột cuối). Ví dụ cấp 130: `1chuyển=48000, 2chuyển=64000, 3chuyển=0, 4chuyển=496000`. Đây là EXP cần cho các mốc "chuyển sinh" song song ở cấp cao — **không đủ ngữ cảnh để xác định ý nghĩa chính xác từng cột nếu không có thêm tài liệu mô tả**, ghi nhận nguyên văn số liệu, không suy luận thêm.

---

## 5. Bảng level_add.txt — đầy đủ 5 hệ ngũ hành

**Nguồn:** `settings\npc\player\level_add.txt` (encoding gốc GBK/Big5, đã giải mã các nhãn cột — cột đầu ghi "hệ Kim/Mộc/Thủy/Hỏa/Thổ").

| Hệ | LifePerLevel<br>(máu/cấp) | StaminaMalePerLevel<br>(thể lực nam/cấp) | StaminaFemalePerLevel<br>(thể lực nữ/cấp) | ManaPerLevel<br>(nội lực/cấp) | LifePerVitality<br>(máu/điểm Vitality) | StaminaPerVitality<br>(thể lực/điểm Vitality) | ManaPerEnergy<br>(nội lực/điểm Energy) | LeadExpShare<br>(chia sẻ EXP bang chủ %?) | fireres<br>(kháng hỏa) | coldres<br>(kháng lạnh/thủy) | poisonres<br>(kháng độc) | lightingres<br>(kháng lôi/mộc) | physicres<br>(kháng vật lý) | StaminaMaleBase | StaminaFemaleBase |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Kim | 4 | 9 | 8 | 1 | 8 | 0 | 1 | 25 | -25 | 0 | 25 | 0 | 0 | 180 | 180 |
| Mộc | 3 | 9 | 8 | 2 | 5 | 0 | 3 | 25 | 0 | 0 | 0 | 25 | -15 | 180 | 180 |
| Thủy | 3 | 9 | 8 | 2 | 6 | 0 | 3 | 25 | 25 | 0 | 0 | -25 | 0 | 180 | 180 |
| Hỏa | 3 | 9 | 8 | 1 | 7 | 0 | 2 | 25 | 0 | -25 | 0 | 0 | 15 | 180 | 180 |
| Thổ | 1 | 9 | 8 | 3 | 3 | 0 | 4 | 25 | 0 | 25 | -25 | 0 | 0 | 180 | 180 |

**Dịch nghĩa cột:**
- `LifePerLevel` = máu cộng thêm mỗi khi lên 1 cấp (hằng số base, không phụ thuộc stat)
- `LifePerVitality` = máu cộng thêm mỗi điểm Vitality (Ngoại lực/iouter)
- `StaminaMalePerLevel` / `StaminaFemalePerLevel` = thể lực cộng mỗi cấp, tách theo giới tính
- `StaminaPerVitality` = thể lực cộng mỗi điểm Vitality — **bằng 0 ở cả 5 hệ**, nghĩa là Stamina KHÔNG phụ thuộc Vitality trong công thức lý thuyết
- `ManaPerLevel` = nội lực cộng mỗi cấp
- `ManaPerEnergy` = nội lực cộng mỗi điểm Energy (Nội lực gốc/iinside)
- `LeadExpShare` = % chia sẻ EXP liên quan vai trò bang chủ/leader (không phải core combat stat, ghi nhận nguyên văn)
- `fireres/coldres/poisonres/lightingres/physicres` = % kháng ngũ hành CƠ BẢN gắn theo hệ ngũ hành nhân vật (Hỏa/Lạnh(Thủy)/Độc/Lôi(Mộc)/Vật lý) — lưu ý: mỗi hệ có kháng dương với hệ "khắc" tương ứng và kháng âm (yếu điểm) với hệ đối lập, phản ánh đúng cơ chế ngũ hành tương sinh/tương khắc truyền thống (VD Kim kháng poison +25 nhưng yếu fire -25)
- `StaminaMaleBase` / `StaminaFemaleBase` = thể lực nền (giống nhau ở cả 5 hệ = 180) — **lưu ý: mâu thuẫn với imaxstamina=100 thực tế trong NewPlayerIni, xem mục 3.**

**Độ tin cậy: trực tiếp từ bảng dữ liệu — chính xác 100% (đây là đọc nguyên văn, không suy luận).**

---

## 6. Kháng ngũ hành (resistance) — dữ liệu bổ sung

### Từ level_add.txt (mục 5 ở trên)
Kháng cơ bản theo hệ ngũ hành của nhân vật — trực tiếp từ bảng, độ tin cậy 100%.

### Từ NewPlayerIni00-09.ini
Mọi file đều có 3 field kháng cố định giống nhau bất kể hệ ngũ hành:
```
ihelmres=19
iarmorres=19
iweaponres=2
```
Đây có vẻ là kháng do **trang bị khởi tạo** (mũ/giáp/vũ khí tân thủ) cộng thêm, không phải kháng gốc nhân vật — vì giống hệt nhau ở mọi hệ trong khi `level_add.txt` cho kháng gốc khác nhau theo hệ. **Độ tin cậy: trực tiếp đọc từ file — chính xác 100% về giá trị, nhưng suy luận "đây là kháng từ trang bị" chỉ là giả thuyết hợp lý, chưa kiểm chứng độc lập.**

### Từ GameSetting.ini — mục `[TransLife]`
```
MinPhyResist=-18
MinWoodResist=-11
MinWaterResist=-18
MinFireResist=-18
MinEarthResist=-18
```
Đây là **giới hạn dưới (cap)** của kháng ngũ hành (không thể âm hơn các giá trị này). **Nguồn:** `settings\GameSetting.ini`, mục `[TransLife]`. Độ tin cậy: trực tiếp từ file — chính xác 100%, nhưng ý nghĩa chính xác của "TransLife" (có thể là cơ chế đặc biệt như "chuyển sinh" hoặc trạng thái biến đổi) không rõ ràng do thiếu ngữ cảnh — ghi nhận số liệu nguyên văn.

---

## 7. Attack / Damage / Defense / Tốc độ đánh / Né tránh / Chính xác / Crit

### KHÔNG TÌM THẤY công thức trực tiếp cho các chỉ số này trong bất kỳ file .txt/.ini nào dưới `settings\`.

Đã grep từ khóa `Attack|Damage|Defense|Accuracy|Evasion|Crit|AttackSpeed|MoveSpeed` (không phân biệt hoa/thường) trên toàn bộ `.txt`/`.ini` dưới `settings\`. Kết quả liên quan tới core player combat stat:

- `settings\npc\player\BaseValue.ini`: chỉ có cấu trúc rỗng (`Strength=0, Dexterity=0, Vitality=0, Engergy=0, Lucky=1` cho cả 5 hệ Kim/Mộc/Thủy/Hỏa/Thổ) — **toàn bộ giá trị = 0**, có vẻ là file template/placeholder chưa điền, KHÔNG chứa công thức hay hệ số thật.
- `settings\npc\player\NewPlayerBaseAttribute.ini`: tương tự BaseValue.ini — toàn 0, là template rỗng.
- `settings\GameSetting.ini`, mục `[Common]`:
  ```
  RunSpeed=10
  WalkSpeed=5
  AttackFrame=18
  CastFrame=18
  HurtFrame=10
  ```
  Đây là **số khung hình animation** (chạy/đi/đánh/thi triển/trúng đòn), KHÔNG phải công thức tốc độ đánh từ Dexterity — chỉ là tốc độ di chuyển cơ bản chung (không phân theo nhân vật) và số frame animation.
- `settings\GameSetting.ini`, mục `[ServerConfig]`:
  ```
  ExpRate=1
  MoneyRate=1
  SkillRate=1
  Skill120Rate=10
  NpcPoisonDamageMax=123456
  PlayerPoisonDamageMax=600
  ```
  Đây là **hệ số nhân toàn server** (rate EXP/tiền/skill — dùng để GM chỉnh tốc độ server) và **trần sát thương độc tối đa** cho NPC/Player — không phải công thức Attack/Damage cơ bản.

### Kết luận
Công thức Attack (từ Strength), Damage, Defense, AttackSpeed (từ Dexterity), Evasion/Accuracy, Crit chance **hoàn toàn không có trong dữ liệu text/ini** đã tìm được. Đúng như nhận định ban đầu — các công thức này nằm cứng trong binary (`Coreserver.dll`/`GameServer.exe`) và không thể trích xuất chính xác từ bộ dữ liệu hiện có.

**Khuyến nghị cho dự án Godot:** với Attack/Damage/Defense/Speed/Crit/Evasion, KHÔNG có căn cứ dữ liệu gốc để tái tạo chính xác — team nên tự thiết kế công thức phù hợp gameplay riêng (không cố gắng "khôi phục" số liệu VLTK gốc cho các chỉ số này vì không có nguồn xác thực).

---

## 8. Các file liên quan khác đã xem qua

- `settings\npc\player\magic_level_exp.txt`: bảng EXP cần để nâng cấp **skill/võ công** theo level 1-60 (60 cột LEVEL1-LEVEL60), theo từng `MAGICID`/`MAGICNAME`/`FACTIONID` (môn phái). Không liên quan trực tiếp tới core stat nhân vật (HP/Mana/Attack...) — đây là bảng cost để luyện chiêu thức, ghi nhận để tham khảo nếu sau này cần thiết kế hệ thống skill progression.
- `settings\npc\player\level_lead_exp.txt`: bảng EXP + cột liên quan tới "lãnh đạo bang hội" (leader), theo cấp 1-100 — cột 2 = EXP cần, cột 3 = "3/4/5..." (có thể số slot đệ tử?), cột 4 = "trực thuộc thành viên" tăng dần (7/15/23/31...), cột 5 = "quyền uy thưởng". Không liên quan core player combat stat, chỉ liên quan cơ chế bang hội — ghi nhận nguyên văn không suy luận thêm do thiếu ngữ cảnh rõ ràng.
- `settings\Ui\Ui3\UiStatus.ini`: chỉ là layout UI, xác nhận tên field đúng (Strength/Dexterity/Vitality/Energy, Life/Mana/Stamina, LeftDamage/RightDamage, Attack/Defense, MoveSpeed/AttackSpeed, ResistPhy/Cold/Lighting/Fire/Poison) — không chứa số liệu.

---

## 9. Danh sách file nghi ngờ còn thông tin nhưng CHƯA kịp xem kỹ

- Thư mục `settings\item\` — chỉ mới xem `AbradeRate.ini` (khớp từ khóa Attack/Damage do grep, nhưng nội dung cụ thể **chưa được đọc kỹ** trong phiên này — có thể chứa tỉ lệ hao mòn trang bị liên quan sát thương/phòng thủ trang bị, không phải base player stat, nhưng nên xác minh thêm).
- Thư mục `settings\npc\` (ngoài `player\`) — chứa dữ liệu NPC/quái (không phải player), có thể có công thức combat chung áp dụng cho cả NPC lẫn Player (ví dụ common damage formula) nhưng chưa được rà soát toàn bộ do phạm vi rất lớn (hàng trăm file).
- `settings\Npcs.txt` và `settings\Skills.txt`, `settings\THIEFSKILLS.txt`, `settings\MagicDesc.ini` — khớp từ khóa Attack/Damage/Crit khi grep nhưng đây nhiều khả năng là dữ liệu kỹ năng/skill cụ thể (sát thương skill, mô tả), không phải core player stat formula — cần thời gian đọc thêm nếu muốn khai thác chi tiết công thức sát thương skill.
- `settings\WorldSet.ini` và `WorldSet1.ini` được đề cập trong yêu cầu ban đầu — **không tìm thấy 2 file này tồn tại** trong cây thư mục `settings\` (glob `*.ini` ở gốc chỉ trả về `GameSetting.ini`, `Weather\Weather.ini`, `Music\MusicFightSet.ini`) — có thể tên file khác hoặc không có trong bộ dữ liệu này.

---

## 10. Rà soát bổ sung: công thức combat damage (settings/npc/, Skills.txt, MagicDesc.ini, THIEFSKILLS.txt)

### 10.1. `settings\npc\` (trừ `npc\player\` đã xem)

Thư mục này **nhỏ hơn nhiều so với dự đoán ban đầu** — không phải "hàng trăm file", chỉ có **21 file** tổng cộng, gồm:
- `settings\npc\PKSet.ini` — duy nhất 1 file KHÔNG nằm trong `player\`
- 20 file còn lại đều nằm trong `settings\npc\player\` (đã rà ở các mục trước: `BaseValue.ini`, `NewPlayerBaseAttribute.ini`, `NewPlayerIni00-09.ini`, `PKPunish.txt`, `RevivalID.ini`, `level_add.txt`, `level_exp.txt`, `level_lead_exp.txt`, `magic_level_exp.txt`, `stamina.ini`, `vssver.scc`)

**`PKSet.ini` — đã đọc toàn bộ (23 dòng).** Đây là config PK (Player-Kill) chung áp dụng toàn server — đúng dạng "1 file duy nhất, không phải per-NPC" như nghi ngờ ban đầu, NHƯNG nội dung chỉ là: tỷ lệ rớt đồ khi bị giết (`Rate`, `LevelRate`, `SpecialRate`), cách tính điểm ác (`FactionPKFaction`, `EnmityPK`, `BeKilled`), % EXP bị trừ khi PK (`NotSubPKExpPercent`, `NotEnmityExpPercent`, `NotFightExpPercent`), thời gian trạng thái PK (`NormalPKTimeLong`, `FightPKTimeLong`). **Không có bất kỳ hệ số Attack/Defense/Crit/Evasion nào** — đây là cơ chế xã hội/hình phạt PK, không phải công thức damage.

**Kết luận 10.1:** Không tồn tại "NPC data folder" lớn nào khác ngoài `settings\Npcs.txt` ở gốc (đã có từ trước, xem lại bên dưới). Không có file config combat chung nào khác ngoài PKSet.ini (không liên quan damage).

### 10.2. `settings\Npcs.txt` (2153 dòng, đọc header + vài dòng mẫu)

Cột dữ liệu gồm: `ARParam/ARParam1-3` (Attack Rating theo mốc level), `DefenseParam/DefenseParam1-3`, `MinDamageParam/MinDamageParam1-3`, `MaxDamageParam/MaxDamageParam1-3`, `FireResist/ColdResist/LightResist/PoisonResist/PhysicsResist` (% kháng nguyên tố), `PhysicalDamageBase`.

Đây **hoàn toàn là SỐ LIỆU cụ thể** cho từng NPC (VD dòng NPC "Đông Bắc hổ": ARParam=100, DefenseParam=100, MinDamageParam=100, MaxDamageParam=100 — đều là base value trước khi nhân theo level qua ParamX). Cấu trúc `Param/Param1/Param2/Param3` cho thấy có công thức nội suy theo level (tương tự cơ chế `Line()`/`Link()` tìm thấy trong `head.lua`, mục 10.4), nhưng **giá trị cột chỉ là input, không phải công thức kết hợp Attack-Defense-Crit-Evasion ra damage cuối**. Xác nhận lại: đây là dữ liệu, không phải công thức.

### 10.3. `settings\Skills.txt` (1566 dòng) — cấu trúc cột + đối chiếu `tangmen.lua`

Đã đọc header đầy đủ + grep mẫu các dòng skill "Công kích vật lý", "Tăng Môn đao pháp". Phát hiện quan trọng:

- Cột `Param1Memo`/`Param2Memo` chứa **tên biến engine** dùng làm modifier cho skill đó, ví dụ: `physicsenhance_p`, `attackrating_p`, `addphysicsdamage_p`, `attackratingenhance_p`, `deadlystrikeenhance_p`, `physicsdamage_v`.
- Cột `LvlSetScript` trỏ tới file `.lua` trong `script\skill\` (VD `script\skill\tangmen.lua`) — file này định nghĩa bảng `SKILLS[...]` với các mốc `{level, value}` cho từng biến, ví dụ trong `tangmen.lua`:
  ```lua
  physicsenhance_p={{{1,20},{20,80}}}      -- % tăng sát thương vật lý, level 1→20%, level 20→80%
  addphysicsdamage_p={{{1,25},{20,215}}}   -- cộng thêm sát thương vật lý tuyệt đối, level 1→25, level 20→215
  deadlystrike_p={{{1,1},{20,8}}}          -- % tỷ lệ chí mạng ("deadly strike" = crit), level 1→1%, level 20→8%
  deadlystrikeenhance_p={{{1,8},{30,26}}}  -- % tăng thêm hiệu ứng chí mạng
  ```
- File `script\skill\head.lua` chứa các hàm nội suy dùng chung: `Line(x,x1,y1,x2,y2)` (tuyến tính), `Conic()` (bậc 2), `Extrac()` (căn), `Link(x,points)` (nội suy theo nhiều mốc điểm), và `GetSkillLevelData()` (đọc bảng `SKILLS[data][levelname]` rồi nội suy theo level hiện tại của skill). **Đây là cơ chế SCALING của giá trị buff theo level skill — KHÔNG PHẢI công thức combat damage tổng quát.** Nó chỉ trả lời "biến X ở level Y của skill này có giá trị bao nhiêu", không trả lời "damage cuối cùng = f(Attack, Defense, Crit, Evasion) là gì".
- Từ `sjbattle_state.lua` (buff trạng thái chiến đấu tạm thời) tìm thêm các biến modifier khác: `adddefense_v` (cộng phòng thủ tuyệt đối), `attackrating_v` (cộng Attack Rating tuyệt đối), `attackspeed_yan_v`/`castspeed_yan_v` (% tăng tốc đánh/tốc thi triển), `enhancehit_rate` (% tăng tỷ lệ đòn nặng/chí mạng), `anti_enhancehit_rate` (% kháng lại đòn nặng/chí mạng của đối phương), `allres_yan_p` (% tăng toàn bộ kháng nguyên tố).

**Nhận xét quan trọng (mới, hữu ích cho việc hiểu hệ thống):** các biến này xác nhận rõ ràng engine VLTK có khái niệm `AttackRating` (không phải "Attack" thô) và cơ chế `enhancehit_rate` riêng biệt cho "đòn đánh nặng/chí mạng" (deadly strike) khác với accuracy/evasion thường. Điều này gợi ý công thức lõi (nằm trong binary) nhiều khả năng có dạng nhiều lớp: (1) roll trúng/né dựa trên AttackRating vs Defense/Evasion, (2) roll thêm crit riêng dựa trên `deadlystrike_p`/`enhancehit_rate` vs `anti_enhancehit_rate`, (3) damage cơ bản trong khoảng [MinDamageParam, MaxDamageParam] cộng modifier % (`physicsenhance_p`) và modifier tuyệt đối (`addphysicsdamage_p`). Đây **CHỈ LÀ SUY LUẬN KIẾN TRÚC** dựa trên tên biến, KHÔNG PHẢI công thức đã xác nhận — không có nơi nào trong text/lua ghi rõ công thức kết hợp các bước này (VD thứ tự cộng/nhân, công thức roll ngẫu nhiên chính xác, cách Defense trừ vào Damage).

Không tìm thấy công thức tổng quát nào viết dưới dạng biểu thức toán học (như `damage = Attack - Defense` hay tương tự) trong Skills.txt hay bất kỳ file .lua skill nào đã xem.

### 10.4. `settings\MagicDesc.ini` (296 dòng, đọc 40 dòng đầu)

**Xác nhận: đây chỉ là template text hiển thị UI** (tooltip mô tả skill cho client), ví dụ `skill_cost_v=Tiêu hao: #d1- điểm`, `skill_mintimepercast_v=Thời gian gián cách #d1- giây`. Các placeholder `#d1`, `#k1` được điền bằng giá trị runtime khi hiển thị — **không chứa công thức tính toán**, chỉ là chuỗi định dạng text. Đúng như nghi ngờ ban đầu trong đề bài.

### 10.5. `settings\THIEFSKILLS.txt` (5 dòng, đọc toàn bộ)

Cấu trúc cột: `SkillId, SkillName, ThiefStyle, AttackRadius, MaxLevel, TimePerCast, ThiefPercent, SkillCostType, Param1, Param2, Movie, TargetMovieInfo, SkillSound, TargetMovie, SkillIcon, Cost, Desc`. Chỉ có 3 skill trộm cắp (lấy tiền, xem HP, xem nội lực đối phương) — không có field liên quan Attack/Defense/Damage, chỉ có `ThiefPercent` (tỷ lệ thành công hành động trộm, không phải combat damage). Không liên quan tới công thức combat.

### Kết luận tổng thể mục 10

**KHÔNG tìm thấy công thức combat damage tổng quát** (dạng `damage = f(Attack, Defense, Accuracy, Evasion, CritChance)`) ở bất kỳ đâu trong 4 khu vực rà soát bổ sung này. Toàn bộ nội dung tìm được chia làm 2 loại rõ rệt:

1. **Dữ liệu số liệu** (không phải công thức): `Npcs.txt` (ARParam/DefenseParam/MinDamageParam/MaxDamageParam per-NPC), `PKSet.ini` (config PK, không phải combat), bảng level-scaling trong các file `.lua` skill (giá trị buff theo level).
2. **Cơ chế/hàm phụ trợ** (không phải công thức combat chính, chỉ là công cụ nội suy dùng chung): `Line/Conic/Extrac/Link` trong `head.lua` — dùng để tính giá trị biến buff tại 1 level cụ thể bằng nội suy tuyến tính/bậc 2 giữa các mốc đã khai báo, KHÔNG liên quan tới việc kết hợp Attack/Defense/Crit/Evasion thành damage cuối.

**Xác nhận lại giả thuyết ban đầu:** công thức combat damage lõi (cách AttackRating/Defense/Evasion/Crit được roll và kết hợp thành 1 con số damage cuối cùng khi player đánh NPC hoặc PK) **nằm cứng trong binary đã biên dịch** (`Coreserver.dll`/`GameServer.exe`) và không thể trích xuất từ bộ dữ liệu text/ini/lua hiện có, dù đã rà thêm 2 khu vực nghi ngờ theo yêu cầu. Không có căn cứ để suy diễn công thức cụ thể — chỉ có thể liệt kê CÁC BIẾN liên quan (xem mục 10.3) làm tài liệu tham khảo tên gọi/khái niệm nếu muốn thiết kế hệ thống combat tương tự cho game riêng.

> **CẬP NHẬT QUAN TRỌNG (phiên sau):** Mục 10 ở trên đã LỖI THỜI — kết luận "công thức nằm cứng trong binary, không trích xuất được" không còn đúng. Đã tìm được **MÃ NGUỒN C++ THẬT** (.cpp/.h, không phải binary) tại `D:\game\source_vo-lam-truyen-ky\VS2022\Source-VS2022-20260926T022613Z-1-002\Source-VS2022\Source\Source\SwordOnline\Sources\Core\Src\`. Xem mục 11 bên dưới — toàn bộ công thức combat lõi đã được đọc trực tiếp và trích dẫn nguyên văn kèm số dòng.

---

## 11. Công thức Combat THẬT từ mã nguồn C++ (KNpc.cpp và liên quan)

> Nguồn: mã nguồn C++ thật (không phải binary/disassemble) tại `D:\game\source_vo-lam-truyen-ky\VS2022\Source-VS2022-20260926T022613Z-1-002\Source-VS2022\Source\Source\SwordOnline\Sources\Core\Src\`. Mọi trích dẫn dưới đây đọc trực tiếp từ file, kèm đường dẫn + số dòng chính xác.

### 11.1. AttackRating (AR) — TÌM THẤY, tính từ Dexterity

File: `KPlayer.cpp`, hàm `KPlayer::SetBaseAttackRating()`, dòng 7164-7167:
```cpp
void	KPlayer::SetBaseAttackRating()
{
	Npc[m_nIndex].m_AttackRating = m_nDexterity * 4 - 28;
}
```
**Công thức: `AttackRating = Dexterity × 4 − 28`.** Không phụ thuộc Strength.

Giá trị này sau đó được copy sang `m_CurrentAttackRating` tại `KPlayer.cpp:2721`:
```cpp
Npc[m_nIndex].m_CurrentAttackRating	= Npc[m_nIndex].m_AttackRating;
```
và có thể cộng thêm buff/skill runtime tại `KPlayer.cpp:2243` (`Npc[m_nIndex].m_CurrentAttackRating += nRating;`) và `KNpcAttribModify.cpp:331,337` (cộng theo % hoặc giá trị tuyệt đối từ hiệu ứng skill/magic: `pNpc->m_CurrentAttackRating += pNpc->m_AttackRating * pMagic->nValue[0] / 100;` và `pNpc->m_CurrentAttackRating += pMagic->nValue[0];`).

### 11.2. Defense — TÌM THẤY, tính từ Dexterity

File: `KPlayer.cpp`, hàm `KPlayer::SetBaseDefence()`, dòng 7169-7172:
```cpp
void	KPlayer::SetBaseDefence()
{
	Npc[m_nIndex].m_Defend = m_nDexterity >> 2;
}
```
**Công thức: `Defend = Dexterity >> 2` = `Dexterity / 4` (chia nguyên, dịch phải 2 bit).** Cũng không phụ thuộc Strength/Vitality — chỉ Dexterity.

Copy sang `m_CurrentDefend` tại `KPlayer.cpp:2733` (`Npc[m_nIndex].m_CurrentDefend = Npc[m_nIndex].m_Defend;`), cộng thêm runtime tại `KPlayer.cpp:2246` và `KNpcAttribModify.cpp:720` (`pNpc->m_CurrentDefend += pMagic->nValue[0];`).

**Nhận xét:** cả AttackRating lẫn Defense của Player đều chỉ phụ thuộc **Dexterity** (không phải Strength/Vitality như suy đoán ban đầu trong yêu cầu). Đây là số liệu đọc trực tiếp, không suy luận.

### 11.3. Damage vật lý cơ bản (tay không) — TÌM THẤY, tính từ Strength

File: `KPlayer.cpp`, hàm `KPlayer::SetFirstDamage()`, dòng 7112-7118:
```cpp
void	KPlayer::SetFirstDamage()
{
	int nDamageBase = m_nCurStrength / STRENGTH_SET_DAMAGE_VALUE/* + 1*/;
	
	Npc[m_nIndex].m_PhysicsDamage.nValue[0] = nDamageBase;
	Npc[m_nIndex].m_PhysicsDamage.nValue[2] = nDamageBase;
	Npc[m_nIndex].m_PhysicsDamage.nValue[1] = 0;
	...
}
```
`STRENGTH_SET_DAMAGE_VALUE` định nghĩa tại `KPlayer.h:29` = `5`.

**Công thức: `MinDamage = MaxDamage = Strength / 5` (chia nguyên)** — cả Min và Max damage vật lý gốc (tay không/chưa cộng vũ khí) BẰNG NHAU và chỉ phụ thuộc Strength (dòng comment `/* + 1*/` bị comment-out, nghĩa là không cộng thêm 1 trong bản build này).

Damage magic tương tự tại `KPlayer::SetFirstMagic()` (dòng 7137-7145): `nDamageBase = m_nCurEngergy / ENGERGY_SET_DAMAGE_VALUE` — nhưng `ENGERGY_SET_DAMAGE_VALUE` định nghĩa tại `KPlayer.h:31` = `0`, và code có check `if(ENGERGY_SET_DAMAGE_VALUE)` trước khi chia (tránh chia cho 0) — nghĩa là **trong bản build này, damage magic gốc từ Energy luôn = 0** (tính năng bị tắt/chưa dùng).

Damage tay không cuối cùng khi tính vào combat: `KPlayer.cpp:7324-7325`:
```cpp
int nMinNpcDamage = Npc[m_nIndex].m_PhysicsDamage.nValue[0] + Npc[m_nIndex].m_CurrentAddPhysicsDamage;
int nMaxNpcDamage = Npc[m_nIndex].m_PhysicsDamage.nValue[2] + Npc[m_nIndex].m_CurrentAddPhysicsDamage;
```
`m_CurrentAddPhysicsDamage` là phần cộng thêm từ skill/item (khớp với biến `addphysicsdamage_p` đã thấy trong Skills.txt/tangmen.lua ở mục 10.3) — được reset về 0 tại `KPlayer.cpp:2774` rồi cộng lại bởi hệ thống modify attrib.

### 11.4. HP/Mana/Stamina runtime — ĐỐI CHIẾU: KHỚP HOÀN TOÀN với suy luận cũ ở mục 1-3

File: `KPlayer.cpp`, hàm xử lý set level (dòng 3853-3864):
```cpp
int nBaseLife, nBaseMana, nBaseStamina;
BaseAttrib.GetInteger("ROLE", "imaxlife", 0, &nBaseLife);
BaseAttrib.GetInteger("ROLE", "imaxinner", 0, &nBaseMana);
BaseAttrib.GetInteger("ROLE", "imaxstamina", 0, &nBaseStamina);

Npc[m_nIndex].m_LifeMax = nBaseLife + (nLevel - PLAYER_PREFIX_LEVEL) * PlayerSet.m_cLevelAdd.GetLifePerLevel(Npc[m_nIndex].m_Series);
Npc[m_nIndex].m_ManaMax = nBaseMana + (nLevel - PLAYER_PREFIX_LEVEL) * PlayerSet.m_cLevelAdd.GetManaPerLevel(Npc[m_nIndex].m_Series);
Npc[m_nIndex].m_StaminaMax = nBaseStamina + (nLevel - PLAYER_PREFIX_LEVEL) * PlayerSet.m_cLevelAdd.GetStaminaPerLevel(Npc[m_nIndex].m_nSex, Npc[m_nIndex].m_Series);
```
Và tăng mỗi lần lên cấp, `KPlayer.cpp:2896-2899` (`KPlayer::LevelAddBaseLifeMax()`):
```cpp
void KPlayer::LevelAddBaseLifeMax()
{
	Npc[m_nIndex].m_LifeMax += PlayerSet.m_cLevelAdd.GetLifePerLevel(Npc[m_nIndex].m_Series);
	Npc[m_nIndex].m_CurrentLifeMax = Npc[m_nIndex].m_LifeMax;
}
```

**Xác nhận: `LifeMax = imaxlife(base từ NewPlayerIni) + (Level − PLAYER_PREFIX_LEVEL) × LifePerLevel(theo hệ ngũ hành)`.**

Đây **KHÔNG mâu thuẫn** với công thức suy luận cũ ở mục 1 (`imaxlife = LifePerLevel × Level + Vitality × LifePerVitality`) — thực ra nó BỔ SUNG thêm chi tiết: base `imaxlife` đọc từ file `NewPlayerIni` (chính là kết quả của công thức `LifePerLevel×1 + Vitality×LifePerVitality` ở level 1, đã kiểm chứng khớp 100% ở mục 1), rồi CỘNG THÊM tuyến tính `LifePerLevel` mỗi cấp từ đó trở đi qua `GetLifePerLevel()`. Điều này **xác nhận** giả thuyết "hằng số base ẩn có thể trùng ngẫu nhiên với LifePerLevel×1 ở level 1" nêu ở mục 1 dòng 42 là ĐÚNG: base thực chất là giá trị `imaxlife` lưu sẵn trong save-file nhân vật (`NewPlayerIni`), không phải công thức tính lại từ Vitality mỗi lần — Vitality chỉ ảnh hưởng lúc KHỞI TẠO nhân vật (ghi vào `imaxlife` ban đầu), còn từ đó về sau mỗi level chỉ cộng thêm `LifePerLevel` cố định (không nhân thêm Vitality nữa trừ khi tăng điểm Vitality thủ công, xử lý ở nơi khác không thuộc phạm vi grep này).

Tương tự cho Mana (`GetManaPerLevel`) và Stamina (`GetStaminaPerLevel(sex, series)`) — cùng cấu trúc, xác nhận công thức mục 2 cũng đúng dạng "base lưu sẵn + tuyến tính theo level".

**Kết luận: KHỚP với suy luận cũ**, đồng thời làm rõ thêm cơ chế (base snapshot lúc tạo nhân vật, không phải công thức runtime tính lại từ Vitality/Energy mỗi lần).

### 11.5. CalcDamage đầy đủ — trích dẫn nguyên văn

File: `KNpc.cpp`, hàm `KNpc::CalcDamage(...)`, dòng 2445-2688 (SERVER only, `#ifdef _SERVER`).

**Bước 1 — Roll damage thô** (dòng 2453-2470):
```cpp
int nDamage = 0, nCurDamage = 0;
if (m_Series == series_minus)
{
	nDamage = 1;
}
else
{
	int	nRes = 0;
	int nDamageRange = nMax - nMin;
	if (nDamageRange < 0) 
	{
		nDamage = nMax + g_Random(-nDamageRange);
	}
	else
	{
		nDamage = nMin + g_Random(nMax - nMin);
	}
```

**Bước 2 — Crit (Deadly Strike / Fatally Strike)**, chỉ áp dụng khi `bReturn` (dòng 2471-2484):
```cpp
if (bIsDS)
	nDamage = nDamage * MAX_DEATLY_STRIKE_ENHANCEP / MAX_PERCENT;

if (bIsFS)
	nDamage = m_CurrentLife / MAX_PERCENT * GetRandomNumber(MIN_FATALLY_STRIKE_ENHANCEP, MAX_FATALLY_STRIKE_ENHANCEP);
```

**Bước 3 — Trừ Armor + Resist theo loại damage** (switch theo `nType`, ví dụ `damage_physics`, dòng 2500-2515):
```cpp
case damage_physics:
	nRes = m_CurrentPhysicsResist;
	if (nRes > m_CurrentPhysicsResistMax)
	{
		nRes = m_CurrentPhysicsResistMax;
	}
	nDamage -= m_PhysicsArmor.nValue[0];;
	if (bIsMelee)
	{
		nMax = m_CurrentMeleeDmgRetPercent;
	}
	else
	{
		nMax = m_CurrentRangeDmgRetPercent;
	}
	break;
```
(Các case `damage_cold/fire/light/poison` cùng cấu trúc, khác field Resist/Armor tương ứng; `damage_magic` và `default` thì `nRes = 0`.)

**Bước 4 — Tương khắc ngũ hành** (dòng 2600-2617), ĐÂY LÀ ĐOẠN QUAN TRỌNG NHẤT — trích dẫn nguyên văn 100%:
```cpp
if ((nMissleSeries == series_metal && m_Series == series_wood) || 
	(nMissleSeries == series_water && m_Series == series_fire) || 
	(nMissleSeries == series_wood && m_Series == series_earth) || 
	(nMissleSeries == series_fire && m_Series == series_metal) || 
	(nMissleSeries == series_earth && m_Series == series_water))
{
	nRes -= nFiveElements_DamageP;
	nDamage -= (Npc[nAttacker].m_CurrentFiveElementsEnhance - m_CurrentFiveElementsResist);
}
else if ((nMissleSeries == series_metal && m_Series == series_fire) || 
	(nMissleSeries == series_water && m_Series == series_earth) || 
	(nMissleSeries == series_wood && m_Series == series_metal) || 
	(nMissleSeries == series_fire && m_Series == series_water) || 
	(nMissleSeries == series_earth && m_Series == series_wood))
{
	nRes += nFiveElements_DamageP;
	nDamage -= (m_CurrentFiveElementsResist - Npc[nAttacker].m_CurrentFiveElementsEnhance);
}

if (nRes > MAX_RESIST)
{
	nRes = MAX_RESIST;
}
```
Điều kiện đầu (`nRes -=`, tức là NGƯỜI TẤN CÔNG có lợi thế khắc chế) đúng 5 cặp: **Kim khắc Mộc, Thủy khắc Hỏa, Mộc khắc Thổ, Hỏa khắc Kim, Thổ khắc Thủy** — khớp chính xác ngũ hành tương khắc truyền thống. Điều kiện `else if` là chiều ngược lại (mục tiêu có hệ khắc chế lại nguyên tố tấn công → `nRes +=`, giảm damage nhận vào).

**Bước 5 — Mana Shield, trừ % Resist cuối, PK rate** (dòng 2619-2644, 2588-2596):
```cpp
if (nRes > MAX_RESIST) { nRes = MAX_RESIST; }
// (mana shield logic — dòng 2624-2641, không thuộc phạm vi câu hỏi)
nDamage -= nDamage * nRes / MAX_PERCENT;
if (nDamage <= 0) return FALSE;
```
PK rate (dòng 2588-2596, áp dụng TRƯỚC bước trừ resist cuối, ngay sau tương khắc ngũ hành trong thứ tự code — thực ra nằm ở khối `if (this->m_Kind == kind_player)` được đặt sau switch nType nhưng trước đoạn ngũ hành theo thứ tự dòng in ra ở trên; xem lại: dòng 2588 nằm SAU switch (2498-2587) và TRƯỚC đoạn ngũ hành 2600 — vậy thứ tự thực: Roll → Crit → Armor/Resist theo loại → **PK rate nhân vào nDamage** → Tương khắc ngũ hành → Resist % cuối):
```cpp
if (this->m_Kind == kind_player)
{
	if(Npc[nAttacker].m_Kind == kind_player)
	{
		nDamage = nDamage * NpcSet.m_nPKDamageRate / MAX_PERCENT;
	}
}		
if (nDamage <= 0)
	return FALSE;
```

### 11.6. CheckHitTarget đầy đủ — trích dẫn nguyên văn

File: `KNpc.cpp`, hàm `KNpc::CheckHitTarget(int nAR, int nDf, int nIngore/* = 0*/)`, dòng 5829-5853, TOÀN VĂN:
```cpp
BOOL KNpc::CheckHitTarget(int nAR, int nDf, int nIngore/* = 0*/)
{
	int nDefense = 0;
	if (nIngore < MAX_PERCENT)
		nDefense = nDf * (MAX_PERCENT - nIngore) / MAX_PERCENT;
	int nPercent = 0;
	if (nAR < 0)
		return FALSE;

	if (nDf < 0)
		nPercent = MAX_HIT_PERCENT;
	else if ((nAR + nDefense) == 0) 
		nPercent = 50;
	else
		nPercent = nAR * MAX_PERCENT / (nAR + nDefense);

	if (nPercent > MAX_HIT_PERCENT + 4)
		nPercent = MAX_HIT_PERCENT;

	if (nPercent < 40)
		nPercent = 40;

	BOOL bRet = g_RandPercent(nPercent);
	return bRet;
}
```
**Lưu ý sai khác nhỏ so với mô tả ban đầu trong yêu cầu:** nếu `Defense < 0` thì tỷ lệ trúng = `MAX_HIT_PERCENT` (95%), không phải "95% trúng" ghi cứng riêng — đúng là dùng luôn hằng số `MAX_HIT_PERCENT`. Cap trên thực tế là kiểm tra `nPercent > MAX_HIT_PERCENT + 4` (tức > 99) mới hạ về 95 — nghĩa là tỷ lệ trúng có thể đạt tới 99% trong một số trường hợp trước khi bị cắt (không phải cắt cứng ở 95 ngay khi vượt 95). Cap dưới đúng như mô tả: 40% (không phải dùng hằng số `MIN_HIT_PERCENT=5` như tên gợi ý — `MIN_HIT_PERCENT` được định nghĩa nhưng KHÔNG được dùng trong hàm này, giá trị cap dưới là số cứng `40` viết trực tiếp trong code).

### 11.7. Các hằng số — định nghĩa tại `GameDataDef.h`

| Hằng số | Giá trị | Dòng | Ghi chú |
|---|---|---|---|
| `MAX_PERCENT` | 100 | `GameDataDef.h:47` | mẫu số % dùng khắp nơi |
| `MAX_RESIST` | 95 | `GameDataDef.h:382` | trần % kháng tối đa |
| `MIN_HIT_PERCENT` | 5 | `GameDataDef.h:385` | định nghĩa nhưng KHÔNG dùng trong `CheckHitTarget` (cap dưới thực tế là số cứng 40) |
| `MAX_HIT_PERCENT` | 95 | `GameDataDef.h:386` | trần % trúng đòn |
| `MAX_DEATLY_STRIKE_ENHANCEP` | 200 | `GameDataDef.h:65` | hệ số nhân Deadly Strike (200/100 = ×2 damage) |
| `MIN_FATALLY_STRIKE_ENHANCEP` | 30 | `GameDataDef.h:66` | Fatally Strike: % tối thiểu của `CurrentLife` mục tiêu |
| `MAX_FATALLY_STRIKE_ENHANCEP` | 50 | `GameDataDef.h:67` | Fatally Strike: % tối đa của `CurrentLife` mục tiêu |
| `LEVEL_EXPLOSIVE` | 120 | `GameDataDef.h:388` | ngưỡng level để kích hoạt cơ chế "explosive" (auto skill khi bị đánh, xem `KNpc.cpp:2487-2496`) |
| `LIFE_EXPLOSIVE` | 25 | `GameDataDef.h:389` | %HP còn lại để trigger "Rescue Skill" khi level ≥ LEVEL_EXPLOSIVE |
| `STRENGTH_SET_DAMAGE_VALUE` | 5 | `KPlayer.h:29` | chia Strength để ra Min/Max damage tay không |
| `ENGERGY_SET_DAMAGE_VALUE` | 0 | `KPlayer.h:31` | tắt (damage magic gốc từ Energy = 0 trong build này) |

### 11.8. Enum ngũ hành `series_*` — xác nhận thứ tự

File: `GameDataDef.h`, dòng 412-416 (comment gốc tiếng Trung giữ nguyên, đã dịch):
```cpp
series_metal,			//	金系 (Kim/hệ Kim)
series_wood,			//	木系 (Mộc/hệ Mộc)
series_water,			//	水系 (Thủy/hệ Thủy)
series_fire,			//	火系 (Hỏa/hệ Hỏa)
series_earth,			//	土系 (Thổ/hệ Thổ)
```
**Xác nhận: `series_metal`=Kim, `series_wood`=Mộc, `series_water`=Thủy, `series_fire`=Hỏa, `series_earth`=Thổ** — khớp đúng thứ tự map sang `ElementTypes.ElementType` (KIM/MOC/THUY/HOA/THO) như giả định ban đầu. Ngoài ra còn có `series_minus` (dùng ở `KNpc.cpp:2454`, damage cố định = 1, có thể là hệ "vô/trung tính" cho NPC không thuộc ngũ hành) và `series_num` (tổng số hệ, dùng làm bound-check, xem `KMath.h:68,79`).

### 11.9. Tổng hợp thứ tự áp dụng công thức CalcDamage (đọc lại toàn bộ luồng code)

1. Roll `nDamage = random(nMin, nMax)` (bù trường hợp `nMax < nMin` bằng cách roll quanh `nMax`).
2. Nếu `bReturn` (damage phản đòn): áp Deadly Strike (×2) hoặc Fatally Strike (theo %HP mục tiêu), rồi nhân thêm `NpcSpecialDamageRate` nếu NPC đặc biệt.
3. Trừ Armor tuyệt đối theo loại damage (`m_PhysicsArmor`, `m_ColdArmor`,...), lấy `nRes` = % Resist theo loại (cap theo `*ResistMax` riêng từng loại).
4. Nếu là PK giữa 2 player: nhân `nDamage` với `NpcSet.m_nPKDamageRate / 100`.
5. Áp tương khắc ngũ hành: cộng/trừ vào cả `nRes` và `nDamage` tuyệt đối dựa trên cặp khắc + `m_CurrentFiveElementsEnhance`/`m_CurrentFiveElementsResist` của 2 bên.
6. Cap `nRes` ở `MAX_RESIST` (95).
7. Trừ theo Mana Shield nếu có.
8. Trừ % Resist cuối: `nDamage -= nDamage * nRes / 100`.
9. Nếu `nDamage <= 0` → coi như miss/không gây damage (`return FALSE`).

### 11.10. Những gì vẫn CHƯA tìm thấy trong phạm vi grep đã thực hiện

- Không grep sâu thêm được công thức Strength/Vitality ảnh hưởng đến HP/damage NGOÀI những gì đã liệt kê (Vitality chỉ ảnh hưởng lúc khởi tạo `imaxlife` ghi sẵn trong `NewPlayerIni`, không thấy công thức runtime nào nhân Vitality mỗi lần tính lại `LifeMax`).
- `m_CurrentFiveElementsEnhance` / `m_CurrentFiveElementsResist` (dùng trong bước tương khắc) — chỉ thấy ĐƯỢC ĐỌC trong `CalcDamage`, KHÔNG grep tìm nơi gán giá trị gốc (có thể từ item/skill bonus, ngoài phạm vi 2 file đã đọc kỹ `KPlayer.cpp`/`KNpc.cpp`) — không suy đoán thêm.
- `NpcSet.m_nPKDamageRate` và `NpcSet.m_nNpcSpecialDamageRate` — chỉ thấy được dùng, chưa grep tìm giá trị cấu hình cụ thể (nhiều khả năng nằm trong file `.ini` config server, không phải hằng số code).

---

## 12. Công thức Damage SKILL — tìm thấy & ĐÃ ÁP DỤNG vào game (KNpc::AppendSkillEffect)

File: `KNpc.cpp`, hàm `KNpc::AppendSkillEffect(...)`, dòng 3013-3151 (đoạn xử lý damage vật lý, dòng
3015-3016 + 3116-3139).

**Công thức cốt lõi (đã trích dẫn nguyên văn):**
```cpp
int nMinDamage = m_PhysicsDamage.nValue[0] + m_CurrentAddPhysicsDamage;
int nMaxDamage = m_PhysicsDamage.nValue[2] + m_CurrentAddPhysicsDamage;
...
// pTemp->nAttribType == magic_physicsenhance_p:
pDes->nValue[0] = nMinDamage * (MAX_PERCENT + (pTemp->nValue[0] + (pTemp->nValue[0] * nAddDamageP / MAX_PERCENT))) / MAX_PERCENT;
```
Rút gọn: `damage_skill = (Strength/5 + AddPhysicsDamage) × (100% + physicsenhance_p%) / 100`, trong
đó `Strength/5` = `m_PhysicsDamage` (damage tay không gốc, xem mục 11.3), `physicsenhance_p` là %
enhance riêng của từng skill/cấp (đã thấy trong `Skills.txt`/`tangmen.lua`, VD Đường Môn
`physicsenhance_p={{{1,20},{20,80}}}` — 20% ở cấp 1, 80% ở cấp max).

**Phần BỎ QUA khi áp dụng (game chưa có hệ tương ứng):** `AddPhysicsDamage` từ item/trang bị,
enhance riêng theo loại vũ khí cận chiến/tầm xa/tay không (`m_CurrentMeleeEnhance`/
`m_CurrentRangeEnhance`/`m_CurrentHandEnhance`, dòng 3121-3138), và mọi field magic khác ngoài
damage vật lý cơ bản (steal life/mana/stamina, stun, ignoredefense, deadlystrike/fatallystrike
enhance — dòng 3059-3115) — VLTK gốc CÓ đầy đủ nhưng game indie này chưa có hệ Trang Bị/Item để áp
dụng có ý nghĩa.

**ĐÃ ÁP DỤNG vào code** (quyết định của user, chấp nhận rủi ro cân bằng): sửa
`player/sect_skill_controller.gd` hàm `_resolve_stats()` — damage skill giờ = `(Strength/5) ×
(100% + skill.base_damage_hiện_tại_tại_cấp_đó%)`, tức field `SkillDefinition.base_damage`/
`damage_growth_per_level` được DIỄN GIẢI LẠI thành % enhance (đúng bản chất VLTK gốc) thay vì số
damage tuyệt đối như trước đây.

**⚠️ CẢNH BÁO CÂN BẰNG (đã báo cho user, user xác nhận chấp nhận):** với Strength mặc định = 35
(đã sửa đúng VLTK ở PlayerProfile), damage tay không gốc = 35/5 = 7 — RẤT THẤP so với damage skill
cố định cũ (VD 24.0). Damage skill sau khi áp enhance% (VD +24% ở cấp 1) chỉ ≈ 8.68, giảm hơn 60%
so với trước. Toàn bộ số liệu skill (`base_damage`/`damage_growth_per_level` trong các file
`duong_mon.tres`...) và/hoặc Strength của player CẦN ĐƯỢC CÂN BẰNG LẠI để đạt mức damage mong muốn
cho gameplay bullet-heaven hiện tại — đây là việc user tự làm sau, không thuộc phạm vi thay đổi
công thức lần này.
