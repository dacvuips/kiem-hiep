"""Nhập dữ liệu TRANG BỊ VLTK gốc -> data/items/*.json (đọc bởi ItemDatabase).

    python tools/import_vltk_items.py

Nguồn (server/settings/item, mã TCVN5712-1; dòng tiêu đề GBK) — xem docs/vltk_equipment_reference.md:
  - meleeweapon/rangeweapon/armor/ring/amulet/boot/belt/helm/cuff/pendant.txt: đồ gốc.
    Cột: Tên | Loại | Loại chi tiết | Loại cụ thể | Ảnh | Vật thể | Rộng | Cao | Mô tả | Ngũ hành | Giá |
         Cấp | 7×(mã thuộc tính gốc, min, max) | 6×(mã yêu cầu, giá trị)
  - magicattrib.txt: tiền tố/hậu tố sinh dòng magic ngẫu nhiên (KItemGenerator::Gen_MagicAttrib):
    Tên | Tiền tố? | Ngũ hành (-1 mọi hệ) | Cấp | Mã thuộc tính | 3×(min, max) | Mô tả | 11 tỷ lệ rơi theo
    loại đồ (cận chiến, tầm xa, áo, nhẫn, dây chuyền, giày, thắt lưng, mũ, bao tay, ngọc bội, ngựa).
  - magicattriblevel.txt: chỉ lấy TÊN tiếng Việt cho từng (mã thuộc tính, tiền/hậu tố).
Mã thuộc tính số -> tên VLTK (VD 126 -> "addphysicsdamage_p") lấy từ enum MAGIC_ATTRIB trong
KMagicAttrib.h, để đi thẳng vào MagicAttribTable của game.
"""
import json
import re
import subprocess
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent))
from han_viet import to_han_viet  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "data" / "items"
ITEM_DIR = Path("D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/item")
MAGIC_ATTRIB_H = Path("D:/game/source_vo-lam-truyen-ky/VS2022/Source-VS2022-20260926T022613Z-1-002/Source-VS2022/"
                      "Source/Source/SwordOnline/Sources/Core/Src/KMagicAttrib.h")
## file -> EQUIPDETAILTYPE gốc (GameDataDef.h)
EQUIP_FILES = {"meleeweapon": 0, "rangeweapon": 1, "armor": 2, "ring": 3, "amulet": 4, "boot": 5,
               "belt": 6, "helm": 7, "cuff": 8, "pendant": 9, "horse": 10}
## Hoàng kim: chỉ lấy loại đồ game có ô đeo (0-9 + ngựa 10); mặt nạ/phi phong/ấn/trang sức chưa có ô.
GOLD_MAX_DETAIL = 10


def read_tcvn(path: Path) -> list[list[str]]:
    raw = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                         capture_output=True, check=True).stdout.decode("utf-8", "replace")
    return [line.split("\t") for line in raw.splitlines()]


def to_int(text: str, default: int = 0) -> int:
    try:
        return int(float(text.strip().rstrip("%")))  # ngựa ghi "10%"
    except (ValueError, AttributeError):
        return default


def parse_attribs(r: list[str], start: int, count: int, enum: dict[int, str]) -> list:
    """count × (mã, min, max) từ cột `start` -> [[tên, min, max], ...]."""
    out = []
    for k in range(count):
        t = to_int(r[start + k * 3], -1)
        if t > 0 and t in enum:
            out.append([enum[t], to_int(r[start + 1 + k * 3]), to_int(r[start + 2 + k * 3])])
    return out


def parse_requires(r: list[str], start: int, enum: dict[int, str]) -> list:
    out = []
    for k in range(6):
        t = to_int(r[start + k * 2], -1)
        if t > 0 and t in enum:
            out.append([enum[t], to_int(r[start + 1 + k * 2])])
    return out


def load_attrib_enum() -> dict[int, str]:
    """enum MAGIC_ATTRIB -> {số: tên không tiền tố magic_} (đếm như trình biên dịch C, có `= N`)."""
    text = MAGIC_ATTRIB_H.read_bytes().decode("gbk", "replace")
    body = text[text.index("enum MAGIC_ATTRIB"):]
    body = body[body.index("{") + 1: body.index("}")]
    out, current = {}, -1
    for line in body.splitlines():
        line = line.split("//")[0]
        m = re.search(r"(magic_\w+)\s*(?:=\s*(\d+))?", line)
        if not m:
            continue
        current = int(m.group(2)) if m.group(2) else current + 1
        out[current] = m.group(1)[len("magic_"):]
    return out


