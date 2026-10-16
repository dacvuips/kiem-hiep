#!/usr/bin/env bash
# CHẠY TOÀN BỘ BÀI TEST — bash server/test.sh [--battle]   (hoặc: bash server/dev.sh test)
#
#   1. Bài test không cần server (logic, giao diện, auto, chọn phái, mục tiêu).
#   2. Server tài khoản (Docker, bật nếu chưa chạy) -> bài test tài khoản.
#   3. Tự bật game server THỬ bằng Godot từ MÃ NGUỒN HIỆN TẠI ở cổng riêng (79xx — không đụng server thật 77xx/78xx đang chạy):
#        thế giới 7917/7918 (chế độ kiểm thử), 2 phòng train chung 7927/7928 + 7937/7938 (index 7, 8)
#      -> bài test mạng + phòng train chung. --battle: thêm chiến trường Tống Kim (trận rút ngắn, ~3 phút).
#   4. Tắt hết server thử (cả khi Ctrl+C), in bảng tổng kết; thoát mã 1 nếu có bài hỏng.
# Bài test không bao giờ ghi đè dữ liệu chơi trên máy (KIEMHIEP_NO_SAVE=1). Tài khoản bot tạo trong DB dev (tiền tố n/fd/tk).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
project="$(dirname "$here")"
logs="$here/game/test-logs"
# Repo backend (server tài khoản, docker-compose, .env) tách riêng: mặc định nằm cạnh repo game.
SERVER_REPO="${SERVER_REPO:-$(cd "$project/.." && pwd)/kiem-hiep-server}"
mkdir -p "$logs"
MARK="--kiemhiep-test-server"   # dấu trên dòng lệnh của server thử -> chỉ tắt đúng các tiến trình này
BATTLE=0
[ "${1:-}" = "--battle" ] && BATTLE=1

env_get() { grep -E "^$1=" "$SERVER_REPO/.env" | tail -n 1 | cut -d= -f2- | tr -d '' || true; }
[ -f "$SERVER_REPO/.env" ] || { echo "Lỗi: chưa có $SERVER_REPO/.env (repo backend kiem-hiep-server)"; exit 1; }
GODOT="${GODOT:-$(env_get GODOT_PATH)}"
[ -n "$GODOT" ] || { echo "Lỗi: đặt GODOT_PATH trong $SERVER_REPO/.env"; exit 1; }
export KIEMHIEP_NO_SAVE=1

stop_test_servers() {
	if command -v powershell >/dev/null 2>&1; then
		powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*$MARK*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
	else
		pkill -f -- "$MARK" >/dev/null 2>&1
	fi
	true
}
trap stop_test_servers EXIT

## start_server <tên> <biến môi trường...> — chạy game server thử ở nền, chờ dòng "Game server" trong log (tối đa 60 giây).
start_server() {
	local name=$1
	shift
	env GAME_SERVICE_KEY="$(env_get GAME_SERVICE_KEY)" GAME_ACCOUNT_URL="http://127.0.0.1:8080" GAME_SERVER_ID=1 GAME_DEV_TRUST_CLIENT=0 \
		GAME_STATUS_POLL=2 "$@" "$GODOT" --headless --path "$project" res://net/server/game_server.tscn -- "$MARK" > "$logs/$name.log" 2>&1 &
	for _ in $(seq 1 120); do
		grep -q "^Game server" "$logs/$name.log" 2>/dev/null && return 0
		sleep 0.5
	done
	echo "  !! server thử $name không khởi động được (xem $logs/$name.log)"
	return 1
}

declare -a NAMES RESULTS
FAILED=0
## run_suite <tên hiển thị> <scene> [biến môi trường...]
run_suite() {
	local label=$1 scene=$2
	shift 2
	printf '  %-28s ' "$label"
	local out="$logs/$(basename "$scene" .tscn).out"
	env "$@" timeout 900 "$GODOT" --headless --path "$project" "res://tests/$scene" > "$out" 2>&1
	local code=$?
	local result fails
	result="$(grep -a "^RESULT" "$out" | tail -n 1)"
	fails="$(grep -ac "^FAIL" "$out")"
	if [ -z "$result" ]; then result="(không chạy xong, mã $code)"; fails=$((fails + 1)); fi
	if grep -aq "SCRIPT ERROR" "$out"; then result="$result + LỖI SCRIPT"; fails=$((fails + 1)); fi
	if [ "$fails" -gt 0 ]; then
		FAILED=1
		echo "HỎNG  $result"
		grep -a "^FAIL\|SCRIPT ERROR" "$out" | head -n 8 | sed 's/^/      /'
	else
		echo "ĐẠT   $result"
	fi
	grep -a "^SKIP" "$out" | sed 's/^/      /'
}

