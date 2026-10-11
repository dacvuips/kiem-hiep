#!/usr/bin/env bash
# ==============================================================================
# QA Issue & Evidence Manager for Kiem-Hiep (dacvuips/kiem-hiep)
# Supports both `gh` CLI and direct GitHub REST API via `git credential fill`.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_SLUG="dacvuips/kiem-hiep"
QA_DIR="$REPO_ROOT/docs/qa_reports"
EVIDENCE_ROOT="$QA_DIR/evidence"
DASHBOARD_FILE="$QA_DIR/QA_DASHBOARD.md"

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

get_github_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "$GITHUB_TOKEN"
    return 0
  fi
  if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "$GH_TOKEN"
    return 0
  fi
  printf "protocol=https\nhost=github.com\n\n" | git -C "$REPO_ROOT" credential fill 2>/dev/null | sed -n 's/^password=//p'
}

has_gh() {
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

github_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local token
  token="$(get_github_token)"
  if [[ -z "$token" ]]; then
    echo "ERROR: Không tìm thấy GitHub token trong git credential hoặc biến môi trường GITHUB_TOKEN." >&2
    exit 1
  fi
  if [[ -n "$data" ]]; then
    curl -sS -X "$method" \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$REPO_SLUG$endpoint" \
      -d "$data"
  else
    curl -sS -X "$method" \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$REPO_SLUG$endpoint"
  fi
}

cmd_setup_labels() {
  echo "==> Đang đồng bộ nhãn (Labels) chuẩn cho QA & Triage trên $REPO_SLUG..."
  local labels_json='[
    {"name": "needs-triage", "color": "fbca04", "description": "Cần kiểm tra và phân loại mức độ ưu tiên"},
    {"name": "needs-info", "color": "d876e3", "description": "Cần thêm thông tin hoặc bước tái hiện"},
    {"name": "ready-for-agent", "color": "0e8a16", "description": "Đã đủ thông tin & bằng chứng để AI Agent tự sửa"},
    {"name": "ready-for-human", "color": "1d76db", "description": "Cần quyết định thiết kế hoặc xử lý từ Developer"},
    {"name": "qa-verified", "color": "5319e7", "description": "Phát hiện và xác thực tự động bởi Game QA Agent"},
    {"name": "incomplete-feature", "color": "f9d0c4", "description": "Tính năng đang phát triển dở dang / placeholder / thiếu hụt"},
    {"name": "ui-ux", "color": "bfdadc", "description": "Lỗi hiển thị giao diện, bố cục, nút bấm, HUD"},
    {"name": "combat-skill", "color": "e99695", "description": "Lỗi chiến đấu, môn phái, kỹ năng, công thức sát thương"},
    {"name": "performance", "color": "c2e0c6", "description": "Vấn đề hiệu năng (FPS, RAM, rò rỉ Node/Orphan Nodes)"}
  ]'

  echo "$labels_json" | jq -c '.[]' | while read -r item; do
    local name
    name="$(echo "$item" | jq -r '.name')"
    local resp
    resp="$(github_api POST "/labels" "$item" || true)"
    if echo "$resp" | jq -e '.id' >/dev/null 2>&1; then
      echo "  [+] Đã tạo label: $name"
    else
      echo "  [=] Label đã tồn tại: $name"
    fi
  done
  echo "==> Hoàn tất đồng bộ Labels!"
}

cmd_list() {
  local state="${1:-open}"
  if has_gh; then
    gh issue list --repo "$REPO_SLUG" --state "$state" --json number,title,state,labels,url \
      --jq '[.[] | {number, title, state, url: .url, labels: [.labels[].name]}]'
  else
    github_api GET "/issues?state=$state&per_page=50" \
      | jq '[.[] | select(.pull_request == null) | {number, title, state, url: .html_url, labels: [.labels[].name]}]'
  fi
}

cmd_check_duplicate() {
  local keyword="${1:-}"
  if [[ -z "$keyword" ]]; then
    echo "Usage: $0 check-duplicate <keyword>" >&2
    exit 1
  fi
  cmd_list "all" | jq --arg kw "$keyword" '[.[] | select((.title | ascii_downcase) | contains($kw | ascii_downcase))]'
}

cmd_save_evidence() {
  local slug="${1:-}"
  local label="${2:-screenshot}"
  local default_src="/tmp/godot_peek_game_screenshot.png"
  if [[ ! -f "$default_src" && -n "${TEMP:-}" && -f "${TEMP}/godot_peek_game_screenshot.png" ]]; then
    default_src="${TEMP}/godot_peek_game_screenshot.png"
  elif [[ ! -f "$default_src" && -n "${TMPDIR:-}" && -f "${TMPDIR%/}/godot_peek_game_screenshot.png" ]]; then
    default_src="${TMPDIR%/}/godot_peek_game_screenshot.png"
  fi
  local src_file="${3:-$default_src}"

  if [[ -z "$slug" ]]; then
    echo "Usage: $0 save-evidence <issue-slug> [step-name] [source-file]" >&2
    exit 1
  fi

  local date_prefix
  date_prefix="$(date +%Y-%m-%d)"
  local target_dir="$EVIDENCE_ROOT/${date_prefix}_${slug}"
  mkdir -p "$target_dir"

  if [[ ! -f "$src_file" ]]; then
    echo "ERROR: Không tìm thấy file nguồn: $src_file" >&2
    exit 1
  fi

  local ext="${src_file##*.}"
  local ts
  ts="$(date +%H%M%S)"
  local dest_file="$target_dir/${ts}_${label}.${ext}"
  cp "$src_file" "$dest_file"

  local rel_path="${dest_file#$REPO_ROOT/}"
  echo "$rel_path"
}

