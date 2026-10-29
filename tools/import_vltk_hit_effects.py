"""Nhập TOÀN BỘ thuộc tính magic VLTK gốc của mọi skill vào systems/sect/data/*.tres:
  - vltk_attribs: {tên thuộc tính: [3 mảng mốc (cấp, giá trị)]} — đúng SKILLS[bảng][thuộc tính] trong lua.
  - target_enemy / target_ally / target_self / is_aura / vltk_is_physical — các cột cùng tên Skills.txt.

    python tools/import_vltk_hit_effects.py          # ghi vào .tres (chạy lại bao nhiêu lần cũng được)
    python tools/import_vltk_hit_effects.py --dry    # chỉ in kết quả, không ghi
    python tools/import_vltk_hit_effects.py hoa_son vu_hon   # chỉ các phái này

Nguồn (không đoán theo giá trị số):
  - settings/Skills.txt (TCVN5712-1): mỗi dòng skill có LvlSettingN (tên thuộc tính) + LvlDataN (tên bảng
    trong file lua) + LvlSetScript (file lua) -> biết CHÍNH XÁC bảng lua nào chứa thuộc tính nào.
  - script/skill/<phái>.lua: SKILLS[<bảng>][<thuộc tính>] = {{{cấp,giá trị}...} x 3 thành phần}; giá trị
    có thể là biểu thức (VD 18*120) — tính ra số.
Skill game <-> dòng Skills.txt ghép theo TÊN (bỏ phần "(hệ X)"/"(Tăng N)" trong tên game).
Ý nghĩa từng thuộc tính khi áp vào nhân vật: systems/combat/magic_attrib_table.gd.
"""
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
TRES_DIR = ROOT / "systems" / "sect" / "data"
VLTK = Path("D:/game/source_vo-lam-truyen-ky/anh-viet")
SKILLS_TXT = VLTK / "Server + client full-001/server/settings/Skills.txt"
MISSLES_TXT = VLTK / "Server + client full-001/server/settings/Missles.txt"
VNG_CLIENT = r"D:\game\source_vo-lam-truyen-ky\vng\Level Up Games\Vo Lam Truyen Ky 2.0"


def _use_vng_tables():
    """Bảng Skills.txt / Missles.txt lấy từ pak client VNG (bản chuẩn) -> thư mục tạm; không đọc được thì giữ bản server cũ."""
    global SKILLS_TXT, MISSLES_TXT
    import os
    import tempfile
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import vltk_pak
    paks = vltk_pak.PakList.__new__(vltk_pak.PakList)
    paks.client_dir, paks.paks = VNG_CLIENT, []
    for n in "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split():
        f = os.path.join(VNG_CLIENT, "data", n + ".pak")
        if os.path.isfile(f):
            paks.paks.append(vltk_pak.PakFile(f))
    out = Path(tempfile.mkdtemp(prefix="vng_hit_"))
    for name in ("Skills.txt", "Missles.txt"):
        data = paks.read("settings/" + name)
        if data is None:
            print("Không thấy %s trong pak VNG - dùng bản server cũ" % name)
            return
        (out / name).write_bytes(data)
    SKILLS_TXT, MISSLES_TXT = out / "Skills.txt", out / "Missles.txt"


_use_vng_tables()
## Bản 15 phái (tools/vltk_source.py): 5 phái mới CHỈ có ở bản này (+ Ngũ Độc theo bản mới) -> Skills.txt/Missles.txt/lua của server 15 phái.
## 10 phái cũ giữ bản VNG ở trên: server 15 phái đã cân bằng lại phái cũ (VD skill 150 lên cấp 50, sát thương x5) — lệch gốc.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import vltk_source  # noqa: E402
NEW_SECTS = set(vltk_source.JX15_DATA_SECTS)
NEW_SKILLS_TXT = vltk_source.settings_file("skills.txt")
NEW_MISSLES_TXT = vltk_source.settings_file("missles.txt")
NEW_LUA_DIRS = [vltk_source.SERVER]
LUA_DIRS = [
    VLTK / "JXWin Anh Việt-20260926T075907Z-1-002/JXWin Anh Việt/Client anhviet pas 123456/Client123456",
    VLTK / "MiTom_Pak_SPR_v1.1.7/Unpacked_Resources",
]
## Thuộc tính không phải chỉ số nhân vật/hiệu ứng (tham số tên lửa, tiêu hao, combo đã có ở stat_lines).
SKIP_PREFIXES = ("skill_", "missle_", "addskilldamage")
FLAG_COLUMNS = {"target_enemy": "TargetEnemy", "target_ally": "TargetAlly", "target_self": "TargetSelf",
                "is_aura": "IsAura"}
