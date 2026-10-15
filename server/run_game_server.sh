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
export GAME_DEV_TRUST_CLIENT="${GAME_DEV_TRUST_CLIENT:-$(grep "^GAME_DEV_TRUST_CLIENT=" "$here/.env" | cut -d= -f2-)}"
export GAME_TEST_MODE="${GAME_TEST_MODE:-0}"
export GAME_STATUS_POLL="${GAME_STATUS_POLL:-30}"     # giây giữa 2 lần hỏi trạng thái khoá / cấm chat   # 1 = luôn rớt thêm tiền khi quái chết (chỉ để chạy tests/net_tests)
exec "$GODOT" --headless --path "$project" res://net/server/game_server.tscn
