# Hướng Dẫn Vận Hành, Build & Phát Hành Game (Kiếm Hiệp)

Tài liệu này tổng hợp toàn bộ quy trình từ triển khai máy chủ (VPS), quản lý Docker Hub, cơ chế đóng gói tài nguyên, xuất bản APK và cập nhật từ xa.

---

## 1. Kiến Trúc Tổng Quan: Server vs Client

Hệ thống tách biệt hoàn toàn giữa **Game Server** và **Game Client**:

```
                                [Docker Hub]
                                     ▲
                                     │ (Chỉ chứa Image Server gọn nhẹ)
                                     │
[Repo kiem-hiep] ────────► GitHub Actions
(Mã nguồn game)                      │
                                     │ (SSH tự động deploy)
                                     ▼
                              [VPS Manager]
        ┌────────────────────────────────────────────────────────┐
        │  Docker Swarm Services:                                │
        │    - kiemhiep_account  (Xác thực tài khoản, API)        │
        │    - kiemhiep_game     (Game server headless)          │
        │    - kiemhiep_caddy    (Reverse proxy, SSL, cấp file)  │
        │    - kiemhiep_postgres (Cơ sở dữ liệu người chơi)       │
        │                                                        │
        │  Thư mục Client CDN tĩnh:                              │
        │    /opt/kiemhiep/client/files/*.pck + manifest.json    │
        └───────────────────────────▲────────────────────────────┘
                                    │ (Tải tài nguyên qua HTTP Range)
                                    │
                         [Mobile Client / APK]
                     Launcher cài 1 lần (~35 MB)
```

### Tại sao KHÔNG đưa các file `.pck` của Client vào Docker Hub?
| Thành phần | Nằm ở đâu | Dung lượng | Mô tả & Mục đích |
|---|---|---|---|
| **`game_server.pck`** | Đóng gói trong **Docker Hub** (`kiemhiep-game`) | ~50 MB | Chỉ chứa logic server, map va chạm. Đã lược bỏ hoàn toàn ~1 GB ảnh, animation và âm thanh để server chạy cực nhẹ. |
| **`Client packs`** (`core.pck`, `avatar.pck`, `monster.pck`, `audio.pck`...) | Đặt trực tiếp tại thư mục file tĩnh trên **VPS** (`/opt/kiemhiep/client/files/`) | ~1 GB | Phục vụ người chơi tải về điện thoại qua HTTP CDN (hỗ trợ resume khi rớt mạng). Tránh làm phình to Docker Image server lên hàng GB. |
| **`APK Launcher`** | Cài đặt trên điện thoại Android | ~35 MB | Chứa Godot runtime tối giản và màn hình cập nhật. |

---

## 2. Quy Trình Cập Nhật Server Qua GitHub Actions

### A. Sửa code Game (Map, Quái, Kỹ năng, Server logic)
- Thư mục: `kiem-hiep/`
- Lệnh:
  ```bash
  git add .
  git commit -m "Mô tả thay đổi"
  git push origin main
  ```
- **GitHub Actions tự động**:
  1. Dùng runner Linux tải Godot headless.
  2. Xuất `server/game/game_server.pck`.
  3. Đóng gói và push `tranhieu05069x/kiemhiep-game:<TAG>` lên Docker Hub.
  4. SSH vào VPS và cập nhật stack Docker Swarm tự động không làm gián đoạn hệ thống.

### B. Sửa Backend & Web (Account, Admin Web, Portal, Database)
- Thư mục: `kiem-hiep-server/`
- Lệnh:
  ```bash
  git add .
  git commit -m "Mô tả thay đổi"
  git push origin main
  ```
- **GitHub Actions tự động**:
  1. Build Go binary và Web assets (Next/Vue/React).
  2. Đóng gói và push `tranhieu05069x/kiemhiep-account:<TAG>` lên Docker Hub.
  3. SSH vào VPS cập nhật service `kiemhiep_account` và tự động migrate PostgreSQL.

---

## 3. Quy Trình Xuất Bản Tài Nguyên Client & Cập Nhật Từ Xa (Remote Update)

Mỗi khi bạn thêm đồ họa mới, âm thanh, map mới cho client:

