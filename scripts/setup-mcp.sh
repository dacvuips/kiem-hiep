#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PROJECT_DIR/tools/godot-peek-mcp/bin"
SOCKET_ENV="/tmp/godot-peek-kiem-hiep.sock"

OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" = "Darwin" ]; then
    xattr -cr "$BIN_DIR" "$PROJECT_DIR/addons/godot_mcp/bin" 2>/dev/null || true
    if [ "$ARCH" = "arm64" ]; then
        BINARY_PATH="$BIN_DIR/godot-peek-mcp-darwin-arm64"
    else
        BINARY_PATH="$BIN_DIR/godot-peek-mcp-darwin-amd64"
    fi
elif [ "$OS" = "Linux" ]; then
    BINARY_PATH="$BIN_DIR/godot-peek-mcp-linux-amd64"
else
    echo "Unsupported Unix OS: $OS (On Windows, run scripts\\setup-mcp.bat)"
    exit 1
fi

chmod +x "$BINARY_PATH"

update_json_config() {
    local file_path="$1"
    mkdir -p "$(dirname "$file_path")"
    python3 - "$file_path" "$BINARY_PATH" "$SOCKET_ENV" <<'PYEOF'
import json, os, sys

file_path, binary_path, socket_env = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read().strip()
            if content:
                data = json.loads(content)
    except Exception:
        data = {}

if not isinstance(data.get("mcpServers"), dict):
    data["mcpServers"] = {}

data["mcpServers"]["godot-peek"] = {
    "command": binary_path,
    "env": {
        "GODOT_PEEK_SOCKET": socket_env
    }
}

with open(file_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"[OK] Updated: {file_path}")
PYEOF
}

echo "=== Setting up Godot Peek MCP ($OS / $ARCH) ==="
update_json_config "$PROJECT_DIR/.cursor/mcp.json"
update_json_config "$PROJECT_DIR/.mcp.json"
update_json_config "$HOME/.gemini/config/mcp_config.json"

if [ -d "$HOME/Library/Application Support/Claude" ]; then
    update_json_config "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
fi

if command -v claude >/dev/null 2>&1; then
    claude mcp remove godot-peek -s local >/dev/null 2>&1 || true
    claude mcp add godot-peek -s local -e "GODOT_PEEK_SOCKET=$SOCKET_ENV" -- "$BINARY_PATH" >/dev/null 2>&1 || true
    echo "[OK] Registered in Claude Code local config"
fi

echo "=== Setup Completed Successfully! ==="

