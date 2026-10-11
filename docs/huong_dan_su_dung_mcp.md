# Hướng Dẫn Cài Đặt & Sử Dụng Godot Peek MCP

Tài liệu này hướng dẫn các thành viên trong team cách thiết lập và sử dụng **Godot Peek MCP** (kết nối AI trực tiếp vào Godot Editor Runtime để chạy thử scene, đọc log Output, kiểm tra lỗi Debugger, xem Remote Scene Tree, chụp ảnh màn hình game và thực thi GDScript trực tiếp).

---

## 1. Cài Đặt Nhanh (Chỉ 1 Bước Sau Khi Clone Repo)

Toàn bộ plugin Godot và các file thực thi (`.exe` cho Windows, binary cho macOS Intel/Apple Silicon và Linux) đã được đóng gói sẵn trong repo. **Bạn không cần cài đặt Go, Python hay trình biên dịch C++.**

### Dành cho máy Windows
1. Mở thư mục dự án, vào thư mục `scripts\` và nhấn đúp chuột chạy file:
   ```bat
   scripts\setup-mcp.bat
   ```
   *(Hoặc chạy trong PowerShell: `powershell -ExecutionPolicy Bypass -File .\scripts\setup-mcp.ps1`)*
2. Script sẽ tự động:
   - Gỡ khóa SmartScreen cho file `tools\godot-peek-mcp\bin\godot-peek-mcp-windows-amd64.exe`.
   - Cấu hình đường dẫn MCP tự động cho **Cursor** (`.cursor\mcp.json`), **Claude Code** (`.mcp.json`), **Antigravity** (`%USERPROFILE%\.gemini\config\mcp_config.json`) và **Claude Desktop** (`%APPDATA%\Claude\claude_desktop_config.json`).

### Dành cho máy macOS (Chip M1/M2/M3/M4 & Intel) hoặc Linux
1. Mở Terminal tại thư mục gốc của dự án và chạy:
   ```bash
   ./scripts/setup-mcp.sh
   ```
2. Script sẽ tự động:
   - Gỡ cờ bảo mật Gatekeeper (`xattr -cr`) trên macOS.
   - Nhận diện đúng kiến trúc CPU (`arm64` hoặc `x86_64`) và cập nhật cấu hình MCP cho **Cursor**, **Claude Code**, **Antigravity** và **Claude Desktop**.

---

## 2. Cách Khởi Động & Kiểm Tra Kết Nối

1. **Mở dự án trong Godot Editor (4.4+)**:
   - Plugin `Godot Peek MCP` và Autoload `PeekRuntimeHelper` đã được bật sẵn trong `project.godot`.
   - Kiểm tra khung **Output** ở dưới cùng của Godot Editor:
     - **Trên macOS / Linux**: Sẽ thấy dòng `GodotPeekPlugin: listening on /tmp/godot-peek-kiem-hiep.sock`
     - **Trên Windows**: Sẽ thấy dòng `GodotPeekPlugin (GDScript TCP): listening on 127.0.0.1:6970`

2. **Làm mới kết nối trên công cụ AI**:
   - **Antigravity**: Vào menu **Additional Options (...) > MCP Servers** > nhấn Refresh (hoặc mở lại cửa sổ).
   - **Cursor**: Vào **Cursor Settings > MCP** > nhấn Refresh bên cạnh `godot-peek`.
   - **Claude Code**: Gõ lệnh `/mcp` trong khung chat CLI để kiểm tra trạng thái `Connected`.

> **Lưu ý quan trọng**: Godot Editor cần được mở trước khi gọi các công cụ MCP để MCP Server có thể kết nối vào phiên Editor đang hoạt động.

---

## 3. Danh Sách 20 Công Cụ MCP & Khả Năng Hỗ Trợ

### 3.1. Điều khiển chạy / dừng Scene & Ghi đè biến (Scene Control)
| Công cụ | Chức năng | Tham số chính |
|---|---|---|
| `run_main_scene` | Chạy Main Scene của game (tương đương `F5`) | `timeout_seconds`, `overrides` (tùy chọn) |
| `run_current_scene` | Chạy Scene đang mở hiện tại trong Editor (`F6`) | `timeout_seconds`, `overrides` (tùy chọn) |
| `run_scene` | Chạy một Scene bất kỳ theo đường dẫn `res://...` | `scene_path`, `timeout_seconds`, `overrides` |
| `stop_scene` | Dừng game đang chạy | Không có |
| `restart_scene` | Khởi động lại Scene với cùng cấu hình lần chạy trước | Không có |

- **`timeout_seconds`**: Tự động dừng game sau `N` giây (rất hữu ích khi nhờ AI tự chạy kiểm thử).
- **`overrides`**: Ghi đè giá trị biến của các Autoload (`PlayerStats`, `GameManager`...) ngay lúc khởi chạy mà không cần sửa code. Ví dụ:
  ```json
  {"PlayerStats": {"gold": 99999}}
  ```

### 3.2. Đọc Log, Bắt Lỗi & Theo Dõi Hiệu Năng (Output & Debugging)
| Công cụ | Chức năng | Tham số chính |
|---|---|---|
| `get_output` | Đọc nội dung khung Output (`print`, `push_error`, `push_warning`) | `clear`, `new_only` |
| `get_debugger_errors` | Lấy toàn bộ danh sách lỗi & cảnh báo trong tab **Debugger > Errors** | Không có |
| `get_monitors` | Xem chỉ số hiệu năng thời gian thực (FPS, RAM, Draw Calls, Physics, Nodes...) | Không có |
| `get_profiler_frame` | Đọc cây gọi hàm (Call Tree) trong Profiler ở một frame cụ thể | `frame_number` |

