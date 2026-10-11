# Mẫu Chuẩn Báo Cáo GitHub Issue, MR Description & Bằng Chứng Kiểm Thử (QA Issue & MR Standard Template)

Mỗi khi phát hiện lỗi (Bug), bất cập giao diện (UI/UX), sai lệch công thức/môn phái (Combat/Skill), tính năng chưa hoàn thiện (Incomplete Feature), hoặc khi tạo/cập nhật **Merge Request / Pull Request (MR/PR)**, **Game QA Expert Agent** bắt buộc tuân thủ cấu trúc dưới đây để hình ảnh bằng chứng luôn được upload lên nhánh `qa-evidence` và hiển thị trực tiếp (`![...](https://...?raw=true)`) trong mô tả Issue lẫn MR/PR.

---

## 1. Cấu Trúc Tiêu Đề Issue (Issue Title)
```text
[QA][<Category>] <Mô tả ngắn gọn, chính xác hiện tượng và vị trí xảy ra>
```
- **Ví dụ**:
  - `[QA][Bug] Mở bảng Kỹ Năng Võ Công giữa trận không đóng lại được khi nhấn phím tắt G lần hai`
  - `[QA][UI-UX] Chữ mô tả thuộc tính trang bị tràn khỏi khung trong ItemDetailPopup ở độ phân giải 1280x720`
  - `[QA][Incomplete] Màn Tạo Nhân Vật (CharacterCreate) chỉ gán cố định 5/10 môn phái`
  - `[QA][Performance] Rò rỉ Orphan Nodes khi đóng/mở lặp lại cửa sổ CharacterStatusWindow trong trận`

---

## 2. Cấu Trúc Nội Dung Issue (Issue Markdown Body Template)

```markdown
## 1. Tổng Quan (Summary)
- **Phân loại (Category)**: `Bug` | `Incomplete Feature` | `UI/UX` | `Combat & Skill` | `Performance`
- **Mức độ nghiêm trọng (Severity)**: `Critical` | `High` | `Medium` | `Low`
- **Scene / Khu vực bị ảnh hưởng**: `res://...` (kèm đường dẫn Node trong Scene Tree nếu có)
- **File mã nguồn liên quan**: `path/to/script.gd` (dòng `Lxx-Lyy`)

## 2. Các Bước Tái Hiện (Steps to Reproduce)
1. Khởi chạy scene `...` thông qua Godot Runtime (`godot-peek`).
2. Thực hiện thao tác / gọi biểu thức GDScript:
   ```gdscript
   # Biểu thức hoặc thao tác tái hiện lỗi
   ```
3. Quan sát kết quả trên màn hình / trong Debugger.

## 3. Kết Quả Thực Tế vs. Kỳ Vọng (Actual vs. Expected)
- **Thực tế (Actual Behavior)**:
  - Mô tả rõ hiện tượng lỗi đang xảy ra.
- **Kỳ vọng (Expected Behavior)**:
  - Mô tả hành vi đúng theo thiết kế (hoặc dẫn chiếu tài liệu `docs/vltk_*.md`).

## 4. Bằng Chứng Kiểm Thử (Evidence)
- **Ảnh chụp màn hình (Screenshot Evidence)**:
  - File lưu trong repo: `docs/qa_reports/evidence/<YYYY-MM-DD>_<issue-slug>/<filename>.png`
  - Hình ảnh hiển thị trực tiếp (được tự động đính kèm bởi `./scripts/qa-issue.sh create --evidence-dir ...` hoặc `./scripts/qa-issue.sh attach-issue`):
    ![<filename>](https://github.com/dacvuips/kiem-hiep/blob/qa-evidence/docs/qa_reports/evidence/<YYYY-MM-DD>_<issue-slug>/<filename>.png?raw=true)
- **Log Output / Debugger Errors**:
  ```text
  <Dán trực tiếp nội dung lỗi từ get_debugger_errors / get_output hoặc giá trị thuộc tính từ get_remote_node_properties>
  ```
- **Thông số Runtime / Hiệu năng (`get_monitors` / `evaluate_expression`)**:
  - FPS: `...` | Node Count: `...` | Orphan Nodes: `...`

## 5. Phân Tích Nguyên Nhân & Đề Xuất Hướng Xử Lý (Root Cause & Suggested Fix)
- **Nguyên nhân gốc rễ (Root Cause)**: Chỉ rõ hàm/dòng lệnh trong file `.gd` hoặc cấu hình node trong `.tscn` dẫn tới vấn đề.
- **Đề xuất sửa (Suggested Fix)**: Gợi ý cách khắc phục cụ thể để Developer hoặc Coding Agent có thể xử lý ngay.
```

---

## 3. Cấu Trúc Mô Tả Merge Request / Pull Request Kèm Hình Ảnh (MR / PR Description Template)

Khi tạo mới hoặc cập nhật một **Merge Request / Pull Request (MR/PR)**, sử dụng lệnh `./scripts/qa-issue.sh create-mr --evidence-dir ...` hoặc `./scripts/qa-issue.sh attach-mr <mr-number> <evidence-dir>` với cấu trúc mô tả chuẩn sau:

```markdown
## 1. Tóm Tắt Thay Đổi (Summary of Changes)
- Giải quyết Issue: Closes #<issue-number>
- Các thay đổi chính:
  - `<file_1.gd>`: Mô tả ngắn gọn thay đổi logic / sửa lỗi.
  - `<file_2.tscn>`: Mô tả ngắn gọn chỉnh sửa giao diện / bố cục.

## 2. Kết Quả Kiểm Thử Thực Tế Trên Godot Runtime (QA Verification)
- [x] Khởi chạy và kiểm thử trực tiếp qua `godot-peek` Runtime.
- [x] Không phát sinh lỗi mới trong `get_debugger_errors` / `get_output`.
- [x] Chỉ số `Orphan Nodes` ổn định, FPS đạt chuẩn.

## 3. Hình Ảnh Bằng Chứng Trước & Sau Khi Sửa (Before / After Screenshots)
| Trước khi sửa (Before) | Sau khi sửa (After) |
| :---: | :---: |
| ![Before](https://github.com/dacvuips/kiem-hiep/blob/qa-evidence/docs/qa_reports/evidence/<YYYY-MM-DD>_<slug>/<before>.png?raw=true) | ![After](https://github.com/dacvuips/kiem-hiep/blob/qa-evidence/docs/qa_reports/evidence/<YYYY-MM-DD>_<slug>/<after>.png?raw=true) |
```