### Bước 1: Đóng gói các gói tài nguyên Client (.pck)
Chạy script tại thư mục gốc `kiem-hiep/`:
```powershell
$env:GODOT="C:\Users\Hieu Tran\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
python tools/build_client_update.py
```
- Script sẽ quét mã băm sha256 và chỉ xuất lại các gói có nội dung thay đổi.
- Kết quả được tạo tại: `server/client/files/*.pck` và `server/client/manifest.json`.

### Bước 2: Đồng bộ các gói lên VPS
Đẩy thư mục client lên VPS bằng SCP (hoặc rsync):
```powershell
scp -i "$env:USERPROFILE\.ssh\github_actions_deploy" -r server/client/* root@161.248.147.33:/opt/kiemhiep/client/
```
Sau bước này, bất kỳ người chơi nào mở app trên điện thoại cũng sẽ tự động nhận diện bản cập nhật và tải về!

---

## 4. Hướng Dẫn Build File APK Cho Android

Chỉ cần build APK launcher một lần (hoặc khi cập nhật phiên bản Godot):

1. **Cơ chế hoạt động**:
   - APK được xuất trực tiếp từ thư mục gốc (`kiem-hiep/`) thông qua preset **"Android Launcher"**.
   - Cấu hình loại trừ (`exclude_filter`) các thư mục tài nguyên nặng (`assets/avatar/*`, `assets/monster/*`, `assets/skill_fx/*`, `world/maps/*`, `audio/*`, `assets/items/*`).
   - Màn hình khởi động đầu tiên là `res://launcher.tscn`.
   - Khi mở app trên điện thoại, Launcher sẽ kết nối tới máy chủ VPS CDN (`https://kiem-hiep-api.viettheo.site`), tải các gói `.pck` còn thiếu (~1.2 GB) về thư mục `user://content/` (hỗ trợ HTTP Range và mã hóa SHA-256).
   - Sau khi tải/xác thực xong, Launcher gọi trực tiếp `ProjectSettings.load_resource_pack(pck_path, replace)` để nạp toàn bộ dữ liệu vào `res://` và chuyển cảnh sang màn hình đăng nhập (`res://ui/login/Login.tscn`). Không cần khởi động lại tiến trình OS hay dùng `--main-pack` (tránh lỗi `Unable to setup the Godot engine! Aborting...` trên Android).

2. **Lệnh xuất file APK bằng CLI**:
   ```powershell
   & "C:\Users\Hieu Tran\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --export-debug "Android Launcher" build/kiem-hiep-launcher.apk
   ```

3. **Xuất bằng giao diện Godot Editor**:
   - Mở Godot Editor tại project gốc `kiem-hiep/`.
   - Vào menu **Project** → **Export...**
   - Chọn preset **Android Launcher**.
   - Bấm **Export Project** và lưu file vào `build/kiem-hiep-launcher.apk`.

4. **Cài đặt & Trải nghiệm**:
   - Chép file `build/kiem-hiep-launcher.apk` vào điện thoại và cài đặt đè.
   - Do cùng package `com.kiemhiep.game`, toàn bộ 1.2 GB tài nguyên bạn đã tải về trước đó vẫn được giữ nguyên trong `user://content/`.
   - Mở app lên: Launcher kiểm tra nhanh các gói, nạp vào engine và chuyển ngay sang màn hình Đăng nhập mà không bị văng.

---

## 5. Các Lệnh Vận Hành & Khắc Phục Lỗi Nhanh Trên VPS

SSH vào VPS:
```bash
ssh root@161.248.147.33
```

- **Kiểm tra trạng thái các service (phải đạt 1/1)**:
  ```bash
  docker stack services kiemhiep
  ```
- **Xem log Game Server thời gian thực**:
  ```bash
  docker service logs -f kiemhiep_game --tail 30
  ```
- **Xem log Account / Web API**:
  ```bash
  docker service logs -f kiemhiep_account --tail 30
  ```
- **Kiểm tra endpoint manifest của client**:
  ```bash
  curl -i -H "Host: kiem-hiep-api.viettheo.site" http://127.0.0.1/v1/client/manifest
  ```
- **Triển khai / Restart stack thủ công**:
  ```bash
  cd /opt/kiemhiep
  bash deploy/swarm_up.sh tranhieu05069x game=latest
  ```
