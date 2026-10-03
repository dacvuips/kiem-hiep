"""Gắn ẢNH SKILL gốc VLTK cho skill các môn phái (systems/sect/data/*.tres).

    python tools/import_vltk_skill_icons.py [--dry]

- Skills.txt (server settings): cột SkillName (TCVN5712-1) + SkillIcon (đường dẫn .spr, thư mục tên chữ Hán nên đọc
  GBK, VD \\spr\\Ui\\技能图标\\icon_sk_sl_gf.spr — "技能图标" = biểu tượng kỹ năng).
- Skill game <-> dòng Skills.txt ghép theo TÊN như tools/import_vltk_hit_effects.py (bỏ phần "(...)" cuối tên).
  Trùng tên nhiều dòng: lấy dòng đầu tiên có ảnh đọc được.
- Ảnh đọc qua tools/vltk_pak.py, lấy frame đầu (36x36) -> assets/skill_icons/vltk/<id skill>.png.
- Ghi vào .tres: ext_resource Texture2D + dòng `icon = ExtResource(...)` cho từng skill (thay ảnh cũ nếu có).
"""
import os
import re
import subprocess
import sys
import difflib
import unicodedata
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
from vltk_pak import PakList  # noqa: E402
import spr_to_png  # noqa: E402

PROJECT = Path(__file__).resolve().parent.parent
SKILLS_TXT = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt")
CLIENT = r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK"
TRES_DIR = PROJECT / "systems" / "sect" / "data"
OUT_DIR = PROJECT / "assets" / "skill_icons" / "vltk"
RES_DIR = "res://assets/skill_icons/vltk/"


def norm(name: str) -> str:
    """Bỏ "(...)" cuối, "- tầng N"; "_" = " - "; gộp khoảng trắng; chữ thường NFC."""
    name = re.sub(r"\s*\([^)]*\)\s*$", "", name.strip())
    name = name.replace("_", " - ")
    name = re.sub(r"\s*-\s*tầng\s*\d+\s*$", "", name, flags=re.I)
    name = re.sub(r"\s+", " ", name)
    return unicodedata.normalize("NFC", name).lower().strip()


## Không trùng tên chính xác: nhận tên Skills.txt giống >= 88% (khác cách viết Diễm/Diệm, Phần/Phàn, Khí/Khi...).
FUZZY_CUTOFF = 0.88


def find_icons(icons: dict, name: str) -> list:
    key = norm(name)
    if key in icons:
        return icons[key]
    close = difflib.get_close_matches(key, list(icons), n=1, cutoff=FUZZY_CUTOFF)
    return icons[close[0]] if close else []


def load_icon_paths():
    """{tên chuẩn hoá: [đường dẫn ảnh, ...]} theo thứ tự dòng."""
    raw_lines = SKILLS_TXT.read_bytes().split(b"\n")
    text = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(SKILLS_TXT)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace").split("\n")
    header = raw_lines[0].rstrip(b"\r").split(b"\t")
    name_col, icon_col = header.index(b"SkillName"), header.index(b"SkillIcon")
    out = {}
    for raw, line in zip(raw_lines[1:], text[1:]):
        cells, raw_cells = line.split("\t"), raw.split(b"\t")
        if len(cells) <= name_col or len(raw_cells) <= icon_col:
            continue
        icon = raw_cells[icon_col].strip().decode("gbk", "replace")
        if icon:
            out.setdefault(norm(cells[name_col]), []).append(icon)
    return out


def main():
    dry = "--dry" in sys.argv
    icons = load_icon_paths()
    paks = PakList(CLIENT)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    tmp = OUT_DIR / "_tmp.spr"
    total = matched = 0
    missing = []
    for tres in sorted(TRES_DIR.glob("*.tres")):
        text = tres.read_text(encoding="utf-8")
        blocks = re.split(r"(?=\n\[sub_resource)", text)
        new_ext = []
        for bi, block in enumerate(blocks):
            id_m = re.search(r'^id = "([^"]*)"', block, re.M)
            name_m = re.search(r'^skill_name = "([^"]*)"', block, re.M)
            if not (id_m and name_m):
                continue
            total += 1
            skill_id = id_m.group(1)
            png = OUT_DIR / (skill_id + ".png")
            ok = png.is_file()
            for path in find_icons(icons, name_m.group(1)):
                if ok:
                    break
                data = paks.read(path)
                if data is None:
                    continue
                tmp.write_bytes(data)
                try:
                    images, _meta = spr_to_png.read_spr(str(tmp))
                except Exception:  ## noqa: BLE001 — file hỏng: thử dòng khác
                    continue
                if not dry:
                    images[0].save(png, optimize=True)
                ok = True
            if not ok:
                missing.append("%s: %s" % (tres.stem, name_m.group(1)))
                continue
            matched += 1
            ext_id = "vicon_" + skill_id
            new_ext.append('[ext_resource type="Texture2D" path="%s%s.png" id="%s"]' % (RES_DIR, skill_id, ext_id))
            block = re.sub(r"^icon = .*\n", "", block, flags=re.M)
            pos = name_m.end() + 1 if block[name_m.end():name_m.end() + 1] == "\n" else name_m.end()
            name_m = re.search(r'^skill_name = "([^"]*)"\n', block, re.M)
            block = block[:name_m.end()] + 'icon = ExtResource("%s")\n' % ext_id + block[name_m.end():]
            blocks[bi] = block
        text = "".join(blocks)
        ## Bỏ ext_resource ảnh vltk cũ rồi thêm bộ mới ngay sau ext_resource cuối; bỏ ảnh cũ không còn ai dùng.
        text = re.sub(r'^\[ext_resource type="Texture2D" path="res://assets/skill_icons/vltk/[^\n]*\n', "", text,
                      flags=re.M)
        last = list(re.finditer(r"^\[ext_resource[^\n]*\n", text, re.M))
        insert_at = last[-1].end() if last else text.index("\n\n") + 1
        text = text[:insert_at] + "".join(e + "\n" for e in new_ext) + text[insert_at:]
        for m in list(re.finditer(r'^\[ext_resource type="Texture2D"[^\n]*id="([^"]+)"\]\n', text, re.M)):
            if 'ExtResource("%s")' % m.group(1) not in text:
                text = text.replace(m.group(0), "")
        if not dry:
            tres.write_text(text, encoding="utf-8", newline="\n")
    if tmp.exists():
        tmp.unlink()
    print("Gắn ảnh: %d / %d skill" % (matched, total))
    for m in missing:
        print("  KHÔNG CÓ ẢNH:", m)


if __name__ == "__main__":
    main()
