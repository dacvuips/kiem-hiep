# Màn chơi "Lộn Xộn" — phân tích & kế hoạch

Hỗn chiến tự do (Free-For-All), **online-only**, chạy trên server thế giới như PUBG (`net/server/pubg_server.gd`),
nhưng: không tổ đội, không vòng bo, không hết giờ, chết thì hồi sinh, rớt hết đồ khi bị hạ, lên cấp bằng cách đánh quái.

## 1. Luật chơi

| # | Luật | Ghi chú triển khai |
|---|------|--------------------|
| 1 | Mỗi người 1 phe, không tạo đội | Không có OP_CREATE/JOIN đội; `allows_hit` true giữa 2 người khác nhau cùng host |
| 2 | Server có sẵn 5 host, người chơi chọn host rồi vào | Host dựng sẵn lúc server khởi động, sống mãi; tối đa 50 người/host |
| 3 | Mỗi host có khung chơi ngẫu nhiên 140×80 region trên Tống Kim 1 như PUBG | Dùng lại `PubgManager.generate_random_arena_box()`; **không** vòng bo |
| 4 | Không giới hạn thời gian | Host không bao giờ `_finish`; không xếp hạng |
| 5 | **Vào trận: nhân vật cấp 50 + chọn thẻ đầu trận như PUBG — 1 ngựa 5x + 1 vũ khí 5x, đều dùng được ở cấp 50** | Xem §1b. Server tự sinh đồ theo lựa chọn, gắn ngựa (`riding = true`) + vũ khí |
| 6 | **Hạ 1 quái = +5 cấp, tối đa cấp 200** | 30 con quái là đạt 200; mỗi cấp cộng điểm tiềm năng như lên cấp thường |
| 7 | Kỹ năng tự mở theo cấp, không cần học (cấp 5x chỉ có tới 5x, cấp 80 mở 9x, 120 mở 12x, 150 mở 15x, 180 mở 18x) | Kỹ năng thường mở ra là MAX; 9x/12x/15x/18x mở ra ở cấp 1, Đại Thành Bí Kíp nâng tiếp. Mở mới thì tự gắn vào ô skill trống |
| 8 | **Quái rơi ~4 món trang bị**, mỗi món: 70% đồ xanh, 25% Hoàng Kim, 5% Hoàng Kim Môn Phái | Xem §3 |
| 9 | **50% rơi ngựa**, đủ loại ngựa | `DropTable.roll_horse()` (mọi loại ngựa trong ItemDatabase) |
| 10 | **Thuốc: 100% rơi đúng 1 bình Hồi Thiên Tái Tạo Đơn** (`1_8_0_4`) | Không rơi thuốc khác |
| 11 | Đại Thành Bí Kíp 9x/12x/15x/18x: quái rơi 1 loại × 5 cuốn; mỗi cuốn = +1 cấp 1 skill đã mở của tầng đó | 4 vật phẩm misc mới |
| 12 | Bị hạ → rớt HẾT trang bị + hành trang ra đất, ai cũng nhặt ngay | Server đổ toàn bộ `equipment` + `inventory` ra `_add_drop(..., owner_eid = 0)` |
| 13 | Chết → 5 giây hồi sinh, trong khung chơi | Hồi sinh tại vị trí ngẫu nhiên trong `box` (`grid.free_near`) |
| 14 | Chết rớt Lệnh Bài; nhặt được thì to hơn, đánh xa hơn, nhìn xa hơn; Top 5 điểm + số hạng trên đầu | Xem §1c |

## 1b. Chọn thẻ đầu trận (giống PUBG, bản 5x)

Dùng lại `PubgDraftPopup` (`ui/pubg/pubg_draft_popup.gd`) và lệnh server `OP_DRAFT` của PUBG, thêm tham số **bộ thẻ**
(`tier = 8` cho PUBG như cũ, `tier = 5` cho Lộn Xộn) thay vì viết popup mới:

**Đợt 1 — chọn 1 trong 5 ngựa 5x** (ngựa cấp 5 trong bảng gốc, `ItemDatabase` detail 10, level 5; mọi ngựa yêu cầu cấp 10 → dùng được ngay):

| Thẻ | Ngựa | particular |
|-----|------|-----------|
| 1 | Hoàng Phiêu | 0 |
| 2 | Tử Lưu | 1 |
| 3 | Ngọc Hoa Thông | 2 |
| 4 | Hắc Kỳ | 3 |
| 5 | Hồng Ly | 4 |

Ngựa 5x giữ đúng chỉ số gốc (không có +100% tốc chạy và dòng riêng như thần mã 8x của PUBG).

**Đợt 2 — chọn 1 trong 14 loại vũ khí cấp 5** (cùng 14 loại như PUBG, chỉ đổi cấp 10 → 5; đều yêu cầu **cấp 36**):

| Loại | Vũ khí 5x | Yêu cầu Sức / Thân |
|------|-----------|--------------------|
| Kiếm | Trảm Mã Kiếm | 50 / 0 |
| Đao | Nguyệt Nha Đao | 60 / 0 |
| Côn | Tiêu Bổng | 90 / 0 |
| Thương | Hoàn Tử Thương | 74 / 74 |
| Chùy | Lượng Ngân Chùy | 115 / 0 |
| Song đao | Tuyết Hoa Lượng Ngân Đao | 40 / 50 |
| Triền thủ | Đại Lực Triền Thủ | 50 / 35 |
| Đao thuẫn / Thuẫn đao | Tinh Chế Đao Thuẫn / Thuẫn Đao | 74 / 74 |
| Phi tiêu | Liễu Diệp Tiêu | 30 / 90 |
| Phi đao | Đái Y Đao | 59 / 70 |
| Tụ tiễn | Bối Trang Nỗ | 35 / 110 |
| Cầm | Loan Cầm | 50 / 0 (chỉ Tiêu Dao) |
| Cung | Cung Dương Môn C5 | 50 / 0 (chỉ Dương Gia) |

Ngũ hành vũ khí = ngũ hành phái của người chơi (như PUBG). Mỗi người chọn 1 lần **mỗi lần vào host**.

Cách làm:
- `PubgDraftPopup`: thêm `HORSES_5X`, `WEAPON_LEVEL_BY_TIER = {8: 10, 5: 5}`, `make_horse(lv, elem, tier)` / `make_weapon(idx, elem, tier)`;
  `open(host, profile, on_finish, tier := 8)` — tiêu đề, mô tả thẻ đổi theo tier. PUBG không đổi hành vi.
- `LonXonServer._draft(c, args)`: chép từ `PubgServer._draft`, gọi `make_horse/make_weapon(..., 5)`; không có bước cộng điểm tiềm năng từ build lưu sẵn (cấp 50 tự cộng).

## 1c. Lệnh Bài & bảng xếp hạng

**Luật:**
- Mỗi người chết rớt **1 Lệnh Bài của chính mình** + **½ số Lệnh Bài đang giữ** (làm tròn xuống) ra đất tại xác.
  VD giữ 5 → chết rớt 1 + 2 = 3 cái, còn giữ 3.
- Người chơi khác nhặt được, mỗi Lệnh Bài đang giữ cho:
  - nhân vật **to hơn 10%**,
  - **bán kính đánh của skill +5%**,
  - **tầm nhìn rộng thêm 10%** (camera thu nhỏ bản đồ lại).
- Mỗi Lệnh Bài = **1000 điểm**. Góc trên bên trái màn hình hiện **Top 5** điểm cao nhất của host.
- **Top 1 / 2 / 3** có số **1 / 2 / 3** hiện trên đầu nhân vật (mọi người đều thấy).

**Thiết kế:**
- Lệnh Bài **không phải món trong túi** (không chiếm ô, không bị luật "rớt hết túi" xử lý lần 2, không vứt / bán / giao dịch được):
  là bộ đếm `tokens` trên hồ sơ tạm của người chơi do server giữ; dưới đất là 1 loại đồ rơi đặc biệt `{"type": "token", "owner": cid}`.