## Field cũ của bản script trước (đã thay bằng vltk_attribs) — xoá khỏi .tres khi chạy lại.
LEGACY_FIELDS = ["freeze_time_points", "poison_time_points", "poison_interval_points", "stun_chance_points",
                 "stun_time_points", "cold_enhance_points", "poison_enhance_points", "freeze_reduce_points",
                 "poison_reduce_points", "stun_reduce_points"]
## Cột số Skills.txt -> field .tres; phạm vi ảnh hưởng lấy từ đạn con (ChildSkillId) trong Missles.txt.
INT_COLUMNS = {"vltk_missle_form": "MisslesForm", "vltk_attack_radius": "AttackRadius",
               "vltk_state_special_id": "StateSpecialId"}
MISSLE_FIELDS = ["vltk_damage_range", "vltk_range_damage", "vltk_hit_friend"]
WRITTEN_FIELDS = (["vltk_attribs", "vltk_is_physical"] + list(FLAG_COLUMNS) + list(INT_COLUMNS)
                  + MISSLE_FIELDS + LEGACY_FIELDS)


def to_int(text: str) -> int:
    try:
        return int(float(text.strip()))
    except ValueError:
        return 0


def load_missles(path=None):
    """MissleId -> {DmgRange, IsRangeDmg, CanColFriend} (KMissle::GetInfoFromTabFile gốc)."""
    raw = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path or MISSLES_TXT)],
                         capture_output=True, check=True).stdout.decode("utf-8", "replace")
    lines = raw.splitlines()
    col = {h: i for i, h in enumerate(lines[0].split("\t"))}
    out = {}
    for line in lines[1:]:
        cells = line.split("\t")
        if len(cells) <= col["CanColFriend"]:
            continue
        out[to_int(cells[col["MissleId"]])] = {
            "vltk_damage_range": to_int(cells[col["DmgRange"]]),
            "vltk_range_damage": to_int(cells[col["IsRangeDmg"]]),
            "vltk_hit_friend": to_int(cells[col["CanColFriend"]]),
        }
    return out


def norm(name: str) -> str:
    name = re.sub(r"\s*\([^)]*\)\s*$", "", name.strip())
    return unicodedata.normalize("NFC", name).lower()


def load_skills_txt(path=None):
    raw = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path or SKILLS_TXT)],
                         capture_output=True, check=True).stdout.decode("utf-8", "replace")
    lines = raw.splitlines()
    header = lines[0].split("\t")
    col = {h: i for i, h in enumerate(header)}
    by_name = {}
    by_id = {}
    for line in lines[1:]:
        cells = line.split("\t")
        cells += [""] * (len(header) - len(cells))
        mapping = {}
        n = 1
        while f"LvlSetting{n}" in col:
            attr = cells[col[f"LvlSetting{n}"]].strip()
            table = cells[col[f"LvlData{n}"]].strip()
            if attr and table and (not attr.startswith(SKIP_PREFIXES) or attr == "skill_attackradius"):
                mapping.setdefault(attr, table)
            n += 1
        flags = {k: cells[col[c]].strip() == "1" for k, c in FLAG_COLUMNS.items()}
        flags["vltk_is_physical"] = 1 if cells[col["IsPhysical"]].strip() == "1" else 0
        for field, column in INT_COLUMNS.items():
            flags[field] = to_int(cells[col[column]])
        flags["_child_missle"] = to_int(cells[col["ChildSkillId"]])
        script = cells[col["LvlSetScript"]].strip().replace("\\", "/").lstrip("/")
        by_name.setdefault(norm(cells[col["SkillName"]]), []).append((script, mapping, flags))
        by_id[to_int(cells[col["SkillId"]])] = (script, mapping, flags)
    return by_name, by_id


