# Hệ thống xã hội VLTK (VNG) — luật gốc & cách game này dựng lại

Nguồn: mã C++ `Core/Src` (KPlayerTeam, KPlayerTong, KPlayerTrade, KPlayer, KProtocolProcess, KItemList, KNpcDeathCalcExp), client VNG
(`settings/tong/Tong_Setting.ini` trong pak), server (`level_lead_exp.txt`, `Tong_level.txt`, `Tong_setting.ini [Main]`, `level_add.txt`).
Số liệu được nhập bằng `tools/import_vltk_social_rules.py` → `data/social/social_rules.json` (đọc qua `SocialRules`).

Kiến trúc: **logic thuần** ở `systems/social/*` (không dính UI, trạng thái nằm trên `PlayerProfile` / `SocialHub`), **giao diện** ở `ui/social/*`
theo phong cách `ui/common/social_ui.gd`. Người chơi khác là **người chơi giả** (`MockPlayer`, `SocialDirectory`) — khi online chỉ thay nguồn đó
bằng dữ liệu server, dịch vụ và UI giữ nguyên.

Kiểm thử: `tests/social_tests.tscn` (logic, 146 ca) và `tests/social_ui_tests.tscn` (giao diện, 21 ca).

---

## 1. Tổ đội (`TeamService`, `ExpRules`)

| Luật gốc | Nguồn | Trong game |
|---|---|---|
| Tạo đội: phải bật "cho phép tổ đội", chưa ở đội; đội mới MỞ; thôi trạng thái mở giao dịch | `KPlayerTeam::CreateTeam` | `create_team()` |
| Số người tối đa = 1 + min(7, số_người_theo_cấp_lãnh_đạo − 1); bảng `[LevelUnionNum]`: 0–9 → 3, 10–29 → 4, 30–49 → 5, 50–69 → 6, 70–89 → 7, 90+ → 8 | `KTeam::CalcCaptainPower`, Tong_Setting.ini (VNG) | `SocialRules.team_size` |
| Mời: chỉ đội trưởng, đội phải mở, đối phương cho phép tổ đội và đồng ý | `KPlayerTeam::InviteAdd/GetInviteReply` | `invite()` |
| Xin vào đội (danh sách xin tối đa 32), đội trưởng nhận/từ chối | `KTeamApplyList`, `MAX_TEAM_APPLY_LIST` | `apply_to()`, `accept_applicant()` |
| Người khác phe "Tân thủ" không vào đội của người Tân thủ | `KTeam::CheckAddCondition` | `_check_join_condition()` |
| Thành viên rời: đội còn; đội trưởng rời: giải tán cả đội | `KTeam::DeleteMember` | `leave()` |
| Đội trưởng đuổi / đổi đội trưởng / mở-đóng / đổi cách nhặt đồ | `c2s_teamapply*`, `SetTeamOpen`, `SetModePick` | `kick`, `change_captain`, `set_open`, `set_pick_mode` |
| Cách nhặt đồ: 0 tự nhặt, 1 tự do, 2 đội trưởng, 3 luân phiên | `Team_S_*Pick`, `KTeam::CheckIn` | `can_local_pick()` / `advance_turn()` (nối vào `GroundDrop`) |
| Chia kinh nghiệm: trong tầm 768, `k = 100 + 15 × số người`, mỗi người `exp × (k × cấp / tổng_cấp) / 100` | `KPlayer::AddExp` | `ExpRules.team_shares` |
| Giảm theo chênh cấp: ≤5 đủ; 6–15: `(295 − 19d)/200`; >15: 1 | `KPlayer::AddSelfExp` | `ExpRules.self_exp` |
| Kinh nghiệm lãnh đạo của đội trưởng: `exp × k × 25 × (tổng_cấp − cấp_đội_trưởng) / (tổng_cấp × 10000)`; lên cấp theo `level_lead_exp.txt` | `KPlayer::AddLeadExp` | `ExpRules.lead_exp`, `add_lead_exp` |

Nối vào gameplay: `VltkMonster.die()` → `KillRewards` (kinh nghiệm quái lấy từ bảng `exp` của `data/monsters`, chia theo đội).

