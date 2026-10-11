# Mẫu Chuẩn Báo Cáo GitHub Issue & Bằng Chứng Kiểm Thử (QA Issue Standard Template)

Mỗi khi phát hiện lỗi (Bug), bất cập giao diện (UI/UX), sai lệch công thức/môn phái (Combat/Skill) hoặc tính năng chưa hoàn thiện (Incomplete Feature), **Game QA Expert Agent** bắt buộc tạo file nội dung theo đúng cấu trúc dưới đây trước khi gọi `./scripts/qa-issue.sh create`.

---

## Cấu Trúc Tiêu Đề (Issue Title)
```text
[QA][<Category>] <Mô tả ngắn gọn, chính xác hiện tượng và vị trí xảy ra>
```
- **Ví dụ**:
  - `[QA][Bug] Mở bảng Kỹ Năng Võ Công giữa trận không đóng lại được khi nhấn phím tắt G lần hai`
  - `[QA][UI-UX] Chữ mô tả thuộc tính trang bị tràn khỏi khung trong ItemDetailPopup ở độ phân giải 1280x720`
  - `[QA][Incomplete] 6 mục điều hướng tại Sảnh Chính (CharacterHub) mới chỉ hiện thông báo "đang phát triển"`
  - `[QA][Performance] Rò rỉ Orphan Nodes khi đóng/mở lặp lại cửa sổ CharacterStatusWindow trong trận`

---

## Cấu Trúc Nội Dung Issue (Markdown Body Template)

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

