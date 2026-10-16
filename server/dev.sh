#!/usr/bin/env bash
# QUẢN LÝ MÁY DEV — 1 lệnh cho cả hệ thống (account + game server thế giới / Tống Kim / Đấu trường / Phòng train chung).
#
#   bash server/dev.sh up [service...]   build lại gói game server NẾU code đổi, rồi bật (mặc định: tất cả)
#   bash server/dev.sh down              tắt hết (GIỮ NGUYÊN dữ liệu PostgreSQL)
#   bash server/dev.sh restart <service> build nếu cần + bật lại 1 service
#   bash server/dev.sh status            bảng service / cổng / bản code đang chạy so với code hiện tại
#   bash server/dev.sh logs <service>    xem log (Ctrl+C để thoát)
#   bash server/dev.sh build             ép build lại gói game server + image
#   bash server/dev.sh local <loại>      chạy game server bằng Godot trên máy (không Docker): world | battle | arena | field
#   bash server/dev.sh test              chạy toàn bộ bài test (xem server/test.sh)
#
# Server tài khoản + docker-compose + .env nằm ở repo RIÊNG kiem-hiep-server (mặc định ../kiem-hiep-server, đổi bằng SERVER_REPO).
# Cấu hình duy nhất: <SERVER_REPO>/.env. Đường dẫn Godot: GODOT_PATH trong .env (hoặc biến GODOT).
# Game server chạy bằng image kiemhiep-game:local build từ server/game/ (thư mục này).
# Script KHÔNG bao giờ xoá volume dữ liệu và không in khoá bí mật ra màn hình.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
project="$(dirname "$here")"
pck="$here/game/game_server.pck"
# Repo backend (server tài khoản, docker-compose, .env) tách riêng: mặc định nằm cạnh repo game.
SERVER_REPO="${SERVER_REPO:-$(cd "$project/.." && pwd)/kiem-hiep-server}"
GAME_SERVICES=(game battle arena field)

die() { echo "Lỗi: $*" >&2; exit 1; }

[ -f "$SERVER_REPO/docker-compose.yml" ] || die "không thấy repo backend ở $SERVER_REPO (clone kiem-hiep-server cạnh repo game, hoặc đặt SERVER_REPO=...)"
[ -f "$SERVER_REPO/.env" ] || die "chưa có $SERVER_REPO/.env — chép .env.example thành .env rồi điền khoá."

## Đọc 1 biến không bí mật từ .env (không source cả file: tránh chạy lệnh lạ trong .env và lộ khoá vào môi trường shell).
env_get() { grep -E "^$1=" "$SERVER_REPO/.env" | tail -n 1 | cut -d= -f2- | tr -d '' || true; }

godot_bin() {
	local g="${GODOT:-$(env_get GODOT_PATH)}"
	[ -n "$g" ] || g="godot"
	command -v "$g" >/dev/null 2>&1 || [ -x "$g" ] || die "không tìm thấy Godot ('$g') — đặt GODOT_PATH=/đường/dẫn/godot trong $SERVER_REPO/.env"
	echo "$g"
}

compose() { (cd "$SERVER_REPO" && docker compose --profile game "$@"); }

## Image game server dùng trong docker-compose của repo backend (GAME_IMAGE, mặc định kiemhiep-game:local).
build_image() { docker build -q -t kiemhiep-game:local "$here/game" >/dev/null || die "build image kiemhiep-game:local lỗi"; }

## Mỗi lần build, image cũ thành image "mồ côi" (<none>) chiếm ổ — dọn ngay (chỉ image không container nào dùng; không đụng volume).
prune_dangling() { docker image prune -f >/dev/null 2>&1 || true; }

## File code / dữ liệu mới hơn gói server -> cần build lại. (Giống bộ lọc xuất gói: bỏ tools, tests, server, ảnh client...)
pck_stale() {
	[ -f "$pck" ] || return 0
	local newer
	newer="$(cd "$project" && find . \( -path ./.godot -o -path ./server -o -path ./tests -o -path ./tools -o -path ./android -o -path ./build \
		-o -path ./launcher -o -path ./docs -o -path ./assets -o -path ./audio \) -prune -o -type f \
		\( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' -o -name '*.json' -o -name '*.json.gz' -o -name 'project.godot' \) \
		-newer "$pck" -print -quit)"
	[ -n "$newer" ]
}