- Server là nguồn duy nhất: nhặt (`C_PICKUP`) đồ loại token → `tokens += 1`, `score = tokens * 1000` → phát `S_LONXON {op: "board", top5, ranks}`
  khi bảng đổi (gộp tối đa 2 lần/giây), và gửi riêng người đó `{op: "tokens", n}` để máy họ áp hiệu ứng.
- Chủ Lệnh Bài **không nhặt lại** Lệnh Bài rớt ra từ chính mình trong ~10 giây đầu (tránh tự chết rồi nhặt lại ngay) — xem điểm cần chốt.
- Lệnh Bài dưới đất tồn tại lâu hơn đồ thường (~5 phút), sau đó biến mất.

**Hiệu ứng (đều tính theo số Lệnh Bài ĐANG GIỮ — mất Lệnh Bài là nhỏ lại):**

| Hiệu ứng | Mỗi Lệnh Bài | Trần đề xuất | Chỗ sửa |
|----------|--------------|--------------|---------|
| Kích thước nhân vật | ×1.10 (cộng dồn tuyến tính: 1 + 0.1·n) | ×2.0 (10 cái) | `scale` node hình nhân vật của `Player` + `RemotePlayer` (vị trí tên/thanh máu dời theo) |
| Bán kính skill | +5% (1 + 0.05·n) | +50% (10 cái) | `Player.get_skill_radius()` nhân thêm hệ số **riêng của player** (không dùng `PlayerStats` toàn cục — quy tắc nhiều player chung skill); vùng nổ / AOE của skill cũng nhân theo |
| Tầm nhìn | camera zoom ÷ (1 + 0.1·n) | +50% (5 cái) | `player.gd` `_zoom_target`; server tăng bán kính AOI của người đó tương ứng để thấy được người/quái ở xa |

Server kiểm tra tầm đánh (`C_DAMAGE`) phải dùng cùng hệ số bán kính, không thì đòn đánh xa bị từ chối.

**Giao diện:**
- `ui/lon_xon/lon_xon_board.gd` (HUD góc trên trái, theo khung GameUi): 5 dòng `hạng · tên · điểm`, dòng của mình tô sáng; nếu mình ngoài top 5 thì thêm 1 dòng "Bạn: hạng X — Y điểm".
- Số hạng trên đầu: `Player` / `RemotePlayer` thêm hàm `set_rank_badge(rank)` (0 = ẩn), số to màu vàng/bạc/đồng (1/2/3) phía trên tên.
- Thông báo kênh hệ thống khi ai đó lên Top 1.

## 2. Những điểm cần chốt (đang hiểu theo mặc định bên phải)

1. **"Khi bị đánh thì rớt hết đồ"** → hiểu là **khi bị hạ gục (chết)**, không phải mỗi lần trúng đòn.
2. **Chết có mất cấp không?** → **Không**: giữ cấp + kỹ năng + điểm tiềm năng đã cộng, chỉ mất đồ. (Nếu muốn khắc nghiệt hơn: về lại cấp 50.)
3. **Hồi sinh có được chọn thẻ lại không?** → **Có**: mỗi lần hồi sinh mở lại popup chọn ngựa 5x + vũ khí 5x (đồ cũ đã rớt ra đất theo luật 12). Nếu muốn khắc nghiệt hơn: chỉ chọn 1 lần lúc vào host, hồi sinh tay trắng.
3b. **Vũ khí 5x đòi Sức/Thân (tới 115)** — ở cấp 50 người chơi chưa cộng điểm có thể chưa cầm được. Mặc định: popup tự cộng điểm tiềm năng tối thiểu vào Sức/Thân cho đủ yêu cầu vũ khí đã chọn, phần còn lại để người chơi tự cộng.
4. **Thuốc khởi đầu** → cấp 10 bình Hồi Thiên Tái Tạo Đơn lúc vào và mỗi lần hồi sinh (trước đây PUBG cấp 50; quái đã rơi 100% nên giảm xuống).
5. **"+5 cấp khi đánh được 1 quái"** → tính cho người **ra đòn kết liễu**. Hạ người chơi khác: không cộng cấp (chỉ nhặt đồ).
6. **Cấp của đồ rơi** → theo cấp hiện tại của người hạ quái (cấp 50 rơi đồ cấp thấp, càng lên cao đồ càng tốt). Hoàng Kim / Hoàng Kim Môn Phái thì cấp cố định theo bảng gốc.
7. **"~4 món"** → mỗi quái rơi 3–5 món (trung bình 4), mỗi món tung riêng 70/25/5.
9. **Hiệu ứng thần tốc lên cấp** → mỗi lần lên cấp: hồi đầy máu/nội lực + hiệu ứng lên cấp như thường.
10. Hồi sinh có miễn sát thương 3 giây; tỉ lệ rơi Bí Kíp 3%/quái; tầng có nhiều chiêu thì dùng bí kíp mở popup chọn chiêu.
11. Thoát giữa chừng = đồ rớt ra đất như chết; tắt giao dịch / bày bán trong trận; cho vứt đồ.

