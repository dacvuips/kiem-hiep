# Server Kiếm Hiệp

Thư mục này nằm ngoài project Godot (có `.gdignore`).

| Thư mục | Nội dung |
|---|---|
| `account/` | Server tài khoản (Go): đăng ký, đăng nhập, quên/đổi mật khẩu, máy chủ, nhân vật, API web Admin |
| `admin-web/` | Web Admin (React + Vite), được build vào image `account` và phục vụ tại `/admin/` |

## Chạy trên máy dev

Cần Docker Desktop đang chạy.

```bash
cd server
cp .env.example .env                              # lần đầu
docker compose run --rm --no-deps account genkeys  # in bộ khóa mới -> dán vào .env
docker compose up -d --build
```

| Dịch vụ | Địa chỉ |
|---|---|
| API tài khoản | http://localhost:8080 |
| Web Admin | http://localhost:8080/admin/ |
| Hộp thư giả (xem mã OTP) | http://localhost:8025 |
| PostgreSQL | `127.0.0.1:5432`, user/db `kiemhiep`, mật khẩu = `DB_PASSWORD` trong `.env` |

Kiểm tra toàn bộ luồng tài khoản:

```bash
docker run --rm --network server_default -e API=http://account:8080 -e MAIL=http://mailpit:8025 \
  -v "$PWD/account:/t" alpine:3.20 sh -c "apk add -q bash curl jq && bash /t/smoke_test.sh"
```

## API người chơi

Lỗi luôn có dạng `{"code": "...", "message": "..."}`. Client dựa vào `code`.

| Method | Đường dẫn | Body | Ghi chú |
|---|---|---|---|
| POST | `/v1/auth/register` | `username, email, password` | Không cần OTP. Trả về phiên đăng nhập |
| POST | `/v1/auth/login` | `username, password` | Không phân biệt hoa thường ở tên |
| POST | `/v1/auth/refresh` | `refresh_token` | Xoay vòng token. Dùng lại token cũ sẽ thu hồi mọi phiên |
| POST | `/v1/auth/logout` | `refresh_token` | |
| POST | `/v1/auth/forgot` | `username, email` | Luôn trả `ok`. Gửi mã 6 số nếu tên và email khớp |
| POST | `/v1/auth/reset` | `username, code, new_password` | Sai 5 lần thì mã bị hủy. Đăng xuất mọi máy |
| POST | `/v1/account/password` | `old_password, new_password` | Cần `Authorization: Bearer`. Trả phiên mới |
| GET | `/v1/account/me` | | Cần Bearer |
| POST | `/v1/auth/google/start` | | Trả `auth_url, state, poll_secret`. Có Bearer = liên kết Google vào tài khoản đang đăng nhập |
| GET | `/v1/auth/google/callback` | | Google chuyển trình duyệt về đây (trang HTML báo quay lại game) |
| POST | `/v1/auth/google/poll` | `state, poll_secret` | `202` = đang chờ; `200` = phiên đăng nhập (lấy được 1 lần) |
| GET | `/v1/servers` | | Cần Bearer. Kèm `characters` = số nhân vật của tài khoản trên từng máy chủ |
| GET | `/v1/characters?server_id=N` | | Nhân vật của tài khoản trên máy chủ N (tối đa 4 ô) |
| POST | `/v1/characters` | `server_id, slot, name, data` | Tên 2–16 ký tự (chữ có dấu, số, cách), không trùng trong máy chủ |
| PUT | `/v1/characters/{id}` | `version, data` | Lưu tiến trình. Sai `version` (máy khác vừa lưu) thì trả `stale_save`. Không đổi được tên qua `data` |
| DELETE | `/v1/characters/{id}` | `password` | Xóa mềm, phải nhập lại mật khẩu |

Phiên đăng nhập: `{access_token (15 phút), refresh_token (30 ngày), expires_in, account}`.

