# APK launcher — cài 1 lần, game tự cập nhật

APK phát hành chỉ chứa **launcher** (engine Godot + 1 màn tải, khoảng 25–35 MB). Nội dung game là các gói `.pck`
tải về máy và tự cập nhật mỗi lần mở app — không cần tải lại APK.

```
Mở app ──> launcher.gd ── GET /v1/client/manifest ──> gói nào mới thì tải (tải tiếp được, kiểm sha256)
                │                                         └─> user://content/*.pck + installed.json
                └─> ghi user://boot_game, khởi động lại app
                       └─> GodotApp.java thấy file đánh dấu -> --main-pack core.pck ++ --kh-content=<thư mục>
                              └─> game chạy như bản đầy đủ; autoload ContentPacks nạp các gói còn lại
```

- Mất mạng nhưng đã tải bản trước đó -> vào game luôn.
- File đánh dấu chỉ dùng 1 lần, nên lần mở app sau lại vào launcher để kiểm tra cập nhật.
- Chỉ phải phát hành APK mới khi **nâng phiên bản Godot** (major.minor) hoặc sửa launcher/`GodotApp.java`
  (tăng `LAUNCHER_VERSION` trong `launcher.gd` rồi chạy build với `--min-launcher <số mới> --apk-url <link>`
  -> launcher cũ hiện nút "Tải bản cài mới").

## Gói

| Gói | Nội dung | Ghi chú |
|---|---|---|
| `core` | code, UI, data, font, mọi thứ còn lại | main pack — đổi mỗi lần sửa code |
| `avatar` `monster` `skill_fx` `maps` `audio` `items` | thư mục tài nguyên nặng | chỉ tải lại khi thư mục đó đổi |

Preset `Client Core` / `Client Pack <tên>` nằm trong `export_presets.cfg` của game. Thêm gói mới: thêm preset +
1 dòng trong `PACKS` của `tools/build_client_update.py` + thêm thư mục đó vào `exclude_filter` của `Client Core`.
Font/theme/`default_bus_layout.tres` **phải ở core** (engine nạp trước khi autoload chạy).

## Phát hành bản cập nhật game

```bash
GODOT="/duong/dan/Godot_v4.7.2-stable_win64_console.exe" python tools/build_client_update.py
```

Script tự xuất lại gói nào đổi nội dung, ghi `server/client/files/*.pck` + `server/client/manifest.json`.
Account server (`CLIENT_DIR=/client`, đã gắn trong `docker-compose.yml`) phục vụ:
- `GET /v1/client/manifest`
- `GET /client/files/{file}` (có Range). Khi có CDN: `--files-base https://cdn.../client/` rồi chép `server/client/files/` lên CDN.

Trên máy chủ thật chỉ cần chép thư mục `server/client/` lên — người chơi nhận bản mới ở lần mở app tiếp theo.

## Build APK launcher

1. Lần đầu (và mỗi khi nâng Godot): `bash launcher/setup_android.sh` — chép template gradle từ `android/` của game
   + đè `android_src/GodotApp.java`.
2. Đổi địa chỉ server: `kiem_hiep/network/account_url` trong `launcher/project.godot` (giống game).
3. Mở `launcher/` bằng Godot -> Export -> **Android Launcher** (cần keystore release để ký bản phát hành),
   hoặc: `godot --headless --path launcher --export-release "Android Launcher" ../build/kiem-hiep-launcher.apk`.

`package/unique_name` = `com.kiemhiep.game` — đổi sau khi đã phát hành thì người chơi phải gỡ app cũ.

## Chạy thử trên PC

Chạy `launcher/` từ editor: trên máy tính launcher mở tiến trình game mới bằng `--main-pack` (không cần Java).
Game mở ra dùng thư mục user của game thật — đặt `KIEMHIEP_NO_SAVE=1` để không ghi đè `profile.json`.
