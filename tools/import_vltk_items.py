"""Nhập dữ liệu VẬT PHẨM VLTK (bản 15 phái, tools/vltk_source.py) -> data/items/*.json (đọc bởi ItemDatabase).

    python -X utf8 -I tools/import_vltk_items.py

Nguồn: settings/item của server 15 phái (vltk_source.SETTINGS, mã TCVN5712-1; dòng tiêu đề GBK) — xem
docs/vltk_equipment_reference.md. Cột tra theo TÊN TIÊU ĐỀ (bản 15 phái chèn thêm cột "是否叠放" sau Cấp):
  - meleeweapon/rangeweapon/armor/ring/amulet/boot/belt/helm/cuff/pendant/horse.txt: đồ gốc.
    Cột: Tên | Loại | Loại chi tiết | Loại cụ thể | Ảnh | Vật thể | Rộng | Cao | Mô tả | Ngũ hành | Giá |
         Cấp | (Chồng được) | 7×(mã thuộc tính gốc, min, max) | 6×(mã yêu cầu, giá trị)
  - magicattrib.txt: tiền tố/hậu tố sinh dòng magic ngẫu nhiên (KItemGenerator::Gen_MagicAttrib):
    Tên | Tiền tố? | Ngũ hành (-1 mọi hệ) | Cấp | Mã thuộc tính | 3×(min, max) | Mô tả | 11 tỷ lệ rơi theo
    loại đồ (cận chiến, tầm xa, áo, nhẫn, dây chuyền, giày, thắt lưng, mũ, bao tay, ngọc bội, ngựa).
  - magicattriblevel.txt: chỉ lấy TÊN tiếng Việt cho từng (mã thuộc tính, tiền/hậu tố).
  - goldequip.txt + magicattrib_ge.txt + suite_activate_count.txt / ext_suite_activate_count.txt: hoàng kim.
  - potion/questkey/magicscript/townportal.txt: thuốc, vật phẩm nhiệm vụ / dược liệu, vật phẩm dùng (script),
    Thổ địa phù -> misc_items.json (chưa có hệ thống dùng, chỉ là dữ liệu + ảnh).
Mã thuộc tính số -> tên VLTK (VD 126 -> "addphysicsdamage_p") lấy từ enum MAGIC_ATTRIB trong
KMagicAttrib.h (bản 15 phái không kèm mã nguồn C++; enum cũ phủ đủ mọi mã dùng trong dữ liệu mới, max 302),
để đi thẳng vào MagicAttribTable của game.

CHỈ SỐ ỔN ĐỊNH: save lưu món đồ bằng chỉ số trong equipment.json / gold_equipment.json. Trước khi ghi đè, file cũ được
đối chiếu với dữ liệu mới -> data/items/index_remap.json (chỉ số cũ -> mới, -1 = không còn); ItemInstance.from_dict
đổi chỉ số của save cũ (chưa có "dv") theo bảng này.
"""
import json
import re
import subprocess
import unicodedata
import zlib
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent))
from han_viet import to_han_viet  # noqa: E402
import vltk_source  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "data" / "items"
MAGIC_ATTRIB_H = Path("D:/game/source_vo-lam-truyen-ky/VS2022/Source-VS2022-20260926T022613Z-1-002/Source-VS2022/"
                      "Source/Source/SwordOnline/Sources/Core/Src/KMagicAttrib.h")
## Bản cũ (server Anh Việt): GoldEquip.txt cũ còn ghi NeedToActive1/2 cho bộ 1-82 — bản 15 phái bỏ 2 cột này và
## suite_activate_count.txt chỉ có từ bộ 83, nên số món kích hoạt của bộ cũ lấy từ đây (không có file thì = 0).
OLD_GOLD_FILE = Path("D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/item/GoldEquip.txt")
## Phiên bản dữ liệu đồ — tăng khi chỉ số món đổi (ItemInstance.DATA_VERSION phải bằng số này).
DATA_VERSION = 2
## file -> EQUIPDETAILTYPE gốc (GameDataDef.h)
EQUIP_FILES = {"meleeweapon": 0, "rangeweapon": 1, "armor": 2, "ring": 3, "amulet": 4, "boot": 5,
               "belt": 6, "helm": 7, "cuff": 8, "pendant": 9, "horse": 10}
