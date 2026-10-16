#!/usr/bin/env bash
# Chạy PHÒNG TRAIN CHUNG Vượt Ải (game server riêng, nhiều phòng — map luyện công / Địa Ngục, vào bằng ID) trên máy dev, cạnh
# server thế giới (run_game_server.sh):
#   GODOT=/duong/dan/godot bash server/run_field_server.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
export GAME_FIELD=1
export GAME_ENET_PORT="${GAME_ENET_PORT:-7807}"
export GAME_WS_PORT="${GAME_WS_PORT:-7808}"
exec bash "$here/run_game_server.sh"
