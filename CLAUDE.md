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