Các mã lỗi: `bad_request`, `bad_username`, `bad_email`, `bad_password`, `password_is_username`, `username_taken`, `wrong_login`,
`wrong_password`, `bad_code`, `bad_name`, `name_taken`, `slot_taken`, `too_many_characters`,
`character_not_found`, `google_disabled`, `google_expired`, `google_in_use`, `google_already_linked`, `google_failed`, `google_canceled`, `bad_server`, `maintenance`, `stale_save`, `data_too_large`, `banned`, `unauthorized`, `rate_limited`, `internal`.

## Bảo mật

| Thứ cần bảo vệ | Cách làm |
|---|---|
| Mật khẩu | argon2id (19 MiB, 2 vòng) trên `HMAC(PASSWORD_PEPPER, mật khẩu)`, salt riêng từng tài khoản. Lộ database mà không có pepper thì không dò được. Tự băm lại khi đổi tham số |
| Access token | JWT ký **Ed25519**, header có `kid`, kèm `iss`/`aud`/`exp`/`nbf`/`iat`/`jti`. Sống 15 phút. Chỉ chấp nhận `EdDSA` (chặn `alg=none`) |
| Kiểm tra token ở game server | Chỉ dùng **khóa công khai** từ `/.well-known/jwks.json`. Game server không ký được token |
| Refresh token, mã OTP | Database chỉ lưu `HMAC(TOKEN_HMAC_KEY, …)`. Refresh xoay vòng, dùng lại token cũ thì thu hồi mọi phiên |
| Khóa bí mật | Chỉ ở biến môi trường (`server/.env`, không commit). Server không khởi động nếu thiếu khóa hoặc còn giá trị mẫu. Không ghi khóa ra log |
| Client | **Không giữ khóa nào**, chỉ giữ token của chính người chơi |
| Dò tài khoản | Cùng thông báo lỗi và cùng thời gian trả lời dù tên có tồn tại hay không. Quên mật khẩu luôn trả `ok` |
| Dò mật khẩu | Giới hạn theo tài khoản (10/phút) và theo IP (120/phút). OTP sai 5 lần thì hủy |
| HTTP | CORS chỉ cho tên miền trong `CORS_ORIGINS`, header `nosniff`/`no-store`/HSTS/`X-Frame-Options`. Production bắt buộc chạy sau HTTPS (Caddy/Nginx) với `TRUST_PROXY=true` |
| Database, hộp thư | Chỉ mở cổng cho `127.0.0.1`, không mở ra mạng |

Đổi khóa ký JWT: chạy `genkeys`, thay `JWT_KID` + `JWT_PRIVATE_KEY`, đưa khóa công khai cũ vào `JWT_PUBLIC_KEYS`
để token đang dùng còn hợp lệ tới khi hết hạn (15 phút), sau đó xóa đi.
**Không được đổi `PASSWORD_PEPPER`** khi đã có người chơi. Phải sao lưu nó an toàn cùng database.

> Hiện client tự gửi dữ liệu nhân vật (`PUT /v1/characters/{id}`), nên sửa client vẫn có thể gian lận chỉ số/đồ.
> Khi có game server (bước B), chỉ game server được ghi dữ liệu nhân vật.

## Web Admin

- Đăng nhập lần đầu bằng `BOOTSTRAP_ADMIN_USER` / `BOOTSTRAP_ADMIN_PASS` trong `.env`. Hệ thống bắt **bật 2FA**
  (Google Authenticator...) rồi **đổi mật khẩu** (ít nhất 12 ký tự) trước khi vào các trang.
- Vai trò: **Super Admin** (toàn quyền), **Game Master** (khóa, cấm chat, khôi phục nhân vật), **Hỗ trợ** (đặt lại mật khẩu,
  đổi email, đăng xuất mọi thiết bị), **Chỉ xem**.
- Mọi thao tác thay đổi dữ liệu bắt nhập lý do và ghi vào nhật ký (bảng `admin_audit`, không sửa / xóa được).
- Phiên admin nằm trong cookie HttpOnly + SameSite=Strict, kèm header chống CSRF, hết hạn sau 8 giờ.
- Mất 2FA / quên mật khẩu Super Admin: chạy trên máy chủ
  `docker compose exec account /account admin <tên> super` để nhận mật khẩu tạm mới (2FA bị xóa, phải thiết lập lại).
