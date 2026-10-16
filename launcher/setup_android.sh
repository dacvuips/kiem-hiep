#!/usr/bin/env bash
# Cài template Android gradle cho project launcher + chép đè GodotApp.java (khởi động game bằng --main-pack).
# Chạy lại mỗi khi nâng phiên bản Godot hoặc sửa launcher/android_src/GodotApp.java.
#   bash launcher/setup_android.sh
# Lấy template từ android/ của project game (Editor game: Project > Install Android Build Template).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$(dirname "$here")/android"
dst="$here/android"
if [[ ! -f "$src/.build_version" || ! -d "$src/build" ]]; then
	echo "Chưa có template Android ở $src — mở project game trong Editor: Project > Install Android Build Template" >&2
	exit 1
fi
rm -rf "$dst"
mkdir -p "$dst"
cp "$src/.build_version" "$dst/"
# Bỏ .gradle / build/ (kết quả build cũ của project game).
(cd "$src" && tar --exclude='build/.gradle' --exclude='build/build' -cf - build) | (cd "$dst" && tar -xf -)
cp "$here/android_src/GodotApp.java" "$dst/build/src/main/java/com/godot/game/GodotApp.java"
echo "Đã cài template $(cat "$dst/.build_version") vào $dst"
