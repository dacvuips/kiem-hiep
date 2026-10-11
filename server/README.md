# Server Kiếm Hiệp

Thư mục này nằm ngoài project Godot (có `.gdignore`).

| Thư mục | Nội dung |
|---|---|
| `account/` | Server tài khoản (Go): đăng ký, đăng nhập, quên/đổi mật khẩu, danh sách máy chủ. Sắp tới: API web Admin |

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
| GET | `/v1/servers` | | Cần Bearer. Định dạng giống `data/server/servers.json` cũ |

Phiên đăng nhập: `{access_token (15 phút), refresh_token (30 ngày), expires_in, account}`.

Các mã lỗi: `bad_request`, `bad_username`, `bad_email`, `bad_password`, `password_is_username`, `username_taken`, `wrong_login`,
`wrong_password`, `bad_code`, `banned`, `unauthorized`, `rate_limited`, `internal`.

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
