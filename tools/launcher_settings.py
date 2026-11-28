"""Dùng chung cho tools/build_launcher_apk.py và tools/build_client_update.py.

APK Android là LAUNCHER MỎNG: chỉ có màn tải + autoload GIẢ (chỉ `extends Node`), không có code game. Lý do: Godot nạp gói
lúc đang chạy (load_resource_pack) KHÔNG thay được script đã biên dịch, và template Android chính thức không cho
`--main-pack` gói nằm ngoài APK. Nếu APK chứa code game thì mỗi lần core đổi script, code cũ trong APK kẹt lại -> văng.

Nhưng một số thứ engine CHỈ đọc từ APK lúc mở app, core không thay được:
  - project.godot (màn hình, render, input map, danh sách + thứ tự autoload...)
  - lớp gốc (extends) của từng autoload — autoload giả phải cùng lớp
  - theme mặc định (gui/theme/custom) + font của nó, default_bus_layout.tres, icon, ảnh splash
=> gộp lại thành `settings_hash`. APK ghi vào ProjectSettings, manifest ghi bản của core. Khác nhau -> launcher báo tải
APK mới. Nhờ vậy sửa code chỉ cần phát core; sửa những thứ trên thì quy trình bắt buộc phát APK trước.
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Mục project.godot không ảnh hưởng game lúc chạy (chỉ editor) -> bỏ khỏi hash và khỏi project launcher.
EDITOR_ONLY_SECTIONS = {"editor", "editor_plugins"}
# Autoload có script không đóng vào core (exclude_filter của preset "Client Core") -> launcher không khai báo.
EXCLUDED_AUTOLOAD_PREFIXES = ("res://addons/godot_mcp/",)
# File engine nạp lúc khởi động (ngoài theme + phụ thuộc, tìm tự động).
STARTUP_FILES = ["default_bus_layout.tres", "icon.png", "art/logo.png"]


def _res_to_path(res: str) -> Path:
    return ROOT / res.removeprefix("res://")


def read_project_lines() -> list[str]:
    return (ROOT / "project.godot").read_text(encoding="utf-8").replace("\r\n", "\n").split("\n")


def split_sections(lines: list[str]) -> list[tuple[str, list[str]]]:
    """[(tên mục, các dòng)], mục đầu tên "" (phần trước [application])."""
    out: list[tuple[str, list[str]]] = [("", [])]
    for ln in lines:
        m = re.match(r"^\[([^\]]+)\]\s*$", ln)
        if m:
            out.append((m.group(1), []))
        else:
            out[-1][1].append(ln)
    return out


def autoloads() -> list[tuple[str, str]]:
    """[(tên, res://đường dẫn script)] theo thứ tự project.godot, đã bỏ autoload không đóng gói."""
    result: list[tuple[str, str]] = []
    for name, body in split_sections(read_project_lines()):
        if name != "autoload":
            continue
        for ln in body:
            m = re.match(r'^(\w+)="\*?(res://[^"]+)"', ln)
            if m and not m.group(2).startswith(EXCLUDED_AUTOLOAD_PREFIXES):
                result.append((m.group(1), m.group(2)))
    return result


def script_base(res: str) -> str:
    """Lớp gốc của script autoload (dòng `extends` đầu tiên). Chỉ chấp nhận lớp có sẵn của engine."""
    for ln in _res_to_path(res).read_text(encoding="utf-8").splitlines():
        m = re.match(r"^extends\s+(\w+)\s*$", ln.strip())
        if m:
            return m.group(1)
        if ln.strip().startswith("extends"):
            raise SystemExit(f"Autoload {res}: '{ln.strip()}' — launcher mỏng cần extends một lớp engine (Node, CanvasLayer...)")
    return "RefCounted"


def theme_files() -> list[str]:
    """Theme mặc định + file nó tham chiếu (font...), dạng đường dẫn tương đối gốc repo."""
    text = "\n".join(read_project_lines())
    m = re.search(r'(?m)^theme/custom="(res://[^"]+)"', text)
    if not m:
        return []
    theme = m.group(1)
    files = [theme.removeprefix("res://")]
    for dep in re.findall(r'path="(res://[^"]+)"', _res_to_path(theme).read_text(encoding="utf-8")):
        files.append(dep.removeprefix("res://"))
    return files


def startup_files() -> list[str]:
    files = [f for f in STARTUP_FILES if (ROOT / f).is_file()] + theme_files()
    return sorted(set(files))


def launcher_project_godot_body() -> list[tuple[str, list[str]]]:
    """Các mục project.godot dùng cho APK: bỏ mục chỉ dành cho editor và autoload không đóng gói."""
    out: list[tuple[str, list[str]]] = []
    for name, body in split_sections(read_project_lines()):
        if name in EDITOR_ONLY_SECTIONS:
            continue
        if name == "autoload":
            body = [ln for ln in body if not re.search(r'"\*?' + "|".join(re.escape(p) for p in EXCLUDED_AUTOLOAD_PREFIXES), ln)]
        out.append((name, body))
    return out


def settings_hash() -> str:
    h = hashlib.sha256()
    for name, body in launcher_project_godot_body():
        h.update(f"[{name}]\n".encode())
        for ln in body:
            if ln.strip():
                h.update((ln.rstrip() + "\n").encode())
    for name, res in autoloads():
        h.update(f"autoload {name} {res} extends {script_base(res)}\n".encode())
    for rel in startup_files():
        h.update(f"file {rel} ".encode() + hashlib.sha256((ROOT / rel).read_bytes()).hexdigest().encode() + b"\n")
    return h.hexdigest()[:16]


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print(settings_hash())
    for n, r in autoloads():
        print(f"  {n:22s} {r}  extends {script_base(r)}")
    print("  khởi động:", ", ".join(startup_files()))
