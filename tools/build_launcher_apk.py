"""Dựng APK Android = LAUNCHER MỎNG (không chứa code game). Xem launcher.gd và tools/launcher_settings.py.

Sinh project Godot riêng ở build/launcher_project/:
  - project.godot  = project.godot của game (bỏ mục chỉ cho editor), main scene = launcher, thêm settings_hash
  - autoload GIẢ   = mỗi đường dẫn autoload một file `extends <lớp gốc>` rỗng (engine tạo node + tên toàn cục lúc mở
                     app; launcher gắn script thật từ core sau khi nạp)
  - launcher.gd/.tscn, ảnh/font của màn tải, theme mặc định + font, default_bus_layout.tres, icon
  - export_presets.cfg = preset "Android Launcher" của game (giữ package, quyền, icon...), xuất hết project này
rồi xuất APK (ký bằng debug keystore trong cài đặt editor, giống các bản đã phát).

    GODOT=".../Godot_v4.7.2-stable_win64_console.exe" python tools/build_launcher_apk.py
    python tools/build_launcher_apk.py --release        # bản phát hành (cần keystore release trong export_credentials)
    python tools/build_launcher_apk.py --publish        # chép APK vào server/client/files/kiem-hiep.apk

Khi nào phải build + phát APK mới:
  - sửa launcher.gd theo cách core mới cần (tăng LAUNCHER_VERSION, phát manifest với --min-launcher)
  - đổi project.godot / autoload / theme / font theme / bus âm thanh: build_client_update.py ghi settings_hash mới vào
    manifest -> launcher cũ tự báo "cần cài bản mới". PHẢI phát APK này TRƯỚC khi phát core đó.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import launcher_settings as ls  # noqa: E402

ROOT = ls.ROOT
PROJ = ROOT / "build" / "launcher_project"
PRESET = "Android Launcher"
# File của màn tải (ngoài file khởi động trong launcher_settings.startup_files()).
LAUNCHER_FILES = ["launcher.gd", "launcher.tscn", "art/bg.jpg", "art/logo.png", "art/BeVietnamPro-Regular.ttf",
                  "art/BeVietnamPro-OFL.txt"]
SIDE_SUFFIXES = (".import", ".uid")


def copy_with_sidecars(rel: str) -> None:
    src = ROOT / rel
    if not src.is_file():
        sys.exit(f"Thiếu file {rel}")
    for path in [src] + [src.with_name(src.name + s) for s in SIDE_SUFFIXES]:
        if path.is_file():
            dst = PROJ / path.relative_to(ROOT)
            dst.parent.mkdir(parents=True, exist_ok=True)
            if not dst.exists() or dst.read_bytes() != path.read_bytes():
                shutil.copyfile(path, dst)


def write_text(rel: str, text: str) -> None:
    dst = PROJ / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists() or dst.read_text(encoding="utf-8") != text:
        dst.write_text(text, encoding="utf-8", newline="\n")


def project_godot(settings_hash: str) -> str:
    out: list[str] = []
    has_kh = False
    for name, body in ls.launcher_project_godot_body():
        if name:
            out.append(f"[{name}]")
        if name == "application":
            body = [ln for ln in body if not ln.startswith("run/main_scene")]
            body.insert(0, 'run/main_scene="res://launcher.tscn"')
        if name == "kiem_hiep":
            has_kh = True
            body = [ln for ln in body if not ln.startswith("launcher/")]
            body.insert(0, f'launcher/settings_hash="{settings_hash}"')
        out.extend(body)
    if not has_kh:
        out += ["[kiem_hiep]", "", f'launcher/settings_hash="{settings_hash}"', ""]
    return "\n".join(out).rstrip("\n") + "\n"


def export_presets() -> str:
    """Preset "Android Launcher" của game, đổi thành preset 0 xuất toàn bộ project launcher."""
    text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8").replace("\r\n", "\n")
    blocks = re.split(r"(?m)^(?=\[preset\.\d+(?:\.options)?\]\s*$)", text)
    idx = None
    for b in blocks:
        m = re.match(r"\[preset\.(\d+)\]", b)
        if m and re.search(r'(?m)^name="' + re.escape(PRESET) + '"', b):
            idx = m.group(1)
    if idx is None:
        sys.exit(f"Không thấy preset '{PRESET}' trong export_presets.cfg")
    main = next(b for b in blocks if b.startswith(f"[preset.{idx}]"))
    opts = next(b for b in blocks if b.startswith(f"[preset.{idx}.options]"))
    main = main.replace(f"[preset.{idx}]", "[preset.0]", 1)
    opts = opts.replace(f"[preset.{idx}.options]", "[preset.0.options]", 1)
    main = re.sub(r'(?m)^export_filter=.*$', 'export_filter="all_resources"', main)
    main = re.sub(r'(?m)^include_filter=.*$', 'include_filter=""', main)
    main = re.sub(r'(?m)^exclude_filter=.*$', 'exclude_filter="*.txt"', main)
    main = re.sub(r'(?m)^export_path=.*$', 'export_path=""', main)
    return main.rstrip("\n") + "\n\n" + opts.rstrip("\n") + "\n"


def run_godot(godot: str, args: list[str], what: str) -> None:
    print(f"  {what} ...", flush=True)
    r = subprocess.run([godot, "--headless", "--path", str(PROJ), *args], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    errs = [ln for ln in (r.stdout + r.stderr).splitlines() if "ERROR" in ln or "SCRIPT ERROR" in ln]
    for ln in errs[:20]:
        print("    " + ln)
    if r.returncode != 0:
        sys.exit(f"{what} thất bại (mã {r.returncode})")


def main() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--out", type=Path, default=ROOT / "build" / "kiem-hiep-launcher.apk")
    ap.add_argument("--release", action="store_true", help="xuất bản release (mặc định debug, ký debug keystore)")
    ap.add_argument("--publish", action="store_true", help="chép APK vào server/client/files/kiem-hiep.apk")
    args = ap.parse_args()

    sh = ls.settings_hash()
    print(f"settings_hash = {sh}")
    PROJ.mkdir(parents=True, exist_ok=True)
    # Xoá file cũ không còn dùng (giữ .godot để import nhanh).
    keep = {".godot"}
    for child in PROJ.iterdir():
        if child.name not in keep:
            shutil.rmtree(child) if child.is_dir() else child.unlink()

    write_text("project.godot", project_godot(sh))
    write_text("export_presets.cfg", export_presets())
    for name, res in ls.autoloads():
        write_text(res.removeprefix("res://"),
                   f"extends {ls.script_base(res)}\n## Autoload GIẢ của APK launcher mỏng ({name}) — launcher.gd gắn "
                   f"script thật từ gói core.\n")
    preset_files = [f.removeprefix("res://") for f in re.findall(r'"(res://[^"]+)"', export_presets())]
    for rel in sorted(set(LAUNCHER_FILES + ls.startup_files() + preset_files)):
        copy_with_sidecars(rel)

    godot = args.godot
    run_godot(godot, ["--import"], "import tài nguyên")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    if args.out.exists():
        args.out.unlink()
    run_godot(godot, ["--export-release" if args.release else "--export-debug", PRESET, str(args.out.resolve())],
              "xuất APK")
    if not args.out.is_file():
        sys.exit("Không thấy APK sau khi xuất")
    print(f"APK: {args.out} ({args.out.stat().st_size / 1048576:.1f} MB)")
    if args.publish:
        dst = ROOT / "server" / "client" / "files" / "kiem-hiep.apk"
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.out, dst)
        print(f"Đã chép -> {dst}  (link: <account_url>/client/files/kiem-hiep.apk)")


if __name__ == "__main__":
    main()