# ---- parser bảng lua literal tối giản (số/biểu thức số, bảng lồng, [n]=, tên hàm Line/Conic/Extrac) ----
def match_brace(text: str, start: int) -> int:
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("brace không đóng")


def strip_comments(text: str) -> str:
    return re.sub(r"--[^\n]*", "", text)


NUM_EXPR = r"-?\(?\s*-?\d+(?:\.\d+)?(?:\s*[-+*/]\s*\(?\s*-?\d+(?:\.\d+)?\s*\)?)*\s*\)?"


def parse_table(src: str):
    tokens = re.findall(r"\{|\}|\[|\]|=|,|" + NUM_EXPR + r"|[A-Za-z_]\w*", src)
    pos = 0

    def value():
        nonlocal pos
        tok = tokens[pos]
        if tok == "{":
            pos += 1
            items, keyed = [], {}
            while tokens[pos] != "}":
                if tokens[pos] == "[":
                    key = int(tokens[pos + 1])
                    pos += 4  # [ n ] =
                    keyed[key] = value()
                else:
                    items.append(value())
                if tokens[pos] == ",":
                    pos += 1
            pos += 1
            if keyed:
                out = [None] * max(list(keyed) + [len(items)])
                for i, v in enumerate(items):
                    out[i] = v
                for k, v in keyed.items():
                    out[k - 1] = v
                return out
            return items
        pos += 1
        if re.fullmatch(NUM_EXPR, tok):
            return float(eval(tok, {"__builtins__": {}}))  # chỉ chứa số và + - * / ( )
        return tok  # tên hàm nội suy (Line/Conic/Extrac)

    return value()


_lua_cache = {}


def lua_attr(script: str, table: str, attr: str, dirs=None):
    dirs = dirs or LUA_DIRS
    key = (script, tuple(dirs))
    if key not in _lua_cache:
        _lua_cache[key] = None
        for base in dirs:
            path = base / script
            if path.exists():
                _lua_cache[key] = strip_comments(path.read_bytes().decode("latin-1"))
                break
    text = _lua_cache[key]
    if text is None:
        return None
    m = re.search(r"(?<![\w])" + re.escape(table) + r"\s*=\s*\{", text)
    if not m:
        return None
    block = text[m.end() - 1: match_brace(text, m.end() - 1) + 1]
    a = re.search(r"(?<![\w])" + re.escape(attr) + r"\s*=\s*\{", block)
    if not a:
        return None
    try:
        return parse_table(block[a.end() - 1: match_brace(block, a.end() - 1) + 1])
    except (ValueError, IndexError, SyntaxError):
        return None


## Mã hàm nội suy của 1 mốc (cột thứ 3 trong lua) — khớp SkillDefinition.eval_level_points().
CURVE_CODES = {"Line": 0, "Conic": 1, "Extrac": 2}


def points_literal(comp) -> str:
    """1 thành phần -> PackedFloat32Array(cấp, giá trị, mã hàm, ...)."""
    if not comp or not isinstance(comp, list):
        return "PackedFloat32Array()"
    nums = []
    for p in comp:
        if isinstance(p, list) and len(p) >= 2 and isinstance(p[0], float) and isinstance(p[1], float):
            curve = CURVE_CODES.get(p[2], 0) if len(p) > 2 and isinstance(p[2], str) else 0
            nums += [p[0], p[1], curve]
    return "PackedFloat32Array(" + ", ".join(f"{v:g}" for v in nums) + ")"


def attribs_literal(attribs: dict) -> str:
    parts = []
    for name in sorted(attribs):
        comps = (attribs[name] + [None, None, None])[:3]
        parts.append(f'"{name}": [' + ", ".join(points_literal(c) for c in comps) + "]")
    return "{\n" + ",\n".join(parts) + "\n}"