def import_equipment(enum: dict[int, str]) -> list[dict]:
    items = []
    for stem, detail in EQUIP_FILES.items():
        rows = read_tcvn(ITEM_DIR / f"{stem}.txt")
        for r in rows[1:]:
            if len(r) < 12 or not r[0].strip():
                continue
            r += [""] * (45 - len(r))
            base = parse_attribs(r, 12, 7, enum)
            req = parse_requires(r, 33, enum)
            items.append({
                "name": r[0].strip(), "detail": detail, "particular": to_int(r[3]), "level": to_int(r[11]),
                "series": to_int(r[9], -1), "price": to_int(r[10]), "width": to_int(r[6], 1),
                "height": to_int(r[7], 1), "intro": clean_text(r[8].strip()), "image": r[4].strip(),
                "base": base, "require": req,
            })
    return items


def import_magic(enum: dict[int, str]) -> list[dict]:
    vi_names = {}
    for r in read_tcvn(ITEM_DIR / "magicattriblevel.txt")[1:]:
        if len(r) > 4 and r[4].strip().lstrip("-").isdigit():
            vi_names.setdefault((to_int(r[4]), to_int(r[1])), r[0].strip())
    out = []
    for r in read_tcvn(ITEM_DIR / "magicattrib.txt")[1:]:
        if len(r) < 23 or not r[4].strip().lstrip("-").isdigit():
            continue
        attrib_id = to_int(r[4])
        if attrib_id not in enum:
            continue
        prefix = to_int(r[1])
        out.append({
            "attrib": enum[attrib_id], "prefix": prefix, "series": to_int(r[2], -1) if r[2].strip() else -1,
            "level": to_int(r[3], 1),
            "range": [[to_int(r[5]), to_int(r[6])], [to_int(r[7]), to_int(r[8])], [to_int(r[9]), to_int(r[10])]],
            "drop": [to_int(x) for x in r[12:23]],
            "name": vi_names.get((attrib_id, prefix), enum[attrib_id]),
        })
    return out


def import_gold(enum: dict[int, str], vi_names: dict) -> list[dict]:
    """GoldEquip.txt (KItemGenerator::Gen_GoldEquipment): 8 chỉ số dòng magic (DefMagic1-6 + ExpandMagic1-2)
    trỏ vào magicattrib_ge.txt — chỉ số k = dòng dữ liệu thứ k (KTabFile dòng k+1, dòng 1 là tiêu đề).
    Giá trị dòng = min + (max - min) × độ_hoàn_mỹ / 10 (lưu min/max, game tính lúc sinh)."""
    ge_rows = read_tcvn(ITEM_DIR / "magicattrib_ge.txt")[1:]
    gold_rows = read_tcvn(ITEM_DIR / "GoldEquip.txt")
    ## Tên gốc dạng byte — vài dòng gốc chưa Việt hoá, tên còn chữ Hán (GBK): giải mã TCVN ra chữ lạ -> đọc lại GBK
    ## rồi chuyển âm Hán-Việt (tools/han_viet.py).
    raw_names = [line.split(b"\t")[0].strip() for line in (ITEM_DIR / "GoldEquip.txt").read_bytes().split(b"\n")]
    col = {h: i for i, h in enumerate(open_header(ITEM_DIR / "GoldEquip.txt"))}
    out = []
    for row, r in enumerate(gold_rows[1:]):
        if len(r) < 52 or not r[0].strip():
            continue
        r += [""] * (60 - len(r))
        detail = to_int(r[col["DetailType"]], -1)
        if detail < 0 or detail > GOLD_MAX_DETAIL:
            continue
        magic = []
        for key in ["DefMagic1", "DefMagic2", "DefMagic3", "DefMagic4", "DefMagic5", "DefMagic6",
                    "ExpandMagic1", "ExpandMagic2"]:
            idx = to_int(r[col[key]], 0) if key in col else 0
            line = None
            if 0 < idx <= len(ge_rows):
                g = ge_rows[idx - 1] + [""] * 12
                attrib_id = to_int(g[4], -1)
                if attrib_id in enum:
                    line = {"attrib": enum[attrib_id], "name": vi_names.get(attrib_id, enum[attrib_id]),
                            "range": [[to_int(g[5]), to_int(g[6])], [to_int(g[7]), to_int(g[8])],
                                      [to_int(g[9]), to_int(g[10])]]}
            magic.append(line)
        req = parse_requires(r, col["Require1"], enum)
        menpai = next((v for n, v in req if n == "requiremenpai"), -1)
        name = r[0].strip()
        raw = raw_names[row + 1] if row + 1 < len(raw_names) else b""
        ## Không có chữ Latin nào nhưng có byte > 0x7F = tên chữ Hán (tên tiếng Việt TCVN luôn có chữ Latin).
        if not re.search(rb"[A-Za-z]", raw.replace(b"[", b"").replace(b"]", b"")) and re.search(rb"[\x80-\xff]", raw):
            name = to_han_viet(raw.decode("gbk", "replace"))
        out.append({
            "name": name, "detail": detail, "particular": to_int(r[col["ParticularType"]]),
            "level": to_int(r[col["Level"]]), "series": to_int(r[col["Series"]], -1),
            "price": to_int(r[col["Price"]]), "image": r[col["Image"]].strip(), "intro": clean_text(r[col["Descript"]].strip()),
            "base": parse_attribs(r, col["Magic1"], 7, enum), "require": req, "menpai": menpai,
            "magic": magic, "group": to_int(r[col["Group"]]), "need1": to_int(r[col["NeedToActive1"]], 1),
            "need2": to_int(r[col["NeedToActive2"]], 0), "set_id": to_int(r[col["SetId"]]),
            ## Số hàng dữ liệu gốc trong GoldEquip.txt (Item.GetRow) — bảng hình GoldEquipRes tra theo row + 1.
            "row": row,
        })
    return out


