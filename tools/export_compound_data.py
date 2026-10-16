"""Xuất dữ liệu CHẾ TẠO (bảng giá trị vật phẩm của Thợ rèn gốc) -> data/items/compound.json (đọc bởi Compound).

    python -X utf8 -I tools/export_compound_data.py

Nguồn: settings/item/004 của server 15 phái (bản dữ liệu đồ mới nhất — ITEM_GetLatestItemVersion):
  - magicattriblevel.txt: mỗi dòng = 1 "cấp thuộc tính" (MagAttrLvl, số thứ tự dòng dữ liệu từ 1): mã thuộc tính, cấp,
    3 khoảng tham số, giá trị gốc, giá trị theo từng loại đồ (cột SWORD..PENDANT) và theo hệ (METAL..EARTH, %).
  - magicattriblevel_index.txt: mã thuộc tính -> khoảng MagAttrLvl (khảm / tách khoáng chọn trong khoảng này).
  - itemvalue/*.txt: giá trị khoáng thạch theo cấp (ore), đồ xanh theo số dòng (equip_normal_magic), đồ tím: số ô trống
    (equip_enchasable_socket), cấp đồ (equip_enchasable_level), loại đồ (equip_enchasable_type), vị trí dòng
    (equip_enchasable_magic_pos), hệ số ghép 2 thuộc tính (magicattrib_combine).
  - itemvaluescript.txt: giá trị cố định của vật phẩm phụ trợ (Thần bí khoáng thạch, Thủy Tinh, Phúc Duyên Lộ).
Công thức dùng các bảng này: script/item/compound/*.lua + script/item/itemvalue/*.lua (xem systems/items/compound.gd).
"""
import json
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent))
import vltk_source  # noqa: E402
from import_vltk_items import read_tcvn, to_int, load_attrib_enum  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "items" / "compound.json"
VER = "item/004/"
EQUIP_COLUMNS = ["SWORD", "BLADE", "WAND", "SPEAR", "HAMMER", "DUALBLADES", "DARTS", "KNIFE", "CROSSBOW", "ARMOR", "RING",
                 "NECKLACE", "AMULET", "BOOT", "BELT", "HELM", "CUFF", "SACHET", "PENDANT"]
SERIES_COLUMNS = ["METAL", "WOOD", "WATER", "FIRE", "EARTH"]
## Vật phẩm phụ trợ (ConsumeItem trong foundryresdemand.ini) — mã game (misc_items.json) -> (genre, detail, particular).
ALT_ITEMS = {"6_1_398": (6, 1, 398), "4_238_1": (4, 238, 1), "4_239_1": (4, 239, 1), "4_240_1": (4, 240, 1),
             "6_1_122": (6, 1, 122), "6_1_123": (6, 1, 123), "6_1_124": (6, 1, 124)}


def table(name: str) -> list[dict]:
    """Bảng tab có tiêu đề (GBK/ASCII) -> các dòng {tên cột: chữ}."""
    path = vltk_source.settings_file(VER + name)
    lines = [l.rstrip("\r").split("\t") for l in path.read_bytes().decode("gbk", "replace").split("\n") if l.strip()]
    head = lines[0]
    return [{head[i]: (r[i] if i < len(r) else "") for i in range(len(head))} for r in lines[1:]]


def main():
    enum = load_attrib_enum()
    path = vltk_source.settings_file(VER + "magicattriblevel.txt")
    rows_raw = read_tcvn(path)
    head = path.read_bytes().split(b"\n", 1)[0].decode("gbk", "replace").rstrip("\r").split("\t")
    col = {h: i for i, h in enumerate(head)}
    rows = [None]   ## MagAttrLvl bắt đầu từ 1 (dòng dữ liệu thứ 1 = dòng 2 của file)
    for r in rows_raw[1:]:
        if len(r) < len(head) - 1 or not r[col["MAGIC_ID"]].strip().lstrip("-").isdigit():
            if any(x.strip() for x in r):
                rows.append(None)
            continue
        mid = to_int(r[col["MAGIC_ID"]])
        rows.append({
            "id": mid, "attrib": enum.get(abs(mid), ""), "name": r[0].strip(), "prefix": to_int(r[col["PREFIX"]]),
            "level": to_int(r[col["LEVEL"]]),
            "p": [[to_int(r[col["MAG_P%d_MIN" % k]], -1), to_int(r[col["MAG_P%d_MAX" % k]], -1)] for k in (1, 2, 3)],
            "base": to_int(r[col["BASE_VALUE"]]),
            "equip": [to_int(r[col[c]]) for c in EQUIP_COLUMNS],
            "series": [to_int(r[col[c]]) for c in SERIES_COLUMNS],
        })
    index = [[to_int(r["MAGIC_ID"]), to_int(r["MAGATTRLVL_START"]), to_int(r["MAGATTRLVL_END"])]
             for r in table("magicattriblevel_index.txt") if r["MAGIC_ID"].strip().lstrip("-").isdigit()]
    ## Hệ số ghép: dòng 2 = MAGIC_ID theo cột; dòng k (k >= 3) = thuộc tính thứ k-2, cột k = thuộc tính thứ k-2.
    cpath = vltk_source.settings_file(VER + "itemvalue/magicattrib_combine.txt")
    clines = [l.rstrip("\r").split("\t") for l in cpath.read_bytes().decode("gbk", "replace").split("\n") if l.strip()]
    ids = [to_int(r[1]) for r in clines[2:]]
    combine = {}
    for a in range(len(ids)):
        for b in range(a + 1, len(ids)):
            row = clines[2 + a]
            cell = row[2 + b].strip() if 2 + b < len(row) else ""
            combine["%d,%d" % (ids[a], ids[b])] = to_int(cell, 100) if cell else 100
    ivs = vltk_source.settings_file("item/itemvaluescript.txt")
    alt = {}
    for r in read_tcvn(ivs)[1:]:
        if len(r) > 7:
            key = (to_int(r[2]), to_int(r[3]), to_int(r[4]))
            for mid, k in ALT_ITEMS.items():
                if k == key and r[7].strip():
                    alt[mid] = to_int(r[7])
    out = {
        "rows": rows, "index": index, "combine": combine,
        "ore": [to_int(r["VALUE"]) for r in table("itemvalue/ore.txt")],
        "normal_magic": [to_int(r["VALUE"]) for r in table("itemvalue/equip_normal_magic.txt")],
        "socket": [to_int(r["VALUE"]) for r in table("itemvalue/equip_enchasable_socket.txt")],
        "level": [[to_int(r["VALUE%_1"]), to_int(r["VALUE%_2"])] for r in table("itemvalue/equip_enchasable_level.txt")],
        "type": [[to_int(r["GENRE"], -1), to_int(r["DETAILTYPE"], -1), to_int(r["PARTICULAR"], -1), to_int(r["VALUE%"], 100)]
                 for r in table("itemvalue/equip_enchasable_type.txt")],
        "pos": [to_int(r["VALUE%"], 100) for r in table("itemvalue/equip_enchasable_magic_pos.txt")],
        "alt": alt,
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("compound.json: %d cấp thuộc tính, %d khoảng, %d cặp ghép, phụ trợ %s" % (len(rows) - 1, len(index), len(combine), alt))
    print("ore", out["ore"], "socket", out["socket"], "pos", out["pos"])


if __name__ == "__main__":
    main()
