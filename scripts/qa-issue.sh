#!/usr/bin/env bash
# ==============================================================================
# QA Issue, MR/PR & Evidence Manager for Kiem-Hiep (dacvuips/kiem-hiep)
# Supports both `gh` CLI and direct GitHub REST API via `git credential fill`.
# Automatically uploads screenshot/log evidence to the `qa-evidence` branch on
# GitHub so inline Markdown images (`![...](https://...?raw=true)`) render
# directly inside GitHub Issue descriptions and Merge Request (PR) descriptions.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_SLUG="dacvuips/kiem-hiep"
EVIDENCE_BRANCH="${QA_EVIDENCE_BRANCH:-qa-evidence}"
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
    if [[ "$data" == @* ]]; then
      curl -sS -X "$method" \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$REPO_SLUG$endpoint" \
        --data-binary "$data"
    else
      curl -sS -X "$method" \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$REPO_SLUG$endpoint" \
        -d "$data"
    fi
  else
    curl -sS -X "$method" \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$REPO_SLUG$endpoint"
  fi
}

ensure_evidence_branch() {
  local branch_sha
  branch_sha="$(github_api GET "/git/ref/heads/$EVIDENCE_BRANCH" | jq -r '.object.sha // empty' 2>/dev/null || true)"
  if [[ -n "$branch_sha" ]]; then
    return 0
  fi
  local main_sha
  main_sha="$(github_api GET "/git/ref/heads/main" | jq -r '.object.sha // empty')"
  if [[ -z "$main_sha" ]]; then
    echo "ERROR: Không lấy được SHA của nhánh main để khởi tạo $EVIDENCE_BRANCH." >&2
    exit 1
  fi
  github_api POST "/git/refs" "{\"ref\":\"refs/heads/$EVIDENCE_BRANCH\",\"sha\":\"$main_sha\"}" >/dev/null
}

# Upload 1 file lên nhánh qa-evidence và trả về URL hiển thị trực tiếp (raw=true cho ảnh)
upload_single_file() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    # Thử ghép với REPO_ROOT nếu là đường dẫn tương đối
    if [[ -f "$REPO_ROOT/$file_path" ]]; then
      file_path="$REPO_ROOT/$file_path"
    else
      echo "ERROR: Không tìm thấy file để upload: $file_path" >&2
      exit 1
    fi
  fi

  local abs_path
  abs_path="$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")"
  local rel_path="${abs_path#$REPO_ROOT/}"
  if [[ "$rel_path" == "$abs_path" ]]; then
    # Nếu file nằm ngoài repo (ví dụ /tmp), đặt vào docs/qa_reports/evidence/uploads/
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    rel_path="docs/qa_reports/evidence/uploads/${ts}_$(basename "$file_path")"
  fi

  ensure_evidence_branch

  local existing_sha
  existing_sha="$(github_api GET "/contents/$rel_path?ref=$EVIDENCE_BRANCH" | jq -r '.sha // empty' 2>/dev/null || true)"

  local b64_file="/tmp/qa_upload_b64_$$.txt"
  local payload_file="/tmp/qa_upload_payload_$$.json"
  base64 < "$abs_path" | tr -d '\r\n' > "$b64_file"

  if [[ -n "$existing_sha" ]]; then
    jq -n \
      --arg msg "chore(qa): upload evidence $rel_path" \
      --rawfile content "$b64_file" \
      --arg branch "$EVIDENCE_BRANCH" \
      --arg sha "$existing_sha" \
      '{message: $msg, content: $content, branch: $branch, sha: $sha}' > "$payload_file"
  else
    jq -n \
      --arg msg "chore(qa): upload evidence $rel_path" \
      --rawfile content "$b64_file" \
      --arg branch "$EVIDENCE_BRANCH" \
      '{message: $msg, content: $content, branch: $branch}' > "$payload_file"
  fi

  local resp
  resp="$(github_api PUT "/contents/$rel_path" "@$payload_file")"
  rm -f "$b64_file" "$payload_file"

  local html_url
  html_url="$(echo "$resp" | jq -r '.content.html_url // empty')"
  if [[ -z "$html_url" ]]; then
    echo "ERROR: Upload file $rel_path lên GitHub thất bại: $resp" >&2
    exit 1
  fi

  local ext
  ext="$(echo "${rel_path##*.}" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    png|jpg|jpeg|gif|webp)
      echo "${html_url}?raw=true"
      ;;
    *)
      echo "$html_url"
      ;;
  esac
}

