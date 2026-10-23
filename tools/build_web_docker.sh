#!/usr/bin/env bash
# Script xuất bản Web và đóng gói Docker cục bộ (để test trước khi push lên main)
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

echo "==> 1. Tạo thư mục output..."
mkdir -p docker/web/dist

echo "==> 2. Xuất bản Web bằng Godot..."
if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="godot"
else
    echo "Lỗi: Không tìm thấy lệnh 'godot' trong PATH."
    exit 1
fi

$GODOT_BIN --headless --path . --export-release "Web" docker/web/dist/index.html

echo "==> 3. Build Docker image kiemhiep-web:local..."
docker build -t kiemhiep-web:local docker/web

echo "==> Hoàn tất! Chạy thử container bằng lệnh:"
echo "    docker run --rm -p 8088:80 kiemhiep-web:local"
echo "    Sau đó truy cập http://localhost:8088"
