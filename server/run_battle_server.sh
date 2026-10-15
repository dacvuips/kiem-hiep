#!/usr/bin/env bash
# Chạy CHIẾN TRƯỜNG TỐNG KIM (game server riêng, map 378) trên máy dev — cạnh server thế giới (run_game_server.sh).
#   GODOT=/duong/dan/godot bash server/run_battle_server.sh
# Test nhanh: GAME_BATTLE_SIGNUP=60 GAME_BATTLE_FIGHT=300 GAME_BATTLE_MIN_LEVEL=1 bash server/run_battle_server.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
export GAME_BATTLE=1
export GAME_MAP_DIR="${GAME_MAP_DIR:-res://world/maps/map_378}"
export GAME_ENET_PORT="${GAME_ENET_PORT:-7787}"
export GAME_WS_PORT="${GAME_WS_PORT:-7788}"
exec bash "$here/run_game_server.sh"