cmd_create_issue() {
  local title=""
  local body=""
  local body_file=""
  local labels="needs-triage,qa-verified"
  local severity="Medium"
  local category="Bug"
  local evidence_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --body) body="$2"; shift 2 ;;
      --body-file) body_file="$2"; shift 2 ;;
      --labels) labels="$2"; shift 2 ;;
      --severity) severity="$2"; shift 2 ;;
      --category) category="$2"; shift 2 ;;
      --evidence-dir) evidence_dir="$2"; shift 2 ;;
      *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$title" ]]; then
    echo "ERROR: Thiếu --title" >&2
    exit 1
  fi
  if [[ -n "$body_file" ]]; then
    body="$(cat "$body_file")"
  fi
  if [[ -z "$body" ]]; then
    echo "ERROR: Thiếu --body hoặc --body-file" >&2
    exit 1
  fi

  local issue_url=""
  local issue_number=""

  if has_gh; then
    issue_url="$(gh issue create --repo "$REPO_SLUG" --title "$title" --body "$body" --label "$labels")"
    issue_number="${issue_url##*/}"
  else
    local payload
    payload="$(jq -n \
      --arg title "$title" \
      --arg body "$body" \
      --arg labels "$labels" \
      '{
        title: $title,
        body: $body,
        labels: ($labels | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)))
      }')"
    local resp
    resp="$(github_api POST "/issues" "$payload")"
    issue_number="$(echo "$resp" | jq -r '.number // empty')"
    issue_url="$(echo "$resp" | jq -r '.html_url // empty')"
    if [[ -z "$issue_number" ]]; then
      echo "ERROR: Tạo GitHub Issue thất bại: $resp" >&2
      exit 1
    fi
  fi

  # Ghi nhận vào QA_DASHBOARD.md
  mkdir -p "$QA_DIR"
  if [[ ! -f "$DASHBOARD_FILE" ]]; then
    cat > "$DASHBOARD_FILE" <<'EOF'
# Bảng Tổng Hợp Kiểm Thử Game (QA Issue Dashboard)

Tài liệu này được **Game QA Expert Agent** cập nhật tự động sau các phiên kiểm thử thực tế trên Godot Runtime (`godot-peek` MCP). Mọi Issue đều được đồng bộ trực tiếp lên GitHub Issues kèm thư mục chứa bằng chứng (ảnh chụp màn hình, log lỗi, thông số Node).

| Issue | Phân loại | Mức độ | Tiêu đề | Bằng chứng (Evidence) | Ngày phát hiện |
|---|---|---|---|---|---|
EOF
  fi

  local date_str
  date_str="$(date '+%Y-%m-%d %H:%M')"
  local ev_link="—"
  if [[ -n "$evidence_dir" ]]; then
    ev_link="[\`$evidence_dir\`](../../$evidence_dir)"
  fi

  echo "| [#$issue_number]($issue_url) | \`$category\` | **$severity** | $title | $ev_link | $date_str |" >> "$DASHBOARD_FILE"

  jq -n \
    --arg number "$issue_number" \
    --arg url "$issue_url" \
    --arg title "$title" \
    --arg dashboard "docs/qa_reports/QA_DASHBOARD.md" \
    '{number: ($number | tonumber), url: $url, title: $title, dashboard: $dashboard}'
}

case "${1:-help}" in
  setup-labels)
    cmd_setup_labels
    ;;
  list)
    shift
    cmd_list "${1:-open}"
    ;;
  check-duplicate)
    shift
    cmd_check_duplicate "${1:-}"
    ;;
  save-evidence)
    shift
    cmd_save_evidence "${1:-}" "${2:-screenshot}" "${3:-/tmp/godot_peek_game_screenshot.png}"
    ;;
  create)
    shift
    cmd_create_issue "$@"
    ;;
  *)
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  setup-labels                                           Đồng bộ các nhãn QA & Triage chuẩn lên GitHub
  list [open|closed|all]                                 Liệt kê danh sách GitHub Issues hiện tại
  check-duplicate <keyword>                              Kiểm tra xem lỗi đã từng được báo cáo chưa
  save-evidence <issue-slug> [step-name] [src-file]      Lưu ảnh chụp màn hình / log từ /tmp vào docs/qa_reports/evidence/
  create --title "..." --body-file <path> [options]      Tạo GitHub Issue mới + ghi vào docs/qa_reports/QA_DASHBOARD.md
    Options:
      --labels "bug,needs-triage,qa-verified"
      --severity "Critical|High|Medium|Low"
      --category "Bug|Incomplete|UI-UX|Balance|Performance"
      --evidence-dir "docs/qa_reports/evidence/..."
EOF
    ;;
esac