- Sửa giao diện: `cd admin-web && npm install && npm run dev` rồi mở http://localhost:5173/admin/ (API tự chuyển sang :8080).

Kiểm tra web Admin bằng trình duyệt thật (cần Chrome):

```bash
PASS=$(docker compose exec -T account /account admin e2e_super super | grep -o 'tạm: .*' | cut -d' ' -f2)
cd admin-web/e2e && npm install && node admin_e2e.mjs e2e_super "$PASS" ./shots
# xong: vô hiệu hóa admin thử
docker compose exec -T postgres psql -U kiemhiep -c "UPDATE admins SET disabled=true WHERE username='e2e_super'"
```

## Game server (Godot headless)

Chế độ MAIN_MAP online: `res://net/server/game_server.tscn` (code trong `net/`). Nghe ENet `:7777` (PC/mobile) và WebSocket
`:7778` (web), mô phỏng 18 tick/giây, gửi vị trí 9 lần/giây theo lưới tầm nhìn 1024 px (mỗi người thấy 3x3 ô quanh mình).

```bash
# Chạy trong Docker (giống production): xuất gói server (~90 MB, chỉ code + dữ liệu, không hình/âm thanh) rồi build image
GODOT="/duong/dan/Godot_v4.7.2_console.exe" bash server/build_game_server.sh
docker compose --profile game up -d

# Hoặc chạy thẳng bằng Godot trên máy (sửa code nhanh, không cần build lại)
GODOT="/duong/dan/Godot_v4.7.2_console.exe" bash server/run_game_server.sh

godot --headless --path . res://tests/net_tests.tscn                          # kiểm thử bằng bot thật
```

Gói server dùng preset export **"Game Server (Linux)"** (chế độ Dedicated Server của Godot: ảnh đã import thành ảnh rỗng,
loại thư mục ảnh / âm thanh thô). Mỗi lần gửi trạng thái, thực thể mới vào tầm / rời tầm được gộp vào 1 gói (`S_SPAWNS`, `S_DESPAWNS`).

- Vào map: game gửi access token + mã nhân vật; game server hỏi `POST /internal/game/join` (khóa `GAME_SERVICE_KEY`).
  Nhân vật đăng nhập nơi khác thì phiên cũ bị đá.
- Di chuyển: game gửi vị trí, server kiểm tra tốc độ (ngân sách quãng đường) + ô vật cản, sai thì kéo về (`S_CORRECT`).
- Quái (693 con theo `map.json`) do game server điều khiển: AI gốc KNpcAI, hồi sinh theo `respawn`. Quái ở vùng không có
  người chơi trong 2 ô AOI thì "ngủ". Server báo quái ra chiêu (`S_MATTACK`); máy người bị nhắm tính đòn thật, máy khác chỉ vẽ.
- Sát thương người chơi gây cho quái: game tính rồi gửi `C_DAMAGE`; server kiểm tra khoảng cách, tốc độ gửi và cắt theo
  **trần sát thương của chính nhân vật** (`ProfileGuard.max_hit`: skill mạnh nhất đã học x chí mạng x dư 20%).
- Quái chết: **server tính kinh nghiệm / lên cấp** (`S_PROGRESS`, chia theo phần sát thương); rớt đồ cho người hạ đòn cuối (`S_KILL`).
- Dữ liệu nhân vật khi đang trong map: game gửi cho game server (`C_PROFILE`), server gộp theo `ProfileGuard` (giữ cấp /
  kinh nghiệm của server, điểm tiềm năng / kỹ năng không vượt số cấp cho phép) và lưu qua `PUT /internal/game/characters/{id}`
  mỗi 60 giây + khi thoát. Túi đồ / tiền tạm tin game — chuyển lên server ở bước C.
- **Production:** chặn đường dẫn `/internal/*` ở reverse proxy (chỉ cho mạng nội bộ của game server gọi).
