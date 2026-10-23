#!/usr/bin/env python3
"""
tools/security/setup_encryption.py
Công cụ quản lý khóa mã hóa AES-256 và cấu hình chống dịch ngược PCK / GDScript cho Godot 4.
"""

import sys
import os
import re
import secrets
import argparse

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

KEY_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".encryption_key"))
PRESETS_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "export_presets.cfg"))

def get_or_create_key(force_new=False):
    if not force_new and os.path.exists(KEY_FILE):
        with open(KEY_FILE, "r", encoding="utf-8") as f:
            key = f.read().strip()
            if len(key) == 64 and all(c in "0123456789abcdefABCDEF" for c in key):
                return key
    key = secrets.token_hex(32)
    with open(KEY_FILE, "w", encoding="utf-8") as f:
        f.write(key + "\n")
    return key

def update_presets(enable=True):
    if not os.path.exists(PRESETS_FILE):
        print(f"[!] Không tìm thấy {PRESETS_FILE}")
        return False
    with open(PRESETS_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    target_encrypt = "true" if enable else "false"
    filters = '"*.gd,*.gdc,*.tscn,*.json"' if enable else '""'

    content = re.sub(r"encrypt_pck=(?:true|false)", f"encrypt_pck={target_encrypt}", content)
    content = re.sub(r"encrypt_directory=(?:true|false)", f"encrypt_directory={target_encrypt}", content)
    if enable:
        content = re.sub(r'encryption_include_filters=".*?"', f'encryption_include_filters={filters}', content)
    else:
        content = re.sub(r'encryption_include_filters=".*?"', 'encryption_include_filters=""', content)

    with open(PRESETS_FILE, "w", encoding="utf-8") as f:
        f.write(content)
    return True

def print_status():
    has_key = os.path.exists(KEY_FILE)
    key_val = ""
    if has_key:
        with open(KEY_FILE, "r", encoding="utf-8") as f:
            key_val = f.read().strip()

    is_enabled = False
    if os.path.exists(PRESETS_FILE):
        with open(PRESETS_FILE, "r", encoding="utf-8") as f:
            is_enabled = "encrypt_pck=true" in f.read()

    print("==================================================")
    print("      JX1 IDLE ORIGIN - ANTI-REVERSE SECURITY     ")
    print("==================================================")
    print(f"[*] Trạng thái Khóa AES-256: {'ĐÃ TẠO' if has_key else 'CHƯA TẠO'}")
    if has_key:
        print(f"[*] Khóa (64 hex digits)  : {key_val[:8]}...{key_val[-8:]} (Lưu tại .encryption_key)")
    print(f"[*] Mã hóa export_presets  : {'BẬT (ENCRYPTED)' if is_enabled else 'TẮT (PLAIN PCK)'}")
    print("==================================================")

def main():
    parser = argparse.ArgumentParser(description="Quản lý mã hóa PCK / Chống dịch ngược Godot 4")
    parser.add_argument("--generate", action="store_true", help="Tạo khóa AES-256 mới (ghi đè nếu có)")
    parser.add_argument("--enable", action="store_true", help="Bật mã hóa trong export_presets.cfg")
    parser.add_argument("--disable", action="store_true", help="Tắt mã hóa trong export_presets.cfg (dùng khi dev)")
    parser.add_argument("--show-commands", action="store_true", help="In lệnh build phát hành chống dịch ngược")

    args = parser.parse_args()

    if args.generate:
        k = get_or_create_key(force_new=True)
        print(f"[+] Đã tạo khóa mã hóa AES-256 mới: {k}")
        print(f"[+] Đã lưu bí mật vào {KEY_FILE}")
        return

    if args.enable:
        k = get_or_create_key()
        update_presets(enable=True)
        print(f"[+] Đã BẬT mã hóa PCK trong export_presets.cfg với bộ lọc: *.gd, *.gdc, *.tscn, *.json")
        print(f"[!] LƯU Ý: Khi export APK/PCK release, bạn PHẢI truyền biến môi trường:")
        print(f'    $env:SCRIPT_AES256_ENCRYPTION_KEY="{k}"')
        return

    if args.disable:
        update_presets(enable=False)
        print("[-] Đã TẮT mã hóa PCK trong export_presets.cfg (chế độ phát triển).")
        return

    print_status()
    k = get_or_create_key()

    print("\nHƯỚNG DẪN BUILD CHỐNG DỊCH NGƯỢC:")
    print("1. Kích hoạt mã hóa cấu hình export:")
    print("   python tools/security/setup_encryption.py --enable")
    print("\n2. Thiết lập biến môi trường khóa AES-256 trước khi build:")
    print(f'   PowerShell: $env:SCRIPT_AES256_ENCRYPTION_KEY="{k}"')
    print(f'   Bash/Linux: export SCRIPT_AES256_ENCRYPTION_KEY="{k}"')
    print("\n3. Xuất bản APK Android có mã hóa mã nguồn:")
    print("   godot --headless --export-release \"Android\" build/release.apk")
    print("==================================================")

if __name__ == "__main__":
    main()