## Dấu phiên bản đóng vào gói (res://build_info.json — đã .gitignore): game server in ra lúc khởi động + báo lên web Admin.
write_build_info() {
	local commit dirty
	commit="$(cd "$project" && git rev-parse --short HEAD 2>/dev/null || echo "?")"
	dirty="false"
	[ -n "$(cd "$project" && git status --porcelain --untracked-files=no 2>/dev/null)" ] && dirty="true"
	printf '{"commit": "%s", "dirty": %s, "built_at": "%s"}\n' "$commit" "$dirty" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$project/build_info.json"
}

build_pck() {
	local g
	g="$(godot_bin)"
	write_build_info
	echo "Build gói game server ($(cat "$project/build_info.json"))..."
	"$g" --headless --path "$project" --export-pack "Game Server (Linux)" "$pck" > "$here/game/export.log" 2>&1 \
		|| { rm -f "$project/build_info.json"; tail -n 20 "$here/game/export.log"; die "xuất gói thất bại (log đầy đủ: server/game/export.log)"; }
	echo "  -> $(du -h "$pck" | cut -f1) $pck"
	cp "$project/build_info.json" "$here/game/build_info.json"   ## bản ghi của gói vừa build (dev.sh status đọc)
	rm -f "$project/build_info.json"   ## chỉ nằm TRONG gói: chạy thẳng mã nguồn thì game server ghi "(chạy từ mã nguồn)", không nhận nhầm bản
}

ensure_pck() {
	if pck_stale; then
		echo "Code game đổi từ lần build trước -> build lại gói server."
		build_pck
	fi
}

wants_game() {
	[ $# -eq 0 ] && return 0
	for s in "$@"; do
		for g in "${GAME_SERVICES[@]}"; do [ "$s" = "$g" ] && return 0; done
	done
	return 1
}

cmd="${1:-help}"
shift || true
case "$cmd" in
	up)
		if wants_game "$@"; then ensure_pck; build_image; fi
		compose up -d --build "$@"
		prune_dangling
		"$0" status
		;;
	down)
		compose down   # KHÔNG -v: giữ volume PostgreSQL
		;;
	restart)
		[ $# -ge 1 ] || die "cần tên service, VD: dev.sh restart field"
		if wants_game "$@"; then ensure_pck; build_image; fi
		compose up -d --build --force-recreate "$@"
		prune_dangling
		;;
	build)
		build_pck
		build_image
		compose build account
		prune_dangling
		;;
	status)
		compose ps --format "table {{.Service}}\t{{.State}}\t{{.Ports}}"
		echo
		if [ -f "$here/game/build_info.json" ]; then echo "Gói server đã build: $(cat "$here/game/build_info.json")"; fi
		echo "Code hiện tại      : $(cd "$project" && git rev-parse --short HEAD 2>/dev/null)$( [ -n "$(cd "$project" && git status --porcelain --untracked-files=no)" ] && echo " (có sửa chưa commit)")"
		if pck_stale; then echo "!! Gói server CŨ hơn code — chạy: bash server/dev.sh up"; fi
		if curl -fsS -m 3 http://127.0.0.1:8080/healthz >/dev/null 2>&1; then echo "Account API: OK (http://localhost:8080, Admin: /admin/)"; else echo "Account API: KHÔNG phản hồi"; fi
		;;
	pck)   # chỉ xuất gói game server (deploy.sh game của repo backend gọi)
		build_pck
		;;
	logs)
		[ $# -ge 1 ] || die "cần tên service, VD: dev.sh logs field"
		compose logs -f --tail 200 "$@"
		;;
	local)
		kind="${1:-world}"
		g="$(godot_bin)"
		export GODOT="$g"
		case "$kind" in
			world) exec bash "$here/run_game_server.sh" ;;
			battle) exec bash "$here/run_battle_server.sh" ;;
			arena) exec bash "$here/run_arena_server.sh" ;;
			field) exec bash "$here/run_field_server.sh" ;;
			*) die "loại không hợp lệ: $kind (world | battle | arena | field)" ;;
		esac
		;;
	test)
		exec bash "$here/test.sh" "$@"
		;;
	*)
		sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
		;;
esac
