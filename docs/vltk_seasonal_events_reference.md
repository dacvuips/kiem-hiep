# Sự kiện theo mùa trong source VLTK gốc — đối chiếu

Kiểm tra ngày 2026-11-26: source gốc có đủ sự kiện theo dịp lễ trong năm không, và mỗi sự kiện có đủ công thức ép,
vật phẩm (tên + ảnh), kết quả, logic, UI không.

## Nguồn

Nguồn đầy đủ nhất là **server bản 15 phái `E:\jx15_src\script`** (giải nén bằng `python tools/vltk_source.py --extract`):

- `event/` — 93 thư mục sự kiện kiểu cũ (2006–2011), mỗi sự kiện tự viết công thức trong lua.
- `activitysys/config/<id>/` — 55 hoạt động kiểu mới (2010–2012, có cả bản VNG), khai báo theo bảng
  (`head.lua` = tên + ngày, `config.lua` = các bước/công thức, `extend.lua` = hàm thưởng, `variables.lua` = hằng vật phẩm).
- `missions/dragonboat`, `missions/springfestival` — phụ bản Đua thuyền rồng và Hội xuân.
- `item/<sự kiện>/` — script dùng vật phẩm sự kiện.
- Bảng vật phẩm sự kiện: `settings/item/004/magicscript.txt` (loại 6; cột 1 tên, cột 4 = mã `ParticularType`,
  cột 5 ảnh `.spr`, cột 9 mô tả, cột 10 script).

Các bộ khác ít hơn nhiều: anh-việt `Server + client full-001/server/script/event` (30/4, Đêm huy hoàng, Hoa đăng,
Ươm mầm), VS2022 (3 sự kiện). Thư mục `source_vo-lam-truyen-ky/vng` chỉ là client đã đóng pak, không có script.

Mã chữ: tiếng Việt trong lua/txt là **TCVN3** (`iconv -f TCVN5712-1 -t UTF-8`), chú thích và tên file tiếng Trung là GBK.

## Theo dịp trong năm

| Dịp | Có? | Nơi chứa chính |
|---|---|---|
| Tết Dương lịch | Có | `event/newyear_2006…2009`, hoạt động 25 (Nguyên Đán – Giáng Sinh 2010) |
| Tết Nguyên Đán | Có, nhiều nhất | `event/chunjie_jieri`, `springfestival07/08`, `spring_2006`, `yn_chunjie`, `ma_chunjie`, `chinesenewyear`, `missions/springfestival`, hoạt động 35, 38 |
| Valentine 14/2 | Có | `event/valentine2006/07/08`, `qingren_jieri`, hoạt động 19, 39, 1008 |
| Quốc tế Phụ nữ 8/3 | Có | `event/funv_jieri`, hoạt động 40 |
| Tết trồng cây | Có | hoạt động 28 |
| Giải phóng 30/4 | Có, nhiều | `event/jiefang_jieri` (41 file), `jiefangri2011`, `nanfangjiefangri`, hoạt động 1009 |
| Quốc tế Lao động 1/5, Tặng hoa | Có, ít | `event/laborday`, hoạt động 29 |
| Ngày của Mẹ | Sơ sài | `event/mothersday` (1 file nhỏ) |
| Đoan Ngọ | Có (kiểu cũ) | Đua thuyền rồng `missions/dragonboat`; Tống tẩu `global/ban_banh_u.lua` — mua bánh chưng 2.000 lượng, nâng cấp chuỗi bánh chưng có tỷ lệ (xem mục dưới) |
| Sinh nhật VLTK / tháng 6 | Có | hoạt động 31, 1010 (làm bánh kem), `event/birthday_jieri` |
| Trung Thu | Có, đầy đủ | `event/zhongqiu_jieri` (2008/2009/2010), `zhongqiu2007`, `mid_autumn`, `mid_autumn06`, hoạt động 21 |
| Quốc khánh 2/9 | Có | `event/guoqing_jieri`, `nationalday_2006`, `2006vm_nationalday`, hoạt động 33 |
| Phụ nữ Việt Nam 20/10 | Có | hoạt động 1007 |
| Nhà giáo 20/11 | Có | `event/jiaoshi_jieri`, `teacherday`, `teachersday06_v`, `teacher_day_200711`, hoạt động 22, 30 |
| Giáng Sinh | Có, đầy đủ | `event/shengdan_jieri`, `xmas06/07_makesnowman`, `vnchristmas2006/07`, `item/christmas2011`, hoạt động 2, 37 |
| **Nguyên Tiêu, Thất Tịch, Trùng Cửu, Lạp Bát** | **Không** | thư mục `*_jieri` chỉ có `help.lua` (bảng quy ước đặt tên, không logic); chỉ còn vài vật phẩm lẻ trong bảng |
| **Halloween, Giỗ Tổ Hùng Vương** | **Không có sự kiện riêng** | Hùng Vương chỉ có câu đố đèn lồng (`settings/event/riddle/huadeng.txt`). NPC thử nghiệm của bản 15 phái ghi "Giỗ Tổ Hùng Vương Mùng 10 Tháng 03" nhưng trỏ tới sự kiện **Mùng 3 tháng 3 (2007) nấu bánh chay** — xem mục dưới |

Ngoài ra có nhiều hoạt động không theo lễ: Mừng phiên bản mới (1000, 1003), Ngôi sao tuyết (1002), Phong Vân Lệnh Bài
(1005), đổi Hành Hiệp Lệnh (10), Phú Quý Cẩm Hạp (500)…

## Công thức ép, vật phẩm, kết quả, logic

- **Hoạt động kiểu mới:** 154 công thức (`szMessageType = "CreateCompose"`). Mỗi công thức có tên, danh sách nguyên liệu
  (`AddOneMaterial`: tên, mã `{6,1,X}` hoặc hằng trong `variables.lua`, số lượng; ngân lượng là `{nJxb=1}`) và kết quả
  (`PlayerFunLib:GetItem` ra vật phẩm cố định, hoặc hàm `ThisActivity:Xxx` trong `extend.lua` quay thưởng ngẫu nhiên).
  Đã kiểm bằng script: **mọi mã vật phẩm đều có trong bảng vật phẩm, mọi hàm kết quả đều được định nghĩa**
  (`AddTask`/`AddTaskDaily` nằm ở lớp gốc `activitysys/activity.lua`).
  Bộ xử lý chung: `activitysys/detailtype/createcompose.lua` (tham số: tiêu đề, ô trống cần có, ép từ hành trang hay
  từ ô nộp đồ, số lần ép tối đa mỗi lượt).
- **Sự kiện kiểu cũ:** công thức viết thẳng trong lua. Ví dụ Trung Thu 2008
  (`event/zhongqiu_jieri/200808/sanyue/hecheng.lua`): 2 mỗi loại lồng đèn (bươm bướm/ngôi sao/ống/tròn) + 1 phụ liệu
  (+ 30.000 lượng ở công thức 2) → Bánh trung thu Vọng Nguyệt / Kiến Nguyệt / Thưởng Nguyệt. Mới đọc mẫu Trung Thu,
  các sự kiện kiểu cũ khác chưa kiểm từng cái.
