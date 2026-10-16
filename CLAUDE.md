## Backend nằm ở repo RIÊNG — `../kiem-hiep-server`

Server tài khoản (Go), web Admin, web người chơi, `docker-compose.yml`, `.env` máy dev và deploy Docker Swarm / GitHub Actions
đã tách sang repo **kiem-hiep-server** (`D:\game\lam-game\kiem-hiep-server`). **Mọi sửa backend làm trong repo đó**, không tạo lại
`server/account`, `server/admin-web`, `server/portal-web`, `server/deploy` hay `server/docker-compose.yml` ở repo này.

Ở lại repo game (vì dùng chung code combat / quái / map): game server Godot `net/`, `server/game/Dockerfile`,
`server/dev.sh`, `server/test.sh`, `server/run_*_server.sh`, `server/client/`, `.github/workflows/game-server.yml`.
Sửa giao thức / API giữa game và backend (VD `/internal/*`, `/v1/*`) thì sửa CẢ 2 repo cho khớp.
Công cụ ghi sang repo backend: `tools/export_admin_catalog.gd` (catalog.json), `tools/export_potion_prices.py`.

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`dacvuips/kiem-hiep`) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Game QA & Playtesting Expert Agent (`game-qa-tester`)

- **Skill & Playbooks**: `.agents/skills/game-qa-tester/SKILL.md` (kịch bản chi tiết tại `.agents/skills/game-qa-tester/references/playtest-playbooks.md` và mẫu báo cáo tại `.agents/skills/game-qa-tester/references/issue-template.md`).
- **Issue & Evidence CLI**: Sử dụng `./scripts/qa-issue.sh` để lưu bằng chứng ảnh chụp/log vào `docs/qa_reports/evidence/`, kiểm tra trùng lặp, tạo trực tiếp GitHub Issue (`dacvuips/kiem-hiep`) và cập nhật bảng `docs/qa_reports/QA_DASHBOARD.md`.