## Hoàng kim: chỉ lấy loại đồ game có ô đeo (0-9 + ngựa 10); mặt nạ/phi phong/ấn/trang sức chưa có ô.
GOLD_MAX_DETAIL = 10
## Tiêu đề cột goldequip.txt bản 15 phái (tiếng Trung) -> tên cột bản cũ (tiếng Anh) mà code dùng.
GOLD_HEADER_ALIAS = {"名称": "Name", "动画文件名": "Image", "说明文字": "Descript", "五行属性": "Series", "价格": "Price",
                     "等级": "Level", "基础属性1类型": "Magic1", "需求属性1类型": "Require1", "所在套装": "Group",
                     "扩展套装": "ExtSuite", "扩展套装序号": "SetId", "扩展套装隐藏属性1": "ExpandMagic1",
                     "扩展套装隐藏属性2": "ExpandMagic2",
                     **{"魔法属性索引%d" % k: "DefMagic%d" % k for k in range(1, 7)}}


def read_tcvn(path: Path, gbk_cols: tuple = ()) -> list[list[str]]:
    """Bảng TCVN -> các dòng. `gbk_cols`: cột đọc lại theo GBK từ byte gốc — đường dẫn ảnh có tên thư mục/file chữ Hán
    (tên trong pak mã GBK; giải mã TCVN làm hỏng)."""
    raw = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                         capture_output=True, check=True).stdout.decode("utf-8", "replace")
    rows = [line.rstrip("\r").split("\t") for line in raw.split("\n")]
    if gbk_cols:
        raw_rows = [line.rstrip(b"\r").split(b"\t") for line in path.read_bytes().split(b"\n")]
        assert len(raw_rows) == len(rows), path
        for r, b in zip(rows, raw_rows):
            for c in gbk_cols:
                if c < len(r) and c < len(b) and re.search(rb"[\x80-\xff]", b[c]):
                    r[c] = b[c].decode("gbk", "replace").strip()
    return rows


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


def item_file(name: str) -> Path:
    """File trong settings/item (không phân biệt hoa thường: GoldEquip.txt / goldequip.txt)."""
    return vltk_source.settings_file("item/" + name)


def attrib_columns(path: Path) -> tuple[int, int]:
    """Cột đầu của 7×thuộc tính gốc và 6×yêu cầu, theo tiêu đề (bản 15 phái lệch 1 cột do "是否叠放")."""
    header = open_header(path)
    return header.index("基础属性1类型"), header.index("需求属性1类型")


def import_equipment(enum: dict[int, str]) -> list[dict]:
    items = []
    for stem, detail in EQUIP_FILES.items():
        path = item_file(f"{stem}.txt")
        magic_col, req_col = attrib_columns(path)
        rows = read_tcvn(path, (4,))
        for r in rows[1:]:
            if len(r) < 12 or not r[0].strip():
                continue
            r += [""] * (req_col + 12 - len(r))
            base = parse_attribs(r, magic_col, 7, enum)
            req = parse_requires(r, req_col, enum)
            items.append({
                "name": r[0].strip(), "detail": detail, "particular": to_int(r[3]), "level": to_int(r[11]),
                "series": to_int(r[9], -1), "price": to_int(r[10]), "width": to_int(r[6], 1),
                "height": to_int(r[7], 1), "intro": clean_text(r[8].strip()), "image": r[4].strip(),
                "base": base, "require": req,
            })
    return items


def import_magic(enum: dict[int, str]) -> list[dict]:
    vi_names = {}
    for r in read_tcvn(item_file("magicattriblevel.txt"))[1:]:
        if len(r) > 4 and r[4].strip().lstrip("-").isdigit():
            vi_names.setdefault((to_int(r[4]), to_int(r[1])), r[0].strip())
    out = []
    for r in read_tcvn(item_file("magicattrib.txt"))[1:]:
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


def read_counts(name: str) -> dict[int, list[int]]:
    """suite_activate_count.txt (SuiteNo, ActivateCount) / ext_suite_activate_count.txt (SuiteNo, Count1, Count2)."""
    out = {}
    for r in read_tcvn(item_file(name))[1:]:
        if r and r[0].strip().isdigit():
            out[int(r[0])] = [to_int(x) for x in r[1:3] if x.strip()]
    return out


