#!/usr/bin/env bash
# Chạy game server (Godot headless) trên máy dev, đọc khóa từ server/.env.
#   GODOT=/duong/dan/godot bash server/run_game_server.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
project="$(dirname "$here")"
GODOT="${GODOT:-godot}"
export GAME_SERVICE_KEY="$(grep '^GAME_SERVICE_KEY=' "$here/.env" | cut -d= -f2-)"
export GAME_ACCOUNT_URL="${GAME_ACCOUNT_URL:-http://127.0.0.1:8080}"
export GAME_SERVER_ID="${GAME_SERVER_ID:-1}"
exec "$GODOT" --headless --path "$project" res://net/server/game_server.tscn