### Điểm cần chốt — Lệnh Bài
12. **Điểm = số Lệnh Bài đang giữ × 1000** (mất Lệnh Bài là tụt điểm, bảng Top 5 luôn phản ánh ai đang mạnh). Phương án khác: điểm cộng dồn, không bao giờ giảm.
13. **"Rớt 1 Lệnh Bài + ½ số đang giữ"** — hiểu là cộng cả hai (1 của bản thân + ½). Nếu ý bạn là chỉ ½ (người chưa có Lệnh Bài vẫn rớt 1) thì đổi công thức thành `max(1, n / 2)`.
14. **Trần hiệu ứng**: to ×2 và bán kính +50% ở 10 Lệnh Bài, tầm nhìn +50% ở 5 Lệnh Bài (tầm nhìn quá xa làm nặng máy + server phải gửi nhiều thực thể hơn). Điểm vẫn tăng không giới hạn.
15. **Chủ không tự nhặt lại** Lệnh Bài của mình trong 10 giây đầu; sau đó ai cũng nhặt được.
16. **Rời host** → Lệnh Bài rớt ra đất như chết; điểm chỉ tính trong host, không lưu.

## 3. Bảng rơi đồ của quái (`LonXonRules.roll_drops(killer_level)`)

| Loại | Tỉ lệ | Số lượng | Nguồn |
|------|-------|----------|-------|
| Trang bị | 100% | 3–5 món (TB 4) | Mỗi món: |
| └ Đồ xanh | 70% | | `DropTable._roll_blue_item(tier theo killer_level, series ngẫu nhiên)` — cần mở thành hàm public `roll_blue_for_level()` |
| └ Hoàng Kim | 25% | | `ItemGenerator.generate_gold_random(idx)` với idx ∈ tất cả gold **trừ** `get_sect_gold_indices()` |
| └ Hoàng Kim Môn Phái | 5% | | `DropTable.roll_sect_gold_item()` |
| Ngựa | 50% | 1 | `DropTable.roll_horse()` — mọi loại |
| Hồi Thiên Tái Tạo Đơn | 100% | 1 bình | `ItemGenerator.generate_misc("1_8_0_4")` |
| Đại Thành Bí Kíp | 3% | 5 cuốn, 1 loại ngẫu nhiên trong 4 | Vật phẩm misc mới |

Mỗi quái ≈ 4 trang bị + 0,5 ngựa + 1 bình → 5–6 món/quái. Với 50 người đánh liên tục, đồ dưới đất tăng nhanh → bắt buộc hạn tồn tại ngắn (xem §6).

## 4. Kiến trúc