def main():
    dry = "--dry" in sys.argv
    old_tables = (*load_skills_txt(), load_missles())
    new_tables = (*load_skills_txt(NEW_SKILLS_TXT), load_missles(NEW_MISSLES_TXT))
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    stats = {"skills": 0, "matched": 0, "with_attribs": 0, "conic": set()}
    for tres in sorted(TRES_DIR.glob("*.tres")):
        if only and tres.stem not in only:
            continue
        is_new = tres.stem in NEW_SECTS
        by_name, by_id, missles = new_tables if is_new else old_tables
        lua_dirs = NEW_LUA_DIRS if is_new else LUA_DIRS
        text = tres.read_text(encoding="utf-8")
        blocks = re.split(r"(?=\n\[sub_resource)", text)
        changed = False
        for bi, block in enumerate(blocks):
            name_m = re.search(r'^skill_name = "([^"]*)"', block, re.M)
            if not name_m:
                continue
            stats["skills"] += 1
            ## Xoá dữ liệu cũ (gồm cả dict nhiều dòng của vltk_attribs) để chạy lại được.
            new_block = re.sub(r'^vltk_attribs = \{.*?^\}\n', "", block, flags=re.M | re.S)
            new_block = re.sub(r"^(?:" + "|".join(WRITTEN_FIELDS) + r") = .*\n", "", new_block, flags=re.M)
            ## Ưu tiên ghép theo SkillId (tên skill VNG đổi chữ so với bản cũ, VD "Tích Lịch Đơn"), không có thì ghép theo tên.
            id_m = re.search(r"^vltk_skill_id = (\d+)", block, re.M)
            rows = [by_id[int(id_m.group(1))]] if id_m and int(id_m.group(1)) in by_id else by_name.get(norm(name_m.group(1)), [])
            if rows:
                stats["matched"] += 1
                script, mapping, flags = rows[0]
                attribs = {}
                for attr, table in mapping.items():
                    parsed = lua_attr(script, table, attr, lua_dirs)
                    if isinstance(parsed, list) and parsed:
                        attribs[attr] = parsed
                        if "Conic" in str(parsed) or "Extrac" in str(parsed):
                            stats["conic"].add(f"{name_m.group(1)}.{attr}")
                if "skill_attackradius" not in attribs:
                    for table in set(mapping.values()):
                        parsed_ar = lua_attr(script, table, "skill_attackradius", lua_dirs)
                        if isinstance(parsed_ar, list) and parsed_ar:
                            attribs["skill_attackradius"] = parsed_ar
                            break
                if "skill_attackradius" in attribs and attribs["skill_attackradius"]:
                    ar_points = attribs["skill_attackradius"][0]
                    if ar_points and len(ar_points) > 0 and len(ar_points[0]) >= 2:
                        flags["vltk_attack_radius"] = int(ar_points[0][1])
                lines = "".join(f"{k} = {'true' if flags[k] else 'false'}\n" for k in FLAG_COLUMNS)
                for field in ["vltk_is_physical"] + list(INT_COLUMNS):
                    value = flags[field]
                    if is_new and field == "vltk_state_special_id" and value > 0:
                        value += vltk_source.FX_ID_OFFSET   ## states.json: trạng thái bản 15 phái ở khoá riêng
                    lines += f"{field} = {value}\n"
                missle = missles.get(flags["_child_missle"], {})
                if not missle and flags["_child_missle"] in by_id:
                    sub_child = by_id[flags["_child_missle"]][2].get("_child_missle", 0)
                    missle = missles.get(sub_child, {})
                for field in MISSLE_FIELDS:
                    lines += f"{field} = {missle.get(field, 0)}\n"
                if attribs:
                    stats["with_attribs"] += 1
                    lines += f"vltk_attribs = {attribs_literal(attribs)}\n"
                anchor = re.search(r"^max_level = .*\n", new_block, re.M)
                pos = anchor.end() if anchor else name_m.end() + 1
                new_block = new_block[:pos] + lines + new_block[pos:]
                if dry:
                    print(f"{tres.stem:18} {name_m.group(1):40} {sorted(attribs)} form={flags['vltk_missle_form']} "
                          f"tầm={flags['vltk_attack_radius']} missle={missle} "
                          f"{dict((k, flags[k]) for k in FLAG_COLUMNS if flags[k])}")
            if new_block != block:
                blocks[bi] = new_block
                changed = True
        if changed and not dry:
            tres.write_text("".join(blocks), encoding="utf-8", newline="\n")
    print(f"\nTổng skill: {stats['skills']}, ghép được Skills.txt: {stats['matched']}, có thuộc tính: {stats['with_attribs']}")
    if stats["conic"]:
        print("Mốc dùng hàm nội suy Conic/Extrac (đã lưu mã hàm):", sorted(stats["conic"]))


if __name__ == "__main__":
    main()
