#!/usr/bin/env bash
# Xuất gói game server (chỉ code + dữ liệu, ~90 MB) rồi build image Docker.
#   GODOT=/duong/dan/godot bash server/build_game_server.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
project="$(dirname "$here")"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$project" --export-pack "Game Server (Linux)" "$here/game/game_server.pck"
ls -la "$here/game/game_server.pck"
cd "$here" && docker compose build game