```
Client                                         Server thế giới (Godot headless)
CharacterHub ── nút "Lộn Xộn" ─► LonXonWindow   LonXonServer (mới, net/server/lon_xon_server.gd)
  │  op=hosts  ◄─────────── S_LONXON ─────────   - 5 host dựng sẵn: {rid, slot, base, box, monsters, players}
  │  op=join{host} ───────── C_LONXON ───────►   - join: thêm vào host còn chỗ, trả "match" {rid, box, spawn}
  └─► _enter_field_map(LonXonManager.start_online(...))
VltkWorld (map Tống Kim 1, khung box, KHÔNG overlay bo)  - on_hello: hồ sơ tạm cấp 50 + 10 bình, chờ chọn thẻ 5x
  - đếm ngược hồi sinh 5s                               - quái chết: killer +5 cấp (≤200), roll_drops(killer_level)
  - chặn ra ngoài box (đã có cho PUBG)                  - on_died: đổ hết đồ ra đất, hẹn hồi sinh +5s
                                                         - tick: hồi sinh người tới giờ, quái sống lại
```

Tái sử dụng PUBG: AOI theo slot (`ROOM_CELLS`, `cell_base`), `_spawn_monsters`, `generate_random_arena_box`, chặn ra khỏi khung,
hồ sơ tạm không lưu (`c.dirty = false`). Mọi check gần dùng `GameServer.near()`.
Lên cấp do **server** quyết (client không tự cộng cấp) → gửi lại hồ sơ bằng `gs.profile_changed(c)`.

## 5. Các bước làm

### Bước 1 — Dữ liệu & vật phẩm (client + server dùng chung)
- `systems/lon_xon/lon_xon_rules.gd` (mới, `class_name LonXonRules`, hàm tĩnh thuần — dễ test):
  - Hằng số: `HOST_COUNT = 5`, `HOST_CAPACITY = 50`, `START_LEVEL = 50`, `LEVEL_PER_KILL = 5`, `MAX_LEVEL = 200`,
    `START_POTIONS = 10`, `RESPAWN_SEC = 5.0`, `SPAWN_PROTECT_SEC = 3.0`,
    `EQUIP_DROPS = [3, 5]`, `BLUE_RATE = 0.70`, `GOLD_RATE = 0.25`, `SECT_GOLD_RATE = 0.05`, `HORSE_RATE = 0.5`,
    `BOOK_RATE = 0.03`, `BOOK_STACK = 5`.
  - `skill_tier(sk) -> int` theo `req_level` (90/120/150/180, còn lại 0).
  - `apply_start(profile)`: cấp 50, chỉ số gốc + điểm tiềm năng theo cấp, skill đủ cấp tự mở (thường = MAX, 9x+ = cấp 1), tay trắng + 10 bình (ngựa + vũ khí đến từ bước chọn thẻ 5x).
  - `add_levels(profile, n) -> int`: +n cấp (≤ 200), cộng điểm tiềm năng, max thêm skill vừa đủ cấp, trả số cấp thực tăng.
  - `roll_drops(killer_level) -> Array` theo bảng §3.
  - `death_drops(profile) -> Array[ItemInstance]`: gom toàn bộ equipment + inventory, xoá khỏi hồ sơ.
  - `learn_from_book(profile, tier, skill_id) -> String` (rỗng = thành công).
- `DropTable`: thêm `roll_blue_for_level(level, series)` và `roll_normal_gold_item()` (gold không thuộc môn phái).
- 4 vật phẩm misc **Đại Thành Bí Kíp (9x/12x/15x/18x)** trong `item_database.gd` + `item_consumer.gd` (chỉ dùng được trong Lộn Xộn).

