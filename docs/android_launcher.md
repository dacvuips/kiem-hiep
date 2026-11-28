# APK launcher mỏng + cập nhật gói (Android)

## Vì sao

Godot **không thay được script đã biên dịch** khi nạp gói lúc đang chạy (`load_resource_pack`). Template Android chính thức
cũng **không cho `--main-pack`** với gói nằm ngoài APK (chỉ cho gói nằm trong `assets/` của APK, xem `main/main.cpp` 4.7.2).
Trước 2026-11-28, APK chứa cả code game: core mới nạp đè nhưng `NetProto`/autoload cũ vẫn kẹt trong bộ nhớ → script mới
biên dịch hỏng → văng khi vào Hub.

Nay APK là **launcher mỏng**: engine + màn tải (`launcher.gd`) + theme/font + **autoload giả** (`extends Node` rỗng ở đúng
đường dẫn autoload). Không có script game nào được nạp trước core, nên không còn gì để kẹt.

## Luồng khi mở app

1. Engine tạo các autoload giả (tên `MusicManager`, `NetClient`... được đăng ký toàn cục) rồi chạy `launcher.gd`.
2. Launcher lấy `/v1/client/manifest`, kiểm `min_launcher`, phiên bản Godot, **`settings_hash`**. Lệch thì báo tải APK mới.
3. Chọn bản để chạy:
   - bản trong manifest đã có **đủ mọi gói** trên máy (tải ngầm từ lần trước) → dùng bản đó;
   - chưa đủ, nhưng bản đang cài (`installed.json`) chạy được và máy chủ không bắt buộc (`min_version`) → **vào ngay bằng
     bản đang cài**, bản mới tải ngầm trong game;
   - không có bản nào chạy được (cài lần đầu, bản cũ không hợp APK, bị bắt buộc) → đứng chờ tải core rồi mới vào.
4. Nạp core (ghi đè) cùng các gói đã có, gỡ script giả, gắn script thật từ core cho từng autoload, cho chúng vào cây lại
   đúng thứ tự (`_enter_tree`/`_ready` chạy như bình thường), rồi vào `ModeSelect`.
5. `WebContentManager`:
   - gói **của bản đang chạy** còn thiếu → tải rồi nạp; cổng ở màn chọn nhân vật chờ tới khi đủ;
   - gói **của bản sau** → chỉ tải về máy, **không nạp** (bắt đầu sau khi đăng nhập, hoặc sau 15 giây nếu chơi Offline).
     Xong thì hiện "Đã tải bản cập nhật — mở lại game để dùng". Lần mở app sau launcher dùng bản mới.

Không bao giờ nạp core của bản khác vào game đang chạy: đó chính là lỗi văng 2026-11-28.

## `settings_hash`: thứ chỉ APK mới đổi được

Engine chỉ đọc lúc mở app, từ APK: `project.godot` (màn hình, render, input map, danh sách/thứ tự autoload), lớp gốc
(`extends`) của autoload, theme mặc định và font của nó, `default_bus_layout.tres`, icon, ảnh splash.
`tools/launcher_settings.py` băm những thứ này. APK ghi mã vào `kiem_hiep/launcher/settings_hash`, manifest ghi mã của core.

## Trình tự phát hành hợp lệ

**Chỉ sửa code / UI / data** (trường hợp thường gặp):

```bash
GODOT=".../Godot_v4.7.2-stable_win64_console.exe" python tools/build_client_update.py
```

Người chơi tải ngầm core mới trong lúc chơi, dùng ở lần mở app sau, không cần cài lại.

**Đổi giao thức mạng / server mà bản cũ không chơi được nữa:** thêm `--force-update` (ghi `min_version`). Launcher bắt
tải xong bản mới mới cho vào game.

**Sửa `project.godot`, thêm/bớt/đổi thứ tự autoload, đổi `extends` của autoload, đổi theme/font theme, bus âm thanh:**
`build_client_update.py` sẽ in `CHÚ Ý: settings_hash đổi ...`. Làm theo thứ tự:

1. `python tools/build_launcher_apk.py --publish` → APK mới ở `server/client/files/kiem-hiep.apk`
2. Đưa APK lên máy chủ, **sau đó** mới phát core:
   `python tools/build_client_update.py --apk-url https://<máy chủ>/client/files/kiem-hiep.apk`

Nếu phát core trước, APK cũ thấy `settings_hash` lệch thì báo "Cần cài bản mới" (không văng), nhưng người chơi bị chặn
cho tới khi có APK.

**Sửa `launcher.gd`** theo cách core mới cần: tăng `LAUNCHER_VERSION`, build APK, rồi phát core với
`--min-launcher <số mới> --apk-url ...`.

## Chuyển người chơi đang dùng APK cũ (chứa cả game) sang launcher mỏng

APK cũ có `LAUNCHER_VERSION = 1`. Phát APK mỏng (`LAUNCHER_VERSION = 2`) lên máy chủ, rồi phát core với
`--min-launcher 2 --apk-url <link APK>`: launcher cũ hiện nút "Tải bản cài mới".

## Ký APK

`build_launcher_apk.py` mặc định `--export-debug`, ký bằng debug keystore trong cài đặt editor. Bản đang phát cũng ký
như vậy nên cài đè giữ được dữ liệu. Đổi keystore thì người chơi phải gỡ app cũ (mất dữ liệu offline).
