#!/usr/bin/env bash
# Chạy ĐẤU TRƯỜNG PK (game server riêng, map 397 — popup PK: Đại hội võ lâm / Võ lâm Liên đấu) trên máy dev, cạnh server
# thế giới (run_game_server.sh):
#   GODOT=/duong/dan/godot bash server/run_arena_server.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
export GAME_ARENA=1
export GAME_MAP_DIR="${GAME_MAP_DIR:-res://world/maps/map_397}"
export GAME_ENET_PORT="${GAME_ENET_PORT:-7797}"
export GAME_WS_PORT="${GAME_WS_PORT:-7798}"
exec bash "$here/run_game_server.sh"