def old_gold_needs() -> dict[int, tuple[int, int]]:
    """Bộ (Group) -> (NeedToActive1, NeedToActive2) của GoldEquip.txt bản cũ — chỉ dùng khi bản 15 phái không có số."""
    if not OLD_GOLD_FILE.exists():
        return {}
    col = {h: i for i, h in enumerate(open_header(OLD_GOLD_FILE))}
    out = {}
    for r in read_tcvn(OLD_GOLD_FILE)[1:]:
        if len(r) > col["NeedToActive2"] and r[col["Group"]].strip().isdigit():
            out.setdefault(int(r[col["Group"]]), (to_int(r[col["NeedToActive1"]], 1), to_int(r[col["NeedToActive2"]], 0)))
    return out


def import_gold(enum: dict[int, str], vi_names: dict) -> list[dict]:
    """goldequip.txt (KItemGenerator::Gen_GoldEquipment): 6 chỉ số dòng magic (DefMagic1-6) + 2 dòng ẩn của bộ mở
    rộng (ExpandMagic1-2) trỏ vào magicattrib_ge.txt — chỉ số k = dòng dữ liệu thứ k (KTabFile dòng k+1, dòng 1 là
    tiêu đề). Giá trị dòng = min + (max - min) × độ_hoàn_mỹ / 10 (lưu min/max, game tính lúc sinh).
    Số món kích hoạt (bản 15 phái tách ra file riêng):
      need2 (đủ bộ, mở hết dòng ẩn) = suite_activate_count[Group] -> ext_suite_activate_count[ExtSuite][1] -> bản cũ;
      need1 (mỗi dòng mở rộng)      = ext_suite_activate_count[ExtSuite][0] -> bản cũ -> 1."""
    path = item_file("goldequip.txt")
    ge_rows = read_tcvn(item_file("magicattrib_ge.txt"))[1:]
    gold_rows = read_tcvn(path, (4,))
    suite = read_counts("suite_activate_count.txt")
    ext_suite = read_counts("ext_suite_activate_count.txt")
    old_needs = old_gold_needs()
    ## Tên gốc dạng byte — vài dòng gốc chưa Việt hoá, tên còn chữ Hán (GBK): giải mã TCVN ra chữ lạ -> đọc lại GBK
    ## rồi chuyển âm Hán-Việt (tools/han_viet.py).
    raw_names = [line.split(b"\t")[0].strip() for line in path.read_bytes().split(b"\n")]
    col = {GOLD_HEADER_ALIAS.get(h, h): i for i, h in enumerate(open_header(path))}
    out = []
    for row, r in enumerate(gold_rows[1:]):
        if len(r) < 52 or not r[0].strip():
            continue
        r += [""] * (col["ExpandMagic2"] + 2 - len(r))
        detail = to_int(r[2], -1)
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
        group = to_int(r[col["Group"]])
        ext = to_int(r[col["ExtSuite"]])
        old1, old2 = old_needs.get(group, (1, 0))
        ext_counts = ext_suite.get(ext, [])
        need1 = ext_counts[0] if ext_counts else old1
        need2 = suite[group][0] if suite.get(group) else (ext_counts[1] if len(ext_counts) > 1 else old2)
        out.append({
            "name": name, "detail": detail, "particular": to_int(r[3]),
            "level": to_int(r[col["Level"]]), "series": to_int(r[col["Series"]], -1),
            "price": to_int(r[col["Price"]]), "image": r[col["Image"]].strip(), "intro": clean_text(r[col["Descript"]].strip()),
            "base": parse_attribs(r, col["Magic1"], 7, enum), "require": req, "menpai": menpai,
            "magic": magic, "group": group, "need1": need1, "need2": need2, "set_id": to_int(r[col["SetId"]]),
            ## Bộ MỞ RỘNG (ExtSuite gốc, 0 = không) — có thể gồm 2 Group (bộ thường + bản nâng cấp).
            "ext": ext,
            ## Số hàng dữ liệu gốc trong goldequip.txt (Item.GetRow) — bảng hình GoldEquipRes tra theo row + 1.
            "row": row,
        })
    return out


