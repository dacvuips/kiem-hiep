# Quy Tắc Điều Phối Chuyên Gia Kiểm Thử Game (Game QA Expert Agent)

Khi người dùng yêu cầu **kiểm thử game**, **chơi thử (playtest)**, **tìm bug**, **rà soát chỗ chưa hoàn thiện**, hoặc **tổng hợp danh sách Issue kèm bằng chứng (Evidence)**:

1. **Kích hoạt ngay skill `game-qa-tester`**: Đọc đầy đủ hướng dẫn tại `.agents/skills/game-qa-tester/SKILL.md` và kịch bản tại `.agents/skills/game-qa-tester/references/playtest-playbooks.md`.
2. **Sử dụng Subagent chuyên biệt khi chạy kiểm thử sâu hoặc liên tục**:
   - Dùng `define_subagent` để định nghĩa subagent `game_qa_specialist` (bật `enable_write_tools: true`, `enable_mcp_tools: true`) rồi gọi `invoke_subagent` để trợ lý QA tự động mở game qua `godot-peek` MCP, chơi thử từng màn, chụp ảnh màn hình, kiểm tra Debugger/Monitors và lập báo cáo.
3. **Bắt buộc lưu Evidence & Tạo GitHub Issue qua `scripts/qa-issue.sh`**:
   - Mọi lỗi và tính năng chưa hoàn thiện phát hiện được phải có bằng chứng thực tế lưu trong `docs/qa_reports/evidence/` (qua `./scripts/qa-issue.sh save-evidence <slug> <step>`).
   - Tự động kiểm tra trùng lặp (`./scripts/qa-issue.sh check-duplicate "<keyword>"`) trước khi đẩy trực tiếp lên GitHub Issues và cập nhật bảng `docs/qa_reports/QA_DASHBOARD.md` (qua `./scripts/qa-issue.sh create ...`).

