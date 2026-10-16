# Game server (máy dev)

Backend (server tài khoản Go, web Admin, web người chơi, docker-compose, `.env`, deploy Swarm) đã tách sang repo
**kiem-hiep-server** — clone cạnh repo này (`../kiem-hiep-server`, hoặc đặt `SERVER_REPO=...`).

Thư mục này chỉ còn phần game server (code ở `net/` của repo game):

| File | Việc |
|---|---|
| `dev.sh` | `up` / `down` / `status` / `logs` / `build` / `pck` / `local` / `test` — build image `kiemhiep-game:local`, bật bằng docker-compose của repo backend |
| `test.sh` | toàn bộ bài test (server thử ở cổng 79xx) |
| `run_*_server.sh` | chạy game server bằng Godot trên máy, không Docker |
| `game/Dockerfile` | image game server (GitHub Actions: `.github/workflows/game-server.yml`) |
| `client/` | bản game cho APK launcher (`python tools/build_client_update.py`) — đẩy lên VPS bằng `deploy.sh client` của repo backend |