def import_magic_desc() -> dict:
    """settings/MagicDesc.ini [Descript]: mẫu câu hiển thị từng thuộc tính (KMagicDesc::GetDesc), VD
    lifemax_v -> "Sinh lực tối đa: #d1+ điểm"."""
    path = vltk_source.settings_file("MagicDesc.ini")
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
    """Skills.txt: SkillId -> tên (cho dòng "Kỹ năng [ <tên> ]: +N cấp" của allskill_v). Bản 15 phái thiếu vài
    trăm mã (VD 1220-1300, 1440-1470 — hoàng kim vẫn dùng) -> mã nào không có thì lấy tên ở Skills.txt bản cũ."""
    out = {}
    for path in (vltk_source.settings_file("Skills.txt"), OLD_GOLD_FILE.parent.parent / "Skills.txt"):
        if not path.exists():
            continue
        for r in read_tcvn(path)[1:]:
            if len(r) > 2 and r[2].strip().isdigit():
                name = clean_text(r[0].strip())
                if name:
                    out.setdefault(r[2].strip(), name)
    return out


## Vật phẩm KHÔNG phải trang bị: file -> cột (chỉ số 0-based) của từng trường. None = file không có cột đó.
## genre gốc: 1 thuốc (potion), 4 nhiệm vụ / dược liệu (questkey), 5 Thổ địa phù, 6 vật phẩm dùng có script.
## Thuốc phân biệt theo (loại chi tiết, CẤP) — VD Kim Sáng Dược tiểu/trung/đại cùng 1_0_0, cấp 1/2/3 — nên id thêm "_cấp".
MISC_FILES = {
    "potion.txt": {"genre": 1, "detail": 2, "particular": 3, "image": 4, "width": 6, "height": 7, "intro": 8,
                   "price": 10, "level": 11, "stack": None, "effects": 13},
    "questkey.txt": {"genre": 1, "detail": 2, "particular": 8, "image": 3, "width": 5, "height": 6, "intro": 7,
                     "price": None, "level": None, "stack": 9},
    "magicscript.txt": {"genre": 1, "detail": 2, "particular": 3, "image": 4, "width": 6, "height": 7, "intro": 8,
                        "price": 10, "level": 11, "stack": 20, "script": 13, "skill_id": 14},
    "townportal.txt": {"genre": 1, "detail": None, "particular": None, "image": 2, "width": 4, "height": 5,
                       "intro": 7, "price": 6, "level": None, "stack": None},
}


def import_misc(enum: dict[int, str]) -> list[dict]:
    """Thuốc / vật phẩm nhiệm vụ / vật phẩm dùng -> [{id "genre_detail_particular", name, ..., effects?, script?}].
    effects (thuốc): [[thuộc tính magic gốc, giá trị, số frame]] — 5×(mã, giá trị, thời gian) của potion.txt."""
    out, seen = [], set()
    for name, cols in MISC_FILES.items():
        for r in read_tcvn(item_file(name), (cols["image"],))[1:]:
            if len(r) < 6 or not r[0].strip() or not r[1].strip().isdigit():
                continue
            r += [""] * 40

            def get(key, default=0):
                c = cols.get(key)
                return to_int(r[c], default) if c is not None else default
            item_id = "%d_%d_%d" % (get("genre"), get("detail"), get("particular"))
            if "effects" in cols:
                item_id += "_%d" % get("level")
            item = {"id": item_id, "name": clean_text(r[0].strip()),
                    "genre": get("genre"), "detail": get("detail"), "particular": get("particular"),
                    "image": r[cols["image"]].strip(), "width": get("width", 1), "height": get("height", 1),
                    "intro": clean_text(r[cols["intro"]].strip()), "price": get("price"), "level": get("level"),
                    "stack": get("stack"), "source": name[:-4]}
            if item["id"] in seen or not item["name"]:
                continue
            seen.add(item["id"])
            if "effects" in cols:
                item["effects"] = [[enum[to_int(r[c])], to_int(r[c + 1]), to_int(r[c + 2])]
                                   for c in range(cols["effects"], cols["effects"] + 15, 3) if to_int(r[c], -1) in enum]
            if "script" in cols:
                script = r[cols["script"]].strip()
                item["script"] = script if script.lower().endswith(".lua") else ""
                item["skill_id"] = get("skill_id")
            out.append(item)
    return out


