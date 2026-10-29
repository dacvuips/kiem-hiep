"""Đóng gói bản cập nhật game cho APK launcher (xem launcher/README.md).

Xuất các gói .pck (preset "Client Core" / "Client Pack <tên>" trong export_presets.cfg) vào server/client/files/
và ghi server/client/manifest.json — account server phục vụ tại /v1/client/manifest và /client/files/.

Chỉ xuất lại gói có nội dung nguồn thay đổi (so dấu vân tay với manifest cũ), nên sửa code chỉ làm người chơi
tải lại gói core (~100 MB), không phải toàn bộ ~1 GB. Gói tài nguyên đổi -> core cũng xuất lại (uid_cache nằm trong core).

    GODOT="/duong/dan/Godot_console.exe" python tools/build_client_update.py
    python tools/build_client_update.py --dry-run          # chỉ in gói nào sẽ xuất lại
    python tools/build_client_update.py --force core       # ép xuất lại gói
    python tools/build_client_update.py --min-launcher 2 --apk-url https://kiemhiep.vn/kiem-hiep.apk
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "server" / "client"

# (tên gói, preset, thư mục nguồn). Gói đầu là core = main pack; thứ tự còn lại = thứ tự ContentPacks nạp.
PACKS: list[tuple[str, str, list[str]]] = [
    ("core", "Client Core", []),
    ("avatar", "Client Pack avatar", ["assets/avatar"]),
    ("monster", "Client Pack monster", ["assets/monster"]),
    ("skill_fx", "Client Pack skill_fx", ["assets/skill_fx"]),
    ("maps", "Client Pack maps", ["world/maps", "world/minimap"]),
    ("audio", "Client Pack audio", ["audio"]),
    ("items", "Client Pack items", ["assets/items"]),
]
# Không thuộc gói nào (khớp exclude_filter của preset "Client Core").
NOT_SHIPPED = {".git", ".godot", "android", "launcher", "server", "tools", "tests", "docs", "build",
               "placeholder_do_not_ship"}
IGNORED_SUFFIXES = (".tmp", ".stackdump")


# Băm lại 1 GB nguồn mỗi lần mất vài phút -> nhớ sha theo (kích thước, mtime) ở build/client_hash_cache.json.
HASH_CACHE_PATH = ROOT / "build" / "client_hash_cache.json"
_hash_cache: dict[str, list] = {}


def cached_sha256(path: Path) -> str:
    st = path.stat()
    key = path.relative_to(ROOT).as_posix()
    hit = _hash_cache.get(key)
    if hit and hit[0] == st.st_size and hit[1] == st.st_mtime_ns:
        return hit[2]
    sha = file_sha256(path)
    _hash_cache[key] = [st.st_size, st.st_mtime_ns, sha]
    return sha


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def walk(base: Path, skip_dirs: set[Path]) -> list[Path]:
    out: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(base):
        d = Path(dirpath)
        dirnames[:] = sorted(n for n in dirnames if d / n not in skip_dirs and not n.startswith("."))
        # Thư mục có project.godot riêng (launcher/...) — editor game cũng bỏ qua.
        if d != ROOT and (d / "project.godot").exists():
            dirnames[:] = []
            continue
        for n in sorted(filenames):
            if not n.endswith(IGNORED_SUFFIXES):
                out.append(d / n)
    return out


def fingerprint(name: str, preset: str, folders: list[str], engine: str, preset_text: str) -> str:
    h = hashlib.sha256()
    h.update(f"{engine}\n{preset_text}\n".encode())
    if folders:
        files = [f for folder in folders for f in walk(ROOT / folder, set())]
    else:
        skip = {ROOT / n for n in NOT_SHIPPED}
        for _, _, fs in PACKS[1:]:
            skip |= {ROOT / f for f in fs}
        files = walk(ROOT, skip)
    for f in files:
        rel = f.relative_to(ROOT).as_posix()
        h.update(f"{rel}\0{cached_sha256(f)}\n".encode())
    print(f"  {name}: {len(files)} file nguồn")
    return h.hexdigest()


def preset_sections() -> dict[str, str]:
    """Tên preset -> nội dung cấu hình (đổi filter cũng tính là gói thay đổi)."""
    text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    out: dict[str, str] = {}
    for block in re.split(r"(?m)^(?=\[preset\.\d+\]\s*$)", text):
        m = re.search(r'(?m)^name="([^"]*)"', block)
        if m:
            out[m.group(1)] = block
    return out


def godot_version(godot: str) -> str:
    v = subprocess.run([godot, "--version"], capture_output=True, text=True, check=True).stdout.strip()
    m = re.match(r"(\d+)\.(\d+)(?:\.(\d+))?", v.splitlines()[-1])
    if not m:
        sys.exit(f"Không đọc được phiên bản Godot: {v!r}")
    return ".".join(x for x in m.groups() if x is not None)


def export_pack(godot: str, preset: str, dest: Path) -> None:
    print(f"  xuất '{preset}' ...", flush=True)
    r = subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-pack", preset, str(dest)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0 or not dest.exists() or dest.stat().st_size == 0:
        sys.stderr.write(r.stdout[-4000:] + r.stderr[-4000:])
        sys.exit(f"Xuất gói '{preset}' thất bại (mã {r.returncode})")


def main() -> None:
    for stream in (sys.stdout, sys.stderr):  # console Windows mặc định cp1252, không in được tiếng Việt
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--out", type=Path, default=OUT)
    ap.add_argument("--force", default="", help="tên gói ép xuất lại, cách nhau dấu phẩy (all = tất cả)")
    ap.add_argument("--only", default="", help="chỉ tính và xuất các gói này (ví dụ: core), các gói khác giữ nguyên từ manifest cũ")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--min-launcher", type=int, help="LAUNCHER_VERSION tối thiểu (launcher cũ hơn -> báo tải APK mới)")
    ap.add_argument("--apk-url", help="link tải APK mới, hiện khi launcher quá cũ")
    ap.add_argument("--files-base", help="để gói trên CDN: https://cdn.../client/ (mặc định server tài khoản)")
    args = ap.parse_args()

    out: Path = args.out
    files_dir = out / "files"
    manifest_path = out / "manifest.json"
    old = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    old_packs = {p["name"]: p for p in old.get("packs", [])}
    force = {s.strip() for s in args.force.split(",") if s.strip()}
    only = {s.strip() for s in args.only.split(",") if s.strip()}

    for proj in (ROOT / "project.godot", ROOT / "launcher" / "project.godot"):
        m = re.search(r'(?m)^network/account_url="([^"]*)"', proj.read_text(encoding="utf-8"))
        url = m.group(1) if m else ""
        if not url.startswith("https://"):
            print(f"CẢNH BÁO: {proj.relative_to(ROOT)} account_url = '{url}' — bản phát hành phải là https://<tên miền>")
    if HASH_CACHE_PATH.exists():
        _hash_cache.update(json.loads(HASH_CACHE_PATH.read_text(encoding="utf-8")))
    engine = godot_version(args.godot)
    presets = preset_sections()
    print(f"Godot {engine} — tính dấu vân tay nguồn:")
    plan: list[tuple[str, str, str, bool]] = []
    for name, preset, folders in PACKS:
        if preset not in presets:
            sys.exit(f"Thiếu preset '{preset}' trong export_presets.cfg")
        if only and name not in only and name in old_packs:
            plan.append((name, preset, old_packs[name].get("src", ""), False))
            continue
        src = fingerprint(name, preset, folders, engine, presets[preset])
        prev = old_packs.get(name)
        changed = ("all" in force or name in force or prev is None or prev.get("src") != src
                   or not (files_dir / prev.get("file", "")).is_file())
        plan.append((name, preset, src, changed))
    HASH_CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    HASH_CACHE_PATH.write_text(json.dumps(_hash_cache), encoding="utf-8")
    if any(c for n, _, _, c in plan if n != "core"):
        plan[0] = (*plan[0][:3], True)  # uid_cache của mọi tài nguyên nằm trong core

    for name, _, _, changed in plan:
        print(f"  {'XUẤT LẠI' if changed else 'giữ nguyên'}: {name}")
    if args.dry_run:
        return

    packs: list[dict] = []
    files_dir.mkdir(parents=True, exist_ok=True)
    tmp_dir = ROOT / "build" / "temp_packs"
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir, ignore_errors=True)
    tmp_dir.mkdir(parents=True, exist_ok=True)
    try:
        for name, preset, src, changed in plan:
            if not changed:
                packs.append(old_packs[name])
                continue
            dest = tmp_dir / f"{name}.pck"
            export_pack(args.godot, preset, dest)
            sha = file_sha256(dest)
            file = f"{name}-{sha[:12]}.pck"
            shutil.move(str(dest), files_dir / file)
            packs.append({"name": name, "file": file, "size": (files_dir / file).stat().st_size,
                          "sha256": sha, "src": src})
            print(f"    -> {file} ({packs[-1]['size'] / 1048576:.1f} MB)")
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

    changed_any = [p["file"] for p in packs] != [p["file"] for p in old.get("packs", [])]
    manifest = {
        "version": int(old.get("version", 0)) + (1 if changed_any else 0),
        "build": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                 if changed_any else old.get("build", ""),
        "engine": engine,
        "min_launcher": args.min_launcher if args.min_launcher is not None else int(old.get("min_launcher", 1)),
        "apk_url": args.apk_url if args.apk_url is not None else old.get("apk_url", ""),
        "files_base": args.files_base if args.files_base is not None else old.get("files_base", ""),
        "packs": packs,
    }
    tmp_manifest = manifest_path.with_suffix(".json.tmp")
    tmp_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp_manifest, manifest_path)

    # Giữ gói của bản trước cho người đang tải dở; xoá gói cũ hơn.
    keep = {p["file"] for p in packs} | {p["file"] for p in old.get("packs", [])}
    for f in files_dir.glob("*.pck"):
        if f.name not in keep:
            f.unlink()
    total = sum(p["size"] for p in packs) / 1048576
    print(f"Bản {manifest['version']}{'' if changed_any else ' (không có gì thay đổi)'} — {len(packs)} gói, "
          f"{total:.0f} MB -> {manifest_path}")


if __name__ == "__main__":
    main()
