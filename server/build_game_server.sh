#!/usr/bin/env bash
# Xuất gói game server (code + dữ liệu, không ảnh nhân vật/quái/chiêu/âm thanh, ~280 MB) rồi build image Docker.
#   GODOT=/duong/dan/godot bash server/build_game_server.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
project="$(dirname "$here")"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$project" --export-pack "Game Server (Linux)" "$here/game/game_server.pck"
ls -la "$here/game/game_server.pck"
docker build -t kiemhiep-game:local "$here/game"   # docker-compose của repo backend (kiem-hiep-server) dùng image này