## 2. Bang hội (`GuildService`, `GuildRules`)

| Luật gốc | Nguồn | Trong game |
|---|---|---|
| Lập bang: cấp ≥ 50, cấp lãnh đạo ≥ 20 (VNG); 20.000.000 lượng, danh vọng ≥ 300, phúc duyên ≥ 500 (server); không trong đội / không giao dịch; tên ≤ 12 ký tự; phe Chính/Tà/Trung lập | `KPlayerTong::ApplyCreateTong`, `[TongCreate]`, `[Main]` | `create_blockers()`, `create()` |
| Gốc còn đòi 1 món đồ (RequireItem 1,4,195 — "Nhạc Vương Kiếm") | `[Main]` | **bỏ qua** (`REQUIRE_CREATE_ITEM = false`), game chưa có món này |
| Chức vụ: Bang chủ > Trưởng lão (tối đa 7) > Đội trưởng (tối đa 56) > Đệ tử | `enumTONG_FIGURE_*`, `defTONG_MAX_*` | `GuildRules.Figure` |
| Bổ nhiệm: Bang chủ đổi mọi chức (trừ Bang chủ); Trưởng lão chỉ đổi Đội trưởng ↔ Đệ tử | `KPlayerTong::CheckInstate` | `GuildRules.can_instate` |
| Khai trừ: Bang chủ đuổi được mọi người khác; Trưởng lão chỉ đuổi Đội trưởng/Đệ tử | `KickMember` | `GuildRules.can_kick` |
| Số thành viên tối đa theo cấp bang (40…500) nhưng không quá `TongMaxMemberCount` = 70 | `Tong_level.txt`, Tong_Setting.ini | `SocialRules.tong_member_cap` |
| Xin vào: không trong đội/bang; chỉ nhận qua Bang chủ/Trưởng lão đang bật tuyển; "cấp tự nhận" thì vào thẳng | `TransferAddApply`, `CheckAcceptAddApplyCondition` | `apply_join()`, `set_accept_level()` |
| Rời bang: trả 100.000 lượng + 100 danh vọng, chờ 86400 s mới xin vào bang khác; Bang chủ không rời được | `[Main] LeavMn/LeaveRp/LeaveTm` | `leave()` |
| Quỹ bang → kinh nghiệm bang: mỗi 750 s, quỹ ≥ 1.000.000 thì trừ 5000, cộng 120 exp; cấp bang theo bảng `[LevelExp]` | `[MoneyToExp]`, `[LevelExp]` | `process_fund()` |
| Thời gian thử thách: 3 ngày (259200 s) phải đủ 16 thành viên, không bang giải tán | `[TongTest]` | `trial_seconds_left()`, `check_trial()` |
| Thông báo bang, tuyển người, danh hiệu thành viên | `CHANGE_JIYU/RECRUIT/AGNAME` | `set_notice`, `set_recruit`, `set_title` |

Dữ liệu bang nằm trong `PlayerProfile.guild` (lưu cùng nhân vật) vì chưa có server chung.

## 3. Rương chứa đồ (`StorageService`, `ItemContainer`)

- Rương chính 6 × 10 + tối đa **5 rương mở rộng** (`room_repository…5`, `REPOSITORY_NUM`); kho tiền riêng; gửi/rút bằng `c2s_storemoney` (`ExchangeMoney`).
- **Giá mở rộng rương là thiết kế của game này** (500.000 × số thứ tự) — gốc mở bằng script/đạo cụ nên không có bảng giá.
- Kéo thả giữa hành trang ↔ rương dùng `ItemRoomView` (đã tổng quát hoá cho `PlayerProfile` và `ItemContainer`).

## 4. Khoá bảo vệ & khoá món đồ (`SecurityLock`)

- Mật khẩu 1–16 ký tự (`MAX_PASSWORD_LENGTH`), chỉ bật khoá được khi đã có mật khẩu (`SetLockState`), mở bằng đúng mật khẩu (`CheckSavePw`).
  Game lưu **mã băm SHA-256**, không lưu chữ thường.