### 3.3. Kiểm Tra & Can Thiệp Trực Tiếp Khi Game Đang Chạy (Runtime Inspection)
| Công cụ | Chức năng | Tham số chính |
|---|---|---|
| `get_remote_scene_tree` | Lấy cây Node thực tế đang tồn tại trong lúc game chạy (Remote Scene Tree) | `max_depth` |
| `get_remote_node_properties` | Đọc toàn bộ thuộc tính Inspector của một Node đang chạy | `node_path` (VD: `/root/Main/Player`) |
| `evaluate_expression` | Thực thi trực tiếp code GDScript ngay trong game đang chạy | `expression` |

### 3.4. Chụp Ảnh Màn Hình (Screenshots)
| Công cụ | Chức năng | Tham số chính |
|---|---|---|
| `get_screenshot` | Chụp ảnh màn hình khung nhìn Editor hoặc cửa sổ Game đang chạy | `target`: `"editor"` hoặc `"game"` |

### 3.5. Điều Khiển Breakpoint & Step Debugging
| Công cụ | Chức năng | Tham số chính |
|---|---|---|
| `set_breakpoint` | Đặt hoặc gỡ breakpoint tại dòng code cụ thể | `path`, `line`, `enabled` |
| `clear_breakpoints` | Xóa toàn bộ các breakpoint đang đặt | Không có |
| `get_debugger_state` | Kiểm tra trạng thái game (đang chạy hay đang dừng ở lỗi/breakpoint) | Không có |
| `get_debugger_stack_trace` | Lấy Stack Trace khi game đang tạm dừng ở lỗi/breakpoint | Không có |
| `get_debugger_locals` | Xem giá trị các biến cục bộ (Local Variables) khi đang dừng ở breakpoint | `frame_index` |
| `debug_break` | Tạm dừng thực thi game | Không có |
| `debug_continue` | Tiếp tục chạy game sau khi dừng ở breakpoint | Không có |
| `debug_step` | Bước qua từng dòng code khi đang dừng ở breakpoint | `mode`: `"into"`, `"over"`, `"out"` |

---

## 4. Ví Dụ Các Câu Lệnh Giao Việc Cho AI

Bạn có thể yêu cầu AI bằng ngôn ngữ tự nhiên:
- **Kiểm tra lỗi nhanh**:
  > *"Chạy thử game 10 giây, chụp màn hình game và kiểm tra xem có lỗi hay cảnh báo nào trong Debugger không."*
- **Kiểm tra kỹ năng / hiệu ứng**:
  > *"Chạy scene hiện tại, xem cây Remote Scene Tree để kiểm tra các node đạn/kỹ năng Đường Môn được sinh ra như thế nào."*
- **Test dữ liệu trực tiếp khi game đang chạy**:
  > *"Trong lúc game đang chạy, dùng `evaluate_expression` kiểm tra chỉ số máu và kháng của nhân vật hiện tại."*
- **Tối ưu hiệu năng**:
  > *"Chạy game và đọc `get_monitors` xem FPS, số lượng Node và bộ nhớ RAM đang tiêu thụ bao nhiêu."*

---

## 5. Cấu Trúc Thư Mục Liên Quan Trong Repo

```text
kiem-hiep/
├── addons/godot_mcp/
│   ├── bin/                                    # Thư viện C++ GDExtension cho macOS/Linux
│   ├── godot_peek.gdextension                  # Cấu hình GDExtension
│   ├── plugin.cfg & plugin.gd                  # Khởi tạo plugin & tự động kích hoạt chế độ Windows
│   ├── peek_editor_server.gd                   # Máy chủ TCP JSON-RPC thuần GDScript (dùng cho Windows)
│   ├── peek_debugger_plugin.gd                 # Điều khiển Debugger thuần GDScript (dùng cho Windows)
│   └── peek_runtime_helper.gd                  # Autoload chụp màn hình game, override biến & evaluate_expression
├── tools/godot-peek-mcp/bin/
│   ├── godot-peek-mcp-windows-amd64.exe        # Binary MCP Server cho Windows (x64)
│   ├── godot-peek-mcp-darwin-amd64             # Binary MCP Server cho macOS Intel
│   ├── godot-peek-mcp-darwin-arm64             # Binary MCP Server cho macOS Apple Silicon (M1/M2/M3/M4)
│   └── godot-peek-mcp-linux-amd64              # Binary MCP Server cho Linux (x64)
└── scripts/
    ├── setup-mcp.bat & setup-mcp.ps1           # Script cài đặt tự động trên Windows
    └── setup-mcp.sh                            # Script cài đặt tự động trên macOS / Linux
```

---

## 6. Lưu Ý Khi Export Game (Build Bản Phát Hành)

Plugin MCP chỉ dành cho môi trường phát triển trong Editor. Khi xuất bản game (**Project > Export**), tại tab **Resources > Filters to exclude files/folders from project**, hãy thêm bộ lọc loại trừ:

```text
addons/godot_mcp/bin/*, addons/godot_mcp/godot_peek.gdextension, addons/godot_mcp/plugin.*, addons/godot_mcp/peek_editor_server.gd, addons/godot_mcp/peek_debugger_plugin.gd
```
*(File `peek_runtime_helper.gd` được giữ lại vì đăng ký trong Autoload, nhưng trong code đã có sẵn lệnh kiểm tra `if not OS.has_feature("editor"): return` nên sẽ tự động bỏ qua khi chạy bản build thực tế).*