def import_magic_desc() -> dict:
    """settings/MagicDesc.ini [Descript]: mẫu câu hiển thị từng thuộc tính (KMagicDesc::GetDesc), VD
    lifemax_v -> "Sinh lực tối đa: #d1+ điểm"."""
    path = ITEM_DIR.parent / "MagicDesc.ini"
    raw = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                         capture_output=True, check=True).stdout.decode("utf-8", "replace")
    out = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith(("//", "[")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if value.strip():
            out[key.strip()] = value.strip()
    return out


def clean_text(text: str) -> str:
    """Bỏ chuỗi lỗi mã: vài ô gốc ghi tiếng Trung (GBK) nên giải mã TCVN ra dấu kết hợp rời
    (U+0300-U+036F) — tiếng Việt TCVN chuẩn luôn ra chữ dựng sẵn, không có dấu rời."""
    return "" if any("̀" <= ch <= "ͯ" for ch in text) else text


def import_skill_names() -> dict:
    """Skills.txt: SkillId -> tên (cho dòng "Kỹ năng [ <tên> ]: +N cấp" của allskill_v)."""
    rows = read_tcvn(ITEM_DIR.parent / "Skills.txt")
    out = {}
    for r in rows[1:]:
        if len(r) > 2 and r[2].strip().isdigit():
            name = clean_text(r[0].strip())
            if name:
                out.setdefault(r[2].strip(), name)
    return out


def open_header(path: Path) -> list[str]:
    return path.read_bytes().split(b"\n", 1)[0].decode("gbk", "replace").rstrip("\r").split("\t")


def main():
    enum = load_attrib_enum()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    equipment = import_equipment(enum)
    magic = import_magic(enum)
    vi_by_attrib = {}
    for r in read_tcvn(ITEM_DIR / "magicattriblevel.txt")[1:]:
        if len(r) > 4 and r[4].strip().lstrip("-").isdigit():
            vi_by_attrib.setdefault(to_int(r[4]), r[0].strip())
    gold = import_gold(enum, vi_by_attrib)
    (OUT_DIR / "equipment.json").write_text(json.dumps(equipment, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (OUT_DIR / "magic_attribs.json").write_text(json.dumps(magic, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (OUT_DIR / "gold_equipment.json").write_text(json.dumps(gold, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    skills = import_skill_names()
    (OUT_DIR / "skill_names.json").write_text(json.dumps(skills, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Tên kỹ năng theo mã: {len(skills)} (VD 271 = {skills.get('271')})")
    desc = import_magic_desc()
    (OUT_DIR / "magic_desc.json").write_text(json.dumps(desc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Mẫu câu thuộc tính: {len(desc)} (VD lifemax_v = {desc.get('lifemax_v')})")
    print(f"Hoàng kim: {len(gold)} món (có môn phái: {sum(1 for g in gold if g['menpai'] >= 0)})")
    print("Mẫu hoàng kim:", gold[0]["name"], gold[0]["menpai"], gold[0]["group"], gold[0]["magic"][:2])
    by_detail = {}
    for it in equipment:
        by_detail[it["detail"]] = by_detail.get(it["detail"], 0) + 1
    print(f"Đồ gốc: {len(equipment)} món theo loại chi tiết {by_detail}")
    print(f"Thuộc tính magic: {len(magic)} dòng")
    print("Mẫu:", equipment[0]["name"], equipment[0]["base"], equipment[0]["require"])
    print("Mẫu magic:", magic[0])


if __name__ == "__main__":
    main()