- Đang khoá: server gốc chặn `tradeapplystateopen / tradeapplystart / playerbuyitem / playersellitem / storemoney / playertradestart / playertradebuy / playerthrowawayitem`
  (`KProtocolProcess::ProcessData`) → `SecurityLock.BLOCKED_WHEN_LOCKED`. Đã nối vào: mở bày bán/giao dịch, xin giao dịch, mua đồ bày bán, gửi/rút tiền rương, vứt đồ.
  Mua/bán với NPC **chưa nối** vì game chưa có cửa hàng NPC.
- Khoá món đồ (`KItemList::Lock`): khoá ngay; mở khoá phải chờ 259200 s (3 ngày); món khoá không bán/giao dịch/vứt/đặt giá.

## 5. Giao dịch trực tiếp (`TradeSession`, `MockTradeAI`)

Đúng `KPlayer::TradeApplyStart/TradeMoveMoney/TradeDecision`: phòng 10 × 4, nhập tiền, **Khoá** → **Đồng ý**; bên đồng ý sau phải chờ ≥ 5000 ms;
kiểm tra tiền không âm + còn chỗ nhận đồ rồi mới đổi; Huỷ trả đồ nguyên vẹn. Người chơi giả định giá (`MockPlayer.suggested_price` — **công thức thiết kế**,
gốc không có bảng giá giữa người chơi), đáp lại tương xứng và tự đồng ý đúng sau 5 giây.

## 6. Bày bán (`StallService`)

Đúng `TradeSet/TradeStart/TradeView/TradeBuy`: đặt giá từng món (món khoá không đặt được); mở quầy cần ≥ 1 món có giá, không cưỡi ngựa, không bị khoá bảo vệ;
quầy loại trừ "mở giao dịch"; người mua không ở chế độ chiến đấu, đủ tiền, đủ chỗ; mua xong món + tiền chuyển ngay (không thuế). Khi bạn mở quầy,
khách giả ghé mua theo giá (rẻ hơn giá gợi ý bán nhanh hơn).

## 7. Xem trang bị người chơi khác (`ViewEquipService`, `ViewEquipWindow`)

Theo `c2s_viewequip` → `KProtocolProcess::c2sViewEquip` → `KPlayer::SendEquipItemInfo` → `KViewItem::GetData`:
- Chặn xem **quá nhanh**: cách nhau < `defMAX_VIEW_EQUIP_TIME` = 30 nhịp game (30/18 giây ≈ 1,7 s).
- Không xem **chính mình**; người kia phải **ở gần** (`FindAroundPlayer`).
- Server gửi từng ô trang bị (14 ô `itempart_num`) dưới dạng **tham số sinh đồ**, client dựng lại món — nên người xem chỉ có **bản sao**; sửa bản sao không đổi món thật.
- Kèm tên, cấp, hình nhân vật. Game này hiện hình + môn phái/phe/bang/lãnh đạo và 11 ô trang bị (kèm bonus bộ), bấm ô để xem chi tiết (chỉ xem).
- Lối vào: nút "Xem trang bị" ở danh sách "Người chơi quanh đây" (menu Giao lưu) và ở màn Lập nhóm (chọn người rồi bấm).

## Chưa làm / ghi chú

- Phe hiện tại theo đội trưởng (`RestoreCurrentCamp`): game chưa tách phe gốc và phe hiện tại nên chưa đổi phe khi vào đội.
- Bang chiến, bản đồ bang, quan hệ liên minh bang, "trò chơi dân gian" trong giao dịch: chưa làm.
- Kinh nghiệm quái trước đây không có trong game (chỉ nhận cuối ải); nay quái cho kinh nghiệm — tắt bằng `KillRewards.ENABLED`.
- Các yêu cầu lập bang (danh vọng 300, phúc duyên 500, cấp lãnh đạo 20) hiện chỉ tăng được bằng bảng TEST (debug build: hàng nút "+20tr / +Danh vọng/Phúc duyên / +Lãnh đạo"); cần nguồn tăng chúng trong game.