### Bước 2 — Server: `net/server/lon_xon_server.gd`
- Giao thức `NetProto.C_LONXON` / `S_LONXON` (op `STATE`, `JOIN{host}`, `QUIT`); client gửi/nhận qua NetClient.
- `OP_DRAFT {horse 1-5, weapon 0-13}` → `_draft` (xem §1b).
- Dựng 5 host (slot riêng, không trùng PUBG/FieldServer), mỗi host 1 `box` ngẫu nhiên + quái trong khung.
- `join` / `on_hello` (hồ sơ tạm `apply_start`) / `place` (điểm ngẫu nhiên trong box) / `on_entered`.
- Quái chết (`game_server.gd` ~dòng 1091): nếu người hạ ở Lộn Xộn → `LonXonRules.add_levels(killer, 5)` + `roll_drops(killer.level)`.
- `on_died`: đổ đồ ra đất quanh xác (owner 0) → `respawn_at[cid] = now + 5`.
- `on_revive`: chặn "Về thành"; `tick` tự hồi sinh: đầy máu, vị trí ngẫu nhiên trong box, cấp 10 bình, mở lại chọn thẻ 5x, miễn sát thương 3s.
- `on_leave`: đồ rớt ra đất, gỡ khỏi host. Quái hồi sinh theo thời gian (như FieldServer).
- Nối vào `game_server.gd`: dispatch C_LONXON, `on_hello`, `on_died` (~902), `_on_revive` (~935), `on_leave`, `tick`, danh sách lệnh cho phép trong trận.

### Bước 3 — Client
- `LonXonWindow`: lấy số người từng host từ server, Bắt Đầu gửi `JOIN`.
- `systems/lon_xon/lon_xon_manager.gd`: `start_online(profile, msg) -> field_entry` (Tống Kim 1, `arena_box`, `lon_xon: true`, không zone).
- HUD: đếm ngược "Hồi sinh sau 5…1"; chặn ra khỏi khung (mở rộng điều kiện PUBG); thông báo "+5 cấp"; nút "Rời Lộn Xộn".
- Character Hub: tin `match` của Lộn Xộn → `_enter_field_map`.

### Bước 3b — Lệnh Bài (xem §1c)
- `LonXonRules`: `TOKEN_SCORE = 1000`, `TOKEN_SCALE = 0.10`, `TOKEN_RADIUS = 0.05`, `TOKEN_VIEW = 0.10`, trần mỗi hiệu ứng;
  `tokens_dropped_on_death(n) -> int` (= 1 + n / 2), `scale_for(n)`, `radius_mult_for(n)`, `zoom_for(base, n)`, `top_n(scores, 5)`.
- Server: đồ rơi loại `token`, nhặt → cộng, chết → trừ + rớt; bảng điểm theo host; `S_LONXON board / tokens`; AOI + kiểm tra tầm đánh theo hệ số.
- Client: áp hiệu ứng khi nhận `tokens`, HUD Top 5, số hạng trên đầu; hiệu ứng Lệnh Bài dưới đất (hình riêng, lấp lánh).

### Bước 4 — Test (`server/test.sh` + `tests/`, luôn `KIEMHIEP_NO_SAVE=1`)
- Unit: `apply_start` (cấp 50, skill ≥ 90 = 0), `make_horse/make_weapon` tier 5 (đúng 5 ngựa cấp 5, 14 vũ khí cấp 5, yêu cầu cấp ≤ 50), `add_levels` (50 + 30×5 = 200, không vượt 200),
  `roll_drops` (10.000 lần: tỉ lệ xanh/HK/HKMP ≈ 70/25/5, ngựa ≈ 50%, đúng 1 bình/quái), `death_drops`, `learn_from_book`.
- Server headless: 2 bot cùng host → A hạ quái lên 55 → A hạ B → đồ của B dưới đất, A nhặt được → B hồi sinh sau 5s trong box với 10 bình + chọn lại thẻ 5x.

## 6. Hiệu năng & rủi ro
- Đồ rơi rất dày (~5–6 món/quái + cả túi khi chết): hạn tồn tại ~60–90 giây cho đồ Lộn Xộn, giới hạn số đồ mỗi host (bỏ món cũ nhất).
- 5 host × quái trong khung: chỉ tick AI quái trong ô có người (AOI); host trống > N phút thì tạm dừng quái.
- Lên cấp quá nhanh (30 quái là max) → người vào sau yếu hơn nhiều; cân nhắc giới hạn +5 cấp chỉ với quái cùng mức trở lên.
- Spawn-kill: miễn sát thương 3s + hồi sinh xa xác.
- Chống gian lận: cấp và đồ do server sinh; client không tự cộng cấp / tạo đồ.

