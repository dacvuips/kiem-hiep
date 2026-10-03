"""Remap ElementType cu (PHYSICAL=0/FIRE=1/ICE=2/LIGHTNING=3/POISON=4/CHAOS=5) sang enum
Ngu Hanh moi (KIM=0/MOC=1/THUY=2/HOA=3/THO=4) trong toan bo file .tres.

Chay dry-run truoc (mac dinh), doi --apply de ghi that.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# cu (int) -> moi (int), xem plan muc 1
MAPPING = {0: 4, 1: 3, 2: 2, 3: 0, 4: 1, 5: 3}

TARGETS = [
    (ROOT / "gem_system" / "data" / "attack", "base_element"),
    (ROOT / "gem_system" / "data" / "partners", "element"),
]


def process_dir(dir_path: Path, field_name: str, apply: bool) -> int:
    if not dir_path.exists():
        print(f"[SKIP] khong ton tai: {dir_path}")
        return 0
    pattern = re.compile(rf"^{re.escape(field_name)} = (\d+)$", re.MULTILINE)
    changed = 0
    for tres_path in sorted(dir_path.rglob("*.tres")):
        text = tres_path.read_text(encoding="utf-8")
        matches = list(pattern.finditer(text))
        if not matches:
            continue
        new_text = text
        offset = 0
        for m in matches:
            old_value = int(m.group(1))
            new_value = MAPPING.get(old_value, old_value)
            rel = tres_path.relative_to(ROOT)
            print(f"{rel}: {field_name} {old_value} -> {new_value}")
            if new_value != old_value:
                start, end = m.span(1)
                start += offset
                end += offset
                new_text = new_text[:start] + str(new_value) + new_text[end:]
                offset += len(str(new_value)) - len(m.group(1))
                changed += 1
        if apply and new_text != text:
            tres_path.write_text(new_text, encoding="utf-8")
    return changed


def main() -> None:
    apply = "--apply" in sys.argv
    total = 0
    for dir_path, field_name in TARGETS:
        total += process_dir(dir_path, field_name, apply)
    mode = "DA GHI" if apply else "DRY-RUN (chua ghi, dung --apply de ghi that)"
    print(f"\n[{mode}] Tong so gia tri se/da doi: {total}")


if __name__ == "__main__":
    main()