# Tạo khối Markdown chứa toàn bộ ảnh & file log trong 1 thư mục hoặc 1 file lẻ
build_evidence_markdown() {
  local target="$1"
  local abs_target="$target"
  if [[ ! -e "$abs_target" && -e "$REPO_ROOT/$target" ]]; then
    abs_target="$REPO_ROOT/$target"
  fi

  if [[ -f "$abs_target" ]]; then
    local url
    url="$(upload_single_file "$abs_target")"
    local fname
    fname="$(basename "$abs_target")"
    local ext
    ext="$(echo "${fname##*.}" | tr '[:upper:]' '[:lower:]')"
    case "$ext" in
      png|jpg|jpeg|gif|webp)
        printf -- "- **%s**:\n\n  ![%s](%s)\n" "$fname" "$fname" "$url"
        ;;
      *)
        printf -- "- [\`%s\`](%s)\n" "$fname" "$url"
        ;;
    esac
    return 0
  fi

  if [[ -d "$abs_target" ]]; then
    local f
    for f in "$abs_target"/*; do
      [[ -f "$f" ]] || continue
      local fname
      fname="$(basename "$f")"
      [[ "$fname" == "README.md" || "$fname" == .* ]] && continue
      local url
      url="$(upload_single_file "$f")"
      local ext
      ext="$(echo "${fname##*.}" | tr '[:upper:]' '[:lower:]')"
      case "$ext" in
        png|jpg|jpeg|gif|webp)
          printf -- "- **%s**:\n\n  ![%s](%s)\n\n" "$fname" "$fname" "$url"
          ;;
        *)
          printf -- "- Dữ liệu đính kèm: [\`%s\`](%s)\n\n" "$fname" "$url"
          ;;
      esac
    done
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
  local upload_flag="${4:---upload}"

  if [[ -z "$slug" ]]; then
    echo "Usage: $0 save-evidence <issue-slug> [step-name] [source-file] [--upload|--local-only]" >&2
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
  if [[ "$upload_flag" != "--local-only" ]]; then
    local remote_url
    remote_url="$(upload_single_file "$dest_file" || true)"
    if [[ -n "$remote_url" ]]; then
      echo "$rel_path"
      echo "MARKDOWN_EMBED: ![$label]($remote_url)" >&2
      return 0
    fi
  fi
  echo "$rel_path"
}

cmd_upload_evidence() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    echo "Usage: $0 upload-evidence <file-or-directory>" >&2
    exit 1
  fi
  build_evidence_markdown "$target"
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

  # Tự động upload hình ảnh trong --evidence-dir và nhúng trực tiếp vào nội dung Issue nếu chưa có ảnh inline
  if [[ -n "$evidence_dir" ]]; then
    local uploaded_md
    uploaded_md="$(build_evidence_markdown "$evidence_dir")"
    if [[ -n "$uploaded_md" ]] && ! echo "$body" | grep -q "raw=true"; then
      body="${body}

---
### Hình Ảnh & Bằng Chứng Trực Quan (Uploaded Evidence)
${uploaded_md}"
    fi
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

cmd_attach_issue() {
  local issue_number="${1:-}"
  local evidence_target="${2:-}"
  local section_title="${3:-Hình Ảnh & Bằng Chứng Trực Quan (Uploaded Evidence)}"

  if [[ -z "$issue_number" || -z "$evidence_target" ]]; then
    echo "Usage: $0 attach-issue <issue-number> <evidence-file-or-dir> [section-title]" >&2
    exit 1
  fi

  local uploaded_md
  uploaded_md="$(build_evidence_markdown "$evidence_target")"
  if [[ -z "$uploaded_md" ]]; then
    echo "ERROR: Không tìm thấy file hợp lệ trong $evidence_target" >&2
    exit 1
  fi

  local current_body
  current_body="$(github_api GET "/issues/$issue_number" | jq -r '.body // ""')"
  local new_body="${current_body}

---
### ${section_title}
${uploaded_md}"

  local payload_file="/tmp/qa_patch_issue_$$.json"
  jq -n --arg body "$new_body" '{body: $body}' > "$payload_file"
  local resp
  resp="$(github_api PATCH "/issues/$issue_number" "@$payload_file")"
  rm -f "$payload_file"

  echo "$resp" | jq '{number: .number, url: .html_url, updated: true}'
}

cmd_attach_mr() {
  local mr_number="${1:-}"
  local evidence_target="${2:-}"
  local section_title="${3:-Bằng Chứng Kiểm Thử (QA Evidence Screenshots)}"

  if [[ -z "$mr_number" || -z "$evidence_target" ]]; then
    echo "Usage: $0 attach-mr <mr-or-pr-number> <evidence-file-or-dir> [section-title]" >&2
    exit 1
  fi

  local uploaded_md
  uploaded_md="$(build_evidence_markdown "$evidence_target")"
  if [[ -z "$uploaded_md" ]]; then
    echo "ERROR: Không tìm thấy file hợp lệ trong $evidence_target" >&2
    exit 1
  fi

  local current_body
  current_body="$(github_api GET "/pulls/$mr_number" | jq -r '.body // ""')"
  local new_body="${current_body}

---
## ${section_title}
${uploaded_md}"

  local payload_file="/tmp/qa_patch_mr_$$.json"
  jq -n --arg body "$new_body" '{body: $body}' > "$payload_file"
  local resp
  resp="$(github_api PATCH "/pulls/$mr_number" "@$payload_file")"
  rm -f "$payload_file"

  echo "$resp" | jq '{number: .number, url: .html_url, updated: true}'
}

cmd_create_mr() {
  local title=""
  local body=""
  local body_file=""
  local head_branch=""
  local base_branch="main"
  local evidence_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --body) body="$2"; shift 2 ;;
      --body-file) body_file="$2"; shift 2 ;;
      --head) head_branch="$2"; shift 2 ;;
      --base) base_branch="$2"; shift 2 ;;
      --evidence-dir) evidence_dir="$2"; shift 2 ;;
      *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$head_branch" ]]; then
    head_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
  fi
  if [[ -z "$title" ]]; then
    echo "ERROR: Thiếu --title cho MR/PR" >&2
    exit 1
  fi
  if [[ -n "$body_file" ]]; then
    body="$(cat "$body_file")"
  fi

  if [[ -n "$evidence_dir" ]]; then
    local uploaded_md
    uploaded_md="$(build_evidence_markdown "$evidence_dir")"
    if [[ -n "$uploaded_md" ]] && ! echo "$body" | grep -q "raw=true"; then
      body="${body}

---
## Bằng Chứng Kiểm Thử (QA Evidence Screenshots)
${uploaded_md}"
    fi
  fi

  local payload_file="/tmp/qa_create_mr_$$.json"
  jq -n \
    --arg title "$title" \
    --arg body "$body" \
    --arg head "$head_branch" \
    --arg base "$base_branch" \
    '{title: $title, body: $body, head: $head, base: $base}' > "$payload_file"
  local resp
  resp="$(github_api POST "/pulls" "@$payload_file")"
  rm -f "$payload_file"

  local mr_num
  mr_num="$(echo "$resp" | jq -r '.number // empty')"
  if [[ -z "$mr_num" ]]; then
    echo "ERROR: Tạo MR/PR thất bại: $resp" >&2
    exit 1
  fi
  echo "$resp" | jq '{number: .number, url: .html_url, title: .title, head: .head.ref, base: .base.ref}'
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
    cmd_save_evidence "${1:-}" "${2:-screenshot}" "${3:-/tmp/godot_peek_game_screenshot.png}" "${4:---upload}"
    ;;
  upload-evidence)
    shift
    cmd_upload_evidence "${1:-}"
    ;;
  create)
    shift
    cmd_create_issue "$@"
    ;;
  attach-issue)
    shift
    cmd_attach_issue "$@"
    ;;
  attach-mr|attach-pr)
    shift
    cmd_attach_mr "$@"
    ;;
  create-mr|create-pr)
    shift
    cmd_create_mr "$@"
    ;;
  *)
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  setup-labels                                           Đồng bộ các nhãn QA & Triage chuẩn lên GitHub
  list [open|closed|all]                                 Liệt kê danh sách GitHub Issues hiện tại
  check-duplicate <keyword>                              Kiểm tra xem lỗi đã từng được báo cáo chưa
  save-evidence <issue-slug> [step-name] [src-file]      Lưu ảnh chụp màn hình / log vào docs/qa_reports/evidence/ và tự động upload lên nhánh $EVIDENCE_BRANCH
  upload-evidence <file-or-dir>                          Upload file/thư mục bằng chứng lên GitHub ($EVIDENCE_BRANCH) và xuất đoạn Markdown ![...](url)
  create --title "..." --body-file <path> [options]      Tạo GitHub Issue mới (tự động upload & nhúng hình ảnh từ --evidence-dir) + ghi vào QA_DASHBOARD.md
  attach-issue <issue-number> <file-or-dir> [title]      Upload và đính kèm hình ảnh trực tiếp vào mô tả của một GitHub Issue có sẵn
  attach-mr <mr-number> <file-or-dir> [title]            Upload và đính kèm hình ảnh trực tiếp vào MR / PR description có sẵn (alias: attach-pr)
  create-mr --title "..." --body-file <path> [options]   Tạo MR / PR mới và tự động upload + đính kèm ảnh từ --evidence-dir vào MR description (alias: create-pr)
EOF
    ;;
esac