## 7. Trạng thái
- [x] Nút "Lộn Xộn" cạnh PUBG trong Character Hub (ẩn ở bản offline như PUBG).
- [x] `ui/lon_xon/lon_xon_window.gd`: modal 2 tab (Vào Chơi: 5 host + Bắt Đầu; Luật Chơi). Bắt Đầu tạm báo "đang xây dựng".
- [x] Bước 1 (2026-11-18): `systems/lon_xon/lon_xon_rules.gd` (vào trận, +5 cấp/quái, bảng rơi đồ, chết rớt đồ, bí kíp, Lệnh Bài),
  `DropTable.roll_blue_for_level` / `roll_normal_gold_item`, 4 vật phẩm `lonxon_bikip_9/12/15/18` (ItemDatabase + ItemConsumer:
  "Sử dụng" học chiêu cấp thấp nhất, mỗi chiêu cùng tầng có nút "Học <tên>"), `tests/lon_xon_rules_tests.tscn` (trong `server/test.sh`).
  Lưu ý dữ liệu: 9x của 10 phái cũ có cấp yêu cầu 80 (5 phái mới 90) → tầng 9x = cấp yêu cầu 80–119. Học bí kíp cần đủ cấp yêu cầu của chiêu.
- [x] (2026-11-18) Đổi luật: kỹ năng 9x/12x/15x/18x TỰ MỞ ở cấp 1 khi đủ cấp (cấp 80/120/150/180), bí kíp chỉ nâng tiếp; kỹ năng mới mở tự gắn vào ô skill trống.
- [x] Bước 1b (2026-11-18): `PubgDraftPopup.open(host, profile, on_finish, tier)` — `TIER_LONXON = 5`: 5 ngựa cấp 5 (`HORSES_5X`,
  mô tả lấy chỉ số gốc từ bảng đồ), 14 vũ khí cấp 5 (tên gốc, yêu cầu cấp 36); `make_horse/make_weapon(..., tier)` cho server dùng lại;
  `auto_meet_weapon(profile, weapon)` tự cộng Sức/Thân vừa đủ cầm vũ khí; lựa chọn 5x ghi vào `PubgDraftPopup.lonxon_pending_draft`
  (không đụng `PubgManager.pending_draft`). PUBG giữ nguyên (test_pubg_button_and_modal, pubg_server_logic_tests, pubg_room_tests đạt).
- [x] Bước 2 (2026-11-18): `net/server/lon_xon_server.gd` trên server thế giới (cạnh PubgServer). `C_LONXON = 32` / `S_LONXON = 44`;
  op `STATE` (xem host / bảng), `JOIN {host}` (từ Hub), `QUIT`, `DRAFT {horse, weapon}`. 5 host slot 8..12, room_id 8_000_001..5,
  khung ngẫu nhiên, quái sinh khi host có người đầu tiên (~1.200–1.300 quái / host, hồi sinh theo nhịp thường).
  GameServer: `Conn.lonxon_host`, hồ sơ tạm không lưu / không nhận EXP / không nhận quà web, chặn gói như PUBG, `scatter_drops`
  (đồ không chủ, `lifetime` riêng cho Lệnh Bài), nhặt Lệnh Bài -> cộng bộ đếm không vào túi, C_REVIVE chỉ nhận sau 5 giây.
  RelationServer: cùng host đánh nhau tự do; SocialServer: chặn giao dịch. `tests/lon_xon_server_logic_tests.tscn` 56/56.
  Chưa: kiểm tra tầm đánh theo hệ số bán kính Lệnh Bài (MAX_HIT_DISTANCE 1200 hiện đủ rộng), tăng AOI theo tầm nhìn.
- [ ] Bước 3 (client: NetClient + LonXonManager + HUD) và Bước 4 (test online với bot thật).