cd "$project"
echo "== Bài test không cần server"
for s in social_tests social_ui_tests auto_tests sect_join_tests target_tests; do
	run_suite "$s" "$s.tscn"
done

echo "== Server tài khoản"
if ! curl -fsS -m 3 http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
	(cd "$SERVER_REPO" && docker compose up -d account) >/dev/null 2>&1
	for _ in $(seq 1 60); do curl -fsS -m 2 http://127.0.0.1:8080/healthz >/dev/null 2>&1 && break; sleep 1; done
fi
if ! curl -fsS -m 3 http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
	echo "  !! server tài khoản không chạy — bỏ các bài test cần server"
	exit 1
fi
run_suite "account_tests" account_tests.tscn

echo "== Game server thử (mã nguồn hiện tại)"
stop_test_servers
start_server world GAME_TEST_MODE=1 GAME_ENET_PORT=7917 GAME_WS_PORT=7918
start_server field7 GAME_FIELD=1 GAME_FIELD_INDEX=7 GAME_ENET_PORT=7927 GAME_WS_PORT=7928
start_server field8 GAME_FIELD=1 GAME_FIELD_INDEX=8 GAME_ENET_PORT=7937 GAME_WS_PORT=7938
run_suite "net_tests" net_tests.tscn GAME_ENET_PORT=7917 DEV_TRUST_CLIENT_SAVES="$(env_get DEV_TRUST_CLIENT_SAVES)" NET_TEST_RESTART=1
run_suite "field_tests (2 tiến trình)" field_tests.tscn GAME_ENET_PORT=7927 FIELD_PORT2=7937 FIELD_INDEX=7 FIELD_INDEX2=8
if [ "$BATTLE" = 1 ]; then
	## Chiến trường báo trạng thái theo mã máy chủ (1 chiến trường / máy chủ): tạm dừng chiến trường Docker để /v1/battle là của bản thử.
	docker_battle="$(cd "$SERVER_REPO" && docker compose ps -q battle 2>/dev/null)"
	if [ -n "$docker_battle" ]; then
		echo "  (tạm dừng chiến trường Docker trong lúc thử, xong bật lại)"
		(cd "$SERVER_REPO" && docker compose stop battle) >/dev/null 2>&1
		sleep 2   ## bản thử báo trạng thái mỗi vài giây, ghi đè trạng thái cũ của bản Docker
	fi
	start_server battle GAME_TEST_MODE=1 GAME_BATTLE=1 GAME_MAP_DIR=res://world/maps/map_378 GAME_ENET_PORT=7947 GAME_WS_PORT=7948 \
		GAME_BATTLE_SIGNUP=50 GAME_BATTLE_FIGHT=110 GAME_BATTLE_MIN_LEVEL=1 GAME_BATTLE_MARSHAL_LIFE=100000
	run_suite "battle_tests" battle_tests.tscn GAME_ENET_PORT=7947 BATTLE_API=http://127.0.0.1:8080
	if [ -n "$docker_battle" ]; then (cd "$SERVER_REPO" && docker compose start battle) >/dev/null 2>&1; fi
fi
for f in "$logs"/*.log; do
	if grep -aq "SCRIPT ERROR" "$f"; then
		FAILED=1
		echo "  !! LỖI SCRIPT trong log server $(basename "$f"):"
		grep -a "SCRIPT ERROR" "$f" | sort | uniq -c | head -n 5 | sed 's/^/      /'
	fi
done

echo
if [ "$FAILED" = 0 ]; then echo "TẤT CẢ ĐẠT (log: server/game/test-logs/)"; else echo "CÓ BÀI HỎNG (log: server/game/test-logs/)"; fi
exit "$FAILED"