def assign_misc_icons(misc: list, equipment: list, gold: list) -> None:
    """Trường "icon" (tên file ảnh trong assets/items/icons) cho vật phẩm khác: tên file ảnh gốc viết thường; nếu tên
    có chữ Hán (pak mã GBK) hoặc trùng tên với ảnh KHÁC đường dẫn -> âm Hán-Việt không dấu + mã crc32 của đường dẫn."""
    def base_name(path):
        return path.replace("\\", "/").rsplit("/", 1)[-1].rsplit(".", 1)[0].lower()
    owners = {}
    for it in equipment + gold + misc:
        if it.get("image"):
            owners.setdefault(base_name(it["image"]), set()).add(it["image"].lower().lstrip("\\"))
    for it in misc:
        if not it["image"]:
            it["icon"] = ""
            continue
        name = base_name(it["image"])
        if name.isascii() and len(owners[name]) == 1:
            it["icon"] = name
            continue
        plain = unicodedata.normalize("NFD", to_han_viet(name).replace("đ", "d").replace("Đ", "D"))
        slug = re.sub(r"[^a-z0-9]+", "_", "".join(ch for ch in plain if ch.isascii()).lower()).strip("_")
        it["icon"] = "%s_%08x" % (slug or "item", zlib.crc32(it["image"].lower().lstrip("\\").encode("utf-8")))


def match_indices(old: list, new: list, keys) -> list[int]:
    """Chỉ số cũ -> mới: thử lần lượt từng hàm khoá (khoá chặt trước), mỗi món mới chỉ ghép 1 lần; -1 = không còn."""
    result = [-1] * len(old)
    used = set()
    for key in keys:
        lookup = {}
        for i, it in enumerate(new):
            if i not in used:
                lookup.setdefault(key(it), []).append(i)
        for j, it in enumerate(old):
            if result[j] >= 0:
                continue
            for i in lookup.get(key(it), []):
                if i not in used:
                    result[j] = i
                    used.add(i)
                    break
    return result


def build_remap(equipment: list, gold: list) -> dict:
    """Bảng đổi chỉ số save cũ (DATA_VERSION trước) -> mới. Chạy lại importer: ghép bảng sẵn có với bước đổi mới."""
    def load(name):
        path = OUT_DIR / name
        return json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    lower = lambda s: str(s).lower().strip()  # noqa: E731
    base_map = match_indices(load("equipment.json"), equipment, [
        lambda e: (e["detail"], e["particular"], e["level"], lower(e["name"])),
        lambda e: (e["detail"], e["particular"], e["level"])])
    gold_map = match_indices(load("gold_equipment.json"), gold, [
        lambda g: (g["row"], lower(g["name"])),
        lambda g: (lower(g["name"]), g["detail"], g["particular"], g["level"], g["menpai"]),
        lambda g: (g["detail"], g["particular"], g["level"], lower(g["image"]), g["group"], g["set_id"]),
        lambda g: (g["detail"], g["particular"], g["level"], lower(g["image"]), g["group"])])
    path = OUT_DIR / "index_remap.json"
    prev = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    if prev.get("version") == DATA_VERSION:
        ## Bảng đã có cho phiên bản này: chỉ số "cũ" của nó trỏ vào dữ liệu lần chạy trước -> ghép tiếp.
        base_map = [base_map[i] if 0 <= i < len(base_map) else -1 for i in prev["base"]]
        gold_map = [gold_map[i] if 0 <= i < len(gold_map) else -1 for i in prev["gold"]]
    return {"version": DATA_VERSION, "base": base_map, "gold": gold_map}


def open_header(path: Path) -> list[str]:
    return path.read_bytes().split(b"\n", 1)[0].decode("gbk", "replace").rstrip("\r").split("\t")


def main():
    enum = load_attrib_enum()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    equipment = import_equipment(enum)
    magic = import_magic(enum)
    vi_by_attrib = {}
    for r in read_tcvn(item_file("magicattriblevel.txt"))[1:]:
        if len(r) > 4 and r[4].strip().lstrip("-").isdigit():
            vi_by_attrib.setdefault(to_int(r[4]), r[0].strip())
    gold = import_gold(enum, vi_by_attrib)
    remap = build_remap(equipment, gold)
    (OUT_DIR / "index_remap.json").write_text(json.dumps(remap, separators=(",", ":")), encoding="utf-8")
    print("Đổi chỉ số save cũ: đồ gốc mất %d/%d, hoàng kim mất %d/%d" % (
        remap["base"].count(-1), len(remap["base"]), remap["gold"].count(-1), len(remap["gold"])))
    misc = import_misc(enum)
    assign_misc_icons(misc, equipment, gold)
    (OUT_DIR / "misc_items.json").write_text(json.dumps(misc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    by_source = {}
    for it in misc:
        by_source[it["source"]] = by_source.get(it["source"], 0) + 1
    print(f"Vật phẩm khác: {len(misc)} món {by_source}")
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