- **Ngày diễn ra:** ghi cứng theo năm cũ (`nStartDate = 201112010000`…). Muốn dùng lại phải đổi sang lịch lặp hằng năm;
  lễ âm lịch (Tết, Trung Thu, Đoan Ngọ…) cần đổi ngày âm → dương.
- **UI:** không sự kiện nào có màn ép riêng. Luồng chung: nói chuyện NPC (Đại Sứ Hoạt Động…) → chọn món muốn đổi → nhập
  số lượng → đặt đồ vào ô nộp (`room_giveitem`) hoặc trừ thẳng trong hành trang. Phần khung này có sẵn trong engine gốc.

## Thiếu ảnh vật phẩm

Kiểm trong client 15 phái, client VNG (`vng/.../data/*.pak`) và bản giải nén MiTom.

**Thiếu thật (19 vật phẩm, đều là sự kiện VNG 2012):**

- Hoạt động 4 (tháng 5/2012): Hạt Mầm 3157, Túi Thuốc Tăng Trưởng 3158, Bình Nước 3159, Phẩm Màu Sắc 3160,
  Hoa Phượng Đỏ/Tím/Trắng 3161–3163 (`\spr\vng\item\201205\`).
- Hoạt động 20 (lúa nước 6/2012): Lưỡi Liềm Sắt 3197, Túi Hương 3201 (`\spr\vng\item\120530_lua_nuoc\`).
- Hoạt động 1010 (bánh kem 6/2012): Bột Mì, Bơ, Sữa, Chocolate, Trái Cây, Đường, Bánh Kem Thường/Chocolate/Trái Cây,
  Bánh Sinh Nhật VLTK — 30204–30213 (`\spr\vng\item\eventthang062012\`).

**Chưa chắc** (tên file ảnh tiếng Trung, script kiểm đọc sai mã nên không tra được): Dây Hồng 2696/3111,
Quỳnh Tương Ngọc Diệp 2703, Thùng gỗ 2736, Thùng Nước Đầy 2737, Hạt Giống Hoa Hồng 3109.

## Sự kiện kiểu cũ tìm thêm (1 và 4 đã đưa vào tab Sự kiện Năm, 2 và 3 chưa)

Rà lại toàn bộ script (giải mã TCVN3) theo từ khóa bánh chưng / bánh tét / gạo nếp / Hùng Vương — có thêm 4 sự kiện
viết kiểu cũ (không qua activitysys nên bộ xuất `tools/export_seasonal_events.py` không thấy):

1. **[ĐÃ LÀM — gộp vào thẻ Tết Nguyên Đán] Tết 2008 — Gói bánh chưng** (`event/newyear_2008/zaozongbing/head.lua`, `item/newyear_2008/makezongzi/*.lua`,
   `event/newyear_2008/cailu/chunjiecailu.lua`). Đầy đủ nhất:
   - Túi mừng xuân `6_1_1652` (quái rơi) mở ra 1 món: Lá bánh 38,8% · Gạo nếp 29,1% · Đậu xanh 19,4% · Thịt heo 9,7% ·
     Phúc / Lộc / Thọ mỗi thứ 1%.
   - Thợ bánh: 4 Lá bánh + 3 Gạo nếp + 2 Đậu xanh + 1 Thịt heo → Bánh chưng thường (20.000 lượng); thêm Bí quyết thượng
     hạng `1660` / hảo hạng `1661` → Bánh chưng thượng hạng `1662` / hảo hạng `1663` (0 lượng). Cấp ≥ 50.
   - Ăn: thượng hạng 2.000.000 kinh nghiệm + 1 món ngẫu nhiên (Thiên Sơn Bảo Lộ, Quế Hoa Tửu, Mặt nạ ông địa, Ngân/Kim/
     Ngọc Bài, Huyền Tinh 3–8, Tiên Thảo Lộ…); hảo hạng 1.500.000 + 1 món (Phúc Duyên Lộ, Bảo Lộ, Quế Hoa Tửu, mặt nạ,
     Huyền Tinh 3–5…); thường 500.000. Trần tổng 2 tỷ kinh nghiệm.
   - Hái lộc: treo liễn Phúc + Lộc + Thọ (9.999 lượng, tối đa 20 lần, theo khung giờ) → Phúc Duyên Lộ Trung 75% / Đại 20% /
     Tiên Thảo Lộ 5% + kinh nghiệm ngẫu nhiên.
   - Bí quyết `1660/1661`: gốc VNG không thấy nguồn rơi (chỉ NPC thử nghiệm phát) — trong game **tự thêm** vào Túi mừng
     xuân (thượng hạng 0,5%, hảo hạng 1%; Lá bánh giảm 38,8 -> 37,3%).
2. **Tết 2011 — Bánh Tét / Bánh Chưng** (`vng_event/lunaryear2011`): Bánh Tét `30087` rơi 5% ở 10 map luyện công;
   Bánh Chưng `30086` từ boss, Tống Kim, Vượt Ải 17. Ăn Bánh Tét 500.000 kinh nghiệm (tối đa 1.000 cái), Bánh Chưng
   1.000.000 (+50% Thiệp Năm Mới, tối đa 3.000). Thợ bánh: 2 Bánh Chưng + 1 Giấy gói bánh `30085` → Bánh Chưng Đặc Biệt
   (Giấy gói không có nguồn trong script — gốc bán Kỳ Trân Các). Thiệp Xuân (Thủy Tinh + Tinh Hồng + Phúc Duyên Lộ) treo
   Cây Mai.
3. **Mùng 3 tháng 3 (2007) — Nấu bánh chay** (`event/cookies2007`, `item/cookies2007`): 20 Túi hàng hóa `1393` (quái rơi)
   + 100.000 lượng → Bao nguyên liệu làm bánh `1394`. Tổ đội đúng 2 người **nam + nữ**, trong thành / thôn / khu phong
   cảnh, tối đa 8 lần/ngày → đặt Bếp lửa; mini-game 4 thao tác (đãi đậu, nhào bột, bỏ nhân, thêm củi) bấm càng đúng giờ
   càng nhiều điểm (10/8/7/6/5) → 9 bánh chia Đặc biệt `1395` (800.000 kn) / Thường `1396` (500.000) / Chưa chín
   `1397` (300.000) theo điểm. Trần 300 triệu kinh nghiệm. Không phải công thức ép — cần làm mini-game riêng.
4. **[ĐÃ LÀM — thẻ "Tết Đoan Ngọ", mùng 5/5 âm, khung −6..+7 ngày tự đặt] Đoan Ngọ — Bánh chưng Tống tẩu** (`global/ban_banh_u.lua`): mua bánh chưng Hạt dẻ / Thịt heo / Thịt bò / Thập cẩm
   2.000 lượng; nâng cấp Thập cẩm → Mật ong → Bát bửu → Bách quả → Thượng hạng → Khuất Nguyên (1.000 lượng/lần, tỷ lệ
   gốc 50 / 30 / 30 / 30 / 3% có cộng thêm; thất bại rơi về Thập cẩm).
   - Nguyên liệu là vật phẩm nhiệm vụ `4_394..399` (Táo đỏ, Hạt dẻ, Lá bánh, Gạo nếp, Thịt heo, Thịt bò), Khuất Nguyên Mật
     phương `4_404` (+10/+20/+10/+5/+3%, mất khi dùng), Gạo nếp may mắn `4_405`. Bảng gốc ghi tên `4_399` là "Thịt heo" (trùng
     398) — đã sửa thành "Thịt bò" theo mô tả (`MISC_NAME_FIX` trong `tools/import_vltk_items.py`).
   - Mỗi lần nâng tốn 1.000 lượng + **1 nguyên liệu bất kỳ** (gốc lấy món đầu tiên có trong túi theo thứ tự 394..399) — trong
     dữ liệu là dòng nguyên liệu `{"any": [...], "count": 1}`; hỏng trả lại Thập cẩm (`fail_result`).
   - Ăn: Hạt dẻ = tốc đánh + tốc ra chiêu +20, Thịt heo = sinh lực / nội lực tối đa +100%, Thịt bò = kháng tất cả +5%
     (10 phút, skill 401–403 → `PotionEffect.SPECIAL_ITEM_EFFECTS`), May mắn +30 may mắn 30 phút; Thập cẩm 1.000, Mật ong
     5.000, Bát bửu 30.000, Bách quả 100.000, Thượng hạng 500.000, Khuất Nguyên 200 triệu kinh nghiệm (1 lần / đợt).
   - Bỏ: bánh Nhân táo (vật phẩm 1_7_0 không có trong bảng); Thượng hạng thành công trừ thêm thịt heo + thịt bò "nếu có";
     giãn cách 1 giờ giữa 2 lần ăn và trần 20 triệu kinh nghiệm của bánh Thập cẩm.

Ảnh của mọi vật phẩm trên đều đã có trong `data/items/misc_items.json`.

## Đã làm trong game — tab "Sự kiện Năm"

Panel Sự kiện (Hub) có 2 tab: **Sự kiện Ngày** (danh sách cũ, giữ nguyên) và **Sự kiện Năm**.

- **Dữ liệu:** `python tools/export_seasonal_events.py` -> `data/events/seasonal_events.json`. Mỗi dịp lấy 1 hoạt động đầy đủ
  nhất (bảng `MANIFEST` trong tool): Tết Nguyên Đán (35), Valentine (1008), 8/3 (40), 30/4 (1009), Sinh nhật VLTK (31),
  Trung Thu (21), Quốc khánh (33), 20/10 (1007), 20/11 (30), Giáng Sinh (37); thêm sự kiện kiểu cũ đọc riêng (`EXTRAS`):
  Trung Thu 2006, Tết 2008 gói bánh chưng, Đoan Ngọ (`act: None`). Bỏ: Tết trồng cây, Tết Dương lịch (không có
  công thức ép thật). Tool tự đọc bảng lua: công thức, hàm thưởng (`tbAwardTemplet`), tỷ lệ thành công (`CheckRandom`),
  thưởng mốc (`if CheckTask(x, N, "", "==")`), giới hạn dùng, cấp tối thiểu, nguồn nguyên liệu.
- **Lịch:** ngày lễ của năm hiện tại (âm lịch đổi bằng `systems/events/lunar_calendar.gd`, giờ VN +7) + độ lệch ngày của
  đợt gốc. VD Tết 2027 (06/02) -> 15/01–14/02/2027; Giáng Sinh -> 01/12–31/12.
- **Trung Thu = lồng đèn giấy kiếng bản 2006** (`event/mid_autumn06`, khung −6..+7 ngày quanh rằm): Hộp vật liệu lồng đèn
  (đánh quái rơi) mở ra giấy kiếng vàng/lam/lục/đỏ/cam, thanh tre, dây cói, nến theo tỷ lệ `tab_material`; 6 công thức theo
  `tab_Lightcage` (bươm bướm 2 vàng … cá chép 1 cam, kéo quân 1 giấy mỗi màu; + tre + cói + nến + 1.000–5.000 lượng). Thắp
  đèn 1241–1246 = nhân đôi kinh nghiệm 10–60 phút (bảng `PotionEffect.SPECIAL_ITEM_EFFECTS`, nút "Thắp Đèn"). Đèn "đặc biệt"
  1229–1234 của gốc không có trong bảng vật phẩm bản 15 phái nên không làm. Từ hoạt động 21 chỉ giữ đổi Ngũ Hành Kỳ Thạch và
  Bánh Trung Thu các thành (bỏ lồng đèn làm từ bánh).
- **Logic:** `systems/events/seasonal_events.gd` (dùng chung máy chơi + game server):
  - ép: đặt nguyên liệu -> tự tính số lần ép tối đa; phần dư giữ lại hành trang; "Tự động" thử mọi thứ tự công thức (≤ 6)
    để ép NHIỀU thành phẩm nhất (hoà thì thừa ít nguyên liệu nhất); thất bại vẫn mất nguyên liệu (đúng gốc);
  - thành phẩm vào hành trang, đầy thì sang rương; kiểm tra đủ chỗ trước khi trừ nguyên liệu;
  - mở / dùng vật phẩm qua `ItemConsumer.use_item` (nút Dùng trong hành trang): quay thưởng đúng thuật toán
    `tbAwardTemplet:GivByRandom`, thưởng mốc, giới hạn số lần mỗi đợt (`PlayerProfile.event_counters`, tách theo năm);
  - đồ có hạn "cuối đợt" trong source hết hạn khi đợt kết thúc;
  - công thức có thể có `limit` (lần / đợt — VD treo liễn 20 lần), `fail_result` (thất bại vẫn nhận lại — VD Đoan Ngọ) và
    dòng nguyên liệu `any` (1 món bất kỳ trong nhóm, trừ theo thứ tự).
- **Hộp sự kiện (chỉ online):** mỗi sự kiện 1 hộp `ev_box_<id>` ("Hộp <tên sự kiện>", tạm chung ảnh Hộp quà trắng `baise_lipinhe` — thành phẩm ép Lễ Tình Nhân
  — đổi ảnh riêng: `BOX_ICON` / `BOX_ICON_DEFAULT` trong tool). Trong đợt, MỌI quái (trừ PUBG / Lộn Xộn) rơi hộp với tỷ lệ `BOX_DROP_RATE` (10% mỗi
  lần hạ quái) — `SeasonalEvents.roll_monster_drops()` gọi trong `GameServer` lúc tung đồ rơi; offline KHÔNG rơi. Mở hộp ra 1 nguyên
  liệu ngẫu nhiên theo **bậc hiếm** (`BOX_TIERS` trong tool): Thường ×10 / Hơi hiếm ×4 / Hiếm ×1,2 / Rất hiếm ×0,25, nhân số cái
  công thức cần (tối đa 5) rồi quy về 100% — cùng bậc thì món cần nhiều ra nhiều hơn. VD Tết: Lá bánh 19% · Gạo 14,3% · Đậu 9,5%
  · Thịt heo + 10 trái cây 4,8% · Mâm Bạc 1,9% · Phúc/Lộc/Thọ, Mâm Vàng, Bí quyết hảo hạng 0,57% · Bí quyết thượng hạng 0,12%;
  Trung Thu: giấy vàng 31,7% … giấy cam 0,4%; Đoan Ngọ: 6 nguyên liệu 16,5%, Gạo nếp may mắn 1%, Mật phương 0,21%. Bỏ đá quý /
  thuốc chung. Thẻ sự kiện có dòng
  "Vật phẩm", Hướng dẫn có mục "Vật phẩm rơi từ quái" (tỷ lệ từng món).
- **Mỗi quái tối đa 1 hộp:** tung 1 lần `BOX_DROP_RATE` (10%); nhiều sự kiện cùng diễn ra (VD GM kích hoạt Giáng Sinh lúc 20/11 còn
  chạy) thì chọn ngẫu nhiên hộp của 1 sự kiện.
- **Trang bị thưởng game chưa có:** bảng trang bị của game mới có 5 mặt nạ (Tân Thủ, Liễu Thanh Thanh, Đạo Thanh Chân Nhân, Chiến
  Thần, Hoàng Kim) — các mặt nạ sự kiện gốc (Đầu ông địa 201, Nguyên soái 447, Anh hùng chiến trường, Vương Giả, Quỷ ảnh 455, Cửu
  mệnh 454, Trường công 479, Kiên ngạnh 480) chưa nhập. Tool bỏ các phần thưởng đó (nhóm quay ngẫu nhiên chia lại tỷ lệ cho món
  còn lại) và bỏ 4 công thức Trung Thu đổi Ngũ Hành Kỳ Thạch lấy mặt nạ — nhập mặt nạ vào equipment.json rồi chạy lại tool là tự có.
- **Chưa tới đợt:** thẻ ẩn nút Chế tạo (cửa sổ Chế tạo cũng chặn ép ngoài đợt).
- **Lịch GM:** bảng GM › "9. Sự Kiện Năm": mỗi sự kiện có ô ngày bắt đầu / kết thúc (dd/mm/yyyy giờ VN) + "Lưu", "Kích hoạt ngay
  (7 ngày)" (0:00 hôm nay → hết ngày thứ 7) và "Mặc định" (xoá, về lịch gốc). Lịch GM thay đợt gốc cho tới khi hết hạn rồi lịch gốc
  chạy lại; thẻ hiện "[GM đặt lịch]". Offline lưu `user://seasonal_event_override.json`. Online: `C_EVENT` op `gm_time` / `gm_reset`
  (server kiểm `is_gm`) → server tài khoản `POST /internal/game/event-override` (bảng `event_overrides`, migration 0016 ở repo
  kiem-hiep-server) → heartbeat 5 giây trả `event_overrides` cho MỌI tiến trình (thế giới / Vượt Ải / Tống Kim / đấu trường) → mỗi
  tiến trình gửi người chơi `S_EVENT_TIMES` (49) lúc vào và khi đổi. Máy chơi online chỉ nhận lịch server; ngắt kết nối thì về lịch máy.
- **Online:** gói `C_EVENT` (39) — server ép / mở trên hồ sơ của nó rồi gửi S_NOTICE + S_PROFILE; `ProfileGuard` giữ
  `event_counters` của server. Cần build lại image game server.
- **UI:** `ui/events/seasonal_event_ui.gd` (thẻ, ô ảnh, cửa sổ Hướng dẫn), `ui/events/event_craft_window.gd` (Chế tạo:
  hành trang trái, lưới ô nhỏ phải như Giao dịch, kéo thả / bấm + nhập số lượng, "Tự đặt nguyên liệu", xem trước).
  Ảnh đại diện thẻ = thành phẩm (`cover` trong MANIFEST nếu có — Tết: Mâm Vàng Ngũ Quả, 30/4: Mũ Hòa Bình; không thì
  thành phẩm công thức đầu, VD Cuốn Sách, Hộp quà giáng sinh, Lồng đèn bươm bướm).
- **Kiểm thử:** `tests/seasonal_events_tests.tscn` (lịch âm, đợt, ép, tối ưu, mua, mở, mốc, lưu) và
  `tests/seasonal_events_ui_tests.tscn` (chạy có cửa sổ + `SHOT_DIR=...` để chụp ảnh).
- **Chưa làm:** nguồn nguyên liệu (quái rơi, Tống Kim, Vượt Ải… theo `material_sources`) chưa nối vào game, nên hiện chỉ có
  nguyên liệu qua GM / Admin; điểm cống hiến bang hội trong bảng thưởng bị bỏ; giới hạn "chỉ dùng trong thành" của gốc bị bỏ.

## Phụ lục — 154 công thức của hoạt động kiểu mới

Sinh tự động từ `activitysys/config/*/config.lua`. Ký hiệu `[6,1,X]` = mã vật phẩm loại 6; hàm `xxx()` = kết quả
ngẫu nhiên, xem `extend.lua` cùng thư mục. Tên có "(tên gốc tiếng Trung)" là hoạt động chỉ đặt tên tiếng Trung.

### Hoạt động 2 — Hoạt động Giáng Sinh 2011 (201112010000 → 201201010000)

- **get award**: 1× Nón giáng sinh [6,1,3072] → (xem extend.lua)

### Hoạt động 4 — 2012-05 (201205030000 → 201206010000)

- **Buy_NongYao**: 10000 lượng → Túi Thuốc Tăng Trưởng [6,1,3158]

### Hoạt động 5 — (tên gốc tiếng Trung) (dài hạn)

- **Đổi [Hoàn mỹ] Hồng ảnh hồng tụ chiêu**: 50× Hoàn Mỹ Kim Bài [6,1,2129] → (xem extend.lua)
- **Đổi [Hoàn mỹ] Hồng ảnh qua kiếm tây phương**: 50× Hoàn Mỹ Kim Bài [6,1,2129] → (xem extend.lua)
- **Đổi [Hoàn mỹ] Hồng ảnh thẩm viên uyển**: 50× Hoàn Mỹ Kim Bài [6,1,2129] → (xem extend.lua)
- **Ta muốn đổi [Hoàn Mỹ] Hồng ảnh Mục Túc**: 50× Hoàn Mỹ Kim Bài [6,1,2129] → (xem extend.lua)
- **Ta muốn đổi [Cực phẩm] Hồng ảnh Hồng Tụ Chiêu**: 50× Hoàn Mỹ Kim Bài [6,1,2129] → (xem extend.lua)
- **Ta muốn đổi [Cực phẩm] Hồng ảnh Kiếm Qua Tây Phương**: 50× Hoàn Mỹ Kim Bài [6,1,2129] → (xem extend.lua)
- **Ta muốn đổi [Cực phẩm] Hồng ảnh Trầm Viên Vãn Túy**: 50× Hoàn Mỹ Kim Bài [6,1,2129] → (xem extend.lua)
- **Ta muốn đổi [Cực phẩm] Hồng ảnh Mục Túc Tương Vong**: 50× Hoàn Mỹ Kim Bài [6,1,2129] → (xem extend.lua)

### Hoạt động 10 — Đổi phần thưởng Hành Hiệp Lệnh (dài hạn) (dài hạn)

- **XingXiaLing_QingJuLing**: 10× Hành Hiệp Lệnh [6,1,2566] → Thanh Câu Lệnh [6,1,2369]
- **XingXiaLing_YunLuLing**: 26× Hành Hiệp Lệnh [6,1,2566] → Vân Lộc Lệnh [6,1,2353]
- **XingXiaLing_CangLangLing**: 170× Hành Hiệp Lệnh [6,1,2566] → Thương Lang Lệnh [6,1,2352]
- **XingXiaLing_XuanYuanLing**: 600× Hành Hiệp Lệnh [6,1,2566] → Huyền Viên Lệnh [6,1,2351]
- **XingXiaLing_XiuFuShenYou**: 1× Hành Hiệp Lệnh [6,1,2566] → Tu Phục Thần Du [6,1,2565]

### Hoạt động 11 — Hoạt động tháng 4 năm 2012 (201204020000 → 201205010000)

- **Hợp thành áo Lính Mới**: 5× Mảnh Vải + 5× Khuy áo + 5× áo Lính Bị Rách + 1× Mảnh Vải Màu Xanh Lá + 1× Cuộn Chỉ → (xem extend.lua)
- **Hợp thành áo Lính Đã Sửa**: 5× Mảnh Vải + 5× Khuy áo + 5× áo Lính Bị Rách + 1× Mảnh Vải Màu Xanh Lá → (xem extend.lua)
- **Hợp thành áo Lính Mới (điểm kinh nghiệm)**: 5× Mảnh Vải + 5× Khuy áo + 5× áo Lính Bị Rách + 1× Mảnh Vải Màu Xanh Lá + 1× Cuộn Chỉ → (xem extend.lua)

### Hoạt động 12 — (tên gốc tiếng Trung) (201204020000 → 205005010000)

- **buy healing bag**: 50000 lượng → Gia Huyết Phù [6,1,3146]

### Hoạt động 15 — (tên gốc tiếng Trung) (dài hạn)

- **Hàng rong bán vỏ bóng hoàng kim_2**: 30000 lượng → Vỏ bóng hoàng kim [6,1,2358]
- **Ghép thành bóng da**: 1× Ruột cao su [6,1,2361] + 1× Chất dẻo [6,1,2362] → Bóng da [6,1,2363]
- **Ghép thành bóng hoàng kim**: 1× Ruột cao su [6,1,2361] + 1× Chất dẻo [6,1,2362] + 1× Vỏ bóng hoàng kim [6,1,2358] → Bóng hoàng kim [6,1,2364]
- **Ghép thành bóng bạch kim**: 1× Ruột cao su [6,1,2361] + 1× Chất dẻo [6,1,2362] + 1× Vỏ bóng bạch kim [6,1,2359] → Bóng bạch kim [6,1,2365]
- **Ghép thành Vinh Diệu Chi Y**: 99× Tiểu Cầu chi y [6,1,2367] → (xem extend.lua)
- **Ghépt hành Tinh Chuẩn Chi Ngoa**: 99× Tiểu túc chi ngoa [6,1,2368] → (xem extend.lua)

### Hoạt động 18 — (tên gốc tiếng Trung) (dài hạn)

- **Đổi tiểu tự khung**: 1× Thất [6,1,2405] + 1× Thành [6,1,2406] + 1× Đại [6,1,2407] + 1× Chiến [6,1,2408] + 10000 lượng + 1× Phúc Duyên Lộ (Tiểu)  [6,1,122] → Tiểu Tự Khung [6,1,2418]
- **Đổi trung tự khung (huyền tinh)**: 1× Thất [6,1,2405] + 1× Thành [6,1,2406] + 1× Đại [6,1,2407] + 1× Chiến [6,1,2408] + 60000 lượng + 1× Huyền Tinh Khoáng Thạch  [6,1,147] → Khung Tranh [6,1,2419]
- **Đổi trung tự khung (Phúc duyên lộ)**: 1× Thất [6,1,2405] + 1× Thành [6,1,2406] + 1× Đại [6,1,2407] + 1× Chiến [6,1,2408] + 40000 lượng + 1× Phúc Duyên Lộ (Đại)  [6,1,124] → Khung Tranh [6,1,2419]
- **Đổi trang bị phiên bản mới**: 1× Thất [6,1,2405] + 1× Thành [6,1,2406] + 1× Đại [6,1,2407] + 1× Chiến [6,1,2408] + 1× Mảnh thiên thư [6,1,2409] → (xem extend.lua)
- **Đổi nhất kỷ càn khôn phù**: 300× Ngũ Hành Kỳ Thạch [6,1,2125] → Nhất Kỷ Càn Khôn Phù [6,1,2126]
- **Đổi mặt nạ cổ truyền**: 30× Ngũ Hành Kỳ Thạch [6,1,2125] → (xem extend.lua)
- **Đổi mặt nạ áo dài**: 30× Ngũ Hành Kỳ Thạch [6,1,2125] → (xem extend.lua)
- **Đổi mặt nạ quỷ ảnh**: 5× Ngũ Hành Kỳ Thạch [6,1,2125] → (xem extend.lua)
- **Đổi mặt nạ cửu mệnh**: 5× Ngũ Hành Kỳ Thạch [6,1,2125] → (xem extend.lua)
- **Đổi ngựa**: 81× Thần Hành Toái Phiến [6,1,2410] → (xem extend.lua)

### Hoạt động 20 — (tên gốc tiếng Trung) (201206010000 → 201207010000)

- **compose**: 3199× Lúa Xanh → (xem extend.lua)
- **buy item**: 100000 lượng → Lưỡi Liềm Sắt [6,1,3197]
- **compose**: 3200× Lúa Vàng → (xem extend.lua)

### Hoạt động 21 — Hoạt động trung thu 2010 (201011160000 → 201012060000)

- **Mua bánh nhân thịt**: 30000 lượng → Bánh nhân thịt [6,1,2500]
- **Hợp thành lồng đèn bươm bướm**: 1× Bánh Hạt Sen [6,1,2496] + 1× Bánh Đậu Xanh [6,1,2497] + 1× Bánh Khoai Môn [6,1,2498] → Lồng đèn bươm bướm [6,1,2502]
- **Hợp thành lồng đèn ngôi sao**: 1× Bánh Hạt Sen [6,1,2496] + 1× Bánh Đậu Xanh [6,1,2497] + 1× Bánh Khoai Môn [6,1,2498] + 1× Bánh dẻo [6,1,2499] → Đèn ngôi sao [6,1,2503]
- **Hợp thành lồng đèn ống**: 1× Bánh Hạt Sen [6,1,2496] + 1× Bánh Đậu Xanh [6,1,2497] + 1× Bánh Khoai Môn [6,1,2498] + 1× Bánh nhân thịt [6,1,2500] → Lồng đèn ống [6,1,2504]
- **Hợp thành lồng đèn tròn**: 1× Bánh Hạt Sen [6,1,2496] + 1× Bánh Đậu Xanh [6,1,2497] + 1× Bánh Khoai Môn [6,1,2498] + 1× Bánh thập cẩm [6,1,2501] → Lồng đèn tròn [6,1,2505]
- **Nộp lồng đèn kéo quân**: 1× Lồng đèn kéo quân [6,1,2506] → (xem extend.lua)
- **Đổi mặt nạ quỷ ảnh**: 5× Ngũ Hành Kỳ Thạch [6,1,2125] → (xem extend.lua)
- **Đổi hồi thiên tái tạo cẩm nang**: 3× Ngũ Hành Kỳ Thạch [6,1,2125] → Cẩm nang thay đổi trời đất [6,1,1781]
- **Đổi nhất kỷ càn khôn phù**: 300× Ngũ Hành Kỳ Thạch [6,1,2125] → Nhất Kỷ Càn Khôn Phù [6,1,2126]
- **Đổi mặt nạ cửu mệnh**: 5× Ngũ Hành Kỳ Thạch [6,1,2125] → (xem extend.lua)
- **Đổi mặt nạ trường công**: 5× Ngũ Hành Kỳ Thạch [6,1,2125] → (xem extend.lua)
- **Đổi Mặt nạ kiên ngạnh**: 20× Ngũ Hành Kỳ Thạch [6,1,2125] → (xem extend.lua)

### Hoạt động 22 — 2010Event nhà giáo_ Hoạt động (201011160000 → 201012130000)

- **Đổi tơ tằm hương bao**: 1× Tây Hồ Long Tĩnh Trà [6,1,2573] + 1× Tơ Tằm [6,1,2574] → Tơ Tằm Hương Bao [6,1,2577]
- **Đổi ngũ sắc hương bao**: 1× Tây Hồ Long Tĩnh Trà [6,1,2573] + 1× Sợi chỉ màu [6,1,2575] → Ngũ Sắc Hương Bao [6,1,2578]
- **Đổi trung dược hương bao**: 1× Tây Hồ Long Tĩnh Trà [6,1,2573] + 1× Trung Dược [6,1,2576] → Trung Dược Hương Bao [6,1,2579]
- **Mua tơ lụa**: 30000 lượng → Tơ Tằm [6,1,2574]

### Hoạt động 24 — (tên gốc tiếng Trung) (dài hạn)

- **Phi phong Lăng Vân**: 66× Tinh lực → (xem extend.lua)
- **Phi phong Tuyệt Thế**: 462× Tinh lực → (xem extend.lua)
- **Phi phong Phá Quân**: 1386× Tinh lực → (xem extend.lua)
- **Phi phong Ngao tuyết (Dịch chuyển tức thời)**: 2310× Tinh lực → (xem extend.lua)
- **Phi phong Kinh Lôi (Dịch chuyển tức thời)**: 3234× Tinh lực → (xem extend.lua)
- **Phi phong Ngự Phong (Dịch chuyển tức thời )**: 4620× Tinh lực → (xem extend.lua)
- **Phi phong Ngạo Tuyết (Xác suất hóa giải sát thương)**: 2310× Tinh lực → (xem extend.lua)
- **Phi phong Kinh Lôi (Xác suất hóa giải sát thương)**: 3234× Tinh lực → (xem extend.lua)
- **Phi phong Kinh Lôi ( Trọng kích )**: 3234× Tinh lực → (xem extend.lua)
- **Phi phong Ngự Phong (Xác suất hóa giải sát thương)**: 4620× Tinh lực → (xem extend.lua)
- **Phi phong Ngự Phong (Trọng kích)**: 4620× Tinh lực → (xem extend.lua)

### Hoạt động 26 — Đại Yến Quần Hiệp năm 2011 (201101230000 → 201102210000)

- **Đổi lấy Giải Tửu Hoàn**: 100000 lượng → Giải Tửu Hoàn [6,1,2695]

### Hoạt động 28 — Hoạt động Tiết Trồng Cây 2011 (201103280000 → 201104050000)

- **Đưa Lão Nông Long Âm Thánh Thủy**: 1× Long Âm Thánh Thủy [6,1,2738] → `OnGiveLongYinShengShui()`

### Hoạt động 29 — Hoạt động Tặng Hoa 2011 (201104280000 → 201105300000)

- **Tặng Hoa Lan**: 1× Hoa Lan [6,1,1977] → `Vng_OnGiveLanHua()`

### Hoạt động 30 — Hoạt động ngày Nhà Giáo Việt Nam 20/11/2011 (201111030000 → 201112010000)

- **Hợp thành Cuốn Sách**: 5× Giấy Trắng [6,1,3039] + 1× Cây Bút [6,1,3040] + 1× Lọ Mực [6,1,3041] → Cuốn Sách [6,1,3042]

### Hoạt động 31 — Sinh Nhật Võ Lâm Truyền Kỳ năm 2011 (201106060000 → 201106300000)

- **Hợp thành Bánh Kem**: 2× Sữa Tươi [6,1,2851] + 2× Đường tinh [6,1,2852] + 2× Bột mì  [6,1,2853] + 1× Kem [6,1,2856] + 2× Bơ [6,1,2855] → Bánh Kem [6,1,2859]
- **Hợp thành Bánh Sinh Nhật**: 2× Sữa Tươi [6,1,2851] + 2× Đường tinh [6,1,2852] + 2× Bột mì  [6,1,2853] + 1× Kem [6,1,2856] + 2× Bơ [6,1,2855] + 1× SoCoLa [6,1,2854] + 1× Nến Sinh Nhật [6,1,2857] → `GetCake()`
- **Hợp thành Bánh Sinh Nhật Đặc Biệt**: 1× Bánh Sinh Nhật Lớn [6,1,2861] + 1× Giỏ Trái Cây [6,1,2858] → Bánh Sinh Nhật Đặc Biệt [6,1,2864]
- **Hợp thành Phiên Vũ**: 200× Lông Thỏ [6,1,2865] → `GetFanYu()`

### Hoạt động 33 — Hoạt động tháng 9 năm 2011 (201109010000 → 201110010000)

- **Nộp Dây Thừng**: 1× Dây Thừng [6,1,2976] → `HandinString()`
- **Đổi Pháo Hoa Quốc Khánh**: 1× Dây Thừng [6,1,2976] + 1× Dải Lụa Màu Đỏ [6,1,2977] → `ConvertFireworks()`, Pháo Hoa Quốc Khánh [6,1,2979]
- **Đổi Bánh Trung Thu Hàn Nguyệt**: 1× Nến Trắng [6,1,2981] + 1× Lồng Đèn ánh Trăng [6,1,2978] → `ConvertMooncake()`, Bánh Trung Thu Hàn Nguyệt [6,1,2980]

### Hoạt động 34 — (tên gốc tiếng Trung) (dài hạn)

- **Buy_TongYaoShi**: 0× Tiền Đồng → (xem extend.lua)

### Hoạt động 35 — (tên gốc tiếng Trung) (201201010000 → 201202010000)

- **wuguobaiyinpan plan_1**: 1× Nải Chuối [6,1,3098] + 1× Trái Cam [6,1,3095] + 1× Trái Bưởi [6,1,3097] + 1× Trái Hồng [6,1,3099] + 1× Trái Lê [6,1,3096] + 1× Mâm Bạc [6,1,3103] → Mâm Bạc Ngũ Quả [6,1,3105]
- **wuguobaiyinpan plan_2**: 1× Xoài [6,1,3093] + 1× Dừa [6,1,3100] + 1× Đu đủ [6,1,3101] + 1× Trái Mãng Cầu [6,1,3094] + 1× Trái Sung [6,1,3102] + 1× Mâm Bạc [6,1,3103] → Mâm Bạc Ngũ Quả [6,1,3105]
- **wuguohuangjinpan plan_1**: 1× Nải Chuối [6,1,3098] + 1× Trái Cam [6,1,3095] + 1× Trái Bưởi [6,1,3097] + 1× Trái Hồng [6,1,3099] + 1× Trái Lê [6,1,3096] + 1× Mâm Vàng [6,1,3104] → Mâm Vàng Ngũ Quả [6,1,3106]
- **wuguohuangjinpan plan_2**: 1× Xoài [6,1,3093] + 1× Dừa [6,1,3100] + 1× Đu đủ [6,1,3101] + 1× Trái Mãng Cầu [6,1,3094] + 1× Trái Sung [6,1,3102] + 1× Mâm Vàng [6,1,3104] → Mâm Vàng Ngũ Quả [6,1,3106]
- **handin redbag**: 1× Bao Lì Xì Năm Mới (nhỏ) [6,1,3108] + 100000 lượng → (xem extend.lua)
- **baolixido_1**: 1× Tinh Hồng Bảo Thạch → `ComposeRedEvelop()`
- **baolixido_1**: 1× Lam Thủy Tinh → `ComposeRedEvelop()`
- **baolixido_2**: 1× Tử Thủy Tinh → `ComposeRedEvelop()`
- **baolixido_2**: 1× Lục Thủy Tinh → `ComposeRedEvelop()`
- **give dragon mask**: 1× Mặt nạ - Long Châu + 1× Mặt nạ - Đầu Rồng + 1× Mặt nạ - Thân Rồng + 1× Mặt nạ - Đuôi Rồng → `ComposeDragonMask()`

### Hoạt động 37 — Hoạt động Giáng Sinh 2011 (201112010000 → 201201010000)

- **Hợp thành Hộp Quà Giáng Sinh**: 2× áo giáng sinh [6,1,3074] + 1× Quần Giáng Sinh [6,1,3075] + 50000 lượng → `ComposeXmasGift()`
- **Hợp thành Ông Già Noel (nhỏ)**: 2× áo giáng sinh [6,1,3074] + 1× Quần Giáng Sinh [6,1,3075] + 1× Túi Giáng Sinh [6,1,3076] + 100000 lượng → `ComposeXmasPerson_S()`
- **Hợp thành Ông Già Noel (trung)**: 2× áo giáng sinh [6,1,3074] + 1× Nón giáng sinh [6,1,3072] → Ông Già Noel (trung) [6,1,3078]
- **Hợp thành Ông Già Noel (đại)**: 2× áo giáng sinh [6,1,3074] + 1× Quần Giáng Sinh [6,1,3075] + 1× Túi Giáng Sinh [6,1,3076] + 2× Nón giáng sinh [6,1,3072] → Ông Già Noel (đại) [6,1,3079]
- **Hợp thành Bánh Giáng Sinh**: 2× áo giáng sinh [6,1,3074] + 1× Túi Giáng Sinh [6,1,3076] → Bánh Giáng Sinh [6,1,3082]
- **Lệnh Bài triệu hồi Boss Trương Tuyên**: 300× Ngôi Sao [6,1,3081] → Lệnh bài Boss - Trương Tuyên [6,1,3083]
- **Lệnh Bài triệu hồi Boss Kim Thí Lượng**: 400× Ngôi Sao [6,1,3081] → Lệnh bài Boss - Kim Thí Lượng [6,1,3084]
- **Lệnh Bài triệu hồi Mộ Dung Toàn**: 500× Ngôi Sao [6,1,3081] → Lệnh bài Boss - Mộ Dung Toàn [6,1,3085]
- **Mua Gà Quay**: 10000 lượng → Gà quay [6,1,30167]
- **Hợp thành ông già Noel hồng**: 1× Gà quay [6,1,30167] + 1× Bánh bí đỏ [6,1,30166] + 1× Nón giáng sinh [6,1,3072] → Ông Già Noel hồng [6,1,30168]

### Hoạt động 39 — 2012valentine (201202090000 → 201203010000)

- **handin yihuahemeng**: 1× Di Hoa Hòa Mộng [6,1,3112] → Càn Khôn Phích Lịch Đơn [6,1,3116]

### Hoạt động 40 — 2012 March Activity (201203050000 → 201204010000)

- **compose 4 color rose**: 5× Hoa Hồng Trắng [6,1,3117] + 5× Hoa Hồng Vàng [6,1,3119] + 5× Hoa Hồng Xanh [6,1,3118] + 5× Hoa hồng đỏ [6,1,3120] + 1× Cỏ Xanh [6,1,3124] + 1× Giỏ Đựng Hoa [6,1,3123] → (xem extend.lua)
- **compose corbeil**: 5× Hoa Hồng Trắng [6,1,3117] + 5× Hoa Hồng Vàng [6,1,3119] + 5× Hoa Hồng Xanh [6,1,3118] + 5× Hoa hồng đỏ [6,1,3120] + 2× Cỏ Xanh [6,1,3124] + 1× Giỏ Đựng Hoa [6,1,3123] + 1× Nơ Cột Bó Hoa [6,1,3126] → (xem extend.lua)
- **compose 3 color rose 1**: 5× Hoa Hồng Trắng [6,1,3117] + 5× Hoa Hồng Vàng [6,1,3119] + 5× Hoa Hồng Xanh [6,1,3118] + 1× Giỏ Đựng Hoa [6,1,3123] → (xem extend.lua)
- **compose 3 color rose 2**: 5× Hoa Hồng Trắng [6,1,3117] + 5× Hoa Hồng Vàng [6,1,3119] + 5× Hoa hồng đỏ [6,1,3120] + 1× Giỏ Đựng Hoa [6,1,3123] → (xem extend.lua)
- **compose 3 color rose 3**: 5× Hoa Hồng Trắng [6,1,3117] + 5× Hoa hồng đỏ [6,1,3120] + 5× Hoa Hồng Xanh [6,1,3118] + 1× Giỏ Đựng Hoa [6,1,3123] → (xem extend.lua)
- **compose 3 color rose 4**: 5× Hoa Hồng Vàng [6,1,3119] + 5× Hoa hồng đỏ [6,1,3120] + 5× Hoa Hồng Xanh [6,1,3118] + 1× Giỏ Đựng Hoa [6,1,3123] → (xem extend.lua)
- **buy basket**: 10000 lượng → (xem extend.lua)

### Hoạt động 41 — 2012 april_zhushuai (201204020000 → 201205010000)

- **compose shijin**: 10000 lượng → (xem extend.lua)

### Hoạt động 500 — Phú Quý Cẩm Hạp (dài hạn)

- **GetAward_dlg**: 100000 lượng → (xem extend.lua)

### Hoạt động 1000 — Mừng phiên bản mới (201107150000 → 201108150000)

- **Đổi bình hồ lô**: 1× Hoa cúc vàng [6,1,30112] + 1× Hoa cúc tím [6,1,30114] → Bình hồ lô Phong Vân [6,1,30115]
- **Đổi thiết tâm tửu**: 1× Hoa cúc vàng [6,1,30112] + 1× Hoa cúc trắng [6,1,30113] + 1× Hoa cúc tím [6,1,30114] → Phong Vân thiết tâm tửu [6,1,30116]
- **Nộp hoa cúc vàng**: 1× Hoa cúc vàng [6,1,30112] → `VngGiveDaisy()`

### Hoạt động 1002 — Event ngôi sao tuyết (201107250000 → 201108312400)

- **Ghép sao cấp 1**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 2**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 3**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 4**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 5**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 6**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 7**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 8**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 9**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 10**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 11**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Ghép sao cấp 12**: 1× Tuyết Băng Tinh [6,1,30118] + 1× Tuyết Băng Thạch [6,1,30119] → `UpgradeStar()`
- **Tặng sao cấp 1**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 2**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 3**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 4**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 5**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 6**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 7**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 8**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 9**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 10**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 11**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`
- **Tặng sao cấp 12**: 1× Tuyết Băng Tinh [6,1,30118] → `GiveStar()`

### Hoạt động 1003 — Mừng phiên bản mới (201108180000 → 201108312400)

- **Đổi Cửu Tiên Ngự Yến**: 1× Nụ Hoa Hồng Đỏ [6,1,30132] → `GiveRedRoseBud()`
- **Đổi Thúy Tựu Hồ Tiên**: 5× Hoa Hồng Đỏ [6,1,30131] + 1× Cửu Tiên Ngự Yến [6,1,30128] + 1× Hải Vị Bồng Lai [6,1,30129] → Thúy Tụ Hồ Tiên [6,1,30130]
- **Tặng Hoa Hồng Đỏ**: 1× Hoa Hồng Đỏ [6,1,30131] → `GiveRedRose()`
- **Tặng Cửu Tiên Ngự Yến**: 1× Cửu Tiên Ngự Yến [6,1,30128] → `GiveCuuTien()`

### Hoạt động 1007 — Event Thang 10 - Phụ Nữ Việt Nam (201110200000 → 201110272400)

- **Hợp thành Băng Tinh Thạch**: 1× Hoàng Thạch [6,1,30153] + 1× Thiên Tinh Thạch [6,1,30154] → Băng Tinh Thạch [6,1,30155]
- **Nộp vật phẩm Hoàng Thạch**: 1× Hoàng Thạch [6,1,30153] → `HandInHoangThach()`

### Hoạt động 1008 — Event tình nhân 2012 (201202020000 → 201202292400)

- **Hợp thành Trà giải nhiệt**: 1× Lọ mật  [6,1,30173] + 1× Thanh Thành Tuyết Nha [6,1,30176] + 1× Quả song tử [6,1,30177] → (xem extend.lua)
- **Hợp thành Quà màu xanh**: 1× Quả song tử [6,1,30177] + 2× Lọ mật  [6,1,30173] → (xem extend.lua)
- **giao nộp Hoa Hồng**: 1× Hoa hồng [6,1,30172] → `GiveRose()`

### Hoạt động 1009 — Event Mini 30-04 (201204260000 → 201205092400)

- **compose shijin**: 10000 lượng → (xem extend.lua)
- **Đổi Chiếc Mũ Hòa Bình**: 5× Mảnh chiến công lệnh 1 [6,1,30196] + 5× Mảnh chiến công lệnh 2 [6,1,30195] → (xem extend.lua)
- **Đổi Chiếc Mũ Tai Bèo**: 5× Mảnh chiến công lệnh 1 [6,1,30196] + 5× Mảnh chiến công lệnh 2 [6,1,30195] + 1× Túi mừng chiến thắng [6,1,30200] → (xem extend.lua)
- **Đổi Chiếc Mũ Tự Do**: 5× Mảnh chiến công lệnh 1 [6,1,30196] + 5× Mảnh chiến công lệnh 2 [6,1,30195] + 1× Túi mừng chiến thắng [6,1,30200] → (xem extend.lua)

### Hoạt động 1010 — Event Tháng 6 (201206030000 → 201206302400)

- **compose shijin**: 10000 lượng → (xem extend.lua)
- **Ta muốn làm Bánh Kem Thường**: 2× Bột Mì [6,1,30204] + 1× Đường [6,1,30209] + 1× Sữa [6,1,30206] + 2× Bơ [6,1,30205] → (xem extend.lua)
- **Ta muốn làm Bánh Kem Chocolate**: 2× Bột Mì [6,1,30204] + 1× Đường [6,1,30209] + 1× Sữa [6,1,30206] + 2× Bơ [6,1,30205] + 1× Chocolate [6,1,30207] → (xem extend.lua)
- **Ta muốn làm Bánh Kem Trái Cây**: 2× Bột Mì [6,1,30204] + 1× Đường [6,1,30209] + 1× Sữa [6,1,30206] + 2× Bơ [6,1,30205] + 1× Trái Cây [6,1,30208] → (xem extend.lua)
- **Ta muốn làm Bánh Sinh Nhật Võ Lâm Truyền Kỳ**: 2× Bột Mì [6,1,30204] + 1× Đường [6,1,30209] + 1× Sữa [6,1,30206] + 2× Bơ [6,1,30205] + 1× Trái Cây [6,1,30208] + 1× Chocolate [6,1,30207] → (xem extend.lua)
- **compose shijin**: 10000 lượng → (xem extend.lua)
- **Ta muốn đổi Bột Mì thành Đường**: 5× Bột Mì [6,1,30204] → (xem extend.lua)
